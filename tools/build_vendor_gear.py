"""Builds Mentor's VendorGear.lua from Questie's classic database (v9.5.2):
weapons and armor sold by vendors for gold, the NPCs that sell them, and where those NPCs stand."""
import re, json

ITEM_DB = "classicItemDB.lua"  # Questie v9.5.2: Database/Classic/classicItemDB.lua
NPC_DB = "classicNpcDB.lua"
ZONE_LOOKUP = "lookupZones.lua"
OUTPUT = "/home/claude/mentor/VendorGear.lua"
WEAPON_CLASS, ARMOR_CLASS = 2, 4
# Vendors that want reputation, honor or tokens rather than only gold.
EXCLUDED_SUBNAME_WORDS = ("Quartermaster", "Officer", "Legion", "Honor", "Supply", "Exchange", "Provisioner", "Emissary")

def split_top_level(text):
    """Splits '{a,{b,c},'x,y'}' contents at top-level commas."""
    parts, depth, current, in_string, quote = [], 0, "", False, ""
    index = 0
    while index < len(text):
        char = text[index]
        if in_string:
            current += char
            if char == "\\":
                current += text[index + 1]; index += 1
            elif char == quote:
                in_string = False
        elif char in "'\"":
            in_string, quote = True, char; current += char
        elif char == "{":
            depth += 1; current += char
        elif char == "}":
            depth -= 1; current += char
        elif char == "," and depth == 0:
            parts.append(current); current = ""
        else:
            current += char
        index += 1
    parts.append(current)
    return parts

def unquote(value):
    value = value.strip()
    if value == "nil":
        return None
    if value[:1] in "'\"":
        return value[1:-1].replace("\\'", "'").replace('\\"', '"')
    return value

def read_rows(path):
    """Yields (id, fields) for each '[id] = {...},' line."""
    for line in open(path, encoding="utf-8"):
        match = re.match(r"\[(\d+)\] = \{(.*)\},\s*$", line)
        if match:
            yield int(match.group(1)), split_top_level(match.group(2))

def number_list(value):
    value = (value or "").strip()
    return [int(n) for n in re.findall(r"-?\d+", value)] if value.startswith("{") else []

zone_names = {int(z): n for z, n in re.findall(r"^\s*\[(\d+)\]=\"([^\"]+)\"", open(ZONE_LOOKUP, encoding="utf-8").read(), re.M)}

npcs = {}
for npc_id, fields in read_rows(NPC_DB):
    fields += ["nil"] * (15 - len(fields))
    name, friendly, subname = unquote(fields[0]), unquote(fields[12]), unquote(fields[13]) or ""
    spawns_text = fields[6].strip()
    first_spawn = re.search(r"\[(\d+)\]=\{\{([\d.]+),([\d.]+)\}", spawns_text)
    if not first_spawn:
        continue
    zone_id, x, y = int(first_spawn.group(1)), float(first_spawn.group(2)), float(first_spawn.group(3))
    if any(word in subname for word in EXCLUDED_SUBNAME_WORDS) or not friendly:
        continue
    npcs[npc_id] = {"name": name, "friendly": friendly, "zone": zone_id, "x": x, "y": y, "subname": subname}

items, used_vendors = {}, set()
for item_id, fields in read_rows(ITEM_DB):
    if len(fields) < 14:  # rows end early when the last fields are nil: no vendors
        continue
    item_class = unquote(fields[11]); required_level = unquote(fields[9])
    if item_class is None or int(item_class) not in (WEAPON_CLASS, ARMOR_CLASS):
        continue
    vendors = [npc for npc in number_list(fields[13]) if npc in npcs and npcs[npc]["zone"] in zone_names]
    if not vendors:
        continue
    items[item_id] = {"level": int(required_level or 0), "vendors": vendors}
    used_vendors.update(vendors)

def q(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'

lines = ["--------------------------------------------------------------------------------",
         "-- Mentor - VendorGear.lua (generated, do not edit by hand)",
         "-- Weapons and armor sold by vendors for gold, who sells them and where.",
         "-- From Questie's classic database (v9.5.2, github.com/Questie/Questie): the",
         "-- original WoW vendors. Vendors that want reputation, honor or tokens are",
         "-- left out. Upgrades.lua checks quality and stats in game.",
         "--   Mentor.VENDOR_GEAR[item id] = { required level, vendor id, vendor id, ... }",
         "--   Mentor.GEAR_VENDORS[vendor id] = { \"name\", \"A\"/\"H\"/\"AH\" (friendly to), zone id, x, y }",
         "--   Mentor.VENDOR_ZONE_NAMES[zone id] = \"zone name\"",
         "--------------------------------------------------------------------------------",
         "", "local _, Mentor = ...", "", "Mentor.VENDOR_GEAR = {"]
for item_id in sorted(items):
    entry = items[item_id]
    lines.append(f"    [{item_id}] = {{ {entry['level']}, {', '.join(str(v) for v in entry['vendors'])} }},")
lines += ["}", "", "Mentor.GEAR_VENDORS = {"]
for npc_id in sorted(used_vendors):
    npc = npcs[npc_id]
    lines.append(f"    [{npc_id}] = {{ {q(npc['name'])}, \"{npc['friendly']}\", {npc['zone']}, {npc['x']}, {npc['y']} }},")
lines += ["}", "", "Mentor.VENDOR_ZONE_NAMES = {"]
for zone_id in sorted({npcs[n]["zone"] for n in used_vendors}):
    lines.append(f"    [{zone_id}] = {q(zone_names[zone_id])},")
lines.append("}")
open(OUTPUT, "w").write("\n".join(lines) + "\n")
print(len(items), "items,", len(used_vendors), "vendors,", len({npcs[n]['zone'] for n in used_vendors}), "zones")
