-- AllInOne: spell ranks. Finds spells on the action bars (and in macros)
-- that are not at the highest rank you know, marks them on the bars, lists
-- them in a window and replaces them with one click.
--
-- Written for AllInOne; the idea comes from Nova Spell Rank Checker.
--
-- Cost: nothing runs on a timer. A check runs once, a moment after the
-- spell book or an action slot changed (several changes in a row become one
-- check), and reuses its tables.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Lower ranks on your bars"]        = "Niedrige Ränge auf deinen Leisten"
    L["Marks spells on your action bars that are not at their highest rank, lists them and replaces them with one click."] =
        "Markiert Zauber auf deinen Aktionsleisten, die nicht den höchsten Rang haben, listet sie auf und ersetzt sie mit einem Klick."
    L["Checks your action bars after you learn a new rank. Buttons you deliberately keep at a lower rank (for example to heal with less mana) can be ignored."] =
        "Prüft deine Aktionsleisten, sobald du einen neuen Rang lernst. Knöpfe, die du absichtlich auf einem niedrigeren Rang hältst (etwa zum Heilen mit weniger Mana), kannst du ignorieren."
    L["Check automatically"]             = "Automatisch prüfen"
    L["After learning a spell or changing a bar."] = "Nach dem Lernen eines Zaubers oder dem Ändern einer Leiste."
    L["Mark buttons on the bars"]        = "Knöpfe auf den Leisten markieren"
    L["Message in chat"]                 = "Meldung im Chat"
    L["Open list"]                       = "Liste öffnen"
    L["Forget ignored spells"]           = "Alle Ignorierten freigeben"
    L["Ignore spells"]                   = "Zauber ignorieren"
    L["Undo"]                            = "Rückgängig"
    L["Check now"]                       = "Jetzt prüfen"
    L["Actions"]                         = "Aktionen"
    L["Settings"]                        = "Einstellungen"
    L["Ignore mode: click action buttons to ignore them (red) or to stop ignoring them. ESC or Done to finish."] =
        "Ignorier-Modus: Klicke Aktionsknöpfe an, um sie zu ignorieren (rot) oder wieder freizugeben. ESC oder Fertig zum Beenden."
    L["Done"]                            = "Fertig"
    L["Restored %d spells."]             = "%d Zauber wiederhergestellt."
    L["Nothing to undo."]                = "Nichts rückgängig zu machen."
    L["Ignored buttons: %d"]             = "Ignorierte Knöpfe: %d"
    L["Undo puts back the spells the last \"Replace all\" changed, as long as nothing else has been put in those slots since."] =
        "Rückgängig setzt die Zauber zurück, die das letzte «Alle ersetzen» geändert hat, solange seither nichts anderes auf diese Plätze gelegt wurde."
    L["In ignore mode you click the action buttons you want to keep at a lower rank, the way you set key bindings."] =
        "Im Ignorier-Modus klickst du die Aktionsknöpfe an, die einen niedrigeren Rang behalten sollen, so wie beim Belegen von Tasten."
    L["Ignored: %d"]                     = "Ignoriert: %d"
    L["Spell ranks"]                     = "Zauberränge"
    L["Check ranks"]                     = "Ränge prüfen"
    L["Replace all"]                     = "Alle ersetzen"
    L["Ignore"]                          = "Ignorieren"
    L["Rank %d » %d"]                    = "Rang %d » %d"
    L["Bar %d, slot %d"]                 = "Leiste %d, Platz %d"
    L["Macro: %s"]                       = "Makro: %s"
    L["All spells on your bars are at their highest rank."] = "Alle Zauber auf deinen Leisten haben den höchsten Rang."
    L["%d spells on your bars are not at their highest rank. /aio ranks"] =
        "%d Zauber auf deinen Leisten haben nicht den höchsten Rang. /aio ranks"
    L["Replaced %d spells."]             = "%d Zauber ersetzt."
    L["Macros have to be changed by hand."] = "Makros musst du selbst anpassen."
    L["Not in combat."]                  = "Nicht im Kampf."
    L["Left-click: pick up the highest rank"] = "Linksklick: höchsten Rang aufnehmen"
    L["Too low"]                         = "Zu niedrig"
    L["Ignored"]                         = "Ignoriert"
    L["Release"]                         = "Freigeben"
    L["Replace"]                         = "Ersetzen"
    L["Puts the highest rank on this button."] = "Legt den höchsten Rang auf diesen Knopf."
    L["(empty)"]                         = "(leer)"
    L["No ignored buttons."]             = "Keine ignorierten Knöpfe."
    L["Show ignored"]                    = "Ignorierte anzeigen"
