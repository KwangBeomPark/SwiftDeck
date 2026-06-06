*Read this in other languages: [English](README.md), [한국어](README.ko.md)*

# ⚡ SwiftDeck: FinOps & Office Workflow Automation Suite
A portable productivity command center for finance managers and business professionals, built with AutoHotkey v2.

<p align="center">
  <img src="./Demo.gif" width="900" alt="SwiftDeck Demo">
</p>

---

## What SwiftDeck Does

**SwiftDeck** helps office professionals reduce repetitive work by combining folder shortcuts, text automation, prompt execution, hotstrings, and key remapping into one lightweight Windows tray application.

It is designed especially for finance, sales administration, accounting, credit control, and other back-office teams that repeatedly work with ERP systems, monthly closing folders, shared drives, standard emails, and routine operational text.

> **Accelerate Team Month-End Closings · Prevent Human Errors · Reduce Repetitive Tasks · Standardize Workflows**

---

## Core Features

- **📂 1-Click Folder Navigation**: Open frequently used folders, ERP download paths, monthly evidence folders, and shared network drives from a hotkey menu.
- **⌨️ Prompt & SQL Text Automation**: Run long text blocks, SQL queries, AI prompts, or control-key sequences such as Enter, Tab, and Wait.
- **✏️ Hotstrings**: Expand short abbreviations into full email templates, reporting phrases, symbols, or standard messages.
- **🔀 Key Remapping**: Remap rarely used keys such as CapsLock into practical shortcuts, mouse clicks, or workflow-specific actions.
- **⚙️ Portable Team Deployment**: Share local `.ini` settings files to standardize folder paths, prompts, and templates across a team.

---

## 🚀 Download & Quick Start

**SwiftDeck** is a **portable application**. It runs by double-clicking the executable and does not require a complex installation process.

### 📥 For General Users (1-Click Portable Download)

1. Go to the **[Releases](https://github.com/KwangBeomPark/SwiftDeck/releases)** tab on the right side of the GitHub repository.
2. Download the latest **`SwiftDeck.zip`** or standalone **`SwiftDeck.exe`** file.
3. Unzip the file if needed, then double-click **`SwiftDeck.exe`**.
4. A black lightning bolt icon will appear in the Windows system tray, and SwiftDeck is ready to use.

If no release file is available yet, please build or run the source using AutoHotkey v2.

### 🛠️ For Power Users & Developers (Custom Build)

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Clone this repository.
3. Customize `SwiftDeck.ahk` as needed.
4. Use the Ahk2Exe tool included with AutoHotkey to package your own `SwiftDeck.exe`.

---

## 💼 Practical FinOps & Business Use Cases

- **Month-end closing folder access**: Press `F1` to open a menu of monthly closing folders, ERP downloads, evidence files, and shared drives.
- **SQL / AI prompt execution**: Press a registered shortcut to type a long SQL query or frequently used AI prompt automatically.
- **Standard email templates**: Type a short hotstring such as `;t1` to expand it into a full report, request, or daily cash update message.
- **Fatigue reduction**: Remap repetitive keyboard or mouse operations to reduce wrist strain during long Excel, ERP, or copy-paste work.
- **Team standardization**: A manager can prepare common prompts, folder paths, and hotstrings, then distribute the generated `.ini` settings files to team members.

---

## 📖 User Manual

✔ **Folders**: Manage and quick-jump to frequently used folder paths.  
✔ **Prompts**: Execute repetitive text strings and control-key macros such as Wait, Enter, and Tab.  
✔ **Hotstrings**: Register text abbreviations for instant auto-completion.  
✔ **Key Remap**: Map physical keys to more useful shortcuts or mouse clicks.  
✔ **General**: Toggle Windows startup behavior and manage the application theme.  
✔ After adding, editing, or deleting items in App Settings, click **Save & Apply** to save and reload the configuration.

<p align="center">
  <img src="./manual.png" width="1000" alt="SwiftDeck User Manual Screenshot">
</p>

---

## ⌨️ Essential Shortcuts & Controls

| Shortcut | Function |
|---------|----------|
| `F1` (Default) | Open the Favorite Folders menu from anywhere |
| `Win + Numpad (0~9)` | Execute registered folder or prompt slots instantly |
| `;abbreviation` e.g., `;t1` | Expand a short hotstring into long text or email templates |
| `Ctrl + Win + Space` | Open the emoji and symbol picker |
| `System Tray Menu` | Open App Settings and related management menus |

---

## ⚙️ Settings File & Team Deployment

SwiftDeck stores configuration data in local `.ini` files.

You can open the settings folder from:

```text
System Tray Menu → Open Settings Folder
```

For team deployment, one manager can configure common folder paths, prompts, and hotstrings first, then share the generated `.ini` files with colleagues. This helps standardize repeated workflows across the department without requiring each team member to configure everything manually.

---

## 🔐 Security & Privacy

- SwiftDeck runs locally on Windows.
- User data is not uploaded to an external server by SwiftDeck.
- Folder paths, prompts, hotstrings, and key remap settings are stored locally in `.ini` files.
- Avoid storing passwords, API keys, personal credentials, or highly confidential information in Prompt or Hotstring settings.
- Review shared `.ini` files before distributing them to other users.

---

## 👨‍💼 Project Background

I am **not a professional software developer, but a finance manager performing hands-on operations in a corporate finance department.**

Watching daily repetitive tasks such as complex ERP inquiries, scattered month-end folder searches, and routine emails, I started this project with a practical question: **How can we remove inefficient workflows and help the whole team focus on higher-value work?**

By analyzing real operational pain points and bottlenecks from office work, **SwiftDeck** evolved from a personal macro script into a practical office automation tool for standardizing workflows and improving team productivity.

---

## 💻 Environment & License

- **Environment**: Windows 10 / 11, AutoHotkey v2 runtime, or compiled standalone executable
- **License**: MIT License. SwiftDeck is open-source and free to modify and distribute.

---

## ☕ Support Practical Automation with a Coffee

If this tool has reduced your month-end closing hours or eased your wrist pain, your support is a great motivation for developing more practical open-source finance automation tools.

<p align="center">
  <a href="https://www.buymeacoffee.com/KBPark_Bob">
    <img
      src="./bmc_button.png"
      width="220"
      alt="Buy Me A Coffee">
  </a>
</p>
