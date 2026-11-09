-- AllInOne: helpers at the merchant — selling junk, repairing and buying
-- back what you always want to carry.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    -- shared
    L["Report in chat"]                         = "Im Chat melden"
    L["Add"]                                    = "Hinzufügen"
    L["Count"]                                  = "Anzahl"
    L["Remove"]                                 = "Entfernen"
    L["Item %d"]                                = "Gegenstand %d"
    L["No items yet."]                          = "Noch keine Gegenstände."
    L["Item ID, link or name"]                  = "Gegenstands-ID, Link oder Name"
    L["Type an item ID, shift-click an item while the field has focus, or drag an item onto the field or the list."]
        = "Gib eine Gegenstands-ID ein, klicke bei aktivem Feld mit gedrückter Umschalttaste auf einen Gegenstand oder ziehe einen Gegenstand auf das Feld oder die Liste."
    L["Unknown item: %s"]                       = "Unbekannter Gegenstand: %s"
    L["Shift-click: steps of 10"]               = "Umschalt-Klick: in Zehnerschritten"
    -- junk
    L["Sell junk"]                              = "Schrott verkaufen"
    L["Sells grey items at every merchant."]
        = "Verkauft graue Gegenstände bei jedem Händler."
    L["When you open a merchant, every grey item with a vendor price is sold, a few at a time."]
        = "Beim Öffnen eines Händlers wird jeder graue Gegenstand mit Verkaufswert verkauft, jeweils ein paar aufs Mal."
    L["Report the total earned"]                = "Gesamterlös im Chat melden"
    L["Sold %d items for %s."]                  = "%d Gegenstände für %s verkauft."
    L["Merchant closed: sold %d items for %s."] = "Händler geschlossen: %d Gegenstände für %s verkauft."
    -- repair
    L["Auto repair"]                            = "Automatisch reparieren"
    L["Repairs your gear at every merchant who can."]
        = "Repariert deine Ausrüstung bei jedem Händler, der das kann."
    L["Repairs all your gear when you open a merchant who can repair. Guild funds can be used first, if your rank allows it."]
        = "Repariert deine ganze Ausrüstung, wenn du einen Händler öffnest, der reparieren kann. Auf Wunsch wird zuerst das Gildengeld verwendet, sofern dein Rang es erlaubt."
    L["Use guild funds first"]                  = "Zuerst Gildengeld verwenden"
    L["Report the cost"]                        = "Kosten im Chat melden"
    L["Repaired for %s (guild funds)."]         = "Für %s repariert (Gildengeld)."
    L["Repaired for %s."]                       = "Für %s repariert."
    L["Not enough money to repair (%s)."]       = "Nicht genug Geld für die Reparatur (%s)."
    -- restock
    L["Restock"]                                = "Auffüllen"
    L["Buys reagents, ammunition and anything on your list."]
        = "Kauft Reagenzien, Munition und alles auf deiner Liste nach."
    L["Keep a list of items and how many of each you want to carry. When a merchant sells one of them, the missing amount is bought for you."]
        = "Führe eine Liste mit Gegenständen und wie viele du jeweils dabeihaben möchtest. Verkauft ein Händler einen davon, wird die fehlende Menge für dich gekauft."
    L["Report purchases"]                       = "Einkäufe im Chat melden"
    L["Gold limit per visit (0 = none)"]        = "Goldlimite pro Besuch (0 = keine)"
    L["Shopping list"]                          = "Einkaufsliste"
    L["Add class reagents"]                     = "Klassenreagenzien hinzufügen"
    L["Adds the reagents your class buys from vendors."] = "Fügt die Reagenzien hinzu, die deine Klasse bei Händlern kauft."
    L["Added %d reagents to the list."]         = "%d Reagenzien zur Liste hinzugefügt."
    L["Nothing to add for your class."]         = "Für deine Klasse gibt es nichts hinzuzufügen."
    L["Ammunition"]                             = "Munition"
    L["Keep ammunition"]                        = "Munition vorrätig halten"
    L["Buys the ammunition you have equipped up to the amount below."]
        = "Kauft die angelegte Munition bis zur unten eingestellten Menge nach."
    L["Ammunition to carry"]                    = "Mitzuführende Munition"
    L["Bought %d × %s for %s."]                 = "%d × %s für %s gekauft."
    L["Restock: not enough money for %s."]      = "Auffüllen: nicht genug Geld für %s."
