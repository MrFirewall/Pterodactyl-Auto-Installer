#!/usr/bin/env bash
# Modern Pterodactyl Auto-Installer (Debian 13)
# Features:
# - Interaktive Dialog-Menüs (dialog)
# - Farbige Status- & Fehlerausgaben
# - Eingabevalidierung (Domain, Email, Passwörter)
# - Externes Logfile (/var/log/pteroinstall.log)
# - Modularer Aufbau (Panel, Wings, All-in-one)
# - Auto-Update (Vergleich mit GitHub raw URL)
# - Flags supported: --panel, --wings, --all, --yes, --no-update

set -o pipefail

### CONFIG
LOGFILE="/var/log/pteroinstall.log"
GITHUB_RAW_URL="https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/main/install_pterodactyl.sh"
SELF_NAME="$(basename "$0")"
TMP_SELF="/tmp/${SELF_NAME}.new"
INSTALL_START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Colors
CYAN="\e[36m"; GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; BOLD="\e[1m"; RESET="\e[0m"
OK="${GREEN}[✔]${RESET}"; ERR="${RED}[✘]${RESET}"; INFO="${CYAN}[➜]${RESET}"; WARN="${YELLOW}[!]${RESET}"

# Defaults
AUTO_YES=false
NO_SELF_UPDATE=false
DEBIAN_CODENAME="$(lsb_release -cs 2>/dev/null || echo bookworm)"

# Install flags
INSTALL_PANEL=false
INSTALL_WINGS=false

# Panel vars
PANEL_DOMAIN=""
DB_PASSWORD=""
ADMIN_EMAIL=""
ADMIN_USERNAME=""
ADMIN_FIRST=""
ADMIN_LAST=""
ADMIN_PASS=""
APP_TIMEZONE="Europe/Berlin"

# Ensure logfile exists
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
chmod 600 "$LOGFILE"

### LOGGING
log()     { echo -e "$(date -Iseconds) [$1] ${*:2}" >>"$LOGFILE"; }
cecho()   { echo -e "$*"; }
info()    { cecho "${INFO} $*"; log "INFO" "$*"; }
ok()      { cecho "${OK} $*"; log "OK" "$*"; }
warn()    { cecho "${WARN} $*"; log "WARN" "$*"; }
error()   { cecho "${ERR} $*"; log "ERROR" "$*"; }

### TRAP EXIT
on_exit() {
    local rc=$?
    if [ $rc -ne 0 ]; then
        error "Installer beendet mit Fehlercode $rc. Prüfe $LOGFILE."
    else
        ok "Installer beendet (Exit code 0)."
    fi
}
trap on_exit EXIT

### BASIC CHECKS
if [ "$(id -u)" -ne 0 ]; then
    error "Dieses Skript muss als root ausgeführt werden."
    exit 1
fi

### PARSE ARGS
while [ $# -gt 0 ]; do
    case "$1" in
        --panel) INSTALL_PANEL=true; shift ;;
        --wings) INSTALL_WINGS=true; shift ;;
        --all) INSTALL_PANEL=true; INSTALL_WINGS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        --no-update) NO_SELF_UPDATE=true; shift ;;
        --help|-h) echo "Usage: $0 [--panel] [--wings] [--all] [--yes] [--no-update]"; exit 0 ;;
        *) shift ;;
    esac
done

### UTILS
ensure_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        info "Dialog nicht gefunden — installiere dialog..."
        apt-get update -y >>"$LOGFILE" 2>&1
        apt-get install -y dialog >>"$LOGFILE" 2>&1 || { error "Konnte dialog nicht installieren."; exit 1; }
    fi
}

