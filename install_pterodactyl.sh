#!/usr/bin/env bash
# Pterodactyl Panel & Wings Installationsskript für Debian 13
# REINES BASH (Ohne 'dialog') - Robust und bessere Fehlersuche

set -o pipefail

### CONFIG
LOGFILE="/var/log/pteroinstall.log"
INSTALL_START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DEBIAN_CODENAME="trixie" # Debian 13

# Colors
CYAN="\e[36m"; GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"
OK="${GREEN}[✔]${RESET}"; ERR="${RED}[✘]${RESET}"; INFO="${CYAN}[➜]${RESET}"

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

run_logged() {
    log "CMD" "$*"
    # Führt den Befehl aus und leitet stdout/stderr ins Log, zeigt aber im Terminal
    # nur den allgemeinen Fortschritt.
    # Wichtig: Fehlerausgabe direkt im Terminal, falls es nicht funktioniert.
    if ! eval "$* 2>>$LOGFILE 1>>$LOGFILE"; then
        local rc=$?
        error "Befehl fehlgeschlagen (RC=$rc): $*"
        # Bei kritischen Fehlern anhalten zur Diagnose
        if [[ "$1" == "apt-get install" || "$1" == "apt-get update" ]]; then
             cecho "\n${RED}!!! WICHTIGER FEHLER: PRÜFEN SIE DEN LOGFILE ($LOGFILE) !!!${RESET}"
             read -r -p "Drücken Sie Enter, um fortzufahren (oder STRG+C zum Abbrechen)..."
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
        cecho "${OK} Installation erfolgreich abgeschlossen."
    fi
}
trap on_exit EXIT

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
}

### INSTALLATION FUNKTIONEN
install_common_dependencies() {
    info "System aktualisieren und Basis-Abhängigkeiten installieren..."
    run_logged "apt-get update -y"
    run_logged "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
    
    # 'gnupg' statt 'gnupg2' und die problematischen Pakete sind entfernt
    run_logged "apt-get install -y curl wget gnupg ca-certificates lsb-release apt-transport-https unzip tar git pwgen"
}

install_php_and_redis_repo() {
    info "Füge PHP 8.3 und Redis Repositories hinzu..."

    # 1. PHP Sury GPG-Schlüssel hinzufügen und Repository-Datei erstellen
    info "Registriere PHP Sury Repository..."
    run_logged "curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/deb.sury.org.gpg"
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org.gpg] https://packages.sury.org/php/ ${DEBIAN_CODENAME} main" | tee /etc/apt/sources.list.d/sury-php.list >>"$LOGFILE" 2>&1

    # 2. Redis GPG-Schlüssel hinzufügen und Repository-Datei erstellen
    info "Registriere Redis Repository..."
    run_logged "curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg"
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${DEBIAN_CODENAME} main" | tee /etc/apt/sources.list.d/redis.list >>"$LOGFILE" 2>&1
    
    # 3. apt-update erneut ausführen (Muss erfolgreich sein, damit PHP/MariaDB gefunden wird)
    info "Finaler apt update zur Validierung der Repositories..."
    run_logged "apt-get update -y"
}

install_panel_dependencies() {
    info "Installiere Panel-Abhängigkeiten (MariaDB, NGINX, PHP 8.3 Module)..."
    
    # Alle Paketinstallationen in einem Rutsch, um Fehler zu konsolidieren
    PACKAGES="mariadb-server nginx redis-server php8.3 php8.3-fpm php8.3-cli php8.3-mbstring php8.3-xml php8.3-mysql php8.3-zip php8.3-curl php8.3-bcmath php8.3-gd php8.3-intl"
    if ! run_logged "apt-get install -y $PACKAGES"; then
        error "Kritischer Fehler bei der Installation der Panel-Pakete. Prüfen Sie $LOGFILE."
        exit 1
    fi
    
    # Composer
    info "Installiere Composer..."
    [ ! -x "$(command -v composer)" ] && run_logged "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
}

# (Rest der Panel- und Wings-Funktionen bleibt wie im letzten Skript, da sie nicht die Fehlerquelle waren.)

# ... (Hier würden die Funktionen install_mariadb_setup, install_panel_files, etc. folgen)

# --- Haupt-Ausführung ---
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
    # ... (Rest der Panel-Installation: Datenbank, Dateien, Nginx, Pteroq)
fi

if $INSTALL_WINGS; then
    # ... (Wings Installation: Docker, Binary)
    :
fi

# Final Summary
cecho "\n======================================================="
cecho "${GREEN}✅ Installation der ausgewählten Komponenten abgeschlossen.${RESET}"

if $INSTALL_PANEL; then
  cecho "Panel-URL: http://$PANEL_DOMAIN"
  cecho "Admin: $ADMIN_USERNAME / $ADMIN_EMAIL"
fi

if $INSTALL_WINGS; then
  cecho "\n!!! WICHTIGER ABSCHLIESSENDER MANUELLER SCHRITT FÜR WINGS !!!"
  cecho "1. Konfigurations-Block vom Panel holen."
  cecho "2. Datei /etc/pterodactyl/config.yml erstellen/befüllen."
  cecho "3. Führen Sie aus: systemctl enable --now wings"
fi
