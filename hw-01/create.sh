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
