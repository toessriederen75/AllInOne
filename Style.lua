-- AllInOne: the look. One flat, dark style for every window the addon draws,
-- built from plain textures so it does not depend on Blizzard templates.
--
--   AIO.Style.color     the palette
--   AIO.Style.Flat(f)   dark background + 1px border on any frame
--   AIO.Style.Button / Check / Slider / Edit / Dropdown / Scroll / Icon
--
-- Every widget returns a frame; values are read and written through the
-- callbacks given to it, so the widgets know nothing about settings.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

local Style = {}
AIO.Style = Style

local WHITE = "Interface\\Buttons\\WHITE8x8"
Style.WHITE = WHITE

Style.color = {
    bg       = { 0.05, 0.05, 0.06, 0.92 },
    panel    = { 0.10, 0.10, 0.12, 1 },
    panel2   = { 0.14, 0.14, 0.17, 1 },
    hover    = { 0.20, 0.20, 0.24, 1 },
    border   = { 0, 0, 0, 1 },
    line     = { 0.22, 0.22, 0.26, 1 },
    text     = { 0.92, 0.92, 0.94 },
    muted    = { 0.58, 0.58, 0.63 },
    accent   = { 0.25, 0.62, 1.00 },
    good     = { 0.30, 0.85, 0.40 },
    bad      = { 0.95, 0.30, 0.30 },
    warn     = { 1.00, 0.75, 0.20 },
}

--- The accent is the player's class colour, once it is known.
function Style:UseClassAccent()
    if self.blizzard then return end   -- the modern look keeps Blizzard's gold
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then self.color.accent = { c.r, c.g, c.b } end
end

-- ---------------------------------------------------------------------------
-- Fonts
-- ---------------------------------------------------------------------------

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local fonts = {}

function Style.Font(size, flags)
    local key = size .. (flags or "")
    if not fonts[key] then
        local f = CreateFont("AllInOneFont" .. size .. (flags or ""):gsub("%W", ""))
        f:SetFont(FONT, size, flags or "")
        f:SetShadowColor(0, 0, 0, 0.8)
        f:SetShadowOffset(1, -1)
        fonts[key] = f
    end
    return fonts[key]
end

function Style.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFontObject(Style.Font(size or 12))
    local c = color or Style.color.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH("LEFT")
    return fs
end

-- ---------------------------------------------------------------------------
-- Flat frames
-- ---------------------------------------------------------------------------

--- Gives a frame a flat background and a 1px border. Returns the frame.
-- A 1px edge must be one real screen pixel. At UI scales below 1, a plain
-- "1" is less than a pixel and some edges round away to nothing.
local function EdgeSize(f)
    local scale = f.GetEffectiveScale and f:GetEffectiveScale() or 1
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, scale, 1)
    end
    local ph = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
    if ph and ph > 0 and scale > 0 then return math.max(1, 768 / ph / scale) end
    return 1
end

local function SizeEdges(f)
    local e, px = f.aioEdges, EdgeSize(f)
    if f.aioEdgePx == px then return end
    f.aioEdgePx = px
    e[1]:SetHeight(px); e[2]:SetHeight(px); e[3]:SetWidth(px); e[4]:SetWidth(px)
end

function Style.Flat(f, bg, border)
    bg = bg or Style.color.bg
    border = border or Style.color.border
    if not f.aioBg then
        f.aioBg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f.aioBg:SetTexture(WHITE)
        f.aioBg:SetAllPoints()
        f.aioEdges = {}
        for i = 1, 4 do
            local t = f:CreateTexture(nil, "BORDER", nil, 7)
            t:SetTexture(WHITE)
            -- A one-pixel line that lies between two screen pixels would be
            -- rounded away to nothing on one side; without snapping it is
            -- always drawn.
            if t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
            f.aioEdges[i] = t
        end
        local e = f.aioEdges
        e[1]:SetPoint("TOPLEFT");     e[1]:SetPoint("TOPRIGHT");    e[1]:SetHeight(1)
        e[2]:SetPoint("BOTTOMLEFT");  e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
        e[3]:SetPoint("TOPLEFT");     e[3]:SetPoint("BOTTOMLEFT");  e[3]:SetWidth(1)
        e[4]:SetPoint("TOPRIGHT");    e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
        -- The real pixel size is known once the frame is on screen.
        if f.HookScript then f:HookScript("OnShow", SizeEdges) end
    end
    f.aioBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
    Style.SetBorder(f, border[1], border[2], border[3], border[4] or 1)
    return f
