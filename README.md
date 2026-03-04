# Система мониторинга Prometheus + Grafana

Скрипты для быстрой установки стека мониторинга Prometheus + Grafana на Ubuntu.

Copyleft(c) by Denis Astahov | Доработка: [devcloud13](https://github.com/devcloud13)

Оригинальный репозиторий: https://github.com/adv4000/prometheus

---

## Что изменено по сравнению с оригиналом

| # | Что добавлено | Зачем |
|---|--------------|-------|
| 1 | **Автоматическое определение последней версии** через GitHub API | Скрипт сам узнаёт актуальную версию при запуске — не надо следить за релизами вручную. Если GitHub недоступен — используется fallback-версия |
| 2 | **`set -e` и `set -u`** в начале bash-скриптов | Скрипт останавливается при первой ошибке, а не продолжает установку в сломанном состоянии |
| 3 | **Проверка: уже установлено?** | Если сервис уже запущен — скрипт спрашивает "переустановить?" вместо того чтобы сломать работающую систему |
| 4 | **Цветной вывод** (зелёный/жёлтый/красный) | Сразу видно что происходит и где ошибка |
| 5 | **Проверка запуска от root** | Внятная ошибка вместо непонятного "Permission denied" в середине установки |
| 6 | **Очистка `/tmp`** после установки | Оригинал оставлял скачанные архивы на диске |
| 7 | **Итоговое сообщение** с URL и полезными командами | Сразу знаешь куда заходить и что делать дальше |
| 8 | **`uninstall.sh`** — новый файл | В оригинале нет. Нужен чтобы полностью снести всё и начать заново (особенно при обучении) |
| 9 | **Удалён Windows Exporter** из комплекта | В оригинале есть `install_prometheus_windows_exporter.ps1`, в этой версии он убран — см. раздел ниже |
| 10 | **Этот README** на русском с архитектурой и командами | В оригинале README почти пустой |

---

## Как работает автоматическое определение версии

Каждый скрипт при запуске обращается к GitHub API и получает номер последнего релиза:

```bash
# Bash (Linux)
PROMETHEUS_VERSION=$(curl -sf https://api.github.com/repos/prometheus/prometheus/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//') || PROMETHEUS_VERSION="2.51.0"
```


Если GitHub недоступен (нет интернета, Rate Limit и т.д.) — скрипт автоматически использует **fallback-версию**, прописанную в коде, и продолжает установку без ошибок.

---

## Архитектура

```
+--------------------+      метрики      +--------------------+
|   Node Exporter    | ----------------> |                    |
|   порт: 9100       |                   |    Prometheus      |
+--------------------+                   |    порт: 9090      |
                                         |                    |
                                         +--------+-----------+
                                                  |
                                                  | запросы
                                                  v
                                         +--------------------+
                                         |      Grafana       |
                                         |    порт: 3000      |
                                         +--------------------+
```

---

## Быстрый старт

### Шаг 1 — Установка Prometheus (на сервере мониторинга)

```bash
sudo bash install_prometheus_server_ubuntu.sh
```

Prometheus будет доступен по адресу: `http://<ip-сервера>:9090`

---

### Шаг 2 — Установка Node Exporter (на каждом Linux-сервере который нужно мониторить)

```bash
sudo bash install_prometheus_node_exporter.sh
```

Метрики доступны по адресу: `http://<ip-ноды>:9100/metrics`

После установки добавь сервер в `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets:
          - '192.168.1.10:9100'   # IP твоего сервера
          - '192.168.1.11:9100'   # ещё один сервер
```

Перечитать конфиг Prometheus без перезапуска:
```bash
systemctl reload prometheus
# или
curl -X POST http://localhost:9090/-/reload
```

---

### Шаг 3 — Установка Grafana (на сервере мониторинга)

```bash
sudo bash install_grafana_server_ubuntu.sh
```

Grafana будет доступна по адресу: `http://<ip-сервера>:3000`

Логин по умолчанию: `admin / admin` (смени при первом входе!)

**Настройка Grafana:**
1. Перейди в **Connections → Data sources → Add data source**
2. Выбери **Prometheus**
3. URL: `http://localhost:9090`
4. Нажми **Save & Test**
5. Перейди в **Dashboards → Import**
6. Введи ID дашборда **`1860`** (Node Exporter Full) → Load

---

## Удаление

Полностью удалить всё (Prometheus + Node Exporter + Grafana):

```bash
sudo bash uninstall.sh
```

Скрипт попросит ввести `yes` для подтверждения.

---

## Порты

| Компонент        | Порт | Протокол |
|-----------------|------|----------|
| Prometheus      | 9090 | HTTP     |
| Node Exporter   | 9100 | HTTP     |
| Grafana         | 3000 | HTTP     |

Открыть порты в Ubuntu UFW:
```bash
sudo ufw allow 9090/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 3000/tcp
```

---

## Полезные команды

```bash
# Статус сервисов
systemctl status prometheus
systemctl status node_exporter
systemctl status grafana-server

# Логи в реальном времени
journalctl -u prometheus -f
journalctl -u node_exporter -f
journalctl -u grafana-server -f

# Перечитать конфиг Prometheus (без перезапуска)
systemctl reload prometheus

# Проверить конфиг на ошибки
promtool check config /etc/prometheus/prometheus.yml
```

---

## Про Windows Exporter

В оригинальном репозитории [adv4000/prometheus](https://github.com/adv4000/prometheus) есть скрипт `install_prometheus_windows_exporter.ps1` для установки экспортёра метрик на Windows-серверах.

**В данной доработанной версии этот скрипт убран.**

Причины:
- Репозиторий сфокусирован на Linux/Ubuntu стеке
- PowerShell-скрипт требует отдельного тестирования на Windows-окружении
- Если нужен Windows Exporter — используй оригинальный скрипт из репозитория adv4000 или скачай готовый MSI-установщик напрямую с [github.com/prometheus-community/windows_exporter/releases](https://github.com/prometheus-community/windows_exporter/releases)

---

## Файлы в репозитории

| Файл | Описание |
|------|----------|
| `install_prometheus_server_ubuntu.sh` | Установка Prometheus на Ubuntu |
| `install_prometheus_node_exporter.sh` | Установка Node Exporter на Ubuntu |
| `install_grafana_server_ubuntu.sh`    | Установка Grafana на Ubuntu |
| `prometheus.yml`                      | Базовый конфиг Prometheus |
| `uninstall.sh`                        | Полное удаление всех компонентов |
