-- AllInOne: consumable tracker. Five small slots — flask, battle elixir,
-- guardian elixir, food buff and weapon oil or stone — each with the time
-- left, dimmed and red when missing. A click uses the best item you carry.
--
-- Flasks and elixirs are recognised by the spell their item uses (the buff
-- carries that spell's name and id). A flask fills both elixir slots.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Consumable tracker"] = "Verbrauchsgüter-Anzeige"
    L["Flask, elixirs, food and weapon oil at a glance; click to use."] = "Fläschchen, Elixiere, Essen und Waffenöl auf einen Blick; Klick benutzt."
    L["Shows five small slots for flask, battle elixir, guardian elixir, food buff and weapon oil or sharpening stone, each with the time left. A missing one is dimmed with a red border. A flask counts for both elixir slots. Click a slot to use the best matching item from your bags (not during combat changes)."] = "Zeigt fünf kleine Felder für Fläschchen, Kampfelixier, Wächterelixier, Essensbuff und Waffenöl oder Wetzstein, jeweils mit der Restzeit. Fehlt etwas, ist das Feld abgedunkelt und rot umrandet. Ein Fläschchen zählt für beide Elixierfelder. Ein Klick benutzt den besten passenden Gegenstand aus den Taschen (Änderungen nicht im Kampf)."
    L["Flask"] = "Fläschchen"
    L["Battle Elixir"] = "Kampfelixier"
    L["Guardian Elixir"] = "Wächterelixier"
    L["Food buff"] = "Essensbuff"
    L["Weapon oil / stone"] = "Waffenöl / Wetzstein"
    L["Display"] = "Anzeige"
    L["Only in dungeons and raids"] = "Nur in Dungeons und Schlachtzügen"
    L["Lock position"] = "Position sperren"
    L["Scale"] = "Skalierung"
    L["Warn before expiry"] = "Warnen vor Ablauf"
    L["%d min"] = "%d Min."
    L["Off"] = "Aus"
    L["Slots"] = "Felder"
    L["Reset position"] = "Position zurücksetzen"
    L["Consumables"] = "Verbrauchsgüter"
    L["Drag to move"] = "Ziehen zum Verschieben"
    L["Missing"] = "Fehlt"
    L["%s left"] = "Noch %s"
    L["Covered by your flask"] = "Durch dein Fläschchen abgedeckt"
    L["Click: use %s"] = "Klick: %s benutzen"
    L["None in your bags"] = "Keines in den Taschen"
end

-- ---------------------------------------------------------------------------
-- Items per slot, roughly best first
-- ---------------------------------------------------------------------------

local ITEMS = {
    flask = {
        22854, 22851, 22866, 22861, 22853, 33208,           -- TBC
        32901, 32898, 32899, 32900, 35716, 35717,           -- Shattrath flasks
        13510, 13511, 13512, 13513,                         -- classic
    },
    battle = {
        22831, 22824, 28104, 28102, 28103, 22825, 22833, 22835, 22827, 31679, 22848,
        13452, 9206, 13454, 9264, 21546,
    },
    guardian = {
        22834, 32062, 32068, 32063, 32067, 22840,
        9088, 3825, 13445, 20007,
    },
    weapon = {
        22522, 22521, 23528, 23529, 28421, 28420, 20749, 20748, 18262,
    },
}

local SLOTS = {
    { key = "flask",    label = L["Flask"] },
    { key = "battle",   label = L["Battle Elixir"] },
    { key = "guardian", label = L["Guardian Elixir"] },
    { key = "food",     label = L["Food buff"] },
    { key = "weapon",   label = L["Weapon oil / stone"] },
}

local WELL_FED = 19705
local FOOD_ICON = "Interface\\Icons\\Spell_Misc_Food"
local SIZE, GAP = 30, 3

local defaults = {
    instanceOnly = true, locked = true, scale = 1, threshold = 5,
    point = { "TOP", "UIParent", "TOP", 120, -140 },
    last = {},
}
for _, s in ipairs(SLOTS) do defaults["slot_" .. s.key] = true end

local function Minutes(v) return v == 0 and L["Off"] or L["%d min"]:format(v) end
local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end

local options = {
    { type = "header", label = L["Display"] },
    { type = "toggle", key = "instanceOnly", label = L["Only in dungeons and raids"], half = true },
    { type = "toggle", key = "locked", label = L["Lock position"], half = true },
    { type = "slider", key = "threshold", label = L["Warn before expiry"], min = 0, max = 15, step = 1, format = Minutes, half = true },
    { type = "slider", key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05, format = Percent, half = true },
    { type = "header", label = L["Slots"] },
}
for _, s in ipairs(SLOTS) do
    options[#options + 1] = { type = "toggle", key = "slot_" .. s.key, label = s.label, half = true }
end
options[#options + 1] = { type = "button", label = L["Reset position"], func = function(m)
    m.db.point = nil
    AIO.CopyDefaults(m.db, defaults)
    m:Place()
end }

local M = AIO:NewModule("consumables", {
    title    = L["Consumable tracker"],
    short    = L["Flask, elixirs, food and weapon oil at a glance; click to use."],
    desc     = L["Shows five small slots for flask, battle elixir, guardian elixir, food buff and weapon oil or sharpening stone, each with the time left. A missing one is dimmed with a red border. A flask counts for both elixir slots. Click a slot to use the best matching item from your bags (not during combat changes)."],
    category = "buffs",
    default  = true,
    defaults = defaults,
    options  = options,
})

-- ---------------------------------------------------------------------------
-- Item spells: which buff belongs to which slot
-- ---------------------------------------------------------------------------

local byName, bySpell = {}, {}     -- buff name / spell id -> { slot, item }
local missingData = {}             -- item id -> true while its spell is unknown
local foodName

local function ItemSpell(itemID)
    local get = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
    if not get then return nil end
    local ok, name, spellID = pcall(get, itemID)
    if ok then return name, spellID end
end

local function RequestItem(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    elseif _G.GetItemInfo then
        GetItemInfo(itemID)
    end
end

local function SpellNameOf(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then return info.name end
    end
    if _G.GetSpellInfo then return (GetSpellInfo(id)) end
end

local function Resolve()
    for slot, list in pairs(ITEMS) do
        for _, itemID in ipairs(list) do
            if missingData[itemID] ~= false then
                local name, spellID = ItemSpell(itemID)
                if name or spellID then
                    local entry = { slot = slot, item = itemID }
                    if name then byName[name] = byName[name] or entry end
                    if spellID then bySpell[spellID] = bySpell[spellID] or entry end
                    missingData[itemID] = false
                else
                    missingData[itemID] = true
                    RequestItem(itemID)
                end
            end
        end
    end
    foodName = foodName or SpellNameOf(WELL_FED)
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local function Count(itemID)
    local get = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
    return (get and get(itemID)) or 0
end

local function ItemIcon(itemID)
    local get = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
    local icon = get and get(itemID)
    if not icon then
        local _, _, _, _, _, i = AIO.ItemInstant(itemID)
        icon = i
    end
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- The item a click on a slot would use: the last one used, if carried, or the first carried.
local function BestItem(self, slot)
    local list = ITEMS[slot]
    if not list then return nil end
    local last = self.db.last and self.db.last[slot]
    if last and Count(last) > 0 then return last end
    for _, id in ipairs(list) do
        if Count(id) > 0 then return id end
    end
end

local function Scan(self)
    local state = {}
    local now = GetTime()
    for i = 1, 40 do
        local name, spellID, expires, icon
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a, blocked = ns.SafeAura("player", i, "HELPFUL")
            if blocked then return nil end      -- not readable now: try later
            if not a then break end
            name, spellID, expires, icon = a.name, a.spellId, a.expirationTime, a.icon
        elseif _G.UnitBuff then
            local n, ic, _, _, _, x, _, _, _, sid = UnitBuff("player", i)
            if not n then break end
            name, spellID, expires, icon = n, sid, x, ic
        else
            break
        end
        local entry = (spellID and bySpell[spellID]) or (name and byName[name])
        local slot = entry and entry.slot
        if not slot and name and foodName and name == foodName then slot = "food" end
        if slot and slot ~= "weapon" then
            local left = (expires and expires > 0) and (expires - now) or nil
            local old = state[slot]
            if not old or (old.left and (not left or left > old.left)) then
                state[slot] = { left = left, icon = icon, item = entry and entry.item }
            end
            if entry and entry.item and self.db.last then self.db.last[slot] = entry.item end
        end
    end
    if _G.GetWeaponEnchantInfo then
        local has, ms = GetWeaponEnchantInfo()
        if has then
            state.weapon = { left = ms and ms / 1000 or nil,
                             icon = _G.GetInventoryItemTexture and GetInventoryItemTexture("player", 16) }
        end
    end
    if state.flask then
        state.battle = state.battle or { left = state.flask.left, icon = state.flask.icon, flask = true }
        state.guardian = state.guardian or { left = state.flask.left, icon = state.flask.icon, flask = true }
    end
    -- Absolute end times, so the countdown can run without scanning again.
    for _, st in pairs(state) do
        if st.left then st.expires = now + st.left end
    end
    return state
end

--- Between scans only the remaining times move on.
local function Countdown(state)
    local now = GetTime()
    for _, st in pairs(state) do
        if st.expires then st.left = math.max(0, st.expires - now) end
    end
end

local function FormatTime(s)
    if s >= 3600 then return ("%dh"):format(math.floor(s / 3600 + 0.5)) end
    if s >= 60 then return ("%dm"):format(math.floor(s / 60 + 0.5)) end
    return ("%ds"):format(math.floor(s))
end

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

local anchor, mover, driver
local buttons = {}

local function ClickRegistration()
    local getBool = (C_CVar and C_CVar.GetCVarBool) or _G.GetCVarBool
    local down = false
    if getBool then
        local ok, v = pcall(getBool, "ActionButtonUseKeyDown")
        down = ok and v and true or false
    end
    return down and "AnyDown" or "AnyUp"
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(self.slot.label, 1, 1, 1)
    local st = self.state
    if st and st.flask then
        GameTooltip:AddLine(L["Covered by your flask"], C.good[1], C.good[2], C.good[3])
    elseif st and st.left then
        GameTooltip:AddLine(L["%s left"]:format(FormatTime(st.left)), C.good[1], C.good[2], C.good[3])
    elseif not st then
        GameTooltip:AddLine(L["Missing"], C.bad[1], C.bad[2], C.bad[3])
    end
    if self.slot.key ~= "food" then
        if self.item then
            local name = AIO.ItemInfo(self.item) or ("item:" .. self.item)
            GameTooltip:AddLine(L["Click: use %s"]:format(name), C.muted[1], C.muted[2], C.muted[3], true)
        else
            GameTooltip:AddLine(L["None in your bags"], C.muted[1], C.muted[2], C.muted[3])
        end
    end
    GameTooltip:Show()
end

local function SavePosition()
    local point, _, rel, x, y = anchor:GetPoint(1)
    if point then M.db.point = { point, "UIParent", rel, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) } end
end

function M:Place()
    if not anchor or InCombatLockdown() then self.needPlace = true; return end
    self.needPlace = nil
    local p = self.db.point or defaults.point
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
end

local Paint   -- defined further down, used by the driver

local function Build()
    if anchor then return end
    anchor = CreateFrame("Frame", "AllInOneConsumables", UIParent)
    anchor:SetSize(SIZE, SIZE)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:SetFrameStrata("MEDIUM")

    for i, slot in ipairs(SLOTS) do
        local b = CreateFrame("Button", "AllInOneConsumable" .. i, anchor, "SecureActionButtonTemplate")
        b.slot = slot
        Style.Flat(b, C.panel, C.line)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.time = Style.Text(b, 10, C.text)
        b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
        b.time:SetJustifyH("CENTER")
        b:RegisterForClicks(ClickRegistration())
        b:SetScript("OnEnter", ShowTooltip)
        b:SetScript("OnLeave", function() GameTooltip_Hide() end)
        Style.AltDrag(b, anchor, SavePosition)
        b:Hide()
        buttons[i] = b
    end

    mover = CreateFrame("Frame", nil, anchor)
    mover:SetPoint("TOPLEFT")
    mover:SetPoint("BOTTOMRIGHT")
    mover:SetFrameLevel((anchor:GetFrameLevel() or 0) + 20)
    Style.Flat(mover, { C.panel[1], C.panel[2], C.panel[3], 0.85 }, C.accent)
    mover.text = Style.Text(mover, 10, C.accent)
    mover.text:SetPoint("CENTER")
    mover.text:SetText(L["Consumables"])
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then anchor:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        SavePosition()
    end)
    mover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Drag to move"], 1, 1, 1)
        GameTooltip:Show()
    end)
    mover:SetScript("OnLeave", function() GameTooltip_Hide() end)
    mover:Hide()

    driver = CreateFrame("Frame")
    driver.elapsed = 0
    -- Once a second: count down from the last scan. A full scan only on
    -- events (auras, bags, weapon) and as a safety net every 30 seconds.
    driver:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + (dt or 0)
        if self.elapsed < 1 then return end
        self.elapsed = 0
        if not M.state or GetTime() >= (M.nextScan or 0) then
            M:Update()
        elseif anchor:IsShown() then
            Countdown(M.state)
            Paint(M, M.state)
        end
    end)
    driver:Hide()
    M:Place()
