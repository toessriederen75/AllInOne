-- AllInOne: a round button on the edge of the minimap, in the classic golden
-- ring like the other minimap buttons. Left click opens
-- the options, right click the bags; drag it around the minimap.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Minimap button"]      = "Minikarten-Knopf"
    L["A round button on the minimap for the options and the bags."] =
        "Ein runder Knopf an der Minikarte für die Optionen und die Taschen."
    L["A round button on the edge of the minimap. Left click opens the options, right click the bags. Drag it to move it around the minimap."] =
        "Ein runder Knopf am Rand der Minikarte. Linksklick öffnet die Optionen, Rechtsklick die Taschen. Zum Verschieben um die Minikarte herum ziehen."
    L["Left click: options"]  = "Linksklick: Optionen"
    L["Right click: bags"]    = "Rechtsklick: Taschen"
    L["Drag: move"]           = "Ziehen: verschieben"
    L["Lock position"]        = "Position sperren"
    L["Reset position"]       = "Position zurücksetzen"
end

local DEFAULT_ANGLE = 210

local M = AIO:NewModule("minimap", {
    title    = L["Minimap button"],
    short    = L["A round button on the minimap for the options and the bags."],
    desc     = L["A round button on the edge of the minimap. Left click opens the options, right click the bags. Drag it to move it around the minimap."],
    category = "display",
    default  = true,
    defaults = { angle = DEFAULT_ANGLE, lock = false },
    options  = {
        { type = "toggle", key = "lock", label = L["Lock position"] },
        { type = "button", label = L["Reset position"], func = function(m)
            m.db.angle = DEFAULT_ANGLE
            m:Position()
        end },
    },
})

local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\logo"   -- the AIO monogram
-- Blizzard look: a version drawn for the small minimap size (big letters, no ring).
if AIO.Style.blizzard then ICON = ICON .. "_minimap" end
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SIZE = 31     -- the size every classic minimap button has

local button

function M:Position()
    if not button then return end
    local minimap = _G.Minimap
    local angle = math.rad(self.db.angle or DEFAULT_ANGLE)
    local x, y = math.cos(angle), math.sin(angle)
    local w = (minimap:GetWidth() or 140) / 2
    local h = (minimap:GetHeight() or 140) / 2
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- push the point out to the edge of the square
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
        x, y = x * (w + 6), y * (h + 6)
    else
        x, y = x * (w + 10), y * (h + 10)
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", minimap, "CENTER", x, y)
end

local function Drag(self)
    local minimap = _G.Minimap
    local mx, my = minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = minimap:GetEffectiveScale() or 1
    if not (mx and px) then return end
    px, py = px / scale, py / scale
    local atan2 = math.atan2 or function(yy, xx) return math.atan(yy, xx) end
    M.db.angle = math.deg(atan2(py - my, px - mx)) % 360
    M:Position()
end

local function ShowTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(AIO.title, C.accent[1], C.accent[2], C.accent[3])
    GameTooltip:AddLine(L["Left click: options"], 1, 1, 1)
    if not ns.lite then GameTooltip:AddLine(L["Right click: bags"], 1, 1, 1) end
    if not M.db.lock then GameTooltip:AddLine(L["Drag: move"], C.muted[1], C.muted[2], C.muted[3]) end
    GameTooltip:Show()
end

local function Build()
    local minimap = _G.Minimap
    button = CreateFrame("Button", "AllInOneMinimapButton", minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(false)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- The classic look of the other minimap buttons: dark disc, our icon,
    -- golden ring on top.
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("TOPLEFT", 4, -4)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ICON)
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", 6, -6)
    if button.icon.SetMask then pcall(button.icon.SetMask, button.icon, MASK) end

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetSize(53, 53)
    button.border:SetPoint("TOPLEFT")

    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(0.7, 0.7, 0.7) end)
    button:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(1, 1, 1) end)
    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" and not ns.lite then
            AIO:Toggle("inventory")
        else
            AIO:OpenOptions()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        if M.db.lock and not IsAltKeyDown() then return end
        self.dragging = true
        GameTooltip_Hide()
        self:SetScript("OnUpdate", Drag)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        self.icon:SetVertexColor(1, 1, 1)
    end)
    M.button = button
end

function M:OnEnable()
    if not _G.Minimap then return end
    if not button then Build() end
    self:Position()
    button:Show()
end

function M:OnDisable()
    if button then
        button:SetScript("OnUpdate", nil)
        button:Hide()
    end
end

function M:OnSettingChanged()
    self:Position()
end
