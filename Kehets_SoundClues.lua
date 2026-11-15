local ADDON_NAME = ...

-- The addon table. SoundClues.db is set when the saved variables are loaded.
-- Chat lines start with a short name, coloured like "Kehet's" in the addon title.
local SoundClues = { name = "Kehet's SoundClues", chatPrefix = "|cFF009900SoundClues|r: " }
LibStub("LibKehetsVerbosity-2.0"):Embed(SoundClues, function() return SoundClues.db end)

-- Event handlers by event name. A handler is a method name, called as self[handler](self, event, ...).
local eventHandlers = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = eventHandlers[event]
    if handler then
        SoundClues[handler](SoundClues, event, ...)
    end
end)

function SoundClues:RegisterEvent(event, handler)
    eventHandlers[event] = handler
    eventFrame:RegisterEvent(event)
end

function SoundClues:UnregisterEvent(event)
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- The sounds are FileDataIDs, because WoW: Forever cannot play game sounds by path.
-- The leave sound is SOUNDKIT.IG_PLAYER_INVITE_DECLINE, which is missing from the SOUNDKIT table on this client.
-- Each alert is its own message type, so the player turns its line and its sound on or off in the
-- Messages settings.
SoundClues:RegisterMessageTypes({
    banner = {
        name = "Login message",
        desc = "The line that says the addon is enabled.",
        order = 1,
    },
    tankDeath = {
        name = "Tank death",
        desc = "The line and the quest failed sound when a tank dies.",
        order = 2,
        sound = { file = 567459 }, -- sound/interface/igquestfailed.ogg
    },
    healerDeath = {
        name = "Healer death",
        desc = "The line and the angry wisp sound when a healer dies.",
        order = 3,
        sound = { file = 567285 }, -- sound/event sounds/wisp/wisppissed1.ogg
    },
    dpsDeath = {
        name = "DPS death",
        desc = "The line and the character creation sound when a DPS dies.",
        order = 4,
        sound = { file = 567522 }, -- sound/interface/icreatecharactera.ogg
    },
    unknownDeath = {
        name = "No assigned role death",
        desc = "The line and the character creation sound when a player with no assigned role dies.",
        order = 5,
        sound = { file = 567522 }, -- sound/interface/icreatecharactera.ogg
    },
    leave = {
        name = "Player leaves the group",
        desc = "The line and the invite declined sound when a player leaves your group or is removed from it. The Leave Alert settings choose when.",
        order = 6,
        sound = { kit = 882 },
    },
    drinking = {
        name = "Healer starts to drink",
        desc = "The line and Millhouse Manastorm's drinking line when the healer starts to drink, while you are out of combat.",
        order = 7,
        sound = { file = 555334 }, -- sound/creature/millhousemanastorm/tempest_millhouse_drinks01.ogg
    },
})

-- The message type of a death, by the role of the member who died
local DEATH_TYPES = {
    TANK = "tankDeath",
    HEALER = "healerDeath",
    DAMAGER = "dpsDeath",
}

local DRINK_SPELL_ID = {
    10250, 25696, 26261, 26402, 26473, 26475, 30024, 46755, 57073, 61830, 64356, 66041, 69176, 72623, 87958, 87959,
    92736, 92797, 92800, 92803, 104262, 104269, 105230, 105590, 114731, 130335, 130336, 130337, 130338, 130339,
    130340, 130341, 1216892, 43155, 118359, 104270
}

-- WoW: Forever hands out secret values that addons cannot compare, and has no issecretvalue on the other clients
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

function SoundClues:OnEnable()
    self:Notify("banner", "Enabled - Use /sc or /soundclues to open the settings")
    -- Deaths come from unit health, because WoW: Forever does not let addons register the combat log
    self:RegisterEvent("UNIT_HEALTH", "OnUnitHealth")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:OnGroupRosterUpdate()
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
end

