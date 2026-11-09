-- AllInOne: an own cast bar and own timer bars (breath, fatigue, feign death)
-- in place of Blizzard's. The cast bar shows the spell name and icon, the
-- remaining and total time, the pushback, the latency and the ticks of
-- channelled spells. Size, look and colours are set on the options page;
-- unlock to move the bars.
--
-- Written for AllInOne from the feature list of eCastingBar (no code taken).
-- Anniversary only.
--
-- Cost: nothing is built before the module is on. The bars listen only to the
-- player's own spell events (RegisterUnitEvent) and run an OnUpdate only
-- while they are visible.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

local GetTime, floor, max, min = GetTime, math.floor, math.max, math.min

if GetLocale() == "deDE" then
    L["Cast bar"]                = "Zauberleiste"
    L["Your own cast bar and timer bars instead of Blizzard's: spell icon, remaining and total time, pushback, latency and the ticks of channelled spells."] =
        "Eigene Zauberleiste und Timerleisten statt der von Blizzard: Zaubersymbol, Rest- und Gesamtzeit, Zurückwerfen, Latenz und die Ticks kanalisierter Zauber."
    L["Replaces Blizzard's cast bar and the timer bars for breath, fatigue and feign death. Unlock the bars to see them and drag them where you want them."] =
        "Ersetzt Blizzards Zauberleiste und die Timerleisten für Atem, Erschöpfung und Totstellen. Entsperre die Leisten, dann siehst du sie und kannst sie hinziehen, wo du willst."
    L["Position"]                = "Position"
    L["Lock the bars"]           = "Leisten sperren"
    L["Unlocked, both bars show a preview and can be dragged."] =
        "Entsperrt zeigen beide Leisten eine Vorschau und lassen sich verschieben."
    L["Reset positions"]         = "Positionen zurücksetzen"
    L["Own cast bar"]            = "Eigene Zauberleiste"
    L["Instead of Blizzard's cast bar."] = "Statt der Zauberleiste von Blizzard."
    L["Frame"]                   = "Rahmen"
    L["Blizzard"]                = "Blizzard"
    L["AllInOne"]                = "AllInOne"
    L["None"]                    = "Keiner"
    L["Bar texture"]             = "Leistentextur"
    L["Smooth"]                  = "Glatt"
    L["Skills bar"]              = "Fertigkeitsleiste"
    L["Flat"]                    = "Flach"
    L["Width"]                   = "Breite"
    L["Height"]                  = "Höhe"
    L["Font size"]               = "Schriftgrösse"
    L["Opacity"]                 = "Deckkraft"
    L["Spell icon"]              = "Zaubersymbol"
    L["Left"]                    = "Links"
    L["Right"]                   = "Rechts"
    L["Hidden"]                  = "Ausgeblendet"
    L["Show"]                    = "Anzeigen"
    L["Spell name"]              = "Zaubername"
    L["Remaining time"]          = "Restzeit"
    L["Total time"]              = "Gesamtzeit"
    L["Pushback"]                = "Zurückwerfen"
    L["How far damage has pushed the cast back, in red next to the time."] =
        "Wie weit Schaden den Zauber zurückgeworfen hat, rot neben der Zeit."
    L["Latency"]                 = "Latenz"
    L["The part of the cast your connection eats, shaded at the end of the bar: from there on you can already press the next spell."] =
        "Der Teil des Zaubers, den deine Verbindung braucht, schraffiert am Ende der Leiste: ab dort kannst du den nächsten Zauber schon drücken."
    L["Latency in milliseconds"] = "Latenz in Millisekunden"
    L["Ticks of channelled spells"] = "Ticks kanalisierter Zauber"
    L["Lines on the bar where a channelled spell (Drain Life, Blizzard, Mind Flay ...) does its work."] =
        "Striche auf der Leiste, wo ein kanalisierter Zauber (Blutsauger, Blizzard, Gedankenschinden ...) wirkt."
    L["Colours"]                 = "Farben"
    L["Cast"]                    = "Zauber"
    L["Channel"]                 = "Kanalisieren"
    L["Finished"]                = "Fertig"
    L["Failed"]                  = "Fehlgeschlagen"
    L["Click a colour to change it."] = "Klick auf eine Farbe, um sie zu ändern."
    L["Timer bars"]              = "Timerleisten"
    L["Own timer bars"]          = "Eigene Timerleisten"
    L["Breath, fatigue and feign death, instead of Blizzard's bars."] =
        "Atem, Erschöpfung und Totstellen statt der Leisten von Blizzard."
    L["Name on the bar"]         = "Name auf der Leiste"
    L["Drag to move"]            = "Ziehen zum Verschieben"
    L["Preview"]                 = "Vorschau"
    L["Breath"]                  = "Atem"
    L["Bars locked."]            = "Leisten gesperrt."
    L["Bars unlocked: drag them where you want them, then lock them with /aio castbar."] =
        "Leisten entsperrt: zieh sie, wohin du willst, und sperre sie mit /aio castbar."
