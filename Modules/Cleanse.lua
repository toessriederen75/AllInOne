-- AllInOne: cleansing. A small square per group member that lights up when
-- someone carries a debuff you can remove; a click removes it. The colour
-- tells which mouse button holds the right spell, so the squares work in
-- combat even though the spell on a button can only be chosen out of combat.
--
-- Written for AllInOne; the idea comes from Decursive (no code taken).
--
-- How it is built:
--   * A secure group header hands units to the squares, also in combat.
--   * Your cure spells sit on Left, Right and Ctrl+Left (in the order of the
--     debuff types: magic, curse, poison, disease); middle click targets,
--     Ctrl+middle sets the focus.
--   * Squares are only repainted on UNIT_AURA for their own unit; a timer
--     (4 times a second, only while shown) checks range and counts down.
--   * Warnings: a sound for a new debuff, a note when a cure fails, and
--     members out of line of sight are skipped for a few seconds.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Squares"]                 = "Quadrate"
    L["A small square per member that lights up when someone has a debuff you can remove. Click it to remove the debuff: the colour shows which mouse button holds the right spell."] =
        "Ein kleines Quadrat pro Mitglied, das aufleuchtet, wenn jemand einen Debuff hat, den du entfernen kannst. Ein Klick entfernt ihn: die Farbe zeigt, welche Maustaste den richtigen Zauber trägt."
    L["Your spells"]             = "Deine Zauber"
    L["Your class cannot remove debuffs from others."] = "Deine Klasse kann bei anderen keine Debuffs entfernen."
    L["Left click"]              = "Linksklick"
    L["Right click"]             = "Rechtsklick"
    L["Ctrl + left click"]       = "Strg + Linksklick"
    L["Middle click: target, Ctrl + middle click: focus."] = "Mittelklick: anvisieren, Strg + Mittelklick: Fokus."
    L["Show"]                    = "Anzeigen"
    L["Hide when"]               = "Ausblenden"
    L["Never"]                   = "Nie"
    L["Alone"]                   = "Wenn alleine"
    L["Not in a raid"]           = "Wenn nicht im Raid"
    L["Pets too"]                = "Auch Begleiter"
    L["Lock position"]           = "Position sperren"
    L["Layout"]                  = "Darstellung"
    L["Size"]                    = "Grösse"
    L["Spacing"]                 = "Abstand"
    L["Per row"]                 = "Pro Zeile"
    L["At most"]                 = "Höchstens"
    L["Opacity without debuff"]  = "Deckkraft ohne Debuff"
    L["Class colour border"]     = "Rand in Klassenfarbe"
    L["Time left in the square"] = "Restzeit im Quadrat"
    L["Skip if Abolish is already on the member"] = "Überspringen, wenn \"Aufheben\" schon wirkt"
    L["Warnings"]                = "Warnungen"
    L["Sound for a new debuff"]  = "Ton bei neuem Debuff"
    L["Note when a cure fails"]  = "Hinweis, wenn eine Reinigung fehlschlägt"
    L["Skip after 'not in line of sight' for"] = "Nach \"nicht in Sichtlinie\" überspringen für"
    L["%d s"]                    = "%d s"
    L["Off"]                     = "Aus"
    L["Test"]                    = "Testen"
    L["Shows every square as if it had a debuff, for 10 seconds."] = "Zeigt 10 Sekunden lang jedes Quadrat, als hätte es einen Debuff."
    L["Reset position"]          = "Position zurücksetzen"
    L["Cleanse"]                 = "Reinigen"
    L["Drag to move. Lock in the options."] = "Ziehen zum Verschieben. Sperren in den Optionen."
    L["%s resisted %s."]         = "%s: %s widerstanden."
    L["%s is not in line of sight, skipped for %d s."] = "%s ist nicht in Sichtlinie, %d s übersprungen."
    L["Magic"]                   = "Magie"
    L["Curse"]                   = "Fluch"
    L["Poison"]                  = "Gift"
    L["Disease"]                 = "Krankheit"
    L["Out of range"]            = "Ausser Reichweite"
    L["Skipped (line of sight)"] = "Übersprungen (Sichtlinie)"
    L["Nothing to remove."]      = "Nichts zu entfernen."
    L["Mind controlled"]         = "Gedankenkontrolliert"
    L["Alt + drag: move"]        = "Alt + Ziehen: verschieben"
