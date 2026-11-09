-- AllInOne: maps. A windowed world map you can move, scale and fade while
-- running, with zone and continent menus; coordinates and zone levels on it;
-- and a battlefield map (Shift+M) you can move, size and fade.
--
-- Written for AllInOne; the ideas come from Leatrix Maps (no code taken).
--
-- Everything here works on Blizzard's own map frames. Changes to the frames
-- themselves are made once, when the module starts; switching the window
-- map off again needs a /reload.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Map window"]              = "Fensterkarte"
    L["The world map as a window instead of full screen: move it, scale it, let it fade while you run, with menus for continent and zone."] =
        "Die Weltkarte als Fenster statt Vollbild: verschieben, skalieren, beim Laufen durchsichtig, mit Menüs für Kontinent und Zone."
    L["Window"]                  = "Fenster"
    L["Scale"]                   = "Grösse"
    L["Lock position"]           = "Position sperren"
    L["Unlocked: drag the map at its edge. Alt + drag always works."] =
        "Entsperrt: Karte am Rand ziehen. Alt + Ziehen geht immer."
    L["Reset position"]          = "Position zurücksetzen"
    L["Continent and zone menus"] = "Menüs für Kontinent und Zone"
    L["Opacity"]                 = "Deckkraft"
    L["Standing still"]          = "Im Stillstand"
    L["While moving"]            = "Beim Laufen"
    L["Fully visible under the mouse"] = "Unter der Maus voll sichtbar"
    L["Switching the map window on or off takes effect after a /reload."] =
        "Das Ein- und Ausschalten der Fensterkarte wirkt nach einem /reload."
    L["Zoom"]                    = "Zoom"
    L["Deepest zoom"]            = "Tiefster Zoom"
    L["Mouse wheel zooms in and out."] = "Das Mausrad zoomt hinein und heraus."
    L["Drag: resize"]            = "Ziehen: Grösse ändern"
    L["Drag here to move the map. Alt + drag on the map works too."] =
        "Hier ziehen, um die Karte zu verschieben. Alt + Ziehen auf der Karte geht auch."
    L["Coordinates & levels"]    = "Koordinaten & Stufen"
    L["Your coordinates and the cursor's on the map, and the level range of a zone when you point at it."] =
        "Deine Koordinaten und die des Mauszeigers auf der Karte, und der Stufenbereich einer Zone, wenn du darauf zeigst."
    L["Show coordinates"]        = "Koordinaten zeigen"
    L["Show zone levels"]        = "Zonenstufen zeigen"
    L["Player"]                  = "Spieler"
    L["Cursor"]                  = "Cursor"
    L["Battlefield map"]         = "Schlachtfeldkarte"
    L["The small zone map (Shift+M): move it, set its size and opacity, larger icons, and keep it centred on you."] =
        "Die kleine Zonenkarte (Shift+M): verschieben, Grösse und Deckkraft einstellen, grössere Symbole und auf dich zentriert halten."
    L["Size"]                    = "Grösse"
    L["Your arrow"]              = "Dein Pfeil"
    L["Group icons"]             = "Gruppensymbole"
    L["Keep centred on you"]     = "Auf dich zentriert halten"
    L["Hold Shift while dragging the map to look around."] = "Halte Shift beim Ziehen der Karte, um dich umzusehen."
    L["Unlocked: drag the map to move it. Alt + drag always works."] =
        "Entsperrt: Karte ziehen zum Verschieben. Alt + Ziehen geht immer."
end

local function Pct(v) return ("%d%%"):format(v * 100 + 0.5) end
local function Try(fn, ...) local ok, a, b = pcall(fn, ...) if ok then return a, b end end

-- ===========================================================================
-- Map window
-- ===========================================================================

local W = AIO:NewModule("worldmap", {
    title     = L["Map window"],
    short     = L["The world map as a window instead of full screen: move it, scale it, let it fade while you run, with menus for continent and zone."],
    desc      = L["The world map as a window instead of full screen: move it, scale it, let it fade while you run, with menus for continent and zone."],
    category  = "maps",
    default   = true,
    defaults  = { scale = 0.9, locked = false, menus = true, alphaStill = 1, alphaMoving = 0.6, mouseFull = true, zoom = 2 },
})