end

function Style.SetBorder(f, r, g, b, a)
    if not f.aioEdges then return end
    SizeEdges(f)
    for _, t in ipairs(f.aioEdges) do t:SetVertexColor(r, g, b, a or 1) end
end

function Style.SetBackground(f, r, g, b, a)
    if f.aioBg then f.aioBg:SetVertexColor(r, g, b, a or 1) end
end

--- A thin horizontal line.
function Style.Line(parent, color)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    local c = color or Style.color.line
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    t:SetHeight(1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
    return t
end

-- ---------------------------------------------------------------------------
-- Modern Blizzard look (a build asks for it with ns.ui = "blizzard"): drawn
-- after Blizzard's current frames (backpack, dialogs): slate background,
-- thin bronze bevel with diamond corners, dark brown title band with a gold
-- title, a round portrait, dark insets, red buttons with a bronze edge.
-- Everything is drawn from plain textures and the pictures in Media\ui, so it
-- looks the same whatever templates the game has.
-- ---------------------------------------------------------------------------

local function HasTemplate(name)
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo) then return false end
    local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
    return ok and info ~= nil
end
Style.HasTemplate = HasTemplate

local BLIZZ = ns.ui == "blizzard"
Style.blizzard = BLIZZ
Style.edge = BLIZZ and 8 or 1      -- from a window's edge to its content
Style.gold = { 1, 0.82, 0 }
Style.popupPad = 1
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\ui\\"
Style.MEDIA = MEDIA

local BRONZE_L = { 0.76, 0.63, 0.51 }
local BRONZE   = { 0.59, 0.46, 0.35 }
local BRONZE_D = { 0.47, 0.38, 0.31 }
local DARK     = { 0.055, 0.04, 0.03 }
Style.bronze = BRONZE

if BLIZZ then
    local c = Style.color
    c.bg     = { 0.22, 0.24, 0.27, 0.97 }
    c.panel  = { 0.14, 0.157, 0.184, 1 }
    c.panel2 = { 0.085, 0.10, 0.118, 1 }
    c.hover  = { 0.30, 0.25, 0.16, 1 }
    c.border = { 0.04, 0.04, 0.05, 1 }
    c.line   = { 0.40, 0.33, 0.25, 1 }
    c.text   = { 0.93, 0.93, 0.93 }
    c.muted  = { 0.66, 0.66, 0.68 }
    c.accent = { 1, 0.82, 0 }
end

