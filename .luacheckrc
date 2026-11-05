std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "Libs/**",
}

-- WoW API, FrameXML and libraries
read_globals = {
    "issecretvalue",
    "C_UnitAuras",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "IsInGroup",
    "IsInInstance",
    "IsInRaid",
    "LibStub",
    "PlaySound",
    "PlaySoundFile",
    "RAID_CLASS_COLORS",
    "tContains",
    "UnitAffectingCombat",
    "UnitClass",
    "UnitGroupRolesAssigned",
    "UnitGUID",
    "UnitInParty",
    "UnitInRaid",
    "UnitIsDeadOrGhost",
    "UnitIsFeignDeath",
    "UnitName",
    "UNKNOWNOBJECT",
}