local hidden = CreateFrame("Frame")
hidden:Hide()

local function MapPoint()
    local p = W.db.point
    WorldMapFrame:ClearAllPoints()
    if p then
        WorldMapFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

local function SavePoint()
    local p, _, rp, x, y = WorldMapFrame:GetPoint(1)
    if p then W.db.point = { p, rp, x, y } end
end

--- Repaints the open options page (after the map changed a value itself).
function AIO:RefreshOptionsPage()
    local o = _G.AllInOneOptions
    if o and o:IsShown() and o.RefreshPage then o:RefreshPage() end
end

-- Continent and zone menus -------------------------------------------------

local CONTINENTS = { 1415, 1414, 1945 }   -- Eastern Kingdoms, Kalimdor, Outland
local ZONE_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local CONTINENT_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2

local function MapName(id)
    local info = C_Map.GetMapInfo(id)
    return info and info.name or tostring(id)
end

--- The continent a map lies on (or nil for the world view).
local function ContinentOf(id)
    local guard = 0
    while id and guard < 10 do
        local info = C_Map.GetMapInfo(id)
        if not info then return nil end
        if info.mapType == CONTINENT_TYPE then return id end
        id = info.parentMapID
        guard = guard + 1
    end
end

local zoneCache = {}
local function ZonesOf(continent)
    local list = zoneCache[continent]
    if list then return list end
    list = {}
    for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, ZONE_TYPE, true) or {}) do
        -- only zones directly on this continent (no zones of other worlds)
        if ContinentOf(child.mapID) == continent then
            list[#list + 1] = { value = child.mapID, label = child.name }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    zoneCache[continent] = list
    return list
end

local menus
local function BuildMenus(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("LEFT", 4, 0)
    f:SetSize(380, 22)
    local continentValues = {}
    for _, id in ipairs(CONTINENTS) do continentValues[#continentValues + 1] = { value = id, label = MapName(id) } end
    f.continent = Style.Dropdown(f, 160, continentValues,
        function() return ContinentOf(WorldMapFrame:GetMapID()) end,
        function(id) WorldMapFrame:SetMapID(id) end)
    f.continent:SetPoint("LEFT")
    f.continent.emptyText = MapName(947)
    f.zone = Style.Dropdown(f, 200,
        function()
            local c = ContinentOf(WorldMapFrame:GetMapID())
            return c and ZonesOf(c) or {}
        end,
        function()
            local id = WorldMapFrame:GetMapID()
            local info = id and C_Map.GetMapInfo(id)
            return info and info.mapType ~= CONTINENT_TYPE and id or nil
        end,
        function(id) WorldMapFrame:SetMapID(id) end)
    f.zone:SetPoint("LEFT", f.continent, "RIGHT", 6, 0)
    f.zone.emptyText = "|cff999999-|r"
    function f.Update()
        f.continent:Update()
        f.zone:Update()
        f.zone:SetShown(ContinentOf(WorldMapFrame:GetMapID()) ~= nil)
    end
    return f
end

-- Opacity ------------------------------------------------------------------

local fadeAdded
local function ApplyOpacity()
    local db = W.db
    if IsPlayerMoving and IsPlayerMoving() then
        WorldMapFrame:SetAlpha(db.alphaMoving)
    else
        WorldMapFrame:SetAlpha(db.alphaStill)
    end
    local fader = _G.PlayerMovementFrameFader
    if fader and fader.AddDeferredFrame then
        if fadeAdded and fader.RemoveFrame then Try(fader.RemoveFrame, WorldMapFrame) end
        Try(fader.AddDeferredFrame, WorldMapFrame, db.alphaMoving, db.alphaStill, 0.5, function()
            return not (W.db.mouseFull and WorldMapFrame:IsMouseOver())
        end)
        fadeAdded = true
    end
end

-- Setting it all up (once) --------------------------------------------------

local built
local function SetupWindow()
    if built or not _G.WorldMapFrame then return end
    built = true
    local map = WorldMapFrame

    -- Other windows opening must not close the map; Esc still does.
    map:SetAttribute("UIPanelLayout-area", nil)
    map:SetAttribute("UIPanelLayout-enabled", false)
    tinsert(UISpecialFrames, "WorldMapFrame")

    -- The small (windowed) map, a bit larger than Blizzard's.
    SetCVar("miniWorldMap", 1)
    map.minimizedWidth, map.minimizedHeight = 1024, 712
    map:SetSize(1024, 712)
    if map.OnFrameSizeChanged then Try(map.OnFrameSizeChanged, map) end
    if map.BlackoutFrame then
        map.BlackoutFrame:Hide()
        hooksecurefunc(map.BlackoutFrame, "Show", function(self) self:Hide() end)
    end
    local maxBtn = map.MaximizeMinimizeFrame and map.MaximizeMinimizeFrame.MaximizeButton
    if maxBtn then
        maxBtn:Hide()
        hooksecurefunc(maxBtn, "Show", function(self) self:Hide() end)
    end
    -- Blizzard's title bar would move the map its own way; ours does it.
    local title = _G.WorldMapTitleButton
    if title then
        title:Hide()
        hooksecurefunc(title, "Show", function(self) self:Hide() end)
    end
    -- Blizzard's own opacity setting is replaced by ours.
    if _G.WorldMapFrame_SetOpacity then Try(WorldMapFrame_SetOpacity, 0) end
    SetCVar("worldMapOpacity", 0)
    map:SetFrameStrata("MEDIUM")
    if map.BorderFrame then map.BorderFrame:SetFrameStrata("MEDIUM") end

    -- Scale: the map sizes itself from the UI, so the cursor is corrected.
    if map.SetIgnoreParentScale then map:SetIgnoreParentScale(false) end
    if map.ScrollContainer.SetIgnoreParentScale then map.ScrollContainer:SetIgnoreParentScale(false) end
    local base = _G.MapCanvasScrollControllerMixin and MapCanvasScrollControllerMixin.GetCursorPosition
    if base then
        map.ScrollContainer.GetCursorPosition = function(f)
            local x, y = base(f)
            local s = map:GetScale() * UIParent:GetEffectiveScale()
            return x / s, y / s
        end
    end
    map:SetScale(W.db.scale)

    -- Moving: at the edge while unlocked, with Alt always.
    map:SetMovable(true)
    map:SetClampedToScreen(true)
    map:RegisterForDrag("LeftButton")
    map:SetScript("OnDragStart", function(self)
        if not W.db.locked or IsAltKeyDown() then self:StartMoving() end
    end)
    map:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self.SetUserPlaced then self:SetUserPlaced(false) end
        SavePoint()
    end)
    map.ScrollContainer:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and IsAltKeyDown() then map.aioMoving = true; map:StartMoving() end
    end)
    map.ScrollContainer:HookScript("OnMouseUp", function()
        if map.aioMoving then
            map.aioMoving = nil
            map:StopMovingOrSizing()
            SavePoint()
        end
    end)
    if map.SynchronizeDisplayState then hooksecurefunc(map, "SynchronizeDisplayState", MapPoint) end
    if map.OnFrameSizeChanged then hooksecurefunc(map, "OnFrameSizeChanged", MapPoint) end
    MapPoint()

    -- Blizzard's frame around the small map is replaced by a flat one of
    -- ours: a title bar (menus, close, drag to move) and a thin border.
    local sc = map.ScrollContainer
    for _, name in ipairs({ "MiniBorderLeft", "MiniBorderRight", "MiniWorldMapTitle", "WorldMapFrameCloseButton",
                            "WorldMapContinentDropdown", "WorldMapZoneDropdown", "WorldMapZoomOutButton",
                            "WorldMapZoneMinimapDropdown", "WorldMapContinentDropDown", "WorldMapZoneDropDown",
                            "WorldMapMagnifyingGlassButton" }) do
        local f = _G[name]
        if f then
            f:Hide()
            if f.SetParent then f:SetParent(hidden) end
        end
    end
    for _, f in ipairs({ map.BorderFrame, map.MiniBorderFrame, map.MaximizeMinimizeFrame }) do
        if f and f.Hide then
            f:Hide()
            hooksecurefunc(f, "Show", function(self) self:Hide() end)
        end
    end

    local edge = CreateFrame("Frame", nil, map)
    local modern = Style.blizzard   -- the AllInOne look of the bags and options
    if modern then
        -- The frame of the bags: bronze edge, dark title band with the menus,
        -- round portrait, red close button.
        edge:SetPoint("TOPLEFT", sc, "TOPLEFT", -8, 34)
        edge:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", 8, -8)
    else
        edge:SetPoint("TOPLEFT", sc, "TOPLEFT", -1, 27)
        edge:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", 1, -1)
    end
    edge:SetFrameLevel(math.max(0, (sc:GetFrameLevel() or 1) - 1))
    if modern then
        Style.Chrome(edge)
        Style.Portrait(edge, "Interface\\Icons\\INV_Misc_Map_01")
    else
        Style.Flat(edge, { 0, 0, 0, 0.6 }, { 0, 0, 0, 1 })
    end

    local head = CreateFrame("Frame", "AllInOneMapTitle", map)
    if modern then
        -- In the title band, right of the portrait and left of the close button.
        head:SetPoint("BOTTOMLEFT", sc, "TOPLEFT", 40, 5)
        head:SetPoint("BOTTOMRIGHT", sc, "TOPRIGHT", -26, 5)
        head:SetHeight(24)
    else
        head:SetPoint("BOTTOMLEFT", sc, "TOPLEFT", 0, 1)
        head:SetPoint("BOTTOMRIGHT", sc, "TOPRIGHT", 0, 1)
        head:SetHeight(25)
    end
    head:SetFrameLevel((sc:GetFrameLevel() or 1) + 30)
    if not modern then Style.Flat(head, C.panel, { 0, 0, 0, 0 }) end
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() if not W.db.locked or IsAltKeyDown() then map:StartMoving() end end)
    head:SetScript("OnDragStop", function()
        map:StopMovingOrSizing()
        if map.SetUserPlaced then map:SetUserPlaced(false) end
        SavePoint()
    end)
    head:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Drag here to move the map. Alt + drag on the map works too."], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", GameTooltip_Hide)
    if modern then
        local close = Style.CloseX(edge, function() map:Hide() end)
        close:SetFrameLevel((sc:GetFrameLevel() or 1) + 31)
    else
        local close = Style.CloseButton(head, function() map:Hide() end)
        close:SetPoint("RIGHT", -4, 0)
    end

    -- Zoom with the mouse wheel, and deeper than Blizzard allows.
    hooksecurefunc(sc, "CreateZoomLevels", function(self)
        local f = W.db.zoom or 1
        if f <= 1 then return end
        local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(self.mapID)
        local first = layers and layers[1]
        if not first or not first.layerWidth then return end
        local base = math.min(self:GetWidth() / first.layerWidth, self:GetHeight() / first.layerHeight)
        self.baseScale = base
        local levels, last = {}, 0
        for i, layer in ipairs(layers) do
            local lo, hi = layer.minScale, layer.maxScale * f
            local steps = 2 + (layer.additionalZoomSteps or 0) + math.ceil((f - 1) * 3)
            for k = 0, steps - 1 do
                local v = math.max(lo + (hi - lo) * k / (steps - 1), last + 0.01)
                last = v
                levels[#levels + 1] = { scale = v * base, layerIndex = i }
            end
        end
        self.zoomLevels = levels
    end)
    sc:EnableMouseWheel(true)
    sc:HookScript("OnMouseWheel", function(self, delta)
        if not (self.GetCurrentZoomRange and self.InstantPanAndZoom) then return end
        local x, y = self:GetNormalizedCursorPosition()
        local zoomOut, zoomIn = self:GetCurrentZoomRange()
        local now = self:GetCanvasScale()
        if delta > 0 and zoomIn and zoomIn > now then
            self:InstantPanAndZoom(zoomIn, x, y)
        elseif delta < 0 and zoomOut and zoomOut < now then
            self:InstantPanAndZoom(zoomOut, x, y)
        end
    end)

    -- Bottom-right grip: drag to make the map bigger or smaller.
    local grip = CreateFrame("Button", "AllInOneMapGrip", map)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel((sc:GetFrameLevel() or 1) + 40)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Drag: resize"], 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)
    grip:SetScript("OnMouseDown", function(self)
        local s0 = map:GetScale()
        local left, top = map:GetLeft() * s0, map:GetTop() * s0          -- screen units
        local cx, cy = GetCursorPosition()
        local ui = UIParent:GetEffectiveScale()
        local d0 = math.max(1, math.sqrt((cx / ui - left) ^ 2 + (top - cy / ui) ^ 2))
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local d = math.sqrt((x / ui - left) ^ 2 + (top - y / ui) ^ 2)
            local sc2 = math.min(2, math.max(0.5, s0 * d / d0))
            map:SetScale(sc2)
            map:ClearAllPoints()
            map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / sc2, top / sc2)
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        W.db.scale = math.floor(map:GetScale() * 100 + 0.5) / 100
        SavePoint()
        if map.OnFrameSizeChanged then Try(map.OnFrameSizeChanged, map) end
        AIO:RefreshOptionsPage()
    end)
    W.grip = grip

    menus = BuildMenus(head)
    menus:SetShown(W.db.menus)
    if map.OnMapChanged then hooksecurefunc(map, "OnMapChanged", function() if menus:IsShown() then menus.Update() end end) end
    map:HookScript("OnShow", function() if menus:IsShown() then menus.Update() end end)

    ApplyOpacity()
