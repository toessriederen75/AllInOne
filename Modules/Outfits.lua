-- AllInOne: outfits. Saved sets of equipment you put on with one click.
--
-- Written for AllInOne; the idea comes from Outfitter.
--
--   Complete    an item (or "empty") for every slot it covers; wearing one
--               replaces everything else you wear as an outfit
--   Mix         partial set worn over the complete one (resistance gear,
--               PvP pieces); a new mix replaces the previous mix
--   Accessory   partial set added on top (fishing pole, riding gloves);
--               any number at once
--
-- Taking off a mix or an accessory puts the complete outfit's items back in
-- those slots. Nothing here runs on a timer: the panel is redrawn when the
-- equipment or the bags change, and only while it is open.
--
-- Saved per character in AllInOneDB.realms[realm][name].outfits:
--   { list = { { name, kind, slots = { [invSlot] = item | false } } },
--     base = name, layers = { name, ... } }
-- `item` is packed like the bag data (see Data.lua); `false` means "empty".

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Save sets of equipment and put them on with one click."] =
        "Speichert Ausrüstungssets und zieht sie mit einem Klick an."
    L["Complete outfits cover every slot you tick, mix outfits go over the complete one, accessories are added on top. Taking one off puts the complete outfit back. Macro commands: /aio wear NAME, /aio unwear NAME, /aio toggle NAME."] =
        "Komplette Outfits belegen jeden angehakten Platz, Zusatz-Outfits kommen darüber, Accessoires werden dazugelegt. Ziehst du eines aus, kommt das komplette Outfit wieder zurück. Makro-Befehle: /aio wear NAME, /aio unwear NAME, /aio toggle NAME."
    L["Complete"]                = "Komplett"
    L["Mix"]                     = "Zusatz"
    L["Accessory"]               = "Accessoire"
    L["Complete outfits"]        = "Komplette Outfits"
    L["Mix outfits"]             = "Zusatz-Outfits"
    L["Accessories"]             = "Accessoires"
    L["New outfit"]              = "Neues Outfit"
    L["Name"]                    = "Name"
    L["Kind"]                    = "Art"
    L["Take what I wear now"]    = "Aktuelle Ausrüstung übernehmen"
    L["Create"]                  = "Erstellen"
    L["Cancel"]                  = "Abbrechen"
    L["Save"]                    = "Speichern"
    L["Rename"]                  = "Umbenennen"
    L["Wear"]                    = "Anziehen"
    L["Take off"]                = "Ausziehen"
    L["Edit slots"]              = "Plätze bearbeiten"
    L["Update from what I wear"] = "Mit aktueller Ausrüstung aktualisieren"
    L["Delete"]                  = "Löschen"
    L["Really delete %s?"]       = "%s wirklich löschen?"
    L["Yes, delete"]             = "Ja, löschen"
    L["Normal"]                  = "Normal"
    L["Naked"]                   = "Nackt"
    L["Editing: %s"]             = "Bearbeiten: %s"
    L["Tick the slots this outfit should cover. Equip the items you want, then Save."] =
        "Hake die Plätze an, die dieses Outfit belegen soll. Zieh die gewünschten Gegenstände an und klicke auf Speichern."
    L["All"]                     = "Alle"
    L["None"]                    = "Keine"
    L["empty"]                   = "leer"
    L["Missing: %d"]             = "Fehlt: %d"
    L["Missing:"]                = "Fehlt:"
    L["Worn"]                    = "Angezogen"
    L["Not in combat. The outfit is put on after the fight."] =
        "Nicht im Kampf. Das Outfit wird nach dem Kampf angezogen."
    L["Wearing %s."]             = "Trage %s."
    L["Took off %s."]            = "%s ausgezogen."
    L["No outfit called %s."]    = "Kein Outfit namens %s."
    L["An outfit called %s exists already."] = "Ein Outfit namens %s gibt es schon."
    L["Your bags are full."]     = "Deine Taschen sind voll."
    L["The outfit could not be put on completely."] = "Das Outfit konnte nicht vollständig angezogen werden."
    L["Button on the character window"] = "Knopf im Charakterfenster"
    L["Open the list with the character window"] = "Liste mit dem Charakterfenster öffnen"
    L["Message in chat when changing"] = "Meldung im Chat beim Wechsel"
    L["Open outfits"]            = "Outfits öffnen"
    L["Left-click: wear / take off. Right-click: menu."] = "Linksklick: anziehen / ausziehen. Rechtsklick: Menü."
    L["Outfits (AllInOne)"]      = "Outfits (AllInOne)"
