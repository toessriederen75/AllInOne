-- AllInOne: comfort modules — mail helpers, error filter, looting and small
-- automations (battleground release, declining duels and so on).

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style

if GetLocale() == "deDE" then
    -- Mail
    L["Mail helpers"] = "Post-Helfer"
    L["Your characters on the send page and an \"Open all\" button in the inbox."] = "Deine Charaktere auf der Sendeseite und ein «Alle öffnen»-Knopf im Posteingang."
    L["On the send page, a column with your other characters of the same faction on this realm fills in the recipient with one click. In the inbox, \"Open all\" takes the money and items from every mail without cash on delivery, one after another, until the bags are full."] = "Auf der Sendeseite trägt eine Spalte mit deinen anderen Charakteren derselben Fraktion auf diesem Realm den Empfänger mit einem Klick ein. Im Posteingang nimmt «Alle öffnen» Geld und Gegenstände aus jeder Post ohne Nachnahme, eine nach der anderen, bis die Taschen voll sind."
    L["Characters on the send page"] = "Charaktere auf der Sendeseite"
    L["\"Open all\" button in the inbox"] = "«Alle öffnen»-Knopf im Posteingang"
    L["Report collected gold"] = "Eingesammeltes Gold melden"
    L["Open all"] = "Alle öffnen"
    L["Stop"] = "Stopp"
    L["Takes money and items from every mail without cash on delivery."] = "Nimmt Geld und Gegenstände aus jeder Post ohne Nachnahme."
    L["Characters"] = "Charaktere"
    L["No other characters of your faction yet."] = "Noch keine anderen Charaktere deiner Fraktion."
    L["Mail: collected %s and %d item(s)."] = "Post: %s und %d Gegenstand/Gegenstände eingesammelt."
    L["Mail: your bags are full."] = "Post: Deine Taschen sind voll."
    L["Mail: stopped."] = "Post: angehalten."
    -- Errors
    L["Error filter"] = "Fehlerfilter"
    L["Hides combat spam from the red error text."] = "Blendet Kampf-Meldungen im roten Fehlertext aus."
    L["Hides the red messages in the middle of the screen that repeat all the time in a fight, such as \"Not enough energy\" or \"Ability is not ready yet\". Other errors still show."] = "Blendet die roten Meldungen in der Bildschirmmitte aus, die sich im Kampf ständig wiederholen, etwa «Nicht genug Energie» oder «Fähigkeit noch nicht bereit». Andere Fehler werden weiter angezeigt."
    L["Hide"] = "Ausblenden"
    L["Cooldowns (\"not ready yet\")"] = "Abklingzeiten («noch nicht bereit»)"
    L["Resources (energy, rage, mana, combo points)"] = "Ressourcen (Energie, Wut, Mana, Combopunkte)"
    L["Target and range"] = "Ziel und Reichweite"
    L["\"Another action is in progress\""] = "«Eine andere Aktion ist im Gange»"
    L["Only in combat"] = "Nur im Kampf"
    L["Out of combat every message shows."] = "Ausserhalb des Kampfes wird jede Meldung angezeigt."
    -- Loot
    L["Looting"] = "Plündern"
    L["Fast loot and fewer loot confirmations."] = "Schnelles Plündern und weniger Plünder-Bestätigungen."
    L["Takes all loot at once when auto loot is on, confirms bind-on-pickup loot when you are alone and can confirm loot rolls for you."] = "Nimmt die ganze Beute auf einmal, wenn automatisches Plündern an ist, bestätigt beim Aufheben gebundene Beute, wenn du allein bist, und kann Würfe für dich bestätigen."
    L["Fast loot"] = "Schnelles Plündern"
    L["Takes every item at once when auto loot is on (or the auto loot key is held)."] = "Nimmt alle Gegenstände auf einmal, wenn automatisches Plündern an ist (oder die Taste dafür gedrückt ist)."
    L["Confirm bind-on-pickup loot when alone"] = "Beim Aufheben gebundene Beute allein bestätigen"
    L["Confirm loot rolls"] = "Würfe bestätigen"
    L["Skips the question whether you really want to roll need or greed on a bind-on-pickup item."] = "Überspringt die Frage, ob du auf einen beim Aufheben gebundenen Gegenstand wirklich Bedarf oder Gier würfeln willst."
    L["Greed on green bind-on-equip items"] = "Gier auf grüne, beim Anlegen gebundene Gegenstände"
    L["Rolls greed automatically in groups."] = "Würfelt in Gruppen automatisch Gier."
    L["Greed: %s"] = "Gier: %s"
    -- Automation
    L["Automation"] = "Automatisierung"
    L["Battleground release, declining duels and invitations, accepting groups."] = "Freilassen im Schlachtfeld, Duelle und Einladungen ablehnen, Gruppen annehmen."
    L["Small things the game asks you again and again, answered for you. Each one can be switched on and off."] = "Kleinigkeiten, die das Spiel immer wieder fragt, für dich beantwortet. Jede lässt sich einzeln ein- und ausschalten."
    L["Release in battlegrounds"] = "Im Schlachtfeld freilassen"
    L["Releases your spirit automatically when you die in a battleground (not with a soulstone)."] = "Lässt deinen Geist automatisch frei, wenn du im Schlachtfeld stirbst (nicht mit Seelenstein)."
    L["Decline duels"] = "Duelle ablehnen"
    L["Decline guild invitations"] = "Gildeneinladungen ablehnen"
    L["Decline guild charters"] = "Gildensatzungen ablehnen"
    L["Accept groups from friends and guild"] = "Gruppen von Freunden und Gilde annehmen"
    L["Accept resurrection out of combat"] = "Wiederbelebung ausserhalb des Kampfes annehmen"
    L["Declined a duel from %s."] = "Duell von %s abgelehnt."
    L["Declined a guild invitation from %s."] = "Gildeneinladung von %s abgelehnt."
    L["Accepted the group invitation from %s."] = "Gruppeneinladung von %s angenommen."
