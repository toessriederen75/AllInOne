-- AllInOne: chat improvements — short channel names, clickable links, a sound
-- on whispers, a saved chat history and a window to search it.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style

if GetLocale() == "deDE" then
    L["Chat improvements"] = "Chat-Verbesserungen"
    L["Short channel names, clickable links, whisper sound, history and search."] = "Kurze Kanalnamen, klickbare Links, Flüsterton, Verlauf und Suche."
    L["Makes the chat easier to read and use: \"[1. General - City]\" becomes \"[1]\", web addresses can be clicked and copied, whispers can play a sound, and the last lines of chat are saved so you can see them after logging in and search them with /aio find."] = "Macht den Chat übersichtlicher: Aus «[1. Allgemein - Stadt]» wird «[1]», Webadressen lassen sich anklicken und kopieren, Flüstern kann einen Ton abspielen, und die letzten Chatzeilen werden gespeichert, damit du sie nach dem Einloggen siehst und mit /aio find durchsuchen kannst."
    L["Channel names"] = "Kanalnamen"
    L["Short channel names"] = "Kurze Kanalnamen"
    L["\"[1. General - City]\" becomes \"[1]\", \"[Guild]\" becomes \"[G]\"."] = "Aus «[1. Allgemein - Stadt]» wird «[1]», aus «[Gilde]» wird «[G]»."
    L["Links"] = "Links"
    L["Clickable web addresses"] = "Klickbare Webadressen"
    L["Click a web address in chat to copy it."] = "Klicke im Chat auf eine Webadresse, um sie zu kopieren."
    L["Whisper sound"] = "Flüsterton"
    L["Sound on incoming whispers"] = "Ton bei eingehendem Flüstern"
    L["Sound"] = "Ton"
    L["Play"] = "Abspielen"
    L["Whisper"] = "Flüstern"
    L["Raid warning"] = "Schlachtzugswarnung"
    L["Ready check"] = "Bereitschaftscheck"
    L["Map ping"] = "Kartenpieps"
    L["Auction house"] = "Auktionshaus"
    L["Level up"] = "Stufenaufstieg"
    L["Chat history"] = "Chatverlauf"
    L["Save chat history"] = "Chatverlauf speichern"
    L["Say, yell, whisper, party, raid, guild, officer and channel messages."] = "Sagen, Schreien, Flüstern, Gruppe, Schlachtzug, Gilde, Offiziere und Kanäle."
    L["Lines to keep"] = "Gespeicherte Zeilen"
    L["Show the last 30 lines after logging in"] = "Nach dem Einloggen die letzten 30 Zeilen zeigen"
    L["Search chat history"] = "Chatverlauf durchsuchen"
    L["Clear history"] = "Verlauf löschen"
    L["Chat history cleared."] = "Chatverlauf gelöscht."
    L["Type /aio find <text> to search the history."] = "Tippe /aio find <Text>, um den Verlauf zu durchsuchen."
    L["Chat search"] = "Chatsuche"
    L["Search text"] = "Suchtext"
    L["%d of %d lines"] = "%d von %d Zeilen"
    L["Copy link (Ctrl+C)"] = "Link kopieren (Strg+C)"
    L["Chat history (last %d lines)"] = "Chatverlauf (letzte %d Zeilen)"
    L["End of chat history"] = "Ende des Chatverlaufs"
    L["Chat improvements are switched off."] = "Die Chat-Verbesserungen sind ausgeschaltet."
end

local REPLAY_LINES = 30
local MAX_RESULTS = 500
local LINK_PREFIX = "aiourl:"

local function SK(name, fallback)
    return (SOUNDKIT and SOUNDKIT[name]) or fallback
end

local SOUNDS = {
    { value = SK("TELL_MESSAGE", 3081),         label = L["Whisper"] },
    { value = SK("RAID_WARNING", 8959),         label = L["Raid warning"] },
    { value = SK("READY_CHECK", 8960),          label = L["Ready check"] },
    { value = SK("MAP_PING", 3175),             label = L["Map ping"] },
    { value = SK("AUCTION_WINDOW_OPEN", 5274),  label = L["Auction house"] },
    { value = SK("LEVEL_UP", 888),              label = L["Level up"] },
}