end

local TEXTURES = {
    { value = "blizzard", label = L["Blizzard"],   file = "Interface\\TargetingFrame\\UI-StatusBar" },
    { value = "smooth",   label = L["Smooth"],     file = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { value = "skills",   label = L["Skills bar"], file = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { value = "flat",     label = L["Flat"],       file = "Interface\\Buttons\\WHITE8x8" },
}
local TEXTURE = {}
for _, t in ipairs(TEXTURES) do TEXTURE[t.value] = t.file end

local FRAMES = {
    { value = "blizzard", label = L["Blizzard"] },
    { value = "aio",      label = L["AllInOne"] },
    { value = "none",     label = L["None"] },
}

local CAST_POINT   = { "BOTTOM", "UIParent", "BOTTOM", 0, 170 }
local MIRROR_POINT = { "TOP", "UIParent", "TOP", 0, -96 }

local function Copy(t) local c = {} for i, v in ipairs(t) do c[i] = v end return c end

local M = AIO:NewModule("castbar", {
    title    = L["Cast bar"],
    short    = L["Your own cast bar and timer bars instead of Blizzard's: spell icon, remaining and total time, pushback, latency and the ticks of channelled spells."],
    desc     = L["Replaces Blizzard's cast bar and the timer bars for breath, fatigue and feign death. Unlock the bars to see them and drag them where you want them."],
    category = "castbar",
    default  = true,
    defaults = {
        locked = true,
        cast = true, castPoint = Copy(CAST_POINT),
        width = 220, height = 16, frame = "blizzard", texture = "blizzard", fontSize = 12, alpha = 1,
        icon = "LEFT", name = true, time = true, total = false, delay = true,
        latency = true, lagText = false, ticks = true,
        colors = {
            cast    = { 1, 0.7, 0 },
            channel = { 0, 1, 0 },
            success = { 0, 1, 0 },
            failed  = { 1, 0, 0 },
            latency = { 1, 0, 0 },
        },
        mirror = true, mirrorPoint = Copy(MIRROR_POINT),
        mirrorWidth = 200, mirrorHeight = 13, mirrorTime = true, mirrorLabel = true,
    },
})
M.slash = "castbar"

local function NoCast(m) return not m.db.cast end
local function NoMirror(m) return not m.db.mirror end
local function Pct(v) return ("%d%%"):format(floor(v * 100 + 0.5)) end

-- ---------------------------------------------------------------------------
-- Colour swatches (options page)
-- ---------------------------------------------------------------------------

local function PickColor(c, onChange)
    local r, g, b = c[1], c[2], c[3]
    local cp = ColorPickerFrame
    local function apply(nr, ng, nb)
        c[1], c[2], c[3] = nr, ng, nb
        onChange()
    end
    local function picked() apply(cp:GetColorRGB()) end
    local function cancel() apply(r, g, b) end
    if cp.SetupColorPickerAndShow then
        cp:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
                                     swatchFunc = picked, cancelFunc = cancel })
    else
        cp:Hide()
        cp.hasOpacity = false
        cp.opacityFunc = nil
        cp.previousValues = { r, g, b }
        cp.func = picked
        cp.cancelFunc = cancel
        cp:SetColorRGB(r, g, b)
        ShowUIPanel(cp)
    end
end

local COLOR_KEYS = {
    { "cast", L["Cast"] }, { "channel", L["Channel"] }, { "success", L["Finished"] },
    { "failed", L["Failed"] }, { "latency", L["Latency"] },
}

local function BuildSwatches(parent, width, m)
    local colW = min(200, floor(width / 3))
    for i, def in ipairs(COLOR_KEYS) do
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(colW, 20)
        b:SetPoint("TOPLEFT", ((i - 1) % 3) * colW, -floor((i - 1) / 3) * 24)
        b.box = CreateFrame("Frame", nil, b)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT")
        local function paint()
            local c = m.db.colors[def[1]]
            Style.Flat(b.box, { c[1], c[2], c[3], 1 }, Style.blizzard and Style.bronze or C.line)
        end
        paint()
        b.text = Style.Text(b, 12)
        b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
        b.text:SetText(def[2])
        b:SetScript("OnClick", function()
            PickColor(m.db.colors[def[1]], function()
                paint()
                AIO:SettingChanged(m, "colors")
            end)
        end)
        b:SetScript("OnShow", paint)
    end
    return 48
end