end

local M = AIO:NewModule("cleanse", {
    title     = L["Squares"],
    pageTitle = L["Cleansing"],
    short     = L["A small square per member that lights up when someone has a debuff you can remove. Click it to remove the debuff: the colour shows which mouse button holds the right spell."],
    desc      = L["A small square per member that lights up when someone has a debuff you can remove. Click it to remove the debuff: the colour shows which mouse button holds the right spell."],
    category  = "cleanse",
    default   = true,
    defaults  = {
        size = 20, spacing = 3, perRow = 10, max = 40,
        hide = "solo", pets = false, locked = true,
        idleAlpha = 0.35, classBorder = true, showTime = true, abolish = true,
        sound = true, failNote = true, losSkip = 5,
    },
})
AIO.Cleanse = M

local _, CLASS = UnitClass("player")

-- ---------------------------------------------------------------------------
-- Spells
-- ---------------------------------------------------------------------------

-- Per class and debuff type the cure spells, best first.
local CURES = {
    PRIEST  = { Magic = { 527 }, Disease = { 552, 528 } },
    PALADIN = { Magic = { 4987 }, Poison = { 4987, 1152 }, Disease = { 4987, 1152 } },
    DRUID   = { Curse = { 2782 }, Poison = { 2893, 8946 } },
    SHAMAN  = { Poison = { 526 }, Disease = { 2870 } },
    MAGE    = { Curse = { 475 } },
}
-- "Abolish" spells keep curing; with one on a member there is nothing to do.
local ABOLISH = { Poison = 2893, Disease = 552 }
local TYPE_ORDER = { "Magic", "Curse", "Poison", "Disease" }
local SLOT_KEYS = { { "type1", "spell1" }, { "type2", "spell2" }, { "ctrl-type1", "ctrl-spell1" } }
local SLOT_LABEL = { L["Left click"], L["Right click"], L["Ctrl + left click"] }
local SLOT_COLOR = { { 0.95, 0.15, 0.15 }, { 0.20, 0.45, 1.00 }, { 1.00, 0.55, 0.10 } }
local TYPE_LABEL = { Magic = L["Magic"], Curse = L["Curse"], Poison = L["Poison"], Disease = L["Disease"] }

local function SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end
local function Known(id) return id and (not IsPlayerSpell or IsPlayerSpell(id)) end

local slots = {}        -- [1..3] = spell name
local typeSlot = {}     -- [debuff type] = slot
local abolishName = {}  -- [debuff type] = name of the abolish buff, when we would use it
local cureNames = {}    -- [spell name] = true, to recognise our own casts

