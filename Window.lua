-- AllInOne: the window every display is built from.
--
-- A window knows how to draw a header (character choice, sort, options,
-- title, close), a search box, a sidebar of filters, a grid of item buttons
-- and a footer. What goes into the grid is asked of its definition:
--
--   def.Entries(window) -> list of entries, each one of
--       { live = true, bag = n, slot = n }
--       { icon, count, quality, locked, link, mode = "offline" | "guild", tab, slot, guildLive }
--     and `gap = true` on the first entry of a new section
--   def.Title(window) -> string
--   def.Footer(window) -> left text (or nil)
--   def.Money(window) -> copper (or nil)
--   def.Owners(window) -> menu entries for the owner choice (or nil: no button)
--   def.CanSort(window) -> bool
--   def.EmptyNote(window) -> text shown when the grid is empty (or nil)
--   def.Build(window)   -> optional, extra widgets
--   def.OnHide(window)  -> optional
--   def.sidebar = "left" | "right" (filters), def.tabs = true (guild tabs)

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

local SIZE = AIO.SIZE
local PAD = 10

-- A build can ask for Blizzard's own modern window look (WoW Forever): the
-- frame with portrait, title and close button, Blizzard's search box, sort
-- button and money bar. Used only when the game has those templates.
local function HasTemplate(name)
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo) then return false end
    local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
    return ok and info ~= nil