end

local function Wanted(self)
    if not self.db.instanceOnly then return true end
    local inside, kind = false, nil
    if _G.IsInInstance then inside, kind = IsInInstance() end
    return inside and (kind == "party" or kind == "raid")
end

--- Secure changes: which slots are shown, where, and what a click uses.
local function Layout(self, items)
    anchor:SetScale(self.db.scale or 1)
    anchor:SetAlpha(1)
    local wanted = Wanted(self)
    local unlocked = not self.db.locked
    local reg = ClickRegistration()
    local n = 0
    for _, b in ipairs(buttons) do
        local key = b.slot.key
        if wanted and self.db["slot_" .. key] then
            n = n + 1
            b:ClearAllPoints()
            b:SetSize(SIZE, SIZE)
            b:SetPoint("TOPLEFT", anchor, "TOPLEFT", (n - 1) * (SIZE + GAP), 0)
            b:RegisterForClicks(reg)
            local item = items[key]
            b.item = item
            if item and key == "weapon" then
                b:SetAttribute("type", "macro")
                b:SetAttribute("item", nil)
                b:SetAttribute("macrotext", ("/use item:%d\n/use 16"):format(item))
            elseif item then
                b:SetAttribute("type", "item")
                b:SetAttribute("item", "item:" .. item)
                b:SetAttribute("macrotext", nil)
            else
                b:SetAttribute("type", nil)
                b:SetAttribute("item", nil)
                b:SetAttribute("macrotext", nil)
            end
            b:Show()
        else
            b.item = nil
            b:Hide()
        end
    end
    anchor:SetSize(math.max(1, n) * (SIZE + GAP) - GAP, SIZE)
    mover:SetShown(unlocked)
    anchor:SetShown(n > 0 or unlocked)
    self.layoutKey = nil
