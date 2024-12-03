local mq = require('mq')
local utils = require('utils')
local commands = require('commands')
local gui = require('gui')
local nav = require('nav')
local spells = require('spells')
local tank = require('tank')
local assist = require('assist')

local class = mq.TLO.Me.Class()
if class ~= "Paladin" then
    print("This script is only for Paladin.")
    mq.exit()
end

local currentLevel = mq.TLO.Me.Level()

utils.PluginCheck()

mq.cmd('/assist off')

mq.imgui.init('controlGUI', gui.controlGUI)

commands.init()
commands.initALL()

local startupRun = false

-- Function to check the botOn status and run startup once
local function checkBotOn(currentLevel)
    if gui.botOn and not startupRun then
        nav.setCamp()
        spells.startup(currentLevel)
        startupRun = true  -- Set flag to prevent re-running
        printf("Bot has been turned on. Running startup.")

        local buffer = require('buffer')
        if gui.buffsOn then
            buffer.buffRoutine()
        end
        local selfbuffer = require('selfbuffer')
        if gui.buffsOn then
            selfbuffer.selfBuffRoutine()
        end

    elseif not gui.botOn and startupRun then
        -- Optional: Reset the flag if bot is turned off
        startupRun = false
    end
end

local toggleboton = false
local function returnChaseToggle()
    -- Check if bot is on and return-to-camp is enabled, and only set camp if toggleboton is false
    if gui.botOn and gui.returntocamp and not toggleboton then
        nav.setCamp()
        toggleboton = true
    elseif not gui.botOn and toggleboton then
        -- Clear camp if bot is turned off after being on
        nav.clearCamp()
        toggleboton = false
    end
end

utils.loadTankConfig()

while gui.controlGUI do

    returnChaseToggle()

    if gui.botOn then

        checkBotOn(currentLevel)

        utils.monitorNav()

        if gui.sitMed then
            utils.sitMed()
        end

        if gui.tankOn then
            tank.tankRoutine()
        elseif gui.assistOn then
            assist.assistRoutine()
        end

        if gui.buffsOn then
            utils.monitorBuffs()
        end

        local newLevel = mq.TLO.Me.Level()
        if newLevel ~= currentLevel then
            printf(string.format("Level has changed from %d to %d. Updating spells.", currentLevel, newLevel))
            spells.startup(newLevel)
            currentLevel = newLevel
        end
    end

    mq.doevents()
    mq.delay(100)
end