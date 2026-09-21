#!/usr/bin/env bash
set -euo pipefail

PREFIX="shrainer-06"

NETWORK_NAME="${PREFIX}-net"
SUBNET_NAME="${PREFIX}-subnet"
VM1_NAME="${PREFIX}-app-1"
VM2_NAME="${PREFIX}-app-2"

echo "Удаление виртуальной машины ${VM1_NAME}..."
yc compute instance delete "$VM1_NAME"

echo "Удаление виртуальной машины ${VM2_NAME}..."
yc compute instance delete "$VM2_NAME"

echo "Удаление подсети ${SUBNET_NAME}..."
yc vpc subnet delete "$SUBNET_NAME"

echo "Удаление сети ${NETWORK_NAME}..."
yc vpc network delete "$NETWORK_NAME"

echo
echo "Проверка оставшихся ресурсов:"
yc compute instance list
yc vpc subnet list
yc vpc network list
yc compute disk list