end

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

local atMerchant = false
AIO:On("MERCHANT_SHOW",   function() atMerchant = true end)
AIO:On("MERCHANT_CLOSED", function() atMerchant = false end)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function SellPrice(item)
    local price = select(11, AIO.ItemInfo(item))
    return tonumber(price) or 0
end

local function ItemCount(id)
    if C_Item and C_Item.GetItemCount then
        local n = Call(C_Item.GetItemCount, id, false)
        if n then return n end
    end
    return Call(_G.GetItemCount, id, false) or 0
end

local function ItemIcon(id)
    local icon = select(6, AIO.ItemInstant(id))
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ItemName(id)
    local name, _, quality = AIO.ItemInfo(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then Call(C_Item.RequestLoadItemDataByID, id) end
        return L["Item %d"]:format(id), nil, false
    end
    return name, quality, true
end

local function ColoredName(id)
    local name, quality = ItemName(id)
    local r, g, b = AIO.QualityColor(quality)
    if r then return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, name) end
    return name
end

--- An item ID from typed text: a number, an item link or a (cached) name.
local function ParseItem(text)
    if type(text) == "number" then return text end
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local id = tonumber(text) or AIO.ItemID(text)
    if not id then
        local _, link = AIO.ItemInfo(text)
        id = AIO.ItemID(link)
    end
    if id and id > 0 then return math.floor(id) end
end

local function UseSlot(bag, slot)
    local use = (C_Container and C_Container.UseContainerItem) or _G.UseContainerItem
    if use then pcall(use, bag, slot) end
end

-- ---------------------------------------------------------------------------
-- An editor for a list of items: { [itemID] = true } or { [itemID] = count }
-- ---------------------------------------------------------------------------

local editors = {}
local linkTarget          -- the item field that has focus, for shift-clicks

local function OnInsertLink(link)
    if type(link) ~= "string" or not link:find("item:", 1, true) then return end
    local box = linkTarget
    if box and box:IsVisible() and box:HasFocus() then box:SetText(link) end
end

local linkHooked
local function HookInsertLink()
    if linkHooked then return end
    linkHooked = true
    if _G.ChatEdit_InsertLink then
        pcall(hooksecurefunc, "ChatEdit_InsertLink", OnInsertLink)
    end
    if type(_G.ChatFrameUtil) == "table" and _G.ChatFrameUtil.InsertLink then
        pcall(hooksecurefunc, _G.ChatFrameUtil, "InsertLink", OnInsertLink)
    end
end

AIO:On("GET_ITEM_INFO_RECEIVED", function()
    for editor in pairs(editors) do
        if editor:IsVisible() then
            AIO:Later("aioMerchantLists", function()
                for e in pairs(editors) do if e:IsVisible() then e:Refresh() end end
            end)
            return
        end
    end
end)