end

function Paint(self, state)
    local threshold = (self.db.threshold or 0) * 60
    for _, b in ipairs(buttons) do
        if b:IsShown() then
            local key = b.slot.key
            local st = state[key]
            b.state = st
            local icon = st and st.icon
            if not icon then
                if key == "food" then icon = FOOD_ICON
                else icon = ItemIcon(b.item or ITEMS[key][1]) end
            end
            b.icon:SetTexture(icon)
            if st then
                b.icon:SetDesaturated(false)
                b.icon:SetAlpha(1)
                local warn = st.left and threshold > 0 and st.left <= threshold
                local c = warn and C.warn or (st.flask and C.accent or C.good)
                Style.SetBorder(b, c[1], c[2], c[3], 1)
                b.time:SetText(st.left and FormatTime(st.left) or "")
                b.time:SetTextColor(unpack(warn and C.warn or C.text))
            else
                b.icon:SetDesaturated(true)
                b.icon:SetAlpha(0.4)
                Style.SetBorder(b, C.bad[1], C.bad[2], C.bad[3], 1)
                b.time:SetText("")
            end
        end
    end
end

local function Signature(self, items)
    local parts = { tostring(Wanted(self)), tostring(self.db.locked), tostring(self.db.scale), ClickRegistration() }
    for _, s in ipairs(SLOTS) do
        parts[#parts + 1] = tostring(self.db["slot_" .. s.key]) .. ":" .. tostring(items[s.key])
    end
    return table.concat(parts, ",")
end

function M:Update()
    if not self.enabled or not anchor then return end
    local state = Scan(self)
    if not state then                -- auras hidden right now (Forever)
        self.nextScan = GetTime() + 5
        return
    end
    self.state = state
    self.nextScan = GetTime() + 30
    if not InCombatLockdown() then
        if self.needPlace then self:Place() end
        -- Searching the bags for the best item only after the bags changed.
        local items = self.items
        if not items or self.bagsDirty then
            items = {}
            for _, s in ipairs(SLOTS) do
                if s.key ~= "food" then items[s.key] = BestItem(self, s.key) end
            end
            self.items, self.bagsDirty = items, false
        end
        local sig = Signature(self, items)
        if sig ~= self.lastSig then
            self.lastSig = sig
            Layout(self, items)
        end
    end
    Paint(self, state)
end

local function Request()
    AIO:Later("consumables", function() M:Update() end)
end

function M:OnEnable()
    Build()
    Resolve()
    self:Place()
    self.lastSig = nil
    driver:Show()
    Request()
end

function M:OnDisable()
    if driver then driver:Hide() end
    if not anchor then return end
    if InCombatLockdown() then
        anchor:SetAlpha(0)
        self.hideAfterCombat = true
    else
        anchor:Hide()
    end
end

function M:OnSettingChanged()
    self.lastSig = nil
    self.bagsDirty = true
    Request()
end

local function ItemLoaded(itemID)
    if itemID and missingData[itemID] then
        Resolve()
        Request()
    end
end

M:On("GET_ITEM_INFO_RECEIVED", ItemLoaded)
M:On("ITEM_DATA_LOAD_RESULT", function(itemID, ok) if ok ~= false then ItemLoaded(itemID) end end)
M:On("UNIT_AURA", function(unit) if unit == "player" then Request() end end)
M:On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then Request() end end)
M:On("BAG_UPDATE_DELAYED", function() M.bagsDirty = true; Request() end)
M:On("PLAYER_ENTERING_WORLD", function() Resolve(); Request() end)
M:On("ZONE_CHANGED_NEW_AREA", Request)
M:On("PLAYER_REGEN_ENABLED", Request)
M:On("CVAR_UPDATE", Request)

AIO:On("PLAYER_REGEN_ENABLED", function()
    if M.hideAfterCombat and not M.enabled and anchor then
        anchor:Hide()
        anchor:SetAlpha(1)
    end
    M.hideAfterCombat = nil
end)
