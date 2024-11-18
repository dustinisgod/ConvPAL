local mq = require('mq')
local gui = require('gui')
local nav = require('nav')

local utils = {}

utils.IsUsingDanNet = true
utils.IsUsingTwist = false
utils.IsUsingCast = true
utils.IsUsingMelee = false

utils.tankConfig = {}
local tankConfigPath = mq.configDir .. '/' .. 'Conv_tank_ignore_list.lua'

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

function utils.PluginCheck()
    if utils.IsUsingDanNet then
        if not mq.TLO.Plugin('mq2dannet').IsLoaded() then
            printf("Plugin \ayMQ2DanNet\ax is required. Loading it now.")
            mq.cmd('/plugin mq2dannet noauto')
        end
        -- turn off fullname mode in DanNet
        if mq.TLO.DanNet.FullNames() then
            mq.cmd('/dnet fullnames off')
        end
        if utils.IsUsingTwist then
            if not mq.TLO.Plugin('mq2twist').IsLoaded() then
                printf("Plugin \ayMQ2Twist\ax is required. Loading it now.")
                mq.cmd('/plugin mq2twist noauto')
            end
        end
        if utils.IsUsingCast then
            if not mq.TLO.Plugin('mq2cast').IsLoaded() then
                printf("Plugin \ayMQ2Cast\ax is required. Loading it now.")
                mq.cmd('/plugin mq2cast noauto')
            end
        end
        if not utils.IsUsingMelee then
            if mq.TLO.Plugin('mq2melee').IsLoaded() then
                printf("Plugin \ayMQ2Melee\ax is not recommended. Unloading it now.")
                mq.cmd('/plugin mq2melee unload')
            end
        end
    end
end

function utils.FacingTarget(tolerance)
    tolerance = tolerance or 20  -- Default tolerance of 20 degrees
    if mq.TLO.Target.ID() == 0 then return true end

    local targetHeading = mq.TLO.Target.HeadingTo.DegreesCCW()
    local myHeading = mq.TLO.Me.Heading.DegreesCCW()
    local difference = math.abs((targetHeading - myHeading + 360) % 360)

    -- Check if the difference is within the tolerance
    return difference <= tolerance or difference >= (360 - tolerance)
end


function utils.isInGroup()
    local inGroup = mq.TLO.Group() and mq.TLO.Group.Members() > 0
    return inGroup
end

-- Utility: Check if the player is in a group or raid
function utils.isInRaid()
    local inRaid = mq.TLO.Raid.Members() > 0
    return inRaid
end

-- Helper function to check if the target is in campQueue
function utils.isTargetInCampQueue(targetID)
    local pull = require('pull')
    for _, mob in ipairs(pull.campQueue) do
        if mob.ID() == targetID then
            return true
        end
    end
    return false
end

local lastNavTime = 0

function utils.monitorNav()
debugPrint("monitorNav")
    if gui.botOn and (gui.chaseOn or gui.returnToCamp) and not gui.pullOn then
        if not gui then
            printf("Error: gui is nil")
            return
        end

        local currentTime = os.time()

        if gui.returnToCamp and (currentTime - lastNavTime >= 5) then
            debugPrint("Run returntocamp routine")
            nav.checkCampDistance()
            lastNavTime = currentTime
        elseif gui.chaseOn and (currentTime - lastNavTime >= 2) then
            debugPrint("Run Chase routine")
            nav.chase()
            lastNavTime = currentTime
        end
    else
        return
    end
end

local lastBuffTime = 0
local lastSelfBuffTime = 0

function utils.monitorBuffs()
local buffer = require('buffer')
local selfbuffer = require('selfbuffer')
    debugPrint("monitorBuffs")
    if gui.botOn and gui.buffsOn then
        if not gui then
            printf("Error: gui is nil")
            return
        end

        local currentTime = os.time()

        -- Check buffs every 5 minutes (300 seconds)
        if gui.buffsOn and (currentTime - lastBuffTime >= 240) then
            debugPrint("Run Buff routine")
            buffer.buffRoutine()
            lastBuffTime = currentTime
       -- Check buffs every 5 minutes (300 seconds)
        elseif gui.buffsOn and (currentTime - lastSelfBuffTime >= 240) then
            debugPrint("Run SelfBuff routine")
            selfbuffer.selfBuffRoutine()
            lastSelfBuffTime = currentTime
        end
    else
        return
    end
