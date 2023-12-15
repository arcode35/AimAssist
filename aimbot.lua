local ownBaseAddress = nil
local enemyCoordinates = {}
local seenAddresses = {}
local distanceTable = {}
local turretAddress = nil
local tankOrientationAddress = nil
local sinOrientationAddress = nil
local YOffset = 0x8
local ZOffset = 0x10
local currentEnemyIndex = 1

function getOwnCoordinates()
    print("Scanning for own Z-coordinate...")
    local xResults = AOBScan("F3 0F 7E 46 10 F2 0F 59 C1 8B 42 58")

    if xResults == nil then
        print("Couldn't find the own Z-coordinate signature.")
        return
    end

    local ownZInstruction = getAddress(stringlist_getString(xResults, 0))
    print("Found own Z-coordinate instruction address: " .. string.format("0x%X", ownZInstruction))

    debug_setBreakpoint(ownZInstruction, function()
        ownBaseAddress = ESI + 0x10
        print("Own X-coordinate base address set to: " .. string.format("0x%X", ownBaseAddress))
        debug_removeBreakpoint(ownZInstruction)
    end)
end


function getEnemyCoordinates()
  for k in pairs(enemyCoordinates) do
        enemyCoordinates[k] = nil
    end

    print("Scanning for enemy coordinates...")
    local exResults = AOBScan("F3 0F 7E 46 10 F2 0F 59 C1 8B 42 58")

    if exResults == nil then
        print("Couldn't find enemy Z coordinate signature.")
        return
    end

    local enemyZInstruction = getAddress(stringlist_getString(exResults, 0))
    print("Found enemy X-coordinate instruction address: " .. string.format("0x%X", enemyZInstruction))

    local breakPointHitCount = 0
    debug_setBreakpoint(enemyZInstruction, function()
        breakPointHitCount = breakPointHitCount + 1

        local enemyXAddress = ESI + 0x10 

        if breakPointHitCount < 30 and enemyXAddress ~= ownBaseAddress and not seenAddresses[enemyXAddress] then
            local enemyYAddress = enemyXAddress + YOffset
            local enemyZAddress = enemyXAddress + ZOffset
            local x = readDouble(enemyXAddress)
            local y = readDouble(enemyYAddress)
            local z = readDouble(enemyZAddress)
            -- Insert the coordinates as a table into the enemyCoordinates table
            table.insert(enemyCoordinates, {enemyXAddress, enemyYAddress, enemyZAddress})

            seenAddresses[enemyXAddress] = true

            print("Retrieved an enemy coordinate: " .. string.format("(%f, %f, %f), 0x%X", x, y, z, enemyXAddress))
        end

        if (breakPointHitCount >= 30) then
           debug_removeBreakpoint(enemyZInstruction)
        end
    end)
    end


function getTurretAddress()
    print("Scanning for turret signature...")
    local tResults = AOBScan("f3 0f 7e 49 ? 66 0f d6 49")
    if (tResults == nil) then
        print("Couldn't find the turret signature.")
        return
    end
    local tInstruction = getAddress(stringlist_getString(tResults, 0))
    print("Found turret instruction address: " .. string.format("0x%X", tInstruction))


    local tAddr = nil
    debug_setBreakpoint(tInstruction, function()
        tAddr = ECX + 0x70
        if (readDouble(tAddr) == 0) then
            turretAddress = tAddr
            print("Own turret address set to: " .. string.format("0x%X", turretAddress))
            debug_removeBreakpoint(tInstruction)
        end
    end)
end

function getTankOrientation()
    print("Scanning for tank orientation")
    local oResults = AOBScan("F3 0F 7E 4A 28 F2 0F 59 CA F2 0F 58 C1")
    if (oResults == nil) then
        print("Couldn't find tank orientation")
        return
    end
    local oInstruction = getAddress(stringlist_getString(oResults, 0))
    print("Found orientation instruction address: " .. string.format("0x%X", oInstruction))


    local oAddr = nil
    debug_setBreakpoint(oInstruction, function()
            oAddr = EDX + 0x28
            print(string.format("Found  orientation address: 0x%X", oAddr))
            tankOrientationAddress = oAddr
            sinOrientationAddress = tankOrientationAddress - 0x18
            debug_removeBreakpoint(oInstruction)
        end)
end

function printEnemies()
    if not enemyCoordinates then
        print("Error: Enemy coordinates not initialized yet")
        return
    end

    local enemyCount = 1;

    local ownX = readDouble(ownBaseAddress)
    local ownY = readDouble(ownBaseAddress + YOffset)
    local ownZ = readDouble(ownBaseAddress + ZOffset)

    for _, enemyAddress in ipairs(enemyCoordinates) do
        local enemyX = readDouble(enemyAddress[1])
        local enemyY = readDouble(enemyAddress[2])
        local enemyZ = readDouble(enemyAddress[3])
        local distance = math.sqrt((enemyX - ownX)^2 + (enemyY - ownY)^2 + (enemyZ - ownZ)^2)
        print(string.format("Enemy %d: (%f, %f, %f) is %f away from you", enemyCount, enemyX, enemyY, enemyZ, distance))
        enemyCount = enemyCount + 1
    end
