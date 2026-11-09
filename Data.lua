-- AllInOne: what is saved about every character and guild, and the item
-- counts shown in tooltips.
--
-- Kept small on purpose, because SavedVariables live in memory for the whole
-- session:
--
-- AllInOneDB.realms[realm][name] = {
--     class, faction, money, guild, lastSeen, hasBank,
--     bags = { [bagID] = { size = n, items = { [slot] = item }, counts = { [slot] = n } } },
-- }
-- AllInOneDB.guilds[realm][guild] = {
--     money, lastSeen, numTabs, tabs = { [tab] = { name, icon, viewable, items, counts } },
-- }
--
-- `item` is the item ID as a number for an ordinary item, or the item string
-- after "item:" for one with an enchant or random suffix. `counts` only holds
-- stacks larger than one. Name, icon and quality come from the game's own
-- item cache when they are drawn, not from the saved file.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

local tonumber, type, pairs, next = tonumber, type, pairs, next

-- ---------------------------------------------------------------------------
-- Packing items
-- ---------------------------------------------------------------------------

--- A hyperlink (or item string) to the smallest form that keeps the item.
function AIO.PackItem(link)
    if not link then return nil end
    local core = link:match("item:([%-%d:]+)")
    if not core then return nil end
    local id, rest = core:match("^(%d+)(.*)$")
    if not id then return nil end
    -- Plain when every field after the ID is empty or zero, apart from the
    -- link level (8th) and specialisation (9th), which say nothing about
    -- the item itself.
    local i, plain = 0, true
    for field in rest:gmatch(":([^:]*)") do
        i = i + 1
        if i ~= 8 and i ~= 9 and field ~= "" and field ~= "0" then plain = false break end
    end
    if plain then return tonumber(id) end
    return (core:gsub(":+$", ""))
end

--- A packed item back to something every item API accepts.
function AIO.UnpackItem(v)
    if not v then return nil end
    if type(v) == "number" then return "item:" .. v end
    return "item:" .. v
end

function AIO.PackedID(v)
    if type(v) == "number" then return v end
    return v and tonumber(v:match("^(%d+)"))
end

--- What a saved item looks like now: full link when the game knows it,
--- icon and quality (quality may be nil until the item is loaded).
function AIO:ItemFace(v)
    local item = self.UnpackItem(v)
    local name, link, quality = self.ItemInfo(item)
    local _, _, _, _, _, icon = self.ItemInstant(item)
    if not name then
        self:WantItem(self.PackedID(v))
    end
    return link or item, icon, quality
end

