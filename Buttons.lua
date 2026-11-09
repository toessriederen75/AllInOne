-- AllInOne: item buttons.
--
-- Two kinds:
--   live    a bag or bank slot you can click. Built on Blizzard's own
--           ContainerFrameItemButtonTemplate, so using, selling, moving and
--           linking items works exactly as in the default bags. Its parent is a
--           small holder frame whose ID is the bag, which is what the template
--           reads its bag from.
--   static  everything else: another character's items, the saved bank, and
--           every guild bank slot (live or saved). Drawn by us; in the open
--           guild bank it picks up and stores items itself.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

local SIZE = AIO.SIZE
local counter = 0

local function NextName()
    counter = counter + 1
    return "AllInOneItem" .. counter
end

local Style = AIO.Style

local MODERN_SLOT
if ns.skin == "modern" and C_Texture and C_Texture.GetAtlasInfo then
    local ok, info = pcall(C_Texture.GetAtlasInfo, "bags-item-slot64")
    if ok and info then MODERN_SLOT = "bags-item-slot64" end
end

local function Decorate(b)
    b:SetSize(SIZE, SIZE)
    local name = b:GetName()
    b.aioIcon  = b.icon or b.Icon or (name and _G[name .. "IconTexture"])
    b.aioCount = b.Count or (name and _G[name .. "Count"])
    b.aioCooldown = b.Cooldown or (name and _G[name .. "Cooldown"])

    if not b.aioIcon then
        b.aioIcon = b:CreateTexture(nil, "BORDER")
    end
    -- The look of Blizzard's own bag slots (as Bagnon has it): the empty-slot
    -- picture behind, the full icon, the bevelled slot frame on top and the
    -- quality glow around the icon.
    if not b.aioEmpty then
        b.aioEmpty = b:CreateTexture(nil, "BACKGROUND", nil, -1)
        -- Blizzard's modern bags (Forever) have their own empty-slot picture.
        if MODERN_SLOT then
            b.aioEmpty:SetAtlas(MODERN_SLOT)
        else
            b.aioEmpty:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        end
        b.aioEmpty:SetAllPoints()
    end
    b.aioIcon:ClearAllPoints()
    b.aioIcon:SetAllPoints()
    b.aioIcon:SetTexCoord(0, 1, 0, 1)

    if not b.aioCount then
        b.aioCount = b:CreateFontString(nil, "OVERLAY")
    end
    b.aioCount:SetFontObject(Style.Font(12, "OUTLINE"))
    b.aioCount:ClearAllPoints()
    b.aioCount:SetPoint("BOTTOMRIGHT", -3, 2)

    local normal = b.GetNormalTexture and b:GetNormalTexture()
    if not normal and b.SetNormalTexture then
        b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
        normal = b:GetNormalTexture()
    end
    if normal then
        normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normal:ClearAllPoints()
        normal:SetSize(SIZE * 64 / 37, SIZE * 64 / 37)
        normal:SetPoint("CENTER", 0, -1)
        normal:SetAlpha(1)
    end
    if b.IconBorder then b.IconBorder:SetAlpha(0) end
    b.aioQuality = b:CreateTexture(nil, "OVERLAY")
    b.aioQuality:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.aioQuality:SetAllPoints()
    b.aioQuality:Hide()
    if b.SetHighlightTexture then
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
    if b.SetPushedTexture and not (b.GetPushedTexture and b:GetPushedTexture()) then
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    end
    local pushed = b.GetPushedTexture and b:GetPushedTexture()
    if pushed then pushed:SetAlpha(1); pushed:SetAllPoints() end

    b.aioLevel = b:CreateFontString(nil, "OVERLAY")
    b.aioLevel:SetFontObject(Style.Font(10, "OUTLINE"))
    b.aioLevel:SetPoint("TOPLEFT", 2, -2)

    -- Padlock: this slot is left alone by the sort button.
    b.aioLock = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.aioLock:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\lock")
    b.aioLock:SetSize(14, 14)
    b.aioLock:SetPoint("TOPRIGHT", -1, -1)
    b.aioLock:Hide()

    b.aioJunk = b:CreateTexture(nil, "OVERLAY")
    b.aioJunk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    b.aioJunk:SetSize(14, 14)
    b.aioJunk:SetPoint("TOPLEFT", 1, -1)
    b.aioJunk:Hide()
