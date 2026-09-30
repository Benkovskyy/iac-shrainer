#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Домашняя работа №1
# Вариант 06 — Шрайнер
# ==========================================

PREFIX="${PREFIX:-shrainer}"

ZONE_A="${ZONE_A:-ru-central1-d}"
ZONE_B="${ZONE_B:-ru-central1-b}"

CIDR_A="${CIDR_A:-10.16.1.0/24}"
CIDR_B="${CIDR_B:-10.16.2.0/24}"

PORT="${PORT:-8018}"
WORD="${WORD:-netlab}"

WEB_COUNT="${WEB_COUNT:-3}"
DISK_SIZE="${DISK_SIZE:-15}"
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-25}"

ENV_NAME="${ENV_NAME:-dev}"

# ==========================================
# Аргументы
# ==========================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --web-count)
            WEB_COUNT="$2"
            shift 2
            ;;
        --disk-size)
            DISK_SIZE="$2"
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
echo "Доп. диск:     ${DISK_SIZE} ГБ"
echo "Boot-диск:     ${BOOT_DISK_SIZE} ГБ"
echo "Окружение:     $ENV_NAME"
echo "=========================================="

# ==========================================
# Имена ресурсов
# ==========================================

NETWORK_NAME="${PREFIX}-net"

SUBNET_A_NAME="${PREFIX}-subnet-a"
SUBNET_B_NAME="${PREFIX}-subnet-b"

NAT_NAME="${PREFIX}-nat"
ROUTE_TABLE_NAME="${PREFIX}-rt"

# ==========================================
# Сеть
# ==========================================

echo
echo "Проверяю сеть $NETWORK_NAME..."

if yc vpc network get "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Сеть $NETWORK_NAME уже существует, пропускаю."
else
    echo "Создаю сеть $NETWORK_NAME..."
    yc vpc network create \
        --name "$NETWORK_NAME"
fi

# ==========================================
# Подсеть A
# ==========================================

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

# ==========================================
# Подсеть B
# ==========================================

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
# NAT-шлюз
# ==========================================

echo
echo "Проверяю NAT-шлюз $NAT_NAME..."

if yc vpc gateway get "$NAT_NAME" >/dev/null 2>&1; then
    echo "NAT-шлюз $NAT_NAME уже существует, пропускаю."
else
    echo "Создаю NAT-шлюз $NAT_NAME..."

    yc vpc gateway create \
        --name "$NAT_NAME"
fi

GW_ID=$(
    yc vpc gateway get \
        --name "$NAT_NAME" \
        --format json |
        jq -r '.id'
)

# ==========================================
# Таблица маршрутизации
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
# Подключение route table
# ==========================================

echo
echo "Подключаю таблицу маршрутизации к $SUBNET_A_NAME..."

yc vpc subnet update \
    --name "$SUBNET_A_NAME" \
    --route-table-name "$ROUTE_TABLE_NAME" \
    >/dev/null

echo "Таблица маршрутизации подключена к $SUBNET_A_NAME."

echo
echo "Подключаю таблицу маршрутизации к $SUBNET_B_NAME..."

yc vpc subnet update \
    --name "$SUBNET_B_NAME" \
    --route-table-name "$ROUTE_TABLE_NAME" \
    >/dev/null

echo "Таблица маршрутизации подключена к $SUBNET_B_NAME."

# ==========================================
# Cloud-init
# ==========================================

SSH_KEY_FILE="$HOME/.ssh/id_ed25519.pub"
CLOUD_INIT_TEMPLATE="cloud-init.tpl.yaml"
CLOUD_INIT_FILE="cloud-init.yaml"

if [[ ! -f "$SSH_KEY_FILE" ]]; then
    echo "Ошибка: SSH-ключ $SSH_KEY_FILE не найден."
    exit 1
fi

if [[ ! -f "$CLOUD_INIT_TEMPLATE" ]]; then
    echo "Ошибка: шаблон $CLOUD_INIT_TEMPLATE не найден."
    exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_FILE")

# ==========================================
# Виртуальные машины
# ==========================================

echo
echo "Создаю виртуальные машины..."