end

W.options = {
    { type = "text", label = L["Switching the map window on or off takes effect after a /reload."] },
    { type = "header", label = L["Window"] },
    { type = "slider", key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05, format = Pct, half = true },
    { type = "toggle", key = "locked", label = L["Lock position"], half = true },
    { type = "text", label = L["Unlocked: drag the map at its edge. Alt + drag always works."] },
    { type = "toggle", key = "menus", label = L["Continent and zone menus"] },
    { type = "header", label = L["Zoom"] },
    { type = "text", label = L["Mouse wheel zooms in and out."] },
    { type = "slider", key = "zoom", label = L["Deepest zoom"], min = 1, max = 4, step = 0.5, format = Pct, half = true },
    { type = "button", label = L["Reset position"], func = function(m) m.db.point = nil; if built then MapPoint() end end },
    { type = "header", label = L["Opacity"] },
    { type = "slider", key = "alphaStill",  label = L["Standing still"], min = 0.1, max = 1, step = 0.05, format = Pct, half = true },
    { type = "slider", key = "alphaMoving", label = L["While moving"],   min = 0.1, max = 1, step = 0.05, format = Pct, half = true },
    { type = "toggle", key = "mouseFull", label = L["Fully visible under the mouse"] },
}

function W:OnEnable()
    if _G.WorldMapFrame then SetupWindow() else self.waiting = true end