--- A vertical colour run on a texture, on old and new clients.
local function Gradient(t, top, bottom)
    t:SetTexture(WHITE)
    if t.SetGradient and CreateColor then
        local ok = pcall(t.SetGradient, t, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
        if ok then return t end
    end
    if t.SetGradientAlpha then
        t:SetGradientAlpha("VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4] or 1,
                           top[1], top[2], top[3], top[4] or 1)
    else
        t:SetVertexColor((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, top[4] or 1)
    end
    return t
end
Style.Gradient = Gradient

local function Pixel(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
    return t
end

--- A one-unit rectangle outline `inset` units inside the frame.
local function Ring(f, inset, color, layer, sub)
    local e = {}
    for i = 1, 4 do
        local t = Pixel(f:CreateTexture(nil, layer or "BORDER", nil, sub or 0))
        t:SetTexture(WHITE)
        t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        e[i] = t
    end
    e[1]:SetPoint("TOPLEFT", inset, -inset);    e[1]:SetPoint("TOPRIGHT", -inset, -inset);   e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT", inset, inset);  e[2]:SetPoint("BOTTOMRIGHT", -inset, inset); e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT", inset, -inset);    e[3]:SetPoint("BOTTOMLEFT", inset, inset);   e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT", -inset, -inset);  e[4]:SetPoint("BOTTOMRIGHT", -inset, inset); e[4]:SetWidth(1)
    return e
end
Style.Ring = Ring

local function HLine(f, y, color, sub)
    local t = Pixel(f:CreateTexture(nil, "BORDER", nil, sub or 1))
    t:SetTexture(WHITE)
    t:SetVertexColor(color[1], color[2], color[3], 1)
    t:SetPoint("TOPLEFT", 4, y)
    t:SetPoint("TOPRIGHT", -4, y)
    t:SetHeight(1)
    return t
end

Style.headerH = 28   -- title band height including the top border

--- A window frame: slate background, bronze bevel, diamond corners and
--- (unless opts.header == false) the dark title band. Without the modern
--- look: Flat.
function Style.Chrome(f, opts)
    if not BLIZZ then return Style.Flat(f) end
    if f.aioChrome then return f end
    opts = opts or {}
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Gradient(bg, { 0.245, 0.26, 0.29, 0.98 }, { 0.17, 0.195, 0.225, 0.98 })
    if opts.header ~= false then
        local h = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        h:SetPoint("TOPLEFT", 4, -4)
        h:SetPoint("TOPRIGHT", -4, -4)
        h:SetHeight(24)
        Gradient(h, { 0.19, 0.12, 0.07, 1 }, { 0.12, 0.075, 0.04, 1 })
        HLine(f, -28, BRONZE_L)
        HLine(f, -29, BRONZE_D)
        HLine(f, -30, { 0.10, 0.07, 0.05 })
    end
    Ring(f, 0, DARK)
    Ring(f, 1, BRONZE_L)
    Ring(f, 2, BRONZE)
    Ring(f, 3, BRONZE_D)
    Ring(f, 4, { 0.10, 0.075, 0.05 })
    for _, p in ipairs({ { "TOPLEFT", 2, -2 }, { "TOPRIGHT", -2, -2 }, { "BOTTOMLEFT", 2, 2 }, { "BOTTOMRIGHT", -2, 2 } }) do
        local d = f:CreateTexture(nil, "OVERLAY", nil, 7)
        d:SetTexture(MEDIA .. "diamond")
        d:SetSize(12, 12)
        d:SetPoint("CENTER", f, p[1], p[2], p[3])
    end
    f.aioChrome = bg
    return f
end

--- A round portrait over the top-left corner, like Blizzard's backpack.
function Style.Portrait(f, texture)
    local p = CreateFrame("Frame", nil, f)
    p:SetSize(54, 54)
    p:SetPoint("TOPLEFT", -12, 12)
    p:SetFrameLevel(f:GetFrameLevel() + 20)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(44, 44)
    p.icon:SetPoint("CENTER")
    p.icon:SetTexture(texture)
    if p.icon.SetMask then pcall(p.icon.SetMask, p.icon, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") end
    p.ring = p:CreateTexture(nil, "OVERLAY")
    p.ring:SetTexture(MEDIA .. "ring")
    p.ring:SetAllPoints()
    f.aioPortrait = p
    return p
end

--- An inner area (lists, money bar, content): dark, with a dark edge.
function Style.Inset(f, bg, border)
    if not BLIZZ then return Style.Flat(f, bg, border) end
    Style.Flat(f, { 0.10, 0.115, 0.135, 0.96 }, { 0.03, 0.03, 0.035, 1 })
    if not f.aioInsetLine then
        local t = Pixel(f:CreateTexture(nil, "BORDER", nil, 6))
        t:SetTexture(WHITE)
        t:SetVertexColor(0.35, 0.36, 0.40, 0.6)
        t:SetPoint("BOTTOMLEFT", 2, -1)
        t:SetPoint("BOTTOMRIGHT", -2, -1)
        t:SetHeight(1)
        f.aioInsetLine = t
    end
    return f
end

--- Menus and small bars: dark, with a bronze edge.
function Style.Popup(f, bg, border)
    if not BLIZZ then return Style.Flat(f, bg, border) end
    return Style.Flat(f, { 0.075, 0.085, 0.10, 0.97 }, BRONZE)
end

--- The red square close button with the golden X.
function Style.CloseX(f, onClick)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 20)
    b:SetNormalTexture(MEDIA .. "close")
    b:SetPushedTexture(MEDIA .. "close")
    local pushed = b:GetPushedTexture()
    if pushed then pushed:SetVertexColor(0.7, 0.7, 0.7) end
    b:SetHighlightTexture(MEDIA .. "close", "ADD")
    local hl = b:GetHighlightTexture()
    if hl then hl:SetAlpha(0.35) end
    b:SetPoint("TOPRIGHT", -7, -6)
    b:SetFrameLevel(f:GetFrameLevel() + 10)
    b:SetScript("OnClick", onClick or function() f:Hide() end)
    return b
end
Style.BlizzardClose = function(f, onClick)
    if BLIZZ then return Style.CloseX(f, onClick) end
    local b = Style.CloseButton(f, onClick)
    b:SetPoint("TOPRIGHT", -4, -4)
    return b
end

--- A title in the band, gold and centred.
function Style.Title(f, text)
    local t = Style.Text(f, 13, Style.gold)
    t:SetPoint("TOP", 0, -10)
    t:SetText(text or "")
    return t
end

--- A movable window with a title bar and a close button.
function Style.Window(name, width, height, title)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if BLIZZ then
        Style.Chrome(f)
        f.titleBar = CreateFrame("Frame", nil, f)
        f.titleBar:SetPoint("TOPLEFT", 4, -4)
        f.titleBar:SetPoint("TOPRIGHT", -4, -4)
        f.titleBar:SetHeight(24)
        f.titleText = Style.Text(f.titleBar, 13, Style.gold)
        f.titleText:SetPoint("CENTER", 0, 0)
        f.titleText:SetText(title or "")
        f.close = Style.CloseX(f)
        if name then tinsert(UISpecialFrames, name) end
        f:Hide()
        return f
    end
    Style.Flat(f)

    f.titleBar = CreateFrame("Frame", nil, f)
    f.titleBar:SetPoint("TOPLEFT", 1, -1)
    f.titleBar:SetPoint("TOPRIGHT", -1, -1)
    f.titleBar:SetHeight(26)
    Style.Flat(f.titleBar, Style.color.panel, { 0, 0, 0, 0 })

    f.titleText = Style.Text(f.titleBar, 13)
    f.titleText:SetPoint("LEFT", 10, 0)
    f.titleText:SetText(title or "")

    f.close = Style.CloseButton(f)
    f.close:SetPoint("TOPRIGHT", -4, -4)
    if name then tinsert(UISpecialFrames, name) end
    f:Hide()
    return f
end

function Style.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b.text = Style.Text(b, 14, Style.color.muted)
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText("×")
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(Style.color.bad)) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(Style.color.muted)) end)
    b:SetScript("OnClick", onClick or function(self) self:GetParent():Hide() end)
    return b
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