end
local MODERN = ns.skin == "modern" and HasTemplate("PortraitFrameTemplate") and HasTemplate("SearchBoxTemplate")
local function AtlasOK(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

local HEADER = MODERN and 62 or 62     -- title bar and search row
local FOOTER = MODERN and 34 or 28
local MIN_WIDTH = 270
local PORTRAIT = { inventory = "Interface\\Icons\\INV_Misc_Bag_08", bank = "Interface\\Icons\\INV_Box_02",
                   guild = "Interface\\Icons\\INV_Misc_Bag_10" }

local Window = {}

-- ---------------------------------------------------------------------------
-- Filters
-- ---------------------------------------------------------------------------

AIO.filters = {
    { key = "all",     icon = "Interface\\Icons\\INV_Misc_Bag_08",   label = "All" },
    { key = "gear",    icon = "Interface\\Icons\\INV_Sword_04",      label = "Weapons & Armor",
      test = function(class) return class == 2 or class == 4 end },
    { key = "consume", icon = "Interface\\Icons\\INV_Potion_54",     label = "Consumables",
      test = function(class) return class == 0 end },
    { key = "trade",   icon = "Interface\\Icons\\INV_Fabric_Silk_01", label = "Trade Goods",
      test = function(class) return class == 7 or class == 5 or class == 3 or class == 9 end },
    { key = "quest",   icon = "Interface\\Icons\\INV_Misc_Note_01",  label = "Quest",
      test = function(class) return class == 12 end },
    { key = "junk",    icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", label = "Junk",
      test = function(_, quality) return quality == 0 end },
    { key = "other",   icon = "Interface\\Icons\\INV_Misc_Gear_01",  label = "Other",
      test = function(class, quality)
          return quality ~= 0 and not (class == 0 or class == 2 or class == 3 or class == 4
              or class == 5 or class == 7 or class == 9 or class == 12)
      end },
}

local function FilterByKey(key)
    for _, f in ipairs(AIO.filters) do
        if f.key == key then return f end
    end
end

local function Passes(filter, link, quality)
    if not filter or not filter.test then return true end
    if not link then return false end
    local _, class = AIO.ItemInstant(link)
    return filter.test(class, quality) and true or false
end

local function Matches(search, link)
    if not search then return true end
    if not link then return false end
    local name = AIO.LinkName(link)
    if name and name:lower():find(search, 1, true) then return true end
    local _, _, _, itemType, subType = AIO.ItemInstant(link)
    if itemType and itemType:lower():find(search, 1, true) then return true end
    if subType and subType:lower():find(search, 1, true) then return true end
    return false
end

-- ---------------------------------------------------------------------------
-- Small widgets (flat style)
-- ---------------------------------------------------------------------------

local Style = AIO.Style

local function IconButton(parent, icon, tip, onClick)
    return Style.Icon(parent, icon, 22, tip, onClick)
end
AIO.IconButton = IconButton

local function SideButton(parent, icon, tip, onClick)
    local b = Style.Icon(parent, icon, 30, tip, onClick)
    -- Kept for the windows: SetChecked marks the chosen filter or tab.
    b.SetChecked = function(self, on) self:SetActive(on) end
    return b
end
AIO.SideButton = SideButton

function AIO:OpenMenu(anchor, items)
    Style.Menu(anchor, items)
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

--- Blizzard's modern chrome around one of our windows.
local function ModernChrome(f, id, def)
    f.modern = true
    if f.SetPortraitToAsset then
        f:SetPortraitToAsset(PORTRAIT[id] or PORTRAIT.inventory)
    elseif f.PortraitContainer and f.PortraitContainer.portrait then
        f.PortraitContainer.portrait:SetTexture(PORTRAIT[id] or PORTRAIT.inventory)
    end
    f.title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
    f.close = f.CloseButton
    if f.close then f.close:SetScript("OnClick", function() f:Hide() end) end

    -- Right of the search box: sort, options, character.
    local x = -10
    if def.CanSort then
        local b = CreateFrame("Button", nil, f)
        b:SetSize(28, 26)
        if AtlasOK("bags-button-autosort-up") then
            b:SetNormalAtlas("bags-button-autosort-up")
            b:SetPushedAtlas("bags-button-autosort-down")
        else
            b:SetNormalTexture("Interface\\Icons\\Ability_Rogue_Sprint")
        end
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetPoint("TOPRIGHT", x, -31)
        b:SetScript("OnClick", function() AIO:Sort(id) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Sort"])
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        f.sortButton = b
        x = x - 30
    end
    f.optionsButton = IconButton(f, "Interface\\Icons\\Trade_Engineering", L["Options"],
        function() AIO:OpenOptions(AIO.windowPages and AIO.windowPages[id] or "bags") end)
    f.optionsButton:SetPoint("TOPRIGHT", x, -33)
    x = x - 26
    for _, hb in ipairs(def.headerButtons or {}) do
        local b = IconButton(f, hb.icon, hb.tip, function() hb.click(f) end)
        b:SetPoint("TOPRIGHT", x, -33)
        b.def = hb
        f.headerButtons = f.headerButtons or {}
        f.headerButtons[#f.headerButtons + 1] = b
        x = x - 26
    end
    if def.Owners then
        f.ownerButton = IconButton(f, "Interface\\Icons\\INV_Misc_Head_Human_01",
            def.ownerTip or L["Choose character"], function(self)
                local items = def.Owners(f)
                if items and #items > 0 then AIO:OpenMenu(self, items) end
            end)
        f.ownerButton:SetPoint("TOPRIGHT", x, -33)
        x = x - 26
    end

    f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    f.search:SetHeight(20)
    f.search:SetPoint("TOPLEFT", 66, -34)
    f.search:SetPoint("TOPRIGHT", x - 6, -34)
    f.search:SetAutoFocus(false)

    -- Money bar at the bottom, like Blizzard's.
    local bar = CreateFrame("Frame", nil, f, HasTemplate("InsetFrameTemplate") and "InsetFrameTemplate" or nil)
    bar:SetPoint("BOTTOMLEFT", 8, 8)
    bar:SetPoint("BOTTOMRIGHT", -8, 8)
    bar:SetHeight(22)
    f.moneyBar = bar
end

--- The modern Blizzard look drawn by AllInOne (TBC Anniversary): the same
--- layout as the modern chrome, built from Style's own frame parts.
local function DrawnChrome(f, id, def)
    f.modern = true
    Style.Chrome(f)
    Style.Portrait(f, PORTRAIT[id] or PORTRAIT.inventory)
    f.title = Style.Text(f, 13, Style.gold)
    f.title:SetPoint("TOPLEFT", 46, -10)
    f.title:SetPoint("TOPRIGHT", -32, -10)
    f.title:SetJustifyH("CENTER")
    f.title:SetWordWrap(false)
    f.close = Style.CloseX(f)

    -- Right of the search box: sort, options, character.
    local x = -10
    if def.CanSort then
        f.sortButton = IconButton(f, "Interface\\Icons\\Ability_Rogue_Sprint", L["Sort"],
            function() AIO:Sort(id) end)
        f.sortButton:SetPoint("TOPRIGHT", x, -35)
        x = x - 26
    end
    f.optionsButton = IconButton(f, "Interface\\Icons\\Trade_Engineering", L["Options"],
        function() AIO:OpenOptions(AIO.windowPages and AIO.windowPages[id] or "bags") end)
    f.optionsButton:SetPoint("TOPRIGHT", x, -35)
    x = x - 26
    for _, hb in ipairs(def.headerButtons or {}) do
        local b = IconButton(f, hb.icon, hb.tip, function() hb.click(f) end)
        b:SetPoint("TOPRIGHT", x, -35)
        b.def = hb
        f.headerButtons = f.headerButtons or {}
        f.headerButtons[#f.headerButtons + 1] = b
        x = x - 26
    end
    if def.Owners then
        f.ownerButton = IconButton(f, "Interface\\Icons\\INV_Misc_Head_Human_01",
            def.ownerTip or L["Choose character"], function(self)
                local items = def.Owners(f)
                if items and #items > 0 then AIO:OpenMenu(self, items) end
            end)
        f.ownerButton:SetPoint("TOPRIGHT", x, -35)
        x = x - 26
    end

    -- Search box with the magnifier, like the backpack's.
    f.search = Style.Edit(f, 100, L["Search"])
    f.search:SetHeight(22)
    f.search:SetPoint("TOPLEFT", 50, -35)
    f.search:SetPoint("TOPRIGHT", x - 4, -35)
    f.search:SetTextInsets(20, 6, 0, 0)
    f.search.hint:ClearAllPoints()
    f.search.hint:SetPoint("LEFT", 20, 0)
    local glass = f.search:CreateTexture(nil, "OVERLAY")
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", 4, -1)
    glass:SetVertexColor(0.7, 0.7, 0.7)

    -- Money bar at the bottom, like Blizzard's.
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 8, 8)
    bar:SetPoint("BOTTOMRIGHT", -8, 8)
    bar:SetHeight(22)
    Style.Inset(bar)
    f.moneyBar = bar
    f.Bg = f.aioChrome   -- the window alpha setting fades the background
end

function AIO:CreateWindow(id, def)
    -- The modern look is tried first; if anything about it fails, the window
    -- is built in the plain AllInOne style instead.
    local modern = MODERN
    local f
    if Style.blizzard then
        -- AllInOne's own drawing of the modern look; always works.
        f = CreateFrame("Frame", "AllInOne_" .. id, UIParent)
        local ok, err = pcall(DrawnChrome, f, id, def)
        if not ok then geterrorhandler()(err) end
        modern = true
    elseif modern then
        local ok, frame = pcall(CreateFrame, "Frame", "AllInOne_" .. id, UIParent, "PortraitFrameTemplate")
        if ok and frame then
            local fine, err = pcall(ModernChrome, frame, id, def)
            if fine then
                f = frame
            else
                geterrorhandler()(err)
                frame:Hide()
            end
        end
        modern = f ~= nil
    end
    f = f or CreateFrame("Frame", "AllInOne_" .. id .. (MODERN and "Plain" or ""), UIParent)
    for k, v in pairs(Window) do f[k] = v end
    f.id, f.def = id, def
    f.filter = "all"
    f:Hide()
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not AIO.settings.locked or IsAltKeyDown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SavePosition()
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then AIO:OpenOptions(AIO.windowPages and AIO.windowPages[id] or "bags") end
    end)
    f:SetScript("OnShow", f.OnShow)
    f:SetScript("OnHide", f.OnHide)
    tinsert(UISpecialFrames, f:GetName())
    if not modern then
    Style.Flat(f)

    -- Title bar
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetPoint("TOPLEFT", 1, -1)
    f.bar:SetPoint("TOPRIGHT", -1, -1)
    f.bar:SetHeight(30)
    Style.Flat(f.bar, Style.color.panel, { 0, 0, 0, 0 })
    f.accent = f.bar:CreateTexture(nil, "ARTWORK")
    f.accent:SetTexture(Style.WHITE)
    f.accent:SetPoint("BOTTOMLEFT")
    f.accent:SetPoint("BOTTOMRIGHT")
    f.accent:SetHeight(1)

    f.close = Style.CloseButton(f)
    f.close:SetPoint("TOPRIGHT", -6, -6)

    local x = PAD - 6
    if def.Owners then
        f.ownerButton = IconButton(f, "Interface\\Icons\\INV_Misc_Head_Human_01",
            def.ownerTip or L["Choose character"], function(self)
                local items = def.Owners(f)
                if items and #items > 0 then AIO:OpenMenu(self, items) end
            end)
        f.ownerButton:SetPoint("TOPLEFT", x, -5)
        x = x + 26
    end
    if def.CanSort then
        f.sortButton = IconButton(f, "Interface\\Icons\\Ability_Rogue_Sprint", L["Sort"],
            function() AIO:Sort(id) end)
        f.sortButton:SetPoint("TOPLEFT", x, -5)
        x = x + 26
    end
    f.optionsButton = IconButton(f, "Interface\\Icons\\Trade_Engineering", L["Options"],
        function() AIO:OpenOptions(AIO.windowPages and AIO.windowPages[id] or "bags") end)
    f.optionsButton:SetPoint("TOPLEFT", x, -5)
    x = x + 26
    for _, hb in ipairs(def.headerButtons or {}) do
        local b = IconButton(f, hb.icon, hb.tip, function() hb.click(f) end)
        b:SetPoint("TOPLEFT", x, -5)
        b.def = hb
        f.headerButtons = f.headerButtons or {}
        f.headerButtons[#f.headerButtons + 1] = b
        x = x + 26
    end

    f.title = Style.Text(f.bar, 13)
    f.title:SetPoint("LEFT", f.bar, "LEFT", x + 2, 0)
    f.title:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
    f.title:SetWordWrap(false)

    -- Search row
    f.search = Style.Edit(f, 100, L["Search"])
    f.search:SetPoint("TOPLEFT", PAD, -36)
    f.search:SetPoint("TOPRIGHT", -PAD, -36)
    end
    f.search:HookScript("OnTextChanged", function(self)
        local text = self:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "")
        f.searchText = (text ~= "") and text or nil
        f:RequestRefresh()
    end)
    f.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- Items
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", PAD, -HEADER - 6)
    f.content:SetSize(1, 1)

    f.emptyNote = Style.Text(f, 12, Style.color.muted)
    f.emptyNote:SetPoint("TOPLEFT", PAD + 2, -HEADER - 8)
    f.emptyNote:SetPoint("RIGHT", -PAD, 0)
    f.emptyNote:Hide()

    -- Footer
    if not modern then
        f.footLine = Style.Line(f)
        f.footLine:SetPoint("BOTTOMLEFT", 1, FOOTER)
        f.footLine:SetPoint("BOTTOMRIGHT", -1, FOOTER)
    end
    f.footerText = Style.Text(f.moneyBar or f, 11, Style.color.muted)
    f.footerText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", modern and 16 or PAD, modern and 13 or 8)
    f.money = CreateFrame("Button", nil, f.moneyBar or f)
    f.money:SetHeight(16)
    f.money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", modern and -16 or -PAD, modern and 11 or 6)
    f.money.text = Style.Text(f.money, 12)
    f.money.text:SetPoint("RIGHT")
    f.money:SetScript("OnEnter", function(self)
        if def.MoneyTooltip then def.MoneyTooltip(f, self) else AIO:ShowMoneyTooltip(self) end
    end)
    f.money:SetScript("OnLeave", GameTooltip_Hide)

    -- Filters
    if def.sidebar then
        f.sideButtons = {}
        for i, filter in ipairs(AIO.filters) do
            local b = SideButton(f, filter.icon, L[filter.label], function(self)
                f.filter = filter.key
                f:RequestRefresh()
            end)
            if def.sidebar == "left" then
                b:SetPoint("TOPRIGHT", f, "TOPLEFT", -3, -(i - 1) * 33)
            else
                b:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, -(i - 1) * 33)
            end
            b.key = filter.key
            f.sideButtons[i] = b
        end
    end

    if def.Build then def.Build(f) end
    f:ApplySettings()
    self.windows[id] = f
    return f
end

-- ---------------------------------------------------------------------------
-- Behaviour
-- ---------------------------------------------------------------------------

function Window:Settings()
    return AIO:FrameSettings(self.id)
end

function Window:ApplySettings()
    local s = self:Settings()
    self:SetScale(s.scale or 1)
    if self.modern then
        if self.Bg then self.Bg:SetAlpha(s.alpha or 0.92) end
    else
        local bg = Style.color.bg
        Style.SetBackground(self, bg[1], bg[2], bg[3], s.alpha or 0.92)
        Style.SetBorder(self, 0, 0, 0, 1)
        local c = s.border or Style.color.accent
        self.accent:SetVertexColor(c[1], c[2], c[3], 1)
    end
    self:RestorePosition()
end

function Window:SavePosition()
    local point, _, relPoint, x, y = self:GetPoint(1)
    if point then
        self:Settings().point = { point, "UIParent", relPoint, x, y }
    end
end

function Window:RestorePosition()
    local p = self:Settings().point
    self:ClearAllPoints()
    if p then
        self:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    else
        self:SetPoint("CENTER")
    end
end

function Window:OnShow()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862)
    self:Refresh()