--- opts: list = function() return tbl end, counts = bool, defaultCount = n,
---       placeholder, onChange = function()
local function ItemListEditor(parent, width, opts)
    local ROW, VISIBLE = 24, 7
    local f = CreateFrame("Frame", nil, parent)
    editors[f] = true
    HookInsertLink()

    local inputW = math.min(280, width - (opts.counts and 160 or 92))
    local input = Style.Edit(f, inputW, opts.placeholder or L["Item ID, link or name"])
    input:SetPoint("TOPLEFT", 0, 0)
    input:HookScript("OnEditFocusGained", function(self) linkTarget = self end)
    input:HookScript("OnEditFocusLost", function(self) if linkTarget == self then linkTarget = nil end end)
    f.input = input

    local countBox
    if opts.counts then
        countBox = Style.Edit(f, 60, L["Count"])
        countBox:SetNumeric(true)
        countBox:SetPoint("LEFT", input, "RIGHT", 6, 0)
        f.countBox = countBox
    end

    local addButton = Style.Button(f, L["Add"], 80, 22, function() f:AddFromInput() end)
    addButton:SetPoint("LEFT", countBox or input, "RIGHT", 6, 0)
    f.addButton = addButton

    local hint = Style.Text(f, 11, C.muted)
    hint:SetPoint("TOPLEFT", 0, -28)
    hint:SetWidth(width)
    hint:SetWordWrap(true)
    hint:SetText(L["Type an item ID, shift-click an item while the field has focus, or drag an item onto the field or the list."])

    local box = CreateFrame("Frame", nil, f)
    Style.Flat(box, C.panel, C.line)
    box:SetPoint("TOPLEFT", 0, -60)
    box:SetSize(width, ROW * VISIBLE + 8)
    box:EnableMouse(true)
    local scroll = Style.Scroll(box)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -10, 4)
    scroll.child:SetWidth(width - 14)
    f.scroll = scroll

    local empty = Style.Text(box, 12, C.muted)
    empty:SetPoint("CENTER")
    empty:SetText(L["No items yet."])

    function f:AddItem(id, count)
        id = ParseItem(id)
        if not id then return false end
        local list = opts.list()
        if opts.counts then
            count = tonumber(count) or tonumber(countBox and countBox:GetText()) or opts.defaultCount or 20
            list[id] = math.max(1, math.floor(count))
        else
            list[id] = true
        end
        if opts.onChange then opts.onChange() end
        self:Refresh()
        return true
    end

    function f:AddFromInput()
        local text = input:GetText()
        if text == "" then return end
        if self:AddItem(text) then
            input:SetText("")
            if countBox then countBox:SetText("") end
            input:ClearFocus()
        else
            AIO:Print(L["Unknown item: %s"], text)
        end
    end

    local function TakeCursor()
        local kind, id, link = Call(_G.GetCursorInfo)
        if kind ~= "item" then return end
        id = tonumber(id) or AIO.ItemID(link)
        if id then
            Call(_G.ClearCursor)
            f:AddItem(id)
        end
    end
    f.TakeCursor = TakeCursor
    input:SetScript("OnEnterPressed", function() f:AddFromInput() end)
    input:SetScript("OnReceiveDrag", TakeCursor)
    input:HookScript("OnMouseDown", TakeCursor)
    box:SetScript("OnReceiveDrag", TakeCursor)
    box:SetScript("OnMouseUp", TakeCursor)
    if countBox then countBox:SetScript("OnEnterPressed", function() f:AddFromInput() end) end

    f.rows = {}
    local function Row(i)
        local row = f.rows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, scroll.child)
        row:SetHeight(ROW)
        row:EnableMouse(true)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetTexture(Style.WHITE)
        row.hl:SetAllPoints()
        row.hl:SetVertexColor(unpack(C.hover))
        row.hl:Hide()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.remove = Style.CloseButton(row, function()
            opts.list()[row.id] = nil
            if opts.onChange then opts.onChange() end
            f:Refresh()
        end)
        row.remove:SetPoint("RIGHT", -2, 0)
        row.remove.tip = L["Remove"]
        local right = row.remove
        if opts.counts then
            local function step(dir)
                local list = opts.list()
                local n = (list[row.id] or 0) + dir * ((IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1)
                list[row.id] = math.max(1, n)
                if opts.onChange then opts.onChange() end
                row.count:SetText(tostring(list[row.id]))
            end
            row.plus = Style.Button(row, "+", 20, 20, function() step(1) end)
            row.plus:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
            row.plus.tip = L["Shift-click: steps of 10"]
            row.count = Style.Edit(row, 56, "")
            row.count:SetNumeric(true)
            row.count:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)
            row.count:SetJustifyH("CENTER")
            local function commit(self)
                local n = tonumber(self:GetText())
                local list = opts.list()
                if n and n > 0 and row.id and list[row.id] then
                    list[row.id] = math.floor(n)
                    if opts.onChange then opts.onChange() end
                end
                if row.id and list[row.id] then self:SetText(tostring(list[row.id])) end
            end
            row.count:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
            row.count:HookScript("OnEditFocusLost", commit)
            row.minus = Style.Button(row, "-", 20, 20, function() step(-1) end)
            row.minus:SetPoint("RIGHT", row.count, "LEFT", -2, 0)
            row.minus.tip = L["Shift-click: steps of 10"]
            right = row.minus
        end
        row.name = Style.Text(row, 12)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", right, "LEFT", -6, 0)
        row.name:SetWordWrap(false)
        row:SetScript("OnEnter", function(self)
            self.hl:Show()
            if self.id and GameTooltip.SetItemByID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip_Hide() end)
        row:SetScript("OnReceiveDrag", TakeCursor)
        row:SetScript("OnMouseUp", TakeCursor)
        f.rows[i] = row
        return row
    end

    function f:Refresh()
        local list = opts.list()
        local ids = {}
        for id, v in pairs(list) do
            if v then ids[#ids + 1] = id end
        end
        local names = {}
        for _, id in ipairs(ids) do names[id] = (ItemName(id)):lower() end
        table.sort(ids, function(a, b)
            if names[a] ~= names[b] then return names[a] < names[b] end
            return a < b
        end)
        for i, id in ipairs(ids) do
            local row = Row(i)
            row.id = id
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
            row:SetPoint("RIGHT", scroll.child, "RIGHT", 0, 0)
            row.icon:SetTexture(ItemIcon(id))
            row.name:SetText(ColoredName(id))
            if row.count then row.count:SetText(tostring(list[id])) end
            row:Show()
        end
        for i = #ids + 1, #self.rows do self.rows[i]:Hide() end
        empty:SetShown(#ids == 0)
        scroll.child:SetHeight(math.max(1, #ids * ROW))
        scroll:UpdateRange()
        self.count = #ids
    end

    f:SetScript("OnShow", function(self) self:Refresh() end)
    f:Refresh()
    return f, 60 + ROW * VISIBLE + 8
end

-- ---------------------------------------------------------------------------
-- Sell junk
-- ---------------------------------------------------------------------------

local Junk = AIO:NewModule("junk", {
    title    = L["Sell junk"],
    short    = L["Sells grey items at every merchant."],
    desc     = L["When you open a merchant, every grey item with a vendor price is sold, a few at a time."],
    category = "merchant",
    default  = true,
    defaults = { report = true },
})

Junk.options = {
    { type = "toggle", key = "report",  label = L["Report the total earned"] },
}

-- The "always sell" list was taken out; old saved lists are dropped.
function Junk:OnEnable()
    self.db.list, self.db.useList = nil, nil
end

local BATCH, DELAY = 8, 0.25
local run  -- the sale in progress

--- Every slot to sell: grey with a vendor price.
function Junk:Collect()
    local db, items = self.db, {}
    for _, bag in ipairs(AIO:InventoryBags()) do
        for slot = 1, AIO.NumSlots(bag) do
            local info = AIO.SlotInfo(bag, slot)
            if info and info.hyperlink and not info.isLocked and not info.hasNoValue then
                local id = info.itemID or AIO.ItemID(info.hyperlink)
                local quality = info.quality
                if quality == nil or quality < 0 then quality = select(3, AIO.ItemInfo(info.hyperlink)) end
                local price = SellPrice(info.hyperlink)
                if price > 0 and quality == 0 then
                    items[#items + 1] = { bag = bag, slot = slot, id = id,
                                          value = price * (info.stackCount or 1) }
                end
            end
        end
    end
    return items
end

function Junk:Finish(closed)
    local r = run
    run = nil
    if not r or r.sold == 0 or not self.db.report then return end
    if closed then
        self:Print(L["Merchant closed: sold %d items for %s."], r.sold, AIO.Money(r.total))
    else
        self:Print(L["Sold %d items for %s."], r.sold, AIO.Money(r.total))
    end
end

function Junk:Step(r)
    if run ~= r then return end
    if not atMerchant or not self.enabled then return self:Finish(true) end
    local done = 0
    while r.pos <= #r.items and done < BATCH do
        local it = r.items[r.pos]
        r.pos = r.pos + 1
        local info = AIO.SlotInfo(it.bag, it.slot)
        local id = info and (info.itemID or AIO.ItemID(info.hyperlink))
        if id == it.id and not info.isLocked then
            UseSlot(it.bag, it.slot)
            r.sold = r.sold + 1
            r.total = r.total + SellPrice(info.hyperlink) * (info.stackCount or 1)
            done = done + 1
        end
    end
    if r.pos > #r.items then return self:Finish(false) end
    C_Timer.After(DELAY, function() Junk:Step(r) end)
end

function Junk:Start()
    local items = self:Collect()
    if #items == 0 then return end
    run = { items = items, pos = 1, sold = 0, total = 0 }
    self:Step(run)
end

Junk:On("MERCHANT_SHOW", function() Junk:Start() end)
Junk:On("MERCHANT_CLOSED", function() if run then Junk:Finish(true) end end)

function Junk:OnDisable() run = nil end

-- ---------------------------------------------------------------------------
-- Auto repair
-- ---------------------------------------------------------------------------

local Repair = AIO:NewModule("repair", {
    title    = L["Auto repair"],
    short    = L["Repairs your gear at every merchant who can."],
    desc     = L["Repairs all your gear when you open a merchant who can repair. Guild funds can be used first, if your rank allows it."],
    category = "merchant",
    default  = true,
    defaults = { guild = true, report = true },
    options  = {
        { type = "toggle", key = "guild",  label = L["Use guild funds first"] },
        { type = "toggle", key = "report", label = L["Report the cost"] },
    },
})

local function RepairCost()
    local cost, can = Call(_G.GetRepairAllCost)
    return tonumber(cost) or 0, can
end

function Repair:WithOwnMoney(cost)
    if GetMoney() >= cost then
        Call(_G.RepairAllItems)
        if self.db.report then self:Print(L["Repaired for %s."], AIO.Money(cost)) end
    else
        self:Print(L["Not enough money to repair (%s)."], AIO.Money(cost))
    end
end

function Repair:Run()
    if not Call(_G.CanMerchantRepair) then return end
    local cost, can = RepairCost()
    if not can or cost <= 0 then return end
    if self.db.guild and Call(_G.IsInGuild) and Call(_G.CanGuildBankRepair) then
        local limit = tonumber(Call(_G.GetGuildBankWithdrawMoney)) or 0
        if limit == -1 or limit >= cost then
            Call(_G.RepairAllItems, true)
            -- The guild bank itself may be short of money: check, then pay ourselves.
            C_Timer.After(0.5, function()
                if not atMerchant or not Repair.enabled then return end
                local left = RepairCost()
                if left > 0 then
                    Repair:WithOwnMoney(left)
                elseif Repair.db.report then
                    Repair:Print(L["Repaired for %s (guild funds)."], AIO.Money(cost))
                end
            end)
            return
        end
    end
    self:WithOwnMoney(cost)
end

Repair:On("MERCHANT_SHOW", function() Repair:Run() end)

-- Everything happens in event handlers, which stop by themselves when off.
function Repair:OnDisable() end

-- ---------------------------------------------------------------------------
-- Restock
-- ---------------------------------------------------------------------------

local Restock = AIO:NewModule("restock", {
    title    = L["Restock"],
    short    = L["Buys reagents, ammunition and anything on your list."],
    desc     = L["Keep a list of items and how many of each you want to carry. When a merchant sells one of them, the missing amount is bought for you."],
    category = "merchant",
    default  = true,
    defaults = { items = {}, report = true, limit = 0, ammo = false, ammoCount = 1000 },
})

local REAGENTS = {
    MAGE    = { { 17020, 40 }, { 17031, 10 }, { 17032, 5 } },
    PRIEST  = { { 17029, 20 } },
    PALADIN = { { 21177, 100 }, { 17033, 5 } },
    DRUID   = { { 22148, 20 }, { 17026, 10 } },
    SHAMAN  = { { 17030, 5 } },
    ROGUE   = { { 5140, 20 } },
    WARLOCK = { { 5565, 5 }, { 16583, 3 } },
}
Restock.REAGENTS = REAGENTS

function Restock:AddClassReagents()
    local _, class = UnitClass("player")
    local list = REAGENTS[class or ""]
    if not list then self:Print(L["Nothing to add for your class."]) return 0 end
    local added = 0
    for _, r in ipairs(list) do
        if not self.db.items[r[1]] then
            self.db.items[r[1]] = r[2]
            added = added + 1
        end
    end
    self:Print(L["Added %d reagents to the list."], added)
    if self.editor then self.editor:Refresh() end
    return added
end

Restock.options = {
    { type = "toggle", key = "report", label = L["Report purchases"] },
    { type = "input",  key = "limit",  label = L["Gold limit per visit (0 = none)"], numeric = true, width = 100 },
    { type = "header", label = L["Shopping list"] },
    { type = "custom", build = function(parent, width, M)
        local editor, h = ItemListEditor(parent, width, {
            list = function() M.db.items = M.db.items or {}; return M.db.items end,
            counts = true, defaultCount = 20,
        })
        editor:SetPoint("TOPLEFT")
        editor:SetSize(width, h)
        Restock.editor = editor
        return h
    end },
    { type = "button", label = L["Add class reagents"], desc = L["Adds the reagents your class buys from vendors."],
      width = 200, func = function(M) M:AddClassReagents() end },
    { type = "header", label = L["Ammunition"] },
    { type = "toggle", key = "ammo", label = L["Keep ammunition"], desc = L["Buys the ammunition you have equipped up to the amount below."] },
    { type = "slider", key = "ammoCount", label = L["Ammunition to carry"], min = 200, max = 4000, step = 100,
      disabled = function(M) return not M.db.ammo end },
}

--- name, price (for one purchase), quantity per purchase, available (-1 = unlimited), purchasable, extendedCost
local function MerchantInfo(i)
    if _G.GetMerchantItemInfo then
        local name, _, price, quantity, available, purchasable, _, extended = Call(_G.GetMerchantItemInfo, i)
        if name then return name, price, quantity, available, purchasable, extended end
    end
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local t = Call(C_MerchantFrame.GetItemInfo, i)
        if type(t) == "table" then
            return t.name, t.price, t.stackCount, t.numAvailable, t.isPurchasable, t.hasExtendedCost
        end
    end
end

local function MerchantItemID(i)
    local id = Call(_G.GetMerchantItemID, i)
    if id then return id end
    return AIO.ItemID(Call(_G.GetMerchantItemLink, i))
end

--- itemID -> wanted count, from the list and the equipped ammunition.
function Restock:Wanted()
    local wanted = {}
    for id, n in pairs(self.db.items or {}) do
        if type(n) == "number" and n > 0 then wanted[id] = n end
    end
    if self.db.ammo then
        local ammo = Call(_G.GetInventoryItemID, "player", _G.INVSLOT_AMMO or 0)
        if ammo then wanted[ammo] = math.max(wanted[ammo] or 0, self.db.ammoCount or 1000) end
    end
    return wanted
end

--- Works out what to buy. Returns { { index, id, units, cost, name, perCall } }.
function Restock:Plan()
    local wanted = self:Wanted()
    if not next(wanted) then return {} end
    local budget = GetMoney()
    local limit = tonumber(self.db.limit) or 0
    if limit > 0 then budget = math.min(budget, limit * 10000) end

    local plan, seen = {}, {}
    local n = Call(_G.GetMerchantNumItems) or 0
    for i = 1, n do
        local id = MerchantItemID(i)
        if id and wanted[id] and not seen[id] then
            local name, price, quantity, available, purchasable, extended = MerchantInfo(i)
            quantity = math.max(1, tonumber(quantity) or 1)
            price = tonumber(price) or 0
            local need = wanted[id] - ItemCount(id)
            if name and need > 0 and purchasable ~= false and not extended and price >= 0 then
                seen[id] = true
                local purchases = math.ceil(need / quantity)
                local limited = available and available >= 0
                if limited then purchases = math.min(purchases, available) end
                local affordable = price > 0 and math.floor(budget / price) or purchases
                if purchases > affordable then
                    if limited then
                        purchases = 0          -- limited stock we can't pay for: leave it
                    else
                        purchases = affordable
                    end
                    if self.db.report then self:Print(L["Restock: not enough money for %s."], name) end
                end
                if purchases > 0 then
                    local maxStack = tonumber(Call(_G.GetMerchantItemMaxStack, i)) or quantity
                    local perCall = math.max(1, math.floor(math.max(maxStack, quantity) / quantity)) -- purchases per call
                    budget = budget - purchases * price
                    plan[#plan + 1] = { index = i, id = id, name = name, purchases = purchases,
                                        quantity = quantity, perCall = perCall, cost = purchases * price }
                end
            end
        end
    end
    return plan
end

function Restock:Run()
    if (Call(_G.GetMerchantNumItems) or 0) == 0 then
        -- The list may arrive a moment later.
        if not self.retried then
            self.retried = true
            C_Timer.After(0.5, function() if atMerchant and Restock.enabled then Restock:Run() end end)
        end
        return
    end
    for _, p in ipairs(self:Plan()) do
        local left = p.purchases
        while left > 0 do
            local now = math.min(left, p.perCall)
            Call(_G.BuyMerchantItem, p.index, now * p.quantity)
            left = left - now
        end
        if self.db.report then
            self:Print(L["Bought %d × %s for %s."], p.purchases * p.quantity, p.name, AIO.Money(p.cost))
        end
    end
end

Restock:On("MERCHANT_SHOW", function()
    Restock.retried = nil
    Restock:Run()
end)

function Restock:OnDisable() self.retried = nil end
