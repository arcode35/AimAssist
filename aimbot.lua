local turretPositionAddress = nil
local redHighlightAddress = nil
local highlightInstructionAddress = nil
local isNopped = false
local oldBytes = {}
local validAimAddresses = {}
function getTurretAddress()

    print("Searching for turret address...")
    local turretSignatures = {
        { pattern = "c5 fb 10 47 ? 8b 7a ? 49 03 fe c5 fb 10 4f ? 48 bf", offset = 0x3, jump = 0x0, register = "RDI" },
        { pattern = "c4 c1 7b ? ? 03 45 ? 64 24 ? 4d 03 e6 c4 c1 7b ? ? 24 ? 49 bc", offset = 0x3, jump = 0x0, register = "R15"},
        { pattern = "c4 c1 73 ? ? 03 c5 fb 2c", offset = 0x3, jump = 0x0, register = "R8" },
        { pattern = "c4 c1 7b ? ? 03 44 8b ? 27 4d 03 c6 c4 c1 7b ? ? 03 44 8b", offset = 0x3, jump = 0xD, register = "R8" },
        { pattern = "c5 f9 2e d9 0f 8a 1c 00 00 00 0f 85 ? ? ? ? 41 83 f9 ? 0f 84 ? ? ? ? 49 8b c1", offset = 0x6, jump = 0xF, register = "RCX" },
        { pattern = "c5 fb 58 c9 c4 c1 7b", offset = 0x3, jump = 0x4, register = "R9"}
    }

    local turretInstructionAddress = nil
    local isBreakpointHit = false
    local breakpointTimeout = 500  -- 500 milliseconds

    for _, signature in ipairs(turretSignatures) do
        isBreakpointHit = false  -- Reset the flag for each signature
        local results = AOBScan(signature.pattern)
        if results ~= nil then
            turretInstructionAddress = getAddress(stringlist_getString(results, 0)) + signature.jump
            print(string.format("Found turret instruction address: 0x%x", turretInstructionAddress))
            local breakpointId = debug_setBreakpoint(
                turretInstructionAddress,
                function()
                    isBreakpointHit = true
                    if (isBreakpointHit) then
                        print("Breakpoint hit.")
                    end
                    local potentialAddress = nil
                    if signature.register == "R11" then
                        potentialAddress = R11 + signature.offset
                    elseif signature.register == "RCX" then
                        potentialAddress = RCX + signature.offset
                    elseif signature.register == "RDI" then
                        potentialAddress = RDI + signature.offset
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
                    if (readDouble(potentialAddress) == 0) then
                        print(string.format("Found a potential address: 0x%X", potentialAddress))
                        turretPositionAddress = potentialAddress
                        print(string.format("Setting turret address: 0x%X", turretPositionAddress))

                        debug_removeBreakpoint(turretInstructionAddress)  -- Remove the breakpoint after capturing the turretPositionAddress
                    end
                end
            )
            print(string.format("Turret position address set to: %x", turretPositionAddress))
            isInitialized = true
            local timerId = createTimer(nil, false)
            timer_setInterval(timerId, breakpointTimeout)
            timer_onTimer(timerId, function()
                if not isBreakpointHit then
                    print(string.format("Breakpoint at 0x%x not hit. Moving to next.", turretInstructionAddress))
                    debug_removeBreakpoint(breakpointId)
                    timerId.destroy()
                    timerId = nil
                else
                    print("Breakpoint hit. Stopping timer.")
                    timerId.destroy()
                    timerId = nil
                end
            end)
            timer_setEnabled(timerId, true)

            if isBreakpointHit then
                break  -- Found a valid breakpoint, so exit the loop
            end
        end
    end

    if turretInstructionAddress == nil then
        print("No valid turret instruction address found.")
    end
end

function esp()

    if (isNopped) then
        writeBytes(highlightInstructionAddress, oldBytes)
        isNopped = false
        return
    end
    if (highlightInstructionAddress == nil) then
        print("Couldn't find the ESP signature.")
        return
    end
   --print(string.format("Found address at: %x", highlightInstructionAddress))
    local numBytes = getInstructionSize(highlightInstructionAddress)
    --print(string.format("The size of the instruction is: %d", numBytes))
    oldBytes = readBytes(highlightInstructionAddress, numBytes, true)
    local t = {}
    for i = 1, numBytes, 1 do
        t[i] = 0x90
    end

    writeBytes(highlightInstructionAddress, t)
    isNopped = true
end




function getRedScan()

    print("Searching for the red highlight scan...")
    local results = AOBScan("45 8b 40 ? 4c 8b 4d ? 45 8b 59 ? 4d 03 de 41 bc ? ? ? ? 45 39 e3 0f 85 ? ? ? ? 45 8b 59")
    if (results == nil) then
        print("Couldn't find the red highlight signature.")
        return
    end
    local breakpointHitCount = 0  -- Counter to keep track of the number of times the breakpoint is hit
    local maxHits = 4
    highlightInstructionAddress = getAddress(stringlist_getString(results, 0))
    if (highlightInstructionAddress ~= nil) then
       print(string.format("Found highlight instruction address: %0X", highlightInstructionAddress))
    end