M.options = {
    { type = "header", label = L["Position"] },
    { type = "toggle", key = "locked", label = L["Lock the bars"], desc = L["Unlocked, both bars show a preview and can be dragged."], half = true },
    { type = "button", label = L["Reset positions"], func = function(m)
        m.db.castPoint, m.db.mirrorPoint = Copy(CAST_POINT), Copy(MIRROR_POINT)
        AIO:SettingChanged(m, "castPoint")
    end },

    { type = "header", label = L["Cast bar"] },
    { type = "toggle", key = "cast", label = L["Own cast bar"], desc = L["Instead of Blizzard's cast bar."] },
    { type = "select", key = "frame", label = L["Frame"], values = FRAMES, half = true, disabled = NoCast },
    { type = "select", key = "texture", label = L["Bar texture"], values = TEXTURES, half = true, disabled = NoCast },
    { type = "slider", key = "width", label = L["Width"], min = 100, max = 600, step = 5, half = true, disabled = NoCast },
    { type = "slider", key = "height", label = L["Height"], min = 8, max = 40, step = 1, half = true, disabled = NoCast },
    { type = "slider", key = "fontSize", label = L["Font size"], min = 8, max = 20, step = 1, half = true, disabled = NoCast },
    { type = "slider", key = "alpha", label = L["Opacity"], min = 0.2, max = 1, step = 0.05, format = Pct, half = true, disabled = NoCast },
    { type = "select", key = "icon", label = L["Spell icon"], disabled = NoCast,
      values = { { value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] }, { value = "HIDDEN", label = L["Hidden"] } } },
    { type = "header", label = L["Show"] },
    { type = "toggle", key = "name", label = L["Spell name"], half = true, disabled = NoCast },
    { type = "toggle", key = "time", label = L["Remaining time"], half = true, disabled = NoCast },
    { type = "toggle", key = "total", label = L["Total time"], half = true, disabled = NoCast },
    { type = "toggle", key = "delay", label = L["Pushback"], desc = L["How far damage has pushed the cast back, in red next to the time."], half = true, disabled = NoCast },
    { type = "toggle", key = "latency", label = L["Latency"], desc = L["The part of the cast your connection eats, shaded at the end of the bar: from there on you can already press the next spell."], half = true, disabled = NoCast },
    { type = "toggle", key = "lagText", label = L["Latency in milliseconds"], half = true,
      disabled = function(m) return not (m.db.cast and m.db.latency) end },
    { type = "toggle", key = "ticks", label = L["Ticks of channelled spells"], desc = L["Lines on the bar where a channelled spell (Drain Life, Blizzard, Mind Flay ...) does its work."], disabled = NoCast },
    { type = "header", label = L["Colours"] },
    { type = "text", label = L["Click a colour to change it."] },
    { type = "custom", build = BuildSwatches },

    { type = "header", label = L["Timer bars"] },
    { type = "toggle", key = "mirror", label = L["Own timer bars"], desc = L["Breath, fatigue and feign death, instead of Blizzard's bars."] },
    { type = "slider", key = "mirrorWidth", label = L["Width"], min = 100, max = 600, step = 5, half = true, disabled = NoMirror },
    { type = "slider", key = "mirrorHeight", label = L["Height"], min = 8, max = 40, step = 1, half = true, disabled = NoMirror },
    { type = "toggle", key = "mirrorTime", label = L["Remaining time"], half = true, disabled = NoMirror },
    { type = "toggle", key = "mirrorLabel", label = L["Name on the bar"], half = true, disabled = NoMirror },
}

-- ---------------------------------------------------------------------------
-- Ticks of channelled spells
-- ---------------------------------------------------------------------------

-- One spell ID per channelled spell (every rank has the same name) and how
-- many times it does its work; 0 = once a second, however long it runs.
local TICK_SPELLS = {
    { 5143, 0 },    -- Arcane Missiles
    { 10, 8 },      -- Blizzard
    { 12051, 4 },   -- Evocation
    { 689, 5 },     -- Drain Life
    { 5138, 5 },    -- Drain Mana
    { 1120, 5 },    -- Drain Soul
    { 755, 10 },    -- Health Funnel
    { 5740, 4 },    -- Rain of Fire
    { 1949, 15 },   -- Hellfire
    { 15407, 3 },   -- Mind Flay
    { 10797, 5 },   -- Starshards
    { 16914, 10 },  -- Hurricane
    { 740, 4 },     -- Tranquility
    { 1510, 6 },    -- Volley
    { 746, 8 },     -- First Aid (bandages)
}
local tickByName

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end

local function TickCount(name, duration)
    if not tickByName then
        tickByName = {}
        for _, s in ipairs(TICK_SPELLS) do
            local n = SpellName(s[1])
            if n then tickByName[n] = s[2] end
        end
    end
    local n = name and tickByName[name]
    if n == 0 then n = floor(duration + 0.5) end
    return n
end

-- ---------------------------------------------------------------------------
-- A bar
-- ---------------------------------------------------------------------------

