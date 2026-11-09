-- AllInOne: tooltips. Item and spell IDs, item level, vendor price, class
-- colours, guild, realm and target on unit tooltips, a flat dark look with a
-- border in the item quality or class colour, and anchoring at the cursor.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L
local Style = AIO.Style
local C = Style.color

if GetLocale() == "deDE" then
    L["Tooltips"]            = "Tooltips"
    L["IDs, item level, vendor price, class colours and a flat look for tooltips."] =
        "IDs, Itemlevel, Verkaufspreis, Klassenfarben und ein flacher Look für Tooltips."
    L["Adds useful lines to item, spell and unit tooltips and gives every tooltip the addon's flat dark look. The border can take the colour of the item quality or the player's class."] =
        "Ergänzt Gegenstands-, Zauber- und Einheiten-Tooltips um nützliche Zeilen und gibt allen Tooltips den flachen, dunklen Look des Addons. Der Rahmen kann die Farbe der Gegenstandsqualität oder der Klasse annehmen."
    L["Items & spells"]      = "Gegenstände & Zauber"
    L["Item ID"]             = "Gegenstands-ID"
    L["Spell ID"]            = "Zauber-ID"
    L["Show item ID"]        = "Gegenstands-ID zeigen"
    L["Show spell ID"]       = "Zauber-ID zeigen"
    L["Item level on armour and weapons"] = "Itemlevel auf Rüstung und Waffen"
    L["Item Level"]          = "Itemlevel"
    L["Vendor sell price"]   = "Verkaufspreis beim Händler"
    L["Sell price"]          = "Verkaufspreis"
    L["Not shown while a merchant is open, the merchant window shows it already."] =
        "Wird bei offenem Händler nicht gezeigt, das Händlerfenster zeigt ihn bereits."
    L["Units"]               = "Einheiten"
    L["Class-coloured player names"] = "Spielernamen in Klassenfarbe"
    L["Coloured guild line"] = "Gildenzeile farbig"
    L["Realm of players from other realms"] = "Realm von Spielern anderer Realms"
    L["Realm"]               = "Realm"
    L["Target line"]         = "Zeile mit dem Ziel"
    L["Target:"]             = "Ziel:"
    L["You"]                 = "Du"
    L["Hide the health bar under unit tooltips"] = "Lebensbalken unter Einheiten-Tooltips ausblenden"
    L["Look & position"]     = "Aussehen & Position"
    L["Flat tooltip style"]  = "Flacher Tooltip-Stil"
    L["Border in item quality or class colour"] = "Rahmen in Qualitäts- oder Klassenfarbe"
    L["Anchor tooltips at the cursor"] = "Tooltips am Mauszeiger verankern"
    L["Only tooltips that would appear in the default corner follow the cursor."] =
        "Nur Tooltips, die sonst in der Standardecke erscheinen, folgen dem Mauszeiger."
end

local M = AIO:NewModule("tooltip", {
    title    = L["Tooltips"],
    short    = L["IDs, item level, vendor price, class colours and a flat look for tooltips."],
    desc     = L["Adds useful lines to item, spell and unit tooltips and gives every tooltip the addon's flat dark look. The border can take the colour of the item quality or the player's class."],
    category = "display",
    default  = true,
    defaults = {
        itemID = true, spellID = true, itemLevel = true, sellPrice = true,
        classNames = true, guild = true, realm = true, target = true, hideHealth = false,
        flat = true, qualityBorder = true, anchorCursor = false,
    },
    options = {
        { type = "header", label = L["Items & spells"] },
        { type = "toggle", key = "itemID",    label = L["Show item ID"],  half = true },
        { type = "toggle", key = "spellID",   label = L["Show spell ID"], half = true },
        { type = "toggle", key = "itemLevel", label = L["Item level on armour and weapons"], half = true },
        { type = "toggle", key = "sellPrice", label = L["Vendor sell price"], half = true,
          desc = L["Not shown while a merchant is open, the merchant window shows it already."] },
        { type = "header", label = L["Units"] },
        { type = "toggle", key = "classNames", label = L["Class-coloured player names"], half = true },
        { type = "toggle", key = "guild",      label = L["Coloured guild line"], half = true },
        { type = "toggle", key = "realm",      label = L["Realm of players from other realms"], half = true },
        { type = "toggle", key = "target",     label = L["Target line"], half = true },
        { type = "toggle", key = "hideHealth", label = L["Hide the health bar under unit tooltips"] },
        { type = "header", label = L["Look & position"] },
        { type = "toggle", key = "flat",          label = L["Flat tooltip style"], half = true },
        { type = "toggle", key = "qualityBorder", label = L["Border in item quality or class colour"], half = true },
        { type = "toggle", key = "anchorCursor",  label = L["Anchor tooltips at the cursor"],
          desc = L["Only tooltips that would appear in the default corner follow the cursor."] },
    },
})