end

local M = AIO:NewModule("spellranks", {
    title    = L["Settings"],
    pageTitle = "Spell Ranks Checker",
    short    = L["Marks spells on your action bars that are not at their highest rank, lists them and replaces them with one click."],
    desc     = L["Checks your action bars after you learn a new rank. Buttons you deliberately keep at a lower rank (for example to heal with less mana) can be ignored."],
    category = "spellranks",
    default  = true,
    defaults = { auto = true, mark = true, chat = true, ignoreSlots = {} },
})
M.slash = "ranks"

M.options = {
    { type = "header", label = L["Actions"] },
    { type = "custom", build = function(parent, width, m)
        local x = 0
        local function add(label, fn)
            local b = Style.Button(parent, label, 140, 24, fn)
            b:SetPoint("TOPLEFT", x, 0)
            x = x + 146
            return b
        end
        add(L["Replace all"], function() m:ReplaceAll() end)
        m.undoButton = add(L["Undo"], function() m:Undo() end)
        add(L["Ignore spells"], function() m:IgnoreMode(true) end)
        local list = Style.Button(parent, L["Open list"], 140, 24, function() m:OpenList("low") end)
        list:SetPoint("TOPLEFT", 0, -30)
        local shown = Style.Button(parent, L["Show ignored"], 140, 24, function() m:OpenList("ignored") end)
        shown:SetPoint("TOPLEFT", 146, -30)
        local forget = Style.Button(parent, L["Forget ignored spells"], 200, 24, function()
            wipe(m.db.ignoreSlots)
            m:Check()
        end)
        forget:SetPoint("TOPLEFT", 292, -30)
        return 56
    end },
    { type = "text", label = L["In ignore mode you click the action buttons you want to keep at a lower rank, the way you set key bindings."] },
    { type = "text", label = L["Undo puts back the spells the last \"Replace all\" changed, as long as nothing else has been put in those slots since."] },
    { type = "header", label = L["Options"] },
    { type = "toggle", key = "auto", label = L["Check automatically"], desc = L["After learning a spell or changing a bar."] },
    { type = "toggle", key = "mark", label = L["Mark buttons on the bars"] },
    { type = "toggle", key = "chat", label = L["Message in chat"] },
}

-- ---------------------------------------------------------------------------
-- Spell data
-- ---------------------------------------------------------------------------

local GetSubtext = (C_Spell and C_Spell.GetSpellSubtext) or _G.GetSpellSubtext
local GetLink = (C_Spell and C_Spell.GetSpellLink) or _G.GetSpellLink
local PickupSpellID = (C_Spell and C_Spell.PickupSpell) or _G.PickupSpell

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    return (GetSpellInfo(id))
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    local _, _, icon = GetSpellInfo(id)
    return icon
end

local function RankOf(text)
    return text and tonumber(text:match("(%d+)"))
end

local best = {}      -- [name] = { rank, id }
local rankOf = {}    -- [spellID] = rank, from the spell book
local waiting = {}   -- spells whose data is still loading

--- The highest known rank of every spell in the spell book.
local function ReadSpellBook()
    for _, v in pairs(best) do v.rank = 0 end
    wipe(rankOf)
    local function add(name, sub, id)
        local rank = RankOf(sub)
        if not (name and rank and id) then return end
        rankOf[id] = rank
        local b = best[name]
        if not b then b = { rank = 0 }; best[name] = b end
        if rank > b.rank then b.rank, b.id = rank, id end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and not _G.GetNumSpellTabs then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if info then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local name, sub, id = C_SpellBook.GetSpellBookItemName(i, bank)
                    -- The modern client gives the spell ID only with the item info.
                    if not id and C_SpellBook.GetSpellBookItemInfo then
                        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                        id = item and (item.spellID or item.actionID)
                        if not sub and item and item.subName then sub = item.subName end
                    end
                    if not sub and id and GetSubtext then sub = GetSubtext(id) end
                    add(name, sub, id)
                end
            end
        end
    elseif _G.GetNumSpellTabs then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for i = offset + 1, offset + count do
                local name, sub, id = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
                add(name, sub, id)
            end
        end
    end
