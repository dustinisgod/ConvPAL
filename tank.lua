local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local nav = require('nav')
local spells = require('spells')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local tank = {}
local charLevel = mq.TLO.Me.Level()
local previousNearbyNPCs = 0 -- Initialize to track changes in nearby NPC count

local function buildMobQueue(range)
    debugPrint("Building mob queue with range:", range)
    local zoneName = mq.TLO.Zone.ShortName() or "UnknownZone"
    local ignoreList = utils.tankConfig[zoneName] or {}
    local globalIgnoreList = utils.tankConfig.globalIgnoreList or {}

    -- Filter mobs within range and not ignored
    local mobs = mq.getFilteredSpawns(function(spawn)
        local mobName = spawn.CleanName() or ""
        local isPlayerPet = spawn.Owner() and spawn.Owner.Type() == "PC"
        local isIgnored = ignoreList[mobName] or globalIgnoreList[mobName]

        return spawn.Type() == "NPC" and
               (spawn.Distance() or math.huge) <= range and
               not isPlayerPet and
               not spawn.Dead() and
               spawn.LineOfSight() and
               not isIgnored
    end)

    -- Sort mobs by priority: PctHPs (ascending), Named, then Level (descending)
    table.sort(mobs, function(a, b)
        local aPctHPs = a.PctHPs() or 100
        local bPctHPs = b.PctHPs() or 100
        local aNamed = a.Named() or false
        local bNamed = b.Named() or false
        local aLevel = a.Level() or 0
        local bLevel = b.Level() or 0

        if aPctHPs ~= bPctHPs then
            return aPctHPs < bPctHPs -- prioritize lower HP percentage
        elseif aNamed ~= bNamed then
            return aNamed -- prioritize named mobs
        else
            return aLevel > bLevel -- then by level, descending
        end
    end)

    debugPrint("Mob queue built with", #mobs, "mobs in range")
    return mobs
end

local function hasEnoughMana(spellName)
    local manaCheck = spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
    debugPrint("Checking mana for spell:", spellName, "Has enough mana:", manaCheck)
    return manaCheck
end

local function inRange(spellName)
    local rangeCheck = false

    if mq.TLO.Target() and spellName then
        local targetDistance = mq.TLO.Target.Distance()
        local spellRange = mq.TLO.Spell(spellName) and mq.TLO.Spell(spellName).Range()

        if targetDistance and spellRange then
            rangeCheck = targetDistance <= spellRange
        else
            debugPrint("DEBUG: Target distance or spell range is nil for spell:", spellName)
        end
    else
        if not mq.TLO.Target() then
            debugPrint("DEBUG: No target available for range check.")
        end
        if not spellName then
            debugPrint("DEBUG: Spell name is nil.")
        end
    end

    debugPrint("DEBUG: Checking range for spell:", spellName, "In range:", tostring(rangeCheck))
    return rangeCheck
end

local function currentlyActive(spell)
    if not mq.TLO.Target() then
        print("No target selected.")
        return false -- No target to check
    end

    local spellName = mq.TLO.Spell(spell).Name()
    if not spellName then
        print("Spell not found:", spell)
        return false -- Spell doesn't exist or was not found
    end

    -- Safely get the buff count with a default of 0 if nil
    local buffCount = mq.TLO.Target.BuffCount() or 0
    for i = 1, buffCount do
        if mq.TLO.Target.Buff(i).Name() == spellName then
            return true -- Spell is active on the target
        end
    end

    return false -- Spell is not active on the target
end

function tank.tankRoutine()
    if not gui.botOn and not gui.tankOn then
        debugPrint("Bot or melee mode is off; exiting combat loop.")
        mq.cmd("/squelch /attack off")
        mq.delay(100)
        mq.cmd("/squelch /stick off")
        mq.delay(100)
        mq.cmd("/squelch /nav off")
        return
    end

    local stickDistance = gui.stickDistance
    local lowerBound = stickDistance * 0.9
    local upperBound = stickDistance * 1.1

    while true do
        if not gui.botOn and not gui.tankOn then
            debugPrint("Bot or melee mode is off; exiting combat loop.")
            mq.cmd("/squelch /attack off")
            mq.delay(100)
            mq.cmd("/squelch /stick off")
            mq.delay(100)
            mq.cmd("/squelch /nav off")
            return
        end

        local nearbyNPCs = mq.TLO.SpawnCount(string.format('npc radius %d los', gui.tankRange))() or 0
        local mobsInRange = {}

        if nearbyNPCs > 0 then
        mobsInRange = buildMobQueue(gui.tankRange)
        end

        if #mobsInRange == 0 then
            debugPrint("No mobs in range.")

            if gui.travelTank then
                if mq.TLO.Navigation.Paused() then
                    debugPrint("Resuming navigation.")
                    mq.cmd("/squelch /nav pause")
                    mq.delay(100)
                end
            end

            if mq.TLO.Me.Combat() then
                debugPrint("Exiting combat mode.")
                mq.cmd("/squelch /attack off")
                mq.delay(100)
                if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and mq.TLO.Me.Pet.Combat() then
                    debugPrint("Calling pet back.")
                    mq.cmd("/squelch /pet back off")
                    mq.delay(100)
                end
                return
            end

            return
        end

        local target = table.remove(mobsInRange, 1)
        debugPrint("Target:", target)

        if target and target.Distance() ~= nil and target.Distance() <= gui.tankRange and (not mq.TLO.Target() or mq.TLO.Target.ID() ~= target.ID()) and target.LineOfSight() then
            mq.cmdf("/target id %d", target.ID())
            mq.delay(300)
            debugPrint("Target set to:", target.CleanName())
        end

        if not mq.TLO.Target() or (mq.TLO.Target() and mq.TLO.Target.ID() ~= target.ID()) then
            debugPrint("No target selected; exiting combat loop.")
            return
        elseif mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Stick.Active() then
         debugPrint("Not stuck to target; initiating stick command.")

            -- Stop or pause navigation depending on the travelTank setting
            if mq.TLO.Navigation.Active() and not mq.TLO.Navigation.Paused() then
                if not gui.travelTank then
                    debugPrint("Stopping navigation.")
                    mq.cmd('/nav stop')
                else
                    debugPrint("Pausing navigation.")
                    mq.cmd('/nav pause')
                end
                mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
            end

            debugPrint("Stick distance:", stickDistance)
            mq.cmdf("/stick front %d uw", stickDistance)
            mq.delay(100, function() return mq.TLO.Stick.Active() end)
        end
        

        if mq.TLO.Target() and mq.TLO.Me.Combat() ~= nil and not mq.TLO.Me.Combat() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() ~= nil and mq.TLO.Target.LineOfSight() then
            debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
            mq.cmd("/squelch /attack on")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and not mq.TLO.Me.Pet.Combat() and mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                debugPrint("Sending pet to attack.")
                mq.cmd("/squelch /pet attack")
                mq.delay(100)
            end
        end

        while mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and not mq.TLO.Target.Dead() do
            debugPrint("Combat state: ", mq.TLO.Me.CombatState())

            if not gui.botOn and not gui.tankOn then
                debugPrint("Bot or melee mode is off; exiting combat loop.")
                mq.cmd("/squelch /attack off")
                mq.delay(100)
                mq.cmd("/squelch /stick off")
                mq.delay(100)
                mq.cmd("/squelch /nav off")
                return
            end

            if mq.TLO.Target() and target and (mq.TLO.Target.ID() ~= target.ID() or mq.TLO.Target.Type() ~= "NPC") then
                mq.cmdf("/target id %d", target.ID())
                mq.delay(200)
            end

            if mq.TLO.Target() and not mq.TLO.Target.Dead() and not mq.TLO.Stick.Active() and mq.TLO.Target.Distance() <= gui.tankRange then
                mq.cmdf("/stick front %d uw", stickDistance)
                mq.delay(100, function() return mq.TLO.Stick.Active() end)
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Me.Combat() then
                debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /attack on")
                mq.delay(100)
                if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and not mq.TLO.Me.Pet.Combat() and mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                    debugPrint("Sending pet to attack.")
                    mq.cmd("/squelch /pet attack")
                    mq.delay(100)
                end
                if gui.usePet and mq.TLO.Pet.Combat() and mq.TLO.Pet.Target() and mq.TLO.Target() and mq.TLO.Pet.Target() ~= mq.TLO.Target() then
                    debugPrint("Setting pet target to:", mq.TLO.Target.CleanName())
                    mq.cmd("/squelch /pet back off")
                    mq.delay(100)
                    mq.cmd("/squelch /pet attack")
                    mq.delay(100)
                end
            end

            if mq.TLO.Target() and mq.TLO.Me.PctAggro() < 100 then
                if nav.campLocation then
                    local playerX, playerY = mq.TLO.Me.X(), mq.TLO.Me.Y()
                    local campX = tonumber(nav.campLocation.x) or 0
                    local campY = tonumber(nav.campLocation.y) or 0
                    local distanceToCamp = math.sqrt((playerX - campX)^2 + (playerY - campY)^2)

                    if gui.returntocamp and distanceToCamp > 100 then
                        debugPrint("Returning to camp location.")
                        if mq.TLO.Me.Combat() then
                            mq.cmd("/squelch /attack off")
                            mq.delay(100)
                        end
                        if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and mq.TLO.Me.Pet.Combat() and mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                            mq.cmd("/squelch /pet back off")
                            mq.delay(100)
                        end
                        mq.cmd("/stick off")
                        mq.delay(100)
                        mq.cmdf("/nav loc %f %f %f", campY, campX, nav.campLocation.z or 0)
                        mq.delay(100)
                        while mq.TLO.Navigation.Active() do
                            mq.delay(50)
                        end
                        return
                    end
                end
            end

            if mq.TLO.Target() and not utils.FacingTarget() and not mq.TLO.Target.Dead() and mq.TLO.Target.LineOfSight() then
                debugPrint("Facing target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /face fast")
                mq.delay(100)
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then

                if mq.TLO.Target() and mq.TLO.Me.AbilityReady("Taunt")() and mq.TLO.Me.PctAggro() < 100 then
                    debugPrint("Using Taunt ability.")
                    mq.cmd("/doability Taunt")
                    mq.delay(100)
                end

                if mq.TLO.Target() and mq.TLO.Me.AltAbilityReady('6001')() and mq.TLO.Me.PctHPs() < 10 then
                    debugPrint("Using lay on hands.")
                    mq.cmd("/squelch /target myself")
                    mq.delay(100)
                    mq.cmd("/squelch /alt act 6001")
                    mq.delay(100)
                    mq.cmd("/squelch /target clear")
                end

                if mq.TLO.Target() and mq.TLO.Me.AbilityReady("Bash")() and mq.TLO.Me.Secondary() ~= "0" then
                    debugPrint("Using Bash ability.")
                    mq.cmd("/squelch /doability Bash")
                    mq.delay(100)
                elseif mq.TLO.Target() and mq.TLO.Me.AbilityReady("Slam")() and mq.TLO.Me.Secondary() == "0" and mq.TLO.Me.Race() == "Ogre" then
                    debugPrint("Using Slam ability.")
                    mq.cmd("/squelch /doability Slam")
                    mq.delay(100)
                end

                local spellsToCast = {
                    {name = "Stun1", spell = spells.findBestSpell("Stun1", charLevel), slot = 1, cond = charLevel >= 7 and mq.TLO.Me.PctAggro() < 100},
                    {name = "Stun2", spell = spells.findBestSpell("Stun2", charLevel), slot = 2, cond = charLevel >= 13 and mq.TLO.Me.PctAggro() < 100 and not mq.TLO.Me.SpellReady(1)()},
                    {name = "SelfAtkBuff", spell = spells.findBestSpell("SelfAtkBuff", charLevel), slot = 4, cond = charLevel >= 9 and mq.TLO.Me.Combat()},
                    {name = "DmgUndead", spell = spells.findBestSpell("DmgUndead", charLevel), slot = 3, cond = charLevel >= 14 and (mq.TLO.Target.Type() == "Undead") and mq.TLO.Me.Combat() and mq.TLO.Me.PctMana() > 20}
                }

                for _, spellInfo in ipairs(spellsToCast) do
                    local spellName, spell, slot, condition = spellInfo.name, spellInfo.spell, spellInfo.slot, spellInfo.cond
                    if mq.TLO.Target() and spell and condition and mq.TLO.Me.SpellReady(slot)() and hasEnoughMana(spell) and inRange(spell) and not currentlyActive(spell) then
                        mq.cmdf("/squelch /stick off")
                        mq.delay(100)
                        debugPrint("Casting spell:", spellName, "on slot", slot)
                        mq.cmdf("/cast %d", slot)
                        mq.delay(100)
                    end
                    while mq.TLO.Me.Casting() do
                        if mq.TLO.Target() and not mq.TLO.Target.LineOfSight() then
                            debugPrint("Interrupting spell cast.")
                            mq.cmd("/squelch /stopcast")
                            mq.delay(100)
                            break
                        elseif not mq.TLO.Target() and target or target.Dead() then
                            mq.cmd("/squelch /stopcast")
                            break
                        end
                        mq.delay(10)
                    end
                end
            end

            local lastStickDistance = nil

            if mq.TLO.Target() and mq.TLO.Stick() == "ON" then
                local targetDistance = mq.TLO.Target.Distance()
                
                -- Check if stickDistance has changed
                if lastStickDistance and  lastStickDistance ~= stickDistance then
                    lastStickDistance = stickDistance
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                end
        
                -- Check if the target distance is out of bounds and adjust as necessary
                if mq.TLO.Target() and not mq.TLO.Target.Dead() then
                    if mq.TLO.Target() and targetDistance > upperBound then
                        mq.cmdf("/squelch /stick moveback %s", stickDistance)
                        mq.delay(100)
                    elseif mq.TLO.Target() and targetDistance < lowerBound then
                        mq.cmdf("/squelch /stick moveback %s", stickDistance)
                        mq.delay(100)
                    end
                end
            end

            if target and target.Dead() then
                debugPrint("Target is dead; exiting combat loop.")
                break
            end

            mq.delay(50)
        end
    end
end

return tank