valid_domain()   { [[ "$1" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]{0,62}\.)+[a-zA-Z]{2,}$ ]]; }
valid_email()    { [[ "$1" =~ ^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$ ]]; }
valid_password() { [[ ${#1} -ge 8 && "$1" =~ [A-Z] && "$1" =~ [a-z] && "$1" =~ [0-9] ]]; }

spinner_start() {
    local msg="$1"; printf "%s " "$msg"
    ( while true; do for s in '/-\|'; do printf "\b%s" "$s"; sleep 0.12; done; done ) &
    SPINNER_PID=$!; disown
}
spinner_stop() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" >/dev/null 2>&1 || true
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\b ✓\n"
        unset SPINNER_PID
    fi
}

run_logged() {
    log "CMD" "$*"
    eval "$*" >>"$LOGFILE" 2>&1
    local rc=$?; [ $rc -ne 0 ] && error "Befehl fehlgeschlagen: $* (rc=$rc)"; return $rc
}

### SELF UPDATE
self_update_prompt() {
    [ "$NO_SELF_UPDATE" = true ] && return
    [ "$AUTO_YES" = true ] && return

    info "Prüfe auf neue Installer-Version..."
    if ! curl -fsSL -o "$TMP_SELF" "$GITHUB_RAW_URL"; then
        warn "Konnte neue Version nicht laden."; rm -f "$TMP_SELF"; return
    fi
    chmod +x "$TMP_SELF"
    oldsum="$(sha256sum "$0" | awk '{print $1}')"
    newsum="$(sha256sum "$TMP_SELF" | awk '{print $1}')"
    if [ "$oldsum" != "$newsum" ]; then
        dialog --title "Installer Update verfügbar" --yesno \
            "Eine neue Version ist verfügbar. Update jetzt?" 10 60
        if [ $? -eq 0 ]; then
            info "Aktualisiere Installer..."
            mv "$TMP_SELF" "$0" && chmod +x "$0"
            exec "$0" "$@"
        else
            warn "Benutzer hat Update abgelehnt."; rm -f "$TMP_SELF"
        fi
    else
        info "Keine neuere Version gefunden."; rm -f "$TMP_SELF"
    fi
}

### COMMON INSTALL MODULE
install_common_dependencies() {
    info "System aktualisieren..."
    spinner_start "apt update && apt upgrade"
    run_logged "apt-get update -y"
    run_logged "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
    spinner_stop
    run_logged "apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https unzip tar git pwgen software-properties-common"
}

install_php_and_redis_repo() {
    info "Füge PHP 8.3 und Redis Repositories hinzu..."
    [ ! -f /etc/apt/sources.list.d/sury-php.list ] && echo "deb https://packages.sury.org/php/ ${DEBIAN_CODENAME} main" > /etc/apt/sources.list.d/sury-php.list
    [ ! -f /etc/apt/sources.list.d/redis.list ] && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${DEBIAN_CODENAME} main" > /etc/apt/sources.list.d/redis.list
    run_logged "apt-get update -y"
}

### PANEL MODULES
install_panel_dependencies() {
    info "Installiere Panel-Abhängigkeiten..."
    run_logged "apt-get install -y php8.3 php8.3-fpm php8.3-cli php8.3-mbstring php8.3-xml php8.3-mysql php8.3-zip php8.3-curl php8.3-bcmath php8.3-gd php8.3-intl mariadb-server nginx redis-server"
    [ ! -x "$(command -v composer)" ] && run_logged "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
}

install_mariadb_setup() {
    info "Konfiguriere MariaDB für Panel..."
    cat > /tmp/panel_db_setup.sql <<EOF
CREATE DATABASE IF NOT EXISTS panel;
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
    run_logged "mysql < /tmp/panel_db_setup.sql" || error "MariaDB Setup fehlgeschlagen"
    rm -f /tmp/panel_db_setup.sql
}

install_panel_files() {
    info "Installiere Pterodactyl Panel Dateien..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || return 1

    spinner_start "Download Panel"
    run_logged "curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    run_logged "tar -xzf panel.tar.gz --strip-components=0"
    run_logged "rm -f panel.tar.gz"
    spinner_stop

    run_logged "cp .env.example .env"
    run_logged "chown -R www-data:www-data /var/www/pterodactyl"
    run_logged "chmod -R 755 storage bootstrap/cache || true"

    spinner_start "Composer install"
    run_logged "cd /var/www/pterodactyl && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
    spinner_stop

    run_logged "cd /var/www/pterodactyl && php artisan key:generate --force"
    run_logged "cd /var/www/pterodactyl && php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password='${DB_PASSWORD}' || true"
    run_logged "cd /var/www/pterodactyl && php artisan p:environment:setup --url=\"https://${PANEL_DOMAIN}\" --timezone=\"${APP_TIMEZONE}\" --cache=redis --session=redis --queue=redis || true"

    spinner_start "Datenbank migrieren & seed"
    run_logged "cd /var/www/pterodactyl && php artisan migrate --seed --force"
    spinner_stop

    run_logged "cd /var/www/pterodactyl && php artisan p:user:make --email='${ADMIN_EMAIL}' --username='${ADMIN_USERNAME}' --name-first='${ADMIN_FIRST}' --name-last='${ADMIN_LAST}' --password='${ADMIN_PASS}' --admin=1 || true"
}

install_nginx_site() {
    info "Erstelle Nginx Site für ${PANEL_DOMAIN}..."
    cat > /etc/nginx/sites-available/pterodactyl.conf <<'EOF'
server {
    listen 80;
    server_name __PANEL_DOMAIN__;
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        include /etc/nginx/fastcgi_params;
    }
    location ~ /\.ht { deny all; }
}
EOF
    sed -i "s|__PANEL_DOMAIN__|${PANEL_DOMAIN}|g" /etc/nginx/sites-available/pterodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    run_logged "systemctl restart nginx || true"
}

install_queue_worker() {
    info "Erstelle pteroq systemd Service..."
    cat > /etc/systemd/system/pteroq.service <<'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
    run_logged "systemctl enable --now pteroq.service"
}

### WINGS MODULES
install_docker() {
    info "Installiere Docker CE..."
    spinner_start "Docker Install"
    run_logged "curl -fsSL https://get.docker.com | CHANNEL=stable bash"
    run_logged "systemctl enable --now docker"
    spinner_stop
}

install_wings_binary() {
    info "Installiere Wings..."
    mkdir -p /etc/pterodactyl
    arch="$(uname -m)"
    [ "$arch" = "x86_64" ] && arch="amd64" || arch="arm64"
    run_logged "curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${arch}"
    run_logged "chmod +x /usr/local/bin/wings"

    cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
    warn "Wings Service erstellt, config muss in /etc/pterodactyl/config.yml gelegt werden und 'systemctl enable --now wings' manuell ausgeführt werden."
}

suggest_firewall() {
    warn "Firewall Hinweis: Öffnen Sie Ports:"
    echo " - 80/443 TCP (Panel)"
    echo " - 8080 TCP (Wings <-> Panel)"
    echo " - 2022 TCP (SFTP Wings)"
}

### MAIN
info "Installation gestartet: ${INSTALL_START_TS}"
ensure_dialog
self_update_prompt
install_common_dependencies
install_php_and_redis_repo

# Interactive selection if not passed via flags
if ! $INSTALL_PANEL && ! $INSTALL_WINGS; then
    CHOICE=$(dialog --clear --stdout --menu "Was möchten Sie installieren?" 15 60 4 \
        1 "Pterodactyl Panel" 2 "Pterodactyl Wings" 3 "Beides" 4 "Abbrechen")
    case "$CHOICE" in
        1) INSTALL_PANEL=true ;;
        2) INSTALL_WINGS=true ;;
        3) INSTALL_PANEL=true; INSTALL_WINGS=true ;;
        *) clear; exit 0 ;;
    esac
