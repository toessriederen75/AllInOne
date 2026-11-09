-- AllInOne: danger alarm. A sound when you stand in something that hurts:
-- fire on the floor, poison clouds, void zones. Four alarms: high damage, low
-- damage, still standing in it, and friendly fire (you hurt your own group).
-- Also for lava, slime, fatigue and drowning, and, if wanted, for damage
-- while you are away. The idea comes from the addon GTFO by Zensunim; no
-- code, lists or sounds are taken from it.
--
-- No list of spells: something on the ground is recognised by how it hurts.
-- Damage that ticks on you again and again without a debuff of that spell
-- on you comes from an area you are standing in. How bad it is follows from
-- the share of your health one tick takes.
--
-- Clients that keep the combat log from addons (WoW Forever, like Retail)
-- get what works without it: fatigue, drowning and being attacked while away.
--
-- Cost: one combat log handler, registered only while the module is on. It
-- leaves at once unless the event hits you or comes from you.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style

local GetTime, tonumber, band = GetTime, tonumber, bit.band
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

if GetLocale() == "deDE" then
    L["Danger alarm"]            = "Gefahren-Alarm"
    L["A loud alarm when you stand in something that hurts: fire on the floor, poison clouds, boss abilities you should step out of."] =
        "Ein lauter Alarm, wenn du in etwas stehst, das dir schadet: Feuer am Boden, Giftwolken, Boss-Fähigkeiten, denen du ausweichen solltest."
    L["Four different alarms tell you how bad it is. Areas on the ground are recognised by themselves: damage that keeps ticking on you without a debuff."] =
        "Vier verschiedene Alarme sagen dir, wie schlimm es ist. Flächen am Boden werden von selbst erkannt: Schaden, der immer wieder tickt, ohne dass du einen Schwächungszauber hast."
    L["This game version does not let addons read the combat log. That leaves the alarms for fatigue, drowning and being attacked while you are away; spells and lava cannot be recognised."] =
        "Diese Spielversion lässt Addons das Kampf-Log nicht lesen. Damit bleiben die Alarme für Erschöpfung, Ertrinken und Angriffe, während du AFK bist; Zauber und Lava lassen sich nicht erkennen."
    L["Attacked while away"] = "Angriff, während du AFK bist"
    L["An alarm when you get into a fight while you are marked as away."] =
        "Ein Alarm, wenn du in einen Kampf gerätst, während du als abwesend markiert bist."
    L["Alarms"]                  = "Alarme"
    L["High damage"]             = "Hoher Schaden"
    L["Something that kills you quickly: get out now."] = "Etwas, das dich schnell tötet: sofort raus."
    L["Low damage"]              = "Geringer Schaden"
    L["Something that hurts, but slowly: move when you can."] = "Etwas, das schadet, aber langsam: weg, sobald es geht."
    L["Still standing in it"]    = "Immer noch drin"
    L["You are still in it a moment after the first alarm."] = "Du stehst einen Moment nach dem ersten Alarm immer noch darin."
    L["Friendly fire"]           = "Eigenbeschuss"
    L["Something of yours is hurting your group."] = "Etwas von dir schadet deiner Gruppe."
    L["Test"]                    = "Testen"
    L["Sound"]                   = "Ton"
    L["Volume"]                  = "Lautstärke"
    L["Quiet"]                   = "Leise"
    L["Soft"]                    = "Gedämpft"
    L["Normal"]                  = "Normal"
    L["Louder"]                  = "Lauter"
    L["Loudest"]                 = "Am lautesten"
    L["Sound channel"]           = "Tonkanal"
    L["Even when the sound is off"] = "Auch wenn der Ton aus ist"
    L["Switches the sound on for a moment for the alarm, when the game sound or the channel is muted."] =
        "Schaltet den Ton für den Alarm kurz ein, wenn der Spielton oder der Kanal stumm ist."
    L["When to warn"]            = "Wann warnen"
    L["Also for harmless hits"]  = "Auch bei harmlosen Treffern"
    L["Normally there is no alarm for things that take only a little of your health."] =
        "Normalerweise gibt es keinen Alarm für Dinge, die dir nur wenig Leben nehmen."
    L["Harmless below"]          = "Harmlos unter"
    L["of your health per hit"]  = "deiner Lebenspunkte pro Treffer"
    L["Lava, slime and campfires"] = "Lava, Schleim und Lagerfeuer"
    L["Fatigue"]                 = "Erschöpfung"
    L["Out in the deep sea, where you start to tire."] = "Draussen im tiefen Meer, wo du erschöpft wirst."
    L["Drowning"]                = "Ertrinken"
    L["When your breath runs out."] = "Wenn dir die Luft ausgeht."
    L["Damage while away"]       = "Schaden, während du AFK bist"
    L["An alarm when something hits you while you are marked as away."] =
        "Ein Alarm, wenn dich etwas trifft, während du als abwesend markiert bist."
    L["Last alarms"]             = "Letzte Alarme"
    L["A spell that should not sound an alarm for you can be ignored here."] =
        "Ein Zauber, der für dich keinen Alarm auslösen soll, lässt sich hier ignorieren."
    L["No alarms yet."]          = "Noch keine Alarme."
    L["Ignore"]                  = "Ignorieren"
    L["Ignored spells"]          = "Ignorierte Zauber"
    L["None."]                   = "Keine."
    L["Release"]                 = "Freigeben"
    L["Environment"]             = "Umgebung"
    L["High damage from"]        = "Hoher Schaden ab"
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local VOLUMES = {
    { value = 1, label = L["Quiet"] }, { value = 2, label = L["Soft"] }, { value = 3, label = L["Normal"] },
    { value = 4, label = L["Louder"] }, { value = 5, label = L["Loudest"] },
}

