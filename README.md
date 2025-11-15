# 🚀 Pterodactyl Auto-Installer für Debian 13

Ein interaktives Skript zur automatisierten Installation des **Pterodactyl Panels**, des **Wings Daemons** oder einer **All-in-One-Lösung** auf Debian 13 (Bookworm).

> **⚠️ Wichtig:** Die Ausführung erfolgt auf **eigene Gefahr**. Das Skript benötigt **Root-Rechte** (via `sudo`) und ist aktuell **ausschließlich für Debian 13** konzipiert.

---

## 💻 Installation und Ausführung

Führen Sie den folgenden Befehl als **normaler Benutzer** auf Ihrer VM aus. Das Skript fragt bei der Ausführung nach Ihrem Root-Passwort.

```bash
curl -sL [https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/9a27d90d326206d6b532874a7cb47c74a7918d15/install_pterodactyl.sh](https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/9a27d90d326206d6b532874a7cb47c74a7918d15/install_pterodactyl.sh) | sudo bash
