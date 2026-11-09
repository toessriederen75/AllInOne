-- AllInOne: buff reminder. A small row of icons for the player's own buffs that
-- are missing or about to run out; a click casts the spell.
--
-- Buffs are found by name, so any rank (and the group version) counts. The
-- buttons are secure action buttons: they are only created, moved, shown,
-- hidden or changed out of combat. During a fight the row is merely faded.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Buff reminder"] = "Buff-Erinnerung"
    L["Icons for your own buffs that are missing or running out. Click to cast."] = "Symbole für eigene Buffs, die fehlen oder bald auslaufen. Klick zaubert."
    L["Shows a small row of icons for your class buffs that are missing or about to expire. Any rank or the group version of a buff counts. Click an icon to cast the buff. During combat the icons cannot be changed, so they are updated again after the fight."] = "Zeigt eine kleine Symbolleiste für Klassenbuffs, die fehlen oder bald auslaufen. Jeder Rang und die Gruppenversion eines Buffs zählen. Ein Klick auf ein Symbol zaubert den Buff. Im Kampf lassen sich die Symbole nicht ändern, sie werden nach dem Kampf wieder aktualisiert."
    L["Display"] = "Anzeige"
    L["Lock position"] = "Position sperren"
    L["Only out of combat"] = "Nur ausserhalb des Kampfes"
    L["Warn before expiry"] = "Warnen vor Ablauf"
    L["%d min"] = "%d Min."
    L["Off"] = "Aus"
    L["Scale"] = "Skalierung"
    L["Icon size"] = "Symbolgrösse"
    L["Grow direction"] = "Wachstumsrichtung"
    L["Right"] = "Rechts"
    L["Left"] = "Links"
    L["Up"] = "Oben"
    L["Down"] = "Unten"
    L["Reset position"] = "Position zurücksetzen"
    L["Buffs of your class"] = "Buffs deiner Klasse"
    L["Spells you have not learned are skipped."] = "Nicht erlernte Zauber werden übersprungen."
    L["Cast: %s"] = "Zaubern: %s"
    L["Best known"] = "Bester bekannter"
    L["Buffs"] = "Buffs"
    L["Drag to move"] = "Ziehen zum Verschieben"
    L["Missing"] = "Fehlt"
    L["Expires in %s"] = "Läuft ab in %s"
    L["Click to cast %s."] = "Klicken, um %s zu zaubern."
    L["Apply a poison to this weapon."] = "Bringe ein Gift auf diese Waffe auf."
    L["Intellect"] = "Intelligenz"
    L["Armor"] = "Rüstung"
    L["Fortitude"] = "Seelenstärke"
    L["Inner Fire"] = "Inneres Feuer"
    L["Divine Spirit"] = "Göttlicher Willen"
    L["Shadow Protection"] = "Schattenschutz"
    L["Mark of the Wild"] = "Mal der Wildnis"
    L["Thorns"] = "Dornen"
    L["Omen of Clarity"] = "Omen der Klarsicht"
    L["Blessing"] = "Segen"
    L["Aura"] = "Aura"
    L["Righteous Fury"] = "Zorn der Gerechtigkeit"
    L["Aspect"] = "Aspekt"
    L["Trueshot Aura"] = "Aura des Volltreffers"
    L["Shout"] = "Ruf"
    L["Shield"] = "Schild"
    L["Weapon imbue"] = "Waffenverzauberung"
    L["Poison on main hand"] = "Gift auf Waffenhand"
    L["Poison on off hand"] = "Gift auf Schildhand"
end

-- ---------------------------------------------------------------------------
-- What each class should keep up
--
--   spells  any of these buffs (by name) satisfies the entry
--   cast    the spells that may be cast for it, best first; with more than
--           one, the options offer a choice
--   weapon  inventory slot whose temporary enchant is checked instead
--   warn    not clickable (rogue poisons)
--   off     off by default
-- ---------------------------------------------------------------------------