local CHANNELS = {
    { value = "Master",   label = _G.MASTER_VOLUME or "Master" },
    { value = "SFX",      label = _G.SOUND_VOLUME or "Sound",       cvar = "Sound_EnableSFX" },
    { value = "Ambience", label = _G.AMBIENCE_VOLUME or "Ambience", cvar = "Sound_EnableAmbience" },
    { value = "Music",    label = _G.MUSIC_VOLUME or "Music",       cvar = "Sound_EnableMusic" },
    { value = "Dialog",   label = _G.DIALOG_VOLUME or "Dialog",     cvar = "Sound_EnableDialog" },
}

-- Without the combat log (WoW Forever, Retail from Midnight on) only what
-- needs no combat log; told apart by the interface version.
local TOC = select(4, GetBuildInfo()) or 0
local LIMITED = (TOC > 16000 and TOC < 20000) or TOC >= 120000 or CombatLogGetCurrentEventInfo == nil

local M = AIO:NewModule("gtfo", {
    title    = L["Danger alarm"],
    short    = L["A loud alarm when you stand in something that hurts: fire on the floor, poison clouds, boss abilities you should step out of."],
    desc     = L["Four different alarms tell you how bad it is. Areas on the ground are recognised by themselves: damage that keeps ticking on you without a debuff."],
    category = "gtfo",
    default  = true,
    defaults = {
        s1 = true, s2 = true, s3 = true, s4 = true,
        volume = 3, channel = "Master", unmute = false,
        trivial = false, trivialPct = 2, highPct = 8,
        lava = true, fatigue = true, drowning = true, afk = false,
        ignore = {},
    },
})
M.slash = "alarm"

-- ---------------------------------------------------------------------------
-- Sounds
-- ---------------------------------------------------------------------------

-- Our own alarms (Media\alarm), each in three volumes.
local SOUND_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\alarm\\"
local SOUND_NAMES = { "high", "low", "stuck", "friendly" }
local SOUND_LEN = { 0.5, 0.3, 0.4, 0.5 }
local quietUntil = 0
local muted       -- cvars switched on for an alarm: { [cvar] = old value }

