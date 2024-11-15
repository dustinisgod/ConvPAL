local mq = require 'mq'
local gui = require 'gui'
local nav = require 'nav'
local utils = require 'utils'

local commands = {}

-- Existing functions

local function setExit()
    print("Closing..")
    gui.isOpen = false
end

local function setSave()
    gui.saveConfig()
end

-- Helper function for on/off commands
local function setToggleOption(option, value, name)
    if value == "on" then
        gui[option] = true
        print(name .. " is now enabled.")
    elseif value == "off" then
        gui[option] = false
        print(name .. " is now disabled.")
    else
        print("Usage: /convPAL " .. name .. " on/off")
    end
end

-- Helper function for numeric value commands
local function setNumericOption(option, value, name)
    if value == "" then
        print("Usage: /convPAL " .. name .. " <number>")
        return
    end
    if not string.match(value, "^%d+$") then
        print("Error: " .. name .. " must be a number with no letters or symbols.")
        return
    end
    gui[option] = tonumber(value)
    print(name .. " set to", gui[option])
end

-- On/Off Commands
local function setBotOnOff(value) setToggleOption("botOn", value, "Bot") end
local function setSwitchWithMA(value) setToggleOption("switchWithMA", value, "Switch with MA") end
local function setSitMedOnOff(value) setToggleOption("sitMed", value, "Sit to Med") end

-- Combined function for setting main assist, range, and percent
local function setAssist(name, range, percent)
    if name then
        utils.setMainAssist(name)
        print("Main Assist set to", name)
    else
        print("Error: Main Assist name is required.")
        return
    end

    -- Set the assist range if provided
    if range and string.match(range, "^%d+$") then
        gui.assistRange = tonumber(range)
        print("Assist Range set to", gui.assistRange)
    else
        print("Assist Range not provided or invalid. Current range:", gui.assistRange)
    end

    -- Set the assist percent if provided
    if percent and string.match(percent, "^%d+$") then
        gui.assistPercent = tonumber(percent)
        print("Assist Percent set to", gui.assistPercent)
    else
        print("Assist Percent not provided or invalid. Current percent:", gui.assistPercent)
    end
end

local function setChaseOnOff(value)
    if value == "" then
        print("Usage: /convPAL Chase <targetName> <distance> or /convPAL Chase off/on")
    elseif value == 'on' then
        gui.chaseOn = true
        gui.returnToCamp = false
        gui.pullOn = false
        print("Chase enabled.")
    elseif value == 'off' then
        gui.chaseOn = false
        print("Chase disabled.")
    else
        -- Split value into targetName and distance
        local targetName, distanceStr = value:match("^(%S+)%s*(%S*)$")
        
        if not targetName then
            print("Invalid input. Usage: /convPAL Chase <targetName> <distance>")
            return
        end
        
        -- Convert distance to a number, if it's provided
        local distance = tonumber(distanceStr)
        
        -- Check if distance is valid
        if not distance then
            print("Invalid distance provided. Usage: /convPAL Chase <targetName> <distance> or /convPAL Chase off")
            return
        end
        
        -- Pass targetName and valid distance to setChaseTargetAndDistance
        nav.setChaseTargetAndDistance(targetName, distance)
    end
end

-- Combined function for setting camp, return to camp, and chase
local function setCampHere(value1)
    if value1 == "on" then
        gui.chaseOn = false
        gui.campLocation = nav.setCamp()
        gui.returnToCamp = true
        gui.campDistance = gui.campDistance or 10
        print("Camp location set to current spot. Return to Camp enabled with default distance:", gui.campDistance)
    elseif value1 == "off" then
        -- Disable return to camp
        gui.returnToCamp = false
        print("Return To Camp disabled.")
    elseif tonumber(value1) then
        gui.chaseOn = false
        gui.campLocation = nav.setCamp()
        gui.returnToCamp = true
        gui.campDistance = tonumber(value1)
        print("Camp location set with distance:", gui.campDistance)
    else
        print("Error: Invalid command. Usage: /convPAL camphere <distance>, /convPAL camphere on, /convPAL camphere off")
    end
end

