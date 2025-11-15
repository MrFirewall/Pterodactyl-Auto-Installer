#!/usr/bin/env bash
# Pterodactyl Panel & Wings Installationsskript für Debian 13
# REINES BASH (Ohne 'dialog') - Robust und mit Fehlerbehebung für Repositories

set -o pipefail

### CONFIG
LOGFILE="/var/log/pteroinstall.log"
INSTALL_START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DEBIAN_CODENAME="trixie" # Debian 13

# Colors
CYAN="\e[36m"; GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; RESET="\e[0m"
OK="${GREEN}[✔]${RESET}"; ERR="${RED}[✘]${RESET}"; INFO="${CYAN}[➜]${RESET}"; WARN="${YELLOW}[!]${RESET}"

# Install flags
INSTALL_PANEL=false
INSTALL_WINGS=false

# Panel vars (Platzhalter für Eingabe)
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

### LOGGING & UTILS
log()     { echo -e "$(date -Iseconds) [$1] ${*:2}" >>"$LOGFILE"; }
cecho()   { echo -e "$*"; }
info()    { cecho "${INFO} $*"; log "INFO" "$*"; }
error()   { cecho "${ERR} $*"; log "ERROR" "$*"; }
warn()    { cecho "${WARN} $*"; log "WARN" "$*"; }

run_logged() {
    log "CMD" "$*"
    # Führt den Befehl aus und leitet stdout/stderr ins Log.
    if ! eval "$* 2>>$LOGFILE 1>>$LOGFILE"; then
        local rc=$?
        error "Befehl fehlgeschlagen (RC=$rc): $*"
        # Bei kritischen Fehlern anhalten zur Diagnose
        if [[ "$1" == *"apt-get install"* || "$1" == *"apt-get update"* ]]; then
             cecho "\n${RED}!!! WICHTIGER FEHLER BEI PAKETINSTALLATION/UPDATE. PRÜFEN SIE $LOGFILE !!!${RESET}"
             read -r -p "Drücken Sie Enter, um fortzufahren (oder STRG+C zum Abbrechen)..."
             return $rc
        fi
        return $rc
    fi
    return 0
}

### TRAP EXIT
on_exit() {
    local rc=$?
    if [ $rc -ne 0 ]; then
        error "Installer beendet mit Fehlercode $rc. Prüfe $LOGFILE."
    else
        cecho "\n${OK} Installation erfolgreich abgeschlossen."
    fi
}
trap on_exit EXIT

### INSTALLATION FUNKTIONEN START

# --- 0. INSTALLATIONSWAHL ---
show_selection() {
    cecho "\n======================================================="
    cecho "  Pterodactyl Installation (Panel & Wings) auf Debian 13"
    cecho "======================================================="

    cecho "Was möchten Sie auf dieser VM installieren?"
    cecho "1) Pterodactyl Panel (Web, DB, Redis)"
    cecho "2) Pterodactyl Wings (Docker Host)"
    cecho "3) Beides (All-in-One)"
    read -r -p "Geben Sie die Zahl der gewünschten Option ein (1-3): " CHOICE

    case "$CHOICE" in
      1) INSTALL_PANEL=true ;;
      2) INSTALL_WINGS=true ;;
      3) INSTALL_PANEL=true; INSTALL_WINGS=true ;;
      *) error "Ungültige Auswahl. Installation abgebrochen."; exit 1 ;;
    esac
}