local FlatButton

local function TipEnter(self)
    if self.tip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

function Style.Button(parent, text, width, height, onClick)
    if not BLIZZ then return FlatButton(parent, text, width, height, onClick) end
    -- Blizzard's red button: dark red run, bronze edge, gold text.
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 2, -2)
    b.bg:SetPoint("BOTTOMRIGHT", -2, 2)
    local function paint(on)
        if on then Gradient(b.bg, { 0.62, 0.11, 0.06, 1 }, { 0.36, 0.04, 0.02, 1 })
        else Gradient(b.bg, { 0.30, 0.28, 0.27, 1 }, { 0.18, 0.17, 0.16, 1 }) end
    end
    paint(true)
    Ring(b, 0, { 0.08, 0.03, 0.01 })
    Ring(b, 1, BRONZE)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetPoint("TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", -2, 2)
    hl:SetVertexColor(1, 0.75, 0.35, 0.18)
    hl:SetBlendMode("ADD")
    b.text = Style.Text(b, 12, Style.gold)
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.text:SetPoint("CENTER", 1, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnEnter", TipEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnDisable", function(self) paint(false); self.text:SetTextColor(unpack(Style.color.muted)) end)
    b:SetScript("OnEnable", function(self) paint(true); self.text:SetTextColor(unpack(Style.gold)) end)
    function b:SetLabel(t) self.text:SetText(t) end
    function b:SetText(t) self.text:SetText(t) end
    return b
end

function FlatButton(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    Style.Flat(b, Style.color.panel2, Style.color.line)
    b.text = Style.Text(b, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            Style.SetBackground(self, unpack(Style.color.hover))
            Style.SetBorder(self, unpack(Style.color.accent))
        end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBackground(self, unpack(Style.color.panel2))
        Style.SetBorder(self, unpack(Style.color.line))
        GameTooltip_Hide()
    end)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnDisable", function(self) self.text:SetTextColor(unpack(Style.color.muted)) end)
    b:SetScript("OnEnable", function(self) self.text:SetTextColor(unpack(Style.color.text)) end)
    function b:SetLabel(t) self.text:SetText(t) end
    return b
end

--- A square icon button with a 1px border, for headers and side bars.
function Style.Icon(parent, icon, size, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 22, size or 22)
    Style.Flat(b, Style.color.panel, Style.color.line)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexture(icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.tip = tip
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if onClick then onClick(self, button) end
    end)
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self, unpack(Style.color.accent))
        local text = type(self.tip) == "function" and self.tip(self) or self.tip
        if text then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self, unpack(self.active and Style.color.accent or Style.color.line))
        GameTooltip_Hide()
    end)
    --- Marks the button as the chosen one of a group (filters, tabs).
    function b:SetActive(active)
        self.active = active and true or false
        Style.SetBorder(self, unpack(self.active and Style.color.accent or Style.color.line))
        Style.SetBackground(self, unpack(self.active and Style.color.hover or Style.color.panel))
    end
    return b