local CLASSES = {
    MAGE = {
        { key = "int",   label = L["Intellect"], spells = { 1459, 23028 }, cast = { 1459 } },
        { key = "armor", label = L["Armor"], spells = { 30482, 6117, 7302, 168 }, cast = { 30482, 6117, 7302, 168 } },
    },
    PRIEST = {
        { key = "fort",   label = L["Fortitude"], spells = { 1243, 21562 }, cast = { 1243 } },
        { key = "fire",   label = L["Inner Fire"], spells = { 588 }, cast = { 588 } },
        { key = "spirit", label = L["Divine Spirit"], spells = { 14752, 27681 }, cast = { 14752 } },
        { key = "shadow", label = L["Shadow Protection"], spells = { 976, 27683 }, cast = { 976 }, off = true },
    },
    DRUID = {
        { key = "motw",   label = L["Mark of the Wild"], spells = { 1126, 21849 }, cast = { 1126 } },
        { key = "thorns", label = L["Thorns"], spells = { 467 }, cast = { 467 }, off = true },
        { key = "omen",   label = L["Omen of Clarity"], spells = { 16864 }, cast = { 16864 } },
    },
    PALADIN = {
        { key = "blessing", label = L["Blessing"],
          spells = { 19740, 19742, 20217, 1038, 19977, 20911, 25782, 25894, 25898, 25895, 25890, 25899 },
          cast = { 20217, 19740, 19742, 1038, 19977, 20911 } },
        { key = "aura", label = L["Aura"],
          spells = { 465, 7294, 19746, 19876, 19888, 19891, 32223, 20218 },
          cast = { 465, 7294, 19746, 19876, 19888, 19891, 32223, 20218 } },
        { key = "fury", label = L["Righteous Fury"], spells = { 25780 }, cast = { 25780 }, off = true },
    },
    HUNTER = {
        { key = "aspect", label = L["Aspect"],
          spells = { 13165, 13163, 5118, 13159, 20043, 34074, 13161 },
          cast = { 13165, 13163, 5118, 13159, 20043, 34074, 13161 } },
        { key = "trueshot", label = L["Trueshot Aura"], spells = { 19506 }, cast = { 19506 } },
    },
    WARRIOR = {
        { key = "shout", label = L["Shout"], spells = { 6673, 469 }, cast = { 6673, 469 } },
    },
    WARLOCK = {
        { key = "armor", label = L["Armor"], spells = { 28176, 706, 687 }, cast = { 28176, 706, 687 } },
    },
    SHAMAN = {
        { key = "shield", label = L["Shield"], spells = { 24398, 324 }, cast = { 24398, 324 } },
        { key = "imbue",  label = L["Weapon imbue"], weapon = 16, cast = { 8232, 8024, 8033, 8017 } },
    },
    ROGUE = {
        { key = "mh", label = L["Poison on main hand"], weapon = 16, warn = true },
        { key = "oh", label = L["Poison on off hand"],  weapon = 17, warn = true },
    },
}

local defaults = {
    locked = true, combat = true, threshold = 3, scale = 1, size = 32, grow = "RIGHT",
    point = { "TOP", "UIParent", "TOP", -120, -140 },
}
for class, list in pairs(CLASSES) do
    for _, e in ipairs(list) do
        e.id = class .. "_" .. e.key
        defaults["on_" .. e.id] = not e.off
        if e.cast and #e.cast > 1 then defaults["cast_" .. e.id] = 0 end
    end
end

-- ---------------------------------------------------------------------------
-- Spells
-- ---------------------------------------------------------------------------

local nameCache, iconCache = {}, {}

local function SpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spell)
        if ok and type(info) == "table" then return info.name, info.iconID end
    end
    if _G.GetSpellInfo then
        local ok, name, _, icon = pcall(_G.GetSpellInfo, spell)
        if ok then return name, icon end
    end
end

