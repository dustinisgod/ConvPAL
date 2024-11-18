mq = require('mq')
local gui = require('gui')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local spells = {
    Stun1 = {
        {level = 7, name = "Cease"}
    },
    Stun2 = {
        {level = 13, name = "Desist"}
    },
    DmgUndead = {
        {level = 54, name = "Expel Undead"},
        {level = 46, name = "Dismiss Undead"},
        {level = 30, name = "Expulse Undead"},
        {level = 14, name = "Ward Undead"}
    },
    SelfAtkBuff = {
        {level = 59, name = "Yaulp IV"},
        {level = 56, name = "Yaulp III"},
        {level = 38, name = "Yaulp II"},
        {level = 9, name = "Yaulp"}
    },
    SelfProcBuff = {
        {level = 45, name = "Divine Might"}
    },
    HPBuff = {
        {level = 60, name = "Brell's Mountainous Barrier"},
        {level = 60, name = "Divine Strength"},
        {level = 60, name = "Divine Brawn"},
        {level = 55, name = "Divine Favor"}
    },
    SelfShielding = {
        {level = 60, name = "Armor of the Crusader"}
    },
    Resurrection = {
        {level = 22, name = "Reanimation"}
    }
}

-- Function to find the best spell for a given type and level
function spells.findBestSpell(spellType, charLevel)
    local spells = spells[spellType]

    if not spells then
        return nil -- Return nil if the spell type doesn't exist
    end

    if spellType == "HPBuff" and charLevel == 60 then
        if mq.TLO.Me.Book("Brell's Mountainous Barrier")() then
            return "Brell's Mountainous Barrier"
        elseif mq.TLO.Me.Book("Divine Strength")() and not mq.TLO.Me.Book("Brell's Mountainous Barrier")() then
            return "Divine Strength"
        elseif mq.TLO.Me.Book("Divine Brawn")() and not mq.TLO.Me.Book("Divine Strength")() and not mq.TLO.Me.Book("Brell's Mountainous Barrier")() then
            return "Divine Brawn"
        elseif mq.TLO.Me.Book("Divine Favor")() and not mq.TLO.Me.Book("Divine Brawn")() and not mq.TLO.Me.Book("Divine Strength")() and not mq.TLO.Me.Book("Brell's Mountainous Barrier")()then
            return "Divine Favor"
        end
    end

    -- General spell search for other types and levels
    for _, spell in ipairs(spells) do
        if charLevel >= spell.level then
            return spell.name
        end
    end

    return nil
end

function spells.loadDefaultSpells(charLevel)
    local defaultSpells = {}

    if gui.stun1 and charLevel >= 7 then
        defaultSpells[1] = spells.findBestSpell("Stun1", charLevel)
    end
    if gui.stun2 and charLevel >= 13 then
        defaultSpells[2] = spells.findBestSpell("Stun2", charLevel)
    end
    if gui.dmgUndead and charLevel >= 14 then
        defaultSpells[3] = spells.findBestSpell("DmgUndead", charLevel)
    end
    if charLevel >= 9 then
        defaultSpells[4] = spells.findBestSpell("SelfAtkBuff", charLevel)
    end
    if charLevel >= 45 then
        defaultSpells[5] = spells.findBestSpell("SelfProcBuff", charLevel)
    end
    if charLevel >= 55 then
        defaultSpells[6] = spells.findBestSpell("HPBuff", charLevel)
    end
    if charLevel >= 60 then
        defaultSpells[7] = spells.findBestSpell("SelfShielding", charLevel)
    end
    if charLevel >= 22 then
        defaultSpells[8] = spells.findBestSpell("Resurrection", charLevel)
    end
    return defaultSpells
end

-- Function to memorize spells in the correct slots with delay
function spells.memorizeSpells(spells)
    for slot, spellName in pairs(spells) do
        if spellName then
            -- Check if the spell is already in the correct slot
            if mq.TLO.Me.Gem(slot)() == spellName then
                printf(string.format("Spell %s is already memorized in slot %d", spellName, slot))
            else
                -- Clear the slot first to avoid conflicts
                mq.cmdf('/mem "" %d', slot)
                mq.delay(500)  -- Short delay to allow the slot to clear

                -- Issue the /mem command to memorize the spell in the slot
                mq.cmdf('/mem "%s" %d', spellName, slot)
                mq.delay(500)  -- Initial delay to allow the memorization command to take effect

                -- Loop to check if the spell is correctly memorized
                local maxAttempts = 10
                local attempt = 0
                while mq.TLO.Me.Gem(slot)() ~= spellName and attempt < maxAttempts do
                    mq.delay(2000)  -- Check every 0.5 seconds
                    attempt = attempt + 1
                end

                -- Check if memorization was successful
                if mq.TLO.Me.Gem(slot)() ~= spellName then
                    printf(string.format("Failed to memorize spell: %s in slot %d", spellName, slot))
                else
                    printf(string.format("Successfully memorized %s in slot %d", spellName, slot))
                end
            end
        end
    end
end


function spells.loadAndMemorizeSpell(spellType, level, spellSlot)

    local bestSpell = spells.findBestSpell(spellType, level)

    if not bestSpell then
        printf("No spell found for type: " .. spellType .. " at level: " .. level)
        return
    end

    -- Check if the spell is already in the correct spell gem slot
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Spell " .. bestSpell .. " is already memorized in slot " .. spellSlot)
        return true
    end

    -- Memorize the spell in the correct slot
    mq.cmdf('/mem "%s" %d', bestSpell, spellSlot)

    -- Add a delay to wait for the spell to be memorized
    local maxAttempts = 10
    local attempt = 0
    while mq.TLO.Me.Gem(spellSlot).Name() ~= bestSpell and attempt < maxAttempts do
        mq.delay(2000) -- Wait 2 seconds before checking again
        attempt = attempt + 1
    end

    -- Check if the spell is now memorized correctly
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Successfully memorized spell " .. bestSpell .. " in slot " .. spellSlot)
        return true
    else
        printf("Failed to memorize spell " .. bestSpell .. " in slot " .. spellSlot)
        return false
    end
end

function spells.startup(charLevel)

    local defaultSpells = spells.loadDefaultSpells(charLevel)

    spells.memorizeSpells(defaultSpells)
end

return spells