local function ColorName(name, className)
    local classColor = RAID_CLASS_COLORS[className]
    if not classColor then
        return name
    end
    return string.format("|cFF%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
end

-- Group members that are dead, by GUID, so a death is reported once and not again on each health update
local deadMembers = {}

local function IsGroupUnit(unit)
    return unit:match("^party%d$") ~= nil or unit:match("^raid%d+$") ~= nil
end

local function IsDead(unit)
    local dead, feigning = UnitIsDeadOrGhost(unit), UnitIsFeignDeath(unit)
    if IsSecret(dead) or IsSecret(feigning) then
        return false
    end
    return dead and not feigning
end

-- Records who is dead now without alerting, so members that were already dead are not reported
local function ReadDeadMembers()
    deadMembers = {}
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        local guid = UnitGUID(unit)
        if guid and IsDead(unit) then
            deadMembers[guid] = true
        end
    end
end

function SoundClues:OnUnitHealth(event, unit)
    if not IsGroupUnit(unit) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    local dead = IsDead(unit)
    if dead == (deadMembers[guid] == true) then
        return
    end
    deadMembers[guid] = dead or nil

    if dead then
        self:OnMemberDied(unit)
    end
end

function SoundClues:OnMemberDied(unit)
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
            self:Notify(DEATH_TYPES[role] or "unknownDeath", message)
        end
    end
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
    ReadDeadMembers()

    -- When the player leaves or the group disbands, nobody else left
    if not IsInGroup() then
        groupMembers = {}
        return
    end

    local roster = ReadRoster()
    if not roster then
        return
    end

    -- The roster is still kept up to date while the alert is off, so turning it on does not report old leaves
    local previous = groupMembers
    groupMembers = roster
    if not self:IsLeaveAlertWanted() then
        return
    end

    for guid, member in pairs(previous) do
        if not roster[guid] then
            self:Notify("leave", string.format("%s has left the group.", ColorName(member.name, member.className)))
        end
    end
end

function SoundClues:IsLeaveAlertWanted()
    local profile = self.db
    if not self:IsMessageShown("leave") then
        return false
    end

    if UnitAffectingCombat("player") then
        if not profile.leaveInCombat then
            return false
        end
    elseif not profile.leaveOutOfCombat then
        return false
    end

    local _, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then
        return profile.leaveBattleground
    elseif IsInRaid() then
        return profile.leaveRaid
    end
    return profile.leaveParty
end

-- GUIDs of healers currently drinking, so each drink plays the sound only once
local drinkingHealers = {}

-- WoW: Forever hides auras from addons at times, and reading them then is an error, so ask first
local function CanReadAura(unit, index)
    if not C_Secrets then
        return true
    end
    if C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        return false
    end
    return not (C_Secrets.ShouldUnitAuraIndexBeSecret and C_Secrets.ShouldUnitAuraIndexBeSecret(unit, index, "HELPFUL"))
end

-- Returns nil when the auras cannot be read
local function IsDrinking(unit)
    for i = 1, 40 do
        if not CanReadAura(unit, i) then
            return nil
        end
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura or IsSecret(aura.spellId) then
            return false
        end
        if tContains(DRINK_SPELL_ID, aura.spellId) then
            return true
        end
    end
    return false
end

function SoundClues:OnUnitAura(event, unit)
    if not self:IsMessageShown("drinking") then
        return
    end
    -- UNIT_AURA also fires for tokens like targettarget, whose role is a secret value in WoW: Forever
    if not IsGroupUnit(unit) or not (UnitInParty(unit) or UnitInRaid(unit)) then
        return
    end

    local role = UnitGroupRolesAssigned(unit)
    if IsSecret(role) or role ~= "HEALER" then
        return
    end

    local guid = UnitGUID(unit)
    local drinking = IsDrinking(unit)
    if drinking == nil then
        return
    end
    local wasDrinking = drinkingHealers[guid]
    drinkingHealers[guid] = drinking or nil

    if drinking and not wasDrinking and not UnitAffectingCombat("player") then
        local _, className = UnitClass(unit)
        self:Notify("drinking", string.format("%s (Healer) is drinking.", ColorName(UnitName(unit), className)))
    end
end

local defaults = {
    leaveInCombat = true,
    leaveOutOfCombat = true,
    leaveParty = true,
    leaveRaid = true,
    leaveBattleground = true,
}

-- Versions up to 1.6.0 saved an AceDB-3.0 database with all characters on the shared "Default" profile.
-- The addon reads and writes that profile in place, so an older version still reads the settings.
local function LoadDB()
    if type(SoundCluesDB) ~= "table" then
        SoundCluesDB = {}
    end
    if type(SoundCluesDB.profiles) ~= "table" then
        SoundCluesDB.profiles = {}
    end
    if type(SoundCluesDB.profiles.Default) ~= "table" then
        SoundCluesDB.profiles.Default = {}
    end
    local profile = SoundCluesDB.profiles.Default
    for key, value in pairs(defaults) do
        if profile[key] == nil then
            profile[key] = value
        end
    end
    return profile
end

function SoundClues:SetOption(key, value)
    self.db[key] = value
end

-- Version 1.6.0 and older had one death message type, and its own check boxes for each sound:
-- tankActive, healerActive, dpsActive, unknownActive, drinkingActive and leaveActive. They are carried
-- over to the message types once, and left in place so an older version still reads them.
local OLD_DEATH_SOUNDS = {
    tankActive = "tankDeath",
    healerActive = "healerDeath",
    dpsActive = "dpsDeath",
    unknownActive = "unknownDeath",
}

local function CopyOutputs(outputs)
    local copy = {}
    for output, on in pairs(outputs or {}) do
        copy[output] = on
    end
    return copy
end

function SoundClues:MigrateSounds()
    local profile = self.db
    if profile.soundTypesMigrated then
        return
    end
    profile.soundTypesMigrated = true

    local internal = LibStub("LibKehetsVerbosity-2.0").internal
    local types = profile.verbosity and profile.verbosity.types or {}

    -- The old death line had its own switch and outputs, apart from the sounds. A death with its line
    -- off but its sound on is shown nowhere, so only the sound plays.
    local oldDeath = types.death
    for oldKey, key in pairs(OLD_DEATH_SOUNDS) do
        local textOn = not (oldDeath and oldDeath.shown == false)
        local soundOn = profile[oldKey] ~= false
        if oldDeath and oldDeath.outputs then
            internal.SetSetting(self, key, "outputs", CopyOutputs(oldDeath.outputs))
        end
        if not textOn and not soundOn then
            self:SetMessageShown(key, false)
        elseif not textOn then
            internal.SetSetting(self, key, "outputs", {})
        elseif not soundOn then
            self:SetMessageSound(key, false)
        end
    end

    -- The leave line had its own switch too, and the sound followed leaveActive
    local leaveTextOn = not (types.leave and types.leave.shown == false)
    if profile.leaveActive == false then
        self:SetMessageShown("leave", false)
    elseif not leaveTextOn then
        self:SetMessageShown("leave", true)
        internal.SetSetting(self, "leave", "outputs", {})
    end

    if profile.drinkingActive == false then
        self:SetMessageShown("drinking", false)
    end
end

local DISPLAY_NAME = "Kehet's SoundClues"

-- The settings page, by section. Each option is a check box for the saved value of the same key.
-- An option with a parent is indented under it and has no effect while the parent is off.
-- Names and headers are in Title Case, like the game's own settings.
local SECTIONS = {
    {
        -- The leave alert itself, and its sound, are turned on or off in the Messages settings
        title = "Leave Alert",
        options = {
            { key = "leaveInCombat", name = "In Combat", desc = "Alert when a player leaves while you are in combat." },
            { key = "leaveOutOfCombat", name = "Out of Combat", desc = "Alert when a player leaves while you are out of combat." },
            { key = "leaveParty", name = "In a Party", desc = "Alert when a player leaves your party." },
            { key = "leaveRaid", name = "In a Raid", desc = "Alert when a player leaves your raid." },
            { key = "leaveBattleground", name = "In a Battleground or Arena", desc = "Alert when a player leaves your battleground or arena group." },
        },
    },
}

local category
local page

-- Clients with proxy settings get the native list of the game settings
local function RegisterNativePage()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(DISPLAY_NAME)
    local initializers = {}
    for _, section in ipairs(SECTIONS) do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section.title))
        for _, option in ipairs(section.options) do
            local key = option.key
            local setting = Settings.RegisterProxySetting(category, "KEHETS_SOUNDCLUES_" .. key:upper(),
                Settings.VarType.Boolean, option.name, defaults[key],
                function() return SoundClues.db[key] end,
                function(value) SoundClues:SetOption(key, value) end)
            local initializer = Settings.CreateCheckbox(category, setting, option.desc)
            initializers[key] = initializer
            local parent = option.parent
            if parent then
                initializer:Indent()
                initializer:SetParentInitializer(initializers[parent], function() return SoundClues.db[parent] end)
            end
        end
    end
    Settings.RegisterAddOnCategory(category)