end

function W:OnSettingChanged(key)
    if not built then return end
    if key == "scale" then
        WorldMapFrame:SetScale(self.db.scale)
        MapPoint()
    elseif key == "menus" then
        menus:SetShown(self.db.menus)
        if self.db.menus then menus.Update() end
    elseif key == "alphaStill" or key == "alphaMoving" or key == "mouseFull" then
        ApplyOpacity()
    elseif key == "zoom" then
        local sc = WorldMapFrame.ScrollContainer
        if sc.CreateZoomLevels then Try(sc.CreateZoomLevels, sc) end
    end
end

AIO:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then
        if W.enabled and W.waiting then W.waiting = nil; SetupWindow() end
        local I = AIO.modules.mapinfo
        if I and I.enabled and I.waiting then I.waiting = nil; I:OnEnable() end
    end
end)

-- ===========================================================================
-- Coordinates & zone levels
-- ===========================================================================

local I = AIO:NewModule("mapinfo", {
    title     = L["Coordinates & levels"],
    short     = L["Your coordinates and the cursor's on the map, and the level range of a zone when you point at it."],
    desc      = L["Your coordinates and the cursor's on the map, and the level range of a zone when you point at it."],
    category  = "maps",
    default   = true,
    defaults  = { coords = true, levels = true },
    options   = {
        { type = "toggle", key = "coords", label = L["Show coordinates"] },
        { type = "toggle", key = "levels", label = L["Show zone levels"] },
    },
})

