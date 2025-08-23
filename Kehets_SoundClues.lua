local SoundClues = LibStub("AceAddon-3.0"):NewAddon("Kehet's SoundClues", "AceConsole-3.0", "AceEvent-3.0")

local soundFiles = {
    DAMAGER = "Sound\\interface\\iCreateCharacterA.ogg",
    HEALER = "Sound\\Event Sounds\\Wisp\\WispPissed1.ogg",
    TANK = "Sound\\interface\\igQuestFailed.ogg",
}

local DRINK_SPELL_ID = 430

function SoundClues:OnEnable()
    self:Print("Enabled")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEventUnfiltered")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
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

            -- Send chat message
            local message = string.format("%s (%s) has died!", coloredName, roleText)
            self:Print(message)

            if role and soundFiles[role] then
                PlaySoundFile(soundFiles[role], "Master")
            else
                PlaySoundFile(soundFiles["DAMAGER"], "Master")
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

    if UnitInParty(unit) or UnitInRaid(unit) then
        for i = 1, 40 do
            local auraId = select(10, UnitAura(unit, i))
            if auraId == DRINK_SPELL_ID then
                PlaySoundFile("Sound\\Creature\\MillhouseManastorm\\TEMPEST_Millhouse_Drinks01.ogg", "Master")
                break
            end
        end
    end
end