local function Unmute(seconds)
    local db = M.db
    if not muted then
        muted = {}
        local cvars = { "Sound_EnableAllSound" }
        for _, c in ipairs(CHANNELS) do
            if c.value == db.channel and c.cvar then cvars[2] = c.cvar end
        end
        for _, cv in ipairs(cvars) do
            local old = GetCVar(cv)
            if old ~= "1" then
                muted[cv] = old
                SetCVar(cv, 1)
            end
        end
    end
    C_Timer.After(seconds + 0.1, function()
        if not muted then return end
        for cv, old in pairs(muted) do SetCVar(cv, old) end
        muted = nil
    end)
end

--- Plays alarm `kind` (1-4). `test`: from the options page, always heard.
function M:Alarm(kind, test)
    if not kind or kind < 1 or kind > 4 then return end
    local db = self.db
    if not test and not db["s" .. kind] then return end
    local now = GetTime()
    if not test and now < quietUntil then return end
    quietUntil = now + 0.2
    if db.unmute then Unmute(SOUND_LEN[kind]) end
    local v = db.volume
    local suffix = v == 1 and "_quiet" or v == 2 and "_soft" or ""
    local file = SOUND_DIR .. SOUND_NAMES[kind] .. suffix .. ".ogg"
    -- Louder and loudest: the same alarm two or three times at once.
    for _ = 1, (v >= 5 and 3 or v >= 4 and 2 or 1) do
        PlaySoundFile(file, db.channel)
    end
end

-- ---------------------------------------------------------------------------
-- Recognising areas on the ground
-- ---------------------------------------------------------------------------

local function HasDebuff(spellID)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, id = UnitAura("player", i, "HARMFUL")
        if not name then return false end
        if id == spellID then return true end
    end
    return false
end

--- Share of your health a hit takes (0-100), or nil when unknown.
local function Pct(damage)
    local max = UnitHealthMax("player")
    if not (max and max > 0 and damage) then return nil end
    return damage * 100 / max
end

-- Per spell that hit you lately: { last = time, hits = n, first = time of
-- the first alarm, stuck = time of the last "still in it" alarm }.
local hits = {}
local WINDOW = 3      -- seconds between two ticks of the same area
local STUCK  = 2      -- seconds after the first alarm: "still standing in it"

-- ---------------------------------------------------------------------------
-- Recent alarms (for the options page)
-- ---------------------------------------------------------------------------

local recent = {}   -- newest first, at most 8: { id, name, kind }
local RefreshPage

local function Remember(id, name, kind)
    for i = #recent, 1, -1 do
        if recent[i][1] == id then table.remove(recent, i) end
    end
    table.insert(recent, 1, { id, name, kind })
    recent[9] = nil
    if RefreshPage then RefreshPage() end
end

-- ---------------------------------------------------------------------------
-- The combat log
-- ---------------------------------------------------------------------------

local me
local AFFILIATION_GROUP = 0x00000006   -- in your party or raid
local REACTION_FRIENDLY = 0x00000010
local PLAYER_CONTROLLED = 0x00000100   -- controlled by a player (players, pets)
local DAMAGE = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }

local function Environment(kind, damage)
    local db = M.db
    local alarm
    if kind == "DROWNING" then
        if not db.drowning then return end
        alarm = 1
    elseif kind == "FATIGUE" then
        if not db.fatigue then return end
        alarm = 1
    elseif kind ~= "FALLING" then
        -- Lava, slime, fire (campfires).
        if not db.lava then return end
        if not db.trivial then
            local max = UnitHealthMax("player")
            if max and max > 0 and damage * 100 / max < db.trivialPct then return end
        end
        alarm = 2
    end
    if alarm then
        M:Alarm(alarm)
        Remember(0, L["Environment"] .. ": " .. (_G["ACTION_ENVIRONMENTAL_DAMAGE_" .. kind] or kind), alarm)
    end