end

local CC = C_Container or {}

local function After(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else AIO:Later(fn, fn) end
end

local function InGroup()
    if IsInGroup then return IsInGroup() end
    return ((GetNumRaidMembers and GetNumRaidMembers()) or 0) > 0
        or ((GetNumPartyMembers and GetNumPartyMembers()) or 0) > 0
end

local function InCombat()
    return (UnitAffectingCombat and UnitAffectingCombat("player")) or InCombatLockdown()
end

local function HidePopup(which)
    if StaticPopup_Hide then StaticPopup_Hide(which) end
end

local function CVarBool(name)
    if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name) end
    if GetCVarBool then return GetCVarBool(name) end
    return GetCVar and GetCVar(name) == "1"
end

-- ===========================================================================
-- Mail
-- ===========================================================================

local Mail = AIO:NewModule("mail", {
    title    = L["Mail helpers"],
    short    = L["Your characters on the send page and an \"Open all\" button in the inbox."],
    desc     = L["On the send page, a column with your other characters of the same faction on this realm fills in the recipient with one click. In the inbox, \"Open all\" takes the money and items from every mail without cash on delivery, one after another, until the bags are full."],
    category = "comfort",
    default  = true,
    defaults = { altList = true, openAll = true, report = true },
    options  = {
        { type = "toggle", key = "altList", label = L["Characters on the send page"] },
        { type = "toggle", key = "openAll", label = L["\"Open all\" button in the inbox"] },
        { type = "toggle", key = "report",  label = L["Report collected gold"],
          disabled = function(m) return not m.db.openAll end },
    },
})

local MAX_ATTACH = _G.ATTACHMENTS_MAX_RECEIVE or 12
local STEP_DELAY = 0.35

local function FreeBagSlots()
    local free = 0
    for _, bag in ipairs(AIO:InventoryBags()) do
        if AIO.BagFamily(bag) == 0 then free = free + AIO.FreeSlots(bag) end
    end
    return free
end

-- --- Characters on the send page -------------------------------------------

