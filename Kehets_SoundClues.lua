local SoundClues = LibStub("AceAddon-3.0"):NewAddon("Kehet's SoundClues", "AceConsole-3.0", "AceEvent-3.0", "LibKehetsVerbosity-1.0")

-- Messages the player can turn off or move in the Messages settings
SoundClues:RegisterMessageTypes({
    banner = {
        name = "Login message",
        desc = "The line that says the addon is enabled.",
        order = 1,
    },
    death = {
        name = "Death messages",
        desc = "The line that says which group member died. The death alert sounds have their own settings.",
        order = 2,
    },
    leave = {
        name = "Leave messages",
        desc = "The line that says which player left the group. The leave alert sound has its own setting.",
        order = 3,
    },
})

local soundFiles = {
    DAMAGER = "Sound\\interface\\iCreateCharacterA.ogg",
    HEALER = "Sound\\Event Sounds\\Wisp\\WispPissed1.ogg",
    TANK = "Sound\\interface\\igQuestFailed.ogg",
}

local DRINK_SPELL_ID = {
    10250, 25696, 26261, 26402, 26473, 26475, 30024, 46755, 57073, 61830, 64356, 66041, 69176, 72623, 87958, 87959,
    92736, 92797, 92800, 92803, 104262, 104269, 105230, 105590, 114731, 130335, 130336, 130337, 130338, 130339,
    130340, 130341, 1216892, 43155, 118359, 104270
}

function SoundClues:OnEnable()
    self:Notify("banner", "Enabled - Use /sc or /soundclues to open the settings")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEventUnfiltered")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:OnGroupRosterUpdate()
    if self.db.profile.drinkingActive then
        self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    end
end

function SoundClues:OnDisable()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("UNIT_AURA")
end

