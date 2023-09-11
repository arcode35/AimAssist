local turretPositionAddress = nil
local ownBaseAddress = nil
local YOffset = 0xC
local ZOffset = 0x18
local tankOrientationAddress = nil
local tankOrientationOffset = 0x30
local redHighlightAddress = nil
local enemyZAddresses = {}
local isInitialized = true
local previousCoordinates = {}

function getTurretAddress()
    print("Searching for turret address...")
    -- Multiple signatures to retrieve our own turret address more consistently.
    local turretSignatures = {
        { pattern = "c4 c1 7b ? ? 03 45 ? 64 24 ? 4d 03 e6 c4 c1 7b ? ? 24 ? 49 bc", offset = 0x3, jump = 0x0, register = "R15" },
        { pattern = "c4 c1 73 ? ? 03 c5 fb 2c", offset = 0x3, jump = 0x0, register = "R8" },
        { pattern = "c4 c1 7b ? ? 03 44 8b ? 27 4d 03 c6 c4 c1 7b ? ? 03 44 8b", offset = 0x3, jump = 0xD, register = "R8" },
        { pattern = "c5 f9 2e d9 0f 8a 1c 00 00 00 0f 85 ? ? ? ? 41 83 f9 ? 0f 84 ? ? ? ? 49 8b c1", offset = 0x6, jump = 0xF, register = "RCX" },
        { pattern = "c5 fb 58 c9 c4 c1 7b", offset = 0x3, jump = 0x4, register = "R9"}
    }

    local turretInstructionAddress = nil

    for _, signature in ipairs(turretSignatures) do
        local results = AOBScan(signature.pattern)
        if results ~= nil then
            turretInstructionAddress = getAddress(stringlist_getString(results, 0)) + signature.jump
            print("Found turret instruction address: " .. string.format("0x%X", turretInstructionAddress))

            -- Set the breakpoint
            debug_setBreakpoint(
                turretInstructionAddress,
                function()
                    local potentialAddress = nil
                    if signature.register == "R11" then
                        potentialAddress = R11 + signature.offset
                    elseif signature.register == "RCX" then
                        potentialAddress = RCX + signature.offset
                    elseif signature.register == "RDX" then
                        potentialAddress = RDX + signature.offset
                    elseif signature.register == "R8" then
                        potentialAddress = R8 + signature.offset
                    elseif signature.register == "R15" then
                        potentialAddress = R15 + signature.offset
                    elseif signature.register == "R9" then
                        potentialAddress = R9 + signature.offset
                    end

                    -- Check if the value at the potential address is 0
                    if readDouble(potentialAddress) == 0 then
                        turretPositionAddress = potentialAddress
                        debug_removeBreakpoint(turretInstructionAddress)  -- Remove the breakpoint after capturing the turretPositionAddress
                        print("Turret position address set to: " .. string.format("0x%X", turretPositionAddress))
                        isInitialized = true
                    end
                end
            )

            -- Break out of the loop as we have found a match
            break
        end
    end

    if turretInstructionAddress == nil then
        print("No valid turret instruction address found.")
    end
end


function getRedScan()
    print("Searching for the red highlight scan...");
    local results = AOBScan("45 8b 40 ? 4c 8b 4d ? 45 8b 59 ? 4d 03 de 41 bc ? ? ? ? 45 39 e3 0f 85 ? ? ? ? 45 8b 59")
    if (results == nil) then
        print("Couldn't find the red highlight signature.")
        return
    end
    redHighlightResults = getAddress(stringlist_getString(results, 0))

    debug_setBreakpoint(
        redHighlightResults,
        function()
            redHighlightAddress = R8 + 0x33

            print("Red highlight address set to: " .. string.format("0x%X", redHighlightAddress))

            -- Optional: If you only want to find the own Z-coordinate once, you can remove the breakpoint here.
            debug_removeBreakpoint(redHighlightResults)
        end
    )

end

