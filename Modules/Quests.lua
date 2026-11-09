-- AllInOne: quests accepted and turned in for you, and gossip that is only a
-- click in the way skipped.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Shift"]                                  = "Umschalt"
    L["Ctrl"]                                   = "Strg"
    L["Alt"]                                    = "Alt"
    L["Hold to suspend"]                        = "Gedrückt halten zum Aussetzen"
    L["Auto accept & turn in"]                  = "Quests automatisch annehmen & abgeben"
    L["Accepts and turns in quests for you."]   = "Nimmt Quests für dich an und gibt sie ab."
    L["Accepts quests and turns in finished ones as soon as you talk to the NPC. Hold the modifier key below while you open the window to do it yourself. Quests that cost money, and the permanent choice between Aldor and Scryers, are never handled for you."]
        = "Nimmt Quests an und gibt erledigte ab, sobald du mit dem NPC sprichst. Halte die Zusatztaste unten gedrückt, während du das Fenster öffnest, um es selbst zu erledigen. Quests, die Geld kosten, und die endgültige Wahl zwischen Aldor und Sehern werden nie für dich erledigt."
    L["Accepting"]                              = "Annehmen"
    L["Accept quests"]                          = "Quests annehmen"
    L["Accept quests shared by your group"]     = "Von der Gruppe geteilte Quests bestätigen"
    L["Confirms escort and group quests started by a group member."]
        = "Bestätigt Begleit- und Gruppenquests, die ein Gruppenmitglied gestartet hat."
    L["Turning in"]                             = "Abgeben"
    L["Turn in quests"]                         = "Quests abgeben"
    L["Pick the most valuable reward"]          = "Die wertvollste Belohnung wählen"
    L["With a choice of rewards, takes the one with the highest vendor price. Otherwise the choice is left to you."]
        = "Bei mehreren Belohnungen wird die mit dem höchsten Verkaufswert genommen. Sonst bleibt die Wahl dir überlassen."
    L["Mark the most valuable reward"]          = "Wertvollste Belohnung markieren"
    L["Shows a small coin on the reward that sells for the most."]
        = "Zeigt eine kleine Münze auf der Belohnung mit dem höchsten Verkaufswert."
    L["NPCs"]                                   = "NPCs"
    L["Handle quests in NPC dialogs"]           = "Quests in NPC-Dialogen auswählen"
    L["Picks finished and new quests from the NPC's dialog."]
        = "Wählt erledigte und neue Quests aus dem Dialog des NPCs."
    L["Skip daily and repeatable quests"]       = "Tägliche und wiederholbare Quests auslassen"
    L["Quest %d"]                               = "Quest %d"
    L["Allegiance to the Aldor"]                = "Treue zu den Aldor"
    L["Allegiance to the Scryers"]              = "Treue zu den Sehern"
    L["Not handled: %s is a permanent choice."] = "Nicht erledigt: %s ist eine endgültige Wahl."
    L["Most valuable reward"]                   = "Wertvollste Belohnung"
    L["Skip gossip"]                            = "Gesprächstexte überspringen"
    L["Picks the only dialog option for you."]  = "Wählt die einzige Dialogoption für dich."
    L["When an NPC has no quests and offers a single dialog option, such as the flight map or the merchant, it is chosen for you. Hold the modifier key below to read the text instead."]
        = "Hat ein NPC keine Quests und bietet nur eine einzige Dialogoption an, etwa die Flugkarte oder den Händler, wird sie für dich gewählt. Halte die Zusatztaste unten gedrückt, um den Text stattdessen zu lesen."
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local MODIFIERS = {
    { value = "SHIFT", label = L["Shift"] },
    { value = "CTRL",  label = L["Ctrl"] },
    { value = "ALT",   label = L["Alt"] },
}

local function ModifierDown(mod)
    if mod == "SHIFT" then return Call(_G.IsShiftKeyDown) and true or false
    elseif mod == "CTRL" then return Call(_G.IsControlKeyDown) and true or false
    elseif mod == "ALT" then return Call(_G.IsAltKeyDown) and true or false end
    return false
end

local function SellPrice(item)
    if not item then return nil end
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not get then return nil end
    local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(get, item)
    if not ok or not name then return nil end
    return tonumber(price) or 0
end

-- ---------------------------------------------------------------------------
-- Auto accept & turn in
-- ---------------------------------------------------------------------------

local DEFAULT_EXCLUDE = {
    [10551] = L["Allegiance to the Aldor"],
    [10552] = L["Allegiance to the Scryers"],
}