end

function normalize_angle(angle_in_radians)
    local normalizedAngle = angle_in_radians
    while (normalizedAngle > math.pi) do
        normalizedAngle = normalizedAngle - 2 * math.pi
    end
    while (normalizedAngle < math.pi) do
        normalizedAngle = normalizedAngle + 2 * math.pi
    end
    return normalizedAngle
end

function srtByDistance()
    if not turretAddress or not ownBaseAddress then
        print("Error: Turret or player coordinates not yet initialized!")
        return
    end

    local ownX = readDouble(ownBaseAddress)
    local ownY = readDouble(ownBaseAddress + YOffset)
    local ownZ = readDouble(ownBaseAddress + ZOffset)

    local distanceTable = {}

    for index, enemyAddress in ipairs(enemyCoordinates) do
        local enemyX = readDouble(enemyAddress[1])
        local enemyY = readDouble(enemyAddress[2])
        local enemyZ = readDouble(enemyAddress[3])

        local distance = math.sqrt((enemyX - ownX)^2 + (enemyY - ownY)^2 + (enemyZ - ownZ)^2)

        if distance >= 1 then 
            table.insert(distanceTable, distance)
        end
    end

    -- Sort both the enemyCoordinates and distanceTable based on distance
    local sortedIndices = {}
    for i = 1, #distanceTable do
        sortedIndices[i] = i
    end

    table.sort(sortedIndices, function(a, b) return distanceTable[a] < distanceTable[b] end)

    local sortedEnemyCoordinates = {}
    local sortedDistanceTable = {}
    for i, index in ipairs(sortedIndices) do
        table.insert(sortedEnemyCoordinates, enemyCoordinates[index])
        table.insert(sortedDistanceTable, distanceTable[index])
    end

    enemyCoordinates = sortedEnemyCoordinates
    distanceTable = sortedDistanceTable
end
-- Compute the angle to the enemy players
function calcAngle(currentEnemyIndex)
    if not turretAddress or not ownBaseAddress then
        print("Error: Turret or player coordinates not yet initialized!")
        return
    end

    local ownX = readDouble(ownBaseAddress)
    local ownY = readDouble(ownBaseAddress + YOffset)

    local enemyX = readDouble(enemyCoordinates[currentEnemyIndex][1])
    local enemyY = readDouble(enemyCoordinates[currentEnemyIndex][2])

    local deltaX = enemyX - ownX
    local deltaY = enemyY - ownY


    local angleToEnemy = math.atan2(deltaY,deltaX)


    local currentTankOrientationCosValue = readDouble(tankOrientationAddress)
    local currentTankOrientationSinValue = readDouble(sinOrientationAddress)

    local tankOrientationAngleCos = math.acos(currentTankOrientationCosValue)
    local tankOrientationAngleSin = math.asin(currentTankOrientationSinValue)

    local quadrant = 0
    if currentTankOrientationCosValue > 0 and currentTankOrientationSinValue > 0 then
        quadrant = 1
    elseif currentTankOrientationCosValue < 0 and currentTankOrientationSinValue > 0 then
        quadrant = 2
    elseif currentTankOrientationCosValue < 0 and currentTankOrientationSinValue < 0 then
        quadrant = 3
    elseif currentTankOrientationCosValue > 0 and currentTankOrientationSinValue < 0 then
        quadrant = 4
    end

    local effectiveAimAngle = 0

    if quadrant == 1 or quadrant == 2 then
        effectiveAimAngle = angleToEnemy + 2 * tankOrientationAngleCos
    elseif quadrant == 3 or quadrant == 4 then
        effectiveAimAngle = angleToEnemy + 2 * -tankOrientationAngleCos
    end

    effectiveAimAngle = effectiveAimAngle + math.pi/2

    effectiveAimAngle = normalize_angle(effectiveAimAngle)

    return effectiveAimAngle
end

function aimbot()
    if not turretAddress then
        print("Turret address is not initialized.")
        return
    end

    srtByDistance()

    local finalAngle = calcAngle(currentEnemyIndex)

    writeDouble(turretAddress, finalAngle)
end



function checkForKeyPress()
    local VK_LSHIFT = 0xA0
    local VK_TAB = 0x09
    local VK_CAPS = 0x14

    if isKeyPressed(VK_LSHIFT) then
        aimbot()
    elseif isKeyPressed(VK_CAPS) then
       if (currentEnemyIndex > #enemyCoordinates) then
            currentEnemyIndex = 1
            return
       end
       currentEnemyIndex = currentEnemyIndex + 1
    end

end

function setupTimers()
    -- Timer for checking key press
    local timerInterval = 1  
    local keypressTimer = createTimer(nil)
    timer_onTimer(keypressTimer, checkForKeyPress)
    timer_setInterval(keypressTimer, timerInterval)
    timer_setEnabled(keypressTimer, true)

end

getTankOrientation()
getOwnCoordinates()
getEnemyCoordinates()
getTurretAddress()
setupTimers()
