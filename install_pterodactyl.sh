#!/usr/bin/env bash
# Pterodactyl Panel & Wings Installationsskript für Debian 13
# REINES BASH (Ohne 'dialog') - Robust, CLI-Flag & Fehlerbehebung für Repositories

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
    if ! eval "$* 2>>$LOGFILE 1>>$LOGFILE"; then
        local rc=$?
        error "Befehl fehlgeschlagen (RC=$rc): $*"
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

### CLI FLAG PARSING
for arg in "$@"; do
    case "$arg" in
        --panel) INSTALL_PANEL=true ;;
        --wings) INSTALL_WINGS=true ;;
        --all)   INSTALL_PANEL=true; INSTALL_WINGS=true ;;
        --domain=*) PANEL_DOMAIN="${arg#*=}" ;;
        --db-pass=*) DB_PASSWORD="${arg#*=}" ;;
        --email=*) ADMIN_EMAIL="${arg#*=}" ;;
        --user=*) ADMIN_USERNAME="${arg#*=}" ;;
        --first=*) ADMIN_FIRST="${arg#*=}" ;;
        --last=*) ADMIN_LAST="${arg#*=}" ;;
        --admin-pass=*) ADMIN_PASS="${arg#*=}" ;;
        --tz=*) APP_TIMEZONE="${arg#*=}" ;;
    esac
done

### INSTALLATION FUNKTIONEN START

show_selection() {
    if $INSTALL_PANEL || $INSTALL_WINGS; then
        info "Installationswahl über CLI-Flag erkannt: Panel=${INSTALL_PANEL}, Wings=${INSTALL_WINGS}"
        return
    fi

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
    # Wenn CLI alle notwendigen Variablen gesetzt hat, überspringe Eingabe
    if [[ -n "$PANEL_DOMAIN" && -n "$DB_PASSWORD" && -n "$ADMIN_EMAIL" && -n "$ADMIN_USERNAME" && -n "$ADMIN_FIRST" && -n "$ADMIN_LAST" && -n "$ADMIN_PASS" ]]; then
        info "Panel-Konfiguration über CLI-Flags erkannt. Interaktive Eingabe übersprungen."
        return
    fi

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

# --- (Rest des Skripts bleibt unverändert, Module: install_common_dependencies, install_php_and_redis_repo, install_panel_dependencies, install_mariadb_setup, install_panel_files, install_nginx_site, install_queue_worker, install_docker, install_wings_binary, suggest_firewall, MAIN EXECUTION) ---

info "Installation gestartet: ${INSTALL_START_TS}"
show_selection
if $INSTALL_PANEL; then
    gather_panel_input
fi

install_common_dependencies
install_php_and_redis_repo

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
