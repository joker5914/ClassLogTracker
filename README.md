# ClassLogTracker 📊

**ClassLogTracker** is a powerful TurtleWoW addon that provides a clean, UI-based way to inspect and filter combat log activity by class during party and raid encounters.

---

## 🧩 Features

- 🎯 **Filter combat logs by class** with a single click
- 🎨 **Class-colored buttons** for Warrior, Mage, Paladin, etc.
- 🔁 Toggle between **Party** or **Raid** log sources
- 🧾 Scrollable, real-time log output for deeper visibility
- 🖱️ Movable and closable UI window
- 🧵 Designed for TurtleWoW (1.12.1) client

---

## 🚀 Installation

### Option 1: TurtleWoW GitHub Installer

1. Open the **TurtleWoW Launcher**
2. Go to the **AddOns** tab
3. Click **“Install from GitHub”**
4. Paste this repo URL:

   ```
   https://github.com/yourname/ClassLogTracker
   ```

5. Launch the game and enable `ClassLogTracker` in your AddOns menu

---

## 🕹️ Usage

### Open the Interface:
```lua
/classlog
```

### Interface Overview:
- 📍Top-left: **Filter toggle** (switches between party and raid logs)
- 🎨 Grid of buttons: **One per class** (colored by class)
- 📜 Main log view: Shows log lines related to the selected class

### Example Workflow:
1. Type `/classlog` to open the window
2. Click "Paladin" to filter logs by paladins in your group
3. Use the "Filter: party/raid" toggle to switch between party or raid events
4. Scroll through logs to analyze their actions during combat

---

## 🧱 Planned Features

- [ ] Sound/visual alerts on key events (e.g., interrupts, deaths)
- [ ] Timestamp display
- [ ] Save logs to disk
- [ ] Right-click class button for further filtering (e.g., healing-only)

---

## 🎨 Addon Display Name

In your AddOns menu, the name will appear as:

```lua
|cffe5b3e5ClassLogTracker|r
```

(Subtle pink for classy vibes)

---

## ⚖️ License

MIT — use, tweak, ship, or meme freely.

---

💬 Built to make raid review suck less.
