local SoundClues = LibStub("AceAddon-3.0"):NewAddon("Kehet's SoundClues", "AceConsole-3.0", "AceEvent-3.0")

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
    self:Print("Enabled")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEventUnfiltered")
    if self.db.profile.drinkingActive then
        self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    end
end

function SoundClues:OnDisable()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("UNIT_AURA")
end

function SoundClues:OnCombatLogEventUnfiltered()
    local _, eventType, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

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

            -- Get class color
            local classColor = RAID_CLASS_COLORS[className]
            local coloredName = playerName
            if classColor then
                coloredName = string.format("|cFF%02x%02x%02x%s|r",
                    classColor.r * 255, classColor.g * 255, classColor.b * 255, playerName)
            end

            -- Convert role to display text
            local roleText = "DPS"
            if role == "HEALER" then
                roleText = "Healer"
            elseif role == "TANK" then
                roleText = "Tank"
            end

            local message = string.format("%s (%s) has died!", coloredName, roleText)
            self:Print(message)

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

function SoundClues:OnUnitAura(unit)
    if UnitAffectingCombat("player") then
        return
    end

    if UnitGroupRolesAssigned(unit) ~= "HEALER" then
        return
    end

    if UnitInParty(unit) or UnitInRaid(unit) then
        for i = 1, 40 do
            local auraId = select(10, UnitAura(unit, i))
            for _, drinkSpellId in ipairs(DRINK_SPELL_ID) do
                if auraId == drinkSpellId then
                    PlaySoundFile("Sound\\Creature\\MillhouseManastorm\\TEMPEST_Millhouse_Drinks01.ogg", "Master")
                    return
                end
            end
        end
    end
end

local options = {
    name = "SoundClues",
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
    },
}

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

local defaults = {
    profile = {
        tankActive = true,
        healerActive = true,
        dpsActive = true,
        unknownActive = true,
        drinkingActive = true,
    },
}

function SoundClues:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SoundCluesDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("SoundClues", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SoundClues", "SoundClues")
    self:RegisterChatCommand("sc", "SlashCommand")
    self:RegisterChatCommand("soundclues", "SlashCommand")
end

function SoundClues:SlashCommand(msg)
    if not msg or msg:trim() == "" then
        Settings.OpenToCategory(self.optionsFrame.name)
    else
        self:Print("hello there!")
    end
end
