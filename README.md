# AimAssist
This project is a proof-of-concept aimbot designed to provide insights into the techniques and algorithms that power aiming assistance in video games. The aimbot is created with a focus on ethical research, aiming to further the understanding of aimbot mechanics and challenge detection algorithms.
**Features**

**Address Scanning**: Scans the game's memory to find the addresses corresponding to certain features like turret position, enemy coordinates, and more.
**Automatic Aiming**: Aims the player's turret toward the closest enemy.
**Coordinate Updates**: Periodically updates the list of enemy coordinates.
**Hotkeys**: Implements hotkeys for certain tasks like locking onto an enemy.
**Dependencies**
Lua environment capable of running the script
Functions like AOBScan, getAddress, debug_setBreakpoint, etc., should be available in the running environment.
**How to Use**
Load this script into your compatible Lua environment.
Run the script to initialize scanning for addresses.
Use the designated hotkeys to activate various features (e.g., Left Shift for aim lock).
**Code Structure**
Variables
turretPositionAddress: Stores the memory address of the turret's position.
ownBaseAddress: Stores the base memory address for the player's coordinates.
YOffset, XOffset: Offsets used for calculating various coordinates.
tankOrientationAddress: Stores the memory address for the tank's orientation.
enemyZAddresses: List storing the Z-coordinates of detected enemies.
isInitialized: Boolean flag to check if initialization is complete.
previousCoordinates: Stores previously detected coordinates.
**Functions**
getTurretAddress()
Searches for and sets the turretPositionAddress.

getRedScan()
Searches for and sets the redHighlightAddress, a 

updateOwnCoordinates()
Updates the ownBaseAddress based on scans.

isValidCoordinate(x, y)
Checks if a set of coordinates is valid.

updateEnemyCoordinates()
Updates the list of enemy Z-coordinate addresses.

pruneStaleAddresses()
Removes stale entries from enemyZAddresses.

aimLock()
Automatically aims the turret toward the closest enemy.

printEnemyCoordinates()
Prints the current list of enemy coordinates.

checkForKeyPress()
Checks for keypress events to trigger certain actions.

Timers
Several timers are set up to periodically call various functions.

License
This project is for educational purposes and should not be used to violate any terms of service.