end

function Window:OnHide()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 863)
    if AIO.menu and AIO.menu:IsShown() and AIO.menu.anchor and AIO.menu.anchor:GetParent() == self then
        AIO.menu:Hide()
    end
    self.openedBy = nil
    if self.def.OnHide then self.def.OnHide(self) end
end

function Window:RequestRefresh()
    if not self:IsShown() then return end
    self.fullPending = true
    self.workFn = self.workFn or function() self:Work() end
    AIO:Later(self, self.workFn)
end

--- The cheap way: the items may have changed, the grid probably not.
function Window:RequestUpdate()
    if not self:IsShown() then return end
    self.workFn = self.workFn or function() self:Work() end
    AIO:Later(self, self.workFn)
end

-- Runs once per frame at most, whatever asked for it.
function Window:Work()
    if self.fullPending or not self:CanRepaint() then
        self.fullPending = false
        self:Refresh()
    else
        self:UpdateTexts()
        self:Repaint()
    end
end

-- A number that changes when the shape of the live grid changes.
local LAYOUT_BAGS
function Window:LayoutKey()
    if not LAYOUT_BAGS then
        LAYOUT_BAGS = AIO:InventoryBags()
        for _, bag in ipairs(AIO:BankBags()) do LAYOUT_BAGS[#LAYOUT_BAGS + 1] = bag end
        if AIO.KEYRING then LAYOUT_BAGS[#LAYOUT_BAGS + 1] = AIO.KEYRING end
    end
    local key = 0
    for i = 1, #LAYOUT_BAGS do key = key * 7 + AIO.NumSlots(LAYOUT_BAGS[i]) end
    return key
end

--- Can the grid stay as it is? Only for live bags, without a filter, with
--- empty slots shown: then moving items never changes which button shows.
function Window:CanRepaint()
    return self.laidOut and self.liveGrid and self.filter == "all" and AIO.settings.emptySlots
        and self.layoutKey == self:LayoutKey()
end

--- Repaints the live buttons on screen and applies the search to them.
function Window:Repaint()
    local search = self.searchText
    local shown = self.shown
    if not shown then return end
    for i = 1, #shown do
        local b = shown[i]
        if b.isLive then
            local info = AIO:PaintLive(b)
            b:SetAlpha(Matches(search, info and info.hyperlink) and 1 or 0.25)
        end
    end
end

--- Title, footer and money only.
function Window:UpdateTexts()
    local def = self.def
    self.title:SetText(def.Title(self) or "")
    self.footerText:SetText(def.Footer and def.Footer(self) or "")
    local money = def.Money and def.Money(self)
    local fmt = (self.modern and GetMoneyString) and function(c) return GetMoneyString(c, true) end or AIO.Money
    self.money.text:SetText(money and fmt(money) or "")
    self.money:SetWidth(math.max(10, self.money.text:GetStringWidth()))
end

--- Is this window showing something you can act on, rather than saved data?
function Window:IsLive()
    return self.def.IsLive and self.def.IsLive(self) or false
end

function Window:Refresh()
    if not self:IsShown() then return end
    local def = self.def
    local s = self:Settings()
    local cols = math.max(4, s.columns or 10)
    local GAP = AIO.settings.slotGap or AIO.GAP
    local combat = InCombatLockdown()

    self:UpdateTexts()
    if self.sortButton then self.sortButton:SetShown(def.CanSort(self)) end
    for _, b in ipairs(self.headerButtons or {}) do
        if b.def.active then b:SetActive(b.def.active(self)) end
    end
    if self.sideButtons then
        for _, b in ipairs(self.sideButtons) do b:SetChecked(b.key == self.filter) end
    end
    if def.Update then def.Update(self) end

    local filter = FilterByKey(self.filter)
    if filter and not filter.test then filter = nil end
    local search = self.searchText
    local showEmpty = AIO.settings.emptySlots and not filter

    -- During a fight only what is already on screen is repainted: laying the
    -- grid out again waits for the end of the fight.
    if combat and self.laidOut then
        self:Repaint()
        return
    end

    local entries = def.Entries(self) or {}

    -- Hide what was shown last time; the list itself is reused.
    local shown = self.shown
    if shown then
        for i = 1, #shown do shown[i]:Hide() end
        wipe(shown)
    else
        shown = {}
        self.shown = shown
    end
    local liveGrid = false

    -- First pass: which entries show, and how many in each section (a
    -- section ends where an entry starts a new block, e.g. the keyring).
    local keepOf = self.keepOf or {}
    local linkOf = self.linkOf or {}
    local qualOf = self.qualOf or {}
    local secCount = self.secCount or {}
    self.keepOf, self.linkOf, self.qualOf, self.secCount = keepOf, linkOf, qualOf, secCount
    wipe(secCount)
    local sec = 1
    secCount[1] = 0
    for i, e in ipairs(entries) do
        local link, quality
        if e.live then
            local info = AIO.SlotInfo(e.bag, e.slot)
            link, quality = info and info.hyperlink, info and info.quality
        else
            link, quality = e.link, e.quality
        end
        local keep
        if link then keep = Passes(filter, link, quality) else keep = showEmpty end
        if e.gap and secCount[sec] > 0 then sec = sec + 1; secCount[sec] = 0 end
        keepOf[i], linkOf[i], qualOf[i] = keep and true or false, link or false, quality
        if keep then secCount[sec] = secCount[sec] + 1 end
    end

    -- With "partial row at the top" each section starts so far to the right
    -- that its last row is full, like Blizzard's own bags.
    local top = AIO.settings.partialTop
    local function StartCol(n) return top and (cols - n % cols) % cols or 0 end

    local staticIndex = 0
    local col, row = 0, 0
    local extraY = 0
    local placed = 0
    sec = 1
    local secPlaced = 0
    col = StartCol(secCount[1] or 0)

    for i, e in ipairs(entries) do
        local link, quality, keep = linkOf[i] or nil, qualOf[i], keepOf[i]
        if e.gap and secPlaced > 0 then
            sec, secPlaced = sec + 1, 0
            if col > 0 then row = row + 1 end
            extraY = extraY + 8
            col = StartCol(secCount[sec] or 0)
        end

        if keep then
            local b
            if not e.live then
                staticIndex = staticIndex + 1
                b = AIO:StaticButton(self, staticIndex)
                b.mode, b.tab, b.slot, b.guildLive = e.mode, e.tab, e.slot, e.guildLive
                b.quality = quality
                AIO:Paint(b, e.icon, e.count, quality, e.locked, link)
            else
                b = AIO:LiveButton(self, e.bag, e.slot)
                if b then
                    AIO:PaintLive(b)
                    liveGrid = true
                end
            end
            if b then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.content, "TOPLEFT",
                    col * (SIZE + GAP), -(row * (SIZE + GAP) + extraY))
                b:SetAlpha(Matches(search, link) and 1 or 0.25)
                b:Show()
                self.shown[#self.shown + 1] = b
                placed = placed + 1
                secPlaced = secPlaced + 1
                col = col + 1
                if col >= cols then col, row = 0, row + 1 end
            else
                self.pending = true
            end
        end
    end

    local rows = row + ((col > 0) and 1 or 0)
    local gridW = cols * (SIZE + GAP) - GAP
    local gridH = math.max(0, rows * (SIZE + GAP) - GAP) + extraY
    if placed == 0 then gridH = 40 end

    self.content:SetSize(gridW, math.max(1, gridH))
    local width = math.max(MIN_WIDTH, gridW + PAD * 2)
    local height = HEADER + 4 + gridH + 8 + FOOTER
    if def.extraHeight then height = height + def.extraHeight(self) end
    if def.minHeight then height = math.max(height, def.minHeight(self)) end
    self:SetSize(width, height)

    local note = def.EmptyNote and def.EmptyNote(self)
    self.emptyNote:SetText(note or "")
    self.emptyNote:SetShown(placed == 0 and note ~= nil)

    self.laidOut = not combat
    self.liveGrid = liveGrid
    self.layoutKey = self:LayoutKey()
    if AIO.lockMode then AIO:LockOverlays(self) end
end