local M -- the module, defined below

-- ---------------------------------------------------------------------------
-- Short channel names
-- ---------------------------------------------------------------------------

-- Global format string → short tag. The long name is taken from inside the
-- brackets of the format, so it follows the client language.
local SHORT_SOURCES = {
    { "CHAT_GUILD_GET",                "G",  "Guild" },
    { "CHAT_OFFICER_GET",              "O",  "Officer" },
    { "CHAT_PARTY_LEADER_GET",         "PL", "Party Leader" },
    { "CHAT_PARTY_GUIDE_GET",          "PG", nil },
    { "CHAT_PARTY_GET",                "P",  "Party" },
    { "CHAT_RAID_LEADER_GET",          "RL", "Raid Leader" },
    { "CHAT_RAID_WARNING_GET",         "RW", "Raid Warning" },
    { "CHAT_RAID_GET",                 "R",  "Raid" },
    { "CHAT_BATTLEGROUND_LEADER_GET",  "BL", "Battleground Leader" },
    { "CHAT_BATTLEGROUND_GET",         "BG", "Battleground" },
    { "CHAT_INSTANCE_CHAT_LEADER_GET", "IL", nil },
    { "CHAT_INSTANCE_CHAT_GET",        "I",  nil },
}

local shortNames -- { { long = "[Guild]", short = "[G]" }, ... }, longest first

