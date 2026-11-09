-- AllInOne: larger Blizzard windows. The quest log, the profession windows and
-- the trainer become double-wide: the list on the left, as tall as the window,
-- the details on the right. The quest log shows quest levels, the trainer gets
-- a "train all" button.
--
-- Written for AllInOne; the ideas come from Leatrix Plus (no code taken).
--
-- How it works: each window is described once in a table (its list, its rows,
-- its detail pane, its buttons) and one function lays any of them out. The
-- windows are changed once, when they first load; switching a module off again
-- needs a /reload.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

if GetLocale() == "deDE" then
    L["Larger quest log"]        = "Grösseres Questlog"
    L["The quest log as a wide window: quests on the left, as many as fit, the text on the right. With quest levels and a map button."] =
        "Das Questlog als breites Fenster: links die Quests, so viele wie Platz haben, rechts der Text. Mit Queststufen und Kartenknopf."
    L["Larger profession windows"] = "Grössere Berufsfenster"
    L["The profession windows (and enchanting) as wide windows: recipes on the left, as many as fit, the details on the right."] =
        "Die Berufsfenster (auch Verzauberkunst) als breite Fenster: links die Rezepte, so viele wie Platz haben, rechts die Details."
    L["Larger trainer window"]   = "Grösseres Lehrerfenster"
    L["The trainer as a wide window, with a button that learns everything you can afford at once."] =
        "Das Lehrerfenster als breites Fenster, mit einem Knopf, der alles lernt, was du dir leisten kannst."
    L["Switching this on or off takes effect after a /reload."] = "Ein- und Ausschalten wirkt nach einem /reload."
    L["Levels"]                  = "Stufen"
    L["Show quest levels"]       = "Queststufen zeigen"
    L["Show the level in front of every quest, in the list and above the quest text."] =
        "Zeigt die Stufe vor jeder Quest, in der Liste und über dem Questtext."
    L["Show the quest kind"]     = "Questart zeigen"
    L["After the level: + group, D dungeon, H heroic, R raid, P PvP."] =
        "Hinter der Stufe: + Gruppe, D Dungeon, H heroisch, R Schlachtzug, P PvP."
    L["Map button"]              = "Kartenknopf"
    L["A button at the bottom that opens the world map."] = "Ein Knopf unten, der die Weltkarte öffnet."
    L["Map"]                     = "Karte"
    L["Show the train all button"] = "Knopf «Alles lernen» zeigen"
    L["Train all"]               = "Alles lernen"
    L["Learn %d for %s"]         = "%d lernen für %s"
    L["Not enough money for everything: learns what you can afford."] =
        "Nicht genug Geld für alles: lernt, was du dir leisten kannst."
end

local floor, max, min = math.floor, math.max, math.min

-- Size of a widened window and where things go in it.
local WIDE_W, WIDE_H = 700, 540
local DETAIL_X       = 352   -- left edge of the detail pane
local DETAIL_W       = 298
local BOTTOM_PAD     = 44    -- room for the button row
local PARCHMENT      = "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated"

local function Loaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(addon) end
    return IsAddOnLoaded and IsAddOnLoaded(addon)
end

-- ---------------------------------------------------------------------------
-- Generic layout
-- ---------------------------------------------------------------------------

-- Where a point sits inside a w x h box, measured from its top left.
local PX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local PY = { TOPLEFT = 0, TOP = 0, TOPRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }

--- The top-left corner of `r` relative to the top left of `f`, worked out from
--- its first anchor (only when it is anchored to `f`); nil otherwise. Works
--- before anything has been shown, which is when we need it.
local function TopLeftIn(r, f)
    local p, rel, rp, x, y = r:GetPoint(1)
    if not p or (rel ~= f and rel ~= nil) then return end
    local fw, fh = f:GetWidth() or 0, f:GetHeight() or 0
    local w, h = r:GetWidth() or 0, r:GetHeight() or 0
    rp = rp or p
    local left = PX[rp] * fw + (x or 0) - PX[p] * w
    local top = -PY[rp] * fh + (y or 0) + PY[p] * h
    return left, top
end

--- Hides a frame's own artwork (its textures, not its text), so ours shows.
local function HideArt(f)
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
end

local function Inset(f, anchor, r, g, b, a, dx2, file)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
    t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", dx2, -5)
    if file and t:SetTexture(file) ~= false then
        t:SetVertexColor(r, g, b, a)
    else
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(r, g, b, a)
    end
    return t
end