-- Blizzard's cast bar art is drawn for a 195 x 13 bar; the border and the
-- flash are 256 x 64 and sit 28 above the bar's top. Other sizes scale it.
local BORDER   = "Interface\\CastingBar\\UI-CastingBar-Border"
local FLASH    = "Interface\\CastingBar\\UI-CastingBar-Flash"
local SPARK    = "Interface\\CastingBar\\UI-CastingBar-Spark"
local ART_W, ART_H, ART_Y = 256 / 195, 64 / 13, 28 / 13

local function NewBar(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:Hide()
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetMinMaxValues(0, 1)
    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.5)
    -- Everything drawn over the fill.
    f.over = CreateFrame("Frame", nil, f)
    f.over:SetAllPoints()
    f.over:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    f.border = f.over:CreateTexture(nil, "ARTWORK")
    f.border:SetTexture(BORDER)
    f.edge = CreateFrame("Frame", nil, f)
    f.edge:SetPoint("TOPLEFT", -3, 3)
    f.edge:SetPoint("BOTTOMRIGHT", 3, -3)
    f.edge:SetFrameLevel(max(0, f.bar:GetFrameLevel() - 1))
    f.spark = f.over:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture(SPARK)
    f.spark:SetBlendMode("ADD")
    f.flash = f.over:CreateTexture(nil, "OVERLAY", nil, 2)
    f.flash:SetBlendMode("ADD")
    f.flash:Hide()
    f.text = f.over:CreateFontString(nil, "OVERLAY")
    f.time = f.over:CreateFontString(nil, "OVERLAY")
    f.time:SetJustifyH("RIGHT")
    return f
end

--- Size, frame, texture and font of a bar.
local function Dress(f, w, h, frame, texture, fontSize)
    f:SetSize(w, h)
    f.bar:SetStatusBarTexture(TEXTURE[texture] or TEXTURE.blizzard)
    local fill = f.bar:GetStatusBarTexture()
    if fill then fill:SetDrawLayer("BORDER") end
    local sw = min(48, h * 32 / 13)
    f.spark:SetSize(sw, h * 32 / 13)
    f.border:ClearAllPoints()
    f.flash:ClearAllPoints()
    if frame == "blizzard" then
        f.border:SetSize(w * ART_W, h * ART_H)
        f.border:SetPoint("TOP", f, "TOP", 0, h * ART_Y)
        f.border:Show()
        f.flash:SetTexture(FLASH)
        f.flash:SetSize(w * ART_W, h * ART_H)
        f.flash:SetPoint("TOP", f, "TOP", 0, h * ART_Y)
        f.edge:Hide()
    else
        f.border:Hide()
        f.flash:SetTexture(Style.WHITE)
        f.flash:SetAllPoints(f)
        if frame == "aio" then
            Style.Popup(f.edge)
            f.edge:Show()
        else
            f.edge:Hide()
        end
    end
    local font = Style.Font(fontSize)
    f.text:SetFontObject(font)
    f.time:SetFontObject(font)
    if f.delay then f.delay:SetFontObject(font) end
    if f.lagText then f.lagText:SetFontObject(Style.Font(max(8, fontSize - 2))) end
end

local function Spark(f, v)
    f.spark:SetPoint("CENTER", f, "LEFT", f:GetWidth() * v, 0)
end

local function Clock(s)
    s = max(0, s)
    if s >= 60 then return ("%d:%02d"):format(floor(s / 60), floor(s % 60)) end
    return ("%.1f"):format(s)
end

-- ---------------------------------------------------------------------------
-- The cast bar
-- ---------------------------------------------------------------------------

local cb             -- our cast bar
local CastPreview    -- (below)
local ticks = {}     -- tick lines, made when first needed
local CastInfo = UnitCastingInfo or CastingInfo
local ChanInfo = UnitChannelInfo or ChannelInfo

local function Blizzard()
    return _G.PlayerCastingBarFrame or _G.CastingBarFrame
end

--- Gives the player's cast bar back to Blizzard, or takes it away.
local function BlizzardCastBar(on)
    local b = Blizzard()
    if not b then return end
    if b.SetUnit then
        b:SetUnit(on and "player" or nil, true, false)
    elseif CastingBarFrame_SetUnit then
        CastingBarFrame_SetUnit(b, on and "player" or nil, true, false)
    elseif not on then
        b:UnregisterAllEvents()
    end
    if not on then b:Hide() end
    if not b.aioHooked then
        b.aioHooked = true
        b:HookScript("OnShow", function(self)
            if M.enabled and M.db.cast then self:Hide() end
        end)
    end
end

local function Color(f, key)
    local c = M.db.colors[key]
    f.bar:SetStatusBarColor(c[1], c[2], c[3])
end