local function SpellName(id)
    local n = nameCache[id]
    if n == nil then
        local name, icon = SpellInfo(id)
        if name then nameCache[id], iconCache[id] = name, icon end
        n = name
    end
    return n
end

local function SpellIcon(id)
    SpellName(id)
    return iconCache[id] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- Rank independent: a lookup by name only answers for spells in the spell book.
local function Known(id)
    if _G.IsPlayerSpell and IsPlayerSpell(id) then return true end
    if _G.IsSpellKnown and IsSpellKnown(id) then return true end
    local name = SpellName(id)
    return name ~= nil and SpellInfo(name) ~= nil
end

--- The spell to cast for an entry, or nil when none is known.
local function CastSpell(M, e)
    if not e.cast then return nil end
    local pick = M.db["cast_" .. e.id]
    if pick and pick ~= 0 and Known(pick) then return pick end
    for _, id in ipairs(e.cast) do
        if Known(id) then return id end
    end
end

-- ---------------------------------------------------------------------------
-- Player buffs by name
-- ---------------------------------------------------------------------------

local function ScanAuras()
    local list = {}
    for i = 1, 40 do
        local name, duration, expires
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a, blocked = ns.SafeAura("player", i, "HELPFUL")
            if blocked then return nil end      -- not readable now: try later
            if not a then break end
            name, duration, expires = a.name, a.duration, a.expirationTime
        elseif _G.UnitBuff then
            local n, _, _, _, d, x = UnitBuff("player", i)
            if not n then break end
            name, duration, expires = n, d, x
        else
            break
        end
        if name then
            local left = (expires and expires > 0) and (expires - GetTime()) or nil
            local old = list[name]
            if not old or (old.left and (not left or left > old.left)) then
                list[name] = { left = left, duration = duration }
            end
        end
    end
    return list
end

local function WeaponEnchant(slot)
    if not _G.GetWeaponEnchantInfo then return false end
    local hasMH, mhMs, _, _, hasOH, ohMs = GetWeaponEnchantInfo()
    if slot == 16 then return hasMH and true or false, mhMs and mhMs / 1000 end
    return hasOH and true or false, ohMs and ohMs / 1000
end

local function HoldsWeapon(slot)
    local id = _G.GetInventoryItemID and GetInventoryItemID("player", slot)
    if not id then return false end
    local _, classID = AIO.ItemInstant(id)
    return classID == 2   -- weapons, not shields or off-hand items
end

local function FormatTime(s)
    if s >= 3600 then return ("%dh"):format(math.floor(s / 3600 + 0.5)) end
    if s >= 60 then return ("%dm"):format(math.floor(s / 60 + 0.5)) end
    return ("%ds"):format(math.floor(s))
end

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

local function Minutes(v) return v == 0 and L["Off"] or L["%d min"]:format(v) end
local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end

local M
local options = {
    { type = "header", label = L["Display"] },
    { type = "toggle", key = "locked", label = L["Lock position"], half = true },
    { type = "toggle", key = "combat", label = L["Only out of combat"], half = true },
    { type = "slider", key = "threshold", label = L["Warn before expiry"], min = 0, max = 10, step = 1, format = Minutes, half = true },
    { type = "slider", key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05, format = Percent, half = true },
    { type = "slider", key = "size", label = L["Icon size"], min = 20, max = 48, step = 2, half = true },
    { type = "select", key = "grow", label = L["Grow direction"], half = true, width = 160, values = {
        { value = "RIGHT", label = L["Right"] }, { value = "LEFT", label = L["Left"] },
        { value = "UP", label = L["Up"] }, { value = "DOWN", label = L["Down"] } } },
    { type = "button", label = L["Reset position"], func = function(m)
        m.db.point = nil
        AIO.CopyDefaults(m.db, defaults)
        m:Place()
    end },
}

