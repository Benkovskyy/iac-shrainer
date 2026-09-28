#!/usr/bin/env bash
set -euo pipefail

# ---- параметры варианта 06 — Шрайнер ----
PREFIX="shrainer-06"
ZONE_A="ru-central1-d"

# По варианту исходно ru-central1-a.
# Временно используется ru-central1-b из-за проблемы
# внешней доступности публичных IP в ru-central1-a.
ZONE_B="ru-central1-b"

CIDR_A="10.16.1.0/24"
CIDR_B="10.16.2.0/24"
APP_PORT="8018"
GREETING="netlab"
VM_COUNT="3"
DISK_SIZE="15"
BOOT_SIZE="25"
IMAGE_FAMILY="ubuntu-2404-lts"

NETWORK_NAME="${PREFIX}-net"
SUBNET_A="${PREFIX}-subnet-a"
SUBNET_B="${PREFIX}-subnet-b"
DATA_DISK="${PREFIX}-data"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT_TEMPLATE="${SCRIPT_DIR}/cloud-init.tpl.yaml"
CLOUD_INIT_FILE="${SCRIPT_DIR}/cloud-init.yaml"
SSH_KEY_FILE="${HOME}/.ssh/id_ed25519.pub"

echo "=== Параметры стенда ${PREFIX} ==="
echo "ZONE_A=${ZONE_A}"
echo "ZONE_B=${ZONE_B}"
echo "CIDR_A=${CIDR_A}"
echo "CIDR_B=${CIDR_B}"
echo "APP_PORT=${APP_PORT}"
echo "GREETING=${GREETING}"
echo "VM_COUNT=${VM_COUNT}"
echo "BOOT_SIZE=${BOOT_SIZE}"
echo "DISK_SIZE=${DISK_SIZE}"

# ---- генерация cloud-init из шаблона ----
SSH_KEY="$(cat "${SSH_KEY_FILE}")"

sed \
  -e "s|__SSH_KEY__|${SSH_KEY}|g" \
  -e "s|__PORT__|${APP_PORT}|g" \
  -e "s|__GREETING__|${GREETING}|g" \
  "${CLOUD_INIT_TEMPLATE}" > "${CLOUD_INIT_FILE}"

echo "==> cloud-init.yaml сгенерирован"

# ---- сеть и две подсети ----
echo "==> сеть и подсети"

yc vpc network create \
  --name "${NETWORK_NAME}"

yc vpc subnet create \
  --name "${SUBNET_A}" \
  --network-name "${NETWORK_NAME}" \
  --zone "${ZONE_A}" \
  --range "${CIDR_A}"

yc vpc subnet create \
  --name "${SUBNET_B}" \
  --network-name "${NETWORK_NAME}" \
  --zone "${ZONE_B}" \
  --range "${CIDR_B}"

# ---- виртуальные машины ----
echo "==> машины"

for i in $(seq 1 "${VM_COUNT}"); do
  VM_NAME="${PREFIX}-app-${i}"

  if (( i % 2 == 1 )); then
    VM_ZONE="${ZONE_A}"
    VM_SUBNET="${SUBNET_A}"
  else
    VM_ZONE="${ZONE_B}"
    VM_SUBNET="${SUBNET_B}"
  fi

  echo "Создание ${VM_NAME} в ${VM_ZONE}"

  yc compute instance create \
    --name "${VM_NAME}" \
    --zone "${VM_ZONE}" \
    --platform standard-v3 \
    --cores=2 \
    --core-fraction=20 \
    --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="${IMAGE_FAMILY}",type=network-hdd,size="${BOOT_SIZE}" \
    --network-interface subnet-name="${VM_SUBNET}",nat-ip-version=ipv4 \
    --hostname "${VM_NAME}" \
    --metadata-from-file user-data="${CLOUD_INIT_FILE}"
done

# ---- дополнительный диск ----
echo "==> дополнительный диск"

yc compute disk create \
  --name "${DATA_DISK}" \
  --zone "${ZONE_A}" \
  --type network-hdd \
  --size "${DISK_SIZE}"

yc compute instance attach-disk "${PREFIX}-app-1" \
  --disk-name "${DATA_DISK}" \
  --device-name data \
  --auto-delete=false

echo "=== Стенд ${PREFIX} создан ==="

yc compute instance list
yc compute disk list


# ---- целевая группа ----
echo "==> целевая группа"

SUBNETS=("${SUBNET_A}" "${SUBNET_B}")
TARGETS=""

for i in $(seq 1 "${VM_COUNT}"); do
  idx=$(( (i - 1) % 2 ))

  IP=$(yc compute instance get "${PREFIX}-app-${i}" \
    --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.address')

  TARGETS="${TARGETS} --target subnet-name=${SUBNETS[$idx]},address=${IP}"
done

yc load-balancer target-group create \
  --name "${PREFIX}-tg" \
  ${TARGETS}
# ---- балансировщик ----
echo "==> балансировщик"

TG_ID=$(yc load-balancer target-group get \
  --name "${PREFIX}-tg" \
  --format json | jq -r '.id')

yc load-balancer network-load-balancer create \
  --name "${PREFIX}-lb" \
  --region-id ru-central1 \
  --listener name=http,port=80,target-port="${APP_PORT}",external-ip-version=ipv4 \
  --target-group target-group-id="${TG_ID}",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="${APP_PORT}",healthcheck-http-path=/