local function HideTicks()
    for i = 1, #ticks do ticks[i]:Hide() end
end

local function ShowTicks(count)
    HideTicks()
    if not (count and count > 1) then return end
    local w, h = cb:GetWidth(), cb:GetHeight()
    for i = 1, count - 1 do
        local t = ticks[i]
        if not t then
            t = cb.over:CreateTexture(nil, "ARTWORK", nil, 3)
            t:SetColorTexture(1, 1, 1, 0.55)
            ticks[i] = t
        end
        t:SetSize(1, h)
        t:ClearAllPoints()
        t:SetPoint("CENTER", cb, "LEFT", w * i / count, 0)
        t:Show()
    end
end

--- The shaded latency part: at the right end of a cast, at the left end of
--- a channel (it runs from right to left).
local function ShowLatency(lag, duration)
    local db = M.db
    if not (db.latency and lag and duration and duration > 0) then
        cb.lag:Hide()
        cb.lagText:SetText("")
        return
    end
    local w = cb:GetWidth()
    local lw = min(w, w * lag / duration)
    if lw < 1 then cb.lag:Hide() else
        local c = db.colors.latency
        cb.lag:SetColorTexture(c[1], c[2], c[3], 0.45)
        cb.lag:ClearAllPoints()
        cb.lag:SetPoint(cb.mode == "channel" and "LEFT" or "RIGHT")
        cb.lag:SetSize(lw, cb:GetHeight())
        cb.lag:Show()
    end
    cb.lagText:SetText(db.lagText and ("%d ms"):format(lag * 1000) or "")
end

local function Begin(mode, name, icon, startMS, endMS, castID)
    local db = M.db
    cb.mode, cb.castID = mode, castID
    cb.startT, cb.endT = startMS / 1000, endMS / 1000
    cb.pushback, cb.holdUntil, cb.fading, cb.preview = 0, nil, nil, nil
    Color(cb, mode)
    cb.text:SetText(db.name and name or "")
    cb.icon:SetTexture(icon)
    cb.icon:SetShown(db.icon ~= "HIDDEN" and icon ~= nil)
    cb.delay:SetText("")
    cb.flash:Hide()
    cb.spark:Show()
    local lag = cb.sentAt and max(0, GetTime() - cb.sentAt) or nil
    cb.sentAt = nil
    ShowLatency(lag, cb.endT - cb.startT)
    if mode == "channel" and db.ticks then
        ShowTicks(TickCount(name, cb.endT - cb.startT))
    else
        HideTicks()
    end
    cb:SetAlpha(db.alpha)
    cb:Show()
end

local function Finish(ok, label)
    if not cb.mode then return end
    local channel = cb.mode == "channel"
    cb.mode = nil
    cb.spark:Hide()
    cb.lag:Hide()
    cb.lagText:SetText("")
    cb.time:SetText("")
    cb.delay:SetText("")
    if ok then
        cb.bar:SetValue(channel and 0 or 1)
        if not channel then Color(cb, "success") end
        cb.flash:SetAlpha(1)
        cb.flash:Show()
        cb.holdUntil = GetTime()
    else
        cb.bar:SetValue(1)
        Color(cb, "failed")
        if label then cb.text:SetText(label) end
        cb.holdUntil = GetTime() + 1
    end
    cb.fading = true
end

local function OnUpdate(self, elapsed)
    local now = GetTime()
    local mode = self.mode
    if mode then
        local s, e = self.startT, self.endT
        local d = e - s
        if d <= 0 then return end
        local v, left
        if mode == "cast" then
            if now >= e + 0.5 then return Finish(true) end   -- the stop never came
            v = min(1, (now - s) / d)
        else
            if now >= e then return Finish(true) end
            v = max(0, (e - now) / d)
        end
        left = e - now
        self.bar:SetValue(v)
        Spark(self, v)
        local db = M.db
        if db.time and db.total then
            self.time:SetText(Clock(left) .. " / " .. Clock(d))
        elseif db.time then
            self.time:SetText(Clock(left))
        elseif db.total then
            self.time:SetText(Clock(d))
        end
        return
    end
    if self.preview then return end
    if self.holdUntil and now < self.holdUntil then return end
    local a = self:GetAlpha() - elapsed * 2
    if self.flash:IsShown() then self.flash:SetAlpha(max(0, self.flash:GetAlpha() - elapsed * 3)) end
    if a <= 0 then
        self.fading = nil
        self:Hide()
        if not M.db.locked then CastPreview(true) end   -- back to the preview
    else
        self:SetAlpha(a)
    end
end

local function Pushback(amount)
    if not M.db.delay or amount == 0 then return end
    cb.pushback = cb.pushback + amount
    cb.delay:SetText(("%s%.1f"):format(cb.pushback > 0 and "+" or "", cb.pushback))