function updateOwnCoordinates()
    print("Scanning for own Z-coordinate...")
    local ZOwnResults = AOBScan("F3 0F 7E 46 10 F2 0F 59 C1 8B 42 58 85 C0")
    if (ZOwnResults == nil) then
        print("Couldn't find the own Z-coordinate signature.")
        return
    end

    local ownZInstructionAddress = getAddress(stringlist_getString(ZOwnResults, 0)) -- Adjust the offset if needed.
    print("Found own Z-coordinate instruction address: " .. string.format("0x%X", ownZInstructionAddress))

    debug_setBreakpoint(
        ownZInstructionAddress,
        function()
            ownBaseAddress = ESI + 0x10 -- This assumes the base address for the player is in the R11 register. Adjust if needed.

            print("Own X-coordinate base address set to: " .. string.format("0x%X", ownBaseAddress))

            -- Optional: If you only want to find the own Z-coordinate once, you can remove the breakpoint here.
            debug_removeBreakpoint(ownZInstructionAddress)
        end
    )
end

function isValidCoordinate(x, y)
    if not isInitialized then
        print("Initialization is not complete yet. Please wait...")
        return
    end

    local playerX = readDouble(ownBaseAddress - XOffset)
    local playerY = readDouble(ownBaseAddress - YOffset)
    local deltaX = math.abs(x - playerX)
    local deltaY = math.abs(y - playerY)

    if (deltaX < 0.1 or deltaY < 0.1) then
        return false
    else
        return true
    end

end
function updateEnemyCoordinates()
    -- Logic to periodically scan and update enemy Z-coordinates
    local ZResults = AOBScan("4d 03 de c4 c1 7b ? ? 03 c5 e3 ? d2 c4")
    if (ZResults == nil) then
        print("Couldn't find the enemy's Z coordinate signature")
        return
    end

    local enemyZInstruction = getAddress(stringlist_getString(ZResults, 0)) + 0x3

    debug_setBreakpoint(
        enemyZInstruction,
        function()
            local currentAddress = R11 + 3
            local enemyX = readDouble(currentAddress - XOffset)
            local enemyY = readDouble(currentAddress - YOffset)

            -- Validate coordinates
            if not isValidCoordinate(enemyX, enemyY) then
                -- Check if this problematic address is in the list and remove it
                for index, addr in ipairs(enemyZAddresses) do
                    if addr == currentAddress then
                        table.remove(enemyZAddresses, index)
                        break
                    end
                end

                -- If this problematic address isn't in the previousCoordinates list, add it
                local alreadyExistsInPrevious = false
                for _, addr in ipairs(previousCoordinates) do
                    if addr == currentAddress then
                        alreadyExistsInPrevious = true
                        break
                    end
                end

                if not alreadyExistsInPrevious then
                    table.insert(previousCoordinates, currentAddress)
                    print("Added problematic address to previousCoordinates: " .. string.format("0x%X", currentAddress))
                end

                return
            end

            -- Check if this address is already in the enemyZAddresses table
            local alreadyExists = false
            for _, addr in ipairs(enemyZAddresses) do
                if addr == currentAddress then
                    alreadyExists = true
                    break
                end
            end

            -- If it's a new address, and not in the problematic list, add it to the enemyZAddresses list
            if not alreadyExists then
                table.insert(enemyZAddresses, currentAddress)
            end
        end
    )
end


-- Call this function periodically (e.g., every 30 seconds) to prune addresses that no longer update
function pruneStaleAddresses()
    for i = #enemyZAddresses, 1, -1 do
        local addr = enemyZAddresses[i]
        local currentX = readDouble(addr - XOffset)
        local currentY = readDouble(addr - YOffset)

        if previousCoordinates[addr] and previousCoordinates[addr].x == currentX and previousCoordinates[addr].y == currentY then
            table.remove(enemyZAddresses, i)
        else
            previousCoordinates[addr] = {x = currentX, y = currentY}
        end
    end
end