local function ResolveSpells()
    wipe(slots); wipe(typeSlot); wipe(abolishName); wipe(cureNames)
    local cures = CURES[CLASS]
    if not cures then return end
    local slotOf = {}
    for _, kind in ipairs(TYPE_ORDER) do
        for _, id in ipairs(cures[kind] or {}) do
            if Known(id) then
                local name = SpellName(id)
                if name then
                    if not slotOf[name] and #slots < 3 then
                        slots[#slots + 1] = name
                        slotOf[name] = #slots
                    end
                    typeSlot[kind] = slotOf[name]
                    cureNames[name] = true
                    if ABOLISH[kind] == id then abolishName[kind] = name end
                end
                break
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Reading a unit
-- ---------------------------------------------------------------------------

local GetAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

local function AuraAt(unit, i, filter)
    if GetAura then
        local a = GetAura(unit, i, filter)
        if not a then return nil end
        return a.name, a.applications, a.dispelName, a.expirationTime
    end
    local name, _, count, kind, _, expires = (filter == "HARMFUL" and UnitDebuff or UnitBuff)(unit, i)
    return name, count, kind, expires
end

--- Is an abolish of this type already working on the unit?
local function HasAbolish(unit, kind)
    local want = abolishName[kind]
    if not want then return false end
    for i = 1, 40 do
        local name = AuraAt(unit, i, "HELPFUL")
        if not name then return false end
        if name == want then return true end
    end
    return false
end

local blacklist = {}    -- [name] = time until skipped

-- ---------------------------------------------------------------------------
-- The squares
-- ---------------------------------------------------------------------------

local headers, buttons, byUnit = {}, {}, {}
local mapDirty = true
local anchor, driver
local testUntil = 0
local lastSound = 0

local function RebuildMap()
    for _, list in pairs(byUnit) do wipe(list) end
    for _, b in ipairs(buttons) do
        local unit = b:IsVisible() and b:GetAttribute("unit")
        if unit then
            local list = byUnit[unit]
            if not list then list = {}; byUnit[unit] = list end
            list[#list + 1] = b
        end
    end
    mapDirty = false
end

local SpellInRange = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange or function() return nil end

local function InRange(unit)
    if UnitIsUnit(unit, "player") then return true end
    local spell = slots[1]
    if spell then
        local r = SpellInRange(spell, unit)
        if r ~= nil then return r == true or r == 1 end
    end
    if UnitInRange then
        local r, checked = UnitInRange(unit)
        if checked then return r end
    end
    return true
end

local function StyleButton(b)
    local db = M.db
    b:SetSize(db.size, db.size)
    b.text:SetFontObject(Style.Font(math.max(8, math.floor(db.size * 0.5)), "OUTLINE"))
end

--- Paints one square from its unit's debuffs.
function M:Paint(b)
    local unit = b:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    local db = self.db
    local now = GetTime()

    local slot, expires, count, kind, debuff
    if not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
        for i = 1, 40 do
            local name, n, k, e = AuraAt(unit, i, "HARMFUL")
            if not name then break end
            local s = k and typeSlot[k]
            if s and not (db.abolish and HasAbolish(unit, k)) then
                slot, expires, count, kind, debuff = s, e, n, k, name
                break
            end
        end
    end
    if not slot and now < testUntil and slots[1] then
        slot, expires, kind, debuff = 1, testUntil, "Magic", L["Test"]
    end

    local name = UnitName(unit)
    local skipped = name and blacklist[name] and blacklist[name] > now
    local was = b.slot
    b.slot, b.expires, b.kind, b.debuff, b.skipped = slot, (expires and expires > 0) and expires or nil, kind, debuff, skipped
    b.count = (count and count > 1) and count or nil

    -- A newly found debuff: sound, at most once every 2 seconds.
    if slot and not was and db.sound and now - lastSound > 2 and not skipped then
        lastSound = now
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end

    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
        b.fill:SetVertexColor(0.35, 0.35, 0.35, 0.4)
    elseif skipped then
        b.fill:SetVertexColor(0, 0, 0, 0.9)
    elseif slot then
        local c = SLOT_COLOR[slot]
        b.fill:SetVertexColor(c[1], c[2], c[3], 1)
    else
        b.fill:SetVertexColor(0.25, 1.00, 0.10, db.idleAlpha)
    end
    b.charm:SetShown(UnitIsCharmed and UnitIsCharmed(unit) or false)

    if db.classBorder then
        local _, cls = UnitClass(unit)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then Style.SetBorder(b, c.r, c.g, c.b, 1) else Style.SetBorder(b, 0, 0, 0, 1) end
    else
        Style.SetBorder(b, 0, 0, 0, 1)
    end
    self:Tick(b, unit, now)
end

--- Range and time left; run by the timer.
function M:Tick(b, unit, now)
    local alpha = 1
    if b.slot and not InRange(unit) then alpha = 0.4 end
    if b.aioAlpha ~= alpha then b.aioAlpha = alpha; b:SetAlpha(alpha) end
    if b.slot and self.db.showTime and b.expires then
        local left = b.expires - now
        b.text:SetText(left > 0 and left < 100 and math.floor(left + 0.5) or (b.count or ""))
    else
        b.text:SetText(b.slot and b.count or "")
    end
end

local function Tooltip(b)
    local unit = b:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local _, cls = UnitClass(unit)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    GameTooltip:AddLine(UnitName(unit) or unit, c and c.r or 1, c and c.g or 1, c and c.b or 1)
    if b.skipped then
        GameTooltip:AddLine(L["Skipped (line of sight)"], 0.7, 0.7, 0.7)
    elseif b.slot then
        GameTooltip:AddLine(b.debuff .. "  (" .. (TYPE_LABEL[b.kind] or b.kind or "") .. ")", 1, 0.3, 0.3)
        local col = SLOT_COLOR[b.slot]
        GameTooltip:AddLine(SLOT_LABEL[b.slot] .. ": " .. (slots[b.slot] or ""), col[1], col[2], col[3])
        if b.aioAlpha and b.aioAlpha < 1 then GameTooltip:AddLine(L["Out of range"], 0.7, 0.7, 0.7) end
    else
        GameTooltip:AddLine(L["Nothing to remove."], 0.6, 0.9, 0.6)
    end
    GameTooltip:AddLine(L["Alt + drag: move"], 0.6, 0.6, 0.6)
    if UnitIsCharmed and UnitIsCharmed(unit) then GameTooltip:AddLine(L["Mind controlled"], 0.3, 1, 0.3) end
    GameTooltip:Show()
end

--- Puts the cure spells on a square (out of combat only).
local function ApplySpells(b)
    for i, keys in ipairs(SLOT_KEYS) do
        local spell = slots[i]
        b:SetAttribute(keys[1], spell and "spell" or nil)
        b:SetAttribute(keys[2], spell)
    end
    if not slots[1] then b:SetAttribute("type1", "target") end
    b:SetAttribute("type3", "target")
    b:SetAttribute("ctrl-type3", "focus")
end

function M:InitButton(b)
    if not b or b.aio then return end
    b.aio = true
    buttons[#buttons + 1] = b
    b:RegisterForClicks("AnyUp")
    Style.Flat(b, { 0, 0, 0, 0 }, { 0, 0, 0, 1 })
    b.fill = b:CreateTexture(nil, "ARTWORK")
    b.fill:SetTexture(Style.WHITE)
    b.fill:SetPoint("TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    b.charm = b:CreateTexture(nil, "OVERLAY")
    b.charm:SetTexture(Style.WHITE)
    b.charm:SetVertexColor(0.2, 1, 0.2)
    b.charm:SetSize(4, 4)
    b.charm:SetPoint("CENTER")
    b.charm:Hide()
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetPoint("CENTER")
    StyleButton(b)
    b:HookScript("OnAttributeChanged", function(self, key)
        if key == "unit" then
            mapDirty = true
            M:Paint(self)
        end
    end)
    -- Alt + drag on any square moves them all (out of combat).
    Style.AltDrag(b, function() if anchor then anchor.moving = true end return anchor end,
        function() M:StopMoving() end)
    b:HookScript("OnEnter", Tooltip)
    b:HookScript("OnLeave", GameTooltip_Hide)
    if not InCombatLockdown() then ApplySpells(b) else M.spellsDirty = true end
end

-- ---------------------------------------------------------------------------
-- Header, layout, position
-- ---------------------------------------------------------------------------

local function NewHeader(key, name, pets)
    local h = CreateFrame("Frame", name, anchor, pets and "SecureGroupPetHeaderTemplate" or "SecureGroupHeaderTemplate")
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("initialConfigFunction", [[
        local header = self:GetParent()
        local size = header:GetAttribute("aioSize") or 20
        self:SetWidth(size)
        self:SetHeight(size)
        header:CallMethod("AIOInitButton", self:GetName())
    ]])
    h.AIOInitButton = function(_, buttonName) M:InitButton(_G[buttonName]) end
    headers[key] = h
    return h
end

--- Your own group first, then the ones after it, then the ones before.
local function GroupOrder()
    local own = 1
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, group = GetRaidRosterInfo(i)
            if name and UnitIsUnit("raid" .. i, "player") then own = group or 1 break end
        end
    end
    local t = {}
    for g = own, 8 do t[#t + 1] = g end
    for g = 1, own - 1 do t[#t + 1] = g end
    return table.concat(t, ",")
end

local function Configure(h, key)
    local db = M.db
    h:SetAttribute("aioSize", db.size)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", db.hide ~= "party")
    h:SetAttribute("showPlayer", true)
    -- Alone the squares are hidden (unless "never"), but while unlocked or
    -- testing your own square shows, so there is something to see and move.
    h:SetAttribute("showSolo", db.hide == "never" or not db.locked or testUntil > GetTime())
    h:SetAttribute("point", "LEFT")
    h:SetAttribute("xOffset", db.spacing)
    h:SetAttribute("yOffset", 0)
    h:SetAttribute("columnAnchorPoint", "TOP")
    h:SetAttribute("columnSpacing", db.spacing)
    h:SetAttribute("unitsPerColumn", db.perRow)
    h:SetAttribute("maxColumns", math.ceil(db.max / db.perRow))
    if key == "raid" then
        h:SetAttribute("groupBy", "GROUP")
        h:SetAttribute("groupingOrder", GroupOrder())
        h:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
        h:SetAttribute("sortMethod", "INDEX")
    end
    for _, b in ipairs(buttons) do
        if b:GetParent() == h then StyleButton(b) end
    end
end

local function PreSpawn(h, count)
    h:SetAttribute("unitsPerColumn", count)
    h:SetAttribute("maxColumns", 1)
    h:SetAttribute("startingIndex", 1 - count)
    h:Show()
    h:SetAttribute("startingIndex", 1)
end

local function MakeAnchor()
    anchor = CreateFrame("Frame", "AllInOneCleanseAnchor", UIParent)
    anchor:SetSize(20, 20)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor.handle = CreateFrame("Frame", nil, anchor)
    anchor.handle:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    anchor.handle:SetSize(80, 14)
    Style.Flat(anchor.handle, C.panel, C.accent)
    local t = Style.Text(anchor.handle, 10)
    t:SetPoint("CENTER")
    t:SetText(L["Cleanse"])
    anchor.handle:EnableMouse(true)
    anchor.handle:RegisterForDrag("LeftButton")
    anchor.handle:SetScript("OnDragStart", function() if not InCombatLockdown() then anchor:StartMoving() end end)
    anchor.handle:SetScript("OnDragStop", function() M:StopMoving() end)
    anchor.handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Drag to move. Lock in the options."], 1, 1, 1)
        GameTooltip:Show()
    end)
    anchor.handle:SetScript("OnLeave", GameTooltip_Hide)
end

function M:StopMoving()
    if not anchor then return end
    anchor.moving = nil
    anchor:StopMovingOrSizing()
    local p, _, rp, x, y = anchor:GetPoint(1)
    if p then self.db.point = { p, rp, x, y } end
end

function M:Place()
    if not anchor or InCombatLockdown() then self.dirty = true return end
    anchor:ClearAllPoints()
    local p = self.db.point
    if p then anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150) end
    anchor.handle:SetShown(not self.db.locked)
    local pets = headers.pets
    if pets then
        pets:ClearAllPoints()
        local rows = math.ceil(self.db.max / self.db.perRow)
        pets:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(rows * (self.db.size + self.db.spacing) + 6))
        pets:SetShown(self.db.pets)
    end
end

function M:ApplyLayout()
    if not anchor then return end
    if InCombatLockdown() then self.dirty = true return end
    self.dirty = false
    if self.db.pets and not headers.pets then
        local h = NewHeader("pets", "AllInOneCleansePets", true)
        Configure(h, "pets")
        PreSpawn(h, 40)
    end
    for key, h in pairs(headers) do Configure(h, key) end
    self:Place()
    mapDirty = true
end

function M:ApplySpells()
    if InCombatLockdown() then self.spellsDirty = true return end
    self.spellsDirty = false
    for _, b in ipairs(buttons) do ApplySpells(b) end
end

local function ForAllShown(fn)
    if mapDirty then RebuildMap() end
    for unit, list in pairs(byUnit) do
        for i = 1, #list do fn(list[i], unit) end
    end
end
local function PaintOne(b) M:Paint(b) end
local function PaintAll() ForAllShown(PaintOne) end

local function Build()
    MakeAnchor()
    local raid = NewHeader("raid", "AllInOneCleanseHeader", false)
    raid:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    Configure(raid, "raid")
    PreSpawn(raid, 40)
    Configure(raid, "raid")

    driver = CreateFrame("Frame", nil, anchor)
    local elapsed = 0
    local function tick(b, unit) M:Tick(b, unit, GetTime()) end
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.25 then return end
        elapsed = 0
        ForAllShown(tick)
        if testUntil > 0 and GetTime() > testUntil then
            testUntil = 0
            PaintAll()
            M:ApplyLayout()     -- hides your own square again when alone
        end
    end)
end

function M:OnEnable()
    self.disableAfterCombat = nil
    if InCombatLockdown() then self.enableAfterCombat = true return end
    ResolveSpells()
    if not anchor then Build() end
    anchor:Show()
    self:ApplyLayout()
    self:ApplySpells()
    self:UpdateLog()
    AIO:Later("cleanse-all", PaintAll)
end

function M:OnDisable()
    self:UpdateLog()
    if not anchor then return end
    if InCombatLockdown() then self.disableAfterCombat = true return end
    anchor:Hide()
end

function M:OnSettingChanged(key)
    if key == "locked" then self:ApplyLayout() return end
    if key == "failNote" or key == "losSkip" then self:UpdateLog() return end
    if key == "idleAlpha" or key == "classBorder" or key == "showTime" or key == "abolish" or key == "sound" then
        PaintAll()
        return
    end
    self:ApplyLayout()
    AIO:Later("cleanse-all", PaintAll)
end

function M:Test()
    testUntil = GetTime() + 10
    lastSound = GetTime()       -- no sound for the test
    self:ApplyLayout()          -- alone: shows your own square for the test
    AIO:Later("cleanse-all", PaintAll)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

M:On("UNIT_AURA", function(unit)
    if not unit then return end
    if mapDirty then RebuildMap() end
    local list = byUnit[unit]
    if list then for i = 1, #list do M:Paint(list[i]) end end
end)
local function Roster()
    mapDirty = true
    if not InCombatLockdown() and headers.raid then
        local order = GroupOrder()
        if headers.raid:GetAttribute("groupingOrder") ~= order then headers.raid:SetAttribute("groupingOrder", order) end
    end
    AIO:Later("cleanse-all", PaintAll)
end
M:On("GROUP_ROSTER_UPDATE", Roster)
M:On("UNIT_PET", function() mapDirty = true end)
M:On("UNIT_CONNECTION", function() AIO:Later("cleanse-all", PaintAll) end)
M:On("SPELLS_CHANGED", function()
    local before = table.concat(slots, ",")
    ResolveSpells()
    if table.concat(slots, ",") ~= before then M:ApplySpells(); M:UpdateLog(); PaintAll() end
end)
M:On("PLAYER_REGEN_ENABLED", function()
    if M.enableAfterCombat then M.enableAfterCombat = nil; M:OnEnable() end
    if M.dirty then M:ApplyLayout() end
    if M.spellsDirty then M:ApplySpells() end
    Roster()
end)
M:On("PLAYER_REGEN_DISABLED", function()
    if anchor and anchor.moving then M:StopMoving() end
end)
AIO:On("PLAYER_REGEN_ENABLED", function()
    if M.disableAfterCombat then
        M.disableAfterCombat = nil
        if not M.enabled and anchor then anchor:Hide() end
    end
end)

-- Warnings: who did we just try to cure, and did it work?
local lastTarget, lastTime = nil, 0
M:On("UNIT_SPELLCAST_SENT", function(unit, target, _, spellID)
    if unit ~= "player" then return end
    local name = spellID and SpellName(spellID)
    if name and cureNames[name] then lastTarget, lastTime = target, GetTime() end
end)
M:On("UI_ERROR_MESSAGE", function(_, message)
    if not lastTarget or GetTime() - lastTime > 1 then return end
    local los = SPELL_FAILED_LINE_OF_SIGHT
    if message and los and message == los and (M.db.losSkip or 0) > 0 then
        local short = lastTarget:match("^[^-]+") or lastTarget
        blacklist[short] = GetTime() + M.db.losSkip
        if M.db.failNote then M:Print(L["%s is not in line of sight, skipped for %d s."], short, M.db.losSkip) end
        PaintAll()
        C_Timer.After(M.db.losSkip + 0.1, PaintAll)
        lastTarget = nil
    end
end)
-- Resisted cures come from the combat log; it is only listened to while the
-- squares are on, the note is wanted and the class can cure at all.
local logFrame = CreateFrame("Frame")
local playerGUID
logFrame:SetScript("OnEvent", function()
    local _, sub, _, srcGUID, _, _, _, _, destName, _, _, _, _, _, _, extraName = CombatLogGetCurrentEventInfo()
    if sub == "SPELL_DISPEL_FAILED" and srcGUID == playerGUID then
        M:Print(L["%s resisted %s."], destName or "?", extraName or "?")
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or 847, "Master")
    end
end)
function M:UpdateLog()
    local want = self.enabled and self.db.failNote and #slots > 0 and CombatLogGetCurrentEventInfo ~= nil
    playerGUID = UnitGUID("player")
    if want then logFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else logFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local function Seconds(v) return v == 0 and L["Off"] or L["%d s"]:format(v) end
local function Pct(v) return ("%d%%"):format(v * 100 + 0.5) end

M.options = {
    { type = "header", label = L["Your spells"] },
    { type = "custom", build = function(parent, width)
        local lines = {}
        for i = 1, 4 do
            local t = Style.Text(parent, 12)
            t:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
            t:SetWidth(width)
            t:SetJustifyH("LEFT")
            lines[i] = t
        end
        parent.Update = function()
            ResolveSpells()
            if #slots == 0 then
                lines[1]:SetText(L["Your class cannot remove debuffs from others."])
                for i = 2, 4 do lines[i]:SetText("") end
                return
            end
            for i = 1, 3 do
                local c = SLOT_COLOR[i]
                if slots[i] then
                    local kinds = {}
                    for _, k in ipairs(TYPE_ORDER) do if typeSlot[k] == i then kinds[#kinds + 1] = TYPE_LABEL[k] end end
                    lines[i]:SetText(("|cff%02x%02x%02x%s|r: %s  |cff999999(%s)|r"):format(c[1] * 255, c[2] * 255, c[3] * 255,
                        SLOT_LABEL[i], slots[i], table.concat(kinds, ", ")))
                else
                    lines[i]:SetText("")
                end
            end
            lines[4]:SetText("|cff999999" .. L["Middle click: target, Ctrl + middle click: focus."] .. "|r")
        end
        parent:HookScript("OnShow", parent.Update)
        parent.Update()
        return 76
    end },

    { type = "header", label = L["Show"] },
    { type = "select", key = "hide", label = L["Hide when"], half = true,
      values = { { value = "never", label = L["Never"] }, { value = "solo", label = L["Alone"] },
                 { value = "party", label = L["Not in a raid"] } } },
    { type = "toggle", key = "pets",   label = L["Pets too"],      half = true },
    { type = "toggle", key = "locked", label = L["Lock position"], half = true },
    { type = "button", label = L["Test"], desc = L["Shows every square as if it had a debuff, for 10 seconds."],
      func = function(m) m:Test() end },
    { type = "button", label = L["Reset position"], func = function(m) m.db.point = nil; m:Place() end },

    { type = "header", label = L["Layout"] },
    { type = "slider", key = "size",    label = L["Size"],    min = 12, max = 40, step = 1, half = true },
    { type = "slider", key = "spacing", label = L["Spacing"], min = 0,  max = 10, step = 1, half = true },
    { type = "slider", key = "perRow",  label = L["Per row"], min = 1,  max = 40, step = 1, half = true },
    { type = "slider", key = "max",     label = L["At most"], min = 5,  max = 40, step = 1, half = true },
    { type = "slider", key = "idleAlpha", label = L["Opacity without debuff"], min = 0, max = 1, step = 0.05, format = Pct, half = true },
    { type = "toggle", key = "classBorder", label = L["Class colour border"], half = true },
    { type = "toggle", key = "showTime",    label = L["Time left in the square"], half = true },
    { type = "toggle", key = "abolish",     label = L["Skip if Abolish is already on the member"] },

    { type = "header", label = L["Warnings"] },
    { type = "toggle", key = "sound",    label = L["Sound for a new debuff"], half = true },
    { type = "toggle", key = "failNote", label = L["Note when a cure fails"], half = true },
    { type = "slider", key = "losSkip",  label = L["Skip after 'not in line of sight' for"], min = 0, max = 15, step = 1,
      format = Seconds, half = true },
}