end

-- Template extras we do not use and that must not linger from earlier use.
local EXTRAS = { "NewItemTexture", "BattlepayItemTexture", "JunkIcon", "UpgradeIcon",
                 "IconQuestTexture", "flash", "searchOverlay", "ExtendedSlot" }

local function HideExtras(b)
    for _, key in ipairs(EXTRAS) do
        local region = b[key]
        if region and region.Hide then region:Hide() end
    end
end

-- Item class and level never change for an item ID, so they are looked up
-- once and kept: painting a full bag then costs no item API calls at all.
local classOf, levelOf = {}, {}

function AIO:ItemClassLevel(link)
    local id = link and self.ItemID(link)
    if not id then return nil end
    local class = classOf[id]
    if class == nil then
        local _, c = self.ItemInstant(link)
        class = c or false
        classOf[id] = class
    end
    local level = levelOf[id]
    if level == nil and (class == 2 or class == 4) then
        local name, _, _, l = self.ItemInfo(link)
        if name then levelOf[id] = l or false; level = l end
    end
    return class or nil, level or nil
end

--- Paints a button. `icon` is nil for an empty slot.
function AIO:Paint(b, icon, count, quality, locked, link)
    b.link = link
    local s = self.settings
    if icon then
        b.aioIcon:SetTexture(icon)
        b.aioIcon:Show()
        b.aioIcon:SetDesaturated(locked and true or false)
    else
        b.aioIcon:Hide()
    end

    if count and count > 1 then
        b.aioCount:SetText(count > 9999 and "*" or count)
        b.aioCount:Show()
    else
        b.aioCount:Hide()
    end

    local classID, ilvl = self:ItemClassLevel(link)
    local r, g, bl
    if icon and s.qualityBorder then
        if classID == 12 then          -- quest item
            r, g, bl = 1, 0.82, 0
        elseif quality and quality >= 2 then
            r, g, bl = self.QualityColor(quality)
        end
    end
    if r then
        b.aioQuality:SetVertexColor(r, g, bl, 1)
        b.aioQuality:Show()
    else
        b.aioQuality:Hide()
    end

    -- Item level on gear, a coin on junk.
    local level
    if icon and s.itemLevel and (classID == 2 or classID == 4) and (quality or 0) >= 2 then
        level = ilvl
    end
    if level and level > 1 then
        b.aioLevel:SetText(level)
        local lr, lg, lb = self.QualityColor(quality)
        b.aioLevel:SetTextColor(lr or 1, lg or 1, lb or 1)
        b.aioLevel:Show()
    else
        b.aioLevel:Hide()
    end
    b.aioJunk:SetShown(icon ~= nil and s.junkIcon and quality == 0)
    HideExtras(b)
end

-- ---------------------------------------------------------------------------
-- Live bag and bank slots
-- ---------------------------------------------------------------------------

local function CreateFromTemplate(parent)
    local name = NextName()
    local ok, b = pcall(CreateFrame, "ItemButton", name, parent, "ContainerFrameItemButtonTemplate")
    if not ok or not b then
        b = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate")
    end
    return b
end

-- The tooltip of a live slot. Blizzard's template refreshes its tooltip
-- several times a second and on some clients loses the item on the way, so
-- the slot sets it itself from the bag and slot it knows. The same function
-- is the refresh (UpdateTooltip), so a refresh shows the same item again.
-- The main bank (bag -1) is not a bag to the tooltip; it is read as an
-- inventory slot of the player.
-- The coin cursor at a merchant: a C_Container function on newer clients.
local SellCursor = (C_Container and C_Container.ShowContainerSellCursor) or _G.ShowContainerSellCursor
local InspectCursor = _G.ShowInspectCursor