end

local M = AIO:NewModule("outfits", {
    title     = L["Settings"],
    pageTitle = L["Outfits"],
    short     = L["Save sets of equipment and put them on with one click."],
    desc      = L["Complete outfits cover every slot you tick, mix outfits go over the complete one, accessories are added on top. Taking one off puts the complete outfit back. Macro commands: /aio wear NAME, /aio unwear NAME, /aio toggle NAME."],
    category  = "outfits",
    default   = true,
    defaults  = { button = true, autoOpen = true, chat = true, open = false },
})
M.slash = { wear = true, unwear = true, toggle = true, outfits = true }

M.options = {
    { type = "button", label = L["Open outfits"], func = function(m) m:Open() end },
    { type = "header", label = L["Options"] },
    { type = "toggle", key = "button",   label = L["Button on the character window"] },
    { type = "toggle", key = "autoOpen", label = L["Open the list with the character window"] },
    { type = "toggle", key = "chat",     label = L["Message in chat when changing"] },
}

-- ---------------------------------------------------------------------------
-- Slots and items
-- ---------------------------------------------------------------------------

local SLOT_NAMES = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot",
    [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot",
    [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
    [19] = "TabardSlot",
}
-- Weapons last; the off hand before the main hand when it is emptied, so a
-- two-hander never finds the off hand still in place.
local ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 19, 16, 17 }
local KINDS = { "full", "mix", "acc" }
local KIND_LABEL = { full = L["Complete"], mix = L["Mix"], acc = L["Accessory"] }
local KIND_HEADER = { full = L["Complete outfits"], mix = L["Mix outfits"], acc = L["Accessories"] }

local GetLink = _G.GetInventoryItemLink

local function Equipped(slot)
    return GetLink and AIO.PackItem(GetLink("player", slot)) or nil
end

local function Data()
    local c = AIO:CharData()
    local o = c.outfits
    if not o then
        o = { list = {}, layers = {} }
        c.outfits = o
    end
    o.layers = o.layers or {}
    return o
end

function M:Find(name)
    if not name then return nil end
    local lower = name:lower()
    for _, o in ipairs(Data().list) do
        if o.name:lower() == lower then return o end
    end
end

-- What a bag place holds: the planned state (`sim`) wins over the game's,
-- because the game only reports a move once the server has made it.
local function BagItem(bag, s, sim)
    local key = bag * 100 + s
    local v = sim and sim[key]
    if v ~= nil then return v or nil end
    local info = AIO.SlotInfo(bag, s)
    return info and AIO.PackItem(info.hyperlink)
end

--- Where an item can be found now: in the bags or worn in another slot.
--- `taken` marks bag places and worn slots already promised to other slots.
local function Locate(item, taken, worn, sim)
    local id = AIO.PackedID(item)
    local loose
    for _, bag in ipairs(AIO:InventoryBags()) do
        for s = 1, AIO.NumSlots(bag) do
            local key = bag * 100 + s
            if not taken[key] then
                local v = BagItem(bag, s, sim)
                if v then
                    if v == item then return "bag", bag, s, key end
                    if not loose and AIO.PackedID(v) == id then loose = { bag, s, key } end
                end
            end
        end
    end
    for slot = 1, 19 do
        if not taken["w" .. slot] and worn[slot] == item then return "worn", slot, nil, "w" .. slot end
    end
    if loose then return "bag", loose[1], loose[2], loose[3] end
end

local function FreeBagSlot(taken, sim)
    for _, bag in ipairs(AIO:InventoryBags()) do
        if AIO.BagFamily(bag) == 0 then
            for s = 1, AIO.NumSlots(bag) do
                local key = bag * 100 + s
                if not taken[key] and not BagItem(bag, s, sim) then return bag, s, key end
            end
        end
    end
end