end

local function OnCastEvent(_, event, unit, castID)
    if event == "UNIT_SPELLCAST_SENT" then
        cb.sentAt = GetTime()
    elseif event == "UNIT_SPELLCAST_START" then
        local name, _, icon, s, e, _, id = CastInfo("player")
        if name then Begin("cast", name, icon, s, e, id) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, _, icon, s, e = ChanInfo("player")
        if name then Begin("channel", name, icon, s, e) end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if cb.mode ~= "cast" then return end
        local name, _, _, s, e = CastInfo("player")
        if not name then return end
        local old = cb.endT
        cb.startT, cb.endT = s / 1000, e / 1000
        Pushback(cb.endT - old)
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if cb.mode ~= "channel" then return end
        local name, _, _, s, e = ChanInfo("player")
        if not name then return end
        local old = cb.endT
        cb.startT, cb.endT = s / 1000, e / 1000
        Pushback(cb.endT - old)
    elseif event == "UNIT_SPELLCAST_STOP" then
        if cb.mode == "cast" and (not cb.castID or not castID or castID == cb.castID) then Finish(true) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if cb.mode == "channel" then Finish(true) end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- A failed press while nothing (or something else) is cast is ignored.
        if cb.mode == "cast" and cb.castID and castID == cb.castID then
            Finish(false, event == "UNIT_SPELLCAST_FAILED" and FAILED or INTERRUPTED)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        cb.mode = nil
        cb:Hide()
        if ChanInfo("player") then OnCastEvent(nil, "UNIT_SPELLCAST_CHANNEL_START", "player")
        elseif CastInfo("player") then OnCastEvent(nil, "UNIT_SPELLCAST_START", "player") end
    end
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
}

local function BuildCastBar()
    if cb then return end
    cb = NewBar("AllInOneCastBar")
    cb.icon = cb.over:CreateTexture(nil, "ARTWORK")
    cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.delay = cb.over:CreateFontString(nil, "OVERLAY")
    cb.delay:SetTextColor(1, 0.25, 0.25)
    cb.lag = cb.bar:CreateTexture(nil, "ARTWORK")
    cb.lag:Hide()
    cb.lagText = cb.over:CreateFontString(nil, "OVERLAY")
    cb.lagText:SetTextColor(0.75, 0.75, 0.75)
    cb:SetScript("OnUpdate", OnUpdate)
    cb:SetScript("OnEvent", OnCastEvent)
end

local function LayoutCastBar()
    local db = M.db
    local w, h = db.width, db.height
    Dress(cb, w, h, db.frame, db.texture, db.fontSize)
    -- Icon outside the bar, a little taller than it.
    local size = floor(h * 1.5 + 0.5)
    local gap = db.frame == "blizzard" and 8 or 6
    cb.icon:SetSize(size, size)
    cb.icon:ClearAllPoints()
    if db.icon == "RIGHT" then
        cb.icon:SetPoint("LEFT", cb, "RIGHT", gap, 0)
    else
        cb.icon:SetPoint("RIGHT", cb, "LEFT", -gap, 0)
    end
    if db.icon == "HIDDEN" then cb.icon:Hide() end
    cb.time:ClearAllPoints()
    cb.time:SetPoint("RIGHT", cb, "RIGHT", -4, 0)
    cb.delay:ClearAllPoints()
    cb.delay:SetPoint("RIGHT", cb.time, "LEFT", -4, 0)
    cb.text:ClearAllPoints()
    cb.text:SetPoint("CENTER", cb, "CENTER", 0, 0)
    cb.text:SetWidth(max(40, w - ((db.time or db.total) and 90 or 12)))
    cb.text:SetWordWrap(false)
    cb.lagText:ClearAllPoints()
    cb.lagText:SetPoint("BOTTOMRIGHT", cb, "TOPRIGHT", 0, db.frame == "blizzard" and 5 or 6)
    local p = db.castPoint
    cb:ClearAllPoints()
    cb:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

-- ---------------------------------------------------------------------------
-- Timer bars (breath, fatigue, feign death)
-- ---------------------------------------------------------------------------

local mirrors = {}   -- three bars, made with the first one needed
local mirrorDriver
local MIRROR_COLORS = {
    EXHAUSTION = { 1, 0.9, 0 }, BREATH = { 0, 0.5, 1 }, DEATH = { 1, 0.7, 0 }, FEIGNDEATH = { 1, 0.7, 0 },
}
local NUM_MIRRORS = _G.MIRRORTIMER_NUMTIMERS or 3

local function MirrorColor(timer)
    local c = _G.MirrorTimerColors and _G.MirrorTimerColors[timer]
    if c then return c.r, c.g, c.b end
    c = MIRROR_COLORS[timer] or MIRROR_COLORS.BREATH
    return c[1], c[2], c[3]