end

--- Rank of a spell on a bar: from the spell book, else from its own data.
local function ActionRank(id)
    local rank = rankOf[id]
    if rank then return rank end
    local sub = GetSubtext and GetSubtext(id)
    if sub == nil and C_Spell and C_Spell.RequestLoadSpellData and not waiting[id] then
        waiting[id] = true
        C_Spell.RequestLoadSpellData(id)
    end
    return RankOf(sub)
end

-- ---------------------------------------------------------------------------
-- The check
-- ---------------------------------------------------------------------------

local found = {}     -- list of { slot, id, name, rank, best, bestID, macro }
local lowAll = {}    -- [slot] = true for every lower rank, ignored or not
local pool = {}      -- entries reused between checks

function M:Check()
    if not self.enabled or not _G.HasAction then return 0 end
    ReadSpellBook()
    local ignore = self.db.ignoreSlots
    local n = 0
    wipe(lowAll)
    for slot = 1, 120 do
        if HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            local macroName
            if kind == "macro" then
                macroName = GetMacroInfo(id)
                id = GetMacroSpell and GetMacroSpell(id) or nil
            elseif kind ~= "spell" then
                id = nil
            end
            if id then
                local name = SpellName(id)
                local b = name and best[name]
                local rank = b and b.rank > 0 and ActionRank(id)
                if rank and rank < b.rank then lowAll[slot] = true end
                if rank and rank < b.rank and not ignore[slot] then
                    n = n + 1
                    local e = pool[n]
                    if not e then e = {}; pool[n] = e end
                    e.slot, e.id, e.name, e.rank, e.best, e.bestID, e.macro =
                        slot, id, name, rank, b.rank, b.id, macroName
                    found[n] = e
                end
            end
        end
    end
    for i = n + 1, #found do found[i] = nil end

    self:Mark()
    if self.list and self.list:IsShown() then self:FillList() end
    if self.undoButton then self.undoButton:SetEnabled(self.db.lastReplace ~= nil) end
    return n
end

local function RequestCheck(announce)
    if announce then M.announce = true end
    AIO:Later("spellranks", function()
        local n = M:Check() or 0
        if M.announce and M.db.chat and n > 0 then
            M:Print(L["%d spells on your bars are not at their highest rank. /aio ranks"], n)
        end
        M.announce = nil
    end)
end

-- ---------------------------------------------------------------------------
-- Marks on the action buttons
-- ---------------------------------------------------------------------------

-- Every action button the default UI and the common bar addons create,
-- found by name once and kept.
local BAR_NAMES = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
                    "MultiBarRightButton", "MultiBarLeftButton" }
local buttons