local function BuildShortNames()
    shortNames = {}
    local seen = {}
    for _, src in ipairs(SHORT_SOURCES) do
        local fmt = _G[src[1]]
        local long = type(fmt) == "string" and fmt:match("%[(.-)%]") or src[3]
        if long and long ~= "" and not long:find("%%") and not seen[long] then
            seen[long] = true
            shortNames[#shortNames + 1] = { long = "[" .. long .. "]", short = "[" .. src[2] .. "]" }
        end
    end
    table.sort(shortNames, function(a, b) return #a.long > #b.long end)
end

--- Only the start of a line is looked at, so that the same words inside the
--- message itself stay as they are.
local HEAD = 60

local function Shorten(text)
    local s, e, num = text:find("%[(%d+)%.%s*[^%]|]-%]")
    if s and s <= HEAD then
        text = text:sub(1, s - 1) .. "[" .. num .. "]" .. text:sub(e + 1)
    end
    if not shortNames then BuildShortNames() end
    for _, n in ipairs(shortNames) do
        local a, b = text:find(n.long, 1, true)
        if a and a <= HEAD then
            text = text:sub(1, a - 1) .. n.short .. text:sub(b + 1)
            break
        end
    end
    return text
end

local function HookChatFrames()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.AddMessage and not f.aioAddMessage and f ~= _G.COMBATLOG then
            local orig = f.AddMessage
            f.aioAddMessage = orig
            f.AddMessage = function(self, text, ...)
                if M.enabled and M.db.shortNames and type(text) == "string" then
                    text = Shorten(text)
                end
                return orig(self, text, ...)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Clickable web addresses
-- ---------------------------------------------------------------------------

local function Link(url)
    return "|cff4fc3f7|H" .. LINK_PREFIX .. url .. "|h[" .. url .. "]|h|r"
end

local function LinkifyPlain(msg)
    return (msg:gsub("%S+", function(word)
        if word:find("|", 1, true) then return nil end           -- inside a link or colour code
        local lead, body = word:match("^([%(<\"']*)(.*)$")
        local core, trail = body:match("^(.-)([%.,;:!%?%)>\"']*)$")
        if not core or core == "" or core:find("[%[%]]") then return nil end
        local l = core:lower()
        if l:match("^https?://[%w%[]") or l:match("^www%.[%w%-]+%.%a") then
            return lead .. Link(core) .. trail
        end
        return nil
    end))
end

--- Turns web addresses into our links, leaving existing hyperlinks (items,
--- players, ...) alone, even when their names contain an address.
local function Linkify(msg)
    local lower = msg:lower()
    if not (lower:find("://", 1, true) or lower:find("www.", 1, true)) then return msg end
    local out, pos = {}, 1
    while true do
        local s, e = msg:find("|H.-|h.-|h", pos)
        if not s then break end
        out[#out + 1] = LinkifyPlain(msg:sub(pos, s - 1))
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    out[#out + 1] = LinkifyPlain(msg:sub(pos))
    return table.concat(out)
end

local URL_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_EMOTE", "CHAT_MSG_SYSTEM",
}

local function UrlFilter(self, event, msg, ...)
    if not (M.enabled and M.db.urls) or type(msg) ~= "string" then return false end
    local new = Linkify(msg)
    if new ~= msg then return false, new, ... end
    return false
end

local function ShowURL(url)
    local w = M.urlWindow
    if not w then
        w = Style.Window("AllInOneURLCopy", 460, 66, L["Copy link (Ctrl+C)"])
        w:SetFrameStrata("DIALOG")
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        local e = Style.Edit(w, 440, "")
        e:SetPoint("TOPLEFT", 10, -34)
        e:SetScript("OnEscapePressed", function() w:Hide() end)
        e:SetScript("OnEnterPressed", function() w:Hide() end)
        e:HookScript("OnTextChanged", function(self, userInput)
            -- Read only: typing puts the address back.
            if userInput and self:GetText() ~= w.url then
                self:SetText(w.url or "")
                self:HighlightText()
            end
        end)
        w.edit = e
        M.urlWindow = w
    end
    w.url = url
    w:Show()
    w.edit:SetText(url)
    w.edit:SetFocus()
    w.edit:HighlightText()
end

local function HookSetItemRef()
    if M.itemRefHooked or not _G.SetItemRef then return end
    M.itemRefHooked = true
    local orig = _G.SetItemRef
    _G.SetItemRef = function(link, text, button, chatFrame, ...)
        if type(link) == "string" and link:sub(1, #LINK_PREFIX) == LINK_PREFIX then
            -- Ours, even when the module is off: Blizzard's code does not know it.
            local url = link:sub(#LINK_PREFIX + 1)
            if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_GetActiveWindow then
                local box = ChatEdit_GetActiveWindow()
                if box then box:Insert(url) return end
            end
            ShowURL(url)
            return
        end
        return orig(link, text, button, chatFrame, ...)
    end
end

-- ---------------------------------------------------------------------------
-- History
-- ---------------------------------------------------------------------------

-- event suffix → short tag
local HISTORY_EVENTS = {
    SAY = "S", YELL = "Y", WHISPER = "W", WHISPER_INFORM = "W",
    PARTY = "P", PARTY_LEADER = "PL", RAID = "R", RAID_LEADER = "RL", RAID_WARNING = "RW",
    GUILD = "G", OFFICER = "O", CHANNEL = "", BATTLEGROUND = "BG", BATTLEGROUND_LEADER = "BL",
    INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "IL",
}

local function CleanName(name)
    if not name or name == "" then return "?" end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and short then return short end
    end
    local base, realm = name:match("^([^%-]+)%-(.+)$")
    if base and realm and realm:gsub("%s", "") == (AIO.realm or ""):gsub("%s", "") then return base end
    return name
end

local function Trim(log, size)
    local extra = #log - size
    if extra > 0 then
        for _ = 1, extra do table.remove(log, 1) end
    end
end

local function Record(kind, msg, sender, ...)
    if not M.db.keepHistory or type(msg) ~= "string" or msg == "" then return end
    local e = { t = time(), p = AIO.player, k = kind, s = CleanName(sender), m = msg }
    if kind == "CHANNEL" then
        local _, _, _, _, _, channelIndex, baseName = ...
        e.c = tonumber(channelIndex)
        e.n = baseName
    end
    local log = M.db.log
    log[#log + 1] = e
    Trim(log, M.db.historySize or 200)
end

local function Tag(e)
    if e.k == "CHANNEL" then return "[" .. tostring(e.c or e.n or "?") .. "]" end
    return "[" .. (HISTORY_EVENTS[e.k] or e.k) .. "]"
end

local function StripColours(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

--- One saved line as text. withDate adds the day for the search window.
local function FormatEntry(e, withDate)
    local when = date(withDate and "%d.%m. %H:%M" or "%H:%M", e.t or 0)
    local who = e.s or "?"
    local name = "|Hplayer:" .. who .. "|h" .. who .. "|h"
    if e.k == "WHISPER_INFORM" then name = "> " .. name end
    local line = ("%s %s %s: %s"):format(when, Tag(e), name, StripColours(e.m or ""))
    if withDate and e.p and e.p ~= AIO.player then line = line .. "  |cff666666(" .. e.p .. ")|r" end
    return line
end

local function Replay()
    local log = M.db.log
    local mine = {}
    for i = #log, 1, -1 do
        if log[i].p == AIO.player then
            table.insert(mine, 1, log[i])
            if #mine >= REPLAY_LINES then break end
        end
    end
    if #mine == 0 or not ChatFrame1 then return end
    ChatFrame1:AddMessage(("|cff808080--- %s ---|r"):format(L["Chat history (last %d lines)"]:format(#mine)))
    for _, e in ipairs(mine) do
        ChatFrame1:AddMessage("|cff808080" .. FormatEntry(e) .. "|r")
    end
    ChatFrame1:AddMessage(("|cff808080--- %s ---|r"):format(L["End of chat history"]))
end

-- ---------------------------------------------------------------------------
-- Search window
-- ---------------------------------------------------------------------------

local function BuildSearch()
    local w = Style.Window("AllInOneChatSearch", 640, 440, L["Chat search"])
    w:SetPoint("CENTER")
    w.edit = Style.Edit(w, 300, L["Search text"])
    w.edit:SetPoint("TOPLEFT", 10, -36)
    w.edit:HookScript("OnTextChanged", function() AIO:Later("aioChatSearch", function() M:RunSearch() end) end)
    w.count = Style.Text(w, 12, Style.color.muted)
    w.count:SetPoint("LEFT", w.edit, "RIGHT", 12, 0)

    local list = CreateFrame("Frame", nil, w)
    list:SetPoint("TOPLEFT", 10, -66)
    list:SetPoint("BOTTOMRIGHT", -10, 10)
    Style.Inset(list, Style.color.panel, Style.color.line)
    w.scroll = Style.Scroll(list)
    w.scroll:SetPoint("TOPLEFT", 6, -6)
    w.scroll:SetPoint("BOTTOMRIGHT", -12, 6)
    w.scroll.child:SetWidth(600)
    w.rows = {}
    M.searchWindow = w
    return w
end

local function Row(w, i)
    local r = w.rows[i]
    if not r then
        r = Style.Text(w.scroll.child, 12)
        r:SetPoint("TOPLEFT", 2, -(i - 1) * 16)
        r:SetPoint("RIGHT", w.scroll.child, "RIGHT", -2, 0)
        r:SetHeight(16)
        r:SetWordWrap(false)
        w.rows[i] = r
    end
    return r
end

--- Lines of the history that contain `text` (any case), newest first.
local function Find(text)
    local needle = (text or ""):lower()
    local found = {}
    local log = M.db.log
    for i = #log, 1, -1 do
        local e = log[i]
        local hay = ((e.m or "") .. " " .. (e.s or "") .. " " .. (e.n or "")):lower()
        if needle == "" or hay:find(needle, 1, true) then
            found[#found + 1] = e
            if #found >= MAX_RESULTS then break end
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- The module
-- ---------------------------------------------------------------------------

M = AIO:NewModule("chat", {
    title    = L["Chat improvements"],
    short    = L["Short channel names, clickable links, whisper sound, history and search."],
    desc     = L["Makes the chat easier to read and use: \"[1. General - City]\" becomes \"[1]\", web addresses can be clicked and copied, whispers can play a sound, and the last lines of chat are saved so you can see them after logging in and search them with /aio find."],
    category = "chat",
    default  = true,
    defaults = { shortNames = true, urls = true, whisperSound = true, sound = SOUNDS[1].value,
                 keepHistory = true, historySize = 200, replay = true, log = {} },
    options  = {
        { type = "header", label = L["Channel names"] },
        { type = "toggle", key = "shortNames", label = L["Short channel names"],
          desc = L["\"[1. General - City]\" becomes \"[1]\", \"[Guild]\" becomes \"[G]\"."] },
        { type = "header", label = L["Links"] },
        { type = "toggle", key = "urls", label = L["Clickable web addresses"],
          desc = L["Click a web address in chat to copy it."] },
        { type = "header", label = L["Whisper sound"] },
        { type = "toggle", key = "whisperSound", label = L["Sound on incoming whispers"] },
        { type = "select", key = "sound", label = L["Sound"], values = SOUNDS, half = true,
          disabled = function(m) return not m.db.whisperSound end },
        { type = "button", label = L["Play"], width = 100, half = true,
          func = function(m) PlaySound(m.db.sound, "Master") end },
        { type = "header", label = L["Chat history"] },
        { type = "toggle", key = "keepHistory", label = L["Save chat history"],
          desc = L["Say, yell, whisper, party, raid, guild, officer and channel messages."] },
        { type = "slider", key = "historySize", label = L["Lines to keep"], min = 50, max = 1000, step = 50,
          disabled = function(m) return not m.db.keepHistory end },
        { type = "toggle", key = "replay", label = L["Show the last 30 lines after logging in"],
          disabled = function(m) return not m.db.keepHistory end },
        { type = "text", label = L["Type /aio find <text> to search the history."] },
        { type = "button", label = L["Search chat history"], half = true,
          func = function(m) m:OpenSearch("") end },
        { type = "button", label = L["Clear history"], half = true,
          func = function(m)
              wipe(m.db.log)
              m:Print(L["Chat history cleared."])
              if m.searchWindow and m.searchWindow:IsShown() then m:RunSearch() end
          end },
    },
})

M.slash = "find"
function M:Slash(rest)
    self:OpenSearch(rest or "")
end

function M:OpenSearch(text)
    if not self.enabled then
        self:Print(L["Chat improvements are switched off."])
        return
    end
    local w = self.searchWindow or BuildSearch()
    w:Show()
    w.edit:SetText(text or "")
    self:RunSearch()
end

function M:RunSearch()
    local w = self.searchWindow
    if not w or not w:IsShown() then return end
    local found = Find(w.edit:GetText())
    for i, e in ipairs(found) do
        local r = Row(w, i)
        r:SetText(FormatEntry(e, true))
        r:Show()
    end
    for i = #found + 1, #w.rows do w.rows[i]:Hide() end
    w.count:SetText(L["%d of %d lines"]:format(#found, #self.db.log))
    w.scroll.child:SetHeight(#found * 16 + 4)
    w.scroll:UpdateRange()
    w.scroll:ScrollToTop()
    w.results = found
end

-- History events
for suffix in pairs(HISTORY_EVENTS) do
    local event = "CHAT_MSG_" .. suffix
    M:On(event, function(msg, sender, ...) Record(suffix, msg, sender, ...) end)
end

-- Whisper sound
local lastSound = 0
local function WhisperSound()
    if not M.db.whisperSound then return end
    local now = GetTime()
    if now - lastSound < 1 then return end
    lastSound = now
    PlaySound(M.db.sound or SOUNDS[1].value, "Master")
end
M:On("CHAT_MSG_WHISPER", WhisperSound)
M:On("CHAT_MSG_BN_WHISPER", WhisperSound)

function M:OnEnable()
    if not self.installed then
        self.installed = true
        HookChatFrames()
        HookSetItemRef()
        if ChatFrame_AddMessageEventFilter then
            for _, event in ipairs(URL_EVENTS) do ChatFrame_AddMessageEventFilter(event, UrlFilter) end
        end
    end
    Trim(self.db.log, self.db.historySize or 200)
    if not self.replayed then
        self.replayed = true
        if self.db.keepHistory and self.db.replay then
            if C_Timer and C_Timer.After then C_Timer.After(1.5, Replay) else AIO:Later("aioReplay", Replay) end
        end
    end
end

function M:OnDisable()
    if self.searchWindow then self.searchWindow:Hide() end
    if self.urlWindow then self.urlWindow:Hide() end
end

function M:OnSettingChanged(key)
    if key == "historySize" then Trim(self.db.log, self.db.historySize) end
end

-- for tests
M.Shorten, M.Linkify, M.Find = Shorten, Linkify, Find