end

local function CreateCheckbox(parent, option)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check.label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText(option.name)
    check:SetScript("OnClick", function(self)
        SoundClues:SetOption(option.key, self:GetChecked() and true or false)
        parent:Refresh()
    end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(option.name, 1, 1, 1)
        GameTooltip:AddLine(option.desc, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", GameTooltip_Hide)
    return check
end

local function BuildCanvasPage()
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(DISPLAY_NAME)

    page.checks = {}
    local y = -52
    for _, section in ipairs(SECTIONS) do
        local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 16, y)
        header:SetText(section.title)
        y = y - 18
        for _, option in ipairs(section.options) do
            local check = CreateCheckbox(page, option)
            check:SetPoint("TOPLEFT", option.parent and 32 or 12, y)
            check.parentKey = option.parent
            page.checks[option.key] = check
            y = y - 26
        end
        y = y - 16
    end
end

-- Clients without proxy settings get a page of check boxes
local function RegisterCanvasPage()
    page = CreateFrame("Frame")
    -- An unparented frame starts shown, so the settings panel's first Show() would not fire OnShow
    page:Hide()
    page.name = DISPLAY_NAME
    function page:Refresh()
        local db = SoundClues.db
        for key, check in pairs(self.checks) do
            local disabled = check.parentKey and not db[check.parentKey]
            check:SetChecked(db[key] and true or false)
            check:SetEnabled(not disabled)
            if disabled then
                check.label:SetTextColor(0.5, 0.5, 0.5)
            else
                check.label:SetTextColor(1, 1, 1)
            end
        end
    end
    page:SetScript("OnShow", function()
        if not page.checks then
            BuildCanvasPage()
        end
        page:Refresh()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, DISPLAY_NAME)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
end

function SoundClues:OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
end

function SoundClues:OnInitialize()
    self.db = LoadDB()
    self:MigrateSounds()
    if Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting then
        RegisterNativePage()
    else
        RegisterCanvasPage()
    end
    self:RegisterMessagePage(category)

    SLASH_KEHETSSOUNDCLUES1 = "/sc"
    SLASH_KEHETSSOUNDCLUES2 = "/soundclues"
    SlashCmdList.KEHETSSOUNDCLUES = function(msg) self:SlashCommand(msg) end
end

function SoundClues:SlashCommand(msg)
    if not msg or strtrim(msg) == "" then
        self:OpenOptions()
    else
        self:Print("hello there!")
    end
end

function SoundClues:OnAddonLoaded(event, name)
    if name == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        self:OnInitialize()
    end
end

function SoundClues:OnPlayerLogin()
    self:UnregisterEvent("PLAYER_LOGIN")
    self:OnEnable()
end

SoundClues:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
SoundClues:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