-- Level ranges of the zones, by map ID (Classic, Burning Crusade).
local LEVELS = {
    -- Eastern Kingdoms
    [1429] = { 1, 10 },  [1426] = { 1, 10 },  [1420] = { 1, 10 },  [1941] = { 1, 10 },
    [1436] = { 10, 20 }, [1432] = { 10, 20 }, [1421] = { 10, 20 }, [1942] = { 10, 20 },
    [1433] = { 15, 25 }, [1431] = { 18, 30 }, [1437] = { 20, 30 }, [1424] = { 20, 30 },
    [1416] = { 30, 40 }, [1417] = { 30, 40 }, [1434] = { 30, 45 }, [1418] = { 35, 45 },
    [1435] = { 35, 45 }, [1425] = { 40, 50 }, [1427] = { 43, 50 }, [1419] = { 45, 55 },
    [1428] = { 50, 58 }, [1422] = { 51, 58 }, [1423] = { 53, 60 }, [1430] = { 55, 60 },
    [1957] = { 70, 70 },
    -- Kalimdor
    [1411] = { 1, 10 },  [1412] = { 1, 10 },  [1438] = { 1, 10 },  [1943] = { 1, 10 },
    [1439] = { 10, 20 }, [1413] = { 10, 25 }, [1950] = { 10, 20 }, [1442] = { 15, 27 },
    [1440] = { 18, 30 }, [1441] = { 25, 35 }, [1443] = { 30, 40 }, [1445] = { 35, 45 },
    [1444] = { 40, 50 }, [1446] = { 40, 50 }, [1447] = { 45, 55 }, [1448] = { 48, 55 },
    [1449] = { 48, 55 }, [1452] = { 53, 60 }, [1451] = { 55, 60 },
    -- Outland
    [1944] = { 58, 63 }, [1946] = { 60, 64 }, [1952] = { 62, 65 }, [1951] = { 64, 67 },
    [1949] = { 65, 68 }, [1953] = { 67, 70 }, [1948] = { 67, 70 },
}