end

--- Damage from a spell hit you. An area on the ground ticks again and again
--- without leaving a debuff of that spell on you; one hit alone is not one.
local function OnSpell(ev, sourceGUID, sourceFlags, id, name, damage)
    local db = M.db
    if db.ignore[id] or sourceGUID == me then return end
    if band(sourceFlags or 0, PLAYER_CONTROLLED) ~= 0 then return end   -- players and pets: PvP, duels
    local now = GetTime()
    local h = hits[id]
    if not h or now - h.last > WINDOW then
        h = { hits = 0 }
        hits[id] = h
    end
    h.last = now
    h.hits = h.hits + 1
    -- A periodic tick is an area at once; a direct hit only from the second one.
    local periodic = ev == "SPELL_PERIODIC_DAMAGE"
    if h.hits < (periodic and 1 or 2) then return end
    if HasDebuff(id) then return end
    local pct = Pct(damage)
    if not db.trivial and pct and pct < db.trivialPct then return end
    local alarm
    if not h.first then
        h.first = now
        alarm = (pct and pct >= db.highPct) and 1 or 2
    elseif now - h.first >= STUCK and now - (h.stuck or 0) >= STUCK then
        h.stuck = now
        alarm = 3
    end
    if alarm then
        M:Alarm(alarm)
        Remember(id, name, alarm)
    end
end

--- Something of yours hurt someone in your group.
local function OnFriendlyFire(id, name, destGUID, destFlags, damage)
    if M.db.ignore[id] or destGUID == me then return end
    if band(destFlags or 0, AFFILIATION_GROUP) == 0 or band(destFlags or 0, REACTION_FRIENDLY) == 0 then return end
    local pct = Pct(damage)
    if not M.db.trivial and pct and pct < M.db.trivialPct then return end
    M:Alarm(4)
    Remember(id, name, 4)
end

local function OnCombatLog()
    local _, ev, _, sourceGUID, _, sourceFlags, _, destGUID, _, destFlags, _, a1, a2, a3, a4 = CombatLogGetCurrentEventInfo()
    if destGUID == me then
        if M.db.afk and UnitIsAFK("player") then
            local dmg = ev == "SWING_DAMAGE" and a1 or ev == "ENVIRONMENTAL_DAMAGE" and a2
                or (ev:find("_DAMAGE", 1, true) and a4)
            if (tonumber(dmg) or 0) > 0 then M:Alarm(1) end
        end
        if ev == "ENVIRONMENTAL_DAMAGE" then
            Environment(tostring(a1):upper(), tonumber(a2) or 0)
        elseif DAMAGE[ev] and not UnitIsCharmed("player") then
            OnSpell(ev, sourceGUID, sourceFlags, a1, a2, tonumber(a4) or 0)
        end
    elseif sourceGUID == me and DAMAGE[ev] then
        OnFriendlyFire(a1, a2, destGUID, destFlags, tonumber(a4) or 0)
    end
end

-- Without the combat log, drowning is seen on the breath bar: an alarm once
-- it has run out. Checked five times a second, only while the bar is there.
local breath
local function WatchBreath(on)
    if breath then breath:Cancel(); breath = nil end
    if not on then return end
    local warned = false
    breath = C_Timer.NewTicker(0.2, function()
        if warned then return end
        local left = GetMirrorTimerProgress("BREATH")
        if left and left <= 0 then
            warned = true
            if M.db.drowning then
                M:Alarm(1)
                Remember(0, L["Drowning"], 1)
            end
        end
    end)
end

local driver
local function OnEvent(_, event, timer, _, _, scale)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    elseif event == "MIRROR_TIMER_START" then
        -- Fatigue: the bar starts running down when you swim too far out.
        if timer == "EXHAUSTION" and (scale or 0) < 0 and M.db.fatigue then
            M:Alarm(1)
            Remember(0, L["Fatigue"], 1)
        elseif timer == "BREATH" and LIMITED then
            WatchBreath(true)
        end
    elseif event == "MIRROR_TIMER_STOP" then
        if timer == "BREATH" then WatchBreath(false) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Pulled into a fight while away.
        if M.db.afk and UnitIsAFK("player") then M:Alarm(1) end
    end
