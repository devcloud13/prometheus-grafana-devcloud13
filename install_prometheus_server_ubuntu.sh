#!/bin/bash
# ==============================================================================
# Установка Prometheus Server на Ubuntu
# Copyleft(c) by Denis Astahov | Доработка: devcloud13 (https://github.com/devcloud13)
# Оригинал: https://github.com/adv4000/prometheus
# ==============================================================================

set -e  # Остановить скрипт при любой ошибке
set -u  # Ошибка если переменная не задана

# ------------------------------------------------------------------------------
# ВЕРСИЯ — автоматически получаем последнюю с GitHub
# Если GitHub недоступен — используем fallback
# ------------------------------------------------------------------------------
FALLBACK_VERSION="2.51.0"
echo -e "\033[0;32m[ИНФО]\033[0m Определяем последнюю версию Prometheus..."
PROMETHEUS_VERSION=$(curl -sf https://api.github.com/repos/prometheus/prometheus/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//') || PROMETHEUS_VERSION="$FALLBACK_VERSION"
echo -e "\033[0;32m[ИНФО]\033[0m Версия для установки: ${PROMETHEUS_VERSION}"

# ------------------------------------------------------------------------------
# Цвета для вывода
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[ИНФО]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"; }
error() { echo -e "${RED}[ОШИБКА]${NC} $1"; exit 1; }

# ------------------------------------------------------------------------------
# Проверка: уже установлен?
# ------------------------------------------------------------------------------
if systemctl is-active --quiet prometheus 2>/dev/null; then
    warn "Prometheus уже запущен!"
    warn "Текущая версия: $(prometheus --version 2>&1 | head -1)"
    read -r -p "Переустановить? (y/N): " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]] || { log "Установка отменена."; exit 0; }
    log "Останавливаем существующий Prometheus..."
    systemctl stop prometheus
fi

# ------------------------------------------------------------------------------
# Проверка что запущен от root
# ------------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || error "Запусти скрипт от root: sudo $0"

# ------------------------------------------------------------------------------
# Установка
# ------------------------------------------------------------------------------
log "Скачиваем Prometheus v${PROMETHEUS_VERSION}..."
cd /tmp
wget -q --show-progress \
    "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    -O prometheus.tar.gz

log "Распаковываем..."
tar xzf prometheus.tar.gz
cd "prometheus-${PROMETHEUS_VERSION}.linux-amd64"

log "Создаём пользователя и директории..."
id prometheus &>/dev/null || useradd --no-create-home --shell /bin/false prometheus

mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

log "Копируем бинарники..."
cp prometheus promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

log "Копируем файлы конфигурации..."
cp -r consoles console_libraries /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus/consoles /etc/prometheus/console_libraries

# Копируем конфиг только если его ещё нет (не перезаписываем пользовательский)
if [[ ! -f /etc/prometheus/prometheus.yml ]]; then
    cp prometheus.yml /etc/prometheus/prometheus.yml
    chown prometheus:prometheus /etc/prometheus/prometheus.yml
    log "Установлен базовый prometheus.yml."
else
    warn "Файл prometheus.yml уже существует — не перезаписываем. Проверь /etc/prometheus/prometheus.yml"
fi

log "Создаём systemd-сервис..."
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --storage.tsdb.retention.time=15d
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

log "Запускаем Prometheus..."
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# ------------------------------------------------------------------------------
# Очистка временных файлов
# ------------------------------------------------------------------------------
log "Удаляем временные файлы..."
cd /tmp
rm -rf prometheus.tar.gz "prometheus-${PROMETHEUS_VERSION}.linux-amd64"

# ------------------------------------------------------------------------------
# Готово
# ------------------------------------------------------------------------------
echo ""
log "========================================"
log "Prometheus v${PROMETHEUS_VERSION} установлен!"
log "Веб-интерфейс: http://$(hostname -I | awk '{print $1}'):9090"
log "Конфиг:        /etc/prometheus/prometheus.yml"
log "Данные:        /var/lib/prometheus/"
log "Статус:        systemctl status prometheus"
log "Логи:          journalctl -u prometheus -f"
log "========================================"
