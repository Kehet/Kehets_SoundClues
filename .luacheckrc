std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "Libs/**",
}

-- Globals the addon defines itself
globals = {
    "GetUnitFromGUID",
}

-- WoW API, FrameXML and libraries
read_globals = {
    "C_CombatLog",
    "C_UnitAuras",
    "IsInRaid",
    "LibStub",
    "PlaySoundFile",
    "RAID_CLASS_COLORS",
    "tContains",
    "UnitAffectingCombat",
    "UnitClass",
    "UnitGroupRolesAssigned",
    "UnitGUID",
    "UnitInParty",
    "UnitInRaid",
    "UnitIsFeignDeath",
    "UnitName",
}
