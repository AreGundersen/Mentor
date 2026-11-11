--------------------------------------------------------------------------------
-- Mentor - Glossary.lua
-- The "Words" tab (ExtrasUI.lua): what the words you see in group chat mean.
--------------------------------------------------------------------------------

local _, Mentor = ...

local WORD_ICON = "Interface\\Icons\\INV_Misc_Book_09"

-- { word, meaning } - in the order a new player meets them.
local GLOSSARY_WORDS = {
    { "Aggro / threat", "Who a mob attacks. It attacks whoever has the most threat - damage and healing make threat, the tank makes the most on purpose." },
    { "Pull", "Starting a fight with a mob or a group of mobs. \"Don't pull\" means wait for the tank." },
    { "Add", "An extra mob that joins a fight you already are in." },
    { "Tank", "The player who takes the hits and keeps the mobs' aggro: warrior, paladin, druid in bear form." },
    { "Healer / DPS", "Healer keeps the group alive. DPS (damage per second) are the players who kill the mobs." },
    { "CC (crowd control)", "Taking a mob out of the fight for a while: Polymorph (sheep), Sap, Fear, Freezing Trap, Shackle. Don't attack a CC'd mob." },
    { "Kite", "Keeping a mob chasing you while you hit it from range, so it never reaches you." },
    { "Wipe", "The whole group dies. Everyone runs back and tries again." },
    { "OOM", "Out of mana. When the healer says it, stop and let them drink." },
    { "LFG / LFM", "Looking for group / looking for more - used when asking for a dungeon group in chat." },
    { "Inc", "Incoming: mobs are coming at you." },
    { "Rested", "Bonus XP you build up while logged out in an inn or a city: your kills give double XP until it is used." },
    { "Elite", "A strong mob with a gold dragon frame - made for a group." },
    { "BoP / BoE", "Bind on Pickup (yours once you loot it) and Bind on Equip (can be traded until someone wears it)." },
    { "Need / Greed", "Roll Need only on loot you will wear. Greed is for everything else." },
    { "Res / rez", "Resurrect: bringing a dead player back to life." },
    { "Buff / debuff", "A good effect on you (buff) or a bad one (debuff)." },
    { "Proc", "A random effect that sometimes happens when you hit or cast." },
    { "Cooldown (CD)", "The time before you can use an ability again." },
}

local glossary = {}
Mentor.Glossary = glossary

function glossary.GetEntries()
    local entries = {}
    for _, glossaryWord in ipairs(GLOSSARY_WORDS) do
        table.insert(entries, { kind = "journey", name = glossaryWord[1], icon = WORD_ICON, levelText = "",
            tag = "", description = glossaryWord[2] })
    end
    return entries
end