local function LiveEnter(self)
    local bag, slot = self.bag, self.slot
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if bag == AIO.BANK then
        local inv = _G.BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(slot) or (39 + slot)
        GameTooltip:SetInventoryItem("player", inv)
    else
        GameTooltip:SetBagItem(bag, slot)
    end
    if GameTooltip:NumLines() == 0 then
        GameTooltip:Hide()
        ResetCursor()
        return
    end
    GameTooltip:Show()
    if (IsModifiedClick and IsModifiedClick("COMPAREITEMS"))
       or (GetCVarBool and GetCVarBool("alwaysCompareItems")) then
        if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
    end
    -- The cursor as in Blizzard's bags: coin at a merchant, magnifier to try on.
    if MerchantFrame and MerchantFrame:IsShown() and SellCursor then
        SellCursor(bag, slot)
    elseif IsModifiedClick and IsModifiedClick("DRESSUP") and InspectCursor then
        InspectCursor()
    else
        ResetCursor()
    end
end

local function LiveLeave()
    GameTooltip_Hide()
    ResetCursor()
end

function AIO:LiveButton(window, bag, slot)
    window.live = window.live or {}
    window.holders = window.holders or {}
    local holder = window.holders[bag]
    if not holder then
        holder = CreateFrame("Frame", nil, window.content)
        holder:SetID(bag)
        holder:SetAllPoints(window.content)
        window.holders[bag] = holder
    end
    window.live[bag] = window.live[bag] or {}
    local b = window.live[bag][slot]
    if b then return b end
    if InCombatLockdown() then return nil end   -- made after the fight

    b = CreateFromTemplate(holder)
    b:SetID(slot)
    b.bag, b.slot, b.isLive = bag, slot, true
    Decorate(b)
    b:SetScript("OnEnter", LiveEnter)
    b:SetScript("OnLeave", LiveLeave)
    b.UpdateTooltip = LiveEnter
    window.live[bag][slot] = b
    return b
end

function AIO:PaintLive(b)
    local info = self.SlotInfo(b.bag, b.slot)
    if info then
        self:Paint(b, info.iconFileID, info.stackCount, info.quality, info.isLocked, info.hyperlink)
    else
        self:Paint(b, nil)
    end
    b.aioLock:SetShown(self:IsSortLocked(b.bag, b.slot))
    if b.aioCooldown and CooldownFrame_Set then
        local start, duration, enable = self.SlotCooldown(b.bag, b.slot)
        if info and start then
            CooldownFrame_Set(b.aioCooldown, start, duration, enable)
        else
            b.aioCooldown:Hide()
        end
    end
    return info
end

-- ---------------------------------------------------------------------------
-- Static buttons: other characters, the saved bank, the guild bank
-- ---------------------------------------------------------------------------

local function StaticEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.mode == "guild" and AIO.atGuild and self.guildLive and GameTooltip.SetGuildBankItem then
        GameTooltip:SetGuildBankItem(self.tab, self.slot)
    elseif self.link then
        GameTooltip:SetHyperlink(self.link)
    else
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
end

local function GuildLive(self)
    return self.mode == "guild" and self.guildLive and AIO.atGuild
end

local function StaticClick(self, button)
    if self.link and HandleModifiedItemClick and HandleModifiedItemClick(self.link) then return end
    if GuildLive(self) then
        if button == "RightButton" then
            AutoStoreGuildBankItem(self.tab, self.slot)
        else
            PickupGuildBankItem(self.tab, self.slot)
        end
    end
end

local function StaticDrag(self)
    if GuildLive(self) then PickupGuildBankItem(self.tab, self.slot) end
end

function AIO:StaticButton(window, index)
    window.statics = window.statics or {}
    local b = window.statics[index]
    if b then return b end
    b = CreateFrame("Button", NextName(), window.content)
    Decorate(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", StaticEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", StaticClick)
    b:SetScript("OnDragStart", StaticDrag)
    b:SetScript("OnReceiveDrag", StaticDrag)
    window.statics[index] = b
    return b
end