local function LevelText(range)
    local lo, hi = range[1], range[2]
    local me = UnitLevel("player")
    local color
    if GetQuestDifficultyColor then
        if me < lo then color = GetQuestDifficultyColor(lo)
        elseif me > hi then color = GetQuestDifficultyColor(hi - 2)
        else color = QuestDifficultyColors and QuestDifficultyColors.difficult or GetQuestDifficultyColor(me + 3) end
    end
    local txt = lo == hi and ("(" .. lo .. ")") or ("(" .. lo .. "-" .. hi .. ")")
    if color then txt = ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, txt) end
    return txt
end
ns.MapLevels, ns.MapLevelText = LEVELS, LevelText

-- The area label ("Duskwood") gets the level range behind it.
local labelHooked
local function HookAreaLabel()
    if labelHooked then return end
    for provider in next, WorldMapFrame.dataProviders or {} do
        if provider.setAreaLabelCallback and provider.Label then
            local label = provider.Label
            local orig = label:GetScript("OnUpdate")
            if orig then
                labelHooked = true
                label:SetScript("OnUpdate", function(self, elapsed)
                    orig(self, elapsed)
                    if not (I.enabled and I.db.levels) then return end
                    local map = self.dataProvider and self.dataProvider:GetMap()
                    if not (map and map:IsCanvasMouseFocus()) then return end
                    local mapID = map:GetMapID()
                    local x, y = map:GetNormalizedCursorPosition()
                    local info = mapID and x and C_Map.GetMapInfoAtPosition(mapID, x, y)
                    local range = info and info.mapID ~= mapID and LEVELS[info.mapID]
                    if range and MAP_AREA_LABEL_TYPE then
                        self:SetLabel(MAP_AREA_LABEL_TYPE.AREA_NAME, info.name .. " " .. LevelText(range))
                        self:EvaluateLabels()
                    end
                end)
            end
        end
    end
