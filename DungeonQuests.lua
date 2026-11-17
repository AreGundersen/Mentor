--------------------------------------------------------------------------------
-- Mentor - DungeonQuests.lua
-- Quests that belong to each dungeon and give gear, from the "Quests" lists
-- of Wowhead's WoW Forever zone pages (Nov 2026).
--   [dungeon name as in Journey.lua] = {
--       { quest id, "quest name", side (1 Alliance, 2 Horde, 3 both),
--         { items you always get }, { items you choose one of } }, ... }
-- Used by Upgrades.lua; quests you have done are skipped.
--------------------------------------------------------------------------------

local _, Mentor = ...

Mentor.DUNGEON_QUESTS = {
    ["Alcaz Island Prison"] = {
        { 95483, "Thrall Needs to Know", 2, {}, { 279831, 279833, 279474 } },
        { 96332, "A Little Payback", 2, {}, { 279824, 279826, 279829 } },
        { 96334, "Blood Red Bandanas", 2, {}, { 279448, 279473 } },
        { 96337, "More Valuable Than Gold", 3, { 274041 }, {} },
        { 96376, "State Secrets", 2, {}, { 279450 } },
        { 96377, "State Secrets", 1, {}, { 279450 } },
        { 96379, "State Secrets", 3, {}, { 279450 } },
        { 96381, "A Bit of Wet Work", 1, {}, { 279825, 279826, 279829 } },
    },
    ["Blackrock Depths"] = {
        { 3802, "Dark Iron Legacy", 3, { 11000 }, {} },
        { 3907, "Disharmony of Fire", 2, {}, { 12113, 12114, 12112, 12115 } },
        { 3911, "The Last Element", 3, { 12038 }, {} },
        { 4004, "The Princess Saved?", 3, {}, { 12544, 12545 } },
        { 4024, "A Taste of Flame", 3, {}, { 12066, 12082, 12083 } },
        { 4063, "The Rise of the Machines", 2, {}, { 12109, 12110, 12108, 12111 } },
        { 4126, "Hurley Blackbreath", 1, { 12003 }, { 11964, 12000, 270123 } },
        { 4132, "Operation: Death to Angerforge", 2, {}, { 12059, 270126 } },
        { 4134, "Lost Thunderbrew Recipe", 2, { 3928, 6149 }, { 11964, 12000, 270123 } },
        { 4136, "Ribbly Screwspigot", 3, {}, { 11865, 11963, 12049 } },
        { 4201, "The Love Potion", 3, {}, { 11962, 11866, 270120, 270121 } },
        { 4242, "Abandoned Hope", 1, {}, { 12018, 12021, 12041, 270118 } },
        { 4263, "Incendius!", 1, {}, { 12113, 12114, 12112, 12115 } },
        { 4286, "The Good Stuff", 1, { 11883 }, {} },
        { 4322, "Jail Break!", 1, { 12065 }, { 12061, 12062 } },
        { 4363, "The Princess's Surprise", 1, {}, { 12548, 12543 } },
        { 7201, "The Last Element", 2, {}, { 12038, 270119 } },
        { 7604, "A Binding Contract", 3, { 18592 }, {} },
        { 82062, "Ever After", 3, { 221316, 216619, 221315 }, {} },
    },
    ["Dire Maul"] = {
        { 1318, "Unfinished Gordok Business", 3, {}, { 18366, 18367, 18368, 18369 } },
        { 5518, "The Gordok Ogre Suit", 3, { 18258 }, {} },
        { 5528, "The Gordok Taste Test", 3, { 18269, 18284 }, {} },
        { 7441, "Pusillin and the Elder Azj'Tordin", 3, {}, { 18411, 18410, 270127 } },
        { 7462, "The Treasure of the Shen'dralar", 3, {}, { 18420, 18421, 18424 } },
        { 7488, "Lethtendris's Web", 1, {}, { 18491, 270124, 270125 } },
        { 7489, "Lethtendris's Web", 2, {}, { 18491, 270124, 270125 } },
        { 7509, "The Forging of Quel'Serrar", 3, { 18348 }, {} },
        { 7703, "Unfinished Gordok Business", 3, {}, { 18366, 18367, 18368, 18369 } },
        { 7877, "The Treasure of the Shen'dralar", 3, {}, { 18420, 18421, 18424 } },
        { 8949, "Falrin's Vendetta", 3, {}, { 22150, 22149 } },
    },
    ["Lower Blackrock Spire"] = {
        { 4701, "Put Her Down", 1, {}, { 15824, 15825, 15827 } },
        { 4724, "The Pack Mistress", 2, {}, { 15824, 15825, 15827 } },
        { 4729, "Kibler's Exotic Pets", 3, { 12264 }, {} },
        { 4765, "Delivery to Ridgewell", 1, {}, { 15861, 15860 } },
        { 4768, "The Darkstone Tablet", 2, {}, { 15861, 15860 } },
        { 4862, "En-Ay-Es-Tee-Why", 3, { 12529 }, {} },
        { 4866, "Mother's Milk", 3, { 15873 }, {} },
        { 4867, "Urok Doomhowl", 3, { 15867 }, {} },
        { 4903, "Warlord's Command", 2, {}, { 13958, 13959, 13961, 13962, 13963 } },
        { 4983, "Bijou's Reconnaissance Report", 2, {}, { 15858, 15859 } },
        { 5081, "Maxwell's Mission", 1, {}, { 13958, 13959, 13961, 13962, 13963 } },
        { 5127, "The Demon Forge", 3, { 12696, 9224, 12849 }, {} },
    },
    ["Maraudon"] = {
        { 7028, "Twisted Evils", 3, {}, { 17775, 17776, 17777, 17779 } },
        { 7029, "Vyletongue Corruption", 2, {}, { 17768, 17778, 17770 } },
        { 7041, "Vyletongue Corruption", 1, {}, { 17768, 17778, 17770 } },
        { 7046, "The Scepter of Celebras", 3, { 17191 }, {} },
        { 7064, "Corruption of Earth and Seed", 2, {}, { 17705, 17743, 17753 } },
        { 7065, "Corruption of Earth and Seed", 1, {}, { 17705, 17743, 17753 } },
        { 7067, "The Pariah's Instructions", 3, { 17774 }, {} },
        { 7068, "Shadowshard Fragments", 2, {}, { 17772, 17773 } },
        { 7070, "Shadowshard Fragments", 1, {}, { 17772, 17773 } },
        { 93404, "Rot and Regret", 3, {}, { 272186, 272187 } },
    },
    ["The Temple of Atal'Hakkar"] = {
        { 1445, "The Temple of Atal'Hakkar", 2, { 1490 }, {} },
        { 1446, "Jammal'an the Prophet", 3, {}, { 11123, 11124, 270115 } },
        { 1475, "Into The Temple of Atal'Hakkar", 1, { 1490 }, {} },
        { 3373, "The Essence of Eranikus", 3, { 10455 }, {} },
        { 3447, "Secret of the Circle", 3, { 10773 }, {} },
        { 3528, "The God Hakkar", 3, {}, { 10749, 10750, 10751, 270117 } },
    },
    ["Upper Blackrock Spire"] = {
        { 4734, "Egg Freezing", 3, { 12144 }, {} },
        { 4743, "Seal of Ascension", 3, { 12344 }, {} },
        { 4974, "For The Horde!", 2, {}, { 13966, 13968, 13965 } },
        { 5102, "General Drakkisath's Demise", 1, {}, { 13966, 13968, 13965 } },
        { 6502, "Drakefire Amulet", 1, { 16309 }, {} },
        { 6602, "Blood of the Black Dragon Champion", 2, { 16309 }, {} },
    },
    ["Zul'Farrak"] = {
        { 2768, "Divino-matic Rod", 3, {}, { 9533, 9534, 270099 } },
        { 2770, "Gahz'rilla", 3, { 11122 }, {} },
        { 2846, "Tiara of the Deep", 3, { 9527 }, { 9531, 270098 } },
    },
}