end

-- ---------------------------------------------------------------------------
-- Check box: a small square that fills with the accent colour
-- ---------------------------------------------------------------------------

function Style.Check(parent, label, get, set, tip)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(20)
    f.box = CreateFrame("Frame", nil, f)
    f.box:SetSize(16, 16)
    f.box:SetPoint("LEFT", 0, 0)
    if BLIZZ then
        -- Blizzard's check box: dark square, bronze edge, golden tick.
        Style.Flat(f.box, Style.color.panel2, BRONZE)
        f.mark = f.box:CreateTexture(nil, "ARTWORK")
        f.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        f.mark:SetSize(22, 22)
        f.mark:SetPoint("CENTER", 1, 1)
    else
        Style.Flat(f.box, Style.color.panel2, Style.color.line)
        f.mark = f.box:CreateTexture(nil, "ARTWORK")
        f.mark:SetTexture(WHITE)
        f.mark:SetPoint("TOPLEFT", 3, -3)
        f.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    f.label = Style.Text(f, 12)
    f.label:SetPoint("LEFT", f.box, "RIGHT", 8, 0)
    f.label:SetText(label or "")
    f:SetWidth(math.max(60, f.label:GetStringWidth() + 30))
    f.tip = tip

    function f:Update()
        local on = get() and true or false
        local enabled = not self.pageOff and (not self.disabledFn or not self.disabledFn())
        if BLIZZ then
            local v = enabled and 1 or 0.5
            self.mark:SetVertexColor(v, v, v)
            self.mark:SetDesaturated(not enabled)
        else
            self.mark:SetVertexColor(unpack(enabled and Style.color.accent or Style.color.muted))
        end
        self.mark:SetShown(on)
        self.label:SetTextColor(unpack(enabled and Style.color.text or Style.color.muted))
        self:EnableMouse(enabled)
    end
    f:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    end)
    f:SetScript("OnEnter", function(self)
        Style.SetBorder(self.box, unpack(Style.color.accent))
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        Style.SetBorder(self.box, unpack(BLIZZ and BRONZE or Style.color.line))
        GameTooltip_Hide()
    end)
    f:SetScript("OnShow", f.Update)
    f:Update()
    return f
end

--- A larger on/off switch, used for turning whole modules on and off.
function Style.Switch(parent, get, set)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(38, 18)
    Style.Flat(f, Style.color.panel2, Style.color.line)
    f.knob = f:CreateTexture(nil, "ARTWORK")
    f.knob:SetTexture(WHITE)
    f.knob:SetSize(16, 14)
    function f:Update()
        local on = get() and true or false
        self.knob:ClearAllPoints()
        if on then
            self.knob:SetPoint("RIGHT", -2, 0)
            self.knob:SetVertexColor(1, 1, 1, 1)
            Style.SetBackground(self, unpack(Style.color.accent))
        else
            self.knob:SetPoint("LEFT", 2, 0)
            self.knob:SetVertexColor(unpack(Style.color.muted))
            Style.SetBackground(self, unpack(Style.color.panel2))
        end
    end
    f:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    end)
    f:SetScript("OnShow", f.Update)
    f:Update()
    return f
end

-- ---------------------------------------------------------------------------
-- Slider
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Alt + drag: any button can move the frame it belongs to, locked or not.
-- On secure buttons a click right after a drag is swallowed (a secure snippet
-- cancels it), so moving never casts anything.
-- ---------------------------------------------------------------------------

local dragHandler
local SWALLOW = [[ if self:GetAttribute("aioDragged") then self:SetAttribute("aioDragged", nil) return false end ]]

