-- AllInOne: collects the minimap buttons of other addons behind one button.
--
-- A round button on the minimap edge, in the same golden ring as the other
-- minimap buttons. A click opens a small window with the collected buttons
-- in a grid; they are the addons' own buttons, moved there, so left click,
-- right click and tooltips work exactly as before. Switched off, every
-- button goes back to where it was.
--
-- Found are: LibDBIcon buttons (most addons) and named buttons that other
-- addons put straight onto the minimap. Blizzard's own buttons and map pins
-- (gathering nodes, notes, arrows) stay where they are.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Addon buttons"]       = "Addon-Knöpfe"
    L["Collects the minimap buttons of your other addons behind one button."] =
        "Sammelt die Minikarten-Knöpfe deiner anderen Addons hinter einem Knopf."
    L["The minimap buttons of your other addons disappear from the minimap and are collected behind one round button. A click on it shows them all to choose from; each still works as before (left and right click). Below you can leave single buttons on the minimap."] =
        "Die Minikarten-Knöpfe deiner anderen Addons verschwinden von der Minikarte und werden hinter einem runden Knopf gesammelt. Ein Klick darauf zeigt sie alle zur Auswahl; jeder funktioniert wie bisher (Links- und Rechtsklick). Unten kannst du einzelne Knöpfe an der Minikarte lassen."
    L["Left click: choose an addon"] = "Linksklick: Addon auswählen"
    L["Drag: move"]           = "Ziehen: verschieben"
    L["%d buttons collected"] = "%d Knöpfe gesammelt"
    L["No addon buttons found."] = "Keine Addon-Knöpfe gefunden."
    L["Lock position"]        = "Position sperren"
    L["Reset position"]       = "Position zurücksetzen"
    L["Buttons per row"]      = "Knöpfe pro Reihe"
    L["Close after a click"]  = "Nach einem Klick schliessen"
    L["Close when the mouse leaves"] = "Schliessen, wenn die Maus weggeht"
    L["Also collect the AllInOne button"] = "Auch den AllInOne-Knopf einsammeln"
    L["Found buttons"]        = "Gefundene Knöpfe"
    L["Ticked buttons are collected; the others stay on the minimap."] =
        "Angehakte Knöpfe werden eingesammelt, die anderen bleiben an der Minikarte."
    L["Search again"]         = "Neu suchen"
end

local DEFAULT_ANGLE = 180
local SIZE = 31        -- every classic minimap button
local CELL = 34
local PAD = 6
local SIDE = Style.blizzard and 10 or PAD   -- inside the window frame
local TOP = Style.blizzard and 38 or 24

local M = AIO:NewModule("buttonbag", {
    title    = L["Addon buttons"],
    short    = L["Collects the minimap buttons of your other addons behind one button."],
    desc     = L["The minimap buttons of your other addons disappear from the minimap and are collected behind one round button. A click on it shows them all to choose from; each still works as before (left and right click). Below you can leave single buttons on the minimap."],
    category = "display",
    default  = true,
    defaults = { angle = DEFAULT_ANGLE, lock = false, columns = 6, closeOnClick = true,
                 closeOnLeave = true, own = true },
})

-- ---------------------------------------------------------------------------
-- Which frames are addon buttons
-- ---------------------------------------------------------------------------

-- Blizzard's own minimap parts (TBC Anniversary and the modern client).
local BLIZZARD = {
    GameTimeFrame = true, TimeManagerClockButton = true, QueueStatusMinimapButton = true,
    QueueStatusButton = true, LFGMinimapFrame = true, ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true, GuildInstanceDifficulty = true, FeedbackUIButton = true,
    BattlefieldMinimap = true, AllInOneButtonBag = true,
}
-- Name parts of map pins and markers, which belong on the map.
local PIN_WORDS = { "pin", "node", "poi", "arrow", "gathermate", "handynotes", "tomtom",
                    "questie", "routes", "waypoint", "blip", "dot" }