end

function getRedHighlight()
    if (highlightInstructionAddress == nil) then
        print("Couldn't find the red highlight instruction address")
        return
    end

    local maxHits = 30
    local breakpointHitCount = 0
    print("Obtaining the IG Aimbot value.. Make sure that you are aiming at someone")
    local IGAimbotAddr = nil
    local breakPointId = debug_setBreakpoint(highlightInstructionAddress, function()
        breakpointHitCount = breakpointHitCount + 1
        IGAimbotAddr = R8 + 0x33
        if (readBytes(IGAimbotAddr, 1, true)[1] == 193) then
            print(string.format("Captured a potential aimbot address: %0X", IGAimbotAddr))
            table.insert(validAimAddresses, IGAimbotAddr)
        end
        if (breakpointHitCount >= 30) then
            print("Breakpoint hit count exceeded. Ending the breakpoint.")
            debug_removeBreakpoint(highlightInstructionAddress)
        end
    end
    )
end



function aimAssist()
    -- Debug: Print all addresses in validAimAddresses
    for i, address in ipairs(validAimAddresses) do
        print(string.format("Address %d: 0x%X", i, address))
    end

    -- Debug: Check if turretPositionAddress and redHighlightAddress are initialized
    if turretPositionAddress == nil or redHighlightAddress == nil then
        print("Error: Turret position or red highlight address not initialized.")
        return
    else
        print(string.format("Turret Position: 0x%X, Red Highlight: 0x%X", turretPositionAddress, redHighlightAddress))
    end

for i, address in ipairs(validAimAddresses) do
    local redHighlightValueTable = readBytes(address, 1, true)
    if redHighlightValueTable then
        local redHighlightValue = redHighlightValueTable[1]
              print(redHighlightValue);
    end
end

    if turretPositionAddress == nil or redHighlightAddress == nil then
        print("Error: Turret position or red highlight address not initialized.")
        return
    end

    local currentTurretPosition = readDouble(turretPositionAddress)
    local step = 0.00005  -- Incremental step for scanning; you can adjust this as needed
    local targetFound = false

    local radians15 = 15 * (math.pi / 180)  -- 15 degrees converted to radians

    --print("Starting aim assist from position: " .. currentTurretPosition)

    -- Scan 15 degrees (0.2618 radians) to the left
    for angle = currentTurretPosition, currentTurretPosition - radians15, -step do
        writeDouble(turretPositionAddress, angle)
        local redHighlightValue = readBytes(validAimAddresses[1], 1, true)[1]

        --print("Debug: redHighlightValue is " .. tostring(redHighlightValue))  -- Debug print

        if redHighlightValue == 193 then
           -- print("Target locked at angle: " .. angle)
            targetFound = true
            break
        end
    end


    -- If target is not found, scan 15 degrees (0.2618 radians) to the right
    if not targetFound then
        for angle = currentTurretPosition, currentTurretPosition + radians15, step do
            writeDouble(turretPositionAddress, angle)
            local redHighlightValueTable = readBytes(validAimAddresses, 1, true)
            local redHighlightValue = redHighlightValueTable[1]



            --print("Debug: redHighlightValue is " .. tostring(redHighlightValue))  -- Debug print

            if redHighlightValue == 193 then
                --print("Target locked at angle: " .. angle)
                targetFound = true
                break
            end
        end
    end

    if not targetFound then
        --print("No target found within 15 degrees.")
    end
end



function checkForKeyPressH()
    local VK_LSHIFT = 0xA0  -- Aim Assist
    local VK_CTRL = 0xA2 -- ESP
    if isKeyPressed(VK_LSHIFT) then
        aimAssist()
    end
    if isKeyPressed(VK_CTRL) then
        esp()
    end
end

function checkForKeyPress()
    local VK_1 = 0x31  -- ASCII for "1"
    local VK_2 = 0x32  -- ASCII for "2"

    if isKeyPressed(VK_1) then
        getTurretAddress()
    end

    if isKeyPressed(VK_2) then
        getRedHighlight()
    end
end

function setUpScanningTimer()
    local timerInterval = 300  -- Check every 300ms
    timerObj = createTimer(nil)
    timer_onTimer(timerObj, checkForKeyPress)
    timer_setInterval(timerObj, timerInterval)
    timer_setEnabled(timerObj, true)
end

function setupHotkeyWithTimer()
    local timerInterval = 200 -- Check every 50ms
    timerObj = createTimer(nil)
    timer_onTimer(timerObj, checkForKeyPressH)
    timer_setInterval(timerObj, timerInterval)
    timer_setEnabled(timerObj, true)
end

-- Start script execution
getRedScan()
setUpScanningTimer()
setupHotkeyWithTimer()
