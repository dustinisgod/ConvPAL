local mq = require('mq')
local ImGui = require('ImGui')


local charName = mq.TLO.Me.Name()
local configPath = mq.configDir .. '/' .. 'ConvPAL_'.. charName .. '_config.lua'
local config = {}

local gui = {}

local previousTankRange = gui.tankRange

gui.isOpen = true

local function setDefaultConfig()
    gui.botOn = false
    gui.mainAssist = ""
    gui.assistRange = 40
    gui.assistPercent = 95
    gui.assistOn = true
    gui.stickFront = false
    gui.stickBehind = true
    gui.stickDistance = 15
    gui.switchWithMA = true
    gui.returnToCamp = false
    gui.campDistance = 10
    gui.chaseOn = false
    gui.chaseTarget = ""
    gui.chaseDistance = 20
    gui.tankMelee = false
    gui.tankRange = 50
    gui.buffsOn = false
    gui.sitMed = false
    gui.stun1 = false
    gui.stun2 = false
    gui.dmgUndead = false
    gui.layOnHands = false
end

function gui.getPullDistanceXY()
    return gui.pullDistanceXY
end

function gui.getPullDistanceZ()
    return gui.pullDistanceZ
end

function gui.saveConfig()
    for key, value in pairs(gui) do
        config[key] = value
    end
    mq.pickle(configPath, config)
    print("Configuration saved to " .. configPath)
end

local function loadConfig()
    local configData, err = loadfile(configPath)
    if configData then
        config = configData() or {}
        for key, value in pairs(config) do
            gui[key] = value
        end
    else
        print("Config file not found. Initializing with defaults.")
        setDefaultConfig()
        gui.saveConfig()
    end
end

loadConfig()

function ColoredText(text, color)
    ImGui.TextColored(color[1], color[2], color[3], color[4], text)
end