local function IsPin(lower)
    for i = 1, #PIN_WORDS do
        if lower:find(PIN_WORDS[i], 1, true) then return true end
    end
end

local function Clickable(f)
    if f.IsObjectType and f:IsObjectType("Button") then return true end
    return (f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown")) and true or false
end

local function IsAddonButton(f)
    if type(f) ~= "table" or not f.GetName or f:IsForbidden() then return false end
    local name = f:GetName()
    if not name or BLIZZARD[name] then return false end
    local lower = name:lower()
    if lower:find("^minimap") or IsPin(lower) then return false end
    if name == "AllInOneMinimapButton" then return M.db.own end
    if f.IsProtected and f:IsProtected() then return false end
    local w, h = f:GetSize()
    if not w or w < 16 or w > 48 or h < 16 or h > 48 then return false end
    return Clickable(f)
end

-- ---------------------------------------------------------------------------
-- Collecting and giving back
-- ---------------------------------------------------------------------------

local collector, panel
local found = {}       -- name -> frame, every addon button seen
local held = {}        -- name -> saved place of a collected button
local order = {}       -- names of collected buttons, sorted
local pending          -- a search waits for the end of combat

local function Noop() end

local function SavePoints(b)
    local pts = {}
    for i = 1, b:GetNumPoints() do pts[i] = { b:GetPoint(i) } end
    return pts
end

local function Collect(name, b)
    if held[name] then return end
    held[name] = {
        parent = b:GetParent(), points = SavePoints(b),
        strata = b:GetFrameStrata(), level = b:GetFrameLevel(),
        ownSet = rawget(b, "SetPoint"), ownClear = rawget(b, "ClearAllPoints"),
        dragStart = b:GetScript("OnDragStart"), dragStop = b:GetScript("OnDragStop"),
        setPoint = b.SetPoint, clearPoints = b.ClearAllPoints,
        alpha = b:GetAlpha(),
        fixedStrata = b.IsFixedFrameStrata and b:IsFixedFrameStrata(),
        fixedLevel = b.IsFixedFrameLevel and b:IsFixedFrameLevel(),
    }
    -- LibDBIcon pins its buttons to the MEDIUM layer; unpinned they can sit
    -- on top of the window (else they stay below it: dark and not clickable).
    if b.SetFixedFrameStrata then b:SetFixedFrameStrata(false) end
    if b.SetFixedFrameLevel then b:SetFixedFrameLevel(false) end
    b:SetParent(panel)
    b:SetFrameStrata("DIALOG")
    -- The addon must not pull its button back onto the minimap.
    b.SetPoint, b.ClearAllPoints = Noop, Noop
    if b:HasScript("OnDragStart") then
        b:SetScript("OnDragStart", nil)
        b:SetScript("OnDragStop", nil)
    end
    if not b.aioBagHooked then
        b.aioBagHooked = true
        local after = function()
            if M.enabled and M.db.closeOnClick and held[b:GetName() or ""] and panel then panel:Hide() end
        end
        if b:IsObjectType("Button") then b:HookScript("OnClick", after) else b:HookScript("OnMouseUp", after) end
        b:HookScript("OnShow", function() if M.enabled and held[b:GetName() or ""] then AIO:Later("bagLayout", function() M:Layout() end) end end)
        b:HookScript("OnHide", function() if M.enabled and held[b:GetName() or ""] then AIO:Later("bagLayout", function() M:Layout() end) end end)
    end
end

local function Release(name)
    local s, b = held[name], found[name]
    held[name] = nil
    if not (s and b) then return end
    b.SetPoint, b.ClearAllPoints = s.ownSet, s.ownClear   -- nil gives the normal ones back
    b:SetParent(s.parent or Minimap)
    b:SetFrameStrata(s.strata or "MEDIUM")
    if s.level then b:SetFrameLevel(s.level) end
    if s.fixedStrata and b.SetFixedFrameStrata then b:SetFixedFrameStrata(true) end
    if s.fixedLevel and b.SetFixedFrameLevel then b:SetFixedFrameLevel(true) end
    if s.alpha then b:SetAlpha(s.alpha) end
    b:ClearAllPoints()
    for _, p in ipairs(s.points) do b:SetPoint(unpack(p)) end
    if s.dragStart then b:SetScript("OnDragStart", s.dragStart) end
    if s.dragStop then b:SetScript("OnDragStop", s.dragStop) end
end

local function LibIcon()
    return _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
end

--- Looks for addon buttons and collects the wanted ones.
function M:Scan()
    if not self.enabled then return end
    if InCombatLockdown() then pending = true; return end
    pending = nil
    local lib = LibIcon()
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _, id in ipairs(lib:GetButtonList()) do
            local b = lib:GetMinimapButton(id)
            local name = b and b:GetName()
            if name then found[name] = b end
        end
    end
    for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
        if parent and parent.GetChildren then
            for _, f in ipairs({ parent:GetChildren() }) do
                local name = f.GetName and f:GetName()
                if name and not found[name] and not held[name] and IsAddonButton(f) then found[name] = f end
            end
        end
    end
    local skip = self.db.skip or {}
    for name, b in pairs(found) do
        local want = not skip[name] and (name ~= "AllInOneMinimapButton" or self.db.own)
        if want then Collect(name, b) elseif held[name] then Release(name) end
    end
    self:Layout()
end

function M:ReleaseAll()
    if InCombatLockdown() then return end
    for name in pairs(held) do Release(name) end
end

-- ---------------------------------------------------------------------------
-- The window with the buttons
-- ---------------------------------------------------------------------------

local function Pretty(name)
    return (name:gsub("^LibDBIcon10_", ""))
end

function M:Layout()
    if not panel or InCombatLockdown() then return end
    wipe(order)
    for name in pairs(held) do
        if found[name]:IsShown() then order[#order + 1] = name end
    end
    table.sort(order, function(a, b) return Pretty(a):lower() < Pretty(b):lower() end)
    local cols = math.max(1, math.min(self.db.columns or 6, #order))
    for i, name in ipairs(order) do
        local b, s = found[name], held[name]
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        s.clearPoints(b)
        s.setPoint(b, "CENTER", panel, "TOPLEFT", SIDE + col * CELL + CELL / 2, -(TOP + row * CELL + CELL / 2))
        b:SetFrameStrata("DIALOG")
        b:SetFrameLevel(panel:GetFrameLevel() + 5)
        b:SetAlpha(1)
        b:EnableMouse(true)
    end
    local rows = math.max(1, math.ceil(#order / cols))
    local minW = (panel.title and panel.title:GetStringWidth() or 0) + 60
    if #order == 0 then
        panel.empty:Show()
        panel:SetSize(math.max(minW, panel.empty:GetStringWidth() + 2 * SIDE), TOP + 30)
    else
        panel.empty:Hide()
        panel:SetSize(math.max(minW, SIDE * 2 + cols * CELL), TOP + PAD + rows * CELL)
    end
end

local function PlacePanel()
    local x, y = collector:GetCenter()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = collector:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x, y = (x or 0) * scale, (y or 0) * scale
    local v = (y > h / 2) and "TOP" or "BOTTOM"
    local left = x > w / 2
    panel:ClearAllPoints()
    panel:SetPoint(v .. (left and "RIGHT" or "LEFT"), collector, (v == "TOP" and "BOTTOM" or "TOP") .. (left and "LEFT" or "RIGHT"), 0, 0)
end

-- While the window is open: close it a moment after the mouse has left.
local away = 0
local function Watch(self, elapsed)
    if not M.db.closeOnLeave then return end
    if MouseIsOver(self) or MouseIsOver(collector) then away = 0; return end
    away = away + elapsed
    if away > 1.5 then self:Hide() end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "AllInOneButtonBagPanel", UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    -- The frame of Blizzard's bags: stone background, metal border, title.
    Style.Chrome(panel)
    panel.title = Style.Text(panel, 12, Style.blizzard and Style.gold or C.accent)
    panel.title:SetPoint("TOP", 0, Style.blizzard and -10 or -6)
    panel.title:SetText(L["Addon buttons"])
    if Style.blizzard then
        Style.BlizzardClose(panel)
    else
        local close = Style.CloseButton(panel)
        close:SetPoint("TOPRIGHT", -3, -3)
    end
    panel.empty = Style.Text(panel, 12, C.muted)
    panel.empty:SetPoint("TOP", 0, -TOP - 6)
    panel.empty:SetText(L["No addon buttons found."])
    panel:SetScript("OnShow", function(self) away = 0; self:SetScript("OnUpdate", Watch) end)
    panel:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    tinsert(UISpecialFrames, "AllInOneButtonBagPanel")
end

-- ---------------------------------------------------------------------------
-- The round button
-- ---------------------------------------------------------------------------

function M:Position()
    if not collector then return end
    local angle = math.rad(self.db.angle or DEFAULT_ANGLE)
    local x, y = math.cos(angle), math.sin(angle)
    local w, h = (Minimap:GetWidth() or 140) / 2, (Minimap:GetHeight() or 140) / 2
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
        x, y = x * (w + 6), y * (h + 6)
    else
        x, y = x * (w + 10), y * (h + 10)
    end
    collector:ClearAllPoints()
    collector:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function Drag()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    if not (mx and px) then return end
    local scale = Minimap:GetEffectiveScale() or 1
    px, py = px / scale, py / scale
    local atan2 = math.atan2 or function(yy, xx) return math.atan(yy, xx) end
    M.db.angle = math.deg(atan2(py - my, px - mx)) % 360
    M:Position()
end

local function ShowTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["Addon buttons"], C.accent[1], C.accent[2], C.accent[3])
    local n = 0
    for _ in pairs(held) do n = n + 1 end
    GameTooltip:AddLine(L["%d buttons collected"]:format(n), C.muted[1], C.muted[2], C.muted[3])
    GameTooltip:AddLine(L["Left click: choose an addon"], 1, 1, 1)
    if not M.db.lock then GameTooltip:AddLine(L["Drag: move"], C.muted[1], C.muted[2], C.muted[3]) end
    GameTooltip:Show()
end

local function BuildCollector()
    collector = CreateFrame("Button", "AllInOneButtonBag", Minimap)
    collector:SetSize(SIZE, SIZE)
    collector:SetFrameStrata("MEDIUM")
    collector:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    collector:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    collector:RegisterForDrag("LeftButton")
    collector:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = collector:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(24, 24)
    bg:SetPoint("TOPLEFT", 4, -4)
    collector.icon = collector:CreateTexture(nil, "ARTWORK")
    collector.icon:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\collect")
    collector.icon:SetSize(20, 20)
    collector.icon:SetPoint("TOPLEFT", 6, -6)
    if collector.icon.SetMask then pcall(collector.icon.SetMask, collector.icon, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") end
    local border = collector:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    collector:SetScript("OnEnter", ShowTip)
    collector:SetScript("OnLeave", GameTooltip_Hide)
    collector:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(0.7, 0.7, 0.7) end)
    collector:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(1, 1, 1) end)
    collector:SetScript("OnClick", function()
        GameTooltip_Hide()
        if panel:IsShown() then panel:Hide(); return end
        M:Layout()
        PlacePanel()
        panel:Show()
    end)
    collector:SetScript("OnDragStart", function(self)
        if M.db.lock and not IsAltKeyDown() then return end
        GameTooltip_Hide()
        if panel then panel:Hide() end
        self:SetScript("OnUpdate", Drag)
    end)
    collector:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.icon:SetVertexColor(1, 1, 1)
    end)
end

-- ---------------------------------------------------------------------------
-- Switching on and off, and when to look again
-- ---------------------------------------------------------------------------

local function ScanSoon() AIO:Later("bagScan", function() M:Scan() end) end
local callbackDone

function M:OnEnable()
    if not Minimap then return end
    self.db.skip = self.db.skip or {}
    if not self.db.ownOnce then self.db.ownOnce = true; self.db.own = true end
    if not panel then BuildPanel() end
    if not collector then BuildCollector() end
    self:Position()
    collector:Show()
    self:Scan()
    -- Many addons make their button a little after login.
    if C_Timer and C_Timer.After then
        C_Timer.After(3, ScanSoon)
        C_Timer.After(10, ScanSoon)
    end
    local lib = LibIcon()
    if lib and not callbackDone and lib.RegisterCallback then
        callbackDone = true
        pcall(lib.RegisterCallback, M, "LibDBIcon_IconCreated", function() if M.enabled then ScanSoon() end end)
    end
end

function M:OnDisable()
    if panel then panel:Hide() end
    if collector then
        collector:SetScript("OnUpdate", nil)
        collector:Hide()
    end
    if InCombatLockdown() then pending = "release" else self:ReleaseAll() end
end

M:On("ADDON_LOADED", ScanSoon)
M:On("PLAYER_ENTERING_WORLD", function()
    if C_Timer and C_Timer.After then C_Timer.After(2, ScanSoon) end
end)
AIO:On("PLAYER_REGEN_ENABLED", function()
    if pending == "release" and not M.enabled then pending = nil; M:ReleaseAll()
    elseif pending and M.enabled then M:Scan() end
end)

function M:OnSettingChanged(key)
    if key == "own" then
        if not self.db.own and held.AllInOneMinimapButton then Release("AllInOneMinimapButton") end
        self:Scan()
    elseif key == "angle" or key == "lock" then
        self:Position()
    else
        self:Layout()
    end
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local function FoundList(parent, width)
    local names = {}
    for name in pairs(found) do
        if name ~= "AllInOneMinimapButton" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return Pretty(a):lower() < Pretty(b):lower() end)
    if #names == 0 then
        local fs = Style.Text(parent, 12, C.muted)
        fs:SetPoint("TOPLEFT")
        fs:SetText(L["No addon buttons found."])
        return 20
    end
    local colW = math.floor(width / 2)
    for i, name in ipairs(names) do
        local check = Style.Check(parent, Pretty(name),
            function() return not (M.db.skip and M.db.skip[name]) end,
            function(v)
                M.db.skip = M.db.skip or {}
                M.db.skip[name] = (not v) or nil
                if v then M:Scan() else Release(name); M:Layout() end
            end)
        check:SetPoint("TOPLEFT", ((i - 1) % 2) * colW, -math.floor((i - 1) / 2) * 24)
    end
    return math.ceil(#names / 2) * 24
end

M.options = {
    { type = "toggle", key = "lock", label = L["Lock position"], half = true },
    { type = "button", label = L["Reset position"], half = true, func = function(m)
        m.db.angle = DEFAULT_ANGLE
        m:Position()
    end },
    { type = "slider", key = "columns", label = L["Buttons per row"], min = 2, max = 12, step = 1 },
    { type = "toggle", key = "closeOnClick", label = L["Close after a click"] },
    { type = "toggle", key = "closeOnLeave", label = L["Close when the mouse leaves"] },
    { type = "toggle", key = "own", label = L["Also collect the AllInOne button"] },
    { type = "header", label = L["Found buttons"] },
    { type = "text",   label = L["Ticked buttons are collected; the others stay on the minimap."] },
    { type = "custom", build = function(parent, width) return FoundList(parent, width) end },
    { type = "button", label = L["Search again"], func = function(m) m:Scan() end },
}