end

-- Coordinates bar at the bottom of the map.
local bar
local function BuildCoords()
    bar = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetHeight(18)
    bar:SetFrameLevel((WorldMapFrame.ScrollContainer:GetFrameLevel() or 1) + 2000)   -- above map pins
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(Style.WHITE)
    bg:SetAllPoints()
    bg:SetVertexColor(0, 0, 0, 0.55)
    bar.player = Style.Text(bar, 12)
    bar.player:SetPoint("LEFT", 10, 0)
    bar.cursor = Style.Text(bar, 12)
    bar.cursor:SetPoint("RIGHT", -26, 0)
    local t = 0
    bar:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        if t < 0.1 then return end
        t = 0
        local id = C_Map.GetBestMapForUnit("player")
        local ok, pos = false, nil
        if id then ok, pos = pcall(C_Map.GetPlayerMapPosition, id, "player") end
        if ok and pos and pos.x and pos.x > 0 then
            self.player:SetFormattedText("%s: %.1f, %.1f", L["Player"], pos.x * 100, pos.y * 100)
        else
            self.player:SetText(L["Player"] .. ": -")
        end
        local sc = WorldMapFrame.ScrollContainer
        if sc:IsMouseOver() then
            local x, y = sc:GetNormalizedCursorPosition()
            if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                self.cursor:SetFormattedText("%s: %.1f, %.1f", L["Cursor"], x * 100, y * 100)
                return
            end
        end
        self.cursor:SetText("")
    end)
end

function I:OnEnable()
    if not _G.WorldMapFrame then self.waiting = true return end
    if not bar then BuildCoords() end
    bar:SetShown(self.db.coords)
    HookAreaLabel()
end

function I:OnDisable()
    if bar then bar:Hide() end
end

function I:OnSettingChanged()
    if bar then bar:SetShown(self.db.coords) end
end

-- ===========================================================================
-- Battlefield map
-- ===========================================================================

local B = AIO:NewModule("battlemap", {
    title     = L["Battlefield map"],
    short     = L["The small zone map (Shift+M): move it, set its size and opacity, larger icons, and keep it centred on you."],
    desc      = L["The small zone map (Shift+M): move it, set its size and opacity, larger icons, and keep it centred on you."],
    category  = "maps",
    default   = true,
    defaults  = { size = 300, alpha = 1, arrow = 12, group = 12, center = false, locked = true },
    options   = {
        { type = "slider", key = "size",  label = L["Size"],    min = 150, max = 1000, step = 10, half = true },
        { type = "slider", key = "alpha", label = L["Opacity"], min = 0.1, max = 1, step = 0.05, format = Pct, half = true },
        { type = "slider", key = "arrow", label = L["Your arrow"],  min = 12, max = 48, step = 1, half = true },
        { type = "slider", key = "group", label = L["Group icons"], min = 8, max = 40, step = 1, half = true },
        { type = "toggle", key = "center", label = L["Keep centred on you"], desc = L["Hold Shift while dragging the map to look around."], half = true },
        { type = "toggle", key = "locked", label = L["Lock position"], half = true },
        { type = "text", label = L["Unlocked: drag the map to move it. Alt + drag always works."] },
        { type = "button", label = L["Reset position"], func = function(m)
            m.db.point = nil
            if m.Place then m:Place() end
        end },
    },
})

local bf      -- BattlefieldMapFrame once set up

function B:Place()
    if not bf then return end
    local p = self.db.point
    bf:ClearAllPoints()
    if p then bf:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else bf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 90) end