--- Missing items of an outfit (neither worn nor in the bags).
function M:Missing(o)
    local list
    local taken, worn = {}, {}
    for slot = 1, 19 do worn[slot] = Equipped(slot) end
    for _, slot in ipairs(ORDER) do
        local want = o.slots[slot]
        if want then
            if worn[slot] == want then
                taken["w" .. slot] = true
            else
                local kind, a, b, key = Locate(want, taken, worn)
                if kind then
                    taken[key] = true
                else
                    list = list or {}
                    list[#list + 1] = want
                end
            end
        end
    end
    return list
end

--- Is everything of the outfit on right now?
function M:IsWorn(o)
    local any = false
    for slot, want in pairs(o.slots) do
        any = true
        if want == false then
            if Equipped(slot) then return false end
        elseif Equipped(slot) ~= want then
            return false
        end
    end
    return any
end

-- ---------------------------------------------------------------------------
-- Putting things on
-- ---------------------------------------------------------------------------

-- One move at a time. Several pickups in the same moment, or a pickup of an
-- item the server is still moving, can leave items stuck as "locked" until
-- you log out. So the runner waits until nothing is locked and the cursor is
-- empty, makes exactly one move, and looks again on the next step.

local runner = CreateFrame("Frame")
runner:Hide()
local STEP, TIMEOUT = 0.15, 10

local function AnythingLocked()
    for slot = 1, 19 do
        if IsInventoryItemLocked and IsInventoryItemLocked(slot) then return true end
    end
    for _, bag in ipairs(AIO:InventoryBags()) do
        for s = 1, AIO.NumSlots(bag) do
            local info = AIO.SlotInfo(bag, s)
            if info and info.isLocked then return true end
        end
    end
    return false
end

local function HasCursor()
    if CursorHasItem then return CursorHasItem() end
    return GetCursorInfo and GetCursorInfo() ~= nil
end

--- The next single move towards `want`; false when all is done.
--- Returns true after a move (or a deliberate skip of the step).
local MAX_TRIES = 3     -- a slot the server keeps refusing is given up

local function NextMove(want, order, skipped, tries)
    local worn = {}
    for slot = 1, 19 do worn[slot] = Equipped(slot) end
    -- Slots that already hold what they should are not taken apart.
    local taken = {}
    for slot = 1, 19 do
        local w = want[slot]
        if w and worn[slot] == w then taken["w" .. slot] = true end
    end
    for _, slot in ipairs(order) do
        local w = want[slot]
        if not skipped[slot] and (w == false and worn[slot] or w and worn[slot] ~= w) then
            tries[slot] = (tries[slot] or 0) + 1
            if tries[slot] > MAX_TRIES then skipped[slot] = true end
        end
        if not skipped[slot] then
            if w == false and worn[slot] then
                local bag, s = FreeBagSlot(taken)
                if not bag then
                    skipped[slot] = true
                    M:Print(L["Your bags are full."])
                else
                    PickupInventoryItem(slot)
                    if HasCursor() then AIO.PickupSlot(bag, s) end
                    return true
                end
            elseif w and worn[slot] ~= w then
                local kind, a, b = Locate(w, taken, worn)
                if not kind then
                    skipped[slot] = true          -- not in the bags: missing
                elseif kind == "bag" then
                    AIO.PickupSlot(a, b)
                    if HasCursor() then PickupInventoryItem(slot) end
                    return true
                else
                    PickupInventoryItem(a)
                    if HasCursor() then PickupInventoryItem(slot) end
                    return true
                end
            end
        end
    end
    return false
end

local function Finish(reason)
    runner:Hide()
    runner.want = nil
    if HasCursor() then ClearCursor() end
    if reason then M:Print(reason) end
    M:Refresh()
end

runner:SetScript("OnUpdate", function(self, dt)
    self.wait = self.wait - dt
    if self.wait > 0 then return end
    self.wait = STEP
    if InCombatLockdown() then
        M.pending = self.want
        return Finish(L["Not in combat. The outfit is put on after the fight."])
    end
    if GetTime() - self.started > TIMEOUT then
        return Finish(L["The outfit could not be put on completely."])
    end
    -- Something still on the cursor or still moving: wait for the server.
    if HasCursor() then
        self.cursorWait = (self.cursorWait or 0) + STEP
        if self.cursorWait > 1 then ClearCursor(); self.cursorWait = 0 end
        return
    end
    self.cursorWait = 0
    if AnythingLocked() then return end
    if not NextMove(self.want, self.order, self.skipped, self.tries) then
        local missed = next(self.skipped) ~= nil
        Finish(missed and L["The outfit could not be put on completely."] or nil)
    end
end)

--- Equips `want` ([slot] = item | false), one careful move at a time.
function M:Apply(want)
    if InCombatLockdown() then
        self.pending = want
        self:Print(L["Not in combat. The outfit is put on after the fight."])
        return
    end
    -- Never at the same time as the sort button: both move items.
    if AIO.IsSorting and AIO:IsSorting() then
        C_Timer.After(1, function() M:Apply(want) end)
        return
    end
    if HasCursor() then ClearCursor() end
    runner.want = want
    runner.order = (want[17] == false) and { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 19, 17, 16 } or ORDER
    runner.skipped = {}
    runner.tries = {}
    runner.started = GetTime()
    runner.wait = 0
    runner.cursorWait = 0
    runner:Show()
end

--- Is an outfit still being put on?
function M:Busy() return runner:IsShown() end

--- The complete outfit with the worn layers on top.
function M:Compose()
    local d = Data()
    local want = {}
    local base = self:Find(d.base)
    if base then
        for slot, v in pairs(base.slots) do want[slot] = v end
    end
    for _, name in ipairs(d.layers) do
        local o = self:Find(name)
        if o then
            for slot, v in pairs(o.slots) do want[slot] = v end
        end
    end
    return want
end

function M:Wear(o)
    local d = Data()
    if o.kind == "full" then
        d.base = o.name
        wipe(d.layers)
    else
        for i = #d.layers, 1, -1 do
            local other = self:Find(d.layers[i])
            if not other or other.name == o.name or (o.kind == "mix" and other.kind == "mix") then
                table.remove(d.layers, i)
            end
        end
        d.layers[#d.layers + 1] = o.name
    end
    local want = self:Compose()
    -- Make sure the chosen outfit wins even where an older layer was.
    for slot, v in pairs(o.slots) do want[slot] = v end
    self:Apply(want)
    if self.db.chat then self:Print(L["Wearing %s."], o.name) end
    self:Refresh()
end

function M:TakeOff(o)
    local d = Data()
    if d.base == o.name then
        d.base = nil
    end
    for i = #d.layers, 1, -1 do
        if d.layers[i] == o.name then table.remove(d.layers, i) end
    end
    -- Put back what the complete outfit and the other layers hold in the
    -- slots this one covered.
    local want = self:Compose()
    local back = {}
    for slot in pairs(o.slots) do
        if want[slot] ~= nil then back[slot] = want[slot] end
    end
    self:Apply(back)
    if self.db.chat then self:Print(L["Took off %s."], o.name) end
    self:Refresh()
end

function M:Toggle(o)
    if self:IsWorn(o) and o.kind ~= "full" then self:TakeOff(o) else self:Wear(o) end
end

-- ---------------------------------------------------------------------------
-- Creating and changing outfits
-- ---------------------------------------------------------------------------

local function Snapshot(all)
    local slots = {}
    for slot = 1, 19 do
        local v = Equipped(slot)
        if v then slots[slot] = v elseif all then slots[slot] = false end
    end
    return slots
end

function M:Create(name, kind, fromWorn)
    if self:Find(name) then
        self:Print(L["An outfit called %s exists already."], name)
        return
    end
    local o = { name = name, kind = kind, slots = fromWorn and Snapshot(kind == "full") or {} }
    table.insert(Data().list, o)
    self:Refresh()
    return o
end

function M:Delete(o)
    local d = Data()
    for i, x in ipairs(d.list) do
        if x == o then table.remove(d.list, i) break end
    end
    if d.base == o.name then d.base = nil end
    for i = #d.layers, 1, -1 do
        if d.layers[i] == o.name then table.remove(d.layers, i) end
    end
    if self.editing == o then self:StopEdit() end
    self:Refresh()
end

function M:Rename(o, name)
    if self:Find(name) and self:Find(name) ~= o then
        self:Print(L["An outfit called %s exists already."], name)
        return
    end
    local d = Data()
    if d.base == o.name then d.base = name end
    for i, n in ipairs(d.layers) do if n == o.name then d.layers[i] = name end end
    o.name = name
    self:Refresh()
end

--- Takes the items worn now for every slot the outfit covers.
function M:UpdateFromWorn(o)
    for slot in pairs(o.slots) do
        o.slots[slot] = Equipped(slot) or false
    end
    self:Refresh()
end

-- First visit: "Normal" (what you wear) and "Naked".
local function Seed()
    local d = Data()
    if d.seeded then return end
    d.seeded = true
    if #d.list > 0 then return end
    local normal = { name = L["Normal"], kind = "full", slots = Snapshot(true) }
    local naked = { name = L["Naked"], kind = "full", slots = {} }
    for slot = 1, 19 do naked.slots[slot] = false end
    d.list[1], d.list[2] = normal, naked
    d.base = normal.name
end

-- ---------------------------------------------------------------------------
-- Dialog for a new name (and kind)
-- ---------------------------------------------------------------------------

local dialog

local function OpenDialog(title, name, kind, isNew, onOK)
    if not dialog then
        dialog = Style.Window("AllInOneOutfitDialog", 300, 196, "")
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetPoint("CENTER", 0, 120)
        local t = Style.Text(dialog, 12, C.muted)
        t:SetPoint("TOPLEFT", 14, -38)
        t:SetText(L["Name"])
        dialog.edit = Style.Edit(dialog, 272, "")
        dialog.edit:SetPoint("TOPLEFT", 14, -54)
        local k = Style.Text(dialog, 12, C.muted)
        k:SetPoint("TOPLEFT", 14, -84)
        k:SetText(L["Kind"])
        local values = {}
        for _, key in ipairs(KINDS) do values[#values + 1] = { value = key, label = KIND_LABEL[key] } end
        dialog.kind = "full"
        dialog.drop = Style.Dropdown(dialog, 272, values,
            function() return dialog.kind end, function(v) dialog.kind = v end)
        dialog.drop:SetPoint("TOPLEFT", 14, -100)
        dialog.fromWorn = true
        dialog.check = Style.Check(dialog, L["Take what I wear now"],
            function() return dialog.fromWorn end, function(v) dialog.fromWorn = v end)
        dialog.check:SetPoint("TOPLEFT", 14, -130)
        dialog.ok = Style.Button(dialog, L["Create"], 100, 24)
        dialog.ok:SetPoint("BOTTOMRIGHT", -10, 10)
        local cancel = Style.Button(dialog, L["Cancel"], 100, 24, function() dialog:Hide() end)
        cancel:SetPoint("RIGHT", dialog.ok, "LEFT", -6, 0)
        dialog.edit:SetScript("OnEnterPressed", function() dialog.ok:Click() end)
    end
    dialog.titleText:SetText(title)
    dialog.edit:SetText(name or "")
    dialog.kind = kind or "full"
    dialog.drop:Update()
    dialog.drop:SetShown(isNew)
    dialog.check:SetShown(isNew)
    dialog.ok:SetLabel(isNew and L["Create"] or L["Save"])
    dialog.ok:SetScript("OnClick", function()
        local text = (dialog.edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return end
        dialog:Hide()
        onOK(text, dialog.kind, dialog.fromWorn)
    end)
    dialog:Show()
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
end

-- ---------------------------------------------------------------------------
-- Editing slots on the character window
-- ---------------------------------------------------------------------------

local slotChecks = {}

local function SlotCheck(slot)
    local c = slotChecks[slot]
    if c then return c end
    local parent = _G["Character" .. SLOT_NAMES[slot]]
    if not parent then return nil end
    c = CreateFrame("Button", nil, parent)
    c:SetSize(16, 16)
    c:SetPoint("TOPRIGHT", 3, 3)
    c:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
    Style.Flat(c, C.panel2, C.line)
    c.mark = c:CreateTexture(nil, "OVERLAY")
    c.mark:SetTexture(Style.WHITE)
    c.mark:SetPoint("TOPLEFT", 3, -3)
    c.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    c.mark:SetVertexColor(unpack(C.accent))
    c:SetScript("OnClick", function()
        local o = M.editing
        if not o then return end
        M.editSlots[slot] = (not M.editSlots[slot]) or nil
        c.mark:SetShown(M.editSlots[slot] and true or false)
    end)
    slotChecks[slot] = c
    return c
end

function M:StartEdit(o)
    self.editing = o
    self.editSlots = {}
    for slot in pairs(o.slots) do self.editSlots[slot] = true end
    if _G.CharacterFrame and not CharacterFrame:IsShown() and ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
    end
    for slot = 1, 19 do
        local c = SlotCheck(slot)
        if c then
            c.mark:SetShown(self.editSlots[slot] and true or false)
            c:Show()
        end
    end
    self:Refresh()
end

function M:StopEdit(save)
    local o = self.editing
    if save and o then
        local slots = {}
        for slot in pairs(self.editSlots) do
            slots[slot] = Equipped(slot) or false
        end
        o.slots = slots
    end
    self.editing, self.editSlots = nil, nil
    for _, c in pairs(slotChecks) do c:Hide() end
    self:Refresh()
end

-- ---------------------------------------------------------------------------
-- The panel next to the character window
-- ---------------------------------------------------------------------------

local panel
local ROW_H = 22

local function RowMenu(row, o)
    local worn = M:IsWorn(o)
    local items = {
        { text = worn and o.kind ~= "full" and L["Take off"] or L["Wear"], func = function() M:Toggle(o) end },
        { text = L["Edit slots"], func = function() M:StartEdit(o) end },
        { text = L["Update from what I wear"], func = function() M:UpdateFromWorn(o) end },
        { text = L["Rename"], func = function()
            OpenDialog(L["Rename"], o.name, o.kind, false, function(name) M:Rename(o, name) end)
        end },
    }
    for _, key in ipairs(KINDS) do
        items[#items + 1] = { text = L["Kind"] .. ": " .. KIND_LABEL[key], checked = o.kind == key,
                              func = function() o.kind = key; M:Refresh() end }
    end
    items[#items + 1] = { text = "|cffff5050" .. L["Delete"] .. "|r", func = function()
        Style.Menu(row, { { text = L["Really delete %s?"]:format(o.name) },
                          { text = "|cffff5050" .. L["Yes, delete"] .. "|r", func = function() M:Delete(o) end },
                          { text = L["Cancel"] } })
    end }
    Style.Menu(row, items)
end

local function RowTooltip(row)
    local o = row.outfit
    if not o then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(o.name, 1, 1, 1)
    GameTooltip:AddLine(KIND_LABEL[o.kind], C.muted[1], C.muted[2], C.muted[3])
    local missing = M:Missing(o)
    if missing then
        GameTooltip:AddLine(L["Missing:"], C.bad[1], C.bad[2], C.bad[3])
        for _, v in ipairs(missing) do
            local link = AIO:ItemFace(v)
            GameTooltip:AddLine("  " .. (link or tostring(v)))
        end
    end
    GameTooltip:AddLine(L["Left-click: wear / take off. Right-click: menu."], C.muted[1], C.muted[2], C.muted[3], true)
    GameTooltip:Show()
end

local function Row(i)
    local r = panel.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, panel.scroll.child)
    r:SetHeight(ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetTexture(Style.WHITE)
    r.hl:SetAllPoints()
    r.hl:SetVertexColor(unpack(C.hover))
    r.hl:Hide()
    r.box = CreateFrame("Frame", nil, r)
    r.box:SetSize(12, 12)
    r.box:SetPoint("LEFT", 6, 0)
    Style.Flat(r.box, C.panel2, C.line)
    r.mark = r.box:CreateTexture(nil, "OVERLAY")
    r.mark:SetTexture(Style.WHITE)
    r.mark:SetPoint("TOPLEFT", 2, -2)
    r.mark:SetPoint("BOTTOMRIGHT", -2, 2)
    r.text = Style.Text(r, 12)
    r.text:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
    r.text:SetPoint("RIGHT", -40, 0)
    r.text:SetWordWrap(false)
    r.miss = Style.Text(r, 10, C.bad)
    r.miss:SetPoint("RIGHT", -6, 0)
    r.head = Style.Text(r, 11, C.accent)
    r.head:SetPoint("LEFT", 4, -2)
    r:SetScript("OnEnter", function(self) if self.outfit then self.hl:Show(); RowTooltip(self) end end)
    r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip_Hide() end)
    r:SetScript("OnClick", function(self, button)
        if not self.outfit then return end
        if button == "RightButton" then RowMenu(self, self.outfit) else M:Toggle(self.outfit) end
    end)
    panel.rows[i] = r
    return r
end

function M:Refresh()
    if not panel or not panel:IsShown() then return end
    AIO:Later("outfits", function() M:Draw() end)
end

function M:Draw()
    if not panel then return end
    local d = Data()
    local i, y = 0, 0
    for _, kind in ipairs(KINDS) do
        local any = false
        for _, o in ipairs(d.list) do
            if o.kind == kind then
                if not any then
                    any = true
                    i = i + 1
                    local h = Row(i)
                    h.outfit = nil
                    h.box:Hide(); h.text:SetText(""); h.miss:SetText("")
                    h.head:SetText(KIND_HEADER[kind]); h.head:Show()
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", 0, -y)
                    h:SetPoint("RIGHT", panel.scroll.child, "RIGHT")
                    h:Show()
                    y = y + ROW_H
                end
                i = i + 1
                local r = Row(i)
                r.outfit = o
                r.head:Hide()
                r.box:Show()
                local worn = self:IsWorn(o)
                r.mark:SetShown(worn)
                r.text:SetText(o.name)
                r.text:SetTextColor(unpack(worn and C.text or C.muted))
                if self.editing == o then r.text:SetTextColor(unpack(C.accent)) end
                local missing = self:Missing(o)
                r.miss:SetText(missing and L["Missing: %d"]:format(#missing) or "")
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetPoint("RIGHT", panel.scroll.child, "RIGHT")
                r:Show()
                y = y + ROW_H
            end
        end
    end
    for j = i + 1, #panel.rows do panel.rows[j]:Hide() end
    panel.scroll.child:SetHeight(math.max(1, y))
    panel.scroll:UpdateRange()

    local editing = self.editing ~= nil
    panel.editBox:SetShown(editing)
    panel.newButton:SetShown(not editing)
    if editing then panel.editTitle:SetText(L["Editing: %s"]:format(self.editing.name)) end
end

local function BuildPanel()
    local parent = _G.PaperDollFrame or UIParent
    panel = CreateFrame("Frame", "AllInOneOutfits", parent)
    panel:SetSize(230, 420)
    if _G.CharacterFrame then
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -32, -14)
    else
        panel:SetPoint("CENTER")
    end
    panel:EnableMouse(true)
    Style.Chrome(panel)
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT", Style.blizzard and 4 or 1, Style.blizzard and -4 or -1)
    bar:SetPoint("TOPRIGHT", Style.blizzard and -4 or -1, Style.blizzard and -4 or -1)
    bar:SetHeight(Style.blizzard and 24 or 26)
    if not Style.blizzard then Style.Flat(bar, C.panel, { 0, 0, 0, 0 }) end
    local title = Style.Text(bar, 13, Style.blizzard and Style.gold or nil)
    if Style.blizzard then title:SetPoint("CENTER") else title:SetPoint("LEFT", 10, 0) end
    title:SetText(L["Outfits"])
    local function closeIt()
        M.db.open = false
        panel:Hide()
    end
    if Style.blizzard then
        Style.BlizzardClose(panel, closeIt)
    else
        local close = Style.CloseButton(panel, closeIt)
        close:SetPoint("TOPRIGHT", -4, -4)
    end

    panel.rows = {}
    panel.scroll = Style.Scroll(panel)
    panel.scroll:SetPoint("TOPLEFT", Style.blizzard and 10 or 6, Style.blizzard and -38 or -32)
    panel.scroll:SetPoint("BOTTOMRIGHT", -12, 40)

    panel.newButton = Style.Button(panel, L["New outfit"], 214, 24, function()
        OpenDialog(L["New outfit"], "", "full", true, function(name, kind, fromWorn)
            local o = M:Create(name, kind, fromWorn)
            if o and not fromWorn then M:StartEdit(o) end
        end)
    end)
    panel.newButton:SetPoint("BOTTOM", 0, 8)

    -- Edit strip: shown instead of "New outfit" while slots are being ticked.
    local edit = CreateFrame("Frame", nil, panel)
    edit:SetPoint("BOTTOMLEFT", 6, 6)
    edit:SetPoint("BOTTOMRIGHT", -6, 6)
    edit:SetHeight(110)
    Style.Flat(edit, C.panel, C.accent)
    panel.editTitle = Style.Text(edit, 12, C.accent)
    panel.editTitle:SetPoint("TOPLEFT", 8, -8)
    panel.editTitle:SetPoint("RIGHT", -8, 0)
    local hint = Style.Text(edit, 10, C.muted)
    hint:SetPoint("TOPLEFT", 8, -26)
    hint:SetPoint("RIGHT", -8, 0)
    hint:SetText(L["Tick the slots this outfit should cover. Equip the items you want, then Save."])
    local all = Style.Button(edit, L["All"], 60, 20, function()
        for slot = 1, 19 do M.editSlots[slot] = true; if slotChecks[slot] then slotChecks[slot].mark:Show() end end
    end)
    all:SetPoint("BOTTOMLEFT", 8, 34)
    local none = Style.Button(edit, L["None"], 60, 20, function()
        wipe(M.editSlots)
        for _, c in pairs(slotChecks) do c.mark:Hide() end
    end)
    none:SetPoint("LEFT", all, "RIGHT", 4, 0)
    local save = Style.Button(edit, L["Save"], 98, 22, function() M:StopEdit(true) end)
    save:SetPoint("BOTTOMRIGHT", -8, 8)
    local cancel = Style.Button(edit, L["Cancel"], 98, 22, function() M:StopEdit(false) end)
    cancel:SetPoint("RIGHT", save, "LEFT", -4, 0)
    edit:Hide()
    panel.editBox = edit
    edit:HookScript("OnShow", function() panel.scroll:SetPoint("BOTTOMRIGHT", -12, 122) end)
    edit:HookScript("OnHide", function() panel.scroll:SetPoint("BOTTOMRIGHT", -12, 40) end)

    panel:SetScript("OnShow", function() M:Draw() end)
    panel:SetScript("OnHide", function() if M.editing then M:StopEdit(false) end end)
    panel:Hide()
end

local charButton

local function BuildCharButton()
    local parent = _G.PaperDollFrame
    if not parent or charButton then return end
    charButton = Style.Icon(parent, "Interface\\Icons\\INV_Chest_Cloth_17", 24, L["Outfits (AllInOne)"], function()
        M:TogglePanel()
    end)
    charButton:SetPoint("TOPRIGHT", _G.CharacterFrame or parent, "TOPRIGHT", -44, -40)
    charButton:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
end

function M:TogglePanel()
    if not panel then BuildPanel() end
    if panel:IsShown() then
        self.db.open = false
        panel:Hide()
    else
        self.db.open = true
        panel:Show()
    end
end

function M:Open()
    if _G.CharacterFrame and not CharacterFrame:IsShown() and ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
    end
    if not panel then BuildPanel() end
    self.db.open = true
    panel:Show()
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

function M:Slash(rest, cmd)
    if cmd == "outfits" then return self:Open() end
    local o = self:Find(rest)
    if not o then
        self:Print(L["No outfit called %s."], rest or "")
        return
    end
    if cmd == "wear" then self:Wear(o)
    elseif cmd == "unwear" then self:TakeOff(o)
    else self:Toggle(o) end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

M:On("PLAYER_EQUIPMENT_CHANGED", function() M:Refresh() end)
M:On("BAG_UPDATE_DELAYED", function() M:Refresh() end)
M:On("PLAYER_REGEN_ENABLED", function()
    local want = M.pending
    if want then
        M.pending = nil
        M:Apply(want)
    end
end)

local hooked
local function HookCharacterFrame()
    if hooked or not _G.PaperDollFrame then return end
    hooked = true
    PaperDollFrame:HookScript("OnShow", function()
        if not M.enabled then return end
        if charButton then charButton:SetShown(M.db.button) end
        if M.db.autoOpen and M.db.open then
            if not panel then BuildPanel() end
            panel:Show()
        end
    end)
end

function M:OnEnable()
    Seed()
    BuildCharButton()
    HookCharacterFrame()
    if charButton then charButton:SetShown(self.db.button) end
end

function M:OnDisable()
    if self.editing then self:StopEdit(false) end
    if panel then panel:Hide() end
    if charButton then charButton:Hide() end
end

function M:OnSettingChanged(key)
    if key == "button" and charButton then charButton:SetShown(self.db.button) end
end
