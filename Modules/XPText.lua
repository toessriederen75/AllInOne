-- AllInOne: numbers on the experience bar ("cur / max (pct%)" and rested
-- experience) and, if wanted, on the reputation bar of the watched faction.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Experience bar text"] = "Text auf der Erfahrungsleiste"
    L["Numbers on the experience and reputation bars."] =
        "Zahlen auf der Erfahrungs- und Rufleiste."
    L["Shows your experience as numbers on the experience bar, with rested experience, and the standing of the watched faction on the reputation bar. Always, or only while the mouse is over the bar."] =
        "Zeigt die Erfahrung als Zahlen auf der Erfahrungsleiste, mit ausgeruhter Erfahrung, und den Stand der beobachteten Fraktion auf der Rufleiste. Immer oder nur, wenn die Maus über der Leiste ist."
    L["Show the text"]       = "Text zeigen"
    L["Always"]              = "Immer"
    L["On mouse-over"]       = "Bei Mausberührung"
    L["Text on the reputation bar"] = "Text auf der Rufleiste"
    L["Rested %s"]           = "Ausgeruht %s"
    L["Font size"]           = "Schriftgrösse"
end

local M = AIO:NewModule("xptext", {
    title    = L["Experience bar text"],
    short    = L["Numbers on the experience and reputation bars."],
    desc     = L["Shows your experience as numbers on the experience bar, with rested experience, and the standing of the watched faction on the reputation bar. Always, or only while the mouse is over the bar."],
    category = "display",
    default  = true,
    defaults = { mode = "always", rep = true, fontSize = 11 },
    options  = {
        { type = "select", key = "mode", label = L["Show the text"],
          values = { { value = "always", label = L["Always"] }, { value = "hover", label = L["On mouse-over"] } } },
        { type = "toggle", key = "rep", label = L["Text on the reputation bar"] },
        { type = "slider", key = "fontSize", label = L["Font size"], min = 8, max = 16, step = 1 },
    },
})

local function Number(n)
    n = math.floor(tonumber(n) or 0)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

-- ---------------------------------------------------------------------------
-- Finding the bars (they differ between clients)
-- ---------------------------------------------------------------------------

local function XPBar()
    return _G.MainMenuExpBar
end

local function RepBar()
    local bar = _G.ReputationWatchBar
    if bar then return bar.StatusBar or bar, bar end
    bar = _G.ReputationWatchStatusBar
    if bar then return bar, bar end
end

--- Blizzard's own texts on the bars, hidden while ours are on.
local function BlizzardTexts()
    local xp, rep = {}, {}
    if _G.MainMenuBarExpText then xp[#xp + 1] = _G.MainMenuBarExpText end
    local bar = _G.ReputationWatchBar
    if bar and bar.OverlayFrame and bar.OverlayFrame.Text then rep[#rep + 1] = bar.OverlayFrame.Text end
    if _G.ReputationWatchStatusBarText then rep[#rep + 1] = _G.ReputationWatchStatusBarText end
    return xp, rep
end

local function ApplyBlizzardTexts()
    local xp, rep = BlizzardTexts()
    for _, fs in ipairs(xp) do fs:SetAlpha(M.enabled and 0 or 1) end
    for _, fs in ipairs(rep) do fs:SetAlpha((M.enabled and M.db.rep) and 0 or 1) end
end

-- ---------------------------------------------------------------------------
-- Overlays
-- ---------------------------------------------------------------------------

local overlays = {}

local function Overlay(key, statusBar, mouseFrame)
    local o = overlays[key]
    if o then return o end
    o = CreateFrame("Frame", nil, statusBar)
    o:SetAllPoints(statusBar)
    o:SetFrameLevel((statusBar:GetFrameLevel() or 1) + 5)
    o:EnableMouse(false)
    o.text = Style.Text(o, M.db.fontSize, C.text)
    o.text:SetPoint("CENTER", 0, 1)
    o.text:SetJustifyH("CENTER")
    o.hovered = false
    local target = mouseFrame or statusBar
    if target.HookScript then
        target:HookScript("OnEnter", function()
            o.hovered = true
            M:UpdateVisibility()
        end)
        target:HookScript("OnLeave", function()
            o.hovered = false
            M:UpdateVisibility()
        end)
    end
    overlays[key] = o
    return o
end

function M:UpdateVisibility()
    for key, o in pairs(overlays) do
        local want = self.enabled and (key ~= "rep" or self.db.rep) and o.hasText
        if want and self.db.mode == "hover" then want = o.hovered end
        o:SetShown(want and true or false)
    end
end

function M:UpdateXP()
    local bar = XPBar()
    if not bar then return end
    local o = Overlay("xp", bar)
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 0
    if max <= 0 then
        o.hasText = false
    else
        local text = ("%s / %s (%.1f%%)"):format(Number(cur), Number(max), cur / max * 100)
        local rested = GetXPExhaustion and GetXPExhaustion()
        if rested and rested > 0 then
            text = text .. "  |cff6fa8ff" .. L["Rested %s"]:format(Number(rested)) .. "|r"
        end
        o.text:SetText(text)
        o.hasText = true
    end
end

function M:UpdateRep()
    local bar, mouse = RepBar()
    if not bar then return end
    local o = Overlay("rep", bar, mouse)
    local name, standing, min, max, value
    if GetWatchedFactionInfo then name, standing, min, max, value = GetWatchedFactionInfo() end
    if not name or not max then
        o.hasText = false
        return
    end
    local cur, top = (value or 0) - (min or 0), max - (min or 0)
    local label = _G["FACTION_STANDING_LABEL" .. (standing or 0)] or ""
    local pct = top > 0 and cur / top * 100 or 100
    o.text:SetText(("%s: %s / %s (%.1f%%) %s"):format(name, Number(cur), Number(top), pct, label))
    o.hasText = true
end

function M:Update()
    if not self.enabled then return end
    local font = Style.Font(self.db.fontSize)
    self:UpdateXP()
    if self.db.rep then self:UpdateRep() end
    for _, o in pairs(overlays) do o.text:SetFontObject(font) end
    self:UpdateVisibility()
end

local function Queue() AIO:Later("xptext", function() M:Update() end) end

M:On("PLAYER_XP_UPDATE", Queue)
M:On("UPDATE_EXHAUSTION", Queue)
M:On("PLAYER_LEVEL_UP", Queue)
M:On("UPDATE_FACTION", Queue)
M:On("PLAYER_ENTERING_WORLD", Queue)

function M:OnEnable()
    if not XPBar() and not RepBar() then return end
    ApplyBlizzardTexts()
    self:Update()
end

function M:OnDisable()
    ApplyBlizzardTexts()
    self:UpdateVisibility()
end

function M:OnSettingChanged()
    ApplyBlizzardTexts()
    self:Update()
end
