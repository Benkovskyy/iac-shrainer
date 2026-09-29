#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Домашняя работа №1
# Вариант 06 (Шрайнер)
# ==========================================

# Личный префикс ресурсов
PREFIX="${PREFIX:-shrainer}"

# Параметры варианта
ZONE_A="${ZONE_A:-ru-central1-d}"
ZONE_B="${ZONE_B:-ru-central1-a}"

CIDR_A="${CIDR_A:-10.16.1.0/24}"
CIDR_B="${CIDR_B:-10.16.2.0/24}"

PORT="${PORT:-8018}"
WORD="${WORD:-netlab}"
WEB_COUNT="${WEB_COUNT:-3}"
ENV_NAME="${ENV_NAME:-dev}"

# Разбор аргументов командной строки.
# Аргумент имеет приоритет над переменной окружения и значением по умолчанию.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --web-count)
            WEB_COUNT="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --word)
            WORD="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --zone-a)
            ZONE_A="$2"
            shift 2
            ;;
        --zone-b)
            ZONE_B="$2"
            shift 2
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Создание стенда"
echo "=========================================="
echo "Префикс:       $PREFIX"
echo "Зона A:        $ZONE_A"
echo "Зона B:        $ZONE_B"
echo "Подсеть A:     $CIDR_A"
echo "Подсеть B:     $CIDR_B"
echo "Порт:          $PORT"
echo "Слово:         $WORD"
echo "Web-серверов:  $WEB_COUNT"
echo "Окружение:     $ENV_NAME"
echo "=========================================="


# ==========================================
# Создание сети
# ==========================================

NETWORK_NAME="${PREFIX}-net"

echo
echo "Проверяю сеть $NETWORK_NAME..."

if yc vpc network get "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Сеть $NETWORK_NAME уже существует, пропускаю."
else
    echo "Создаю сеть $NETWORK_NAME..."
    yc vpc network create --name "$NETWORK_NAME"
fi


# ==========================================
# Создание подсетей
# ==========================================

SUBNET_A_NAME="${PREFIX}-subnet-a"
SUBNET_B_NAME="${PREFIX}-subnet-b"

echo
echo "Проверяю подсеть $SUBNET_A_NAME..."

if yc vpc subnet get "$SUBNET_A_NAME" >/dev/null 2>&1; then
    echo "Подсеть $SUBNET_A_NAME уже существует, пропускаю."
else
    echo "Создаю подсеть $SUBNET_A_NAME..."
    yc vpc subnet create \
        --name "$SUBNET_A_NAME" \
        --zone "$ZONE_A" \
        --network-name "$NETWORK_NAME" \
        --range "$CIDR_A"
fi

echo
echo "Проверяю подсеть $SUBNET_B_NAME..."

if yc vpc subnet get "$SUBNET_B_NAME" >/dev/null 2>&1; then
    echo "Подсеть $SUBNET_B_NAME уже существует, пропускаю."
else
    echo "Создаю подсеть $SUBNET_B_NAME..."
    yc vpc subnet create \
        --name "$SUBNET_B_NAME" \
        --zone "$ZONE_B" \
        --network-name "$NETWORK_NAME" \
        --range "$CIDR_B"
fi


# ==========================================
# Создание NAT-шлюза
# ==========================================

NAT_NAME="${PREFIX}-nat"
ROUTE_TABLE_NAME="${PREFIX}-rt"

echo
echo "Проверяю NAT-шлюз $NAT_NAME..."

if yc vpc gateway get "$NAT_NAME" >/dev/null 2>&1; then
    echo "NAT-шлюз $NAT_NAME уже существует, пропускаю."
else
    echo "Создаю NAT-шлюз $NAT_NAME..."
    yc vpc gateway create --name "$NAT_NAME"
fi

GW_ID=$(yc vpc gateway get --name "$NAT_NAME" --format json | jq -r '.id')

# ==========================================
# Создание таблицы маршрутизации
# ==========================================

echo
echo "Проверяю таблицу маршрутизации $ROUTE_TABLE_NAME..."

if yc vpc route-table get "$ROUTE_TABLE_NAME" >/dev/null 2>&1; then
    echo "Таблица маршрутизации $ROUTE_TABLE_NAME уже существует, пропускаю."
else
    echo "Создаю таблицу маршрутизации $ROUTE_TABLE_NAME..."
    yc vpc route-table create \
        --name "$ROUTE_TABLE_NAME" \
        --network-name "$NETWORK_NAME" \
        --route "destination=0.0.0.0/0,gateway-id=$GW_ID"
fi

# ==========================================
# Подключение таблицы маршрутизации к подсети A
# ==========================================

echo
echo "Подключаю таблицу маршрутизации к $SUBNET_A_NAME..."

yc vpc subnet update \
    --name "$SUBNET_A_NAME" \
    --route-table-name "$ROUTE_TABLE_NAME" \
    >/dev/null

echo "Таблица маршрутизации подключена к $SUBNET_A_NAME."
