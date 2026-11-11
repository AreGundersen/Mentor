--------------------------------------------------------------------------------
-- Mentor - Weapons.lua
-- Data for the Weapons tab (ExtrasUI.lua): every weapon type your class can
-- learn, whether you know it already, and which weapon master in your
-- faction's cities teaches it (10 silver each in classic).
-- Weapon masters are the classic ones; WoW Forever keeps the classic cities.
--------------------------------------------------------------------------------

local _, Mentor = ...

-- Weapon types: spell id of the weapon skill (to see if you know it), icon.
local WEAPON_TYPES = {
    ["Daggers"]            = { spellId = 1180,  icon = "Interface\\Icons\\INV_Weapon_ShortBlade_05" },
    ["Fist Weapons"]       = { spellId = 15590, icon = "Interface\\Icons\\INV_Gauntlets_04" },
    ["One-Handed Axes"]    = { spellId = 196,   icon = "Interface\\Icons\\INV_Axe_01" },
    ["Two-Handed Axes"]    = { spellId = 197,   icon = "Interface\\Icons\\INV_Axe_09" },
    ["One-Handed Maces"]   = { spellId = 198,   icon = "Interface\\Icons\\INV_Mace_01" },
    ["Two-Handed Maces"]   = { spellId = 199,   icon = "Interface\\Icons\\INV_Hammer_16" },
    ["One-Handed Swords"]  = { spellId = 201,   icon = "Interface\\Icons\\INV_Sword_04" },
    ["Two-Handed Swords"]  = { spellId = 202,   icon = "Interface\\Icons\\INV_Sword_06" },
    ["Polearms"]           = { spellId = 200,   icon = "Interface\\Icons\\INV_Spear_06" },
    ["Staves"]             = { spellId = 227,   icon = "Interface\\Icons\\INV_Staff_08" },
    ["Bows"]               = { spellId = 264,   icon = "Interface\\Icons\\INV_Weapon_Bow_05" },
    ["Crossbows"]          = { spellId = 5011,  icon = "Interface\\Icons\\INV_Weapon_Crossbow_01" },
    ["Guns"]               = { spellId = 266,   icon = "Interface\\Icons\\INV_Weapon_Rifle_01" },
    ["Thrown"]             = { spellId = 2567,  icon = "Interface\\Icons\\INV_ThrowingKnife_02" },
    ["Wands"]              = { spellId = 5009,  icon = "Interface\\Icons\\INV_Wand_01" },
}

-- What each class can learn (classic rules).
local CLASS_WEAPONS = {
    WARRIOR = { "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces",
                "One-Handed Swords", "Two-Handed Swords", "Polearms", "Staves", "Bows", "Crossbows", "Guns", "Thrown" },
    PALADIN = { "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces",
                "One-Handed Swords", "Two-Handed Swords", "Polearms" },
    HUNTER  = { "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "One-Handed Swords", "Two-Handed Swords",
                "Polearms", "Staves", "Bows", "Crossbows", "Guns", "Thrown" },
    ROGUE   = { "Daggers", "Fist Weapons", "One-Handed Maces", "One-Handed Swords", "Bows", "Crossbows", "Guns", "Thrown" },
    PRIEST  = { "Daggers", "One-Handed Maces", "Staves", "Wands" },
    SHAMAN  = { "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "Staves" },
    MAGE    = { "Daggers", "One-Handed Swords", "Staves", "Wands" },
    WARLOCK = { "Daggers", "One-Handed Swords", "Staves", "Wands" },
    DRUID   = { "Daggers", "Fist Weapons", "One-Handed Maces", "Two-Handed Maces", "Staves" },
}

-- Weapon masters: { name, city, faction, weapons they teach }.
local WEAPON_MASTERS = {
    { "Woo Ping", "Stormwind, Trade District", "Alliance",
      { "Daggers", "Staves", "One-Handed Swords", "Two-Handed Swords", "Crossbows", "Polearms" } },
    { "Buliwyf Stonehand", "Ironforge, Military Ward", "Alliance",
      { "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "Guns" } },
    { "Ilyenia Moonfire", "Darnassus, Warrior's Terrace", "Alliance",
      { "Bows", "Daggers", "Fist Weapons", "Staves", "Thrown" } },
    { "Sayoc", "Orgrimmar, Valley of Honor", "Horde",
      { "Bows", "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "Thrown" } },
    { "Hanashi", "Orgrimmar, Valley of Honor", "Horde",
      { "Bows", "One-Handed Axes", "Two-Handed Axes", "Staves", "Thrown" } },
    { "Archibald", "Undercity, War Quarter", "Horde",
      { "Crossbows", "Daggers", "One-Handed Swords", "Two-Handed Swords", "Polearms" } },
    { "Ansekhwa", "Thunder Bluff, Lower Rise", "Horde",
      { "Guns", "One-Handed Maces", "Two-Handed Maces", "Staves" } },
}

local TRAINING_COST_COPPER = 1000     -- 10 silver per weapon type at a weapon master

local weapons = {}
Mentor.Weapons = weapons

local function IsWeaponKnown(weaponName)
    local weaponType = WEAPON_TYPES[weaponName]
    if not weaponType then
        return false
    end
    for _, checkFunction in ipairs({ IsPlayerSpell, IsSpellKnown }) do
        if checkFunction then
            local success, isKnown = pcall(checkFunction, weaponType.spellId)
            if success and isKnown then
                return true
            end
        end
    end
    return false
end
weapons.IsWeaponKnown = IsWeaponKnown

-- Weapon masters in your faction that teach this weapon: "Woo Ping (Stormwind, Trade District".
local function GetTeachers(weaponName, playerFaction)
    local teachers = {}
    for _, master in ipairs(WEAPON_MASTERS) do
        if master[3] == playerFaction then
            for _, taughtWeapon in ipairs(master[4]) do
                if taughtWeapon == weaponName then
                    table.insert(teachers, master[1] .. " (" .. master[2] .. ")")
                end
            end
        end
    end
    return teachers
end

-- Rows for ExtrasUI: weapons to learn first, then the ones you know.
function weapons.GetEntries(advice)
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    local toLearn, known = {}, {}
    for _, weaponName in ipairs(CLASS_WEAPONS[advice.classFileName] or {}) do
        local weaponType = WEAPON_TYPES[weaponName]
        if IsWeaponKnown(weaponName) then
            table.insert(known, { kind = "journey", name = weaponName, icon = weaponType.icon, levelText = "",
                tag = "|cff40ff40Known|r", description = "|cffa6a6a6You can use these already.|r" })
        else
            local teachers = GetTeachers(weaponName, playerFaction)
            local description = #teachers > 0
                and ("Weapon master: " .. table.concat(teachers, " or ") .. ".")
                or "Ask a city guard for a weapon master (another faction's city may teach it)."
            -- The price stands out on the right, with the game's coin icons.
            local priceText = Mentor.FormatMoneyWithIcons(TRAINING_COST_COPPER)
            table.insert(toLearn, { kind = "journey", name = weaponName, icon = weaponType.icon, levelText = "",
                tag = "|cffff9933Learn|r  |cffffffff" .. priceText .. "|r", description = description })
        end
    end
    for _, knownEntry in ipairs(known) do
        table.insert(toLearn, knownEntry)
    end
    return toLearn
end
