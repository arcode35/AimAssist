# Aimbot

This guide explains the various functions in the game hacking script. The script includes functions to retrieve and manipulate game data such as player and enemy coordinates, turret orientation, and implementing an aimbot feature.

## Functions

### `getOwnCoordinates()`
- Scans for the player's Z-coordinate.
- Sets up a breakpoint to retrieve the X-coordinate base address.

### `getEnemyCoordinates()`
- Clears and updates the `enemyCoordinates` table.
- Scans for enemy Z-coordinate signatures.
- Sets a breakpoint to capture enemy coordinates and stores them.

### `getTurretAddress()`
- Searches for the turret signature in the game memory.
- Retrieves and stores the turret address.

### `getTankOrientation()`
- Scans for the tank's orientation signature.
- Retrieves and stores the tank's orientation address.

### `printEnemies()`
- Prints the coordinates and distances of all detected enemies.

### `normalize_angle(angle_in_radians)`
- Normalizes an angle to the range [-π, π].

### `srtByDistance()`
- Sorts enemies by distance from the player.

### `calcAngle(currentEnemyIndex)`
- Calculates the angle to the current enemy based on the player's orientation.

### `aimbot()`
- Implements the aimbot functionality by adjusting the turret's orientation.

### `checkForKeyPress()`
- Checks for specific key presses to trigger the aimbot or cycle through enemies.

### `setupTimers()`
- Sets up timers for continuous execution of certain functions like `checkForKeyPress`.

## Usage

1. Call `getTankOrientation()`, `getOwnCoordinates()`, `getEnemyCoordinates()`, and `getTurretAddress()` to initialize the script.
2. Use `setupTimers()` to start the keypress check loop.
3. In-game, use the designated keys to activate the aimbot or cycle through enemies.

## Notes

- This script is intended for educational purposes and understanding game mechanics.
- The effectiveness and safety of using such scripts in online games vary and might lead to bans or other penalties.