local GUILD_COLOR = { 0.25, 1, 0.25 }
local ID_COLOR = C.muted

local function Tooltips()
    return { GameTooltip, ItemRefTooltip, _G.ShoppingTooltip1, _G.ShoppingTooltip2 }
end

-- ---------------------------------------------------------------------------
-- Colours of the tooltip frame
-- ---------------------------------------------------------------------------

local function SetColors(tt, bg, border)
    local ns9 = tt.NineSlice
    if ns9 and ns9.SetCenterColor then
        if bg then pcall(ns9.SetCenterColor, ns9, bg[1], bg[2], bg[3], bg[4] or 1) end
        if border and ns9.SetBorderColor then pcall(ns9.SetBorderColor, ns9, border[1], border[2], border[3], border[4] or 1) end
    else
        if bg and tt.SetBackdropColor then pcall(tt.SetBackdropColor, tt, bg[1], bg[2], bg[3], bg[4] or 1) end
        if border and tt.SetBackdropBorderColor then
            pcall(tt.SetBackdropBorderColor, tt, border[1], border[2], border[3], border[4] or 1)
        end
    end
end

local DEFAULT_BG = { 0.09, 0.09, 0.19, 1 }
local DEFAULT_BORDER = { 1, 1, 1, 1 }

local function Paint(tt)
    if not tt then return end
    if not M.enabled then
        if tt.aioPainted then
            tt.aioPainted = nil
            local bg = TOOLTIP_DEFAULT_BACKGROUND_COLOR
            local bd = TOOLTIP_DEFAULT_COLOR
            SetColors(tt, bg and { bg.r, bg.g, bg.b, 1 } or DEFAULT_BG, bd and { bd.r, bd.g, bd.b, 1 } or DEFAULT_BORDER)
        end
        return
    end
    local db = M.db
    local border = (db.qualityBorder and tt.aioBorder) or nil
    if db.flat then
        SetColors(tt, C.bg, border or C.line)
        tt.aioPainted = true
    elseif border then
        SetColors(tt, nil, border)
        tt.aioPainted = true
    elseif tt.aioPainted then
        tt.aioPainted = nil
        local bd = TOOLTIP_DEFAULT_COLOR
        SetColors(tt, nil, bd and { bd.r, bd.g, bd.b, 1 } or DEFAULT_BORDER)
    end
end
M.Paint = Paint

-- ---------------------------------------------------------------------------
-- Line helpers: each kind of line is added once per tooltip until it is cleared
-- ---------------------------------------------------------------------------

local function Once(tt, what)
    tt.aioTip = tt.aioTip or {}
    if tt.aioTip[what] then return false end
    tt.aioTip[what] = true
    return true
end

local function Cleared(tt)
    tt.aioTip = nil
    tt.aioBorder = nil
    if M.enabled then Paint(tt) end
end

local function AddID(tt, label, id)
    tt:AddDoubleLine(label, tostring(id), ID_COLOR[1], ID_COLOR[2], ID_COLOR[3], ID_COLOR[1], ID_COLOR[2], ID_COLOR[3])
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