--- mover: the frame to move, or a function returning it; onStop(frame) saves.
function Style.AltDrag(b, mover, onStop)
    b:RegisterForDrag("LeftButton")
    local secure = b.IsProtected and b:IsProtected()
    if secure and SecureHandlerWrapScript and not InCombatLockdown() then
        dragHandler = dragHandler or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        SecureHandlerWrapScript(b, "OnClick", dragHandler, SWALLOW)
    end
    b:HookScript("OnDragStart", function(self)
        if not IsAltKeyDown() or InCombatLockdown() then return end
        local f = type(mover) == "function" and mover() or mover
        if not f then return end
        if secure then self:SetAttribute("aioDragged", true) end
        self.aioMoving = f
        GameTooltip_Hide()
        f:StartMoving()
    end)
    b:HookScript("OnDragStop", function(self)
        local f = self.aioMoving
        if not f then return end
        self.aioMoving = nil
        f:StopMovingOrSizing()
        self.aioDragEnd = GetTime()
        if onStop then onStop(f) end
        if secure then
            C_Timer.After(0.3, function()
                if not InCombatLockdown() then self:SetAttribute("aioDragged", nil) end
            end)
        end
    end)
end

--- True right after an Alt-drag ended on this button (to skip its click).
function Style.JustDragged(b)
    return b.aioDragEnd and GetTime() - b.aioDragEnd < 0.3
end

--- A slider with - and + buttons and a field to type the value. The mouse
--- wheel is left alone on purpose: it scrolls the page, never the value.
function Style.Slider(parent, label, min, max, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(240, 38)
    f.label = Style.Text(f, 12)
    f.label:SetPoint("TOPLEFT", 0, 0)
    f.label:SetText(label or "")

    -- Percent sliders (0..1 shown as "35%") are typed in percent.
    local scale = (fmt and max <= 1 and tostring(fmt(max)):find("%%")) and 100 or 1

    local function clamp(v)
        v = math.min(max, math.max(min, v))
        v = min + math.floor((v - min) / step + 0.5) * step
        if step < 1 then v = tonumber(("%.2f"):format(v)) end
        return v
    end

    local minus = FlatButton(f, "-", 20, 20)
    minus:SetPoint("BOTTOMLEFT", 0, 0)
    local box = Style.Edit(f, 54)
    box:SetHeight(20)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(2, 2, 0, 0)
    local plus = FlatButton(f, "+", 20, 20)
    plus:SetPoint("RIGHT", box, "LEFT", -4, 0)

    local s = CreateFrame("Slider", nil, f)
    s:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    s:SetPoint("RIGHT", plus, "LEFT", -6, 0)
    s:SetHeight(12)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(false)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetVertexColor(unpack(Style.color.panel2))
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetTexture(WHITE)
    s.fill:SetVertexColor(unpack(Style.color.accent))
    s.fill:SetPoint("LEFT")
    s.fill:SetHeight(4)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    if BLIZZ then
        thumb:SetTexture(MEDIA .. "diamond")
        thumb:SetSize(14, 14)
        track:SetHeight(6)
        s.fill:SetHeight(4)
    else
        thumb:SetTexture(WHITE)
        thumb:SetVertexColor(1, 1, 1, 1)
        thumb:SetSize(8, 12)
    end
    s:SetThumbTexture(thumb)
    f.slider, f.minus, f.plus, f.box = s, minus, plus, box

    local current
    local function show(v)
        current = v
        if not box:HasFocus() then box:SetText(fmt and fmt(v) or tostring(v)) end
        local w = s:GetWidth() or 0
        s.fill:SetWidth(math.max(1, w * (v - min) / math.max(0.0001, max - min)))
    end
    local function apply(v)
        v = clamp(v)
        s.busy = true
        s:SetValue(v)
        s.busy = false
        show(v)
        set(v)
    end
    function f:Update()
        s.busy = true
        local v = get()
        s:SetValue(v)
        s.busy = false
        show(v)
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = clamp(v)
        show(v)
        if not self.busy then set(v) end
    end)
    s:SetScript("OnSizeChanged", function() show(get()) end)

    -- - and +: one step per click, repeating while held.
    local function stepper(b, dir)
        b:SetScript("OnClick", nil)
        b:SetScript("OnMouseDown", function(self)
            apply((current or get()) + dir * step)
            self.wait, self.held = 0.4, true
        end)
        b:SetScript("OnMouseUp", function(self) self.held = false end)
        b:HookScript("OnHide", function(self) self.held = false end)
        b:SetScript("OnUpdate", function(self, dt)
            if not self.held then return end
            self.wait = self.wait - dt
            if self.wait <= 0 then
                self.wait = 0.06
                apply((current or get()) + dir * step)
            end
        end)
    end
    stepper(minus, -1)
    stepper(plus, 1)

    -- Typed value: plain number (in percent for percent sliders), comma or point.
    box:SetScript("OnEditFocusGained", function(self)
        local v = (current or get()) * scale
        self:SetText((("%.2f"):format(v):gsub("%.?0+$", "")))
        self:HighlightText()
        Style.SetBorder(self, unpack(Style.color.accent))
    end)
    local function commit(self)
        local n = tonumber((self:GetText() or ""):gsub(",", "."):match("%-?[%d%.]+") or "")
        if n then apply(n / scale) end
    end
    box:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self.cancel = true; self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        Style.SetBorder(self, unpack(Style.color.line))
        if not self.cancel then commit(self) end
        self.cancel = nil
        show(current or get())
    end)

    f:SetScript("OnShow", f.Update)
    f:Update()
    return f
