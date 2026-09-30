#!/usr/bin/env bash

set -uo pipefail

PREFIX="${PREFIX:-shrainer}"
PORT="${PORT:-8018}"
WEB_COUNT="${WEB_COUNT:-3}"

LB_NAME="${PREFIX}-lb"
APP_NAME="${PREFIX}-app"

RESULT=0

echo "=========================================="
echo "Проверка стенда"
echo "=========================================="

# ==========================================
# Проверка наличия балансировщика
# ==========================================

if ! LB_JSON=$(yc load-balancer network-load-balancer get "$LB_NAME" --format json 2>/dev/null); then
    echo "✗ балансировщик $LB_NAME не найден"
    exit 1
fi

LB_IP=$(echo "$LB_JSON" | jq -r '.listeners[0].address // empty')

if [[ -z "$LB_IP" ]]; then
    echo "✗ у балансировщика нет публичного IP"
    exit 1
fi

# ==========================================
# 1. Балансировщик отвечает HTTP 200
# ==========================================

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 \
    "http://${LB_IP}/" || true)

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✓ балансировщик отвечает: 200"
else
    echo "✗ балансировщик не отвечает: ${HTTP_CODE:-нет ответа}"
    RESULT=1
fi

# ==========================================
# 2. Ответы приходят более чем с одной ВМ
# ==========================================

SERVERS=$(
    for ((i=1; i<=10; i++)); do
        curl -s --connect-timeout 3 "http://${LB_IP}/" 2>/dev/null |
            sed -n 's/.*Server: \([^<]*\).*/\1/p'
    done |
    sort -u
)

SERVER_COUNT=$(printf '%s\n' "$SERVERS" | sed '/^$/d' | wc -l)

if (( SERVER_COUNT == WEB_COUNT )); then
    echo "✓ ответили машины: $(echo "$SERVERS" | paste -sd ', ' -)"
else
    echo "✗ ответили машины: ${SERVER_COUNT} из ${WEB_COUNT}"
    RESULT=1
fi

# ==========================================
# 3. App доступен с web-сервера
# ==========================================

APP_IP=$(
    yc compute instance get "$APP_NAME" --format json 2>/dev/null |
    jq -r '.network_interfaces[0].primary_v4_address.address // empty'
)

WEB1_IP=$(
    yc compute instance get "${PREFIX}-web-1" --format json 2>/dev/null |
    jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty'
)

if [[ -n "$APP_IP" && -n "$WEB1_IP" ]]; then
    APP_CODE=$(
        ssh -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=no \
            "shrainer@${WEB1_IP}" \
            "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://${APP_IP}:${PORT}/" \
            2>/dev/null || true
    )

    if [[ "$APP_CODE" == "200" ]]; then
        echo "✓ сервер приложения доступен с web-1: 200"
    else
        echo "✗ сервер приложения недоступен с web-1"
        RESULT=1
    fi
else
    echo "✗ не удалось определить адрес web-1 или app"
    RESULT=1
fi

echo "=========================================="
exit "$RESULT"
