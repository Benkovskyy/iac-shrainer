#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Домашняя работа №1
# Удаление стенда
# Вариант 06 — Шрайнер
# ==========================================

PREFIX="${PREFIX:-shrainer}"
ENV_NAME="${ENV_NAME:-dev}"

echo "=========================================="
echo "Удаление стенда"
echo "Метка owner: $PREFIX"
echo "=========================================="

# Возвращает ID ресурсов, созданных этим стендом.
# Поиск выполняется по метке owner, а не по имени.
find_by_owner() {
    "$@" --format json |
        jq -r --arg OWNER "$PREFIX" --arg ENV_LABEL "$ENV_NAME" \
        '.[] | select(.labels.owner == $OWNER and .labels.env == $ENV_LABEL) | .id'
}

# ==========================================
# Удаление балансировщиков
# ==========================================

echo
echo "Ищу балансировщики с owner=$PREFIX..."

mapfile -t LB_IDS < <(
    find_by_owner yc load-balancer network-load-balancer list
)

if (( ${#LB_IDS[@]} == 0 )); then
    echo "Балансировщики отсутствуют, пропускаю."
else
    for ID in "${LB_IDS[@]}"; do
        echo "Удаляю балансировщик $ID..."
        yc load-balancer network-load-balancer delete --id "$ID"
    done
fi

# ==========================================
# Удаление target group
# ==========================================

echo
echo "Ищу target group с owner=$PREFIX..."

mapfile -t TG_IDS < <(
    find_by_owner yc load-balancer target-group list
)

if (( ${#TG_IDS[@]} == 0 )); then
    echo "Target group отсутствуют, пропускаю."
else
    for ID in "${TG_IDS[@]}"; do
        echo "Удаляю target group $ID..."
        yc load-balancer target-group delete --id "$ID"
    done
fi

# ==========================================
# Удаление виртуальных машин
# ==========================================

echo
echo "Ищу ВМ с owner=$PREFIX..."

mapfile -t VM_IDS < <(
    find_by_owner yc compute instance list
)

if (( ${#VM_IDS[@]} == 0 )); then
    echo "ВМ отсутствуют, пропускаю."
else
    for ID in "${VM_IDS[@]}"; do
        echo "Удаляю ВМ $ID..."
        yc compute instance delete --id "$ID"
    done
fi

# ==========================================
# Удаление дополнительных дисков
# ==========================================

echo
echo "Ищу дополнительные диски с owner=$PREFIX..."

mapfile -t DISK_IDS < <(
    find_by_owner yc compute disk list
)

if (( ${#DISK_IDS[@]} == 0 )); then
    echo "Дополнительные диски отсутствуют, пропускаю."
else
    for ID in "${DISK_IDS[@]}"; do
        echo "Удаляю диск $ID..."
        yc compute disk delete --id "$ID"
    done
fi

# Загрузочные диски отдельно не ищутся:
# они создаются вместе с ВМ с auto-delete и собственных меток не получают.

# ==========================================
# Удаление подсетей
# ==========================================

echo
echo "Ищу подсети с owner=$PREFIX..."

mapfile -t SUBNET_IDS < <(
    find_by_owner yc vpc subnet list
)

if (( ${#SUBNET_IDS[@]} == 0 )); then
    echo "Подсети отсутствуют, пропускаю."
else
    for ID in "${SUBNET_IDS[@]}"; do
        echo "Удаляю подсеть $ID..."
        yc vpc subnet delete --id "$ID"
    done
fi

# ==========================================
# Удаление таблиц маршрутизации
# ==========================================

echo
echo "Ищу таблицы маршрутизации с owner=$PREFIX..."

mapfile -t ROUTE_TABLE_IDS < <(
    find_by_owner yc vpc route-table list
)

if (( ${#ROUTE_TABLE_IDS[@]} == 0 )); then
    echo "Таблицы маршрутизации отсутствуют, пропускаю."
else
    for ID in "${ROUTE_TABLE_IDS[@]}"; do
        echo "Удаляю таблицу маршрутизации $ID..."
        yc vpc route-table delete --id "$ID"
    done
fi

# ==========================================
# Удаление NAT-шлюзов
# ==========================================

echo
echo "Ищу NAT-шлюзы с owner=$PREFIX..."

mapfile -t NAT_IDS < <(
    find_by_owner yc vpc gateway list
)

if (( ${#NAT_IDS[@]} == 0 )); then
    echo "NAT-шлюзы отсутствуют, пропускаю."
else
    for ID in "${NAT_IDS[@]}"; do
        echo "Удаляю NAT-шлюз $ID..."
        yc vpc gateway delete --id "$ID"
    done
fi

# ==========================================
# Удаление сетей
# ==========================================

echo
echo "Ищу сети с owner=$PREFIX..."

mapfile -t NETWORK_IDS < <(
    find_by_owner yc vpc network list
)

if (( ${#NETWORK_IDS[@]} == 0 )); then
    echo "Сети отсутствуют, пропускаю."
else
    for ID in "${NETWORK_IDS[@]}"; do
        echo "Удаляю сеть $ID..."
        yc vpc network delete --id "$ID"
    done
fi

echo
echo "=========================================="
echo "Удаление стенда завершено."
echo "=========================================="
