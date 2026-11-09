-- AllInOne: the options window.
--
-- Left: a search box and every module, grouped by category, with a dot that
-- shows whether it is on. Right: the chosen page — the overview, where every
-- module can be switched on and off at a glance, or one module's own page,
-- drawn from its `options` list:
--
--   { type = "header", label = "..." }
--   { type = "text",   label = "..." }                        -- a paragraph
--   { type = "toggle", key = "x", label = "...", desc = "..." }
--   { type = "slider", key = "x", label = "...", min = 0, max = 10, step = 1, format = fn }
--   { type = "select", key = "x", label = "...", values = { { value = v, label = "..." }, ... } }
--   { type = "input",  key = "x", label = "...", numeric = true, width = 120 }
--   { type = "button", label = "...", func = function(M) end }
--   { type = "custom", build = function(parent, width, M) return height end }
--
-- Instead of `key`, an entry may carry get = function() and set = function(v)
-- to store its value anywhere. `disabled = function(M) return bool end` greys
-- an entry out. `half = true` puts two entries side by side.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

local W, H = 880, 600
local NAV_W = 220
local panel

-- ---------------------------------------------------------------------------
-- Value access
-- ---------------------------------------------------------------------------

local function Getter(m, e)
    if e.get then return e.get end
    return function() return m.db[e.key] end
end

local function Setter(m, e)
    return function(v)
        if e.set then e.set(v) else m.db[e.key] = v end
        AIO:SettingChanged(m, e.key, v)
        if panel and panel.RefreshPage then panel:RefreshPage() end
    end
end

-- ---------------------------------------------------------------------------
-- A module's page
-- ---------------------------------------------------------------------------

local function Paragraph(parent, text, width, color)
    local fs = Style.Text(parent, 12, color or C.muted)
    fs:SetWidth(width)
    fs:SetWordWrap(true)
    fs:SetText(text)
    return fs, math.ceil(fs:GetStringHeight() or 14)
end

local function BuildEntry(parent, m, e, width)
    local kind = e.type
    if kind == "header" then
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(width, 30)
        local t = Style.Text(f, 13, C.accent)
        t:SetPoint("BOTTOMLEFT", 0, 6)
        t:SetText(e.label)
        local line = Style.Line(f)
        line:SetPoint("BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT")
        return f, 30
    elseif kind == "text" then
        local f = CreateFrame("Frame", nil, parent)
        local fs, h = Paragraph(f, e.label, width)
        fs:SetPoint("TOPLEFT")
        f:SetSize(width, h + 2)
        return f, h + 2
    elseif kind == "toggle" then
        local f = Style.Check(parent, e.label, Getter(m, e), Setter(m, e), e.desc)
        if e.disabled then f.disabledFn = function() return e.disabled(m) end end
        return f, 22
    elseif kind == "slider" then
        local f = Style.Slider(parent, e.label, e.min, e.max, e.step or 1, Getter(m, e), Setter(m, e), e.format)
        f:SetWidth(math.min(width, 300))
        return f, 40
    elseif kind == "select" then
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(width, 46)
        local t = Style.Text(f, 12)
        t:SetPoint("TOPLEFT")
        t:SetText(e.label)
        local dd = Style.Dropdown(f, e.width or 220, e.values, Getter(m, e), Setter(m, e))
        dd:SetPoint("TOPLEFT", 0, -18)
        f:SetScript("OnShow", function() dd:Update() end)
        return f, 46
    elseif kind == "input" then
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(width, 46)
        local t = Style.Text(f, 12)
        t:SetPoint("TOPLEFT")
        t:SetText(e.label)
        local box = Style.Edit(f, e.width or 220, e.placeholder)
        box:SetPoint("TOPLEFT", 0, -18)
        if e.numeric then box:SetNumeric(true) end
        local get, set = Getter(m, e), Setter(m, e)
        f:SetScript("OnShow", function() box:SetText(tostring(get() or "")) end)
        local function commit(self)
            local v = self:GetText()
            if e.numeric then v = tonumber(v) or 0 end
            set(v)
        end
        box:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
        box:HookScript("OnEditFocusLost", commit)
        return f, 46
    elseif kind == "button" then
        local b = Style.Button(parent, e.label, e.width or 180, 22, function() e.func(m) end)
        b.tip = e.desc
        return b, 26
    elseif kind == "custom" then
        local f = CreateFrame("Frame", nil, parent)
        local h = e.build(f, width, m) or 20
        f:SetSize(width, h)
        return f, h
    end