function aimLock()
    if not isInitialized then
        print("Initialization is not complete yet. Please wait...")
        return
    end

    if not turretPositionAddress or not ownBaseAddress then
        print("Error: Turret or player coordinates not yet initialized!")
        return
    end

    -- Get the player's coordinates
    local ownX = readDouble(ownBaseAddress - XOffset)
    local ownY = readDouble(ownBaseAddress - YOffset)

    -- Initialize to track the closest enemy
    local closestDistance = math.huge
    local closestEnemy = nil

    -- Loop through the enemy addresses to find the closest one
    for _, enemyAddress in ipairs(enemyZAddresses) do
        local enemyX = readDouble(enemyAddress - XOffset)
        local enemyY = readDouble(enemyAddress - YOffset)
        local distance = math.sqrt((enemyX - ownX)^2 + (enemyY - ownY)^2)

        -- Proximity check to skip ourselves
        if distance < 1 then
            return
        end

        if distance < closestDistance then
            closestDistance = distance
            closestEnemy = {x = enemyX, y = enemyY}
        end
    end

    if not closestEnemy then
        print("No enemies found.")
        return
    end

    -- Calculate the angle to the closest enemy
    local deltaX = closestEnemy.x - ownX
    local deltaY = closestEnemy.y - ownY
    local angle = -math.atan2(deltaY, deltaX)

    -- Write the calculated angle to the turret's position
    tankOrientationAddress = ownBaseAddress + tankOrientationOffset
    local tankOrientationAngle = 2 * (math.acos(readDouble(tankOrientationAddress))))
    angle = angle - tankOrientationAngle
    writeDouble(turretPositionAddress, angle)
end


function printEnemyCoordinates()
    if #enemyZAddresses == 0 then
        print("No enemy coordinates captured yet.")
        return
    end

    print("Number of enemies: " .. #enemyZAddresses)

    print("Captured enemy coordinates:")
    for _, enemyAddress in ipairs(enemyZAddresses) do
        local enemyX = readDouble(enemyAddress - XOffset)
        local enemyY = readDouble(enemyAddress - YOffset)
        print(string.format("Enemy at (X: %f, Y: %f)", enemyX, enemyY))
    end
end

function checkForKeyPress()
    local VK_LSHIFT = 0xA0 
    local VK_TAB = 0x09 

    if isKeyPressed(VK_LSHIFT) then
        aimLock()
    elseif isKeyPressed(VK_TAB) then
        printEnemyCoordinates()
    end
end

function setupHotkeyWithTimer()
    local timerInterval = 100  -- Check every 100ms
    timerObj = createTimer(nil)
    timer_onTimer(timerObj, checkForKeyPress)
    timer_setInterval(timerObj, timerInterval)
    timer_setEnabled(timerObj, true)
end

function setupEnemyCoordinateUpdateTimer()
    local updateInterval = 240000  -- 30 seconds in milliseconds
    coordUpdateTimer = createTimer(nil)
    timer_onTimer(coordUpdateTimer, function()
        updateEnemyCoordinates()
        pruneStaleAddresses()  -- Prune stale addresses after updating the enemy coordinates
    end)
    timer_setInterval(coordUpdateTimer, updateInterval)
    timer_setEnabled(coordUpdateTimer, true)
end


function setupOwnCoordinateUpdateTimer()
    local updateInterval = 240000  -- 30 seconds in milliseconds
    ownZUpdateTimer = createTimer(nil)
    timer_onTimer(ownZUpdateTimer, updateOwnCoordinates)
    timer_setInterval(ownZUpdateTimer, updateInterval)
    timer_setEnabled(ownZUpdateTimer, true)
end

function setupTurretUpdateTimer()
    local updateInterval = 240000  -- 120 seconds in milliseconds (2 minutes)
    turretUpdateTimer = createTimer(nil)
    timer_onTimer(turretUpdateTimer, getTurretAddress)
    timer_setInterval(turretUpdateTimer, updateInterval)
    timer_setEnabled(turretUpdateTimer, true)
end

-- Start script execution
print("Starting script...")
getTurretAddress()
updateOwnCoordinates()
updateEnemyCoordinates()
printEnemyCoordinates()
setupOwnCoordinateUpdateTimer()
setupEnemyCoordinateUpdateTimer()
setupHotkeyWithTimer()