--- Stack size of the item under the mouse, if the tooltip belongs to a bag slot.
local function StackCount(tt, link)
    local owner = tt.GetOwner and tt:GetOwner()
    if not owner then return 1 end
    local bag, slot = owner.bag, owner.slot
    if (bag == nil or slot == nil) and owner.GetID and owner.GetParent then
        local parent = owner:GetParent()
        if parent and parent.GetID then bag, slot = parent:GetID(), owner:GetID() end
    end
    if type(bag) == "number" and type(slot) == "number" and slot > 0 then
        local ok, info = pcall(AIO.SlotInfo, bag, slot)
        if ok and info and info.hyperlink and AIO.ItemID(info.hyperlink) == AIO.ItemID(link) then
            return info.stackCount or 1
        end
    end
    local count = owner.count or owner.Count
    if type(count) == "number" and count > 0 then return count end
    return 1
end

local function OnItem(tt)
    if not M.enabled or not tt or not tt.GetItem then return end
    local _, link = tt:GetItem()
    if not link then return end
    local db = M.db
    local id = AIO.ItemID(link)
    local _, _, quality, ilvl, _, _, _, _, _, _, sellPrice = AIO.ItemInfo(link)
    local _, classID = AIO.ItemInstant(link)
    local changed = false

    if db.itemLevel and ilvl and ilvl > 1 and (classID == 2 or classID == 4) and Once(tt, "ilvl") then
        tt:AddLine(("%s %d"):format(L["Item Level"], ilvl), 1, 0.82, 0)
        changed = true
    end
    if db.sellPrice and sellPrice and sellPrice > 0 and Once(tt, "price")
       and not (MerchantFrame and MerchantFrame:IsShown()) then
        local count = StackCount(tt, link)
        local text = AIO.Money(sellPrice * count)
        if count > 1 then text = ("|cffaaaaaa%d x|r %s"):format(count, text) end
        tt:AddDoubleLine(L["Sell price"], text, C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        changed = true
    end
    if db.itemID and id and Once(tt, "itemID") then
        AddID(tt, L["Item ID"], id)
        changed = true
    end
    if quality then
        local r, g, b = AIO.QualityColor(quality)
        if r then tt.aioBorder = { r, g, b, 1 } end
    end
    Paint(tt)
    if changed then tt:Show() end
end

-- ---------------------------------------------------------------------------
-- Spells and auras
-- ---------------------------------------------------------------------------

local function AddSpellID(tt, id)
    if not M.enabled or not M.db.spellID or not id then return end
    if Once(tt, "spellID") then
        AddID(tt, L["Spell ID"], id)
        tt:Show()
    end
end

local function OnSpell(tt, data)
    if not M.enabled or not tt then return end
    local id = data and data.id
    if not id and tt.GetSpell then
        local _, a, b = tt:GetSpell()
        id = tonumber(b) or tonumber(a)
    end
    AddSpellID(tt, id)
end

local function OnAura(tt, unit, index, filter)
    if not M.enabled or not UnitAura then return end
    local ok, r = pcall(function() return select(10, UnitAura(unit, index, filter)) end)
    if ok then AddSpellID(tt, r) end
end

-- ---------------------------------------------------------------------------
-- Units
-- ---------------------------------------------------------------------------

local function ClassColor(unit)
    if not UnitIsPlayer(unit) then return nil end
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b, 1 } end
end

local function LineText(tt, i)
    local name = tt.GetName and tt:GetName()
    return name and _G[name .. "TextLeft" .. i]
end

local function UnitColorText(unit, text)
    local c = ClassColor(unit)
    if c then return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text) end
    return text
end