--- New look for a widened window: a dark background, a gold edge and two
--- panes. `light` gives the detail pane a parchment (for dark quest text).
local function Dress(f, s)
    HideArt(f)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    if bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background", true, true) == false then
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.05, 0.05, 0.05, 0.95)
    end
    if bg.SetHorizTile then bg:SetHorizTile(true); bg:SetVertTile(true) end
    local edge = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    edge:SetAllPoints()
    edge:SetFrameLevel(f:GetFrameLevel() or 1)
    if edge.SetBackdrop then
        edge:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32 })
    end
    f.aioListBg = Inset(f, s.listFrame, 0, 0, 0, 0.3, 27)
    if s.light then
        -- A light page for the dark quest text: plain paper colour with a
        -- faint parchment grain on top.
        f.aioDetailBg = Inset(f, s.detailFrame, 0.95, 0.89, 0.74, 1, 27)
        local grain = Inset(f, s.detailFrame, 1, 1, 1, 0.22, 27, PARCHMENT)
        grain:SetDrawLayer("BACKGROUND", 3)
    else
        f.aioDetailBg = Inset(f, s.detailFrame, 0, 0, 0, 0.3, 27)
    end
end

--- The AllInOne look (TBC Anniversary, Style.blizzard): the window gets the
--- same frame as the bags and the options (slate background, bronze edge,
--- dark title band, round portrait, red close button) instead of Blizzard's
--- pictures; the list and the details sit in dark insets, the quest text
--- keeps its light page.
local function Skin(f, s)
    local Style = AIO.Style
    if f.aioSkinned then return end
    f.aioSkinned = true
    -- The window's own picture for the portrait, taken before it is hidden.
    local p = f.portrait or (f.PortraitContainer and f.PortraitContainer.portrait) or _G[s.frame .. "Portrait"]
    local picture = p and p.GetTexture and p:GetTexture()
    HideArt(f)
    for _, k in ipairs({ "NineSlice", "PortraitContainer", "Bg", "TitleBg", "TopTileStreaks" }) do
        local o = f[k]
        if type(o) == "table" then
            if o.SetAlpha then o:SetAlpha(0) end
            if o.Hide and o ~= p then o:Hide() end
        end
    end
    if f.TitleContainer then HideArt(f.TitleContainer) end
    local inset = f.Inset
    if inset then
        HideArt(inset)
        if inset.NineSlice then inset.NineSlice:Hide() end
    end
    Style.Chrome(f)
    local FALLBACK = { QuestLogFrame = "Interface\\QuestFrame\\UI-QuestLog-BookIcon",
                       ClassTrainerFrame = "Interface\\Icons\\INV_Misc_Book_11" }
    local por = Style.Portrait(f, picture or FALLBACK[s.frame] or "Interface\\Icons\\INV_Misc_Book_09")
    -- Blizzard sets its portrait anew each time (the profession's icon, the
    -- trainer's face): ours follows.
    if p then
        if _G.SetPortraitToTexture then
            hooksecurefunc("SetPortraitToTexture", function(t, path)
                if path and (t == p or (type(t) == "string" and _G[t] == p)) then por.icon:SetTexture(path) end
            end)
        end
        if _G.SetPortraitTexture then
            hooksecurefunc("SetPortraitTexture", function(t, unit)
                if unit and (t == p or (type(t) == "string" and _G[t] == p)) then SetPortraitTexture(por.icon, unit) end
            end)
        end
    end

    local title = (s.title and _G[s.title]) or (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
    if title then
        title:SetTextColor(unpack(Style.gold))
        title:ClearAllPoints()
        title:SetPoint("TOP", f, "TOP", 0, -10)
    end
    local close = (s.close and _G[s.close]) or f.CloseButton
    if close then
        local tex = Style.MEDIA .. "close"
        close:SetNormalTexture(tex)
        close:SetPushedTexture(tex)
        local pushed = close:GetPushedTexture()
        if pushed then pushed:SetVertexColor(0.7, 0.7, 0.7) end
        close:SetHighlightTexture(tex, "ADD")
        local hl = close:GetHighlightTexture()
        if hl then hl:SetAlpha(0.35) end
        if close.SetDisabledTexture then close:SetDisabledTexture(tex) end
        close:SetSize(20, 20)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, -6)
        close:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
    end

    -- Dark insets behind the list and the details, like the bags' money bar.
    local function pane(anchor)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
        t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 27, -5)
        t:SetColorTexture(0.10, 0.115, 0.135, 0.96)
        return t
    end
    f.aioListBg = pane(s.listFrame)
    if s.light then
        f.aioDetailBg = Inset(f, s.detailFrame, 0.95, 0.89, 0.74, 1, 27)
        local grain = Inset(f, s.detailFrame, 1, 1, 1, 0.22, 27, PARCHMENT)
        grain:SetDrawLayer("BACKGROUND", 3)
    else
        f.aioDetailBg = pane(s.detailFrame)
    end
    if s.diag then s.diag[#s.diag + 1] = "look: AllInOne frame" end
end

--- Tells Blizzard's panel layout the window's new width. Everything else
--- stays as Blizzard set it, so the window still opens next to others (the
--- profession window beside the auction house, for one).
local function PanelWide(f, name, width)
    if UIPanelWindows then
        local t, old = {}, UIPanelWindows[name]
        if old then
            for k, v in pairs(old) do t[k] = v end
        else
            t.area, t.pushable = "left", 1
        end
        t.width = width
        UIPanelWindows[name] = t
    end
    if f.GetAttribute and f:GetAttribute("UIPanelLayout-defined") then
        f:SetAttribute("UIPanelLayout-width", width)
    end
end

local function Place(name, ...)
    local r = _G[name]
    if r then r:ClearAllPoints(); r:SetPoint(...) end
    return r
end

--- How many rows fit, makes them, and sizes list and detail to match.
local function FitRows(s)
    local f, row1 = s.f, _G[s.row .. "1"]
    local top
    if not s.modern then top = select(2, TopLeftIn(row1, f)) end
    top = top or s.top
    local rowH = row1:GetHeight() or 16
    if rowH < 8 then rowH = 16 end
    local n = floor((top - s.paneBottom) / rowH)
    for i = s.made + 1, n do
        local b = CreateFrame("Button", s.row .. i, f, s.template)
        b:SetID(i)
        b:Hide()
        b:SetPoint("TOPLEFT", _G[s.row .. (i - 1)], "BOTTOMLEFT", 0, 0)
        if s.onNewRow then s.onNewRow(b, i) end
    end
    s.made = max(s.made, n)
    for i = n + 1, s.made do _G[s.row .. i]:Hide() end
    _G[s.count] = n
    local paneTop = s.paneTop or top
    local h = n * rowH + (paneTop - top)
    s.listFrame:SetHeight(h)
    s.detailFrame:ClearAllPoints()
    s.detailFrame:SetPoint("TOPLEFT", f, "TOPLEFT", s.detailX, paneTop)
    s.detailFrame:SetSize(s.detailW, h)
end

-- Rectangle { left, top, right, bottom } of `r` inside `f` (top left of `f`
-- is 0,0; y goes up), worked out from the anchors alone, so it can be done
-- before the window has ever been shown.
local function Rect(r, f, memo, depth)
    if r == f then return { 0, 0, f:GetWidth() or 0, -(f:GetHeight() or 0) } end
    local known = memo[r]
    if known ~= nil then return known or nil end
    depth = depth or 0
    if depth > 8 or not r.GetNumPoints then return end
    memo[r] = false
    local n = r:GetNumPoints()
    if not n or n == 0 then return end
    local L, R, CX, T, B, CY
    for i = 1, n do
        local p, rel, rp, x, y = r:GetPoint(i)
        rel = rel or r:GetParent()
        local q = rel and Rect(rel, f, memo, depth + 1)
        if not q then return end
        rp = rp or p
        local px = q[1] + PX[rp] * (q[3] - q[1]) + (x or 0)
        local py = q[2] - PY[rp] * (q[2] - q[4]) + (y or 0)
        if PX[p] == 0 then L = px elseif PX[p] == 1 then R = px else CX = px end
        if PY[p] == 0 then T = py elseif PY[p] == 1 then B = py else CY = py end
    end
    local w, h = r:GetWidth() or 0, r:GetHeight() or 0
    L = L or (R and R - w) or (CX and CX - w / 2)
    R = R or (L and L + w)
    T = T or (B and B + h) or (CY and CY + h / 2)
    B = B or (T and T - h)
    if not (L and R and T and B) then return end
    local q = { L, T, R, B }
    memo[r] = q
    return q
end

--- The same rectangle, read from the screen: exact, but only once the window
--- is showing.
local function ScreenRect(r, f)
    local fl, ft = f:GetLeft(), f:GetTop()
    if not (fl and ft and r.GetLeft) then return end
    local l, t, rr, b = r:GetLeft(), r:GetTop(), r:GetRight(), r:GetBottom()
    if not (l and t and rr and b) then return end
    local src = r.GetEffectiveScale and r:GetEffectiveScale()
        or (r.GetParent and r:GetParent() and r:GetParent():GetEffectiveScale()) or 1
    local k = src / (f:GetEffectiveScale() or 1)
    return { l * k - fl, t * k - ft, rr * k - fl, b * k - ft }
end

local function Area(q) return max(0, q[3] - q[1]) * max(0, q[2] - q[4]) end
local function Overlap(a, b)
    local w = min(a[3], b[3]) - max(a[1], b[1])
    local h = min(a[2], b[2]) - max(a[4], b[4])
    return (w > 0 and h > 0) and w * h or 0
end

local EXTRA_H  = 80   -- how much taller a window with Blizzard's new frame gets
local SCROLL_W = 26   -- the scroll bar beside a pane

--- Windows drawn with Blizzard's newer frame (it stretches by itself): keep
--- every piece of the original look. The window gets wider and taller; the
--- pieces that belong to the list or the detail pane (their backgrounds and
--- borders) travel with their pane.
local function Label(o)
    local n = o.GetName and o:GetName()
    if n then return n end
    local p = o.GetParent and o:GetParent()
    if p then for k, v in pairs(p) do if v == o and type(k) == "string" then return "." .. k end end end
    return o.GetObjectType and o:GetObjectType() or "?"
end
local function RectText(q)
    return q and ("%.0f,%.0f .. %.0f,%.0f"):format(q[1], q[2], q[3], q[4]) or "?"
end

--- The list's scroll bar track is drawn by Blizzard from two pieces of a
--- fixed height (no middle). Once the list is taller than Blizzard drew it,
--- a gap opens between them. The track is just two thin rails beside the
--- arrow buttons, the same all the way down, so it is drawn again in full
--- length behind Blizzard's pieces, beside the up and down buttons. It
--- hangs on the buttons, so it follows any size without measuring.
local RAIL_DARK  = { 0.11, 0.105, 0.09 }
local RAIL_LIGHT = { 0.205, 0.20, 0.16 }

local function Rail(bar, up, down, side)
    -- side -1: left of the buttons, 1: right of them.
    local pts = side < 0 and { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }
                          or { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    local function strip(x, w, c)
        local t = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        t:SetColorTexture(c[1], c[2], c[3], 1)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
        t:SetPoint(pts[1], up, pts[2], x, 0)
        t:SetPoint(pts[3], down, pts[4], x, 0)
        t:SetWidth(w)
    end
    -- From the button outwards: a light rail, then a darker edge.
    strip(side * 1, 3, RAIL_LIGHT)
    strip(side * 4, 1, RAIL_DARK)
end

local function FillTrack(pane, d)
    local pn = pane:GetName() or ""
    local bar = pane.ScrollBar or _G[pn .. "ScrollBar"]
    local bn = bar and bar:GetName() or ""
    local up = bar and (bar.ScrollUpButton or _G[bn .. "ScrollUpButton"])
    local down = bar and (bar.ScrollDownButton or _G[bn .. "ScrollDownButton"])
    if not (up and down) then
        if d then d[#d + 1] = ("  track: bar %s, up %s, down %s"):format(bar and "yes" or "no", up and "yes" or "no", down and "yes" or "no") end
        return
    end
    Rail(bar, up, down, -1)
    Rail(bar, up, down, 1)
    if d then d[#d + 1] = "  track: drawn in full length" end
end

local function WidenModern(s, f, list, detail, row1)
    local memo = {}
    local function Measure(r) return ScreenRect(r, f) or Rect(r, f, memo) end
    local W0, H0 = f:GetWidth() or 0, f:GetHeight() or 0
    local lq, dq, rq = Measure(list), Measure(detail), Measure(row1)
    local d = s.diag
    d[#d + 1] = ("size %.0fx%.0f  list %s  detail %s  row1 %s"):format(W0, H0, RectText(lq), RectText(dq), RectText(rq))
    if not (lq and dq and W0 > 0 and H0 > 0) then
        for _, r in ipairs({ list, detail }) do
            for i = 1, (r:GetNumPoints() or 0) do
                local p, rel, rp, x, y = r:GetPoint(i)
                d[#d + 1] = ("  %s: %s -> %s %s (%.0f,%.0f)"):format(Label(r), tostring(p), rel and Label(rel) or "-", tostring(rp), x or 0, y or 0)
            end
        end
        d[#d + 1] = "-> could not measure, plain look used"
        return false
    end
    local zones = {
        { { lq[1], lq[2], lq[3] + SCROLL_W, lq[4] }, list, lq },
        { { dq[1], dq[2], dq[3] + SCROLL_W, dq[4] }, detail, dq },
    }
    local movers, stretch, limit = {}, {}, W0 * H0 * 0.6
    local function consider(r)
        if r == list or r == detail then return end
        local q = Measure(r)
        if not q then return end
        local a = Area(q)
        if a <= 0 then return end
        if a > limit then
            -- Covers most of the window (its background): grows with it.
            stretch[#stretch + 1] = { r, q[1], q[2], q[3] - W0, q[4] + H0 }
            return
        end
        for _, z in ipairs(zones) do
            if Overlap(q, z[1]) >= a * 0.6 then
                local o = z[3]
                movers[#movers + 1] = { r, z[2], q[1] - o[1], q[2] - o[2], q[3] - o[3], q[4] - o[4] }
                return
            end
        end
    end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" then consider(r) end
    end
    local rowPattern = "^" .. s.row .. "%d"
    for _, c in ipairs({ f:GetChildren() }) do
        local name = c:GetName()
        if c:GetObjectType() == "Frame" and not (name and name:find(rowPattern)) then consider(c) end
    end

    s.modern = true
    d[#d + 1] = ("grow with the window: %d"):format(#stretch)
    for i = 1, min(#stretch, 6) do d[#d + 1] = "  " .. Label(stretch[i][1]) .. " " .. RectText({ stretch[i][2], stretch[i][3], stretch[i][4] + W0, stretch[i][5] - H0 }) end
    d[#d + 1] = ("moved with the panes: %d"):format(#movers)
    for i = 1, min(#movers, 8) do
        local m = movers[i]
        d[#d + 1] = ("  %s -> %s"):format(Label(m[1]), m[2] == list and "list" or "detail")
    end
    for _, k in ipairs({ "PortraitContainer", "portrait", "Bg", "Inset" }) do
        local o = f[k]
        if o then d[#d + 1] = ("  .%s %s %s"):format(k, RectText(Measure(o)), o:IsShown() and "shown" or "hidden") end
    end
    s.top = rq and rq[2] or lq[2]
    s.paneTop = lq[2]
    s.paneBottom = dq[4] - EXTRA_H
    s.detailX = W0 - 8 + dq[1]
    s.detailW = dq[3] - dq[1]
    s.width = 2 * W0 - 16
    f:SetSize(s.width, H0 + EXTRA_H)
    PanelWide(f, s.frame, s.width)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", f, "TOPLEFT", lq[1], lq[2])
    FitRows(s)
    FillTrack(list, d)
    for _, m in ipairs(stretch) do
        local r = m[1]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", m[2], m[3])
        r:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", m[4], m[5])
    end
    for _, m in ipairs(movers) do
        local r, pane = m[1], m[2]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", pane, "TOPLEFT", m[3], m[4])
        r:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", m[5], m[6])
    end
    -- Scroll bar tracks built from a top and a bottom piece only would show
    -- a gap once the pane is taller; tracks with a middle piece stretch.
    for _, n in ipairs(s.hide or {}) do
        local r = _G[n]
        local base = n:gsub("Top$", ""):gsub("Bottom$", "")
        if r and r.SetAlpha and not _G[base .. "Middle"] then r:SetAlpha(0) end
    end
    return true
end

--- Lays out one window as described by `s`.
local WidenOld
local function Widen(s)
    s.WidenOld = WidenOld
    local f = _G[s.frame]
    if not f or f.aioWide then return end
    local list, detail, row1 = _G[s.list], _G[s.detail], _G[s.row .. "1"]
    if not (list and detail and row1 and _G[s.count]) then return end
    f.aioWide = true
    s.f, s.listFrame, s.detailFrame = f, list, detail
    s.made = _G[s.count]

    -- Blizzard's newer frames carry these parts.
    local keys = {}
    for _, k in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "Bg", "Inset", "CloseButton", "portrait" }) do
        if f[k] then keys[#keys + 1] = k end
    end
    s.diag = { ("%s: %s"):format(s.frame, #keys > 0 and table.concat(keys, ", ") or "old frame") }
    if #keys > 0 then
        -- Measured the first time the window shows, when every part has its
        -- real place on screen.
        local function go()
            if s.done then return end
            s.done = true
            if WidenModern(s, f, list, detail, row1) then
                if AIO.Style.blizzard then Skin(f, s) end
                if s.setup then s.setup(f, s) end
            else
                s.WidenOld(s, f, list, detail, row1)
            end
            if UpdateUIPanelPositions then C_Timer.After(0, function() UpdateUIPanelPositions(f) end) end
        end
        if f:IsShown() and f:GetLeft() then go() else f:HookScript("OnShow", go) end
        return
    end
    s.WidenOld(s, f, list, detail, row1)
end

WidenOld = function(s, f, list, detail, row1)
    -- Older frames are painted from fixed pictures that cannot stretch:
    -- they get a plain dialog look instead.
    -- Measure before the window changes size: the list may hang off the
    -- window's right edge, which is about to move.
    local lx, ly = TopLeftIn(list, f)
    local rx, ry = TopLeftIn(row1, f)
    if not lx then lx, ly = (rx or 22) - 1, ry or -96 end
    s.top = ry or ly
    s.paneBottom = -(WIDE_H - BOTTOM_PAD)
    s.detailX, s.detailW, s.width = DETAIL_X, DETAIL_W, WIDE_W

    f:SetSize(WIDE_W, WIDE_H)
    PanelWide(f, s.frame, WIDE_W)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", f, "TOPLEFT", lx, ly)
    for _, n in ipairs(s.hide or {}) do
        local r = _G[n]
        if r then if r.SetAlpha then r:SetAlpha(0) end end
    end
    Place(s.title, "TOP", f, "TOP", 0, -16)
    Place(s.close, "TOPRIGHT", f, "TOPRIGHT", -6, -6)
    FitRows(s)
    FillTrack(list, s.diag)
    if AIO.Style.blizzard then Skin(f, s) else Dress(f, s) end
    if s.setup then s.setup(f, s) end
end

local function BottomRow(f, right, left)
    local r = Place(right, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    if r and left then Place(left, "RIGHT", r, "LEFT", -2, 0) end
end

-- ---------------------------------------------------------------------------
-- Quest log
-- ---------------------------------------------------------------------------

local Q = AIO:NewModule("questlog", {
    title     = L["Larger quest log"],
    short     = L["The quest log as a wide window: quests on the left, as many as fit, the text on the right. With quest levels and a map button."],
    desc      = L["The quest log as a wide window: quests on the left, as many as fit, the text on the right. With quest levels and a map button."],
    category  = "windows",
    default   = true,
    defaults  = { levels = true, kind = true, map = true },
    options   = {
        { type = "text", label = L["Switching this on or off takes effect after a /reload."] },
        { type = "header", label = L["Levels"] },
        { type = "toggle", key = "levels", label = L["Show quest levels"], desc = L["Show the level in front of every quest, in the list and above the quest text."] },
        { type = "toggle", key = "kind", label = L["Show the quest kind"], desc = L["After the level: + group, D dungeon, H heroic, R raid, P PvP."],
          disabled = function(m) return not m.db.levels end },
        { type = "toggle", key = "map", label = L["Map button"], desc = L["A button at the bottom that opens the world map."] },
    },
})

-- Quest kinds as the game names them, shortened. Unknown kinds show nothing.
local KIND = {}
local function AddKind(word, mark) if word then KIND[word] = mark end end
AddKind(ELITE, "+"); AddKind(GROUP, "+"); AddKind(LFG_TYPE_DUNGEON, "D"); AddKind(RAID, "R"); AddKind(PVP, "P")
AddKind("Elite", "+"); AddKind("Group", "+"); AddKind("Dungeon", "D"); AddKind("Raid", "R"); AddKind("PvP", "P")
AddKind("Heroic", "H")

local function LevelTag(level, kind)
    local mark = Q.db.kind and kind and KIND[kind] or ""
    return "[" .. level .. mark .. "] "
end

local function QuestListLevels()
    if not (Q.enabled and Q.db.levels) then return end
    local entries = GetNumQuestLogEntries()
    if not entries or entries == 0 then return end
    local offset = FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
    for i = 1, QUESTS_DISPLAYED do
        local index = i + offset
        if index > entries then break end
        local title, level, kind, isHeader = GetQuestLogTitle(index)
        local button = _G["QuestLogTitle" .. i]
        if title and level and level > 0 and not isHeader and button and button:IsShown() then
            local text = button:GetText()
            -- Another addon may already show levels.
            if text and not text:find("^%s*%[") then
                button:SetText("  " .. LevelTag(level, kind) .. title)
                local check = _G["QuestLogTitle" .. i .. "Check"]
                local fs = button.GetFontString and button:GetFontString()
                if check and fs and check:IsShown() then
                    check:ClearAllPoints()
                    check:SetPoint("LEFT", button, "LEFT", min((fs:GetStringWidth() or 0) + 24, 270), 0)
                end
            end
        end
    end
end

local function QuestDetailLevel()
    if not (Q.enabled and Q.db.levels) then return end
    local index = GetQuestLogSelection and GetQuestLogSelection()
    if not index or index == 0 then return end
    local title, level, kind, isHeader = GetQuestLogTitle(index)
    if title and level and level > 0 and not isHeader and QuestLogQuestTitle then
        QuestLogQuestTitle:SetText(LevelTag(level, kind) .. title)
    end
end

local mapButton
local QUEST = {
    frame = "QuestLogFrame", list = "QuestLogListScrollFrame", detail = "QuestLogDetailScrollFrame",
    row = "QuestLogTitle", template = "QuestLogTitleButtonTemplate", count = "QUESTS_DISPLAYED",
    title = "QuestLogTitleText", close = "QuestLogFrameCloseButton", light = true,
    hide = { "QuestLogDetailScrollFrameTop", "QuestLogDetailScrollFrameBottom" },
    setup = function(f, s)
        local abandon, share = _G.QuestLogFrameAbandonButton, _G.QuestFramePushQuestButton
        if not s.modern then
            abandon = Place("QuestLogFrameAbandonButton", "BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
            share = abandon and Place("QuestFramePushQuestButton", "LEFT", abandon, "RIGHT", 2, 0)
            Place("QuestFrameExitButton", "BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
        end
        mapButton = CreateFrame("Button", "AllInOneQuestMapButton", f, "UIPanelButtonTemplate")
        mapButton:SetSize(share and share:GetWidth() > 0 and share:GetWidth() or 100, share and share:GetHeight() > 0 and share:GetHeight() or 22)
        mapButton:SetText(L["Map"])
        local after = share or abandon
        if after then
            mapButton:SetPoint("LEFT", after, "RIGHT", 2, 0)
        else
            mapButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
        end
        mapButton:SetScript("OnClick", function() ToggleWorldMap() end)
        mapButton:SetShown(Q.db.map)
        -- The empty log keeps its picture out of the way.
        local empty = _G.EmptyQuestLogFrame
        if empty and not s.modern then
            HideArt(empty)
            hooksecurefunc(empty, "Show", function(self)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
                self:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
            end)
        end
        local none = _G.QuestLogNoQuestsText
        if none then
            none:ClearAllPoints()
            none:SetPoint("TOP", QuestLogListScrollFrame, "TOP", 0, -50)
        end
    end,
}

-- /aio fenster: what the widening found, for when a window looks wrong.
Q.slash = { fenster = true, windows = true }
local ALL_SPECS
function Q:Slash()
    for _, spec in ipairs(ALL_SPECS) do
        if spec.diag then
            for _, line in ipairs(spec.diag) do AIO:Print(line) end
        else
            AIO:Print(spec.frame .. ": -")
        end
    end
end

local listHooked, detailHooked
function Q:OnEnable()
    Widen(QUEST)          -- does nothing once done, or while the log is not loaded
    if not listHooked and QuestLog_Update then
        listHooked = true
        hooksecurefunc("QuestLog_Update", QuestListLevels)
    end
    if not detailHooked and QuestLog_UpdateQuestDetails then
        detailHooked = true
        hooksecurefunc("QuestLog_UpdateQuestDetails", QuestDetailLevel)
    end
end

function Q:OnSettingChanged(key)
    if key == "map" and mapButton then mapButton:SetShown(self.db.map) end
    if QuestLogFrame and QuestLogFrame:IsShown() and QuestLog_Update then QuestLog_Update() end
end

-- ---------------------------------------------------------------------------
-- Professions
-- ---------------------------------------------------------------------------

local P = AIO:NewModule("professions", {
    title     = L["Larger profession windows"],
    short     = L["The profession windows (and enchanting) as wide windows: recipes on the left, as many as fit, the details on the right."],
    desc      = L["The profession windows (and enchanting) as wide windows: recipes on the left, as many as fit, the details on the right."],
    category  = "windows",
    default   = true,
    options   = {
        { type = "text", label = L["Switching this on or off takes effect after a /reload."] },
    },
})

local TRADE = {
    frame = "TradeSkillFrame", list = "TradeSkillListScrollFrame", detail = "TradeSkillDetailScrollFrame",
    row = "TradeSkillSkill", template = "TradeSkillSkillButtonTemplate", count = "TRADE_SKILLS_DISPLAYED",
    title = "TradeSkillFrameTitleText", close = "TradeSkillFrameCloseButton",
    hide = { "TradeSkillDetailScrollFrameTop", "TradeSkillDetailScrollFrameBottom", "TradeSkillExpandTabLeft" },
    setup = function(f, s)
        if not s.modern then
            BottomRow(f, "TradeSkillCancelButton", "TradeSkillCreateButton")
            local slot = Place("TradeSkillInvSlotDropdown", "TOPRIGHT", f, "TOPRIGHT", -14, -42)
            if slot then Place("TradeSkillSubClassDropdown", "RIGHT", slot, "LEFT", -8, 0) end
        end
        -- The search box stays where Blizzard put it, but the dropdowns
        -- travel to the new right edge and end up on top of it. It goes
        -- under the skill bar instead, beside "Have Materials".
        local box = _G.TradeSkillFrameSearchBox or _G.TradeSkillSearchBox or f.SearchBox
        local function find(h, depth)
            for _, c in ipairs({ h:GetChildren() }) do
                if c:GetObjectType() == "EditBox" then return c end
                if depth > 0 then
                    local r = find(c, depth - 1)
                    if r then return r end
                end
            end
        end
        box = box or find(f, 2)
        if not box then s.diag[#s.diag + 1] = "  search box: not found" end
        if box then
            local rank = _G.TradeSkillRankFrame or f.RankFrame
            local function place()
                box:ClearAllPoints()
                if rank then
                    box:SetPoint("TOPRIGHT", rank, "BOTTOMRIGHT", 0, -3)
                else
                    box:SetPoint("BOTTOMRIGHT", s.listFrame, "TOPRIGHT", 0, 6)
                end
            end
            place()
            -- In case the game puts it back when the window updates.
            if TradeSkillFrame_Update then hooksecurefunc("TradeSkillFrame_Update", place) end
            s.diag[#s.diag + 1] = "  search box: " .. Label(box) .. (rank and "" or " (no skill bar)")
        end
    end,
}

-- Enchanting (and beast training) use the older craft window.
local function PlaceCraftCosts()
    for i = 1, CRAFTS_DISPLAYED or 0 do
        local row, cost = _G["Craft" .. i], _G["Craft" .. i .. "Cost"]
        if row and cost then
            cost:ClearAllPoints()
            cost:SetPoint("RIGHT", row, "RIGHT", -30, 0)
        end
    end
end

local CRAFT = {
    frame = "CraftFrame", list = "CraftListScrollFrame", detail = "CraftDetailScrollFrame",
    row = "Craft", template = "CraftButtonTemplate", count = "CRAFTS_DISPLAYED",
    title = "CraftFrameTitleText", close = "CraftFrameCloseButton",
    hide = { "CraftDetailScrollFrameTop", "CraftDetailScrollFrameBottom", "CraftExpandTabLeft" },
    setup = function(f, s)
        local function buttons() if not s.modern then BottomRow(f, "CraftCancelButton", "CraftCreateButton") end end
        buttons()
        if f.Dropdown and not s.modern then
            f.Dropdown:ClearAllPoints()
            f.Dropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -42)
        end
        PlaceCraftCosts()
        -- The game moves these again when the window updates.
        if CraftFrame_Update then
            hooksecurefunc("CraftFrame_Update", function() buttons(); PlaceCraftCosts() end)
        end
    end,
}

function P:OnEnable()
    if Loaded("Blizzard_TradeSkillUI") then Widen(TRADE) end
    if Loaded("Blizzard_CraftUI") then Widen(CRAFT) end
end

-- ---------------------------------------------------------------------------
-- Trainers
-- ---------------------------------------------------------------------------

local T = AIO:NewModule("trainers", {
    title     = L["Larger trainer window"],
    short     = L["The trainer as a wide window, with a button that learns everything you can afford at once."],
    desc      = L["The trainer as a wide window, with a button that learns everything you can afford at once."],
    category  = "windows",
    default   = true,
    defaults  = { trainAll = true },
    options   = {
        { type = "text", label = L["Switching this on or off takes effect after a /reload."] },
        { type = "toggle", key = "trainAll", label = L["Show the train all button"] },
    },
})

--- Skills the trainer offers you right now: count, total cost.
local function Available()
    local n, cost = 0, 0
    for i = 1, GetNumTrainerServices() do
        local _, _, kind = GetTrainerServiceInfo(i)
        if kind == "available" then
            n = n + 1
            cost = cost + (GetTrainerServiceCost(i) or 0)
        end
    end
    return n, cost
end

local trainAll
local function TrainAllTip(self)
    local n, cost = Available()
    if n == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Learn %d for %s"]:format(n, GetCoinTextureString(cost)), 1, 1, 1)
    if cost > GetMoney() then
        GameTooltip:AddLine(L["Not enough money for everything: learns what you can afford."], 1, 0.3, 0.3, true)
    end
    GameTooltip:Show()
end

-- From the bottom up, so learning one skill does not shift the ones still to
-- come; stops buying what the purse cannot pay.
local function TrainAllClick()
    local money = GetMoney()
    for i = GetNumTrainerServices(), 1, -1 do
        local _, _, kind = GetTrainerServiceInfo(i)
        if kind == "available" then
            local cost = GetTrainerServiceCost(i) or 0
            if cost <= money then
                BuyTrainerService(i)
                money = money - cost
            end
        end
    end
end

local TRAINER = {
    frame = "ClassTrainerFrame", list = "ClassTrainerListScrollFrame", detail = "ClassTrainerDetailScrollFrame",
    row = "ClassTrainerSkill", template = "ClassTrainerSkillButtonTemplate", count = "CLASS_TRAINER_SKILLS_DISPLAYED",
    title = "ClassTrainerNameText", close = "ClassTrainerFrameCloseButton",
    hide = { "ClassTrainerDetailScrollFrameTop", "ClassTrainerDetailScrollFrameBottom", "ClassTrainerExpandTabLeft" },
    setup = function(f, s)
        if not s.modern then
            BottomRow(f, "ClassTrainerCancelButton", "ClassTrainerTrainButton")
            Place("ClassTrainerMoneyFrame", "BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
        end
        if f.FilterDropdown and not s.modern then
            f.FilterDropdown:ClearAllPoints()
            f.FilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -42)
        end
        trainAll = CreateFrame("Button", "AllInOneTrainAllButton", f, "UIPanelButtonTemplate")
        trainAll:SetSize(110, 22)
        trainAll:SetText(L["Train all"])
        if ClassTrainerTrainButton then
            trainAll:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -2, 0)
        else
            trainAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -200, 14)
        end
        trainAll:SetScript("OnEnter", TrainAllTip)
        trainAll:SetScript("OnLeave", function() GameTooltip:Hide() end)
        trainAll:SetScript("OnClick", TrainAllClick)
        trainAll:SetShown(T.db.trainAll)
        -- Class and profession trainers reset the row count when they open.
        local function refit() FitRows(s) end
        if ClassTrainer_SetToTradeSkillTrainer then hooksecurefunc("ClassTrainer_SetToTradeSkillTrainer", refit) end
        if ClassTrainer_SetToClassTrainer then hooksecurefunc("ClassTrainer_SetToClassTrainer", refit) end
        if ClassTrainerFrame_Update then
            hooksecurefunc("ClassTrainerFrame_Update", function()
                if not trainAll:IsShown() then return end
                trainAll:SetEnabled(Available() > 0)
                if trainAll:IsMouseOver() then TrainAllTip(trainAll) end
            end)
        end
    end,
}

function T:OnEnable()
    if Loaded("Blizzard_TrainerUI") then Widen(TRAINER) end
end

function T:OnSettingChanged(key)
    if key == "trainAll" and trainAll then trainAll:SetShown(self.db.trainAll) end
end

ALL_SPECS = { QUEST, TRADE, CRAFT, TRAINER }

-- ---------------------------------------------------------------------------
-- Load-on-demand windows
-- ---------------------------------------------------------------------------

AIO:On("ADDON_LOADED", function(name)
    if name == "Blizzard_TradeSkillUI" then
        if P.enabled then Widen(TRADE) end
    elseif name == "Blizzard_CraftUI" then
        if P.enabled then Widen(CRAFT) end
    elseif name == "Blizzard_TrainerUI" then
        if T.enabled then Widen(TRAINER) end
    elseif Q.enabled and not (listHooked and detailHooked and QUEST.f) then
        Q:OnEnable()      -- in case the quest log comes in an addon of its own
    end
end)