local function controlGUI()
    gui.isOpen, _ = ImGui.Begin("Convergence Paladin", gui.isOpen, 2)

    if not gui.isOpen then
        mq.exit()
    end

    ImGui.SetWindowSize(440, 600)

    gui.botOn = ImGui.Checkbox("Bot On", gui.botOn or false)

    ImGui.SameLine()

    if ImGui.Button("Save Config") then
        gui.saveConfig()
    end

    ImGui.Separator()

    ImGui.Spacing()

    -- Tank Checkbox
    gui.tankMelee = ImGui.Checkbox("Tank", gui.tankMelee or false)
    if gui.tankMelee then
        gui.assistOn = false
    end

    ImGui.SameLine()

    -- Assist Checkbox
    gui.assistOn = ImGui.Checkbox("Assist", gui.assistOn or false)
    if gui.assistOn then
        gui.tankMelee = false
    end

    if gui.tankMelee then

        gui.stun1 = ImGui.Checkbox("Cease", gui.stun1 or false)

        ImGui.Spacing()
    
        gui.stun2 = ImGui.Checkbox("Desist", gui.stun2 or false)

        ImGui.Spacing()

        ImGui.SetNextItemWidth(100)
                -- Inside your rendering loop or function
        gui.tankRange = ImGui.SliderInt("Tank Range", gui.tankRange, 5, 100)
        
        -- Check if the tank range has changed
        if gui.tankRange ~= previousTankRange then
            mq.cmdf('/mapfilter spellradius %s', gui.tankRange)
            previousTankRange = gui.tankRange
        end


        ImGui.Spacing()

        -- Add Mob to Zone Tank Ignore List Button
        if ImGui.Button("+ Tank Zone Ignore") then
            local utils = require("utils")
            local targetName = mq.TLO.Target.CleanName()
            if targetName then
                utils.addMobToTankIgnoreList(targetName)  -- Add to the zone-specific tank ignore list
                print(string.format("'%s' has been added to the tank ignore list for the current zone.", targetName))
            else
                print("Error: No target selected. Please target a mob to add it to the tank ignore list.")
            end
        end

        -- Remove Mob from Zone Tank Ignore List Button
        if ImGui.Button("- Tank Zone Ignore") then
            local utils = require("utils")
            local targetName = mq.TLO.Target.CleanName()
            if targetName then
                utils.removeMobFromTankIgnoreList(targetName)  -- Remove from the zone-specific tank ignore list
                print(string.format("'%s' has been removed from the tank ignore list for the current zone.", targetName))
            else
                print("Error: No target selected. Please target a mob to remove it from the tank ignore list.")
            end
        end

        -- Add Mob to Global Tank Ignore List Button
        if ImGui.Button("+ Tank Global Ignore") then
            local utils = require("utils")
            local targetName = mq.TLO.Target.CleanName()
            if targetName then
                utils.addMobToTankIgnoreList(targetName, true)  -- Add to the global tank ignore list
                print(string.format("'%s' has been added to the global tank ignore list.", targetName))
            else
                print("Error: No target selected. Please target a mob to add it to the global tank ignore list.")
            end
        end

        -- Remove Mob from Global Tank Ignore List Button
        if ImGui.Button("- Tank Global Ignore") then
            local utils = require("utils")
            local targetName = mq.TLO.Target.CleanName()
            if targetName then
                utils.removeMobFromTankIgnoreList(targetName, true)  -- Remove from the global tank ignore list
                print(string.format("'%s' has been removed from the global tank ignore list.", targetName))
            else
                print("Error: No target selected. Please target a mob to remove it from the global tank ignore list.")
            end
        end
    end

    if gui.assistOn then
        if ImGui.CollapsingHeader("Assist Settings") then
            ImGui.Spacing()
            ImGui.SetNextItemWidth(100)
            gui.mainAssist = ImGui.InputText("Assist Name", gui.mainAssist)
                if ImGui.IsItemDeactivatedAfterEdit() then

                    if gui.mainAssist ~= "" then
                        gui.mainAssist = gui.mainAssist:sub(1, 1):upper() .. gui.mainAssist:sub(2):lower()
                    end
                end

                if gui.mainAssist ~= "" then
                    local spawn = mq.TLO.Spawn(gui.mainAssist)
                    if not (spawn and spawn.Type() == "PC") or gui.mainAssist == charName then
                        ImGui.TextColored(1, 0, 0, 1, "Invalid Target")
                    end
                end

            ImGui.Spacing()

            if gui.mainAssist ~= "" then

                ImGui.Spacing()

                ImGui.SetNextItemWidth(100)
                gui.assistRange = ImGui.SliderInt("Assist Range", gui.assistRange, 5, 200)

                ImGui.Spacing()

                ImGui.SetNextItemWidth(100)
                gui.assistPercent= ImGui.SliderInt("Assist %", gui.assistPercent, 5, 100)

                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                gui.assistOn = ImGui.Checkbox("Melee", gui.assistOn or false)
                if gui.assistOn then

                    ImGui.Spacing()

                    gui.stickFront = ImGui.Checkbox("Front", gui.stickFront or false)
                        if gui.stickFront then
                            gui.stickBehind = false
                        end

                    gui.stickBehind = ImGui.Checkbox("Behind", gui.stickBehind or false)
                        if gui.stickBehind then
                            gui.stickFront = false
                        end

                    ImGui.Spacing()
                    ImGui.Separator()
                    ImGui.Spacing()

                    ImGui.SetNextItemWidth(100)
                    gui.stickDistance = ImGui.SliderInt("Stick Distance", gui.stickDistance, 5, 50)

                    ImGui.Spacing()

                    gui.switchWithMA = ImGui.Checkbox("Switch with MA", gui.switchWithMA or false)
                end
            end
        end
    end

    ImGui.Spacing()
    if ImGui.CollapsingHeader("Nav Settings") then
    ImGui.Spacing()
    
        local previousReturnToCamp = gui.returnToCamp or false
        local previousChaseOn = gui.chaseOn or false

        local currentReturnToCamp = ImGui.Checkbox("Return To Camp", gui.returnToCamp or false)
        if currentReturnToCamp ~= previousReturnToCamp then
            gui.returnToCamp = currentReturnToCamp
                if gui.returnToCamp then
                    gui.chaseOn = false
                else
                    local nav = require('nav')
                    nav.campLocation = nil
                end
            previousReturnToCamp = currentReturnToCamp
        end

        if gui.returnToCamp then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            gui.campDistance = ImGui.SliderInt("Camp Distance", gui.campDistance, 5, 200)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            if ImGui.Button("Camp Here") then
                local nav = require('nav')
                nav.setCamp()
            end
        end

        local currentChaseOn = ImGui.Checkbox("Chase", gui.chaseOn or false)
        if currentChaseOn ~= previousChaseOn then
            gui.chaseOn = currentChaseOn
                if gui.chaseOn then
                    local nav = require('nav')
                    gui.returnToCamp = false
                    nav.campLocation = nil
                    gui.pullOn = false
                end
            previousChaseOn = currentChaseOn
        end

        if gui.chaseOn then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            gui.chaseTarget = ImGui.InputText("Name", gui.chaseTarget)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(100)
            gui.chaseDistance = ImGui.SliderInt("Chase Distance", gui.chaseDistance, 5, 200)
        end
    end

    ImGui.Spacing()
        if ImGui.CollapsingHeader("Misc Settings") then

            ImGui.Spacing()

            gui.dmgUndead = ImGui.Checkbox("Smite Undead", gui.dmgUndead or false)

            ImGui.Spacing()
        
            gui.buffsOn = ImGui.Checkbox("Buffs", gui.buffsOn or false)

            ImGui.Spacing()

            gui.layOnHands = ImGui.Checkbox("Lay On Hands", gui.layOnHands or false)

            ImGui.Spacing()

            gui.sitMed = ImGui.Checkbox("Sit Med", gui.sitMed or false)

            ImGui.Spacing()
    end

    ImGui.End()
end

gui.controlGUI = controlGUI

return gui