function Mail:AltNames()
    local faction = UnitFactionGroup("player")
    local list = {}
    for _, name in ipairs(AIO:Characters()) do
        if name ~= AIO.player then
            local c = AIO:CharData(name)
            if c and (c.faction == nil or c.faction == faction) then list[#list + 1] = name end
        end
    end
    return list
end

function Mail:BuildAltList()
    if self.altFrame or not _G.SendMailFrame then return end
    local f = CreateFrame("Frame", "AllInOneMailAlts", SendMailFrame)
    f:SetWidth(132)
    f:SetPoint("TOPLEFT", _G.MailFrame or SendMailFrame, "TOPRIGHT", 2, -12)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    Style.Chrome(f)
    f.title = Style.Text(f, 12, Style.blizzard and Style.gold or Style.color.accent)
    if Style.blizzard then f.title:SetPoint("TOP", 0, -10) else f.title:SetPoint("TOPLEFT", 8, -7) end
    f.title:SetText(L["Characters"])
    f.empty = Style.Text(f, 11, Style.color.muted)
    f.empty:SetPoint("TOPLEFT", Style.blizzard and 10 or 8, Style.blizzard and -38 or -26)
    f.empty:SetWidth(116)
    f.empty:SetWordWrap(true)
    f.empty:SetText(L["No other characters of your faction yet."])
    f.buttons = {}
    self.altFrame = f
    SendMailFrame:HookScript("OnShow", function() Mail:RefreshAltList() end)
end

function Mail:RefreshAltList()
    local f = self.altFrame
    if not f then return end
    if not (self.enabled and self.db.altList) then f:Hide() return end
    local names = self:AltNames()
    for i, name in ipairs(names) do
        local b = f.buttons[i]
        if not b then
            b = Style.Button(f, "", 116, 20, function(btn)
                if SendMailNameEditBox then
                    SendMailNameEditBox:SetText(btn.charName)
                    if SendMailNameEditBox.ClearFocus then SendMailNameEditBox:ClearFocus() end
                    if SendMailSubjectEditBox and SendMailSubjectEditBox.SetFocus then SendMailSubjectEditBox:SetFocus() end
                end
            end)
            b:SetPoint("TOPLEFT", 8, (Style.blizzard and -38 or -26) - (i - 1) * 22)
            f.buttons[i] = b
        end
        local c = AIO:CharData(name)
        b.charName = name
        b:SetLabel(AIO.ClassColored(name, c and c.class))
        b:Show()
    end
    for i = #names + 1, #f.buttons do f.buttons[i]:Hide() end
    f.empty:SetShown(#names == 0)
    local rows = math.max(#names, 1)
    f:SetHeight(26 + rows * 22 + (#names == 0 and 14 or 4) + (Style.blizzard and 18 or 0))
    f:Show()
end

-- --- Open all ----------------------------------------------------------------

function Mail:BuildOpenAll()
    if self.openButton or not _G.InboxFrame then return end
    local b = Style.Button(InboxFrame, L["Open all"], 110, 22, function() Mail:ToggleOpenAll() end)
    b.tip = L["Takes money and items from every mail without cash on delivery."]
    local blizz = _G.OpenAllMail
    if blizz then
        -- Newer clients have their own button; ours takes its place.
        b:SetPoint("CENTER", blizz, "CENTER", 0, 0)
        blizz:HookScript("OnShow", function(s) if Mail.enabled and Mail.db.openAll then s:Hide() end end)
    else
        b:SetPoint("BOTTOM", InboxFrame, "BOTTOM", -10, 100)
    end
    b:SetFrameLevel((InboxFrame:GetFrameLevel() or 0) + 5)
    self.openButton = b
end

function Mail:RefreshOpenAll()
    local b = self.openButton
    if not b then return end
    local show = self.enabled and self.db.openAll
    b:SetShown(show and true or false)
    b:SetLabel(self.running and L["Stop"] or L["Open all"])
    if _G.OpenAllMail then
        if show then
            OpenAllMail:Hide()
            self.hidBlizzard = true
        elseif self.hidBlizzard then
            self.hidBlizzard = false
            OpenAllMail:Show()
        end
    end
end

function Mail:ToggleOpenAll()
    if self.running then self:StopOpenAll(L["Mail: stopped."]) else self:StartOpenAll() end
end

function Mail:StartOpenAll()
    if self.running or not self.atMailbox then return end
    self.running = true
    self.token = (self.token or 0) + 1
    self.gold, self.items = 0, 0
    self.index = GetInboxNumItems() or 0
    self.tries = 0
    self:RefreshOpenAll()
    self:Step(self.token)
end

function Mail:StopOpenAll(reason)
    if not self.running then return end
    self.running = false
    self.token = (self.token or 0) + 1
    if reason then self:Print(reason) end
    if self.db.report and ((self.gold or 0) > 0 or (self.items or 0) > 0) then
        self:Print(L["Mail: collected %s and %d item(s)."], AIO.Money(self.gold), self.items)
    end
    self:RefreshOpenAll()
end

--- One action per call: take the money or one attachment of the current
--- mail, or move on to the next. Mails are worked from the last to the first
--- so that a mail deleted after being emptied does not shift the rest.
function Mail:Step(token)
    if token ~= self.token or not self.running then return end
    if not self.atMailbox or not self.enabled then self:StopOpenAll() return end
    local i = self.index
    local count = GetInboxNumItems() or 0
    if i > count then i = count; self.index = i end
    if i < 1 then self:StopOpenAll() return end

    local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
    local acted = false
    self.tries = self.tries + 1
    if (cod or 0) <= 0 and self.tries <= 20 then
        if (money or 0) > 0 then
            TakeInboxMoney(i)
            self.gold = self.gold + money
            acted = true
        elseif hasItem and hasItem ~= 0 then
            for a = 1, MAX_ATTACH do
                if GetInboxItem(i, a) then
                    if FreeBagSlots() <= 0 then
                        self:StopOpenAll(L["Mail: your bags are full."])
                        return
                    end
                    TakeInboxItem(i, a)
                    self.items = self.items + 1
                    acted = true
                    break
                end
            end
        end
    end
    if not acted then
        self.index = i - 1
        self.tries = 0
    end
    After(acted and STEP_DELAY or 0.05, function() Mail:Step(token) end)
end

-- --- Events ----------------------------------------------------------------

Mail:On("MAIL_SHOW", function()
    Mail.atMailbox = true
    Mail:BuildAltList()
    Mail:BuildOpenAll()
    Mail:RefreshAltList()
    Mail:RefreshOpenAll()
end)

Mail:On("MAIL_CLOSED", function()
    Mail.atMailbox = false
    Mail:StopOpenAll()
end)

Mail:On("UI_ERROR_MESSAGE", function(a, b)
    local msg = type(b) == "string" and b or a
    if Mail.running and msg and (msg == _G.ERR_INV_FULL or msg == _G.ERR_ITEM_MAX_COUNT) then
        Mail:StopOpenAll(L["Mail: your bags are full."])
    end
end)

function Mail:OnEnable()
    self:RefreshAltList()
    self:RefreshOpenAll()
end

function Mail:OnDisable()
    self:StopOpenAll()
    if self.altFrame then self.altFrame:Hide() end
    self:RefreshOpenAll()
end

function Mail:OnSettingChanged()
    self:RefreshAltList()
    self:RefreshOpenAll()
end

-- ===========================================================================
-- Error filter
-- ===========================================================================

local Errors = AIO:NewModule("errors", {
    title    = L["Error filter"],
    short    = L["Hides combat spam from the red error text."],
    desc     = L["Hides the red messages in the middle of the screen that repeat all the time in a fight, such as \"Not enough energy\" or \"Ability is not ready yet\". Other errors still show."],
    category = "comfort",
    default  = true,
    defaults = { cooldown = true, resource = true, target = true, progress = true, combatOnly = false },
    options  = {
        { type = "header", label = L["Hide"] },
        { type = "toggle", key = "cooldown", label = L["Cooldowns (\"not ready yet\")"] },
        { type = "toggle", key = "resource", label = L["Resources (energy, rage, mana, combo points)"] },
        { type = "toggle", key = "target",   label = L["Target and range"] },
        { type = "toggle", key = "progress", label = L["\"Another action is in progress\""] },
        { type = "header", label = L["Options"] },
        { type = "toggle", key = "combatOnly", label = L["Only in combat"],
          desc = L["Out of combat every message shows."] },
    },
})

local ERROR_GROUPS = {
    cooldown = { "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "SPELL_FAILED_NOT_READY" },
    resource = { "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_MANA", "ERR_OUT_OF_FOCUS",
                 "SPELL_FAILED_NO_COMBO_POINTS" },
    target   = { "ERR_NO_ATTACK_TARGET", "SPELL_FAILED_BAD_TARGETS", "ERR_SPELL_OUT_OF_RANGE",
                 "SPELL_FAILED_OUT_OF_RANGE", "ERR_BADATTACKPOS", "ERR_BADATTACKFACING",
                 "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_TARGETS_DEAD", "ERR_INVALID_ATTACK_TARGET",
                 "SPELL_FAILED_BAD_IMPLICIT_TARGETS", "ERR_GENERIC_NO_TARGET" },
    progress = { "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_SPELL_IN_PROGRESS" },
}

function Errors:BuildSet()
    local set = {}
    for group, names in pairs(ERROR_GROUPS) do
        for _, name in ipairs(names) do
            local text = _G[name]
            if type(text) == "string" and text ~= "" then set[text] = group end
        end
    end
    self.set = set
end

--- Is this UI_ERROR_MESSAGE one to drop? Modern clients pass (type, text),
--- older ones only the text.
function Errors:Drop(a, b)
    if not self.enabled or not self.set then return false end
    local msg = type(b) == "string" and b or a
    local group = type(msg) == "string" and self.set[msg]
    if not group or not self.db[group] then return false end
    if self.db.combatOnly and not InCombat() then return false end
    return true
end

function Errors:Hook()
    if self.hooked or not _G.UIErrorsFrame then return end
    local orig = UIErrorsFrame:GetScript("OnEvent")
    if not orig then return end
    self.hooked = true
    UIErrorsFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "UI_ERROR_MESSAGE" and Errors:Drop(...) then return end
        return orig(frame, event, ...)
    end)
end

function Errors:OnEnable()
    if not self.set then self:BuildSet() end
    self:Hook()
end

function Errors:OnDisable() end   -- the hook checks Errors.enabled

-- ===========================================================================
-- Looting
-- ===========================================================================

local Loot = AIO:NewModule("loot", {
    title    = L["Looting"],
    short    = L["Fast loot and fewer loot confirmations."],
    desc     = L["Takes all loot at once when auto loot is on, confirms bind-on-pickup loot when you are alone and can confirm loot rolls for you."],
    category = "comfort",
    default  = true,
    defaults = { fast = true, bopSolo = true, confirmRolls = true, greedGreens = false },
    options  = {
        { type = "toggle", key = "fast",    label = L["Fast loot"],
          desc = L["Takes every item at once when auto loot is on (or the auto loot key is held)."] },
        { type = "toggle", key = "bopSolo", label = L["Confirm bind-on-pickup loot when alone"] },
        { type = "toggle", key = "confirmRolls", label = L["Confirm loot rolls"],
          desc = L["Skips the question whether you really want to roll need or greed on a bind-on-pickup item."] },
        { type = "toggle", key = "greedGreens", label = L["Greed on green bind-on-equip items"],
          desc = L["Rolls greed automatically in groups."] },
    },
})

local function AutoLootWanted()
    local default = CVarBool("autoLootDefault") and true or false
    local toggle = (IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")) and true or false
    return default ~= toggle
end

function Loot:FastLoot()
    if not self.db.fast or self.looted then return end
    if not AutoLootWanted() then return end
    -- With master loot the looter has to choose who gets an item.
    if InGroup() and GetLootMethod and GetLootMethod() == "master" then return end
    self.looted = true
    for slot = (GetNumLootItems() or 0), 1, -1 do
        LootSlot(slot)
    end
end

Loot:On("LOOT_READY",  function() Loot:FastLoot() end)
Loot:On("LOOT_OPENED", function() Loot:FastLoot() end)
Loot:On("LOOT_CLOSED", function() Loot.looted = nil end)

Loot:On("LOOT_BIND_CONFIRM", function(slot)
    if not Loot.db.bopSolo or InGroup() or not slot then return end
    ConfirmLootSlot(slot)
    HidePopup("LOOT_BIND")
end)

Loot:On("CONFIRM_LOOT_ROLL", function(rollID, rollType)
    if not Loot.db.confirmRolls or not rollID then return end
    ConfirmLootRoll(rollID, rollType)
    HidePopup("CONFIRM_LOOT_ROLL")
end)

Loot:On("START_LOOT_ROLL", function(rollID)
    if not Loot.db.greedGreens or not rollID or not InGroup() then return end
    local _, name, _, quality, bindOnPickUp, _, canGreed = GetLootRollItemInfo(rollID)
    if quality ~= 2 or bindOnPickUp then return end
    if canGreed == false then return end
    RollOnLoot(rollID, 2)
    if GetLootRollItemLink then name = GetLootRollItemLink(rollID) or name end
    Loot:Print(L["Greed: %s"], tostring(name))
end)

function Loot:OnDisable() self.looted = nil end

-- ===========================================================================
-- Automation
-- ===========================================================================

local Auto = AIO:NewModule("automation", {
    title    = L["Automation"],
    short    = L["Battleground release, declining duels and invitations, accepting groups."],
    desc     = L["Small things the game asks you again and again, answered for you. Each one can be switched on and off."],
    category = "comfort",
    default  = true,
    defaults = { bgRelease = true, declineDuels = false, declineGuild = false, declineCharters = false,
                 acceptGroups = false, acceptRes = false },
    options  = {
        { type = "toggle", key = "bgRelease", label = L["Release in battlegrounds"],
          desc = L["Releases your spirit automatically when you die in a battleground (not with a soulstone)."] },
        { type = "toggle", key = "declineDuels",    label = L["Decline duels"] },
        { type = "toggle", key = "declineGuild",    label = L["Decline guild invitations"] },
        { type = "toggle", key = "declineCharters", label = L["Decline guild charters"] },
        { type = "toggle", key = "acceptGroups",    label = L["Accept groups from friends and guild"] },
        { type = "toggle", key = "acceptRes",       label = L["Accept resurrection out of combat"] },
    },
})

local function BaseName(name)
    return name and (name:match("^([^%-]+)") or name)
end

local function IsFriend(name)
    name = BaseName(name)
    if not name then return false end
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and BaseName(info.name) == name then return true end
        end
    elseif GetNumFriends and GetFriendInfo then
        for i = 1, GetNumFriends() or 0 do
            if BaseName((GetFriendInfo(i))) == name then return true end
        end
    end
    return false
end

local function IsGuildMate(name)
    name = BaseName(name)
    if not name or not (IsInGuild and IsInGuild()) or not GetNumGuildMembers then return false end
    for i = 1, GetNumGuildMembers() or 0 do
        if BaseName((GetGuildRosterInfo(i))) == name then return true end
    end
    return false
end

--- Hides a pop-up without letting its OnHide decline what was just accepted.
local function HideAccepted(which)
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local f = _G["StaticPopup" .. i]
        if f and f.which == which then f.inviteAccepted = true end
    end
    HidePopup(which)
end

Auto:On("PLAYER_DEAD", function()
    if not Auto.db.bgRelease then return end
    local _, kind = IsInInstance()
    if kind ~= "pvp" then return end
    if HasSoulstone and HasSoulstone() then return end
    After(0.6, function()
        if not Auto.enabled then return end
        if UnitIsDead("player") and not UnitIsGhost("player") then RepopMe() end
    end)
end)

Auto:On("DUEL_REQUESTED", function(name)
    if not Auto.db.declineDuels then return end
    CancelDuel()
    HidePopup("DUEL_REQUESTED")
    Auto:Print(L["Declined a duel from %s."], tostring(name))
end)

Auto:On("GUILD_INVITE_REQUEST", function(name)
    if not Auto.db.declineGuild then return end
    DeclineGuild()
    HidePopup("GUILD_INVITE")
    Auto:Print(L["Declined a guild invitation from %s."], tostring(name))
end)

Auto:On("PETITION_SHOW", function()
    if not Auto.db.declineCharters then return end
    if GetPetitionInfo then
        local kind, _, _, _, _, isOriginator = GetPetitionInfo()
        if isOriginator or (kind and kind ~= "guild") then return end
    end
    ClosePetition()
end)

Auto:On("PARTY_INVITE_REQUEST", function(name)
    if not Auto.db.acceptGroups or not name then return end
    if not (IsFriend(name) or IsGuildMate(name)) then return end
    AcceptGroup()
    AIO:Later("aioPartyInvite", function() HideAccepted("PARTY_INVITE") end)
    Auto:Print(L["Accepted the group invitation from %s."], name)
end)

Auto:On("RESURRECT_REQUEST", function()
    if not Auto.db.acceptRes or InCombat() then return end
    AcceptResurrect()
    AIO:Later("aioResurrect", function()
        HidePopup("RESURRECT")
        HidePopup("RESURRECT_NO_SICKNESS")
        HidePopup("RESURRECT_NO_TIMER")
    end)
end)

function Auto:OnEnable()
    -- Keep the guild roster fresh for recognising guild members.
    if self.db.acceptGroups then
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then pcall(GuildRoster) end
    end
end

function Auto:OnDisable() end