local function setMeleeOptions(meleeOption, stickOption, stickDistance)
    -- Set Assist Melee on or off based on the first argument
    if meleeOption == "on" then
        gui.assistMelee = true
        print("Assist Melee is now enabled")
    elseif meleeOption == "off" then
        gui.assistMelee = false
        print("Assist Melee is now disabled")
    elseif meleeOption == "front" or meleeOption == "behind" then
        -- Set Stick position based on 'front' or 'behind' and optionally set distance
        gui.assistMelee = true
        if meleeOption == "front" then
            gui.stickFront = true
            gui.stickBehind = false
            print("Stick set to front")
        elseif meleeOption == "behind" then
            gui.stickBehind = true
            gui.stickFront = false
            print("Stick set to behind")
        end

        -- Check if stickDistance is provided and is a valid number
        if stickOption and tonumber(stickOption) then
            gui.stickDistance = tonumber(stickOption)
            print("Stick distance set to", gui.stickDistance)
        elseif stickOption then
            print("Invalid stick distance. Usage: /convPAL melee front/behind <distance>")
        end
    else
        print("Error: Invalid command. Usage: /convPAL melee on/off or /convPAL melee front/behind <distance>")
    end
end

local function setTankIgnore(scope, action)
    -- Check for a valid target name
    local targetName = mq.TLO.Target.CleanName()
    if not targetName then
        print("Error: No target selected. Please target a mob to modify the tank ignore list.")
        return
    end

    -- Determine if the scope is global or zone-specific
    local isGlobal = (scope == "global")

    if action == "add" then
        utils.addMobToTankIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "tank ignore list for the current zone"
        print(string.format("'%s' has been added to the %s.", targetName, scopeText))

    elseif action == "remove" then
        utils.removeMobFromTankIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "tank ignore list for the current zone"
        print(string.format("'%s' has been removed from the %s.", targetName, scopeText))

    else
        print("Error: Invalid action. Usage: /convPAL tankignore zone/global add/remove")
    end
end

-- New functions
local function setTankMelee(value)
    if value == "on" then
        if gui.assistMelee then
            print("Error: assistMelee and tankMelee cannot be enabled simultaneously.")
            return
        end
        gui.tankMelee = true
        print("Tank Melee is now enabled.")
    elseif value == "off" then
        gui.tankMelee = false
        print("Tank Melee is now disabled.")
    else
        print("Usage: /convPAL tankmelee on/off")
    end
end

local function setAssistMelee(value)
    if value == "on" then
        if gui.tankMelee then
            print("Error: tankMelee and assistMelee cannot be enabled simultaneously.")
            return
        end
        gui.assistMelee = true
        print("Assist Melee is now enabled.")
    elseif value == "off" then
        gui.assistMelee = false
        print("Assist Melee is now disabled.")
    else
        print("Usage: /convPAL assistmelee on/off")
    end
end

local function setBuffsOn(value)
    setToggleOption("buffsOn", value, "Buffs On")
end

local function setLayOnHands(value)
    setToggleOption("layOnHands", value, "Lay on Hands")
end

local function setStun1(value)
    setToggleOption("stun1", value, "Stun 1")
end

local function setStun2(value)
    setToggleOption("stun2", value, "Stun 2")
end

local function setDmgUndead(value)
    setToggleOption("dmgUndead", value, "Damage Undead")
end

local function setTankRange(value)
    setNumericOption("tankRange", value, "Tank Range")
end

-- Main command handler
local function commandHandler(command, ...)
    -- Convert command and arguments to lowercase for case-insensitive matching
    command = string.lower(command)
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = string.lower(arg)
    end

    if command == "exit" then
        setExit()
    elseif command == "bot" then
        setBotOnOff(args[1])
    elseif command == "save" then
        setSave()
    elseif command == "assistmelee" then
        setAssistMelee(args[1])
    elseif command == "tankmelee" then
        setTankMelee(args[1])
    elseif command == "buffs" then
        setBuffsOn(args[1])
    elseif command == "layonhands" then
        setLayOnHands(args[1])
    elseif command == "tank" then
        setTankRange(args[1])
    elseif command == "stun1" then
        setStun1(args[1])
    elseif command == "stun2" then
        setStun2(args[1])
    elseif command == "dmgundead" then
        setDmgUndead(args[1])
    elseif command == "sitmed" then
        setSitMedOnOff(args[1])
    elseif command == "melee" then
        setMeleeOptions(args[1], args[2], args[3])
    elseif command == "switchwithma" then
        setSwitchWithMA(args[1])
    elseif command == "assist" then
        setAssist(args[1], args[2], args[3])
    elseif command == "chase" then
        local chaseValue = args[1]
        if args[2] then
            chaseValue = chaseValue .. " " .. args[2]
        end
        setChaseOnOff(chaseValue)
    elseif command == "camphere" then
        setCampHere(args[1])
    elseif command == "pullignore" then
        setTankIgnore(args[1], args[2])
    end
end

function commands.init()
    -- Single binding for the /convPAL command
    mq.bind('/convPAL', function(command, ...)
        commandHandler(command, ...)
    end)
end

return commands