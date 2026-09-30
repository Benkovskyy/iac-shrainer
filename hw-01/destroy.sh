#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Домашняя работа №1
# Удаление стенда
# Вариант 06 — Шрайнер
# ==========================================

PREFIX="${PREFIX:-shrainer}"
WEB_COUNT="${WEB_COUNT:-3}"

ZONE_A="${ZONE_A:-ru-central1-d}"
ZONE_B="${ZONE_B:-ru-central1-b}"

NETWORK_NAME="${PREFIX}-net"
SUBNET_A_NAME="${PREFIX}-subnet-a"
SUBNET_B_NAME="${PREFIX}-subnet-b"
ROUTE_TABLE_NAME="${PREFIX}-rt"
NAT_NAME="${PREFIX}-nat"
TG_NAME="${PREFIX}-tg"
LB_NAME="${PREFIX}-lb"

echo "=========================================="
echo "Удаление стенда"
echo "Префикс: $PREFIX"
echo "=========================================="

# ==========================================
# Удаление балансировщика
# ==========================================

echo
echo "Проверяю балансировщик $LB_NAME..."

LB_ID=$(
    yc load-balancer network-load-balancer list --format json |
    jq -r --arg NAME "$LB_NAME" '.[] | select(.name == $NAME) | .id' |
    head -n 1
)

if [[ -n "$LB_ID" ]]; then
    echo "Удаляю балансировщик $LB_NAME..."
    yc load-balancer network-load-balancer delete --id "$LB_ID"
else
    echo "Балансировщик $LB_NAME отсутствует, пропускаю."
fi

# ==========================================
# Удаление target group
# ==========================================

echo
echo "Проверяю target group $TG_NAME..."

TG_ID=$(
    yc load-balancer target-group list --format json |
    jq -r --arg NAME "$TG_NAME" '.[] | select(.name == $NAME) | .id' |
    head -n 1
)

if [[ -n "$TG_ID" ]]; then
    echo "Удаляю target group $TG_NAME..."
    yc load-balancer target-group delete --id "$TG_ID"
else
    echo "Target group $TG_NAME отсутствует, пропускаю."
fi

# ==========================================
# Удаление виртуальных машин
# ==========================================

for ((i=1; i<=WEB_COUNT; i++)); do

    VM_NAME="${PREFIX}-web-${i}"

    echo
    echo "Проверяю ВМ $VM_NAME..."

    VM_ID=$(
        yc compute instance list --format json |
        jq -r --arg NAME "$VM_NAME" \
        '.[] | select(.name == $NAME) | .id' |
        head -n 1
    )

    if [[ -n "$VM_ID" ]]; then
        echo "Удаляю ВМ $VM_NAME..."
        yc compute instance delete \
            --id "$VM_ID"
    else
        echo "ВМ $VM_NAME отсутствует, пропускаю."
    fi

done

# ==========================================
# Удаление дополнительных дисков
# ==========================================

for ((i=1; i<=WEB_COUNT; i++)); do

    DISK_NAME="${PREFIX}-data-${i}"

    echo
    echo "Проверяю диск $DISK_NAME..."

    DISK_ID=$(
        yc compute disk list --format json |
        jq -r --arg NAME "$DISK_NAME" \
        '.[] | select(.name == $NAME) | .id' |
        head -n 1
    )

    if [[ -n "$DISK_ID" ]]; then
        echo "Удаляю диск $DISK_NAME..."
        yc compute disk delete \
            --id "$DISK_ID"
    else
        echo "Диск $DISK_NAME отсутствует, пропускаю."
    fi

done

# ==========================================
# Удаление подсетей
# ==========================================

echo
echo "Проверяю подсеть $SUBNET_A_NAME..."

if yc vpc subnet get "$SUBNET_A_NAME" >/dev/null 2>&1; then
    echo "Удаляю подсеть $SUBNET_A_NAME..."
    yc vpc subnet delete \
        --name "$SUBNET_A_NAME"
else
    echo "Подсеть $SUBNET_A_NAME отсутствует, пропускаю."
fi

echo
echo "Проверяю подсеть $SUBNET_B_NAME..."

if yc vpc subnet get "$SUBNET_B_NAME" >/dev/null 2>&1; then
    echo "Удаляю подсеть $SUBNET_B_NAME..."
    yc vpc subnet delete \
        --name "$SUBNET_B_NAME"
else
    echo "Подсеть $SUBNET_B_NAME отсутствует, пропускаю."
fi

# ==========================================
# Удаление таблицы маршрутизации
# ==========================================

echo
echo "Проверяю таблицу маршрутизации $ROUTE_TABLE_NAME..."

if yc vpc route-table get "$ROUTE_TABLE_NAME" >/dev/null 2>&1; then
    echo "Удаляю таблицу маршрутизации $ROUTE_TABLE_NAME..."
    yc vpc route-table delete \
        --name "$ROUTE_TABLE_NAME"
else
    echo "Таблица маршрутизации отсутствует, пропускаю."
fi

# ==========================================
# Удаление NAT-шлюза
# ==========================================

echo
echo "Проверяю NAT-шлюз $NAT_NAME..."

if yc vpc gateway get "$NAT_NAME" >/dev/null 2>&1; then
    echo "Удаляю NAT-шлюз $NAT_NAME..."
    yc vpc gateway delete \
        --name "$NAT_NAME"
else
    echo "NAT-шлюз отсутствует, пропускаю."
fi

# ==========================================
# Удаление сети
# ==========================================

echo
echo "Проверяю сеть $NETWORK_NAME..."

if yc vpc network get "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Удаляю сеть $NETWORK_NAME..."
    yc vpc network delete \
        --name "$NETWORK_NAME"
else
    echo "Сеть $NETWORK_NAME отсутствует, пропускаю."
fi

echo
echo "=========================================="
echo "Удаление стенда завершено."
echo "=========================================="