local function ColorName(name, className)
    local classColor = RAID_CLASS_COLORS[className]
    if not classColor then
        return name
    end
    return string.format("|cFF%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
end

function SoundClues:OnCombatLogEventUnfiltered()
    local _, eventType, _, _, _, _, _, destGUID = C_CombatLog.GetCurrentEventInfo()

    if eventType ~= "UNIT_DIED" then
        return
    end

    local unit = GetUnitFromGUID(destGUID)

    if unit == nil then
        return
    end

    if UnitIsFeignDeath(unit) then
        return
    end

    if UnitInParty(unit) or UnitInRaid(unit) then
        if unit then
            local role = UnitGroupRolesAssigned(unit)
            local playerName = UnitName(unit)
            local _, className = UnitClass(unit)
            local coloredName = ColorName(playerName, className)

            -- Convert role to display text
            local roleText = "DPS"
            if role == "HEALER" then
                roleText = "Healer"
            elseif role == "TANK" then
                roleText = "Tank"
            end

            local message = string.format("%s (%s) has died!", coloredName, roleText)
            self:Notify("death", message)

            local shouldPlaySound = false

            if role == "TANK" and self.db.profile.tankActive then
                shouldPlaySound = true
            elseif role == "HEALER" and self.db.profile.healerActive then
                shouldPlaySound = true
            elseif role == "DAMAGER" and self.db.profile.dpsActive then
                shouldPlaySound = true
            elseif (not role or not soundFiles[role]) and self.db.profile.unknownActive then
                shouldPlaySound = true
            end

            if shouldPlaySound then
                if role and soundFiles[role] then
                    PlaySoundFile(soundFiles[role], "Master")
                else
                    PlaySoundFile(soundFiles["DAMAGER"], "Master")
                end
            end
        end
    end
end

function GetUnitFromGUID(guid)
    local units = {"party1", "party2", "party3", "party4"}
    if IsInRaid() then
        for i = 1, 40 do
            table.insert(units, "raid"..i)
        end
    end

    for _, unit in ipairs(units) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end

    return nil
end

-- Group members from the last roster update, by GUID, so a member can still be named after they leave
local groupMembers = {}

-- Returns nil while a member is not loaded yet, so a half-loaded roster does not look like people leaving
local function ReadRoster()
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end

    local playerGUID = UnitGUID("player")
    local roster = {}
    for i = 1, count do
        local unit = prefix .. i
        local guid = UnitGUID(unit)
        local name = UnitName(unit)
        if not guid or not name or name == UNKNOWNOBJECT then
            return nil
        end
        if guid ~= playerGUID then
            local _, className = UnitClass(unit)
            roster[guid] = { name = name, className = className }
        end
    end
    return roster
end

function SoundClues:OnGroupRosterUpdate()
    -- When the player leaves or the group disbands, nobody else left
    if not IsInGroup() then
        groupMembers = {}
        return
    end

    local roster = ReadRoster()
    if not roster then
        return
    end

    local someoneLeft = false
    for guid, member in pairs(groupMembers) do
        if not roster[guid] then
            someoneLeft = true
            self:Notify("leave", string.format("%s has left the group.", ColorName(member.name, member.className)))
        end
    end

    if someoneLeft and self.db.profile.leaveActive then
        -- SOUNDKIT.IG_PLAYER_INVITE_DECLINE, which is missing from the SOUNDKIT table on this client
        PlaySound(882, "Master")
    end

    groupMembers = roster
end

-- GUIDs of healers currently drinking, so each drink plays the sound only once
local drinkingHealers = {}

local function IsDrinking(unit)
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then
            return false
        end
        if tContains(DRINK_SPELL_ID, aura.spellId) then
            return true
        end
    end
    return false
end

function SoundClues:OnUnitAura(event, unit)
    if UnitGroupRolesAssigned(unit) ~= "HEALER" then
        return
    end

    if not (UnitInParty(unit) or UnitInRaid(unit)) then
        return
    end

    local guid = UnitGUID(unit)
    local drinking = IsDrinking(unit)
    local wasDrinking = drinkingHealers[guid]
    drinkingHealers[guid] = drinking or nil

    if drinking and not wasDrinking and not UnitAffectingCombat("player") then
        PlaySoundFile("Sound\\Creature\\MillhouseManastorm\\TEMPEST_Millhouse_Drinks01.ogg", "Master")
    end
end

local options = {
    name = "Kehet's SoundClues",
    handler = SoundClues,
    type = "group",
    args = {
        tankActive = {
            type = "toggle",
            name = "Enable death alert for tank",
            get = "IsTankActive",
            set = "ToggleTankActive",
            width = "full"
        },
        healerActive = {
            type = "toggle",
            name = "Enable death alert for healer",
            get = "IsHealerActive",
            set = "ToggleHealerActive",
            width = "full"
        },
        dpsActive = {
            type = "toggle",
            name = "Enable death alert for DPS",
            get = "IsDpsActive",
            set = "ToggleDpsActive",
            width = "full"
        },
        unknownActive = {
            type = "toggle",
            name = "Enable death alert for unknown roles",
            get = "IsUnknownActive",
            set = "ToggleUnknownActive",
            width = "full"
        },
        drinkingActive = {
            type = "toggle",
            name = "Enable healer drinking alert",
            get = "IsDrinkingActive",
            set = "ToggleDrinkingActive",
            width = "full"
        },
        leaveActive = {
            type = "toggle",
            name = "Enable alert when a player leaves the group",
            get = "IsLeaveActive",
            set = "ToggleLeaveActive",
            width = "full"
        },
    },
}

options.args.messages = SoundClues:GetMessageOptions()
options.args.messages.inline = true
options.args.messages.order = 200

function SoundClues:IsTankActive(info)
    return self.db.profile.tankActive
end

function SoundClues:ToggleTankActive(info, value)
    self.db.profile.tankActive = value
end

function SoundClues:IsHealerActive(info)
    return self.db.profile.healerActive
end

function SoundClues:ToggleHealerActive(info, value)
    self.db.profile.healerActive = value
end

function SoundClues:IsDpsActive(info)
    return self.db.profile.dpsActive
end

function SoundClues:ToggleDpsActive(info, value)
    self.db.profile.dpsActive = value
end

function SoundClues:IsUnknownActive(info)
    return self.db.profile.unknownActive
end

function SoundClues:ToggleUnknownActive(info, value)
    self.db.profile.unknownActive = value
end

function SoundClues:IsDrinkingActive(info)
    return self.db.profile.drinkingActive
end

function SoundClues:ToggleDrinkingActive(info, value)
    self.db.profile.drinkingActive = value
    if value then
        self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    else
        self:UnregisterEvent("UNIT_AURA")
    end
end

function SoundClues:IsLeaveActive(info)
    return self.db.profile.leaveActive
end

function SoundClues:ToggleLeaveActive(info, value)
    self.db.profile.leaveActive = value
end

local defaults = {
    profile = {
        tankActive = true,
        healerActive = true,
        dpsActive = true,
        unknownActive = true,
        drinkingActive = true,
        leaveActive = true,
    },
}

function SoundClues:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SoundCluesDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("SoundClues", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SoundClues", "Kehet's SoundClues")
    self:RegisterChatCommand("sc", "SlashCommand")
    self:RegisterChatCommand("soundclues", "SlashCommand")
end

function SoundClues:SlashCommand(msg)
    if not msg or msg:trim() == "" then
        -- Settings.OpenToCategory is protected on this client, so open a standalone window instead
        LibStub("AceConfigDialog-3.0"):Open("SoundClues")
    else
        self:Print("hello there!")
    end
end
