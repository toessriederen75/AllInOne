-- AllInOne: sorting the bags and the bank.
--
-- One move at a time: merge partial stacks first, then put every item in its
-- place, waiting after each move until the game has unlocked the slots. Bags
-- that only take one kind of item (quiver, soul bag, herb bag, ...) are
-- sorted on their own, and nothing is moved between them and normal bags.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style

if GetLocale() == "deDE" then
    L["Click slots in your bags (and the open bank) to keep them out of sorting. Click again to free them."] =
        "Klicke Plätze in deinen Taschen (und der offenen Bank) an, um sie vom Sortieren auszunehmen. Nochmal klicken gibt sie frei."
    L["Done"]      = "Fertig"
    L["Free all"]  = "Alle freigeben"
    L["Locked for sorting"] = "Vom Sortieren ausgenommen"
end

local Sorter = CreateFrame("Frame")
Sorter:Hide()

-- Order of item classes; anything not listed goes after these.
local CLASS_ORDER = {
    [0]  = 1,   -- consumable
    [2]  = 2,   -- weapon
    [4]  = 3,   -- armor
    [11] = 4,   -- quiver / ammo pouch
    [6]  = 5,   -- projectile
    [1]  = 6,   -- container
    [3]  = 7,   -- gem
    [7]  = 8,   -- trade goods
    [5]  = 9,   -- reagent
    [9]  = 10,  -- recipe
    [12] = 11,  -- quest
    [13] = 12,  -- key
    [15] = 13,  -- miscellaneous
}
local FIRST = { [6948] = true }   -- Hearthstone always first

local function Describe(bag, slot)
    local info = AIO.SlotInfo(bag, slot)
    if not info or not info.hyperlink then return nil end
    local link = info.hyperlink
    local id, class, subClass = AIO.ItemInstant(link)
    local name, _, _, level, _, _, _, maxStack = AIO.ItemInfo(link)
    return {
        link = link, id = id or info.itemID, count = info.stackCount or 1,
        quality = info.quality or 1, locked = info.isLocked,
        class = class or 99, sub = subClass or 0,
        level = level or 0, name = name or AIO.LinkName(link) or "",
        max = maxStack or 1,
    }
end

local questFirst     -- read from the settings when a sort starts

local function Before(a, b)
    if questFirst then
        local qa, qb = a.class == 12, b.class == 12
        if qa ~= qb then return qa end
    end
    local fa, fb = FIRST[a.id] and 0 or 1, FIRST[b.id] and 0 or 1
    if fa ~= fb then return fa < fb end
    local ca, cb = CLASS_ORDER[a.class] or 50, CLASS_ORDER[b.class] or 50
    if ca ~= cb then return ca < cb end
    if a.sub ~= b.sub then return a.sub < b.sub end
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.level ~= b.level then return a.level > b.level end
    if a.name ~= b.name then return a.name < b.name end
    if a.id ~= b.id then return (a.id or 0) < (b.id or 0) end
    if a.link ~= b.link then return a.link < b.link end
    return a.count > b.count
end

local function Same(a, b)
    return a and b and a.link == b.link and a.count == b.count
end