end

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

local function TestButton(kind)
    return { type = "button", label = L["Test"], width = 100, half = true, func = function(m) m:Alarm(kind, true) end }
end

--- The last alarms with an "Ignore" button, then the ignored spells. Drawn
--- again (rows reused) whenever the page refreshes.
local KIND = { L["High damage"], L["Low damage"], L["Still standing in it"], L["Friendly fire"] }

local function SpellLabel(id)
    return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or GetSpellInfo(id) or "?"
end

local function BuildRecent(parent, width, m)
    local rows, used, y = {}, 0, 0
    local head = Style.Text(parent, 13, Style.color.accent)
    head:SetText(L["Ignored spells"])
    local function line(text, button, onClick)
        used = used + 1
        local f = rows[used]
        if not f then
            f = CreateFrame("Frame", nil, parent)
            f:SetSize(width, 24)
            f.text = Style.Text(f, 12)
            f.text:SetPoint("LEFT")
            f.text:SetWidth(width - 130)
            f.text:SetWordWrap(false)
            f.button = Style.Button(f, "", 110, 20, function(b) if b.onClick then b.onClick() end end)
            f.button:SetPoint("RIGHT", -6, 0)
            rows[used] = f
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -y)
        f.text:SetText(text)
        f.button:SetShown(button ~= nil)
        if button then
            f.button:SetText(button)
            f.button.onClick = onClick
        end
        f:Show()
        y = y + 24
    end
    local function changed()
        AIO:SettingChanged(m, "ignore")
    end
    function parent:Update()
        used, y = 0, 0
        if #recent == 0 then line("|cff999999" .. L["No alarms yet."] .. "|r") end
        for _, r in ipairs(recent) do
            local id, name, kind = r[1], r[2], r[3]
            local label = ("%s  |cff999999%s%s|r"):format(name or "?", KIND[kind] or "", id > 0 and (" · " .. id) or "")
            if id > 0 and not m.db.ignore[id] then
                line(label, L["Ignore"], function() m.db.ignore[id] = true; changed() end)
            else
                line(label)
            end
        end
        y = y + 8
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
        local any = false
        for id in pairs(m.db.ignore) do
            any = true
            line(("%s  |cff999999%d|r"):format(SpellLabel(id), id), L["Release"], function() m.db.ignore[id] = nil; changed() end)
        end
        if not any then line("|cff999999" .. L["None."] .. "|r") end
        for i = used + 1, #rows do rows[i]:Hide() end
        -- The page grows or shrinks with the list (it is the last entry).
        local old = self:GetHeight() or 0
        self:SetHeight(y)
        local content = self:GetParent()
        if content and old > 0 and old ~= y then content:SetHeight((content:GetHeight() or 0) + y - old) end
        return y
    end
    return parent:Update()
end

