#!/usr/bin/env bash
set -u

PREFIX="shrainer-06"
VM_COUNT="${1:-3}"

NETWORK_NAME="${PREFIX}-net"
SUBNET_A="${PREFIX}-subnet-a"
SUBNET_B="${PREFIX}-subnet-b"
DATA_DISK="${PREFIX}-data"
TARGET_GROUP="${PREFIX}-tg"
LOAD_BALANCER="${PREFIX}-lb"

echo "=== Удаление стенда ${PREFIX} ==="

# ---- балансировщик ----
echo "==> балансировщик"

if yc load-balancer network-load-balancer get \
  --name "${LOAD_BALANCER}" >/dev/null 2>&1; then

  yc load-balancer network-load-balancer delete \
    --name "${LOAD_BALANCER}"
else
  echo "${LOAD_BALANCER}: уже отсутствует"
fi

# ---- целевая группа ----
echo "==> целевая группа"

if yc load-balancer target-group get \
  --name "${TARGET_GROUP}" >/dev/null 2>&1; then

  yc load-balancer target-group delete \
    --name "${TARGET_GROUP}"
else
  echo "${TARGET_GROUP}: уже отсутствует"
fi

# ---- виртуальные машины ----
echo "==> виртуальные машины"

for i in $(seq 1 "${VM_COUNT}"); do
  VM_NAME="${PREFIX}-app-${i}"

  if yc compute instance get \
    --name "${VM_NAME}" >/dev/null 2>&1; then

    echo "Удаление ${VM_NAME}"

    yc compute instance delete \
      --name "${VM_NAME}"
  else
    echo "${VM_NAME}: уже отсутствует"
  fi
done

# ---- дополнительный диск ----
echo "==> дополнительный диск"

if yc compute disk get \
  --name "${DATA_DISK}" >/dev/null 2>&1; then

  yc compute disk delete \
    --name "${DATA_DISK}"
else
  echo "${DATA_DISK}: уже отсутствует"
fi

# ---- подсети ----
echo "==> подсети"

for SUBNET in "${SUBNET_A}" "${SUBNET_B}"; do
  if yc vpc subnet get \
    --name "${SUBNET}" >/dev/null 2>&1; then

    yc vpc subnet delete \
      --name "${SUBNET}"
  else
    echo "${SUBNET}: уже отсутствует"
  fi
done

# ---- сеть ----
echo "==> сеть"

if yc vpc network get \
  --name "${NETWORK_NAME}" >/dev/null 2>&1; then

  yc vpc network delete \
    --name "${NETWORK_NAME}"
else
  echo "${NETWORK_NAME}: уже отсутствует"
fi

echo "=== Стенд ${PREFIX} удалён ==="
