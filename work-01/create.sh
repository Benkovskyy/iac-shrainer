#!/usr/bin/env bash
set -euo pipefail

PREFIX="shrainer-06"
ZONE="ru-central1-d"
CIDR="10.16.1.0/24"
APP_PORT="8018"
GREETING="netlab"
DISK_SIZE="25"
IMAGE_FAMILY="ubuntu-2204-lts"

NETWORK_NAME="${PREFIX}-net"
SUBNET_NAME="${PREFIX}-subnet"
VM1_NAME="${PREFIX}-app-1"
VM2_NAME="${PREFIX}-app-2"

SSH_KEY="$HOME/.ssh/id_ed25519.pub"

echo "Создание сети ${NETWORK_NAME}..."
yc vpc network create \
  --name "$NETWORK_NAME"

echo "Создание подсети ${SUBNET_NAME}..."
yc vpc subnet create \
  --name "$SUBNET_NAME" \
  --network-name "$NETWORK_NAME" \
  --zone "$ZONE" \
  --range "$CIDR"

echo "Создание виртуальной машины ${VM1_NAME}..."
yc compute instance create \
  --name "$VM1_NAME" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$SUBNET_NAME",nat-ip-version=ipv4 \
  --ssh-key "$SSH_KEY" \
  --labels created-by=script

echo "Создание виртуальной машины ${VM2_NAME}..."
yc compute instance create \
  --name "$VM2_NAME" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$SUBNET_NAME",nat-ip-version=ipv4 \
  --ssh-key "$SSH_KEY" \
  --labels created-by=script

echo
echo "Созданные виртуальные машины:"
yc compute instance list

echo
echo "Параметры стенда:"
echo "PREFIX=$PREFIX"
echo "ZONE=$ZONE"
echo "CIDR=$CIDR"
echo "APP_PORT=$APP_PORT"
echo "GREETING=$GREETING"
echo "DISK_SIZE=$DISK_SIZE"
echo "IMAGE_FAMILY=$IMAGE_FAMILY"
