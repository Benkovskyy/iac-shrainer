#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-shrainer-06}"
NAME_PREFIX="${PREFIX}-"

echo "=== Удаление ресурсов с префиксом ${PREFIX} ==="

echo "==> балансировщики"
mapfile -t LB_IDS < <(
  yc load-balancer network-load-balancer list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#LB_IDS[@]} == 0 )); then
  echo "Балансировщики отсутствуют."
else
  for ID in "${LB_IDS[@]}"; do
    echo "Удаляю балансировщик ${ID}..."
    if ! yc load-balancer network-load-balancer delete --id "$ID"; then
      echo "Не удалось удалить балансировщик ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "==> целевые группы"
mapfile -t TG_IDS < <(
  yc load-balancer target-group list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#TG_IDS[@]} == 0 )); then
  echo "Целевые группы отсутствуют."
else
  for ID in "${TG_IDS[@]}"; do
    echo "Удаляю целевую группу ${ID}..."
    if ! yc load-balancer target-group delete --id "$ID"; then
      echo "Не удалось удалить целевую группу ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "==> виртуальные машины"
mapfile -t VM_IDS < <(
  yc compute instance list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#VM_IDS[@]} == 0 )); then
  echo "Виртуальные машины отсутствуют."
else
  for ID in "${VM_IDS[@]}"; do
    echo "Удаляю ВМ ${ID}..."
    if ! yc compute instance delete --id "$ID"; then
      echo "Не удалось удалить ВМ ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "==> дополнительные диски"
mapfile -t DISK_IDS < <(
  yc compute disk list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#DISK_IDS[@]} == 0 )); then
  echo "Дополнительные диски отсутствуют."
else
  for ID in "${DISK_IDS[@]}"; do
    echo "Удаляю диск ${ID}..."
    if ! yc compute disk delete --id "$ID"; then
      echo "Не удалось удалить диск ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "==> подсети"
mapfile -t SUBNET_IDS < <(
  yc vpc subnet list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#SUBNET_IDS[@]} == 0 )); then
  echo "Подсети отсутствуют."
else
  for ID in "${SUBNET_IDS[@]}"; do
    echo "Удаляю подсеть ${ID}..."
    if ! yc vpc subnet delete --id "$ID"; then
      echo "Не удалось удалить подсеть ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "==> сети"
mapfile -t NETWORK_IDS < <(
  yc vpc network list --format json |
    jq -r --arg p "$NAME_PREFIX" \
      '.[] | select((.name // "") | startswith($p)) | .id'
)

if (( ${#NETWORK_IDS[@]} == 0 )); then
  echo "Сети отсутствуют."
else
  for ID in "${NETWORK_IDS[@]}"; do
    echo "Удаляю сеть ${ID}..."
    if ! yc vpc network delete --id "$ID"; then
      echo "Не удалось удалить сеть ${ID}, продолжаю уборку." >&2
    fi
  done
fi

echo "=== Уборка завершена ==="

echo "=== Оставшиеся ВМ с префиксом ${PREFIX} ==="
yc compute instance list --format json |
  jq -r --arg p "$NAME_PREFIX" \
    '.[] | select((.name // "") | startswith($p)) | [.id, .name] | @tsv'

echo "=== Оставшиеся диски с префиксом ${PREFIX} ==="
yc compute disk list --format json |
  jq -r --arg p "$NAME_PREFIX" \
    '.[] | select((.name // "") | startswith($p)) | [.id, .name] | @tsv'

echo "=== Оставшиеся сети с префиксом ${PREFIX} ==="
yc vpc network list --format json |
  jq -r --arg p "$NAME_PREFIX" \
    '.[] | select((.name // "") | startswith($p)) | [.id, .name] | @tsv'
