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

    self:Print("unit is unit " .. unit)

    if UnitInParty(unit) or UnitInRaid(unit) then

        self:Print("Is in raid or party")

        if unit then
            local role = UnitGroupRolesAssigned(unit)

            self:Print("Role is " .. role)

            if role and soundFiles[role] then

                self:Print("Play sound " .. soundFiles[role])

                PlaySoundFile(soundFiles[role], "Master")
            else
                self:Print("Player has no role")

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