local Q = AIO:NewModule("questauto", {
    title    = L["Auto accept & turn in"],
    short    = L["Accepts and turns in quests for you."],
    desc     = L["Accepts quests and turns in finished ones as soon as you talk to the NPC. Hold the modifier key below while you open the window to do it yourself. Quests that cost money, and the permanent choice between Aldor and Scryers, are never handled for you."],
    category = "quests",
    default  = true,
    defaults = {
        modifier = "SHIFT", accept = true, shared = false, turnin = true, bestReward = false,
        markBest = true, gossip = true, skipRepeat = false,
    },
})

--- Quests never handled for you: the choice between Aldor and Scryers is
--- permanent, so it is always left to you.
function Q:Excluded() return DEFAULT_EXCLUDE end

function Q:IsExcluded(questID)
    questID = tonumber(questID)
    return questID and self:Excluded()[questID] and true or false
end

function Q:Suspended()
    return ModifierDown(self.db.modifier)
end

local function CurrentQuestID()
    local id = Call(_G.GetQuestID)
    if id and id > 0 then return id end
end

local function CurrentIsRepeatable()
    return (Call(_G.QuestIsDaily) or Call(_G.QuestIsWeekly)) and true or false
end

--- Checks shared by every step in the quest frame. Returns true when we may act.
function Q:MayHandle(stage)
    if self:Suspended() then return false end
    local id = CurrentQuestID()
    if id and self:IsExcluded(id) then
        if self.warned ~= id then
            self.warned = id
            local title = Call(_G.GetTitleText) or (L["Quest %d"]):format(id)
            self:Print(L["Not handled: %s is a permanent choice."], title)
        end
        return false
    end
    if (tonumber(Call(_G.GetQuestMoneyToGet)) or 0) > 0 then return false end
    if self.db.skipRepeat and CurrentIsRepeatable() then return false end
    return true
end

Q:On("QUEST_DETAIL", function()
    if not Q.db.accept or not Q:MayHandle("detail") then return end
    Call(_G.AcceptQuest)
end)

Q:On("QUEST_ACCEPT_CONFIRM", function()
    if not Q.db.shared or Q:Suspended() then return end
    Call(_G.ConfirmAcceptQuest)
    Call(_G.StaticPopup_Hide, "QUEST_ACCEPT")
end)

Q:On("QUEST_PROGRESS", function()
    if not Q.db.turnin or not Q:MayHandle("progress") then return end
    if Call(_G.IsQuestCompletable) then Call(_G.CompleteQuest) end
end)

--- Index of the choice that sells for the most, or nil (also when an item is not cached yet).
function Q:BestChoice()
    local n = tonumber(Call(_G.GetNumQuestChoices)) or 0
    if n < 2 then return nil end
    local best, bestValue = nil, -1
    for i = 1, n do
        local link = Call(_G.GetQuestItemLink, "choice", i)
        local price = SellPrice(link)
        if price == nil then return nil, true end
        local _, _, count = Call(_G.GetQuestItemInfo, "choice", i)
        local value = price * math.max(1, tonumber(count) or 1)
        if value > bestValue then best, bestValue = i, value end
    end
    if bestValue <= 0 then return nil end
    return best
end

-- The coin on the most valuable reward.
local coin
local function RewardButton(index)
    local frame = _G.QuestInfoRewardsFrame
    local buttons = frame and frame.RewardButtons
    if type(buttons) == "table" then
        for _, b in ipairs(buttons) do
            if b.type == "choice" and b.GetID and b:GetID() == index and b:IsShown() then return b end
        end
        local b = buttons[index]
        if b and (b.type == nil or b.type == "choice") then return b end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. index] or _G["QuestInfoItem" .. index]
end

function Q:HideCoin()
    if coin then coin:Hide() end
end

function Q:MarkBest(index)
    local button = RewardButton(index)
    if not button then return end
    if not coin then
        coin = CreateFrame("Frame", nil, button)
        coin:SetSize(16, 16)
        Style.Flat(coin, C.panel, C.warn)
        coin.icon = coin:CreateTexture(nil, "OVERLAY")
        coin.icon:SetPoint("TOPLEFT", 1, -1)
        coin.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        coin.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        coin:EnableMouse(true)
        coin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Most valuable reward"], 1, 0.82, 0)
            GameTooltip:Show()
        end)
        coin:SetScript("OnLeave", function() GameTooltip_Hide() end)
    end
    coin:SetParent(button)
    coin:ClearAllPoints()
    local anchor = button.Icon or button.icon or _G[(button.GetName and button:GetName() or "") .. "IconTexture"] or button
    coin:SetPoint("TOPLEFT", anchor, "TOPLEFT", -4, 4)
    if coin.SetFrameLevel and button.GetFrameLevel then
        local lvl = button:GetFrameLevel()
        if lvl then coin:SetFrameLevel(lvl + 5) end
    end
    coin:Show()
    self.markedIndex = index
end