--- The groups of slots that are sorted separately.
local function Groups(bags)
    local normal, groups = {}, {}
    local locked = AIO:SortLocks()
    for _, bag in ipairs(bags) do
        local n = AIO.NumSlots(bag)
        if n > 0 then
            local target = normal
            if AIO.BagFamily(bag) ~= 0 then
                target = {}
                groups[#groups + 1] = target
            end
            for slot = 1, n do
                if not locked[bag .. ":" .. slot] then target[#target + 1] = { bag = bag, slot = slot } end
            end
        end
    end
    table.insert(groups, 1, normal)
    return groups
end

--- The next move for one group, or nil when it is in order.
--- Returns from, to (slot tables), or "wait" when something is locked.
local function NextMove(group)
    local items = {}
    for i, pos in ipairs(group) do
        local item = Describe(pos.bag, pos.slot)
        if item and item.locked then return "wait" end
        items[i] = item
    end

    -- Merge: two partial stacks of the same item become one.
    local partial = {}
    for i = 1, #group do
        local it = items[i]
        if it and it.max > 1 and it.count < it.max then
            local first = partial[it.link]
            if first then return group[i], group[first] end
            partial[it.link] = i
        end
    end

    -- Order. Normally from the first slot on; "from the bottom" puts the
    -- same order into the last slots, so the free space stays at the top.
    local sorted = {}
    for i = 1, #group do
        if items[i] then sorted[#sorted + 1] = items[i] end
    end
    table.sort(sorted, Before)
    local offset = AIO.settings.sortBottom and (#group - #sorted) or 0
    for k = 1, #sorted do
        local p = offset + k
        local want = sorted[k]
        if not Same(items[p], want) then
            -- Prefer an item that is not already in its own right place.
            local fallback
            for q = 1, #group do
                if q ~= p and Same(items[q], want) then
                    local done = q > offset and q < p
                    if not done then
                        local wantedThere = q > offset and sorted[q - offset]
                        if not Same(items[q], wantedThere) then return group[q], group[p] end
                        fallback = fallback or q
                    end
                end
            end
            if fallback then return group[fallback], group[p] end
        end
    end
    return nil
end

local function Stop(reason)
    Sorter:Hide()
    Sorter.groups = nil
    if reason then
        AIO:Print(L["Sorting stopped: %s"], reason)
    else
        AIO:Print(L["Sorted."])
    end
    AIO:RefreshAll()
end

Sorter:SetScript("OnUpdate", function(self, elapsed)
    self.wait = (self.wait or 0) - elapsed
    if self.wait > 0 then return end
    self.wait = 0.08

    if InCombatLockdown() then return Stop(L["in combat"]) end
    if GetTime() - self.started > 90 or self.moves > 600 then return Stop(L["took too long"]) end
    if GetCursorInfo() then
        self.cursorTime = (self.cursorTime or 0) + 0.08
        if self.cursorTime > 2 then ClearCursor(); return Stop(L["item on the cursor"]) end
        return
    end
    self.cursorTime = 0

    for _, group in ipairs(self.groups) do
        local from, to = NextMove(group)
        if from == "wait" then return end
        if from then
            AIO.PickupSlot(from.bag, from.slot)
            AIO.PickupSlot(to.bag, to.slot)
            self.moves = self.moves + 1
            return
        end
    end
    Stop()
end)

function AIO:IsSorting() return Sorter:IsShown() end

function AIO:Sort(kind)
    if Sorter:IsShown() then return end
    local outfits = self.modules.outfits
    if outfits and outfits.Busy and outfits:Busy() then return end
    if InCombatLockdown() then
        self:Print(L["Can't sort in combat."])
        return
    end
    local bags
    if kind == "bank" then
        if not self.atBank then
            self:Print(L["The bank must be open to sort it."])
            return
        end
        bags = self:BankBags()
    else
        bags = self:InventoryBags()
    end
    ClearCursor()
    questFirst = self.settings.questFirst
    Sorter.groups = Groups(bags)
    Sorter.started = GetTime()
    Sorter.moves = 0
    Sorter.wait = 0
    Sorter:Show()
    self:Print(L["Sorting..."])
end


-- ---------------------------------------------------------------------------
-- Single slots kept out of sorting, per character: [ "bag:slot" ] = true.
-- They are marked in a "lock mode" by clicking them in the open windows.
-- ---------------------------------------------------------------------------

function AIO:SortLocks()
    local c = self:CharData()
    c.sortLocked = c.sortLocked or {}
    return c.sortLocked
end

function AIO:IsSortLocked(bag, slot)
    local c = self:CharData()
    return c and c.sortLocked and c.sortLocked[bag .. ":" .. slot] or false
end

function AIO:CountSortLocks()
    local n = 0
    for _ in pairs(self:SortLocks()) do n = n + 1 end
    return n
end

local overlays = {}      -- pool, reused across windows
local banner, backToOptions

local function PaintOverlay(o)
    local b = o.button
    local on = b and AIO:IsSortLocked(b.bag, b.slot)
    o.tint:SetVertexColor(on and 0.9 or 1, on and 0.2 or 1, on and 0.2 or 1, on and 0.35 or 0.06)
    Style.SetBorder(o, on and 1 or 0.9, on and 0.25 or 0.8, on and 0.25 or 0.3, 1)
end

local function OverlayClick(o)
    local b = o.button
    if not b then return end
    local locks = AIO:SortLocks()
    local key = b.bag .. ":" .. b.slot
    locks[key] = (not locks[key]) or nil
    AIO:PaintLive(b)
    PaintOverlay(o)
end

local function OverlayEnter(o)
    GameTooltip:SetOwner(o, "ANCHOR_RIGHT")
    local b = o.button
    if b and AIO:IsSortLocked(b.bag, b.slot) then
        GameTooltip:SetText(L["Locked for sorting"], 1, 0.4, 0.4)
    else
        GameTooltip:SetText(L["Click slots in your bags (and the open bank) to keep them out of sorting. Click again to free them."], 1, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function Overlay(i)
    local o = overlays[i]
    if o then return o end
    o = CreateFrame("Button", nil, UIParent)
    o:SetFrameStrata("DIALOG")
    o.tint = o:CreateTexture(nil, "ARTWORK")
    o.tint:SetTexture(Style.WHITE)
    o.tint:SetAllPoints()
    Style.Flat(o, { 0, 0, 0, 0 }, { 1, 1, 1, 1 })
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o:SetScript("OnClick", OverlayClick)
    o:SetScript("OnEnter", OverlayEnter)
    o:SetScript("OnLeave", GameTooltip_Hide)
    overlays[i] = o
    return o
end

local used = 0
--- Lays a clickable cover over every live slot of the open windows.
function AIO:LockOverlays()
    used = 0
    for _, id in ipairs({ "inventory", "bank" }) do
        local w = self.windows[id]
        if w and w:IsShown() and w.shown then
            for _, b in ipairs(w.shown) do
                if b.isLive and b:IsShown() then
                    used = used + 1
                    local o = Overlay(used)
                    o.button = b
                    o:SetParent(w)
                    o:SetFrameStrata("DIALOG")
                    o:ClearAllPoints()
                    o:SetAllPoints(b)
                    o:SetFrameLevel((w:GetFrameLevel() or 1) + 50)
                    PaintOverlay(o)
                    o:Show()
                end
            end
        end
    end
    for i = used + 1, #overlays do overlays[i]:Hide(); overlays[i].button = nil end
end

--- Switches the lock mode on or off. `fromOptions`: reopen the options after.
function AIO:SlotLockMode(on, fromOptions)
    if on then
        if InCombatLockdown() then self:Print(L["Can't sort in combat."]) return end
        backToOptions = fromOptions
        if fromOptions and _G.AllInOneOptions then AllInOneOptions:Hide() end
        self.lockMode = true
        self:Show("inventory")
        if not banner then
            banner = CreateFrame("Frame", "AllInOneSlotLockBanner", UIParent)
            banner:SetFrameStrata("DIALOG")
            banner:SetSize(620, 36)
            banner:SetPoint("TOP", 0, -120)
            Style.Flat(banner, Style.color.panel, Style.color.accent)
            local t = Style.Text(banner, 12)
            t:SetPoint("LEFT", 12, 0)
            t:SetPoint("RIGHT", -190, 0)
            t:SetJustifyH("LEFT")
            t:SetText(L["Click slots in your bags (and the open bank) to keep them out of sorting. Click again to free them."])
            local done = Style.Button(banner, L["Done"], 76, 24, function() banner:Hide() end)
            done:SetPoint("RIGHT", -8, 0)
            local free = Style.Button(banner, L["Free all"], 96, 24, function()
                wipe(AIO:SortLocks())
                AIO:RefreshAll()
            end)
            free:SetPoint("RIGHT", done, "LEFT", -6, 0)
            banner:SetScript("OnHide", function() AIO:SlotLockMode(false) end)
            tinsert(UISpecialFrames, "AllInOneSlotLockBanner")
        end
        banner:Show()
        self:RefreshAll()
    else
        if not self.lockMode then return end
        self.lockMode = false
        for _, o in ipairs(overlays) do o:Hide(); o.button = nil end
        if banner and banner:IsShown() then banner:Hide() end
        self:RefreshAll()
        if backToOptions then
            backToOptions = nil
            self:OpenOptions("bags")
        end
    end
end

AIO:On("PLAYER_REGEN_DISABLED", function() if AIO.lockMode then AIO:SlotLockMode(false) end end)