end

function B:ApplySize()
    if not bf then return end
    bf:SetSize(self.db.size, self.db.size / 1.5)
    if bf.OnFrameSizeChanged then Try(bf.OnFrameSizeChanged, bf) end
end

function B:ApplyAlpha()
    if not bf then return end
    if _G.BattlefieldMapOptions then BattlefieldMapOptions.opacity = 1 - self.db.alpha end
    if bf.RefreshAlpha then Try(bf.RefreshAlpha, bf) end
end

function B:ApplyIcons()
    if not bf or not bf.EnumerateAllPins then return end
    for pin in bf:EnumerateAllPins() do
        if pin.UpdateAppearanceData and pin.dataProvider then
            if bf.groupMembersDataProvider and bf.groupMembersDataProvider.SetUnitPinSize then
                Try(bf.groupMembersDataProvider.SetUnitPinSize, bf.groupMembersDataProvider, "player", self.db.arrow)
            end
            local sizes = pin.dataProvider.GetUnitPinSizesTable and pin.dataProvider:GetUnitPinSizesTable()
            if sizes then sizes.party, sizes.raid = self.db.group, self.db.group end
            if pin.SynchronizePinSizes then Try(pin.SynchronizePinSizes, pin) end
        end
    end
end

local function SaveBF()
    local p, _, rp, x, y = bf:GetPoint(1)
    if p then B.db.point = { p, rp, x, y } end
end

local function SetupBattlefield()
    if bf then return end
    if not _G.BattlefieldMapFrame then
        local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        if load then Try(load, "Blizzard_BattlefieldMap") end
    end
    bf = _G.BattlefieldMapFrame
    if not bf then return end
    bf:SetMovable(true)
    bf:SetClampedToScreen(true)
    if bf.SetUserPlaced then bf:SetUserPlaced(true) end
    if bf.SetDontSavePosition then bf:SetDontSavePosition(true) end
    local sc = bf.ScrollContainer
    sc:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and (IsAltKeyDown() or not B.db.locked) and not IsShiftKeyDown() then
            bf.aioMoving = true
            bf:StartMoving()
        end
    end)
    sc:HookScript("OnMouseUp", function()
        if bf.aioMoving then
            bf.aioMoving = nil
            bf:StopMovingOrSizing()
            SaveBF()
        end
    end)
    bf:HookScript("OnShow", function()
        B:Place(); B:ApplySize(); B:ApplyAlpha(); B:ApplyIcons()
    end)

    -- Keep centred on the player, every 2 seconds unless you look around.
    local ticker = CreateFrame("Frame", nil, bf)
    local t = 2
    ticker:SetScript("OnUpdate", function(_, dt)
        if not (B.enabled and B.db.center) then return end
        t = t + dt
        if t < 2 then return end
        t = 0
        if sc.IsPanning and sc:IsPanning() then return end
        if IsShiftKeyDown() then return end
        local ok, pos = false, nil
        if bf.mapID then ok, pos = pcall(C_Map.GetPlayerMapPosition, bf.mapID, "player") end
        if ok and pos and pos.x and sc.CalculateScrollExtentsAtScale and sc.SetPanTarget then
            local minX, maxX, minY, maxY = sc:CalculateScrollExtentsAtScale(sc:GetCanvasScale())
            local x = math.min(maxX, math.max(minX, pos.x))
            local y = math.min(maxY, math.max(minY, pos.y))
            sc:SetPanTarget(x, y)
        end
    end)

    B:Place(); B:ApplySize(); B:ApplyAlpha(); B:ApplyIcons()
end

function B:OnEnable()
    if InCombatLockdown() then self.later = true return end
    SetupBattlefield()
end

function B:OnSettingChanged(key)
    if not bf then return end
    if key == "size" then self:ApplySize()
    elseif key == "alpha" then self:ApplyAlpha()
    elseif key == "arrow" or key == "group" then self:ApplyIcons() end
end

B:On("PLAYER_REGEN_ENABLED", function()
    if B.later then B.later = nil; SetupBattlefield() end
end)
