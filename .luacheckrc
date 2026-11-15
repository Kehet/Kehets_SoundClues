std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "Libs/**",
}

-- Saved variables and slash command registrations
globals = {
    "SLASH_KEHETSSOUNDCLUES1",
    "SLASH_KEHETSSOUNDCLUES2",
    "SlashCmdList",
    "SoundCluesDB",
}

-- WoW API, FrameXML and libraries
read_globals = {
    "issecretvalue",
    "C_Secrets",
    "C_UnitAuras",
    "CreateFrame",
    "CreateSettingsListSectionHeaderInitializer",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "IsInGroup",
    "IsInInstance",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",
    "IsInRaid",
    "LibStub",
    "PlaySound",
    "PlaySoundFile",
    "RAID_CLASS_COLORS",
    "Settings",
    "strtrim",
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
