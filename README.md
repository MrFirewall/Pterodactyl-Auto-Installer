# 🚀 Pterodactyl Auto-Installer für **Debian 13 (Bookworm)**

Willkommen! Dieses Skript installiert **Pterodactyl schnell, sauber, interaktiv und vollautomatisch** auf Debian 13 – inklusive **farbiger Fehlerbehandlung, Eingabevalidierung, Auto‑Update und vollständigem Logging**.

Es unterstützt:
- 🖥️ **Panel-Installation** (PHP 8.3, Redis, MariaDB, Nginx)
- 🐦 **Wings-Installation** (Docker CE + Wings-Daemon)
- 🔄 **All‑in‑One‑Setup**
- ⚙️ Interaktive Menüs mit **dialog**
- 🧪 Validierte Eingaben (Domain, E‑Mail, Passwörter)
- 📄 Logfile unter: `/var/log/pteroinstall.log`
- 🆕 Automatisches Self‑Update des Installers

---

## ⚠️ Wichtige Hinweise

1. **Nutzung auf eigene Gefahr.**  
   Das Skript verändert zentrale Systemkomponenten (Nginx, Docker, MariaDB usw.).

2. **Nur für frische Systeme empfohlen!**  
   Bereits konfigurierte Server können Probleme verursachen.

3. **Unterstützt ausschließlich Debian 13 (Bookworm).**

4. **Erfordert Root‑ oder Sudo‑Rechte.**

---

## 💻 Installation

Führe diesen Befehl als Benutzer mit Sudo-Rechten aus:

```bash
curl -sL https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/9a27d90d326206d6b532874a7cb47c74a7918d15/install_pterodactyl.sh | sudo bash
```

Das Skript startet anschließend automatisch, führt Updates durch und prüft optional, ob eine neuere Version des Installers verfügbar ist.

---

## ✨ Installationsoptionen
Beim Start kannst du auswählen:

### **1️⃣ Pterodactyl Panel installieren**
- Installiert: **PHP 8.3**, **Nginx**, **MariaDB**, **Redis**, **Composer**
- Automatische Einrichtung von:
  - Datenbank & Benutzer
  - `.env`‑Konfiguration
  - Admin‑Benutzer
  - Queue‑Worker (systemd)

### **2️⃣ Pterodactyl Wings installieren**
- Installiert: **Docker CE** + **Wings Daemon**
- Wings wird bereitgestellt, aber **nicht automatisch gestartet**, bis eine gültige `config.yml` eingetragen wurde.

### **3️⃣ Beide Komponenten installieren**
Perfekt für kleine Projekte, Testsysteme oder All‑in‑One‑Setups.

---

## 🛠️ Nach der Installation

### 🔧 Wings mit dem Panel verbinden
Wings wird erst gestartet, nachdem die Konfiguration aus dem Panel eingetragen wurde.

1. Öffne dein Panel.
2. Navigiere zu **Nodes/Knoten** → Neue Konfiguration erzeugen.
3. Kopiere die generierte `config.yml`.
4. Erstelle die Datei:
   ```bash
   nano /etc/pterodactyl/config.yml
   ```
5. Speichere die Konfiguration.
6. Öffne folgende Ports:
   - **8080/TCP** – Kommunikation Panel ↔ Wings
   - **2022/TCP** – SFTP für Benutzer
7. Starte Wings:
   ```bash
   systemctl enable --now wings
   ```

### 🌐 Zuweisungen (Allocations)
Damit Gameserver Ports nutzen können, musst du im Panel **IP‑ und Port‑Zuweisungen** einrichten.

---

## 📦 Installierte Komponenten

| Komponente         | Version              | Beschreibung                                       |
|-------------------|----------------------|----------------------------------------------------|
| **Betriebssystem** | Debian 13            | Offiziell unterstützte Umgebung                    |
| **Nginx**          | aktuell              | Webserver für das Panel                            |
| **MariaDB**        | aktuell              | Panel‑Datenbank                                    |
| **PHP**            | 8.3                  | Moderne PHP‑Version inkl. aller benötigten Module  |
| **Redis**          | aktuell              | Cache + Queue System                                |
| **Docker CE**      | aktuell              | Container‑Runtime für Wings                         |
| **Wings**          | aktuell              | Pterodactyl Daemon zur Game‑Serververwaltung       |

---

## 🧩 Erweiterte Features dieses Installers

### ✔️ Farbige Fehler- & Statusausgaben
Alle Aktionen werden übersichtlich im Terminal dargestellt.

### ✔️ Eingabevalidierung
- Domain → FQDN‑Prüfung
- E‑Mail → RegEx‑Validierung
- Passwort → Mindestlänge + Komplexität

### ✔️ Externes Logfile
Komplette Ausgabe unter:
```
/var/log/pteroinstall.log
```

### ✔️ Auto‑Update
Der Installer prüft beim Start automatisch, ob eine neue Version vorliegt.
Wenn ja, wirst du gefragt, ob du aktualisieren möchtest.

---

## 🎉 Viel Erfolg mit deinem Pterodactyl‑Setup!

Feedback, Wünsche oder Verbesserungen?  
Erstelle gerne ein Issue oder einen Pull‑Request im GitHub‑Repository!