M = AIO:NewModule("buffs", {
    title    = L["Buff reminder"],
    short    = L["Icons for your own buffs that are missing or running out. Click to cast."],
    desc     = L["Shows a small row of icons for your class buffs that are missing or about to expire. Any rank or the group version of a buff counts. Click an icon to cast the buff. During combat the icons cannot be changed, so they are updated again after the fight."],
    category = "buffs",
    default  = true,
    defaults = defaults,
    options  = options,
})

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

local classOptionsDone = false
local function AddClassOptions()
    if classOptionsDone then return end
    local class = PlayerClass()
    local list = class and CLASSES[class]
    if not class then return end
    classOptionsDone = true
    if not list then return end
    options[#options + 1] = { type = "header", label = L["Buffs of your class"] }
    options[#options + 1] = { type = "text", label = L["Spells you have not learned are skipped."] }
    for _, e in ipairs(list) do
        options[#options + 1] = { type = "toggle", key = "on_" .. e.id, label = e.label, half = e.cast and #e.cast > 1 }
        if e.cast and #e.cast > 1 then
            options[#options + 1] = {
                type = "select", key = "cast_" .. e.id, half = true, width = 180,
                label = L["Cast: %s"]:format(e.label),
                disabled = function(m) return not m.db["on_" .. e.id] end,
                values = function()
                    local v = { { value = 0, label = L["Best known"] } }
                    for _, id in ipairs(e.cast) do
                        local name = SpellName(id)
                        if name then v[#v + 1] = { value = id, label = name } end
                    end
                    return v
                end,
            }
        end
    end
end
AddClassOptions()

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

local anchor, mover, driver
local buttons = {}
local GAP = 3

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
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(e.label, 1, 1, 1)
    if self.left then
        GameTooltip:AddLine(L["Expires in %s"]:format(FormatTime(self.left)), C.warn[1], C.warn[2], C.warn[3])
    else
        GameTooltip:AddLine(L["Missing"], C.bad[1], C.bad[2], C.bad[3])
    end
    if e.warn then
        GameTooltip:AddLine(L["Apply a poison to this weapon."], C.muted[1], C.muted[2], C.muted[3], true)
    elseif self.spell then
        GameTooltip:AddLine(L["Click to cast %s."]:format(SpellName(self.spell) or "?"), C.muted[1], C.muted[2], C.muted[3], true)
    end
    GameTooltip:Show()
end

local SavePosition    -- defined with the anchor below

local function Button(i)
    if buttons[i] then return buttons[i] end
    local b = CreateFrame("Button", "AllInOneBuffButton" .. i, anchor, "SecureActionButtonTemplate")
    Style.Flat(b, C.panel, C.bad)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.time = Style.Text(b, 11, C.warn)
    b.time:SetPoint("BOTTOM", 0, 2)
    b.time:SetJustifyH("CENTER")
    b:RegisterForClicks(ClickRegistration())
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip_Hide() end)
    Style.AltDrag(b, anchor, function() SavePosition() end)
    b:Hide()
    buttons[i] = b
    return b
end

function M:Place()
    if not anchor or InCombatLockdown() then self.needPlace = true; return end
    self.needPlace = nil
    local p = self.db.point or defaults.point
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
end

function SavePosition()
    local point, _, rel, x, y = anchor:GetPoint(1)
    if point then M.db.point = { point, "UIParent", rel, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) } end
end

local function Build()
    if anchor then return end
    anchor = CreateFrame("Frame", "AllInOneBuffReminder", UIParent)
    anchor:SetSize(32, 32)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:SetFrameStrata("MEDIUM")

    -- Shown while unlocked: a flat handle above the first icon to drag the row.
    mover = CreateFrame("Frame", nil, anchor)
    mover:SetAllPoints()
    mover:SetFrameLevel((anchor:GetFrameLevel() or 0) + 20)
    Style.Flat(mover, { C.panel[1], C.panel[2], C.panel[3], 0.85 }, C.accent)
    mover.text = Style.Text(mover, 10, C.accent)
    mover.text:SetPoint("CENTER")
    mover.text:SetText(L["Buffs"])
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

    -- Not secure: counts the time down and re-checks once a second.
    driver = CreateFrame("Frame")
    driver.elapsed = 0
    driver:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + (dt or 0)
        if self.elapsed < 1 then return end
        self.elapsed = 0
        if GetTime() >= (M.nextCheck or 0) then M:Update() end
    end)
    driver:Hide()
    M:Place()
end

-- ---------------------------------------------------------------------------
-- What is missing
-- ---------------------------------------------------------------------------

local function Collect(self)
    local class = PlayerClass()
    local list = class and CLASSES[class]
    local out = {}
    if not list then return out end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return out end
    if UnitOnTaxi and UnitOnTaxi("player") then return out end
    local auras = ScanAuras()
    if not auras then return self.lastList or out end   -- auras hidden right now
    local threshold = (self.db.threshold or 0) * 60
    -- Seconds until the next buff reaches the warning time: the driver
    -- sleeps until then instead of scanning every second.
    local soonest = 30
    local function due(left)
        if left and left > threshold then soonest = math.min(soonest, left - threshold) end
    end
    for _, e in ipairs(list) do
        if self.db["on_" .. e.id] then
            if e.weapon then
                local spell = not e.warn and CastSpell(self, e) or nil
                local relevant
                if e.warn then
                    relevant = HoldsWeapon(e.weapon) and (UnitLevel("player") or 0) >= 20
                else
                    relevant = spell ~= nil and HoldsWeapon(e.weapon)
                end
                if relevant then
                    local has, left = WeaponEnchant(e.weapon)
                    due(left)
                    if not has then
                        out[#out + 1] = { entry = e, spell = spell }
                    elseif left and left > 0 and threshold > 0 and left <= threshold then
                        out[#out + 1] = { entry = e, spell = spell, left = left }
                    end
                end
            else
                local spell = CastSpell(self, e)
                if spell then
                    local best
                    for _, id in ipairs(e.spells) do
                        local name = SpellName(id)
                        local a = name and auras[name]
                        if a then
                            if not a.left then best = false break end   -- no expiry: fine
                            if best == nil or a.left > best then best = a.left end
                        end
                    end
                    due(best)
                    if best == nil then
                        out[#out + 1] = { entry = e, spell = spell }
                    elseif best and threshold > 0 and best <= threshold then
                        out[#out + 1] = { entry = e, spell = spell, left = best }
                    end
                end
            end
        end
    end
    self.soonest = soonest
    return out
end

local function Offset(i, step, grow)
    local d = (i - 1) * step
    if grow == "LEFT" then return "TOPRIGHT", -d, 0 end
    if grow == "UP" then return "BOTTOMLEFT", 0, d end
    if grow == "DOWN" then return "TOPLEFT", 0, -d end
    return "TOPLEFT", d, 0
end

--- Changes the secure buttons; only out of combat.
local function Layout(self, list)
    local size = self.db.size or 32
    anchor:SetScale(self.db.scale or 1)
    anchor:SetSize(size, size)
    local step = size + GAP
    local reg = ClickRegistration()
    for i, item in ipairs(list) do
        local b = Button(i)
        b.entry, b.spell = item.entry, item.spell
        b:SetSize(size, size)
        b:ClearAllPoints()
        local point, x, y = Offset(i, step, self.db.grow)
        b:SetPoint(point, anchor, point, x, y)
        b:RegisterForClicks(reg)
        if item.spell and not item.entry.warn then
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", SpellName(item.spell))
        else
            b:SetAttribute("type", nil)
            b:SetAttribute("spell", nil)
        end
        b:Show()
    end
    for i = #list + 1, #buttons do
        local b = buttons[i]
        b:Hide()
        b.entry, b.spell = nil, nil
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
    end
    self.shownCount = #list
    local unlocked = not self.db.locked
    mover:SetShown(unlocked)
    anchor:SetShown(#list > 0 or unlocked)
end

--- Not protected: icons, timers and borders on the buttons already shown.
local function Paint(list)
    for i, item in ipairs(list) do
        local b = buttons[i]
        if b and b:IsShown() and b.entry == item.entry then
            b.left = item.left
            local e = item.entry
            local icon
            if e.warn or (e.weapon and not item.spell) then
                icon = _G.GetInventoryItemTexture and GetInventoryItemTexture("player", e.weapon)
            end
            b.icon:SetTexture(icon or (item.spell and SpellIcon(item.spell)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            if item.left then
                b.time:SetText(FormatTime(item.left))
                Style.SetBorder(b, C.warn[1], C.warn[2], C.warn[3], 1)
            else
                b.time:SetText("")
                Style.SetBorder(b, C.bad[1], C.bad[2], C.bad[3], 1)
            end
        end
    end
end

local function SameEntries(list)
    if (M.shownCount or 0) ~= #list then return false end
    for i, item in ipairs(list) do
        local b = buttons[i]
        if not b or b.entry ~= item.entry or b.spell ~= item.spell then return false end
    end
    return true
end

function M:Update()
    if not self.enabled or not anchor then return end
    local combat = InCombatLockdown()
    if combat and self.db.combat then
        anchor:SetAlpha(0)
        self.dirty = true
        return
    end
    local list = Collect(self)
    self.lastList = list
    -- A countdown on screen needs a fresh look every second; otherwise wake
    -- up when the next buff reaches the warning time (events cover the rest).
    local countdown = false
    for _, item in ipairs(list) do if item.left then countdown = true break end end
    self.nextCheck = GetTime() + (countdown and 1 or math.max(1, self.soonest or 30))
    if combat then
        -- Only what may change in combat: fade buttons whose buff came back.
        anchor:SetAlpha(1)
        if not SameEntries(list) then self.dirty = true end
        local byEntry = {}
        for _, item in ipairs(list) do byEntry[item.entry] = item end
        for i = 1, (self.shownCount or 0) do
            local b = buttons[i]
            local item = b and byEntry[b.entry]
            if b then b:SetAlpha(item and 1 or 0.25) end
        end
        Paint(list)
        return
    end
    self.dirty = false
    if self.needPlace then self:Place() end
    anchor:SetAlpha(1)
    for _, b in ipairs(buttons) do b:SetAlpha(1) end
    Layout(self, list)
    Paint(list)
end

local function Request()
    AIO:Later("buffs", function() M:Update() end)
end
M.Request = Request

function M:OnEnable()
    AddClassOptions()
    Build()
    self:Place()
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
    Request()
end

M:On("UNIT_AURA", function(unit) if unit == "player" then Request() end end)
M:On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then Request() end end)
M:On("PLAYER_EQUIPMENT_CHANGED", Request)
M:On("SPELLS_CHANGED", Request)
M:On("LEARNED_SPELL_IN_TAB", Request)
M:On("PLAYER_ENTERING_WORLD", Request)
M:On("PLAYER_ALIVE", Request)
M:On("PLAYER_UNGHOST", Request)
M:On("PLAYER_CONTROL_GAINED", Request)
M:On("CVAR_UPDATE", Request)

-- Just before combat lockdown starts the row may still be hidden.
M:On("PLAYER_REGEN_DISABLED", function()
    if anchor and M.db.combat and not InCombatLockdown() then
        anchor:Hide()
        M.dirty = true
    end
end)
M:On("PLAYER_REGEN_ENABLED", function() M:Update() end)

AIO:On("PLAYER_REGEN_ENABLED", function()
    if M.hideAfterCombat and not M.enabled and anchor then
        anchor:Hide()
        anchor:SetAlpha(1)
    end
    M.hideAfterCombat = nil
end)
