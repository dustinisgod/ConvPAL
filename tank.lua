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

local function buildMobQueue(range)
    debugPrint("Building mob queue with range:", range)
    local zoneName = mq.TLO.Zone.ShortName() or "UnknownZone"
    local ignoreList = utils.tankConfig[zoneName] or {}
    local globalIgnoreList = utils.tankConfig.globalIgnoreList or {}

    local mobs = mq.getFilteredSpawns(function(spawn)
        local mobName = spawn.CleanName()
        local isPlayerPet = spawn.Owner.Type() == "PC"
        local isIgnored = ignoreList[mobName] or globalIgnoreList[mobName]

        return spawn.Type() == "NPC" and
               spawn.Distance() <= range and
               not isPlayerPet and
               not spawn.Dead() and
               spawn.LineOfSight() and
               not isIgnored
    end)

    -- Sort mobs by priority: named mobs first, then by level (descending)
    table.sort(mobs, function(a, b)
        if a.Named() ~= b.Named() then
            return a.Named() -- prioritize named mobs
        else
            return a.Level() > b.Level() -- then by level, descending
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
    local rangeCheck = mq.TLO.Target() and spellName and mq.TLO.Target.Distance() <= mq.TLO.Spell(spellName).Range() or false
    debugPrint("Checking range for spell:", spellName, "In range:", rangeCheck)
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
    if not gui.botOn and not gui.tankMelee then
        debugPrint("Bot or melee mode is off; exiting tankRoutine.")
        return
    end

    local stickDistance = gui.stickDistance
    local lowerBound = stickDistance * 0.5
    local upperBound = stickDistance * 1.1

    while true do
        local nearbyNPCs = mq.TLO.SpawnCount(string.format('npc radius %d los', gui.tankRange))() or 0
        local mobsInRange = {}

        if nearbyNPCs > 0 then
        mobsInRange = buildMobQueue(gui.tankRange)
        end

        if #mobsInRange == 0 then
            mq.cmd("/squelch /attack off") -- Stop attacking if no more targets
            mq.delay(100)
            return
        end

        if #mobsInRange == 0 then
            debugPrint("No mobs in range. Exiting tankRoutine.")
            if mq.TLO.Me.Combat() then
                debugPrint("Exiting combat mode.")
                mq.cmd("/squelch /attack off")
                mq.delay(100)
            end
            debugPrint("Stopping stick and navigation.")
            return
        end

        local target = table.remove(mobsInRange, 1)
        debugPrint("Target:", target)

        if target and target.Distance() <= gui.tankRange and (not mq.TLO.Target() or mq.TLO.Target.ID() ~= target.ID()) and target.LineOfSight() then
            mq.cmdf("/squelch /target id %d", target.ID())
            mq.delay(200)
            debugPrint("Target set to:", target.CleanName())
        end

        if mq.TLO.Target() and mq.TLO.Stick.Active() == false and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
            debugPrint("Not stuck to target; initiating stick command.")
            if mq.TLO.Navigation.Active() then
                mq.cmd('/squelch /nav stop')
                mq.delay(100)
            end
            mq.cmdf("/stick front %d uw", stickDistance)
            mq.delay(100)
        end

        if mq.TLO.Target() and not mq.TLO.Me.Combat() and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
            debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
            mq.cmd("/squelch /attack on")
            mq.delay(100)
        end
        debugPrint("Combat state: ", mq.TLO.Me.CombatState())

        while mq.TLO.Me.CombatState() == "COMBAT" and target and mq.TLO.Target.ID() == mq.TLO.Target.ID() and not mq.TLO.Target.Dead() do
            debugPrint("Combat state: ", mq.TLO.Me.CombatState())

            if mq.TLO.Target() and target and (mq.TLO.Target.ID() ~= target.ID or mq.TLO.Target.Dead() == true or (mq.TLO.Target.PctHPs() ~= nil and mq.TLO.Target.PctHPs() < 0)) then
                mq.cmdf("/squelch /target id %d", target.ID())
                mq.delay(200)
                debugPrint("Target set to:", target.CleanName())
            elseif not mq.TLO.Target() or mq.TLO.Target() and (mq.TLO.Target.Dead() or mq.TLO.Target.PctHPs() < 0) then
                debugPrint("Target is dead. Exiting combat loop.")
                break
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Me.Combat() then
                debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /attack on")
                mq.delay(100)
            end

            if mq.TLO.Me.PctAggro() < 100 then
                if nav.campLocation then
                    local playerX, playerY = mq.TLO.Me.X(), mq.TLO.Me.Y()
                    local campX = tonumber(nav.campLocation.x) or 0
                    local campY = tonumber(nav.campLocation.y) or 0
                    local distanceToCamp = math.sqrt((playerX - campX)^2 + (playerY - campY)^2)

                    if gui.returnToCamp and distanceToCamp > 100 then
                        debugPrint("Returning to camp location.")
                        if mq.TLO.Me.Combat() then
                            mq.cmd("/squelch /attack off")
                            mq.delay(100)
                        end
                        mq.cmd("/squelch /stick off")
                        mq.delay(100)
                        mq.cmdf("/squelch /nav loc %f %f %f", campY, campX, nav.campLocation.z or 0)
                        mq.delay(100)
                        while mq.TLO.Navigation.Active() do
                            mq.delay(50)
                        end
                        return
                    end
                end
            end

            if not utils.FacingTarget() and not mq.TLO.Target.Dead() and mq.TLO.Target.LineOfSight() then
                debugPrint("Facing target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /face id " .. mq.TLO.Target.ID())
                mq.delay(100)
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then

                if mq.TLO.Target.Distance() < lowerBound then
                    debugPrint("Target too close; moving back.")
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                    mq.delay(100)
                end



                if mq.TLO.Me.AbilityReady("Taunt")() and mq.TLO.Me.PctAggro() < 100 then
                    debugPrint("Using Taunt ability.")
                    mq.cmd("/squelch /doability Taunt")
                    mq.delay(100)
                end

                if mq.TLO.Me.AltAbilityReady('6001')() and mq.TLO.Me.PctHPs() < 10 then
                    debugPrint("Using Bash ability.")
                    mq.cmd("/squelch /target myself")
                    mq.delay(100)
                    mq.cmd("/squelch /alt act 6001")
                    mq.delay(100)
                    mq.cmd("/squelch /target clear")
                end

                if mq.TLO.Me.AbilityReady("Bash")() and mq.TLO.Me.Secondary() ~= "0" then
                    debugPrint("Using Bash ability.")
                    mq.cmd("/squelch /doability Bash")
                    mq.delay(100)
                elseif mq.TLO.Me.AbilityReady("Slam")() and mq.TLO.Me.Secondary() == "0" and mq.TLO.Me.Race() == "Ogre" then
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
                    if spell and condition and mq.TLO.Me.SpellReady(slot)() and hasEnoughMana(spell) and inRange(spell) and not currentlyActive(spell) then
                        mq.cmdf("/squelch /stick off")
                        mq.delay(100)
                        debugPrint("Casting spell:", spellName, "on slot", slot)
                        mq.cmdf("/squelch /cast %d", slot)
                        mq.delay(100)
                    end
                    while mq.TLO.Me.Casting() do
                        mq.delay(10)
                    end
                end

            elseif mq.TLO.Target() and mq.TLO.Target.Distance() > upperBound and mq.TLO.Target.LineOfSight() then
                debugPrint("Target too far; moving closer.")
                mq.cmdf("/squelch /stick front %d uw", stickDistance)
                mq.delay(100)
            elseif mq.TLO.Target() and mq.TLO.Target.Distance() > (upperBound + 100) and not mq.TLO.Target.LineOfSight() then
            debugPrint("Target out of range and line of sight; ending combat.")
            if mq.TLO.Me.Combat() then
                mq.cmd("/squelch /attack off")
                mq.delay(100)
            end
            if gui.returnToCamp and nav.campLocation then
                debugPrint("Returning to camp location.")
                mq.cmd("/squelch /stick off")
                mq.delay(100)
                mq.cmdf("/squelch /nav loc %f %f %f", nav.campLocation.y, nav.campLocation.x, nav.campLocation.z or 0)
                mq.delay(100)
                while mq.TLO.Navigation.Active() do
                    mq.delay(50)
                end
            end
                mq.delay(100)
            end

            mq.delay(100)
        end
        debugPrint("Exiting combat loop.")
        mq.delay(100)
    end
end

return tank