end

local function BuildModulePage(page, m)
    local width = page.child:GetWidth() - 20
    local content = page.child
    local y = -16

    local title = Style.Text(content, 18)
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(m.pageTitle or m.title or m.key)

    if not m.alwaysOn then
        local sw = Style.Switch(content, function() return m.db.enabled end, function(v)
            AIO:SetModuleEnabled(m.key, v)
            panel:RefreshNav()
            panel:RefreshPage()
        end)
        sw:SetPoint("TOPRIGHT", -16, y - 2)
        page.switch = sw
        local state = Style.Text(content, 12, C.muted)
        state:SetPoint("RIGHT", sw, "LEFT", -8, 0)
        page.state = state
    end
    local secKey = AIO:SectionOf(m.key)
    for _, sd in ipairs(AIO.sections) do
        if sd.key == secKey and sd.grouped then
            local back = Style.Button(content, "< " .. L["All helpers"], 110, 20, function()
                panel:Select("__overview:" .. secKey)
            end)
            back:SetPoint("TOPRIGHT", -150, y)
        end
    end
    y = y - 30

    if m.desc then
        local fs, h = Paragraph(content, m.desc, width - 16)
        fs:SetPoint("TOPLEFT", 16, y)
        y = y - h - 10
    end

    page.entries = {}
    page.entriesTop = y
    local col = 0
    local rowHeight = 0
    for _, e in ipairs(m.options or {}) do
        local half = e.half
        local w = half and math.floor((width - 32) / 2) or (width - 16)
        local f, h = BuildEntry(content, m, e, w)
        if f then
            if half and col == 1 then
                f:SetPoint("TOPLEFT", 16 + w + 16, y)
                col = 0
                rowHeight = math.max(rowHeight, h)
                y = y - rowHeight - 8
                rowHeight = 0
            else
                if col == 1 then y = y - rowHeight - 8; col = 0 end
                f:SetPoint("TOPLEFT", 16, y)
                if half then
                    col, rowHeight = 1, h
                else
                    y = y - h - 8
                end
            end
            f.entry = e
            page.entries[#page.entries + 1] = f
        end
    end
    if col == 1 then y = y - rowHeight - 8 end
    content:SetHeight(-y + 20)

    -- While the module is off its settings are greyed out and take no clicks.
    if not m.alwaysOn then
        local blocker = CreateFrame("Frame", nil, content)
        blocker:SetPoint("TOPLEFT", 0, page.entriesTop + 4)
        blocker:SetPoint("BOTTOMRIGHT")
        blocker:SetFrameLevel((content:GetFrameLevel() or 1) + 50)
        blocker:EnableMouse(true)
        blocker:Hide()
        page.blocker = blocker
    end
end

-- ---------------------------------------------------------------------------
-- The overview: every module with its switch
-- ---------------------------------------------------------------------------

--- Modules of a category, in their order.
local function ModulesOf(catKey)
    local list = {}
    for _, key in ipairs(AIO.moduleOrder) do
        local m = AIO.modules[key]
        if m.category == catKey then list[#list + 1] = m end
    end
    return list
end

--- A grouped section's front page: every helper as a tick box under its
--- group, groups spread over two columns. Pointing at a helper tells what it
--- does; the gear next to it opens its settings.
local function BuildChecklist(page, section, content, width, y)
    page.checks = {}
    local GAP = 28
    local colW = math.floor((width - 16 - GAP) / 2)
    local colY = { y, y }
    for _, cat in ipairs(AIO.categories) do
        local list = cat.section == section and ModulesOf(cat.key) or {}
        if #list > 0 then
            local c = colY[1] >= colY[2] and 1 or 2      -- the shorter column
            local x, cy = 16 + (c - 1) * (colW + GAP), colY[c]
            local head = Style.Text(content, 13, C.accent)
            head:SetPoint("TOPLEFT", x, cy)
            head:SetText(cat.label)
            local line = Style.Line(content)
            line:SetPoint("TOPLEFT", x, cy - 18)
            line:SetWidth(colW)
            cy = cy - 26
            for _, m in ipairs(list) do
                local title = m.title or m.key
                local tip = "|cffffd100" .. title .. "|r\n" .. (m.desc or m.short or "")
                local chk = Style.Check(content, title,
                    function() return m.alwaysOn or m.db.enabled end,
                    function(v)
                        if m.alwaysOn then return end
                        AIO:SetModuleEnabled(m.key, v)
                        panel:RefreshNav()
                    end, tip)
                chk:SetPoint("TOPLEFT", x, cy)
                chk:SetWidth(colW - 26)
                page.checks[#page.checks + 1] = chk
                if m.options and #m.options > 0 then
                    local gear = Style.Icon(content, "Interface\\Icons\\INV_Misc_Gear_01", 18,
                        L["Settings"], function() panel:Select(m.key) end)
                    gear:SetPoint("TOPLEFT", x + colW - 18, cy - 1)
                end
                cy = cy - 22
            end
            colY[c] = cy - 14
        end
    end
    return math.min(colY[1], colY[2])
end

local function BuildOverview(page, section, onlyCat)
    local content = page.child
    local width = content:GetWidth() - 20
    local y = -16
    local sec, catDef
    for _, s in ipairs(AIO.sections) do if s.key == section then sec = s end end
    for _, c in ipairs(AIO.categories) do if c.key == onlyCat then catDef = c end end
    local title = Style.Text(content, 18)
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(catDef and catDef.label or sec and sec.label or L["Overview"])
    y = y - 28
    local introText = catDef and (catDef.blurb or "")
        or (sec and sec.grouped and L["Tick what you want. Point at a name to see what it does; the gear opens its settings."])
        or (sec and sec.intro) or ""
    local intro, h = Paragraph(content, introText, width - 16)
    intro:SetPoint("TOPLEFT", 16, y)
    y = y - h - 12

    if sec and sec.grouped and not onlyCat then
        y = BuildChecklist(page, section, content, width, y)
        content:SetHeight(-y + 20)
        return
    end

    page.switches = {}
    local cardW = math.floor((width - 16 - 12) / 2)
    for _, cat in ipairs(AIO.categories) do
        local list = {}
        if cat.section == section and (not onlyCat or cat.key == onlyCat) then
            for _, key in ipairs(AIO.moduleOrder) do
                local m = AIO.modules[key]
                if m.category == cat.key then list[#list + 1] = m end
            end
        end
        if #list > 0 then
            if not cat.hideHeader and not onlyCat then
                local head = Style.Text(content, 13, C.accent)
                head:SetPoint("TOPLEFT", 16, y)
                head:SetText(cat.label)
                y = y - 20
            end
            for i, m in ipairs(list) do
                local card = CreateFrame("Button", nil, content)
                card:SetSize(cardW, 54)
                Style.Inset(card, C.panel, C.line)
                local col = (i - 1) % 2
                card:SetPoint("TOPLEFT", 16 + col * (cardW + 12), y)
                local name = Style.Text(card, 13)
                name:SetPoint("TOPLEFT", 10, -8)
                name:SetPoint("RIGHT", -56, 0)
                name:SetText(m.title or m.key)
                local desc = Style.Text(card, 11, C.muted)
                desc:SetPoint("TOPLEFT", 10, -26)
                desc:SetPoint("RIGHT", -56, 0)
                desc:SetHeight(24)
                desc:SetJustifyV("TOP")
                desc:SetText(m.short or m.desc or "")
                if not m.alwaysOn then
                    local sw = Style.Switch(card, function() return m.db.enabled end, function(v)
                        AIO:SetModuleEnabled(m.key, v)
                        panel:RefreshNav()
                    end)
                    sw:SetPoint("TOPRIGHT", -10, -8)
                    page.switches[#page.switches + 1] = sw
                end
                card:SetScript("OnEnter", function(self) Style.SetBorder(self, unpack(C.accent)) end)
                card:SetScript("OnLeave", function(self) Style.SetBorder(self, unpack(C.line)) end)
                card:SetScript("OnClick", function() panel:Select(m.key) end)
                if col == 1 or i == #list then y = y - 54 - 8 end
            end
            y = y - 8
        end
    end
    content:SetHeight(-y + 20)
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local function Build()
    panel = Style.Window("AllInOneOptions", W, H, AIO.title)
    panel:SetFrameStrata("DIALOG")
    panel:SetPoint("CENTER")
    local ver = Style.Text(panel.titleBar, 11, C.muted)
    ver:SetPoint("LEFT", panel.titleText, "RIGHT", 8, 0)
    ver:SetText("v" .. AIO.version)

    if Style.blizzard then Style.Portrait(panel, "Interface\\AddOns\\" .. ADDON .. "\\Media\\logo") end
    local reload = Style.Button(panel.titleBar, L["Reload UI"], 90, 18, function() ReloadUI() end)
    reload:SetPoint("RIGHT", panel.close, "LEFT", -8, 0)
    reload.tip = L["Reloads the interface (/reload)."]

    -- Tabs: one per section
    local TAB_H = 34
    local tabBar = CreateFrame("Frame", nil, panel)
    local E = Style.edge
    local TOPY = Style.blizzard and -32 or -27
    tabBar:SetPoint("TOPLEFT", E, TOPY)
    tabBar:SetPoint("TOPRIGHT", -E, TOPY)
    tabBar:SetHeight(TAB_H)
    if not Style.blizzard then Style.Flat(tabBar, C.bg, { 0, 0, 0, 0 }) end
    local tabLine = Style.Line(tabBar)
    tabLine:SetPoint("BOTTOMLEFT")
    tabLine:SetPoint("BOTTOMRIGHT")
    panel.tabs = {}
    panel.lastPage = {}
    local tx = Style.blizzard and 44 or 12
    for _, sec in ipairs(AIO.sections) do
      local used = false
      for _, cat in ipairs(AIO.categories) do
          if cat.section == sec.key then
              for _, key in ipairs(AIO.moduleOrder) do
                  if AIO.modules[key].category == cat.key then used = true break end
              end
          end
      end
      if used then
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetHeight(Style.blizzard and 26 or TAB_H)
        if Style.blizzard then
            -- A tab like Blizzard's: its own face with a bronze edge.
            tab.face = tab:CreateTexture(nil, "BACKGROUND")
            tab.face:SetPoint("TOPLEFT", 1, -1)
            tab.face:SetPoint("BOTTOMRIGHT", -1, 0)
            tab.edge = Style.Ring(tab, 0, Style.bronze)
        end
        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetSize(18, 18)
        tab.icon:SetPoint("LEFT", 10, 0)
        tab.icon:SetTexture(sec.icon)
        tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.text = Style.Text(tab, 13)
        tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 8, 0)
        tab.text:SetText(sec.label)
        tab:SetWidth(tab.text:GetStringWidth() + 50)
        tab:SetPoint("BOTTOMLEFT", tx, Style.blizzard and -1 or 0)
        tx = tx + tab:GetWidth() + 4
        tab.under = tab:CreateTexture(nil, "OVERLAY")
        tab.under:SetTexture(Style.WHITE)
        tab.under:SetPoint("BOTTOMLEFT")
        tab.under:SetPoint("BOTTOMRIGHT")
        tab.under:SetHeight(2)
        tab.hl = tab:CreateTexture(nil, "BACKGROUND")
        tab.hl:SetTexture(Style.WHITE)
        tab.hl:SetAllPoints()
        tab.hl:SetVertexColor(unpack(C.hover))
        tab.hl:Hide()
        tab.key = sec.key
        tab:SetScript("OnEnter", function(t) if t.key ~= panel.section then t.hl:Show() end end)
        tab:SetScript("OnLeave", function(t) t.hl:Hide() end)
        tab:SetScript("OnClick", function(t)
            panel:Select(panel.lastPage[t.key] or ("__overview:" .. t.key))
        end)
        panel.tabs[#panel.tabs + 1] = tab
      end
    end

    -- More tabs than the window is wide: tighter tabs first, then smaller
    -- text, then no icons.
    do
        local left = Style.blizzard and 44 or 12
        local avail = W - 2 * E - left - 6
        local function total(pad)
            local sum = 0
            for _, tab in ipairs(panel.tabs) do sum = sum + tab.text:GetStringWidth() + pad + 4 end
            return sum
        end
        local pad = 50
        if total(pad) > avail then pad = 42 end
        if total(pad) > avail then
            for _, tab in ipairs(panel.tabs) do tab.text:SetFontObject(Style.Font(12)) end
        end
        local noIcon = total(pad) > avail
        if noIcon then pad = 20 end
        if pad ~= 50 then
            local x = left
            for _, tab in ipairs(panel.tabs) do
                if noIcon then
                    tab.icon:Hide()
                    tab.text:ClearAllPoints()
                    tab.text:SetPoint("LEFT", 10, 0)
                end
                tab:SetWidth(tab.text:GetStringWidth() + pad)
                tab:ClearAllPoints()
                tab:SetPoint("BOTTOMLEFT", x, Style.blizzard and -1 or 0)
                x = x + tab:GetWidth() + 4
            end
        end
    end

    function panel:UpdateTabs()
        for _, tab in ipairs(self.tabs) do
            local active = tab.key == self.section
            if tab.face then
                if active then
                    Style.Gradient(tab.face, { 0.30, 0.31, 0.35, 1 }, { 0.23, 0.25, 0.28, 1 })
                else
                    Style.Gradient(tab.face, { 0.16, 0.17, 0.20, 1 }, { 0.11, 0.12, 0.14, 1 })
                end
                local c = active and { 0.76, 0.63, 0.51 } or { 0.40, 0.33, 0.25 }
                for _, t in ipairs(tab.edge) do t:SetVertexColor(c[1], c[2], c[3], 1) end
                tab.edge[2]:SetShown(not active)   -- the open tab runs into the page
                tab.text:SetTextColor(unpack(active and Style.gold or C.muted))
            end
            tab.under:SetVertexColor(unpack(C.accent))
            tab.under:SetShown(active and not tab.face)
            if not tab.face then tab.text:SetTextColor(unpack(active and C.text or C.muted)) end
            tab.icon:SetDesaturated(not active)
            if active then tab.hl:Hide() end
        end
    end

    -- Navigation
    local nav = CreateFrame("Frame", nil, panel)
    nav:SetPoint("TOPLEFT", E, TOPY - TAB_H - (Style.blizzard and 6 or 0))
    nav:SetPoint("BOTTOMLEFT", E, E)
    nav:SetWidth(NAV_W)
    Style.Inset(nav, C.panel, { 0, 0, 0, 0 })
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(Style.WHITE)
    sep:SetVertexColor(unpack(C.line))
    sep:SetPoint("TOPLEFT", nav, "TOPRIGHT")
    sep:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT")
    sep:SetWidth(1)

    local search = Style.Edit(nav, NAV_W - 20, L["Search"])
    search:SetPoint("TOPLEFT", 10, -10)
    search:SetScript("OnTextChanged", function(self)
        panel.filter = self:GetText():lower()
        panel:RefreshNav()
    end)

    local navScroll = Style.Scroll(nav)
    navScroll:SetPoint("TOPLEFT", 0, -40)
    navScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    panel.navScroll = navScroll
    panel.navRows = {}

    -- Pages
    local area = CreateFrame("Frame", nil, panel)
    area:SetPoint("TOPLEFT", nav, "TOPRIGHT", Style.blizzard and 8 or 1, 0)
    area:SetPoint("BOTTOMRIGHT", -E, E)
    if Style.blizzard then
        Style.Inset(area)
        sep:Hide()
    end
    panel.area = area
    panel.pages = {}

    function panel:NavRow(i)
        local row = self.navRows[i]
        if row then return row end
        row = CreateFrame("Button", nil, navScroll.child)
        row:SetHeight(22)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetTexture(Style.WHITE)
        row.hl:SetAllPoints()
        row.hl:SetVertexColor(unpack(C.hover))
        if Style.blizzard then
            -- Blizzard's list selection: a golden run.
            Style.Gradient(row.hl, { 0.46, 0.35, 0.12, 0.9 }, { 0.24, 0.17, 0.06, 0.9 })
        end
        row.hl:Hide()
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetTexture(Style.WHITE)
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.bar:SetWidth(3)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetTexture(Style.WHITE)
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("RIGHT", -10, 0)
        row.text = Style.Text(row, 12)
        row.text:SetPoint("LEFT", 14, 0)
        row.text:SetPoint("RIGHT", -22, 0)
        row.arrow = row:CreateTexture(nil, "ARTWORK")
        row.arrow:SetSize(10, 10)
        row.arrow:SetPoint("RIGHT", -8, 0)
        row.arrow:Hide()
        row.text:SetWordWrap(false)
        row:SetScript("OnEnter", function(r) if not r.isHeader then r.hl:Show() end end)
        row:SetScript("OnLeave", function(r) if r.key ~= panel.selected then r.hl:Hide() end end)
        row:SetScript("OnClick", function(r) if r.key then panel:Select(r.key) end end)
        self.navRows[i] = row
        return row
    end

    function panel:RefreshNav()
        local i, y = 0, 0
        local filter = self.filter ~= "" and self.filter or nil
        local function add(key, text, isHeader, enabled, indent)
            i = i + 1
            local row = self:NavRow(i)
            row.key, row.isHeader = key, isHeader
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", navScroll.child, "RIGHT", 0, 0)
            row.text:SetText(text)
            row.text:SetPoint("LEFT", indent and 26 or 14, 0)
            row.arrow:Hide()
            if row.arrow.SetRotation then row.arrow:SetRotation(0) end
            if isHeader then
                row.text:SetFontObject(Style.Font(10))
                row.text:SetTextColor(unpack(C.muted))
                row:SetHeight(24)
                row.dot:Hide()
            else
                row.text:SetFontObject(Style.Font(12))
                row.text:SetTextColor(unpack(C.text))
                row:SetHeight(22)
                row.dot:SetShown(enabled ~= nil)
                if enabled ~= nil then
                    row.dot:SetVertexColor(unpack(enabled and C.good or C.line))
                end
            end
            local selected = key ~= nil and key == self.selected
            row.hl:SetShown(selected)
            row.bar:SetVertexColor(unpack(C.accent))
            row.bar:SetShown(selected)
            row:Show()
            y = y + row:GetHeight()
        end

        local section = self.section
        local secDef
        for _, sd in ipairs(AIO.sections) do if sd.key == section then secDef = sd end end
        if not filter and not (secDef and secDef.noOverview) then
            add("__overview:" .. section, L["Overview"], false, nil)
        end
        -- Grouped section, no search: the groups, and only the open one shows
        -- its helpers underneath.
        if secDef and secDef.grouped and not filter then
            local sel = self.selected
            local openCat = sel and (sel:match("^__cat:(.+)$") or (AIO.modules[sel] and AIO.modules[sel].category))
            for _, cat in ipairs(AIO.categories) do
                if cat.section == section then
                    local list = ModulesOf(cat.key)
                    if #list > 0 then
                        local open = cat.key == openCat
                        add("__cat:" .. cat.key, cat.label, false, nil)
                        local row = self.navRows[i]
                        row.text:SetFontObject(Style.Font(12))
                        row.text:SetTextColor(unpack(open and C.accent or C.text))
                        -- one arrow: pointing down when open, to the right when closed
                        row.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
                        if row.arrow.SetRotation then row.arrow:SetRotation(open and 0 or math.pi / 2) end
                        row.arrow:SetVertexColor(unpack(C.muted))
                        row.arrow:Show()
                        if open then
                            for _, m in ipairs(list) do
                                add(m.key, m.title or m.key, false, m.alwaysOn and nil or (m.db and m.db.enabled), true)
                            end
                            y = y + 4
                        end
                    end
                end
            end
            for j = i + 1, #self.navRows do self.navRows[j]:Hide() end
            navScroll.child:SetHeight(y + 10)
            navScroll:UpdateRange()
            return
        end
        for _, cat in ipairs(AIO.categories) do
            local headerAdded = cat.section ~= section
            for _, key in ipairs(AIO.moduleOrder) do
                local m = AIO.modules[key]
                if m.category == cat.key and cat.section == section then
                    local title = m.title or key
                    local hay = (title .. " " .. (m.desc or "")):lower()
                    if not filter or hay:find(filter, 1, true) then
                        if not headerAdded then
                            y = y + 6
                            if not cat.hideHeader then add(nil, cat.label, true) end
                            headerAdded = true
                        end
                        add(key, title, false, m.alwaysOn and nil or (m.db and m.db.enabled))
                    end
                end
            end
        end
        for j = i + 1, #self.navRows do self.navRows[j]:Hide() end
        navScroll.child:SetHeight(y + 10)
        navScroll:UpdateRange()
    end

    function panel:Page(key)
        local page = self.pages[key]
        if page then return page end
        page = Style.Scroll(self.area)
        page:SetPoint("TOPLEFT", 0, 0)
        page:SetPoint("BOTTOMRIGHT", -10, 0)
        page.child:SetWidth(W - NAV_W - 14)
        local sec = key:match("^__overview:(.+)$")
        local catKey = key:match("^__cat:(.+)$")
        if sec then
            BuildOverview(page, sec)
        elseif catKey then
            BuildOverview(page, AIO:SectionOf(key), catKey)
        else
            BuildModulePage(page, AIO.modules[key])
        end
        page:UpdateRange()
        self.pages[key] = page
        return page
    end

    function panel:Select(key)
        if key == "__overview" then key = "__overview:" .. AIO.sections[1].key end
        -- A group opens on its first helper, not on a page of its own.
        local group = key:match("^__cat:(.+)$")
        if group then
            local first = ModulesOf(group)[1]
            key = first and first.key or ("__overview:" .. AIO:SectionOf(key))
        end
        if not key:match("^__overview:") and not AIO.modules[key] then
            key = "__overview:" .. AIO.sections[1].key
        end
        -- A section without an overview opens on its first page instead.
        local ov = key:match("^__overview:(.+)$")
        if ov then
            for _, sd in ipairs(AIO.sections) do
                if sd.key == ov and sd.noOverview then
                    for _, cat in ipairs(AIO.categories) do
                        if cat.section == ov then
                            for _, k in ipairs(AIO.moduleOrder) do
                                if AIO.modules[k].category == cat.key then key = k break end
                            end
                        end
                        if not key:match("^__overview:") then break end
                    end
                end
            end
        end
        self.section = AIO:SectionOf(key)
        self.lastPage[self.section] = key
        self:UpdateTabs()
        self.selected = key
        for k, p in pairs(self.pages) do p:SetShown(k == key) end
        local page = self:Page(key)
        page:Show()
        page:ScrollToTop()
        self:RefreshNav()
        self:RefreshPage()
    end

    function panel:RefreshPage()
        local page = self.selected and self.pages[self.selected]
        if not page then return end
        local m = AIO.modules[self.selected]
        if page.switch then page.switch:Update() end
        if page.state and m then
            page.state:SetText(m.db.enabled and L["On"] or L["Off"])
        end
        local off = m and not m.alwaysOn and not m.db.enabled
        if page.blocker then page.blocker:SetShown(off and true or false) end
        for _, f in ipairs(page.entries or {}) do
            f.pageOff = off
            if f.Update then f:Update() end
            local dim = off or (f.entry and f.entry.disabled and f.entry.type ~= "toggle" and f.entry.disabled(m))
            f:SetAlpha(dim and 0.4 or 1)
        end
        for _, sw in ipairs(page.switches or {}) do sw:Update() end
        for _, c in ipairs(page.checks or {}) do c:Update() end
    end

    panel:SetScript("OnShow", function(self)
        self:RefreshNav()
        self:RefreshPage()
    end)
    panel.filter = ""
    panel.section = AIO.sections[1].key
end

function AIO:OpenOptions(key)
    if not panel then Build() end
    if panel:IsShown() and not key then panel:Hide() return end
    panel:Show()
    panel:Select(key or panel.selected or ("__overview:" .. AIO.sections[1].key))
end
