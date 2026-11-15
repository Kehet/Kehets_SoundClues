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
        desc = "The line that says which player left the group. It shows only when the leave alert settings allow the alert.",
        order = 3,
    },
})

-- FileDataIDs, because WoW: Forever cannot play game sounds by path
local soundFiles = {
    DAMAGER = 567522, -- sound/interface/icreatecharactera.ogg
    HEALER = 567285, -- sound/event sounds/wisp/wisppissed1.ogg
    TANK = 567459, -- sound/interface/igquestfailed.ogg
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
    if self.db.drinkingActive then
        self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    end
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
            self:Notify("death", message)

            local shouldPlaySound = false

            if role == "TANK" and self.db.tankActive then
                shouldPlaySound = true
            elseif role == "HEALER" and self.db.healerActive then
                shouldPlaySound = true
            elseif role == "DAMAGER" and self.db.dpsActive then
                shouldPlaySound = true
            elseif (not role or not soundFiles[role]) and self.db.unknownActive then
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

    local someoneLeft = false
    for guid, member in pairs(previous) do
        if not roster[guid] then
            someoneLeft = true
            self:Notify("leave", string.format("%s has left the group.", ColorName(member.name, member.className)))
        end
    end

    if someoneLeft then
        -- SOUNDKIT.IG_PLAYER_INVITE_DECLINE, which is missing from the SOUNDKIT table on this client
        PlaySound(882, "Master")
    end
end

function SoundClues:IsLeaveAlertWanted()
    local profile = self.db

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
        PlaySoundFile(555334, "Master") -- sound/creature/millhousemanastorm/tempest_millhouse_drinks01.ogg
    end
end

local defaults = {
    tankActive = true,
    healerActive = true,
    dpsActive = true,
    unknownActive = true,
    drinkingActive = true,
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
    if key == "drinkingActive" then
        if value then
            self:RegisterEvent("UNIT_AURA", "OnUnitAura")
        else
            self:UnregisterEvent("UNIT_AURA")
        end
    end
end

local DISPLAY_NAME = "Kehet's SoundClues"

-- The settings page, by section. Each option is a check box for the saved value of the same key.
local SECTIONS = {
    {
        title = "Death alerts",
        options = {
            { key = "tankActive", name = "Tank", desc = "Play the quest failed sound when a tank dies." },
            { key = "healerActive", name = "Healer", desc = "Play the angry wisp sound when a healer dies." },
            { key = "dpsActive", name = "DPS", desc = "Play the character creation sound when a DPS dies." },
            { key = "unknownActive", name = "No assigned role", desc = "Play the character creation sound when a player with no assigned role dies." },
        },
    },
    {
        title = "Healer drinking alert",
        options = {
            { key = "drinkingActive", name = "Healer starts to drink", desc = "Play Millhouse Manastorm's drinking line when the healer starts to drink, while you are out of combat." },
        },
    },
    {
        title = "Leave alert",
        options = {
            { key = "leaveInCombat", name = "In combat", desc = "Alert when a player leaves while you are in combat." },
            { key = "leaveOutOfCombat", name = "Out of combat", desc = "Alert when a player leaves while you are out of combat." },
            { key = "leaveParty", name = "In a party", desc = "Alert when a player leaves your party." },
            { key = "leaveRaid", name = "In a raid", desc = "Alert when a player leaves your raid." },
            { key = "leaveBattleground", name = "In a battleground or arena", desc = "Alert when a player leaves your battleground or arena group." },
        },
    },
}

local category
local page

-- Clients with proxy settings get the native list of the game settings
local function RegisterNativePage()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(DISPLAY_NAME)
    for _, section in ipairs(SECTIONS) do
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section.title))
        for _, option in ipairs(section.options) do
            local key = option.key
            local setting = Settings.RegisterProxySetting(category, "KEHETS_SOUNDCLUES_" .. key:upper(),
                Settings.VarType.Boolean, option.name, defaults[key],
                function() return SoundClues.db[key] end,
                function(value) SoundClues:SetOption(key, value) end)
            Settings.CreateCheckbox(category, setting, option.desc)
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
            check:SetPoint("TOPLEFT", 12, y)
            page.checks[option.key] = check
            y = y - 26
        end
        y = y - 16
    end
end

-- Clients without proxy settings get a page of check boxes
local function RegisterCanvasPage()
    page = CreateFrame("Frame")
    page.name = DISPLAY_NAME
    page:SetScript("OnShow", function()
        if not page.checks then
            BuildCanvasPage()
        end
        for key, check in pairs(page.checks) do
            check:SetChecked(SoundClues.db[key] and true or false)
        end
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
