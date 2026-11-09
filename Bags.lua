-- AllInOne: the bag windows' page in the options. The windows themselves are
-- built in Window.lua and Windows.lua; this only describes their settings.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

local function Setting(key)
    return function() return AIO.settings[key] end,
           function(v) AIO.settings[key] = v end
end

local function Toggle(key, label, desc)
    local get, set = Setting(key)
    return { type = "toggle", label = label, desc = desc, get = get, set = set }
end

local function FrameSlider(id, field, label, min, max, step, fmt)
    return {
        type = "slider", label = label, min = min, max = max, step = step, format = fmt, half = true,
        get = function() return AIO.settings.frames[id][field] end,
        set = function(v)
            AIO.settings.frames[id][field] = v
            local w = AIO.windows[id]
            if w then w:ApplySettings(); w:RequestRefresh() end
        end,
    }
end

local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end

local general = {
    { type = "header", label = L["Replace the default windows"] },
    { type = "text",   label = L["Changes here take effect after a /reload."] },
    Toggle("replaceBags",  L["Replace the default bags"]),
    Toggle("replaceBank",  L["Replace the default bank"]),
    Toggle("replaceGuild", L["Replace the default guild bank"]),

    { type = "header", label = L["Items"] },
    Toggle("qualityBorder", L["Quality borders"], L["Colours the border of an item by its quality; quest items in gold."]),
    Toggle("itemLevel",     L["Item level on gear"]),
    Toggle("junkIcon",      L["Coin on junk"]),
    Toggle("newGlow",       L["Glow on new items"], L["Quest items and armour you have just looted shine the first time you open your bags. Not junk."]),
    Toggle("emptySlots",    L["Show empty slots"]),
    { type = "slider", label = L["Space between slots"], min = 0, max = 10, step = 1, half = true,
      get = function() return AIO.settings.slotGap end,
      set = function(v)
          AIO.settings.slotGap = v
          for _, w in pairs(AIO.windows) do w.laidOut = false; w:RequestRefresh() end
      end },
    Toggle("tooltipCounts", L["Item counts in tooltips"], L["Shows how many of an item each character and the guild bank hold."]),

    { type = "header", label = L["Arrangement & sorting"] },
    Toggle("partialTop", L["Unfilled row at the top"], L["Like the default bags: the last row is full and the gaps sit at the top."]),
    Toggle("sortBottom", L["Sort from the bottom"], L["Sorting fills the last slots first, so the free slots stay at the top."]),
    Toggle("questFirst", L["Quest items first"], L["Sorting always puts quest items at the very top."]),
    { type = "button", label = L["Lock slots from sorting"], width = 220,
      desc = L["Opens your bags; click single slots to keep them out of sorting. They show a small padlock."],
      func = function() AIO:SlotLockMode(true, true) end },
    { type = "custom", build = function(parent, width)
        local t = AIO.Style.Text(parent, 12, AIO.Style.color.muted)
        t:SetPoint("TOPLEFT", 0, -2)
        local free = AIO.Style.Button(parent, L["Free all"], 110, 22, function()
            wipe(AIO:SortLocks())
            AIO:RefreshAll()
            parent.Update()
        end)
        free:SetPoint("LEFT", t, "RIGHT", 12, 0)
        parent.Update = function()
            local n = AIO:CountSortLocks()
            t:SetText(L["Locked slots: %d"]:format(n))
            free:SetShown(n > 0)
        end
        parent:HookScript("OnShow", parent.Update)
        parent.Update()
        return 26
    end },

    { type = "header", label = L["Windows"] },
    Toggle("locked",        L["Lock window positions"]),
    { type = "button", label = L["Reset positions"], func = function()
        for id, w in pairs(AIO.windows) do
            AIO.settings.frames[id].point = nil
            AIO.CopyDefaults(AIO.settings.frames[id], AIO.defaults.frames[id])
            w:ApplySettings()
        end
    end },
}

local function WindowOptions(id, extra)
    local list = { { type = "header", label = L["Layout"] } }
    list[#list + 1] = FrameSlider(id, "columns", L["Columns"], 4, 24, 1)
    list[#list + 1] = FrameSlider(id, "scale", L["Scale"], 0.6, 1.5, 0.05, Percent)
    list[#list + 1] = FrameSlider(id, "alpha", L["Background opacity"], 0.3, 1, 0.05, Percent)
    for _, e in ipairs(extra or {}) do list[#list + 1] = e end
    list[#list + 1] = { type = "header", label = L["Open"] }
    list[#list + 1] = { type = "button", label = L["Show window"], func = function() AIO:Toggle(id) end }
    return list
end

AIO:NewModule("bags", {
    title = L["General"],
    short = L["Replacing the default windows, item display, tooltip counts."],
    desc = L["Bags, bank and guild bank in one window each. The search dims what you are not looking for, the sort button tidies the bags, and the head icon shows the bags and bank of your other characters."],
    category = "bags",
    alwaysOn = true,
    options = general,
})

AIO:NewModule("bagsInventory", {
    title = L["Bags"],
    short = L["Columns, size and keyring of the bag window."],
    desc = L["The window for your bags. B or /aio opens it."],
    category = "bags",
    alwaysOn = true,
    options = WindowOptions("inventory", {
        { type = "header", label = L["Keyring"] },
        Toggle("showKeyring", L["Show keyring in bags"]),
    }),
})

AIO:NewModule("bagsBank", {
    title = L["Bank"],
    short = L["Columns and size of the bank window."],
    desc = L["Opens by itself at a banker; elsewhere it shows the bank as last seen. /aio bank"],
    category = "bags",
    alwaysOn = true,
    options = WindowOptions("bank"),
})

AIO:NewModule("bagsGuild", {
    title = L["Guild Bank"],
    short = L["Columns and size of the guild bank window."],
    desc = L["Opens by itself at the guild vault; elsewhere it shows the tabs as last seen. /aio guild"],
    category = "bags",
    alwaysOn = true,
    options = WindowOptions("guild"),
})

AIO.windowPages = { inventory = "bagsInventory", bank = "bagsBank", guild = "bagsGuild" }