# --- 1. INTERAKTIVE EINGABEN SAMMELN ---
gather_panel_input() {
    cecho "\n--- Panel Konfiguration ---"
    read -r -p "FQDN (Domain für Panel, z.B. game-panel.domain.de): " PANEL_DOMAIN
    read -r -p "Passwort für den Pterodactyl-Datenbankbenutzer: " DB_PASSWORD
    cecho "\n--- Admin-Benutzer Details ---"
    read -r -p "Admin E-Mail: " ADMIN_EMAIL
    read -r -p "Admin Benutzername: " ADMIN_USERNAME
    read -r -p "Admin Vorname: " ADMIN_FIRST
    read -r -p "Admin Nachname: " ADMIN_LAST
    read -r -p "Admin Passwort (mind. 8 Zeichen, Groß/Klein, Zahl): " ADMIN_PASS
    read -r -p "Zeitzone (z.B. Europe/Berlin): " APP_TIMEZONE
    
    # Validierung
    ! [[ "$PANEL_DOMAIN" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]{0,62}\.)+[a-zA-Z]{2,}$ ]] && { error "Ungültige Domain"; exit 1; }
    ! [[ "$ADMIN_EMAIL" =~ ^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$ ]] && { error "Ungültige Email"; exit 1; }
    ! [[ ${#ADMIN_PASS} -ge 8 && "$ADMIN_PASS" =~ [A-Z] && "$ADMIN_PASS" =~ [a-z] && "$ADMIN_PASS" =~ [0-9] ]] && { error "Passwort zu schwach (mind. 8 Zeichen, Groß/Klein, Zahl)"; exit 1; }
}

### INSTALLATION MODULE START

install_common_dependencies() {
    info "System aktualisieren und Basis-Abhängigkeiten installieren..."
    run_logged "apt-get update -y"
    run_logged "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
    
    # 'gnupg' und entfernt 'software-properties-common'
    run_logged "apt-get install -y curl wget gnupg ca-certificates lsb-release apt-transport-https unzip tar git pwgen"
}

install_php_and_redis_repo() {
    info "Füge PHP 8.3 und Redis Repositories hinzu..."

    # 1. PHP Sury GPG-Schlüssel hinzufügen und Repository-Datei erstellen (Behebt GPG-Fehler)
    info "Registriere PHP Sury Repository..."
    run_logged "curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/deb.sury.org.gpg"
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org.gpg] https://packages.sury.org/php/ ${DEBIAN_CODENAME} main" | tee /etc/apt/sources.list.d/sury-php.list >>"$LOGFILE" 2>&1

    # 2. Redis GPG-Schlüssel hinzufügen und Repository-Datei erstellen (Behebt GPG-Fehler)
    info "Registriere Redis Repository..."
    run_logged "curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg"
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${DEBIAN_CODENAME} main" | tee /etc/apt/sources.list.d/redis.list >>"$LOGFILE" 2>&1
    
    # 3. apt-update erneut ausführen (Muss erfolgreich sein, damit PHP/MariaDB gefunden wird)
    info "Finaler apt update zur Validierung der Repositories..."
    run_logged "apt-get update -y"
}

install_panel_dependencies() {
    info "Installiere Panel-Abhängigkeiten (MariaDB, NGINX, PHP 8.3 Module)..."
    
    # Alle Paketinstallationen in einem Rutsch.
    PACKAGES="mariadb-server nginx redis-server php8.3 php8.3-fpm php8.3-cli php8.3-mbstring php8.3-xml php8.3-mysql php8.3-zip php8.3-curl php8.3-bcmath php8.3-gd php8.3-intl"
    run_logged "apt-get install -y $PACKAGES" || { error "Kritischer Fehler bei der Installation der Panel-Pakete."; exit 1; }
    
    # Composer
    info "Installiere Composer..."
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

    info "Lade Panel herunter und entpacke..."
    run_logged "curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    run_logged "tar -xzf panel.tar.gz --strip-components=0"
    run_logged "rm -f panel.tar.gz"

    run_logged "cp .env.example .env"
    run_logged "chown -R www-data:www-data /var/www/pterodactyl"
    run_logged "chmod -R 755 storage bootstrap/cache || true"

    info "Composer install..."
    run_logged "cd /var/www/pterodactyl && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"

    info "Generiere Schlüssel und setze Umgebungsvariablen..."
    run_logged "cd /var/www/pterodactyl && php artisan key:generate --force"
    run_logged "cd /var/www/pterodactyl && php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password='${DB_PASSWORD}' || true"
    run_logged "cd /var/www/pterodactyl && php artisan p:environment:mail --driver=mail || true"
    run_logged "cd /var/www/pterodactyl && php artisan p:environment:setup --url=\"http://${PANEL_DOMAIN}\" --timezone=\"${APP_TIMEZONE}\" --cache=redis --session=redis --queue=redis || true"

    info "Datenbank migrieren & seed..."
    run_logged "cd /var/www/pterodactyl && php artisan migrate --seed --force"

    info "Erstelle Admin-Benutzer..."
    run_logged "cd /var/www/pterodactyl && php artisan p:user:make --email='${ADMIN_EMAIL}' --username='${ADMIN_USERNAME}' --name-first='${ADMIN_FIRST}' --name-last='${ADMIN_LAST}' --password='${ADMIN_PASS}' --admin=1 || true"
}

install_nginx_site() {
    info "Erstelle Nginx Site für ${PANEL_DOMAIN} (Non-SSL Backend)..."
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
    run_logged "curl -fsSL https://get.docker.com | CHANNEL=stable bash"
    run_logged "systemctl enable --now docker"
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
    cecho "\n${YELLOW}Firewall Hinweis: Öffnen Sie Ports:${RESET}"
    cecho " - 80/443 TCP (Panel)"
    cecho " - 8080 TCP (Wings <-> Panel)"
    cecho " - 2022 TCP (SFTP Wings)"
}

### MAIN EXECUTION

info "Installation gestartet: ${INSTALL_START_TS}"
show_selection
if $INSTALL_PANEL; then
    gather_panel_input
fi

install_common_dependencies
install_php_and_redis_repo

# RUN INSTALLATIONS
if $INSTALL_PANEL; then
    install_panel_dependencies
    install_mariadb_setup
    install_panel_files
    install_nginx_site
    install_queue_worker
fi

if $INSTALL_WINGS; then
    install_docker
    install_wings_binary
fi

# Final Summary
cecho "\n======================================================="
cecho "${GREEN}✅ Installation der ausgewählten Komponenten abgeschlossen.${RESET}"

if $INSTALL_PANEL; then
  cecho "Panel: http://${PANEL_DOMAIN} | Admin: ${ADMIN_USERNAME} / ${ADMIN_EMAIL}"
fi

if $INSTALL_WINGS; then
  cecho "\n!!! WICHTIGER ABSCHLIESSENDER MANUELLER SCHRITT FÜR WINGS !!!"
  cecho "1. Konfigurations-Block vom Panel holen."
  cecho "2. Datei /etc/pterodactyl/config.yml erstellen/befüllen."
  cecho "3. Führen Sie aus: systemctl enable --now wings"
fi
suggest_firewall
cecho "Logs: ${LOGFILE}"
exit 0