end

function utils.sitMed()
    debugPrint("sitMed")
    if gui.botOn and gui.sitMed and mq.TLO.Me.PctMana() < 100 and not mq.TLO.Me.Mount() and not mq.TLO.Me.Combat() ~= "COMBAT" then
        local nearbyNPCs = mq.TLO.SpawnCount(string.format('npc radius %d los', gui.tankRange))() or 0
        debugPrint("Nearby NPCs: " .. nearbyNPCs)
        if mq.TLO.Me.PctHPs() < 70 and nearbyNPCs > 0 then
            debugPrint("Returning: HPs < 70 or nearby NPCs > 0")
            return
        end
        debugPrint("PctHPs: " .. mq.TLO.Me.PctHPs())
        if nearbyNPCs == 0 then
            debugPrint("No nearby NPCs or HPs >= 70")
            if not mq.TLO.Me.Casting() and not mq.TLO.Me.Moving() then
                debugPrint("Not casting or moving")
                if not mq.TLO.Me.Sitting() then
                    debugPrint("Not sitting")
                    mq.cmd('/sit')
                    mq.delay(100)
                end
            end
        end
    end
end

function utils.setMainAssist(charName)
    if charName and charName ~= "" then
        -- Remove spaces, numbers, and symbols
        charName = charName:gsub("[^%a]", "")
        
        -- Capitalize the first letter and make the rest lowercase
        charName = charName:sub(1, 1):upper() .. charName:sub(2):lower()

        gui.mainAssist = charName
    end
end

-- Utility function to check if a table contains a given value
function utils.tableContains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

local hasLoggedError = false