M.options = {
    { type = "header", label = L["Alarms"] },
    { type = "toggle", key = "s1", label = L["High damage"], desc = L["Something that kills you quickly: get out now."], half = true },
    TestButton(1),
    { type = "toggle", key = "s2", label = L["Low damage"], desc = L["Something that hurts, but slowly: move when you can."], half = true },
    TestButton(2),
    { type = "toggle", key = "s3", label = L["Still standing in it"], desc = L["You are still in it a moment after the first alarm."], half = true },
    TestButton(3),
    { type = "toggle", key = "s4", label = L["Friendly fire"], desc = L["Something of yours is hurting your group."], half = true },
    TestButton(4),

    { type = "header", label = L["Sound"] },
    { type = "select", key = "volume", label = L["Volume"], values = VOLUMES, half = true },
    { type = "select", key = "channel", label = L["Sound channel"], values = CHANNELS, half = true },
    { type = "toggle", key = "unmute", label = L["Even when the sound is off"], desc = L["Switches the sound on for a moment for the alarm, when the game sound or the channel is muted."] },

    { type = "header", label = L["When to warn"] },
    { type = "toggle", key = "trivial", label = L["Also for harmless hits"], desc = L["Normally there is no alarm for things that take only a little of your health."] },
    { type = "slider", key = "trivialPct", label = L["Harmless below"] .. " (" .. L["of your health per hit"] .. ")", min = 1, max = 20, step = 1,
      format = function(v) return v .. "%" end, disabled = function(m) return m.db.trivial end },
    { type = "slider", key = "highPct", label = L["High damage from"] .. " (" .. L["of your health per hit"] .. ")", min = 3, max = 30, step = 1,
      format = function(v) return v .. "%" end },
    { type = "toggle", key = "lava", label = L["Lava, slime and campfires"], half = true },
    { type = "toggle", key = "fatigue", label = L["Fatigue"], desc = L["Out in the deep sea, where you start to tire."], half = true },
    { type = "toggle", key = "drowning", label = L["Drowning"], desc = L["When your breath runs out."], half = true },
    { type = "toggle", key = "afk", label = L["Damage while away"], desc = L["An alarm when something hits you while you are marked as away."], half = true },

    { type = "header", label = L["Last alarms"] },
    { type = "text", label = L["A spell that should not sound an alarm for you can be ignored here."] },
    { type = "custom", build = BuildRecent },
}

-- Without the combat log: only what works without it.
if LIMITED then
    M.options = {
        { type = "text", label = L["This game version does not let addons read the combat log. That leaves the alarms for fatigue, drowning and being attacked while you are away; spells and lava cannot be recognised."] },
        { type = "header", label = L["Alarms"] },
        { type = "toggle", key = "s1", label = L["High damage"], desc = L["Something that kills you quickly: get out now."], half = true },
        TestButton(1),
        { type = "header", label = L["Sound"] },
        { type = "select", key = "volume", label = L["Volume"], values = VOLUMES, half = true },
        { type = "select", key = "channel", label = L["Sound channel"], values = CHANNELS, half = true },
        { type = "toggle", key = "unmute", label = L["Even when the sound is off"], desc = L["Switches the sound on for a moment for the alarm, when the game sound or the channel is muted."] },
        { type = "header", label = L["When to warn"] },
        { type = "toggle", key = "fatigue", label = L["Fatigue"], desc = L["Out in the deep sea, where you start to tire."], half = true },
        { type = "toggle", key = "drowning", label = L["Drowning"], desc = L["When your breath runs out."], half = true },
        { type = "toggle", key = "afk", label = L["Attacked while away"], desc = L["An alarm when you get into a fight while you are marked as away."] },
        { type = "header", label = L["Last alarms"] },
        { type = "custom", build = BuildRecent },
    }
end

-- The page is drawn once; a new alarm or a change redraws it while it is open.
RefreshPage = function()
    AIO:Later("gtfoPage", function()
        local p = AIO.optionsPanel or _G.AllInOneOptions
        if p and p:IsShown() and p.RefreshPage then p:RefreshPage() end
    end)
end

-- ---------------------------------------------------------------------------
-- On and off
-- ---------------------------------------------------------------------------

function M:OnEnable()
    me = UnitGUID("player")
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
    end
    driver:RegisterEvent("MIRROR_TIMER_START")
    if LIMITED then
        driver:RegisterEvent("MIRROR_TIMER_STOP")
        driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    else
        driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

function M:OnDisable()
    if driver then driver:UnregisterAllEvents() end
    WatchBreath(false)
end

function M:Slash(rest)
    local n = tonumber(rest)
    if n then self:Alarm(n, true) else AIO:OpenOptions("gtfo") end
end