for ((i=1; i<=WEB_COUNT; i++)); do

    VM_NAME="${PREFIX}-web-${i}"
    DISK_NAME="${PREFIX}-data-${i}"

    # Нечётные машины — зона A
    # Чётные машины — зона B
    if (( i % 2 == 1 )); then
        VM_ZONE="$ZONE_A"
        VM_SUBNET="$SUBNET_A_NAME"
    else
        VM_ZONE="$ZONE_B"
        VM_SUBNET="$SUBNET_B_NAME"
    fi

    echo
    echo "------------------------------------------"
    echo "ВМ:      $VM_NAME"
    echo "Зона:    $VM_ZONE"
    echo "Подсеть: $VM_SUBNET"
    echo "------------------------------------------"

    # ======================================
    # Генерация cloud-init
    # ======================================

    sed \
        -e "s|__SSH_KEY__|$SSH_KEY|g" \
        -e "s|__PORT__|$PORT|g" \
        -e "s|__WORD__|$WORD|g" \
        -e "s|__SERVER_NAME__|$VM_NAME|g" \
        "$CLOUD_INIT_TEMPLATE" > "$CLOUD_INIT_FILE"

    # ======================================
    # Дополнительный диск
    # ======================================

    DISK_EXISTS=$(
        yc compute disk list \
            --format json |
            jq -r --arg NAME "$DISK_NAME" \
            '.[] | select(.name == $NAME) | .id' |
            head -n 1
    )

    if [[ -n "$DISK_EXISTS" ]]; then
        echo "Диск $DISK_NAME уже существует, пропускаю."
    else
        echo "Создаю дополнительный диск $DISK_NAME (${DISK_SIZE} ГБ)..."

        yc compute disk create \
            --name "$DISK_NAME" \
            --zone "$VM_ZONE" \
            --size "$DISK_SIZE"
    fi

    # ======================================
    # Проверка существования ВМ
    # ======================================

    VM_EXISTS=$(
        yc compute instance list \
            --format json |
            jq -r --arg NAME "$VM_NAME" \
            '.[] | select(.name == $NAME) | .id' |
            head -n 1
    )

    if [[ -n "$VM_EXISTS" ]]; then
        echo "ВМ $VM_NAME уже существует, пропускаю."
        continue
    fi

    # ======================================
    # Создание ВМ
    # ======================================

    echo "Создаю ВМ $VM_NAME..."

    yc compute instance create \
        --name "$VM_NAME" \
        --zone "$VM_ZONE" \
        --cores 2 \
        --memory 2GB \
        --create-boot-disk \
            "image-family=ubuntu-2204-lts,image-folder-id=standard-images,size=${BOOT_DISK_SIZE}GB" \
        --attach-disk \
            "disk-name=$DISK_NAME,device-name=data-disk" \
        --network-interface \
            "subnet-name=$VM_SUBNET,nat-ip-version=ipv4" \
        --metadata-from-file \
            "user-data=$CLOUD_INIT_FILE"

done

# ==========================================
# Очистка временного cloud-init
# ==========================================
# Target group и балансировщик
# ==========================================

TG_NAME="${PREFIX}-tg"
LB_NAME="${PREFIX}-lb"

echo
echo "Создаю target group $TG_NAME..."

TG_EXISTS=$(
    yc load-balancer target-group list --format json |
    jq -r --arg NAME "$TG_NAME" '.[] | select(.name == $NAME) | .id' |
    head -n 1
)

if [[ -z "$TG_EXISTS" ]]; then
    TARGET_ARGS=()

    for ((i=1; i<=WEB_COUNT; i++)); do
        VM_NAME="${PREFIX}-web-${i}"
        VM_INFO=$(yc compute instance get "$VM_NAME" --format json)
        VM_IP=$(echo "$VM_INFO" | jq -r '.network_interfaces[0].primary_v4_address.address')
        SUBNET_ID=$(echo "$VM_INFO" | jq -r '.network_interfaces[0].subnet_id')

        TARGET_ARGS+=(--target "subnet-id=${SUBNET_ID},address=${VM_IP}")
    done

    yc load-balancer target-group create \
        --name "$TG_NAME" \
        "${TARGET_ARGS[@]}"
else
    echo "Target group $TG_NAME уже существует, пропускаю."
fi

echo
echo "Создаю сетевой балансировщик $LB_NAME..."

LB_EXISTS=$(
    yc load-balancer network-load-balancer list --format json |
    jq -r --arg NAME "$LB_NAME" '.[] | select(.name == $NAME) | .id' |
    head -n 1
)

if [[ -z "$LB_EXISTS" ]]; then
    yc load-balancer network-load-balancer create \
        --name "$LB_NAME" \
        --listener "name=${PREFIX}-listener,port=${PORT},target-port=${PORT},external-ip-version=ipv4"

    TG_ID=$(yc load-balancer target-group get "$TG_NAME" --format json | jq -r '.id')

    yc load-balancer network-load-balancer attach-target-group "$LB_NAME" \
        --target-group "target-group-id=${TG_ID},healthcheck-name=${PREFIX}-healthcheck,healthcheck-tcp-port=${PORT}"
else
    echo "Балансировщик $LB_NAME уже существует, пропускаю."
fi

echo "Балансировщик настроен."

# ==========================================

rm -f "$CLOUD_INIT_FILE"

echo
echo "=========================================="
echo "Создание виртуальных машин завершено."
echo "=========================================="