function utils.isInCamp(range)

    range = range or 10  -- Default to a 10-unit range if none is provided

    -- Determine reference location (camp location or main assist's location)
    local referenceLocation
    if gui.returnToCamp then
        -- Use camp location if returnToCamp is enabled
        nav.campLocation = nav.campLocation or {x = 0, y = 0, z = 0}  -- Default camp location if not set
        referenceLocation = {x = nav.campLocation.x, y = nav.campLocation.y, z = nav.campLocation.z}
    elseif gui.chaseOn then
        -- Use main assist's location if chaseOn is enabled
        local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
        if mainAssistSpawn() then
            referenceLocation = {x = mainAssistSpawn.X(), y = mainAssistSpawn.Y(), z = mainAssistSpawn.Z()}
        else
            if not hasLoggedError then
                hasLoggedError = true
            end
            return false  -- No valid main assist, so not in camp
        end
    else
        if not hasLoggedError then
            hasLoggedError = true
        end
        return false  -- Neither camp nor chase is active, so not in camp
    end

    -- Reset error flag if a valid reference location is found
    hasLoggedError = false

    -- Get the player’s current location
    local playerX, playerY, playerZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    if not playerX or not playerY or not playerZ then
        return false  -- Exit if player coordinates are unavailable
    end

    -- Calculate distance from the player to the reference location
    local distanceToCamp = math.sqrt((referenceLocation.x - playerX)^2 +
                                     (referenceLocation.y - playerY)^2 +
                                     (referenceLocation.z - playerZ)^2)
    
    -- Check if the player is within the specified range of the camp location
    return distanceToCamp <= range
end

function utils.referenceLocation(range)
    range = range or 100  -- Set a default range if none is provided

    -- Determine reference location based on returnToCamp or chaseOn settings
    local referenceLocation
    if gui.assistOn and gui.returnToCamp then
        nav.campLocation = nav.campLocation or {x = 0, y = 0, z = 0}  -- Initialize campLocation with a default if needed
        referenceLocation = {x = nav.campLocation.x, y = nav.campLocation.y, z = nav.campLocation.z}
    elseif gui.chaseOn or (not gui.chaseon and not gui.returnToCamp) then
        local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
        if mainAssistSpawn() then
            referenceLocation = {x = mainAssistSpawn.X(), y = mainAssistSpawn.Y(), z = mainAssistSpawn.Z()}
        else
            if not hasLoggedError then
                hasLoggedError = true
            end
            return {}  -- Return an empty table if no valid main assist found
        end
    else
        if not hasLoggedError then
            hasLoggedError = true
        end
        return {}  -- Return an empty table if neither returnToCamp nor chaseOn is enabled
    end

    -- Reset error flag if a valid location is found
    hasLoggedError = false

    local mobsInRange = mq.getFilteredSpawns(function(spawn)
        local mobX, mobY, mobZ = spawn.X(), spawn.Y(), spawn.Z()
        if not mobX or not mobY or not mobZ then
            return false  -- Skip this spawn if any coordinate is nil
        end

        local distanceToReference = math.sqrt((referenceLocation.x - mobX)^2 +
                                              (referenceLocation.y - mobY)^2 +
                                              (referenceLocation.z - mobZ)^2)
        return spawn.Type() == 'NPC' and distanceToReference <= range
    end)
    

    return mobsInRange  -- Return the list of mobs in range
end

-- Load the tank ignore list from the config file
function utils.loadTankConfig()
    local configData, err = loadfile(tankConfigPath)
    if configData then
        local config = configData() or {}
        
        -- Load each zone-specific list
        for zone, mobs in pairs(config) do
            utils.tankConfig[zone] = mobs
        end
        
        -- Ensure the global ignore list is always loaded and initialized
        utils.tankConfig.globalIgnoreList = utils.tankConfig.globalIgnoreList or {}
        
        print("Tank ignore list loaded from " .. tankConfigPath)
    else
        print("No tank ignore list found. Starting with an empty list.")
        utils.tankConfig = {globalIgnoreList = {}}  -- Initialize with an empty global list
    end
end

-- Function to add a mob to the tank ignore list using its clean name
function utils.addMobToTankIgnoreList(targetName, isGlobal)
    local zoneName = isGlobal and "globalIgnoreList" or mq.TLO.Zone.ShortName() or "UnknownZone"
    
    if targetName then
        -- Ensure the zone or global list has an entry in the table
        utils.tankConfig[zoneName] = utils.tankConfig[zoneName] or {}
        
        -- Add the mob's clean name to the appropriate ignore list if not already present
        if not utils.tankConfig[zoneName][targetName] then
            utils.tankConfig[zoneName][targetName] = true
            print(string.format("Added '%s' to the tank ignore list for '%s'.", targetName, zoneName))
            utils.saveTankConfig() -- Save the configuration after adding
        else
            print(string.format("'%s' is already in the tank ignore list for '%s'.", targetName, zoneName))
        end
    else
        print("Error: No target selected. Please target a mob to add it to the tank ignore list.")
    end
end

-- Function to remove a mob from the tank ignore list using its clean name
function utils.removeMobFromTankIgnoreList(targetName, isGlobal)
    local zoneName = isGlobal and "globalIgnoreList" or mq.TLO.Zone.ShortName() or "UnknownZone"
    
    if targetName then
        -- Check if the zone or global entry exists in the ignore list
        if utils.tankConfig[zoneName] and utils.tankConfig[zoneName][targetName] then
            utils.tankConfig[zoneName][targetName] = nil  -- Remove the mob entry
            print(string.format("Removed '%s' from the tank ignore list for '%s'.", targetName, zoneName))
            utils.saveTankConfig()  -- Save the updated ignore list
        else
            print(string.format("'%s' is not in the tank ignore list for '%s'.", targetName, zoneName))
        end
    else
        print("Error: No target selected. Please target a mob to remove it from the tank ignore list.")
    end
end

-- Save the tank ignore list to the config file
function utils.saveTankConfig()
    local config = {}
    for zone, mobs in pairs(utils.tankConfig) do
        config[zone] = mobs
    end
    mq.pickle(tankConfigPath, config)
    print("Tank ignore list saved to " .. tankConfigPath)
end

return utils