local function CollectButtons()
    buttons = {}
    for _, prefix in ipairs(BAR_NAMES) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if b then buttons[#buttons + 1] = b end
        end
    end
    for i = 1, 120 do
        local b = _G["BT4Button" .. i] or _G["DominosActionButton" .. i]
        if b then buttons[#buttons + 1] = b end
    end
    for bar = 1, 15 do
        for i = 1, 12 do
            local b = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if b then buttons[#buttons + 1] = b end
        end
    end
end

local function ButtonSlot(b)
    local slot = b._state_action or b.action
    if not slot and b.GetAttribute then slot = b:GetAttribute("action") end
    return tonumber(slot)
end

local marks = {}      -- [button] = overlay

local AMBER = { 1, 0.86, 0.32 }

local function Mark(b)
    local m = marks[b]
    if not m then
        m = CreateFrame("Frame", nil, b)
        m:SetAllPoints()
        m:SetFrameLevel(b:GetFrameLevel() + 5)
        m:EnableMouse(false)
        -- Soft light around the button; only this part pulses.
        local halo = CreateFrame("Frame", nil, m)
        halo:SetAllPoints()
        local glow = halo:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER")
        glow:SetSize((b:GetWidth() or 36) * 1.9, (b:GetHeight() or 36) * 1.9)
        glow:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 1)
        -- A crisp light frame and a faint tint over the icon.
        local tint = m:CreateTexture(nil, "ARTWORK")
        tint:SetTexture(Style.WHITE)
        tint:SetAllPoints()
        tint:SetVertexColor(AMBER[1], AMBER[2], AMBER[3], 0.12)
        for i = 1, 4 do
            local t = m:CreateTexture(nil, "OVERLAY")
            t:SetTexture(Style.WHITE)
            t:SetVertexColor(1, 0.94, 0.62, 1)
            if i <= 2 then
                t:SetPoint(i == 1 and "TOPLEFT" or "BOTTOMLEFT")
                t:SetPoint(i == 1 and "TOPRIGHT" or "BOTTOMRIGHT")
                t:SetHeight(2)
            else
                t:SetPoint(i == 3 and "TOPLEFT" or "TOPRIGHT")
                t:SetPoint(i == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT")
                t:SetWidth(2)
            end
        end
        -- Small badge with an up arrow in the corner.
        local badge = CreateFrame("Frame", nil, m)
        badge:SetSize(14, 14)
        badge:SetPoint("TOPRIGHT", 4, 4)
        Style.Flat(badge, { AMBER[1], AMBER[2], AMBER[3], 1 }, { 0, 0, 0, 1 })
        local arrow = badge:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        arrow:SetSize(12, 12)
        arrow:SetPoint("CENTER", 0, -2)
        arrow:SetVertexColor(0.1, 0.08, 0)
        local ag = halo:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.35)
        a:SetDuration(0.9)
        if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
        m.anim = ag
        marks[b] = m
    end
    m:Show()
    m.anim:Play()
end

function M:Mark()
    for _, m in pairs(marks) do
        m.anim:Stop()
        m:Hide()
    end
    if not self.db.mark or #found == 0 or self.ignoring then return end
    if InCombatLockdown() then self.markLater = true return end
    if not buttons then CollectButtons() end
    local wanted = {}
    for _, e in ipairs(found) do wanted[e.slot] = true end
    for _, b in ipairs(buttons) do
        local slot = ButtonSlot(b)
        if slot and wanted[slot] and b:IsVisible() then Mark(b) end
    end
end

-- ---------------------------------------------------------------------------
-- Replacing
-- ---------------------------------------------------------------------------

function M:ReplaceAll()
    if InCombatLockdown() then
        self:Print(L["Not in combat."])
        return
    end
    if not PickupSpellID or not PlaceAction then return end
    local done, macros = 0, 0
    local record = {}
    ClearCursor()
    for _, e in ipairs(found) do
        if e.macro then
            macros = macros + 1
        elseif e.bestID then
            PickupSpellID(e.bestID)
            PlaceAction(e.slot)
            ClearCursor()
            done = done + 1
            record[#record + 1] = { e.slot, e.id, e.bestID }
        end
    end
    if done > 0 then self.db.lastReplace = record end
    if done > 0 then self:Print(L["Replaced %d spells."], done) end
    if macros > 0 then self:Print(L["Macros have to be changed by hand."]) end
    RequestCheck()
end

--- Replaces a single button; "Undo" then puts back just this one.
function M:ReplaceOne(e)
    if InCombatLockdown() then
        self:Print(L["Not in combat."])
        return
    end
    if e.macro or not e.bestID or not PickupSpellID or not PlaceAction then return end
    ClearCursor()
    PickupSpellID(e.bestID)
    PlaceAction(e.slot)
    ClearCursor()
    self.db.lastReplace = { { e.slot, e.id, e.bestID } }
    RequestCheck()
end

--- Puts back what the last "Replace all" changed, slot by slot, but only
--- where the new spell still sits.
function M:Undo()
    local record = self.db.lastReplace
    if not record then
        self:Print(L["Nothing to undo."])
        return
    end
    if InCombatLockdown() then
        self:Print(L["Not in combat."])
        return
    end
    local done = 0
    ClearCursor()
    for _, r in ipairs(record) do
        local slot, old, new = r[1], r[2], r[3]
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id == new then
            PickupSpellID(old)
            PlaceAction(slot)
            ClearCursor()
            done = done + 1
        end
    end
    self.db.lastReplace = nil
    self:Print(L["Restored %d spells."], done)
    RequestCheck()
end

-- ---------------------------------------------------------------------------
-- The list window
-- ---------------------------------------------------------------------------

local ROW_H = 30

local function Where(e)
    if e.macro then return L["Macro: %s"]:format(e.macro) end
    return L["Bar %d, slot %d"]:format(math.floor((e.slot - 1) / 12) + 1, (e.slot - 1) % 12 + 1)
end

local function Row(list, i)
    local r = list.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, list.scroll.child)
    r:SetHeight(ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Style.Text(r, 12)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
    r.info = Style.Text(r, 11, C.muted)
    r.info:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 0)
    r.ignore = Style.Button(r, L["Ignore"], 80, 20)
    r.ignore:SetPoint("RIGHT", -4, 0)
    r.replace = Style.Button(r, L["Replace"], 80, 20)
    r.replace:SetPoint("RIGHT", r.ignore, "LEFT", -4, 0)
    r.line = Style.Line(r)
    r.line:SetPoint("BOTTOMLEFT")
    r.line:SetPoint("BOTTOMRIGHT")
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID and self.bestID then GameTooltip:SetSpellByID(self.bestID) end
        GameTooltip:AddLine(L["Left-click: pick up the highest rank"], C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnClick", function(self)
        if self.bestID and PickupSpellID and not InCombatLockdown() then PickupSpellID(self.bestID) end
    end)
    list.rows[i] = r
    return r
end

local function SlotSpell(slot)
    local kind, id = GetActionInfo(slot)
    local macro
    if kind == "macro" then
        macro = GetMacroInfo(id)
        id = GetMacroSpell and GetMacroSpell(id) or nil
    elseif kind ~= "spell" then
        id = nil
    end
    return id, macro, kind
end

local ignoredRows = {}

function M:FillList()
    local list = self.list
    local tab = list.tab or "low"
    local rows = found
    if tab == "ignored" then
        wipe(ignoredRows)
        local slots = {}
        for slot in pairs(self.db.ignoreSlots) do slots[#slots + 1] = slot end
        table.sort(slots)
        for _, slot in ipairs(slots) do
            local id, macro = SlotSpell(slot)
            ignoredRows[#ignoredRows + 1] = { slot = slot, id = id, macro = macro,
                name = id and SpellName(id) or (macro or L["(empty)"]), rank = id and ActionRank(id) }
        end
        rows = ignoredRows
    end
    for i, e in ipairs(rows) do
        local r = Row(list, i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT", list.scroll.child, "RIGHT", -6, 0)
        r.icon:SetTexture((e.id and SpellIcon(e.id)) or (HasAction(e.slot) and GetActionTexture and GetActionTexture(e.slot)) or nil)
        local slot = e.slot
        if tab == "ignored" then
            local rank = e.rank and ("  |cff999999" .. (RANK or "Rank") .. " " .. e.rank .. "|r") or ""
            r.name:SetText((e.name or "") .. rank)
            r.bestID = nil
            r.ignore:SetLabel(L["Release"])
            r.replace:Hide()
            r.ignore:SetScript("OnClick", function()
                M.db.ignoreSlots[slot] = nil
                M:Check()
            end)
        else
            r.name:SetText(e.name .. "  |cffffd75a" .. L["Rank %d » %d"]:format(e.rank, e.best) .. "|r")
            r.bestID = e.bestID
            r.ignore:SetLabel(L["Ignore"])
            local entry = e
            r.replace:Show()
            r.replace:SetEnabled(not e.macro)
            r.replace.tip = e.macro and L["Macros have to be changed by hand."] or L["Puts the highest rank on this button."]
            r.replace:SetScript("OnClick", function() M:ReplaceOne(entry) end)
            r.ignore:SetScript("OnClick", function()
                M.db.ignoreSlots[slot] = true
                M:Check()
            end)
        end
        r.info:SetText(Where(e))
        r:Show()
    end
    for i = #rows + 1, #list.rows do list.rows[i]:Hide() end
    list.scroll.child:SetHeight(math.max(1, #rows * ROW_H))
    list.scroll:UpdateRange()

    local ignored = 0
    for _ in pairs(self.db.ignoreSlots) do ignored = ignored + 1 end
    list.tabLow:SetLabel(L["Too low"] .. " (" .. #found .. ")")
    list.tabIgnored:SetLabel(L["Ignored"] .. " (" .. ignored .. ")")
    list.tabLow:SetActive(tab == "low")
    list.tabIgnored:SetActive(tab == "ignored")
    list.empty:SetText(tab == "low" and L["All spells on your bars are at their highest rank."] or L["No ignored buttons."])
    list.empty:SetShown(#rows == 0)
    list.undo:SetEnabled(self.db.lastReplace ~= nil)
    list.replace:SetEnabled(#found > 0)
end

local function TabButton(parent, onClick)
    local b = Style.Button(parent, "", 130, 24, onClick)
    function b:SetActive(on)
        self.active = on
        local c = on and C.accent or C.line
        Style.SetBorder(self, c[1], c[2], c[3], 1)
        self.text:SetTextColor(unpack(on and C.text or C.muted))
    end
    b:HookScript("OnLeave", function(self) self:SetActive(self.active) end)
    return b
end

function M:OpenList(tab)
    local list = self.list
    if not list then
        list = Style.Window("AllInOneSpellRanks", 460, 400, L["Spell ranks"])
        -- Above the options window, which sits on the dialog layer.
        list:SetFrameStrata("FULLSCREEN")
        list:SetPoint("CENTER", 60, -20)
        list.rows = {}
        list.tabLow = TabButton(list, function() list.tab = "low"; M:FillList() end)
        list.tabLow:SetPoint("TOPLEFT", 10, -34)
        list.tabIgnored = TabButton(list, function() list.tab = "ignored"; M:FillList() end)
        list.tabIgnored:SetPoint("LEFT", list.tabLow, "RIGHT", 6, 0)
        list.scroll = Style.Scroll(list)
        list.scroll:SetPoint("TOPLEFT", 10, -66)
        list.scroll:SetPoint("BOTTOMRIGHT", -16, 44)
        list.empty = Style.Text(list, 12, C.muted)
        list.empty:SetPoint("TOPLEFT", 14, -74)
        list.empty:SetPoint("RIGHT", -14, 0)
        list.replace = Style.Button(list, L["Replace all"], 130, 24, function() M:ReplaceAll() end)
        list.replace:SetPoint("BOTTOMRIGHT", -10, 10)
        list.undo = Style.Button(list, L["Undo"], 100, 24, function() M:Undo() end)
        list.undo:SetPoint("RIGHT", list.replace, "LEFT", -6, 0)
        local ignore = Style.Button(list, L["Ignore spells"], 120, 24, function() M:IgnoreMode(true) end)
        ignore:SetPoint("RIGHT", list.undo, "LEFT", -6, 0)
        self.list = list
    end
    if tab then list.tab = tab end
    list:Show()
    list:Raise()
    self:Check()
end

function M:Slash()
    if self.list and self.list:IsShown() then self.list:Hide() else self:OpenList() end
end

-- ---------------------------------------------------------------------------
-- Ignore mode: like setting key bindings. Every action button with something
-- on it gets a clickable cover; a click switches "ignore" for that button.
-- The covers are our own frames on top of the bars, so a click never casts.
-- ---------------------------------------------------------------------------

local covers = {}
local banner

-- Ignored: red with ×. A lower rank not yet ignored: amber with the arrow,
-- as on the bars. Everything else: a faint frame you can still click.
local function PaintCover(c)
    local ignored = M.db.ignoreSlots[c.slot]
    local low = lowAll[c.slot]
    local col, alpha
    if ignored then
        col, alpha = C.bad, 0.45
    elseif low then
        col, alpha = AMBER, 0.28
    else
        col, alpha = C.accent, 0.10
    end
    Style.SetBorder(c, col[1], col[2], col[3], 1)
    Style.SetBackground(c, col[1], col[2], col[3], alpha)
    c.mark:SetText(ignored and "×" or "")
    c.badge:SetShown(low and not ignored)
end

local function Cover(b)
    local c = covers[b]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c:SetFrameStrata("DIALOG")
        Style.Flat(c)
        c.mark = c:CreateFontString(nil, "OVERLAY")
        c.mark:SetFontObject(Style.Font(20, "OUTLINE"))
        c.mark:SetPoint("CENTER")
        c.mark:SetTextColor(1, 1, 1)
        c.badge = CreateFrame("Frame", nil, c)
        c.badge:SetSize(14, 14)
        c.badge:SetPoint("TOPRIGHT", 4, 4)
        Style.Flat(c.badge, { AMBER[1], AMBER[2], AMBER[3], 1 }, { 0, 0, 0, 1 })
        local arrow = c.badge:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        arrow:SetSize(12, 12)
        arrow:SetPoint("CENTER", 0, -2)
        arrow:SetVertexColor(0.1, 0.08, 0)
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c:SetScript("OnClick", function(self)
            local slots = M.db.ignoreSlots
            slots[self.slot] = (not slots[self.slot]) or nil
            PaintCover(self)
        end)
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if GameTooltip.SetAction then GameTooltip:SetAction(self.slot) end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", GameTooltip_Hide)
        covers[b] = c
    end
    -- Placed by screen position, not anchored to the (secure) button, so a
    -- fight starting never finds our frame tied to a protected one.
    local scale = (b:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    c:ClearAllPoints()
    c:SetSize((b:GetWidth() or 36) * scale, (b:GetHeight() or 36) * scale)
    c:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (b:GetLeft() or 0) * scale, (b:GetBottom() or 0) * scale)
    c.slot = ButtonSlot(b)
    PaintCover(c)
    c:Show()
end

function M:IgnoreMode(on, quiet)
    if on then
        if InCombatLockdown() then self:Print(L["Not in combat."]) return end
        -- Remember where the mode was started from, to go back there after.
        local panel = _G.AllInOneOptions
        self.backToList = self.list and self.list:IsShown() or false
        self.backToOptions = panel and panel:IsShown() or false
        if self.backToList then self.list:Hide() end
        if self.backToOptions then panel:Hide() end
        self:Check()
        CollectButtons()
        for _, b in ipairs(buttons) do
            local slot = ButtonSlot(b)
            if slot and HasAction(slot) and b:IsVisible() then Cover(b) end
        end
        if not banner then
            banner = CreateFrame("Frame", "AllInOneIgnoreBanner", UIParent)
            banner:SetFrameStrata("DIALOG")
            banner:SetSize(560, 36)
            banner:SetPoint("TOP", 0, -120)
            Style.Flat(banner, C.panel, C.accent)
            local t = Style.Text(banner, 12)
            t:SetPoint("LEFT", 12, 0)
            t:SetPoint("RIGHT", -96, 0)
            t:SetText(L["Ignore mode: click action buttons to ignore them (red) or to stop ignoring them. ESC or Done to finish."])
            local done = Style.Button(banner, L["Done"], 76, 24, function() banner:Hide() end)
            done:SetPoint("RIGHT", -6, 0)
            banner:SetScript("OnHide", function() M:IgnoreMode(false) end)
            tinsert(UISpecialFrames, "AllInOneIgnoreBanner")
        end
        self.ignoring = true
        banner:Show()
        for _, m in pairs(marks) do m:Hide() end
    else
        if not self.ignoring then return end
        self.ignoring = false
        for _, c in pairs(covers) do c:Hide() end
        if banner and banner:IsShown() then banner:Hide() end
        GameTooltip_Hide()
        self:Check()
        local toOptions, toList = self.backToOptions, self.backToList
        self.backToOptions, self.backToList = nil, nil
        if quiet or not self.enabled then return end
        if toOptions then AIO:OpenOptions("spellranks") end
        if toList then self:OpenList() end
    end
end

-- ---------------------------------------------------------------------------
-- Events and switching on and off
-- ---------------------------------------------------------------------------

local function Auto(announce)
    if M.db.auto then RequestCheck(announce) end
end

M:On("LEARNED_SPELL_IN_TAB", function() Auto(true) end)
M:On("SPELLS_CHANGED", function() Auto(false) end)
M:On("ACTIONBAR_SLOT_CHANGED", function() Auto(false) end)
M:On("ACTIONBAR_PAGE_CHANGED", function() if #found > 0 then M:Mark() end end)
M:On("UPDATE_MACROS", function() Auto(false) end)
M:On("SPELL_DATA_LOAD_RESULT", function(id)
    if id and waiting[id] then
        waiting[id] = nil
        RequestCheck()
    end
end)
M:On("PLAYER_REGEN_ENABLED", function()
    if M.markLater then
        M.markLater = nil
        M:Mark()
    end
end)
M:On("PLAYER_REGEN_DISABLED", function() M:IgnoreMode(false, true) end)

function M:OnEnable()
    -- Settings of version 2.2 ignored spells by name; buttons replace that.
    self.db.ignore, self.db.bookButton = nil, nil
    RequestCheck(true)
end

function M:OnDisable()
    for _, m in pairs(marks) do m.anim:Stop(); m:Hide() end
    self:IgnoreMode(false)
    if self.list then self.list:Hide() end
    wipe(found)
end

function M:OnSettingChanged(key)
    if key == "mark" then self:Mark() end
end
