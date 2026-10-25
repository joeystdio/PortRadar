<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="PortRadar Icon">
</p>

<h1 align="center">PortRadar</h1>

<p align="center">
  <strong>Menu bar localhost & dev port manager for macOS — 100% free, open-source, native Swift.</strong>
</p>

<p align="center">
  <a href="https://github.com/joeystdio/PortRadar/releases/latest/download/PortRadar.dmg">
    <img src="https://img.shields.io/badge/Download-PortRadar.dmg-00B4D8?style=for-the-badge&logo=apple" alt="Download PortRadar.dmg">
  </a>
  <a href="https://github.com/joeystdio/PortRadar/releases/latest">
    <img src="https://img.shields.io/github/v/release/joeystdio/PortRadar?style=for-the-badge&color=blue" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B%20(Universal)-success?style=for-the-badge&logo=apple" alt="macOS 14+ Universal">
  <a href="https://buymeacoffee.com/joeystdio">
    <img src="https://img.shields.io/badge/☕_Buy_Me_a_Coffee-joeystdio-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee">
  </a>
</p>

---

## ✨ Features

- **📡 Live Dev Port Radar**: Instantly see every listening TCP port on your Mac (`:3000`, `:5173`, `:8080`, `:5000`, `:5432`, `:6379`) right from your menu bar, with a live active dev-server counter badge.
- **⚡ 1-Click Kill (`SIGTERM` / `SIGKILL -9`)**: Never type `lsof -i :3000` or `kill -9` again when you hit `EADDRINUSE: address already in use`. Kill any stuck port in a single click.
- **🧠 Smart Framework & Stack Detection**: Automatically tags **Next.js**, **Vite**, **Angular**, **Node.js**, **Bun**, **.NET / Kestrel**, **FastAPI / Python**, **Go**, **Rust**, **Docker / OrbStack**, **PostgreSQL**, **Redis**, **MySQL**, **MongoDB**, and **Ollama** — along with live **RAM (MB)**, **CPU %**, and **PID** badges.
- **📌 Pinned Watchlist Bar**: Pin your favorite ports (`:3000`, `:5173`, `:8080`, `:5000`, `:5432`, `:6379`) to the top watchlist bar with live green/grey status indicators and instant 1-click Open or Kill actions.
- **🌐 1-Click Open & Copy**: Open `http://localhost:PORT` directly in your browser or copy the URL to your clipboard.
- **⌨️ Global Shortcut (`⌃⌘P`)**: Summon PortRadar from anywhere in macOS with **`⌃⌘P`**.

---

## 📦 Installation

### Option 1: Homebrew (Recommended)
```bash
brew tap joeystdio/tap
brew install --cask portradar
```

### Option 2: Direct Download (`.dmg`)
1. Download [**`PortRadar.dmg`**](https://github.com/joeystdio/PortRadar/releases/latest/download/PortRadar.dmg) from the [latest release](https://github.com/joeystdio/PortRadar/releases/latest).
2. Open `PortRadar.dmg` and drag **PortRadar.app** into your **Applications** folder.

> **Note for First Launch**:
> If macOS Gatekeeper shows a warning on first launch, right-click `PortRadar.app` → **Open**, or run:
> ```bash
> xattr -cr /Applications/PortRadar.app
> ```

---

## 🛠️ Building from Source

Requires macOS 14.0+ and Swift 5.10+ / Xcode 15+:

```bash
git clone https://github.com/joeystdio/PortRadar.git
cd PortRadar
./release_dmg.sh
```

---

## ☕ Support & Buy Me a Coffee

PortRadar is 100% free and open-source. If it saves you time debugging stuck ports, consider buying me a coffee!

<p align="left">
  <a href="https://buymeacoffee.com/joeystdio">
    <img src="https://img.shields.io/badge/☕_Buy_Me_a_Coffee-buymeacoffee.com%2Fjoeystdio-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee">
  </a>
  <a href="https://paypal.me/joeystdio">
    <img src="https://img.shields.io/badge/💳_PayPal-paypal.me%2Fjoeystdio-00457C?style=for-the-badge&logo=paypal&logoColor=white" alt="Support via PayPal">
  </a>
</p>

---

## 📄 License

MIT License — completely free and open source forever.