end

-- ---------------------------------------------------------------------------
-- Text field
-- ---------------------------------------------------------------------------

function Style.Edit(parent, width, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 160, 22)
    e:SetAutoFocus(false)
    e:SetFontObject(Style.Font(12))
    e:SetTextInsets(6, 6, 0, 0)
    if BLIZZ then
        Style.Flat(e, { 0.05, 0.058, 0.07, 1 }, Style.color.line)
    else
        Style.Flat(e, Style.color.panel2, Style.color.line)
    end
    e.hint = Style.Text(e, 12, Style.color.muted)
    e.hint:SetPoint("LEFT", 6, 0)
    e.hint:SetText(placeholder or "")
    local function hint(self) self.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end
    e:SetScript("OnEditFocusGained", function(self) self.hint:Hide(); Style.SetBorder(self, unpack(Style.color.accent)) end)
    e:SetScript("OnEditFocusLost", function(self) hint(self); Style.SetBorder(self, unpack(Style.color.line)) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:HookScript("OnTextChanged", hint)
    return e
end

-- ---------------------------------------------------------------------------
-- Pop-up menu and drop-down
-- ---------------------------------------------------------------------------

--- items: { { text, checked, func, icon }, ... }
--- Long lists show MENU_ROWS at a time and scroll with the mouse wheel.
local MENU_ROWS, ROW_H = 20, 20

local function MenuRow(m, i)
    local row = CreateFrame("Button", nil, m)
    row:SetHeight(ROW_H)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetTexture(WHITE)
    row.hl:SetAllPoints()
    row.hl:SetVertexColor(unpack(Style.color.hover))
    row.hl:Hide()
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(WHITE)
    row.mark:SetSize(3, 14)
    row.mark:SetPoint("LEFT", 2, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 9, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = Style.Text(row, 12)
    row:SetScript("OnEnter", function(self) self.hl:Show() end)
    row:SetScript("OnLeave", function(self) self.hl:Hide() end)
    row:SetScript("OnClick", function(self)
        local item = self.item
        m:Hide()
        if item and item.func then item.func() end
    end)
    local pad = Style.popupPad
    row:SetPoint("TOPLEFT", pad, -pad - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", m, "RIGHT", -pad, 0)
    m.rows[i] = row
    return row
end

local function MenuFill(m)
    local items, offset = m.items, m.offset
    for i = 1, math.min(#items, MENU_ROWS) do
        local row = m.rows[i] or MenuRow(m, i)
        local item = items[offset + i]
        row.item = item
        row.text:SetText(item.text)
        row.text:ClearAllPoints()
        if item.icon then
            row.icon:SetTexture(item.icon)
            row.icon:Show()
            row.text:SetPoint("LEFT", 30, 0)
        else
            row.icon:Hide()
            row.text:SetPoint("LEFT", 10, 0)
        end
        row.mark:SetVertexColor(unpack(Style.color.accent))
        row.mark:SetShown(item.checked and true or false)
        row:Show()
    end
    for i = #items + 1, #m.rows do m.rows[i]:Hide() end
    -- Thin bar that shows where in a long list we are.
    local extra = #items - MENU_ROWS
    if extra > 0 then
        local h = m:GetHeight() - 2 * Style.popupPad
        local thumbH = math.max(16, h * MENU_ROWS / #items)
        m.thumb:SetHeight(thumbH)
        m.thumb:ClearAllPoints()
        m.thumb:SetPoint("TOPRIGHT", -Style.popupPad, -Style.popupPad - (h - thumbH) * offset / extra)
        m.thumb:Show()
    else
        m.thumb:Hide()
    end
end

function Style.Menu(anchor, items)
    local m = Style.menu
    if not m then
        m = CreateFrame("Frame", "AllInOneMenu", UIParent)
        -- Menus open from dialogs too, so they live on the topmost layer.
        m:SetFrameStrata("TOOLTIP")
        m:SetToplevel(true)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m:EnableMouseWheel(true)
        Style.Popup(m, Style.color.panel, Style.color.line)
        m.rows = {}
        m.thumb = m:CreateTexture(nil, "OVERLAY")
        m.thumb:SetTexture(WHITE)
        m.thumb:SetWidth(3)
        m.thumb:SetVertexColor(unpack(Style.color.muted))
        m:SetScript("OnMouseWheel", function(self, delta)
            local max = math.max(0, #self.items - MENU_ROWS)
            local o = math.min(max, math.max(0, self.offset - delta * 3))
            if o ~= self.offset then self.offset = o; MenuFill(self) end
        end)
        tinsert(UISpecialFrames, "AllInOneMenu")
        Style.menu = m
    end
    if m:IsShown() and m.anchor == anchor then m:Hide(); return end
    m.anchor = anchor
    m.items = items
    m.offset = 0
    -- Start with the checked entry in view.
    for i, item in ipairs(items) do
        if item.checked then m.offset = math.max(0, math.min(i - 5, #items - MENU_ROWS)) break end
    end

    local width = math.max(120, anchor:GetWidth() or 0)
    local probe = m.probe or Style.Text(m, 12)
    m.probe = probe
    probe:Hide()
    local hasIcon = false
    for _, item in ipairs(items) do
        probe:SetText(item.text)
        if item.icon then hasIcon = true end
        width = math.max(width, probe:GetStringWidth() + 30)
    end
    if hasIcon then width = width + 20 end
    m:SetSize(width, math.min(#items, MENU_ROWS) * ROW_H + 2 * Style.popupPad)
    MenuFill(m)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    m:Show()
    m:Raise()
end

--- values: { { value = v, label = text }, ... }
function Style.Dropdown(parent, width, values, get, set)
    local b = FlatButton(parent, "", width or 160, 22)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 8, 0)
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    b.arrow:SetSize(12, 12)
    b.arrow:SetPoint("RIGHT", -6, -3)
    b.arrow:SetVertexColor(unpack(Style.color.muted))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon:Hide()
    b.text:SetPoint("RIGHT", -20, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    local function show(self, label, icon)
        self.text:SetText(label)
        self.icon:SetShown(icon ~= nil)
        if icon then self.icon:SetTexture(icon) end
        self.text:SetPoint("LEFT", icon and 24 or 8, 0)
    end
    function b:Update()
        local v = get()
        local list = type(values) == "function" and values() or values
        for _, item in ipairs(list) do
            if item.value == v then show(self, item.label, item.icon) return end
        end
        show(self, b.emptyText and (v == nil or v == "") and b.emptyText or tostring(v or ""), nil)
    end
    b:SetScript("OnClick", function(self)
        local list = type(values) == "function" and values() or values
        local items = {}
        for _, item in ipairs(list) do
            items[#items + 1] = { text = item.label, checked = (item.value == get()), icon = item.icon,
                                  func = function() set(item.value); self:Update() end }
        end
        Style.Menu(self, items)
    end)
    b:SetScript("OnShow", b.Update)
    b:Update()
    return b
end

-- ---------------------------------------------------------------------------
-- Scroll area with a thin bar
-- ---------------------------------------------------------------------------

function Style.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child

    local bar = CreateFrame("Slider", nil, sf)
    bar:SetWidth(4)
    bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 6, 0)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetAllPoints()
    track:SetVertexColor(unpack(Style.color.panel2))
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(unpack(Style.color.line))
    thumb:SetSize(4, 40)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    sf.bar = bar

    function sf:UpdateRange()
        local range = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        if bar:GetValue() > range then bar:SetValue(range) end
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local _, max = bar:GetMinMaxValues()
        bar:SetValue(math.min(max, math.max(0, bar:GetValue() - delta * 40)))
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        self:UpdateRange()
    end)
    function sf:ScrollToTop() bar:SetValue(0) end
    return sf
end
