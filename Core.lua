-- AllInOne: namespace, events, settings, container helpers and the hooks that
-- put our windows where Blizzard's bags, bank and guild bank would open.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local L = ns.L

local AIO = {}
ns.AIO = AIO
_G.AllInOne = AIO

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
AIO.version = (GetMeta and GetMeta(ADDON, "Version")) or "dev"

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

AIO.BACKPACK     = _G.BACKPACK_CONTAINER or 0
AIO.BANK         = _G.BANK_CONTAINER or -1
AIO.KEYRING      = _G.KEYRING_CONTAINER or -2
AIO.NUM_BAGS     = _G.NUM_BAG_SLOTS or 4
AIO.NUM_BANKBAGS = _G.NUM_BANKBAGSLOTS or 7
AIO.GUILD_SLOTS  = _G.MAX_GUILDBANK_SLOTS_PER_TAB or 98
AIO.SIZE         = 37   -- item button size
AIO.GAP          = 4    -- space between buttons (the setting slotGap wins)

local IT = Enum and Enum.PlayerInteractionType
AIO.INTERACT_BANKER      = (IT and IT.Banker) or 8
AIO.INTERACT_GUILDBANKER = (IT and IT.GuildBanker) or 10

function AIO:InventoryBags()
    local list = {}
    for bag = self.BACKPACK, self.NUM_BAGS do list[#list + 1] = bag end
    return list
end

function AIO:BankBags()
    local list = { self.BANK }
    for bag = self.NUM_BAGS + 1, self.NUM_BAGS + self.NUM_BANKBAGS do list[#list + 1] = bag end
    return list
end

function AIO:IsBankBag(bag)
    return bag == self.BANK or (bag > self.NUM_BAGS and bag <= self.NUM_BAGS + self.NUM_BANKBAGS)
end

function AIO:IsInventoryBag(bag)
    return (self.KEYRING ~= nil and bag == self.KEYRING) or (bag >= self.BACKPACK and bag <= self.NUM_BAGS)
end

-- ---------------------------------------------------------------------------
-- Container API, whichever form this client has
-- ---------------------------------------------------------------------------

local CC = C_Container or {}

function AIO.NumSlots(bag)
    local get = CC.GetContainerNumSlots or _G.GetContainerNumSlots
    return (get and get(bag)) or 0
end

--- Always a table (or nil for an empty slot), in C_Container's shape.
function AIO.SlotInfo(bag, slot)
    if CC.GetContainerItemInfo then
        return CC.GetContainerItemInfo(bag, slot)
    end
    if not _G.GetContainerItemInfo then return nil end
    local icon, count, locked, quality, _, _, link, _, _, itemID = _G.GetContainerItemInfo(bag, slot)
    if not icon then return nil end
    return { iconFileID = icon, stackCount = count, isLocked = locked,
             quality = quality, hyperlink = link, itemID = itemID }
end

function AIO.BagFamily(bag)
    if bag == AIO.BACKPACK or bag == AIO.BANK then return 0 end
    local get = CC.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
    if not get then return 0 end
    local _, family = get(bag)
    return family or 0
end

function AIO.FreeSlots(bag)
    local get = CC.GetContainerNumFreeSlots or _G.GetContainerNumFreeSlots
    return (get and get(bag)) or 0
end

function AIO.PickupSlot(bag, slot)
    local pick = CC.PickupContainerItem or _G.PickupContainerItem
    if pick then pick(bag, slot) end
end

function AIO.SlotCooldown(bag, slot)
    local get = CC.GetContainerItemCooldown or _G.GetContainerItemCooldown
    if get then return get(bag, slot) end
end

function AIO.ItemInstant(item)
    local get = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if not get or not item then return nil end
    local ok, itemID, itemType, subType, equipLoc, icon, classID, subClassID = pcall(get, item)
    if not ok then return nil end
    return itemID, classID, subClassID, itemType, subType, icon
end

function AIO.ItemInfo(item)
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not get or not item then return nil end
    return get(item)
end

function AIO.ItemID(link)
    if type(link) == "number" then return link end
    return link and tonumber(link:match("item:(%-?%d+)"))
end

function AIO.LinkName(link)
    return link and link:match("%[(.-)%]")
end

function AIO.QualityColor(quality)
    if not quality then return nil end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    if _G.GetItemQualityColor then
        local r, g, b = _G.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
end

-- ---------------------------------------------------------------------------
-- Text helpers
-- ---------------------------------------------------------------------------

function AIO:Print(text, ...)
    if select("#", ...) > 0 then text = text:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff" .. AIO.title .. "|r: " .. tostring(text))
end

local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

function AIO.Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. GOLD end
    if s > 0 or g > 0 then parts[#parts + 1] = s .. SILVER end
    parts[#parts + 1] = c .. COPPER
    return table.concat(parts, " ")
end

function AIO.ClassColored(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name) end
    return name
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function AIO:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        -- An event this client does not know raises an error on register.
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Work collected during a frame and done once on the next one.
local pending = {}
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(self)
    self:Hide()
    local jobs = pending
    pending = {}
    for key, fn in pairs(jobs) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end)

function AIO:Later(key, fn)
    pending[key] = fn
    ticker:Show()
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

AIO.title = ns.title or "AllInOne"   -- the name shown in the game

AIO.defaults = {
    replaceBags   = true,
    replaceBank   = true,
    replaceGuild  = true,
    tooltipCounts = true,
    qualityBorder = true,
    showKeyring   = true,
    emptySlots    = true,
    slotGap       = 4,
    partialTop    = false,  -- the unfilled row at the top instead of the bottom
    sortBottom    = false,  -- sorting fills the last slots first
    questFirst    = true,   -- quest items before everything else
    itemLevel     = true,
    junkIcon      = true,
    locked        = false,
    frames = {
        inventory = { columns = 10, scale = 1, alpha = 0.92,
                      point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -60, 110 } },
        bank      = { columns = 14, scale = 1, alpha = 0.92, border = { 1, 0.82, 0 },
                      point = { "TOPLEFT", "UIParent", "TOPLEFT", 60, -110 } },
        guild     = { columns = 14, scale = 1, alpha = 0.92, border = { 0.25, 1, 0.25 },
                      point = { "TOPLEFT", "UIParent", "TOPLEFT", 60, -110 } },
    },
}
-- A build can start with other defaults (Forever: own bags off at first).
for k, v in pairs(ns.defaults or {}) do AIO.defaults[k] = v end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
AIO.CopyDefaults = CopyDefaults

function AIO:FrameSettings(id)
    return self.settings.frames[id]
end

-- ---------------------------------------------------------------------------
-- Modules
--
-- Every feature besides the bag windows is a module:
--
--   local M = AIO:NewModule("key", {
--       title = L["..."], desc = L["..."], category = "merchant",
--       default = true,                 -- on for a new install (default true)
--       defaults = { ... },             -- its own settings, in M.db
--       options = { ... },              -- drawn by Options.lua, see there
--       OnEnable = function(M) end,     -- switched on (also at login)
--       OnDisable = function(M) end,    -- switched off; without it a /reload is asked for
--   })
--   M:On("EVENT", function(...) end)   -- only called while the module is on
--   M:Print("text %s", value)
-- ---------------------------------------------------------------------------

-- The options window shows one tab per section; each section groups its
-- categories, and each category its modules.
AIO.sections = {
    { key = "bags",    label = L["Bags & Bank"], icon = "Interface\\Icons\\INV_Misc_Bag_08", noOverview = true,
      intro = L["Settings for the bag, bank and guild bank windows."] },
    { key = "helpers", label = L["Helpers"],     icon = "Interface\\Icons\\Trade_Engineering", grouped = true,
      intro = L["Switch whole modules on and off here. Click a name for its settings."] },
    { key = "spells",  label = L["Spell ranks"], icon = "Interface\\Icons\\INV_Misc_Book_09", noOverview = true,
      intro = L["Finds spells on your action bars that are not at their highest rank."] },
    { key = "gear",    label = L["Outfits"], icon = "Interface\\Icons\\INV_Chest_Cloth_17", noOverview = true,
      intro = "" },
    { key = "cleanse", label = L["Cleansing"], icon = "Interface\\Icons\\Spell_Holy_DispelMagic", noOverview = true,
      intro = "" },
    { key = "maps",    label = L["Maps"], icon = "Interface\\Icons\\INV_Misc_Map_01", noOverview = true,
      intro = "" },
    { key = "castbar", label = L["Cast bar"], icon = "Interface\\Icons\\Spell_Nature_Lightning", noOverview = true,
      intro = "" },
    { key = "gtfo",    label = L["Danger alarm"], icon = "Interface\\Icons\\Spell_Fire_Fire", noOverview = true,
      intro = "" },
}

-- The helpers-only build has no other tabs.
if ns.lite then
    for i = #AIO.sections, 1, -1 do
        if AIO.sections[i].key ~= "helpers" then table.remove(AIO.sections, i) end
    end
end

AIO.categories = {
    { key = "bags",     section = "bags",    label = L["Bags & Bank"], hideHeader = true },
    { key = "merchant", section = "helpers", label = L["Merchants & NPCs"], icon = "Interface\\Icons\\INV_Misc_Coin_01",
      blurb = L["Selling junk, repairing and restocking."] },
    { key = "quests",   section = "helpers", label = L["Quests"], icon = "Interface\\Icons\\INV_Misc_Book_09",
      blurb = L["Accepting and handing in quests on their own, skipping gossip."] },
    { key = "buffs",    section = "helpers", label = L["Buffs & Consumables"], icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
      blurb = L["Reminders for missing buffs and a watch on your consumables."] },
    { key = "display",  section = "helpers", label = L["Display"], icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      blurb = L["Info bar, tooltips, minimap button and experience."] },
    { key = "windows",  section = "helpers", label = L["Blizzard windows"], icon = "Interface\\Icons\\INV_Scroll_03",
      blurb = L["Larger quest log, profession and trainer windows."] },
    { key = "comfort",  section = "helpers", label = L["Comfort"], icon = "Interface\\Icons\\INV_Misc_Gear_01",
      blurb = L["Mail helpers, error filter, looting and small automations."] },
    { key = "chat",     section = "helpers", label = L["Chat"], icon = "Interface\\Icons\\INV_Letter_15",
      blurb = L["Improvements for the chat window."] },
    { key = "spellranks", section = "spells", label = L["Spell ranks"], hideHeader = true },
    { key = "outfits",    section = "gear",   label = L["Outfits"],     hideHeader = true },
    { key = "cleanse",    section = "cleanse", label = L["Cleansing"], hideHeader = true },
    { key = "maps",       section = "maps",    label = L["Maps"],      hideHeader = true },
    { key = "castbar",    section = "castbar", label = L["Cast bar"],  hideHeader = true },
    { key = "gtfo",       section = "gtfo",    label = L["Danger alarm"],         hideHeader = true },
}

function AIO:SectionOf(key)
    local sec = key and key:match("^__overview:(.+)$")
    if sec then return sec end
    local catKey = key and key:match("^__cat:(.+)$")
    if catKey then
        for _, cat in ipairs(self.categories) do
            if cat.key == catKey then return cat.section end
        end
    end
    local m = key and self.modules[key]
    if m then
        for _, cat in ipairs(self.categories) do
            if cat.key == m.category then return cat.section end
        end
    end
    return self.sections[1].key
end

AIO.modules, AIO.moduleOrder = {}, {}
local Module = {}
Module.__index = Module

function AIO:NewModule(key, def)
    assert(not self.modules[key], "module registered twice: " .. key)
    def.key = key
    def.enabled = false
    if def.default == nil then def.default = true end
    def.defaults = def.defaults or {}
    setmetatable(def, Module)
    self.modules[key] = def
    self.moduleOrder[#self.moduleOrder + 1] = key
    return def
end

function Module:On(event, fn)
    AIO:On(event, function(...)
        if self.enabled then return fn(...) end
    end)
end

function Module:IsEnabled() return self.enabled end

function Module:Print(text, ...)
    AIO:Print(text, ...)
end

function AIO:ModuleDB(key)
    local m = self.modules[key]
    local all = self.settings.modules
    all[key] = all[key] or {}
    local db = all[key]
    if db.enabled == nil then db.enabled = m.default end
    CopyDefaults(db, m.defaults)
    return db
end

function AIO:SetModuleEnabled(key, on)
    local m = self.modules[key]
    if not m or m.alwaysOn then return end
    m.db.enabled = on and true or false
    if on and not m.enabled then
        m.enabled = true
        if m.OnEnable then
            local ok, err = pcall(m.OnEnable, m)
            if not ok then geterrorhandler()(err) end
        end
    elseif not on and m.enabled then
        m.enabled = false
        if m.OnDisable then
            local ok, err = pcall(m.OnDisable, m)
            if not ok then geterrorhandler()(err) end
        else
            self:Print(L["%s is switched off after a /reload."], m.title or key)
        end
    end
end

function AIO:EnableModules()
    for _, key in ipairs(self.moduleOrder) do
        local m = self.modules[key]
        m.db = self:ModuleDB(key)
        if m.alwaysOn or m.db.enabled then
            m.enabled = true
            if m.OnEnable then
                local ok, err = pcall(m.OnEnable, m)
                if not ok then geterrorhandler()(err) end
            end
        end
    end
end

--- Called by an option after it changed a value.
function AIO:SettingChanged(m, key, value)
    if m and m.OnSettingChanged and m.enabled then
        local ok, err = pcall(m.OnSettingChanged, m, key, value)
        if not ok then geterrorhandler()(err) end
    end
    self:RefreshAll()
end

-- ---------------------------------------------------------------------------
-- Showing and hiding our windows
-- ---------------------------------------------------------------------------

AIO.windows = {}

--- Shows a window. `requester` is the Blizzard frame (or our own key) that
--- asked for it, so that only the same requester closes it again, the way the
--- default bags behave at a vendor or the mailbox.
function AIO:Show(id, requester)
    local w = self.windows[id]
    if not w then return end
    if not w:IsShown() then
        w.openedBy = requester
        w:Show()
    end
    return true
end

function AIO:Hide(id, requester)
    local w = self.windows[id]
    if not w or not w:IsShown() then return false end
    if requester ~= nil and w.openedBy ~= requester then return false end
    w:Hide()
    return true
end

function AIO:Toggle(id)
    local w = self.windows[id]
    if not w then return end
    if w:IsShown() then
        w:Hide()
    else
        w.owner = nil
        self:Show(id)
    end
end

--- Full rebuild of every open window (settings, owner, filter changed).
function AIO:RefreshAll()
    for _, w in pairs(self.windows) do
        if w:IsShown() then w:RequestRefresh() end
    end
end

--- Items changed: open windows repaint, and only lay out again when needed.
function AIO:UpdateAll()
    for _, w in pairs(self.windows) do
        if w:IsShown() then w:RequestUpdate() end
    end
end

--- Only locks and cooldowns changed: repaint the live buttons, nothing else.
function AIO:RepaintAll()
    self:Later("repaint", function()
        for _, w in pairs(AIO.windows) do
            if w:IsShown() then w:Repaint() end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Replacing the default bags
-- ---------------------------------------------------------------------------

function AIO:HookBlizzardBags()
    if not self.settings.replaceBags then return end
    local orig = {}
    for _, name in ipairs({ "ToggleBag", "OpenBag", "CloseBag" }) do orig[name] = _G[name] end

    local function inventoryBag(id)
        return id == nil or AIO:IsInventoryBag(id)
    end

    _G.ToggleAllBags  = function() AIO:Toggle("inventory") end
    _G.ToggleBackpack = function() AIO:Toggle("inventory") end
    _G.OpenAllBags    = function(requester) AIO:Show("inventory", requester) end
    _G.OpenBackpack   = function() AIO:Show("inventory") end
    _G.CloseAllBags   = function(requester) return AIO:Hide("inventory", requester) end
    _G.CloseBackpack  = function() return AIO:Hide("inventory") end
    _G.ToggleKeyRing  = function() AIO:Toggle("inventory") end

    _G.ToggleBag = function(id, ...)
        if inventoryBag(id) then AIO:Toggle("inventory")
        elseif orig.ToggleBag and not AIO.settings.replaceBank then orig.ToggleBag(id, ...) end
    end
    _G.OpenBag = function(id, ...)
        if inventoryBag(id) then AIO:Show("inventory")
        elseif orig.OpenBag and not AIO.settings.replaceBank then orig.OpenBag(id, ...) end
    end
    _G.CloseBag = function(id, ...)
        if inventoryBag(id) then AIO:Hide("inventory")
        elseif orig.CloseBag then orig.CloseBag(id, ...) end
    end
end

-- ---------------------------------------------------------------------------
-- The default bank and guild bank: kept open, but invisible and out of reach.
--
-- Hiding them would end the conversation with the banker, and the game
-- decides from them that a bank is open (a right-click on a bag item then
-- moves it into the bank). So they stay shown, at zero opacity, off screen.
-- ---------------------------------------------------------------------------

local ghosts = {}

local function Banish(frame)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -4000, -4000)
end

function AIO:Ghost(frame)
    if not frame or ghosts[frame] then return end
    ghosts[frame] = true
    frame:HookScript("OnShow", Banish)
    if frame:IsShown() then Banish(frame) end
end

if _G.UpdateUIPanelPositions then
    hooksecurefunc("UpdateUIPanelPositions", function()
        for frame in pairs(ghosts) do
            if frame:IsShown() then Banish(frame) end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Bank
-- ---------------------------------------------------------------------------

function AIO:BankOpened()
    if self.atBank then return end
    self.atBank = true
    self:ScanBank()
    if not self.settings.replaceBank then return end
    self:Ghost(_G.BankFrame)
    local w = self.windows.bank
    w.owner = nil
    self:Show("bank")
    w:RequestRefresh()
    self:Show("inventory", "bank")
end

function AIO:BankClosed()
    if not self.atBank then return end
    self:ScanBank()
    self.atBank = false
    self.closingBank = true
    self:Hide("bank")
    self:Hide("inventory", "bank")
    self.closingBank = nil
end

function AIO:CloseBank()
    if _G.CloseBankFrame then
        _G.CloseBankFrame()
    elseif C_PlayerInteractionManager and C_PlayerInteractionManager.ClearInteraction then
        C_PlayerInteractionManager.ClearInteraction(self.INTERACT_BANKER)
    end
end

-- ---------------------------------------------------------------------------
-- Guild bank
-- ---------------------------------------------------------------------------

function AIO:GuildOpened()
    if self.atGuild then return end
    self.atGuild = true
    self.guildQueried = {}
    if self.settings.replaceGuild then
        self:Ghost(_G.GuildBankFrame)
        local w = self.windows.guild
        w.owner = nil
        w.tab = (_G.GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 1
        self:Show("guild")
        self:Show("inventory", "guild")
    end
    self:QueryGuildTabs()
end

function AIO:GuildClosed()
    if not self.atGuild then return end
    self.atGuild = false
    self.closingGuild = true
    self:Hide("guild")
    self:Hide("inventory", "guild")
    self.closingGuild = nil
end

function AIO:CloseGuild()
    if _G.CloseGuildBankFrame then
        _G.CloseGuildBankFrame()
    elseif C_PlayerInteractionManager and C_PlayerInteractionManager.ClearInteraction then
        C_PlayerInteractionManager.ClearInteraction(self.INTERACT_GUILDBANKER)
    end
end

--- Asks the server for every tab we may see, one after another, so that the
--- whole guild bank can be saved for viewing it later.
function AIO:QueryGuildTabs()
    if not (_G.GetNumGuildBankTabs and _G.QueryGuildBankTab) then return end
    local n = GetNumGuildBankTabs() or 0
    local delay = 0
    for tab = 1, n do
        local _, _, viewable = GetGuildBankTabInfo(tab)
        if viewable then
            C_Timer.After(delay, function()
                if not AIO.atGuild then return end
                AIO.guildQueried[tab] = true
                QueryGuildBankTab(tab)
            end)
            delay = delay + 0.3
        end
    end
end

-- ---------------------------------------------------------------------------
-- Start-up and events
-- ---------------------------------------------------------------------------

AIO:On("ADDON_LOADED", function(name)
    if name == ADDON then
        local dbName = ns.dbName or "AllInOneDB"
        _G[dbName] = _G[dbName] or {}
        local db = _G[dbName]
        db.settings = CopyDefaults(db.settings or {}, AIO.defaults)
        db.settings.modules = db.settings.modules or {}
        db.realms   = db.realms or {}
        db.guilds   = db.guilds or {}
        AIO.db = db
        AIO.settings = db.settings
        -- Settings of modules that were taken out of the addon.
        for _, key in ipairs({ "raidframes", "raidclick", "raidhover", "raidbuffs", "raidpanels", "raidprofiles", "raidtanks" }) do
            db.settings.modules[key] = nil
        end
        db.settings.sortSkip = nil     -- the whole-bag list was taken out again
        -- A build can change a setting once for everyone (Forever: keyring off).
        db.settings.resetDone = db.settings.resetDone or {}
        for k, v in pairs(ns.resetOnce or {}) do
            if not db.settings.resetDone[k] then
                db.settings[k] = v
                db.settings.resetDone[k] = true
            end
        end
        AIO:MigrateData()
    elseif name == "Blizzard_GuildBankUI" and AIO.settings and AIO.settings.replaceGuild then
        AIO:Ghost(_G.GuildBankFrame)
    end
end)

-- One failing step at login (say, a game version with a different bag
-- window) shows its error but does not stop the rest from starting.
local function Step(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

AIO:On("PLAYER_LOGIN", function()
    AIO.realm  = GetRealmName()
    AIO.player = UnitName("player")
    Step(AIO.Style.UseClassAccent, AIO.Style)
    Step(AIO.UpdateCharacter, AIO)
    if not ns.lite then
        Step(AIO.ScanInventory, AIO)
        Step(AIO.CreateWindows, AIO)
        Step(AIO.HookBlizzardBags, AIO)
        Step(AIO.HookTooltips, AIO)
        if AIO.settings.replaceGuild and _G.GuildBankFrame then Step(AIO.Ghost, AIO, _G.GuildBankFrame) end
    end
    AIO:EnableModules()
end)

AIO:On("PLAYER_MONEY", function()
    if not AIO.db then return end
    local c = AIO:CharData()
    c.money = GetMoney()
    for _, w in pairs(AIO.windows) do
        if w:IsShown() then w:UpdateTexts() end
    end
end)
AIO:On("PLAYER_GUILD_UPDATE", function() if AIO.db then AIO:UpdateCharacter() end end)

-- Bags, bank and guild bank: only in the full build.
if not ns.lite then
AIO:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if kind == AIO.INTERACT_BANKER then AIO:BankOpened()
    elseif kind == AIO.INTERACT_GUILDBANKER then AIO:GuildOpened() end
end)
AIO:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if kind == AIO.INTERACT_BANKER then AIO:BankClosed()
    elseif kind == AIO.INTERACT_GUILDBANKER then AIO:GuildClosed() end
end)
AIO:On("BANKFRAME_OPENED",      function() AIO:BankOpened() end)
AIO:On("BANKFRAME_CLOSED",      function() AIO:BankClosed() end)
AIO:On("GUILDBANKFRAME_OPENED", function() AIO:GuildOpened() end)
AIO:On("GUILDBANKFRAME_CLOSED", function() AIO:GuildClosed() end)

-- Bags
local dirtyBags = {}
AIO:On("BAG_UPDATE", function(bag)
    if bag then dirtyBags[bag] = true end
end)
AIO:On("BAG_UPDATE_DELAYED", function()
    for bag in pairs(dirtyBags) do
        if AIO:IsInventoryBag(bag) or (AIO.atBank and AIO:IsBankBag(bag)) then AIO:SaveBag(bag) end
    end
    wipe(dirtyBags)
    AIO:UpdateAll()
end)
AIO:On("PLAYERBANKSLOTS_CHANGED", function()
    if AIO.atBank then AIO:SaveBag(AIO.BANK) end
    AIO:UpdateAll()
end)
AIO:On("PLAYERBANKBAGSLOTS_CHANGED", function()
    if AIO.atBank then AIO:ScanBank() end
    AIO:RefreshAll()
end)
AIO:On("ITEM_LOCK_CHANGED", function() AIO:RepaintAll() end)
AIO:On("BAG_UPDATE_COOLDOWN", function() AIO:RepaintAll() end)

-- Guild bank
AIO:On("GUILDBANKBAGSLOTS_CHANGED", function()
    if not AIO.atGuild then return end
    AIO:SaveGuild()
    AIO:RefreshAll()
end)
AIO:On("GUILDBANK_ITEM_LOCK_CHANGED", function() AIO:RefreshAll() end)
AIO:On("GUILDBANK_UPDATE_TABS", function()
    if AIO.atGuild then AIO:SaveGuild() end
    AIO:RefreshAll()
end)
AIO:On("GUILDBANK_UPDATE_MONEY", function()
    if AIO.atGuild then AIO:SaveGuild() end
    AIO:RefreshAll()
end)
AIO:On("GUILDBANK_UPDATE_WITHDRAWMONEY", function() AIO:RefreshAll() end)

end

-- After a fight, catch up on what could not be laid out during it.
if not ns.lite then AIO:On("PLAYER_REGEN_ENABLED", function() AIO:RefreshAll() end) end

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------

SLASH_ALLINONE1 = "/aio"
SLASH_ALLINONE2 = "/allinone"
SlashCmdList.ALLINONE = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if ns.lite and (cmd == "" or cmd == "bags") then
        AIO:OpenOptions()
    elseif cmd == "" or cmd == "bags" then
        AIO:Toggle("inventory")
    elseif cmd == "bank" then
        AIO:Toggle("bank")
    elseif cmd == "guild" then
        AIO:Toggle("guild")
    elseif cmd == "sort" and AIO.Sort then
        AIO:Sort(rest == "bank" and "bank" or "inventory")
    elseif cmd == "config" or cmd == "options" then
        AIO:OpenOptions()
    elseif cmd == "forget" and rest ~= "" then
        AIO:ForgetCharacter(rest)
    else
        local handled = false
        for _, key in ipairs(AIO.moduleOrder) do
            local m = AIO.modules[key]
            local mine = m.slash == cmd or (type(m.slash) == "table" and m.slash[cmd])
            if m.enabled and m.Slash and mine then
                m:Slash(rest, cmd)
                handled = true
                break
            end
        end
        if not handled then
            AIO:Print(L["Commands: /aio, /aio bank, /aio guild, /aio sort, /aio config, /aio forget NAME"])
        end
    end
end