local function OnUnit(tt)
    if not M.enabled or not tt or not tt.GetUnit then return end
    local _, unit = tt:GetUnit()
    if not unit and UnitExists and UnitExists("mouseover") then unit = "mouseover" end
    if not unit or not UnitExists(unit) then return end
    local db = M.db
    local changed = false
    local classColor = ClassColor(unit)

    if UnitIsPlayer(unit) then
        if db.classNames and classColor then
            local first = LineText(tt, 1)
            if first then first:SetTextColor(classColor[1], classColor[2], classColor[3]) end
        end
        if db.guild then
            local guild, rank = GetGuildInfo(unit)
            if guild then
                local found = false
                local n = tt.NumLines and tt:NumLines() or 0
                for i = 2, n do
                    local fs = LineText(tt, i)
                    local text = fs and fs:GetText()
                    if text and (text == guild or text:find(guild, 1, true)) then
                        fs:SetTextColor(GUILD_COLOR[1], GUILD_COLOR[2], GUILD_COLOR[3])
                        found = true
                        break
                    end
                end
                if not found and Once(tt, "guild") then
                    local text = "<" .. guild .. ">"
                    if rank and rank ~= "" then text = text .. " |cffaaaaaa" .. rank .. "|r" end
                    tt:AddLine(text, GUILD_COLOR[1], GUILD_COLOR[2], GUILD_COLOR[3])
                    changed = true
                end
            end
        end
        if db.realm then
            local _, realm = UnitName(unit)
            if realm and realm ~= "" and realm ~= GetRealmName() and Once(tt, "realm") then
                tt:AddDoubleLine(L["Realm"], realm, C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
                changed = true
            end
        end
    end

    if db.target and Once(tt, "target") then
        local target = unit .. "target"
        if UnitExists(target) then
            local text
            if UnitIsUnit(target, "player") then
                text = "|cffff4040" .. L["You"] .. "|r"
            else
                text = UnitColorText(target, UnitName(target) or "?")
            end
            tt:AddLine(L["Target:"] .. " " .. text, 1, 1, 1)
            changed = true
        end
    end

    if classColor then tt.aioBorder = classColor end
    if db.hideHealth and GameTooltipStatusBar and tt == GameTooltip then GameTooltipStatusBar:Hide() end
    Paint(tt)
    if changed then tt:Show() end
end

-- ---------------------------------------------------------------------------
-- Hooks (installed once, gated by M.enabled)
-- ---------------------------------------------------------------------------

local hooked = false

local function SafeHook(frame, script, fn)
    if frame and frame.HookScript then pcall(frame.HookScript, frame, script, fn) end
end

local function InstallHooks()
    if hooked then return end
    hooked = true

    for _, tt in ipairs(Tooltips()) do
        if tt then
            SafeHook(tt, "OnTooltipCleared", Cleared)
            SafeHook(tt, "OnShow", Paint)
        end
    end

    local TDP = TooltipDataProcessor
    local TT = Enum and Enum.TooltipDataType
    if TDP and TDP.AddTooltipPostCall and TT then
        if TT.Item then TDP.AddTooltipPostCall(TT.Item, function(tt) OnItem(tt) end) end
        if TT.Unit then TDP.AddTooltipPostCall(TT.Unit, function(tt) OnUnit(tt) end) end
        if TT.Spell then TDP.AddTooltipPostCall(TT.Spell, function(tt, data) OnSpell(tt, data) end) end
    else
        for _, tt in ipairs(Tooltips()) do
            if tt then
                SafeHook(tt, "OnTooltipSetItem", OnItem)
                SafeHook(tt, "OnTooltipSetSpell", function(self) OnSpell(self) end)
            end
        end
        SafeHook(GameTooltip, "OnTooltipSetUnit", OnUnit)
    end

    for _, method in ipairs({ "SetUnitAura", "SetUnitBuff", "SetUnitDebuff" }) do
        if GameTooltip[method] then
            local filter = method == "SetUnitBuff" and "HELPFUL" or (method == "SetUnitDebuff" and "HARMFUL") or nil
            hooksecurefunc(GameTooltip, method, function(tt, unit, index, f)
                OnAura(tt, unit, index, filter or f)
            end)
        end
    end

    if GameTooltip_SetDefaultAnchor then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            if M.enabled and M.db.anchorCursor and tooltip and parent then
                tooltip:SetOwner(parent, "ANCHOR_CURSOR")
            end
        end)
    end

    if GameTooltipStatusBar then
        SafeHook(GameTooltipStatusBar, "OnShow", function(bar)
            if M.enabled and M.db.hideHealth then bar:Hide() end
        end)
    end
end

function M:OnEnable()
    InstallHooks()
    for _, tt in ipairs(Tooltips()) do Paint(tt) end
end

function M:OnDisable()
    for _, tt in ipairs(Tooltips()) do Paint(tt) end
end

function M:OnSettingChanged()
    for _, tt in ipairs(Tooltips()) do Paint(tt) end
end
