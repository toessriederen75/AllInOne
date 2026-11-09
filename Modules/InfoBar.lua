-- AllInOne: info bar. A thin flat bar, as wide as its segments and placed
-- anywhere on the screen (unlock, drag, lock)
-- with gold, durability, bag space, PvP points, experience, performance,
-- clock, coordinates, guild and mail. UIParent itself is never moved.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Info bar"]           = "Infoleiste"
    L["A bar with gold, durability, bag space, experience, clock and more."] =
        "Eine Leiste mit Gold, Haltbarkeit, Taschenplatz, Erfahrung, Uhr und mehr."
    L["Lock position"]      = "Position sperren"
    L["Grow from"]          = "Wächst ab"
    L["Left edge"]          = "Linkem Rand"
    L["Centre"]             = "Mitte"
    L["Right edge"]         = "Rechtem Rand"
    L["Reset position"]     = "Position zurücksetzen"
    L["Alt + drag moves the bar even while it is locked."] = "Mit Alt + Ziehen lässt sich die Leiste auch gesperrt verschieben."
    L["Unlock, drag the bar where you want it, then lock it again."] =
        "Entsperren, die Leiste an den gewünschten Ort ziehen und wieder sperren."
    L["Drag to move. Lock it in the options."] = "Ziehen zum Verschieben. Sperren in den Optionen."
    L["A flat bar you can place anywhere; it is exactly as wide as the segments you switch on. Every segment can be switched on and off on its own; hover a segment for details, click it for the matching window."] =
        "Eine flache Leiste, die du frei platzierst; sie ist genau so breit wie die eingeschalteten Segmente. Jedes Segment lässt sich einzeln ein- und ausschalten; Maus darüber zeigt Details, ein Klick öffnet das passende Fenster."
    L["A flat bar across the top or bottom edge of the screen. Every segment can be switched on and off on its own; hover a segment for details, click it for the matching window."] =
        "Eine flache Leiste am oberen oder unteren Bildschirmrand. Jedes Segment lässt sich einzeln ein- und ausschalten; mit der Maus darüber gibt es Details, ein Klick öffnet das passende Fenster."
    L["Layout"]             = "Darstellung"
    L["Position"]           = "Position"
    L["Top"]                = "Oben"
    L["Bottom"]             = "Unten"
    L["Height"]             = "Höhe"
    L["Font size"]          = "Schriftgrösse"
    L["24-hour clock"]      = "24-Stunden-Uhr"
    L["Segments"]           = "Segmente"
    L["Gold"]               = "Gold"
    L["Durability"]         = "Haltbarkeit"
    L["Bag space"]          = "Taschenplatz"
    L["Honor & arena points"] = "Ehre & Arenapunkte"
    L["Experience"]         = "Erfahrung"
    L["Performance"]        = "Leistung"
    L["Clock"]              = "Uhr"
    L["Coordinates"]        = "Koordinaten"
    L["Guild"]              = "Gilde"
    L["Mail"]               = "Post"
    L["This session"]       = "Diese Sitzung"
    L["Lowest"]             = "Niedrigste"
    L["Click: character window"] = "Klick: Charakterfenster"
    L["Click: bags"]        = "Klick: Taschen"
    L["Free bag slots"]     = "Freie Taschenplätze"
    L["Special bags"]       = "Spezialtaschen"
    L["Honor"]              = "Ehre"
    L["Arena"]              = "Arena"
    L["Honor points"]       = "Ehrenpunkte"
    L["Arena points"]       = "Arenapunkte"
    L["Honorable kills"]    = "Ehrenhafte Siege"
    L["XP"]                 = "EP"
    L["Rested"]             = "Ausgeruht"
    L["Current"]            = "Aktuell"
    L["Remaining"]          = "Verbleibend"
    L["XP per hour"]        = "EP pro Stunde"
    L["Time to level"]      = "Zeit bis zum Stufenaufstieg"
    L["Home latency"]       = "Latenz (Heim)"
    L["World latency"]      = "Latenz (Welt)"
    L["Frame rate"]         = "Bildrate"
    L["Bandwidth in / out"] = "Bandbreite ein / aus"
    L["Local time"]         = "Ortszeit"
    L["Realm time"]         = "Realmzeit"
    L["Click: world map"]   = "Klick: Weltkarte"
    L["Click: guild window"] = "Klick: Gildenfenster"
    L["%d online"]          = "%d online"
    L["Online members"]     = "Mitglieder online"
    L["... and %d more"]    = "... und %d weitere"
    L["New mail"]           = "Neue Post"
    L["From:"]              = "Von:"