fi

# Panel form input
if $INSTALL_PANEL; then
    FORM=$(dialog --stdout --title "Panel Setup" --form "Panel-Einstellungen:" 18 70 12 \
        "Domain:" 1 1 "$PANEL_DOMAIN" 1 28 40 0 \
        "DB Passwort:" 3 1 "" 3 28 40 0 \
        "Admin Email:" 5 1 "$ADMIN_EMAIL" 5 28 40 0 \
        "Admin Username:" 7 1 "$ADMIN_USERNAME" 7 28 40 0 \
        "Admin Vorname:" 9 1 "$ADMIN_FIRST" 9 28 40 0 \
        "Admin Nachname:" 11 1 "$ADMIN_LAST" 11 28 40 0 \
        "Admin Passwort:" 13 1 "" 13 28 40 0 \
        "Timezone:" 15 1 "$APP_TIMEZONE" 15 28 40 0)
    IFS=$'\n' read -r PANEL_DOMAIN DB_PASSWORD ADMIN_EMAIL ADMIN_USERNAME ADMIN_FIRST ADMIN_LAST ADMIN_PASS APP_TIMEZONE <<<"$FORM"

    ! valid_domain "$PANEL_DOMAIN" && { dialog --msgbox "Ungültige Domain"; clear; exit 1; }
    ! valid_email "$ADMIN_EMAIL" && { dialog --msgbox "Ungültige Email"; clear; exit 1; }
    ! valid_password "$ADMIN_PASS" && { dialog --msgbox "Passwort zu schwach"; clear; exit 1; }
    [ -z "$DB_PASSWORD" ] && DB_PASSWORD="$(head -c32 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c16)" && warn "DB-Passwort generiert"
fi

# RUN INSTALLATIONS
$INSTALL_PANEL && { install_panel_dependencies; install_panel; install_nginx_site; install_queue_worker; }
$INSTALL_WINGS && { install_docker; install_wings_binary; }

# Final Summary
clear
echo -e "${GREEN}✅ Installation abgeschlossen${RESET}"
$INSTALL_PANEL && echo "Panel: https://${PANEL_DOMAIN} | Admin: ${ADMIN_USERNAME} / ${ADMIN_EMAIL}"
$INSTALL_WINGS && echo "Wings installiert. Config muss in /etc/pterodactyl/config.yml gelegt werden."
suggest_firewall
echo -e "Logs: ${LOGFILE}"
ok "Fertig."

exit 0