end

--- Blizzard's own timer bars: invisible while ours are on.
local function BlizzardMirrors(on)
    local a = on and 1 or 0
    for i = 1, NUM_MIRRORS do
        local f = _G["MirrorTimer" .. i]
        if f then f:SetAlpha(a) end
    end
    if _G.MirrorTimerContainer then _G.MirrorTimerContainer:SetAlpha(a) end
end

local function MirrorUpdate(self)
    if self.paused or not self.timer then return end
    local value = (GetMirrorTimerProgress(self.timer) or 0) / 1000
    local v = self.maxValue > 0 and max(0, min(1, value / self.maxValue)) or 0
    self.bar:SetValue(v)
    Spark(self, v)
    self.time:SetText(M.db.mirrorTime and Clock(value) or "")
end

local function PlaceMirrors()
    local db = M.db
    local p = db.mirrorPoint
    local gap = db.mirrorHeight * 2 + 6
    local n = 0
    for i = 1, #mirrors do
        local f = mirrors[i]
        f:ClearAllPoints()
        if f.timer or f.preview then
            f:SetPoint(p[1], UIParent, p[3], p[4], p[5] - n * gap)
            n = n + 1
        end
    end
end

local function MirrorBar(i)
    local f = mirrors[i]
    if f then return f end
    f = NewBar("AllInOneTimerBar" .. i)
    f:SetScript("OnUpdate", MirrorUpdate)
    mirrors[i] = f
    local db = M.db
    Dress(f, db.mirrorWidth, db.mirrorHeight, "blizzard", "blizzard", 12)
    f.text:SetPoint("CENTER")
    f.time:SetPoint("RIGHT", -4, 0)
    -- The first bar carries the drag for all of them.
    if i == 1 then
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) if not M.db.locked then self:StartMoving() end end)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, rel, x, y = self:GetPoint(1)
            M.db.mirrorPoint = { point, "UIParent", rel, floor(x + 0.5), floor(y + 0.5) }
            PlaceMirrors()
        end)
    end
    return f
end

local function MirrorStart(timer, value, maxValue, scale, paused, label)
    if not timer then return end
    local f
    for i = 1, NUM_MIRRORS do
        local m = mirrors[i]
        if m and m.timer == timer then f = m break end
    end
    if not f then
        for i = 1, NUM_MIRRORS do
            local m = MirrorBar(i)
            if not m.timer then f = m break end
        end
    end
    if not f then return end
    f.preview = nil
    f.timer, f.maxValue = timer, (maxValue or 0) / 1000
    f.paused = paused and paused > 0
    f.bar:SetStatusBarColor(MirrorColor(timer))
    f.text:SetText(M.db.mirrorLabel and label or "")
    f.flash:Hide()
    f.spark:Show()
    f:SetAlpha(1)
    f:Show()
    MirrorUpdate(f)
    PlaceMirrors()
end

local function MirrorStop(timer)
    for i = 1, #mirrors do
        local f = mirrors[i]
        if f.timer == timer then
            f.timer = nil
            f:Hide()
        end
    end
    PlaceMirrors()
end

local function MirrorRescan()
    for i = 1, #mirrors do mirrors[i].timer = nil; mirrors[i]:Hide() end
    for i = 1, NUM_MIRRORS do
        local timer, value, maxValue, scale, paused, label = GetMirrorTimerInfo(i)
        if timer and timer ~= "UNKNOWN" and maxValue and maxValue > 0 then
            MirrorStart(timer, value, maxValue, scale, paused, label)
        end
    end
end

local function OnMirrorEvent(_, event, timer, a2, a3, a4, a5, a6)
    if event == "MIRROR_TIMER_START" then
        MirrorStart(timer, a2, a3, a4, a5, a6)
    elseif event == "MIRROR_TIMER_STOP" then
        MirrorStop(timer)
    elseif event == "MIRROR_TIMER_PAUSE" then
        -- (timer, paused) on some clients, only (paused) on others: pauses all.
        local paused = (type(timer) == "number" and timer or a2 or 0) > 0
        for i = 1, #mirrors do
            local f = mirrors[i]
            if f.timer and (type(timer) ~= "string" or f.timer == timer) then f.paused = paused end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        MirrorRescan()
    end
end

local function LayoutMirrors()
    local db = M.db
    for i = 1, #mirrors do
        local f = mirrors[i]
        Dress(f, db.mirrorWidth, db.mirrorHeight, "blizzard", "blizzard", 12)
        if not db.mirrorTime then f.time:SetText("") end
    end
    PlaceMirrors()
end

-- ---------------------------------------------------------------------------
-- Preview while unlocked
-- ---------------------------------------------------------------------------