end

local SEGMENT_KEYS = { "gold", "durability", "bags", "honor", "xp", "perf", "clock", "coords", "guild", "mail" }

local M = AIO:NewModule("infobar", {
    title    = L["Info bar"],
    short    = L["A bar with gold, durability, bag space, experience, clock and more."],
    desc     = L["A flat bar you can place anywhere; it is exactly as wide as the segments you switch on. Every segment can be switched on and off on its own; hover a segment for details, click it for the matching window."],
    category = "display",
    default  = true,
    defaults = {
        locked = true, grow = "CENTER", height = 20, fontSize = 11, alpha = 0.85, clock24 = true,
        gold = true, durability = true, bags = true, honor = true, xp = true,
        perf = true, clock = true, coords = true, guild = true, mail = true,
    },
})

local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end

M.options = {
    { type = "header", label = L["Layout"] },
    { type = "text",   label = L["Unlock, drag the bar where you want it, then lock it again."] .. " " .. L["Alt + drag moves the bar even while it is locked."] },
    { type = "toggle", key = "locked", label = L["Lock position"], half = true },
    { type = "toggle", key = "clock24", label = L["24-hour clock"], half = true },
    { type = "select", key = "grow", label = L["Grow from"], half = true,
      values = { { value = "LEFT", label = L["Left edge"] }, { value = "CENTER", label = L["Centre"] },
                 { value = "RIGHT", label = L["Right edge"] } } },
    { type = "button", label = L["Reset position"], func = function(m)
        m.db.x, m.db.y = nil, nil
        m:Layout()
    end },
    { type = "slider", key = "height",   label = L["Height"],    min = 14, max = 32, step = 1, half = true },
    { type = "slider", key = "fontSize", label = L["Font size"], min = 8,  max = 18, step = 1, half = true },
    { type = "slider", key = "alpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05, format = Percent },
    { type = "header", label = L["Segments"] },
    { type = "toggle", key = "gold",       label = L["Gold"],                 half = true },
    { type = "toggle", key = "durability", label = L["Durability"],           half = true },
    { type = "toggle", key = "bags",       label = L["Bag space"],            half = true },
    { type = "toggle", key = "honor",      label = L["Honor & arena points"], half = true },
    { type = "toggle", key = "xp",         label = L["Experience"],           half = true },
    { type = "toggle", key = "perf",       label = L["Performance"],          half = true },
    { type = "toggle", key = "clock",      label = L["Clock"],                half = true },
    { type = "toggle", key = "coords",     label = L["Coordinates"],          half = true },
    { type = "toggle", key = "guild",      label = L["Guild"],                half = true },
    { type = "toggle", key = "mail",       label = L["Mail"],                 half = true },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function Hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local function Colored(c, text) return Hex(c) .. text .. "|r" end
local function Label(text) return Colored(C.muted, text) end

local function Number(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local function Duration(sec)
    sec = math.floor(sec or 0)
    local h = math.floor(sec / 3600)
    local m = math.floor(sec / 60) % 60
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm %02ds"):format(m, sec % 60)
end

local function PctColor(p)
    if p >= 50 then return C.good elseif p >= 25 then return C.warn end
    return C.bad
end

local function Tip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    -- Above the bar in the lower half of the screen, below it otherwise.
    local _, y = owner:GetCenter()
    if y and y < (UIParent:GetHeight() or 0) / 2 then
        GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
    else
        GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -4)
    end
end

local function Line(left, right)
    GameTooltip:AddDoubleLine(left, right, C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
end

local function Hint(text)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(text, C.accent[1], C.accent[2], C.accent[3])
end

local function MaxLevel()
    local lvl = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL
    return tonumber(lvl) or 70
end

local function AtMaxLevel()
    if IsXPUserDisabled and IsXPUserDisabled() then return true end
    return (UnitLevel("player") or 1) >= MaxLevel()
end

-- ---------------------------------------------------------------------------
-- Session tracking
-- ---------------------------------------------------------------------------

local session = {}

local function StartSession()
    if session.started then return end
    session.started = true
    session.money = GetMoney()
    session.time = GetTime()
    session.xpGained = 0
    session.lastXP = UnitXP("player") or 0
    session.lastMax = UnitXPMax("player") or 1
end

local function TrackXP()
    if not session.started then return end
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if cur < session.lastXP then
        -- levelled up: the rest of the old level plus what is in the new one
        session.xpGained = session.xpGained + math.max(0, session.lastMax - session.lastXP) + cur
    else
        session.xpGained = session.xpGained + (cur - session.lastXP)
    end
    session.lastXP, session.lastMax = cur, max
end

-- ---------------------------------------------------------------------------
-- Segments: text() returns the text or nil to hide; tip(self) fills
-- GameTooltip; click(self, button) is optional; every = seconds between
-- refreshes by the ticker (events refresh at once).
-- ---------------------------------------------------------------------------

local guildOnline, guildList, lastRoster = 0, {}, nil

local function RequestRoster(force)
    if not (IsInGuild and IsInGuild()) then return end
    local now = GetTime()
    if not force and lastRoster and now - lastRoster < 60 then return end
    lastRoster = now
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        pcall(GuildRoster)
    end
end

local function ReadRoster()
    guildList = {}
    if not (IsInGuild and IsInGuild()) or not GetNumGuildMembers then
        guildOnline = 0
        return
    end
    local total, online = GetNumGuildMembers()
    local count = 0
    for i = 1, total or 0 do
        local name, _, _, level, _, zone, _, _, isOnline, _, class = GetGuildRosterInfo(i)
        if name and isOnline then
            count = count + 1
            guildList[#guildList + 1] = {
                name = Ambiguate and Ambiguate(name, "guild") or name:gsub("%-.*$", ""),
                level = level, zone = zone, class = class,
            }
        end
    end
    guildOnline = online or count
    table.sort(guildList, function(a, b) return a.name < b.name end)
end

local SLOT_NAMES = {
    [1] = "HEADSLOT", [3] = "SHOULDERSLOT", [5] = "CHESTSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT",
    [8] = "FEETSLOT", [9] = "WRISTSLOT", [10] = "HANDSSLOT", [16] = "MAINHANDSLOT",
    [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT",
}

local function Durability()
    local lowest, list = nil, {}
    if not GetInventoryItemDurability then return nil, list end
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local p = cur / max * 100
            if not lowest or p < lowest then lowest = p end
            list[#list + 1] = { slot = slot, pct = p }
        end
    end
    return lowest, list
end

local function BagSpace()
    local free, total = 0, 0
    for bag = AIO.BACKPACK, AIO.NUM_BAGS do
        if AIO.BagFamily(bag) == 0 then
            free = free + AIO.FreeSlots(bag)
            total = total + AIO.NumSlots(bag)
        end
    end
    return free, total
end

local function Currency(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and type(info) == "table" then return info.quantity or 0 end
    end
    return 0
end

local function HonorPoints()
    if GetHonorCurrency then return GetHonorCurrency() or 0 end
    return Currency(1901)
end

local function ArenaPoints()
    if GetArenaCurrency then return GetArenaCurrency() or 0 end
    return Currency(1900)
end

local function PlayerPosition()
    if IsInInstance and IsInInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not x or (x == 0 and y == 0) then return nil end
    return x * 100, y * 100
end

local function ClockText(h, m)
    if M.db.clock24 then return ("%02d:%02d"):format(h, m) end
    local suffix = h >= 12 and "PM" or "AM"
    h = h % 12
    if h == 0 then h = 12 end
    return ("%d:%02d %s"):format(h, m, suffix)
end

local segments = {
    {
        key = "gold", every = 60, events = { "PLAYER_MONEY" },
        text = function() return AIO.Money(GetMoney()) end,
        tip = function(self)
            AIO:ShowMoneyTooltip(self)
            local diff = GetMoney() - (session.money or GetMoney())
            local text = AIO.Money(math.abs(diff))
            if diff > 0 then text = "|cff4dd966+|r" .. text elseif diff < 0 then text = "|cfff24d4d-|r" .. text end
            GameTooltip:AddDoubleLine(L["This session"], text, C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
            GameTooltip:Show()
        end,
        click = function() AIO:Toggle("inventory") end,
    },
    {
        key = "durability", every = 60, icon = "Interface\\Icons\\Trade_BlackSmithing",
        events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
        text = function()
            local p = Durability()
            if not p then return Colored(C.good, "100%") end
            return Colored(PctColor(p), ("%d%%"):format(p))
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(L["Durability"], 1, 1, 1)
            local lowest, list = Durability()
            for _, e in ipairs(list) do
                local name = SLOT_NAMES[e.slot] and _G[SLOT_NAMES[e.slot]] or ("#" .. e.slot)
                local c = PctColor(e.pct)
                GameTooltip:AddDoubleLine(name, ("%d%%"):format(e.pct), 1, 1, 1, c[1], c[2], c[3])
            end
            if lowest then Line(L["Lowest"], ("%d%%"):format(lowest)) end
            Hint(L["Click: character window"])
            GameTooltip:Show()
        end,
        click = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end,
    },
    {
        key = "bags", every = 60, icon = "Interface\\Icons\\INV_Misc_Bag_08", events = { "BAG_UPDATE_DELAYED" },
        text = function()
            local free, total = BagSpace()
            local c = (total > 0 and free / total < 0.1) and C.bad or C.text
            return Colored(c, ("%d/%d"):format(free, total))
        end,
        tip = function(self)
            Tip(self)
            local free, total = BagSpace()
            GameTooltip:AddDoubleLine(L["Free bag slots"], ("%d/%d"):format(free, total), 1, 1, 1, 1, 1, 1)
            local special = false
            for bag = AIO.BACKPACK + 1, AIO.NUM_BAGS do
                if AIO.BagFamily(bag) ~= 0 and AIO.NumSlots(bag) > 0 then
                    if not special then GameTooltip:AddLine(L["Special bags"], C.muted[1], C.muted[2], C.muted[3]) end
                    special = true
                    local name = GetBagName and GetBagName(bag) or ("#" .. bag)
                    Line(name, ("%d/%d"):format(AIO.FreeSlots(bag), AIO.NumSlots(bag)))
                end
            end
            Hint(L["Click: bags"])
            GameTooltip:Show()
        end,
        click = function() AIO:Toggle("inventory") end,
    },
    {
        key = "honor", every = 60,
        events = { "HONOR_CURRENCY_UPDATE", "ARENA_CURRENCY_UPDATE", "CURRENCY_DISPLAY_UPDATE", "PLAYER_PVP_KILLS_CHANGED" },
        text = function()
            return ("%s %s  %s %s"):format(Colored({ 1, 0.82, 0 }, L["Honor"]), Number(HonorPoints()),
                                           Colored({ 0.65, 0.5, 1 }, L["Arena"]), Number(ArenaPoints()))
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(L["Honor & arena points"], 1, 1, 1)
            Line(L["Honor points"], Number(HonorPoints()))
            Line(L["Arena points"], Number(ArenaPoints()))
            if GetPVPLifetimeStats then
                local kills = GetPVPLifetimeStats()
                if kills then Line(L["Honorable kills"], Number(kills)) end
            end
            GameTooltip:Show()
        end,
    },
    {
        key = "xp", every = 30, events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" },
        text = function()
            if AtMaxLevel() then return nil end
            local cur, max = UnitXP("player") or 0, math.max(1, UnitXPMax("player") or 1)
            local text = ("%s %.1f%%"):format(Label(L["XP"]), cur / max * 100)
            local rested = GetXPExhaustion and GetXPExhaustion()
            if rested and rested > 0 then
                text = text .. " " .. Colored({ 0.3, 0.6, 1 }, ("+%d%%"):format(rested / max * 100))
            end
            return text
        end,
        tip = function(self)
            Tip(self)
            local cur, max = UnitXP("player") or 0, math.max(1, UnitXPMax("player") or 1)
            GameTooltip:AddLine(L["Experience"], 1, 1, 1)
            Line(L["Current"], ("%s / %s (%.1f%%)"):format(Number(cur), Number(max), cur / max * 100))
            Line(L["Remaining"], Number(max - cur))
            local rested = GetXPExhaustion and GetXPExhaustion()
            if rested and rested > 0 then
                Line(L["Rested"], ("%s (%.0f%%)"):format(Number(rested), rested / max * 100))
            end
            local elapsed = GetTime() - (session.time or GetTime())
            local gained = session.xpGained or 0
            if elapsed > 0 and gained > 0 then
                local perHour = gained / elapsed * 3600
                Line(L["XP per hour"], Number(perHour))
                Line(L["Time to level"], Duration((max - cur) / perHour * 3600))
            else
                Line(L["XP per hour"], "-")
            end
            GameTooltip:Show()
        end,
    },
    {
        key = "perf", every = 1,
        text = function()
            local fps = GetFramerate and GetFramerate() or 0
            local _, _, home, world = 0, 0, 0, 0
            if GetNetStats then _, _, home, world = GetNetStats() end
            local ms = math.max(home or 0, world or 0)
            local c = ms < 150 and C.good or (ms < 300 and C.warn or C.bad)
            return ("%d %s  %s %s"):format(fps, Label("fps"), Colored(c, tostring(ms)), Label("ms"))
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(L["Performance"], 1, 1, 1)
            Line(L["Frame rate"], ("%.0f fps"):format(GetFramerate and GetFramerate() or 0))
            if GetNetStats then
                local bwIn, bwOut, home, world = GetNetStats()
                Line(L["Home latency"], ("%d ms"):format(home or 0))
                Line(L["World latency"], ("%d ms"):format(world or 0))
                Line(L["Bandwidth in / out"], ("%.1f / %.1f KB/s"):format(bwIn or 0, bwOut or 0))
            end
            GameTooltip:Show()
        end,
    },
    {
        key = "clock", every = 1,
        text = function()
            local t = date("*t")
            return ClockText(t.hour, t.min)
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(L["Clock"], 1, 1, 1)
            local t = date("*t")
            Line(L["Local time"], ClockText(t.hour, t.min))
            if GetGameTime then
                local h, m = GetGameTime()
                Line(L["Realm time"], ClockText(h or 0, m or 0))
            end
            GameTooltip:Show()
        end,
        click = function()
            if TimeManager_Toggle then TimeManager_Toggle() end
        end,
    },
    {
        key = "coords", every = 1, events = { "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS" },
        text = function()
            local x, y = PlayerPosition()
            if not x then return nil end
            return ("%.1f, %.1f"):format(x, y)
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(GetZoneText and GetZoneText() or L["Coordinates"], 1, 1, 1)
            local sub = GetSubZoneText and GetSubZoneText()
            if sub and sub ~= "" then GameTooltip:AddLine(sub, C.muted[1], C.muted[2], C.muted[3]) end
            Hint(L["Click: world map"])
            GameTooltip:Show()
        end,
        click = function() if ToggleWorldMap then ToggleWorldMap() end end,
    },
    {
        key = "guild", every = 60, events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
        text = function()
            if not (IsInGuild and IsInGuild()) then return nil end
            RequestRoster()
            return Label(L["Guild"]) .. " " .. Colored(C.good, tostring(guildOnline))
        end,
        tip = function(self)
            RequestRoster()
            Tip(self)
            local name = GetGuildInfo("player")
            GameTooltip:AddDoubleLine(name or L["Guild"], L["%d online"]:format(guildOnline), 0.25, 1, 0.25, 1, 1, 1)
            local shown = 0
            for _, e in ipairs(guildList) do
                if shown >= 25 then
                    GameTooltip:AddLine(L["... and %d more"]:format(#guildList - shown), C.muted[1], C.muted[2], C.muted[3])
                    break
                end
                shown = shown + 1
                GameTooltip:AddDoubleLine(("%d %s"):format(e.level or 0, AIO.ClassColored(e.name, e.class)),
                                          e.zone or "", 1, 1, 1, C.muted[1], C.muted[2], C.muted[3])
            end
            Hint(L["Click: guild window"])
            GameTooltip:Show()
        end,
        click = function()
            if ToggleGuildFrame then
                local ok = pcall(ToggleGuildFrame)
                if ok then return end
            end
            if ToggleFriendsFrame then ToggleFriendsFrame(3) end
        end,
    },
    {
        key = "mail", every = 60, events = { "UPDATE_PENDING_MAIL", "MAIL_CLOSED", "MAIL_INBOX_UPDATE" },
        text = function()
            if not (HasNewMail and HasNewMail()) then return nil end
            return Colored(C.warn, L["New mail"])
        end,
        tip = function(self)
            Tip(self)
            GameTooltip:AddLine(L["New mail"], 1, 1, 1)
            if GetLatestThreeSenders then
                local senders = { GetLatestThreeSenders() }
                if #senders > 0 then
                    GameTooltip:AddLine(L["From:"], C.muted[1], C.muted[2], C.muted[3])
                    for _, s in ipairs(senders) do GameTooltip:AddLine(s, 1, 1, 1) end
                end
            end
            GameTooltip:Show()
        end,
    },
}
M.segments = segments

-- ---------------------------------------------------------------------------
-- The bar
-- ---------------------------------------------------------------------------

local bar
local PAD, ICON_GAP = 10, 4

local function SegmentFrame(seg)
    local b = CreateFrame("Button", nil, bar)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.hl = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.hl:SetTexture(Style.WHITE)
    b.hl:SetAllPoints()
    b.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 0.6)
    b.hl:Hide()
    if seg.icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(seg.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetPoint("LEFT", PAD / 2, 0)
    end
    b.text = Style.Text(b, M.db.fontSize)
    b.sep = bar:CreateTexture(nil, "ARTWORK")
    b.sep:SetTexture(Style.WHITE)
    b.sep:SetVertexColor(C.line[1], C.line[2], C.line[3], 1)
    b.sep:SetWidth(1)
    b.seg = seg
    b:SetScript("OnEnter", function(self)
        self.hl:Show()
        if seg.tip then
            local ok, err = pcall(seg.tip, self)
            if not ok then geterrorhandler()(err) end
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.hl:Hide()
        GameTooltip_Hide()
    end)
    b:SetScript("OnClick", function(self, button)
        if bar.dragEnd and GetTime() - bar.dragEnd < 0.3 then return end
        if seg.click then seg.click(self, button) end
    end)
    -- Dragging a segment moves the whole bar while it is unlocked.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() M:StartDrag() end)
    b:SetScript("OnDragStop", function() M:StopDrag() end)
    seg.frame = b
    return b
end

-- ---------------------------------------------------------------------------
-- Position: saved as the top edge plus the left edge, the centre or the right
-- edge (whichever the bar grows from), so a wider bar never shifts the side
-- it is anchored on.
-- ---------------------------------------------------------------------------

local GROW_POINT = { LEFT = "TOPLEFT", CENTER = "TOP", RIGHT = "TOPRIGHT" }

function M:Place()
    local db = self.db
    local point = GROW_POINT[db.grow] or "TOP"
    bar:ClearAllPoints()
    if db.x and db.y then
        bar:SetPoint(point, UIParent, "BOTTOMLEFT", db.x, db.y)
    else
        bar:SetPoint("TOP", UIParent, "TOP", 0, -4)
    end
end

function M:SavePosition()
    local left, top, width = bar:GetLeft(), bar:GetTop(), bar:GetWidth()
    if not (left and top) then return end
    local grow = self.db.grow
    local x = left
    if grow == "CENTER" or grow == nil then x = left + width / 2
    elseif grow == "RIGHT" then x = left + width end
    self.db.x, self.db.y = math.floor(x + 0.5), math.floor(top + 0.5)
    self:Place()
end

--- Unlocked: drag anywhere. Locked: Alt + drag still moves it.
function M:StartDrag()
    if not bar or (self.db.locked and not IsAltKeyDown()) then return end
    GameTooltip_Hide()
    bar.moving = true
    bar:StartMoving()
end

function M:StopDrag()
    if not bar or not bar.moving then return end
    bar.moving = nil
    bar:StopMovingOrSizing()
    bar.dragEnd = GetTime()
    self:SavePosition()
end

local function ShowLock()
    local unlocked = not M.db.locked
    bar:EnableMouse(unlocked)
    local c = unlocked and C.accent or C.line
    Style.SetBorder(bar, c[1], c[2], c[3], unlocked and 1 or math.min(1, M.db.alpha + 0.1))
end

function M:Layout()
    if not bar then return end
    local db = self.db
    local h = db.height
    self:Place()
    bar:SetHeight(h)
    Style.SetBackground(bar, C.bg[1], C.bg[2], C.bg[3], db.alpha)
    ShowLock()
    local font = Style.Font(db.fontSize)
    local iconSize = math.max(8, math.min(h - 6, db.fontSize + 3))
    for _, seg in ipairs(segments) do
        local b = seg.frame
        b.text:SetFontObject(font)
        b.text:ClearAllPoints()
        if b.icon then
            b.icon:SetSize(iconSize, iconSize)
            b.text:SetPoint("LEFT", b.icon, "RIGHT", ICON_GAP, 0)
        else
            b.text:SetPoint("LEFT", PAD / 2, 0)
        end
        b:SetHeight(h)
        b.sep:SetHeight(math.max(4, h - 8))
    end
    self:Refresh(true)
end

--- Updates the segment texts (only those that are due, unless `all`) and
--- lays them out left to right.
function M:Refresh(all)
    if not bar or not self.enabled then return end
    local now = GetTime()
    -- First only the texts that are due; the bar is laid out again only
    -- when one of them actually changed.
    local changed = all
    for _, seg in ipairs(segments) do
        local on = self.db[seg.key] and true or false
        if on ~= seg.wasOn then seg.wasOn = on; changed = true end
        if on and (all or not seg.nextUpdate or now >= seg.nextUpdate) then
            local ok, res = pcall(seg.text)
            if not ok then geterrorhandler()(res); res = nil end
            if res ~= seg.cached then seg.cached = res; changed = true end
            seg.nextUpdate = now + (seg.every or 1)
        end
    end
    if not changed then return end

    local x = 1
    local prev
    for _, seg in ipairs(segments) do
        local b = seg.frame
        local text
        if self.db[seg.key] then
            text = seg.cached
        end
        if text then
            b.text:SetText(text)
            local w = (b.text:GetStringWidth() or 0) + PAD
            if b.icon then w = w + b.icon:GetWidth() + ICON_GAP end
            b:SetWidth(math.ceil(w))
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            b:Show()
            if prev then
                b.sep:ClearAllPoints()
                b.sep:SetPoint("CENTER", bar, "LEFT", x, 0)
                b.sep:Show()
            else
                b.sep:Hide()
            end
            x = x + b:GetWidth() + 1
            prev = b
        else
            b:Hide()
            b.sep:Hide()
        end
    end
    -- As wide as what is on it. With nothing switched on it stays visible
    -- only while unlocked, as a handle to drag.
    local empty = prev == nil
    bar.handle:SetShown(empty and not self.db.locked)
    if empty then x = 120 end
    bar:SetWidth(x)
    bar:SetShown(not empty or not self.db.locked)
end

local function Build()
    bar = CreateFrame("Frame", "AllInOneInfoBar", UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(5)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() M:StartDrag() end)
    bar:SetScript("OnDragStop", function() M:StopDrag() end)
    bar:SetScript("OnEnter", function(self)
        if M.db.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Drag to move. Lock it in the options."], 1, 1, 1)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    Style.Popup(bar)
    bar.handle = Style.Text(bar, 11, C.muted)
    bar.handle:SetPoint("CENTER")
    bar.handle:SetText(L["Info bar"])
    bar.handle:Hide()
    for _, seg in ipairs(segments) do SegmentFrame(seg) end
    local elapsed = 0
    bar:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 1 then return end
        elapsed = 0
        M:Refresh()
        -- keep an open tooltip current
        for _, seg in ipairs(segments) do
            local b = seg.frame
            if b:IsShown() and GameTooltip:IsShown() and GameTooltip:GetOwner() == b and seg.key ~= "gold" then
                pcall(seg.tip, b)
            end
        end
    end)
    M.bar = bar
end

-- Any of the segment events marks that segment due and refreshes next frame.
local registered = {}
for _, seg in ipairs(segments) do
    for _, event in ipairs(seg.events or {}) do
        if not registered[event] then
            registered[event] = {}
            M:On(event, function()
                for _, s in ipairs(registered[event]) do s.nextUpdate = nil end
                AIO:Later("infobar", function() M:Refresh() end)
            end)
        end
        table.insert(registered[event], seg)
    end
end

M:On("PLAYER_XP_UPDATE", TrackXP)
M:On("PLAYER_LEVEL_UP", function() AIO:Later("infobar-xp", TrackXP) end)
M:On("GUILD_ROSTER_UPDATE", ReadRoster)
M:On("PLAYER_GUILD_UPDATE", function() RequestRoster(true) end)
M:On("PLAYER_ENTERING_WORLD", function()
    RequestRoster(true)
    M:Refresh(true)
end)

function M:OnEnable()
    StartSession()
    if not bar then Build() end
    bar:Show()
    self:Layout()
    RequestRoster()
    ReadRoster()
end

function M:OnDisable()
    if bar then
        bar:StopMovingOrSizing()
        bar:Hide()
    end
end

function M:OnSettingChanged(key)
    -- Keep the bar where it is when the side it grows from changes.
    if key == "grow" and bar and self.db.x then self:SavePosition() end
    self:Layout()
end