-- Items the game has not loaded yet: ask once, redraw when they arrive.
local wanted = {}
function AIO:WantItem(id)
    if not id or wanted[id] then return end
    wanted[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
end

AIO:On("GET_ITEM_INFO_RECEIVED", function(id)
    if id and wanted[id] then
        wanted[id] = nil
        AIO:Later("itemsArrived", function() AIO:RefreshAll() end)
    end
end)

-- ---------------------------------------------------------------------------
-- Item counts per character, for tooltips
--
-- Built the first time a tooltip asks, then kept up to date bag by bag:
-- saving a bag takes its old contribution out and puts the new one in.
-- index[itemID][who] = { bags = n, bank = n, guild = n }
-- ---------------------------------------------------------------------------

local index

local function Contribute(who, where, data, sign)
    if not index or not data or not data.items then return end
    local counts = data.counts
    for slot, v in pairs(data.items) do
        local id = AIO.PackedID(v)
        if id then
            local n = sign * ((counts and counts[slot]) or 1)
            local item = index[id]
            if not item then item = {}; index[id] = item end
            local row = item[who]
            if not row then row = {}; item[who] = row end
            local value = (row[where] or 0) + n
            if value <= 0 then
                row[where] = nil
                if not next(row) then
                    item[who] = nil
                    if not next(item) then index[id] = nil end
                end
            else
                row[where] = value
            end
        end
    end
end

local function BuildIndex()
    index = {}
    for name, c in pairs(AIO:RealmData()) do
        for bag, data in pairs(c.bags or {}) do
            Contribute(name, AIO:IsBankBag(bag) and "bank" or "bags", data, 1)
        end
    end
    local _, guilds = AIO:GuildData()
    for guild, g in pairs(guilds) do
        for _, t in pairs(g.tabs or {}) do
            Contribute("<" .. guild .. ">", "guild", t, 1)
        end
    end
end

function AIO:ResetCounts() index = nil end

-- ---------------------------------------------------------------------------
-- Characters
-- ---------------------------------------------------------------------------

function AIO:RealmData(realm)
    -- Some events (guild, money) can come before PLAYER_LOGIN has set these.
    self.realm  = self.realm or GetRealmName()
    self.player = self.player or UnitName("player")
    realm = realm or self.realm
    local all = self.db.realms
    local r = all[realm]
    if not r then r = {}; all[realm] = r end
    return r
end

function AIO:CharData(name, realm)
    local r = self:RealmData(realm)
    name = name or self.player
    if name == self.player and (realm == nil or realm == self.realm) and not r[name] then
        r[name] = { bags = {} }
    end
    return r[name]
end

function AIO:UpdateCharacter()
    local c = self:CharData()
    c.bags     = c.bags or {}
    c.class    = select(2, UnitClass("player"))
    c.faction  = UnitFactionGroup("player")
    c.money    = GetMoney()
    c.guild    = GetGuildInfo("player")
    c.lastSeen = time()
end

--- Names on this realm with saved data, the current character first.
function AIO:Characters()
    local list = {}
    for name in pairs(self:RealmData()) do
        if name ~= self.player then list[#list + 1] = name end
    end
    table.sort(list)
    table.insert(list, 1, self.player)
    return list
end

function AIO:ForgetCharacter(name)
    name = name:sub(1, 1):upper() .. name:sub(2):lower()
    local r = self:RealmData()
    if name == self.player or not r[name] then
        self:Print(L["No saved character called %s on this realm."], name)
        return
    end
    r[name] = nil
    index = nil
    self:Print(L["Forgot %s."], name)
    self:RefreshAll()
end

-- ---------------------------------------------------------------------------
-- Bags
-- ---------------------------------------------------------------------------

--- Fills `data` (reused, not replaced) with the bag's packed contents.
local function Fill(data, bag, size)
    local items, counts = data.items, data.counts
    if items then wipe(items) else items = {}; data.items = items end
    if counts then wipe(counts) end
    for slot = 1, size do
        local info = AIO.SlotInfo(bag, slot)
        local v = info and AIO.PackItem(info.hyperlink)
        if v then
            items[slot] = v
            local n = info.stackCount or 1
            if n > 1 then
                if not counts then counts = {}; data.counts = counts end
                counts[slot] = n
            end
        end
    end
    if counts and not next(counts) then data.counts = nil end
    data.size = size
end

function AIO:SaveBag(bag)
    local c = self:CharData()
    local where = self:IsBankBag(bag) and "bank" or "bags"
    local data = c.bags[bag]
    if data then Contribute(self.player, where, data, -1) end
    local size = self.NumSlots(bag)
    if size <= 0 then
        c.bags[bag] = nil
    else
        if not data then data = {}; c.bags[bag] = data end
        Fill(data, bag, size)
        Contribute(self.player, where, data, 1)
    end
    c.lastSeen = time()
end

function AIO:ScanInventory()
    for _, bag in ipairs(self:InventoryBags()) do self:SaveBag(bag) end
    if self.KEYRING then self:SaveBag(self.KEYRING) end
end

function AIO:ScanBank()
    if not self.atBank then return end
    for _, bag in ipairs(self:BankBags()) do self:SaveBag(bag) end
    self:CharData().hasBank = true
end

-- ---------------------------------------------------------------------------
-- Guild
-- ---------------------------------------------------------------------------

function AIO:GuildData(guild, realm)
    realm = realm or self.realm
    local all = self.db.guilds
    local r = all[realm]
    if not r then r = {}; all[realm] = r end
    if guild and not r[guild] and guild == GetGuildInfo("player") then
        r[guild] = { tabs = {} }
    end
    return guild and r[guild], r
end

function AIO:SaveGuild()
    local guild = GetGuildInfo("player")
    if not guild then return end
    local g = self:GuildData(guild)
    local who = "<" .. guild .. ">"
    g.money = GetGuildBankMoney and GetGuildBankMoney() or g.money
    g.lastSeen = time()
    local n = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
    g.numTabs = n
    for tab = 1, n do
        local name, icon, viewable = GetGuildBankTabInfo(tab)
        local t = g.tabs[tab]
        if not t then t = {}; g.tabs[tab] = t end
        t.name, t.icon, t.viewable = name, icon, viewable
        -- Only a tab the server has sent us this visit holds real items;
        -- the others read as empty and must not overwrite what was saved.
        if viewable and self.guildQueried and self.guildQueried[tab] then
            Contribute(who, "guild", t, -1)
            local items, counts = t.items, t.counts
            if items then wipe(items) else items = {}; t.items = items end
            if counts then wipe(counts) else counts = {}; t.counts = counts end
            for slot = 1, self.GUILD_SLOTS do
                local v = AIO.PackItem(GetGuildBankItemLink(tab, slot))
                if v then
                    items[slot] = v
                    local _, count = GetGuildBankItemInfo(tab, slot)
                    if count and count > 1 then counts[slot] = count end
                end
            end
            if not next(counts) then t.counts = nil end
            Contribute(who, "guild", t, 1)
        end
    end
    for tab = n + 1, #g.tabs do
        Contribute(who, "guild", g.tabs[tab], -1)
        g.tabs[tab] = nil
    end
end

function AIO:Guilds()
    local _, r = self:GuildData()
    local list = {}
    for name in pairs(r) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- Old saved data (version 1 kept a full link, icon and quality per slot)
-- ---------------------------------------------------------------------------

local function Migrate(data)
    if not data or not data.items then return end
    local counts
    for slot, e in pairs(data.items) do
        if type(e) == "table" then
            data.items[slot] = AIO.PackItem(e.l)
            if (e.c or 1) > 1 then
                counts = counts or data.counts or {}
                counts[slot] = e.c
            end
        end
    end
    if counts then data.counts = counts end
end

function AIO:MigrateData()
    if (self.db.format or 1) >= 2 then return end
    for _, realm in pairs(self.db.realms) do
        for _, c in pairs(realm) do
            for _, data in pairs(c.bags or {}) do Migrate(data) end
        end
    end
    for _, realm in pairs(self.db.guilds) do
        for _, g in pairs(realm) do
            for _, t in pairs(g.tabs or {}) do Migrate(t) end
        end
    end
    self.db.format = 2
end

-- ---------------------------------------------------------------------------
-- Tooltip lines
-- ---------------------------------------------------------------------------

local WHERE = { "bags", "bank", "guild" }
local WHERE_LABEL = { bags = L["Bags"], bank = L["Bank"], guild = L["Guild Bank"] }

function AIO:CountLines(itemID)
    if not index then BuildIndex() end
    local item = index[itemID]
    if not item then return nil end
    local realm = self:RealmData()
    local names = {}
    for who in pairs(item) do names[#names + 1] = who end
    local me = self.player
    table.sort(names, function(a, b)
        if a == me then return true end
        if b == me then return false end
        return a < b
    end)
    -- One line per place: who, then where (bags, bank, guild bank), then how many.
    local lines, total, places = {}, 0, 0
    for _, who in ipairs(names) do
        local row = item[who]
        local c = realm[who]
        local label = c and self.ClassColored(who, c.class) or ("|cff40ff40" .. who .. "|r")
        for _, where in ipairs(WHERE) do
            local n = row[where]
            if n then
                lines[#lines + 1] = { label .. " |cffaaaaaa- " .. WHERE_LABEL[where] .. "|r", tostring(n) }
                total, places = total + n, places + 1
            end
        end
    end
    if places > 1 then
        lines[#lines + 1] = { L["Total"], tostring(total) }
    end
    return lines
end

-- Tooltips that do not always report their item the usual way: the link is
-- worked out from the call itself.
local LINK_OF = {
    SetTradeSkillItem = function(index, reagent)
        if reagent then return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(index, reagent) end
        return GetTradeSkillItemLink and GetTradeSkillItemLink(index)
    end,
    SetCraftItem = function(index, reagent)
        if reagent then return GetCraftReagentItemLink and GetCraftReagentItemLink(index, reagent) end
        return GetCraftItemLink and GetCraftItemLink(index)
    end,
    SetItemByID = function(id) return id and ("item:" .. id) end,
    SetHyperlink = function(link) return link end,
}
-- Every other item tooltip call; the link comes from the tooltip.
local ITEM_CALLS = { "SetBagItem", "SetInventoryItem", "SetGuildBankItem", "SetMerchantItem",
                     "SetBuybackItem", "SetLootItem", "SetLootRollItem", "SetQuestItem",
                     "SetQuestLogItem", "SetInboxItem", "SetSendMailItem", "SetAuctionItem",
                     "SetAuctionSellItem", "SetTradePlayerItem", "SetTradeTargetItem" }

function AIO:HookTooltips()
    local function add(tooltip, link)
        if not AIO.settings.tooltipCounts or tooltip.aioDone then return end
        if not link and tooltip.GetItem then link = select(2, tooltip:GetItem()) end
        local id = AIO.ItemID(link)
        if not id then return end
        local lines = AIO:CountLines(id)
        if not lines then return end
        tooltip.aioDone = true
        tooltip:AddLine(" ")
        for i = 1, #lines do
            tooltip:AddDoubleLine(lines[i][1], lines[i][2], 1, 1, 1, 1, 1, 1)
        end
        tooltip:Show()
    end
    local function clear(tooltip) tooltip.aioDone = nil end

    local tips = { GameTooltip, ItemRefTooltip }
    for _, tip in ipairs(tips) do
        if tip then tip:HookScript("OnTooltipCleared", clear) end
    end

    -- The game's own item hook, whichever this client has. The tooltip
    -- calls below cover what it misses; `aioDone` keeps it to one block.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
       and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip then add(tooltip) end
        end)
    end
    for _, tip in ipairs(tips) do
        if tip and tip.HasScript and tip:HasScript("OnTooltipSetItem") then
            tip:HookScript("OnTooltipSetItem", function(t) add(t) end)
        end
    end
    for _, tip in ipairs(tips) do
        if tip then
            for method, linkOf in pairs(LINK_OF) do
                if tip[method] then
                    hooksecurefunc(tip, method, function(t, ...)
                        local ok, link = pcall(linkOf, ...)
                        add(t, ok and link or nil)
                    end)
                end
            end
            for _, method in ipairs(ITEM_CALLS) do
                if tip[method] then hooksecurefunc(tip, method, function(t) add(t) end) end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Money overview
-- ---------------------------------------------------------------------------

function AIO:ShowMoneyTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOPRIGHT")
    GameTooltip:AddLine(L["Gold on this realm"])
    local total = 0
    local realm = self:RealmData()
    for _, name in ipairs(self:Characters()) do
        local c = realm[name]
        if c and c.money then
            total = total + c.money
            GameTooltip:AddDoubleLine(self.ClassColored(name, c.class), self.Money(c.money), 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Total"], self.Money(total), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end
