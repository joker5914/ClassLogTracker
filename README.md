# RaidRecon

**RaidRecon** is your spy-themed WoW addon for TurtleWoW (1.12.1) that lets you eavesdrop on combat logs by class—so you can sniff out mistakes in your party or raid.

---

## Features

-  **Class-filtered logs**: one-click buttons to view only Warrior, Priest, Mage, etc.  
-  **Color-coded** class buttons for instant recognition  
-  **Party/Raid switch**: toggle between small-group and full-raid data  
-  **Live scrolling output**: real-time feed of the selected class’s spells, heals, auras and fades  
-  **Minimal dependencies**: uses Blizzard frames + LibAddonMenu-2.0 only  
-  **Draggable & closable** UI panel  

---

##  Installation

### TurtleWoW GitHub Installer

1. Open the **TurtleWoW Launcher**  
2. Go to the **AddOns** tab  
3. Click **“Install from GitHub”**  
4. Paste this repo URL:  
   ```text
   https://github.com/joker5914/RaidRecon
   ```  
5. Launch the game and enable **RaidRecon** in your AddOns menu  

---

##  Usage

### Open the Spy Panel
```lua
/raidrecon
```

### Panel Breakdown

- **Top row**  
  -  **ChatLog**: toggles Blizzard’s `/chatlog` on/off  
  -  **Filter**: switches between your party or full raid  

- **Class buttons**  
  - 🔵 **Warrior**, 🟣 **Warlock**, etc.—click one to filter to that class  

- **Log window**  
  - Live feed of the selected class’s combat-log events  

### Quickstart

1. Type `/raidrecon`  
2. Click **“Priest”** to spy on your healers  
3. Toggle **Filter: party/raid** to expand scope  
4. Scroll to spot interrupts, overheals, buff fades, and more  

---

## 🛠️ Configuration Panel

Open **Interface → AddOns → RaidRecon** to configure:

| Control       | Description                                           |
|---------------|-------------------------------------------------------|
| **ChatLog**   | Toggle Blizzard’s `/chatlog` on or off                |
| **Filter**    | Choose **Party** or **Raid** as your data source      |
| **Debug**     | Enable or disable debug messages in your chat window  |
| **Clear Logs**| Erase all stored log entries                          |

---

## 🧪 Roadmap

- [ ] Sound or visual alerts on key events (interrupts, dispels, deaths)  
- [ ] Add timestamps and severity highlights  
- [ ] Export logs to file for post-mortem analysis  
- [ ] Right-click class buttons for sub-filters (heals-only, casts-only)  

---

## 📝 License

MIT — steal, tweak, laugh, repeat.