function Q:OnComplete(attempt)
    attempt = attempt or 1
    local n = tonumber(Call(_G.GetNumQuestChoices)) or 0
    local best, pending = self:BestChoice()
    if pending and attempt < 6 then
        C_Timer.After(0.2, function() if Q.enabled and Q.completeOpen then Q:OnComplete(attempt + 1) end end)
        return
    end
    if best and self.db.markBest then
        AIO:Later("aioQuestCoin", function() if Q.completeOpen then Q:MarkBest(best) end end)
    end
    if not self.db.turnin or not self:MayHandle("complete") then return end
    if n <= 1 then
        Call(_G.GetQuestReward, n)
    elseif best and self.db.bestReward then
        Call(_G.GetQuestReward, best)
    end
end

Q:On("QUEST_COMPLETE", function()
    Q.completeOpen = true
    Q:HideCoin()
    Q:OnComplete(1)
end)

local function QuestClosed()
    Q.completeOpen = false
    Q:HideCoin()
end
Q:On("QUEST_FINISHED", QuestClosed)
Q:On("QUEST_DETAIL", function() Q:HideCoin() end)

-- Gossip and greeting windows ------------------------------------------------

--- Quests in a gossip window, in one shape:
--- { questID, title, isComplete, repeatable, index }
local function GossipQuests(kind)
    local list = {}
    local G = C_GossipInfo
    local fn = G and (kind == "active" and G.GetActiveQuests or G.GetAvailableQuests)
    if fn then
        local infos = Call(fn)
        if type(infos) == "table" then
            for i, q in ipairs(infos) do
                list[#list + 1] = {
                    questID = q.questID, title = q.title, index = i,
                    isComplete = q.isComplete,
                    repeatable = q.repeatable or (q.frequency and q.frequency > 0) or false,
                }
            end
            return list, true
        end
    end
    -- The older API: flat lists with a fixed number of fields per quest.
    local count = Call(kind == "active" and _G.GetNumGossipActiveQuests or _G.GetNumGossipAvailableQuests) or 0
    if count > 0 then
        local packed = { Call(kind == "active" and _G.GetGossipActiveQuests or _G.GetGossipAvailableQuests) }
        local stride = math.max(1, math.floor(#packed / count))
        for i = 1, count do
            local base = (i - 1) * stride
            local q = { title = packed[base + 1], index = i }
            if kind == "active" then
                q.isComplete = packed[base + 4] and true or false
            else
                local freq = packed[base + 4]
                q.repeatable = (type(freq) == "number" and freq > 0) or packed[base + 5] and true or false
            end
            list[#list + 1] = q
        end
    end
    return list, false
end

local function SelectGossipQuest(kind, q, modern)
    local G = C_GossipInfo
    if modern then
        local fn = kind == "active" and G.SelectActiveQuest or G.SelectAvailableQuest
        if q.questID then return Call(fn, q.questID) end
        return Call(fn, q.index)
    end
    return Call(kind == "active" and _G.SelectGossipActiveQuest or _G.SelectGossipAvailableQuest, q.index)
end

function Q:Allowed(q)
    if q.questID and self:IsExcluded(q.questID) then return false end
    if self.db.skipRepeat and q.repeatable then return false end
    return true
end

Q:On("GOSSIP_SHOW", function()
    if not Q.db.gossip or Q:Suspended() then return end
    if Q.db.turnin then
        local active, modern = GossipQuests("active")
        for _, q in ipairs(active) do
            if q.isComplete and Q:Allowed(q) then return SelectGossipQuest("active", q, modern) end
        end
    end
    if Q.db.accept then
        local available, modern = GossipQuests("available")
        for _, q in ipairs(available) do
            if Q:Allowed(q) then return SelectGossipQuest("available", q, modern) end
        end
    end
end)

--- Is the quest called `title` finished, judging by the quest log?
local function LogComplete(title)
    if not title or not GetNumQuestLogEntries then return false end
    local n = Call(GetNumQuestLogEntries) or 0
    for i = 1, n do
        local t, _, _, isHeader, _, isComplete = Call(GetQuestLogTitle, i)
        if t == title and not isHeader then return isComplete == 1 or isComplete == true end
    end
    return false
end

Q:On("QUEST_GREETING", function()
    if not Q.db.gossip or Q:Suspended() then return end
    if Q.db.turnin then
        local n = Call(_G.GetNumActiveQuests) or 0
        for i = 1, n do
            local title, isComplete = Call(_G.GetActiveTitle, i)
            if isComplete == nil then isComplete = LogComplete(title) end
            local id = Call(_G.GetActiveQuestID, i)
            if isComplete and not (id and Q:IsExcluded(id)) then return Call(_G.SelectActiveQuest, i) end
        end
    end
    if Q.db.accept then
        local n = Call(_G.GetNumAvailableQuests) or 0
        for i = 1, n do
            local _, frequency, repeatable, _, id = Call(_G.GetAvailableQuestInfo, i)
            local q = { questID = id, repeatable = repeatable or (type(frequency) == "number" and frequency > 0) }
            if Q:Allowed(q) then return Call(_G.SelectAvailableQuest, i) end
        end
    end
end)

-- Options ----------------------------------------------------------------------


local function NotTurnin(M) return not M.db.turnin end

Q.options = {
    { type = "select", key = "modifier", label = L["Hold to suspend"], values = MODIFIERS, width = 160 },
    { type = "header", label = L["Accepting"] },
    { type = "toggle", key = "accept", label = L["Accept quests"] },
    { type = "toggle", key = "shared", label = L["Accept quests shared by your group"],
      desc = L["Confirms escort and group quests started by a group member."] },
    { type = "header", label = L["Turning in"] },
    { type = "toggle", key = "turnin", label = L["Turn in quests"] },
    { type = "toggle", key = "bestReward", label = L["Pick the most valuable reward"],
      desc = L["With a choice of rewards, takes the one with the highest vendor price. Otherwise the choice is left to you."],
      disabled = NotTurnin },
    { type = "toggle", key = "markBest", label = L["Mark the most valuable reward"],
      desc = L["Shows a small coin on the reward that sells for the most."] },
    { type = "header", label = L["NPCs"] },
    { type = "toggle", key = "gossip", label = L["Handle quests in NPC dialogs"],
      desc = L["Picks finished and new quests from the NPC's dialog."] },
    { type = "toggle", key = "skipRepeat", label = L["Skip daily and repeatable quests"] },
}

-- The editable exclusion list was taken out; an old saved one is dropped.
function Q:OnEnable() self.db.exclude = nil end
function Q:OnDisable() self:HideCoin() end

-- ---------------------------------------------------------------------------
-- Skip gossip
-- ---------------------------------------------------------------------------

local G = AIO:NewModule("gossip", {
    title    = L["Skip gossip"],
    short    = L["Picks the only dialog option for you."],
    desc     = L["When an NPC has no quests and offers a single dialog option, such as the flight map or the merchant, it is chosen for you. Hold the modifier key below to read the text instead."],
    category = "quests",
    default  = true,
    defaults = { modifier = "SHIFT" },
    options  = {
        { type = "select", key = "modifier", label = L["Hold to suspend"], values = MODIFIERS, width = 160 },
    },
})

local function NumGossipQuests()
    local CG = C_GossipInfo
    local n = 0
    if CG and (CG.GetNumActiveQuests or CG.GetActiveQuests) then
        local a = CG.GetNumActiveQuests and Call(CG.GetNumActiveQuests)
        if a == nil then local t = Call(CG.GetActiveQuests); a = type(t) == "table" and #t or 0 end
        local b = CG.GetNumAvailableQuests and Call(CG.GetNumAvailableQuests)
        if b == nil then local t = Call(CG.GetAvailableQuests); b = type(t) == "table" and #t or 0 end
        return (a or 0) + (b or 0)
    end
    n = (Call(_G.GetNumGossipActiveQuests) or 0) + (Call(_G.GetNumGossipAvailableQuests) or 0)
    return n
end

--- The options as a list of { id = gossipOptionID or nil }.
local function GossipOptions()
    local CG = C_GossipInfo
    if CG and CG.GetOptions then
        local t = Call(CG.GetOptions)
        if type(t) == "table" then
            local list = {}
            for i, o in ipairs(t) do
                list[i] = { id = o.gossipOptionID or o.optionID, name = o.name }
            end
            return list
        end
    end
    local packed = { Call(_G.GetGossipOptions) }
    local list = {}
    for i = 1, math.floor(#packed / 2) do list[i] = { name = packed[i * 2 - 1] } end
    return list
end

local lastSkip = { guid = nil, time = 0, closed = true }

G:On("GOSSIP_SHOW", function()
    if ModifierDown(G.db.modifier) then return end
    local guid = Call(_G.UnitGUID, "npc") or "?"
    -- Only once per interaction: not again before the window has closed and a moment passed.
    if lastSkip.guid == guid and (not lastSkip.closed or GetTime() - lastSkip.time < 2) then return end
    if NumGossipQuests() > 0 then return end
    local options = GossipOptions()
    if #options ~= 1 then return end
    lastSkip.guid, lastSkip.time, lastSkip.closed = guid, GetTime(), false
    local CG = C_GossipInfo
    if options[1].id and CG and CG.SelectOption then
        Call(CG.SelectOption, options[1].id)
    elseif _G.SelectGossipOption then
        Call(_G.SelectGossipOption, 1)
    elseif CG and CG.SelectOption then
        Call(CG.SelectOption, 1)
    end
end)

AIO:On("GOSSIP_CLOSED", function() lastSkip.closed = true end)

function G:OnDisable() end