function CastPreview(on)
    if not cb then return end
    local db = M.db
    cb:EnableMouse(on)
    if on then
        cb:RegisterForDrag("LeftButton")
        cb:SetScript("OnDragStart", function(self) self:StartMoving() end)
        cb:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, rel, x, y = self:GetPoint(1)
            M.db.castPoint = { point, "UIParent", rel, floor(x + 0.5), floor(y + 0.5) }
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Drag to move"], 1, 1, 1)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
        if cb.mode then return end      -- a real cast keeps the bar
        cb.preview, cb.fading, cb.holdUntil = true, nil, nil
        Color(cb, "cast")
        cb.text:SetText(db.name and L["Cast bar"] or "")
        local icon = GetSpellTexture and GetSpellTexture(133) or "Interface\\Icons\\Spell_Fire_FlameBolt"
        cb.icon:SetTexture(icon)
        cb.icon:SetShown(db.icon ~= "HIDDEN")
        cb.bar:SetValue(0.6)
        Spark(cb, 0.6)
        cb.spark:Show()
        cb.flash:Hide()
        cb.time:SetText(db.time and (db.total and "1.0 / 2.5" or "1.0") or (db.total and "2.5" or ""))
        cb.delay:SetText(db.delay and "+0.4" or "")
        cb.mode = nil
        ShowLatency(0.12, 2.5)
        if db.ticks then ShowTicks(5) else HideTicks() end
        cb:SetAlpha(db.alpha)
        cb:Show()
    else
        cb:SetScript("OnEnter", nil)
        cb:SetScript("OnLeave", nil)
        if cb.preview then
            cb.preview = nil
            HideTicks()
            cb.lag:Hide()
            cb.lagText:SetText("")
            if not cb.mode then cb:Hide() end
        end
    end
end

local function MirrorPreview(on)
    if not on and not mirrors[1] then return end
    local f = MirrorBar(1)
    f:EnableMouse(on)
    if on then
        if f.timer then return end
        f.preview = true
        f.bar:SetStatusBarColor(MirrorColor("BREATH"))
        f.text:SetText(M.db.mirrorLabel and (L["Breath"] .. " (" .. L["Preview"] .. ")") or "")
        f.bar:SetValue(0.7)
        Spark(f, 0.7)
        f.time:SetText(M.db.mirrorTime and "42.0" or "")
        f:SetAlpha(1)
        f:Show()
    elseif f.preview then
        f.preview = nil
        if not f.timer then f:Hide() end
    end
    PlaceMirrors()
end

-- ---------------------------------------------------------------------------
-- Switching on and off
-- ---------------------------------------------------------------------------

function M:Apply()
    local db = self.db
    local on = self.enabled
    local unlocked = not db.locked

    -- Cast bar
    if on and db.cast then
        BuildCastBar()
        if not cb.listening then
            cb.listening = true
            for _, e in ipairs(CAST_EVENTS) do
                if cb.RegisterUnitEvent then pcall(cb.RegisterUnitEvent, cb, e, "player")
                else pcall(cb.RegisterEvent, cb, e) end
            end
            cb:RegisterEvent("PLAYER_ENTERING_WORLD")
            BlizzardCastBar(false)
        end
        LayoutCastBar()
        if not cb.mode and not cb.fading then cb:SetAlpha(db.alpha) end
        CastPreview(unlocked)
    elseif cb and cb.listening then
        cb.listening = nil
        cb:UnregisterAllEvents()
        CastPreview(false)
        cb.mode = nil
        cb:Hide()
        BlizzardCastBar(true)
    end

    -- Timer bars
    if on and db.mirror then
        if not mirrorDriver then
            mirrorDriver = CreateFrame("Frame")
            mirrorDriver:SetScript("OnEvent", OnMirrorEvent)
        end
        if not mirrorDriver.listening then
            mirrorDriver.listening = true
            for _, e in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MIRROR_TIMER_PAUSE", "PLAYER_ENTERING_WORLD" }) do
                pcall(mirrorDriver.RegisterEvent, mirrorDriver, e)
            end
            BlizzardMirrors(false)
            MirrorRescan()
        end
        LayoutMirrors()
        MirrorPreview(unlocked)
    elseif mirrorDriver and mirrorDriver.listening then
        mirrorDriver.listening = nil
        mirrorDriver:UnregisterAllEvents()
        for i = 1, #mirrors do
            mirrors[i].timer, mirrors[i].preview = nil, nil
            mirrors[i]:Hide()
        end
        BlizzardMirrors(true)
    end
end

function M:OnEnable() self:Apply() end
function M:OnDisable() self:Apply() end
function M:OnSettingChanged() self:Apply() end

function M:Slash()
    self.db.locked = not self.db.locked
    self:Apply()
    self:Print(self.db.locked and L["Bars locked."] or L["Bars unlocked: drag them where you want them, then lock them with /aio castbar."])
end
