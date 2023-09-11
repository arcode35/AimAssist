# Game Enhancement Script README

## Description

This Lua script is designed to assist in gameplay by providing various features like aim assist, enemy highlighting (ESP), and dynamically finding memory addresses related to the game's internal state. It employs advanced techniques like AOB (Array of Bytes) scanning, breakpoint setting, and direct memory manipulation.

---

## Features

### Aim Assist

- Automatically adjusts the player's aim toward a target within a 15-degree cone.
- Uses real-time memory scanning to lock onto the closest enemy.

### ESP (Enemy Highlight)

- Highlights enemies in the game world.
- Allows for toggling the ESP on and off via a hotkey.

### Dynamic Address Finding

- Scans the game memory to find the addresses for the player's turret position and enemy highlighting.
- Multiple signatures are used to increase the reliability of address finding.

---

## How it Works

### Variables

- `turretPositionAddress`: Holds the memory address for the player's turret position.
- `redHighlightAddress`: Holds the memory address where enemies are highlighted.
- `highlightInstructionAddress`: Holds the address for the instruction responsible for enemy highlighting.
- `isNopped`: Flag to indicate if the ESP instruction has been replaced with NOPs.
- `oldBytes`: Holds the original bytes of the ESP instruction.
- `validAimAddresses`: A list to store addresses that have a valid aim assist value.

### Functions

- `getTurretAddress()`: Scans the game's memory to find and set `turretPositionAddress`.
- `esp()`: Toggles the ESP feature on and off.
- `getRedScan()`: Finds the instruction responsible for enemy highlighting.
- `getRedHighlight()`: Captures addresses that have a valid aim assist value.
- `aimAssist()`: Performs the aim assist logic.
- `checkForKeyPressH()`: Checks for hotkey presses related to aim assist and ESP.
- `checkForKeyPress()`: Checks for hotkey presses related to address scanning.
- `setUpScanningTimer()`: Sets up a timer to periodically scan for addresses.
- `setupHotkeyWithTimer()`: Sets up a timer to check for hotkey presses.

---

## How to Use

1. Start the script.
2. Use the designated hotkeys to toggle features on and off.
