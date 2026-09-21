export PREFIX=shrainer-06
export ZONE=ru-central1-d
export CIDR=10.16.1.0/24

yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"
