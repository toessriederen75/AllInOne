-- AllInOne: one addon for several game versions.
--
-- TBC Anniversary still has the classic global functions (GetItemInfo,
-- UnitBuff, GetQuestLogTitle ...). WoW Forever runs on the modern client,
-- where most of them moved into C_ tables. Instead of sprinkling checks over
-- every file, the missing ones are rebuilt here once, from their modern
-- counterparts, and every AllInOne file sees them through its own
-- environment. Nothing is written into the global table, so other addons
-- see the game exactly as it is.
--
-- On a client that has all of them (Anniversary) nothing is built and no
-- environment is set: zero cost there.

local ADDON, ns = ...

-- Which game this is. WOW_PROJECT_CAMELOT is Forever's own project ID.
local PROJECT = WOW_PROJECT_ID
local TOC = GetBuildInfo and select(4, GetBuildInfo()) or nil
ns.isForever = (WOW_PROJECT_CAMELOT ~= nil and PROJECT == WOW_PROJECT_CAMELOT) or PROJECT == 18
    or (TOC ~= nil and TOC >= 16000 and TOC < 20000)   -- Forever's own interface numbers
ns.isTBC     = WOW_PROJECT_BURNING_CRUSADE_CLASSIC ~= nil and PROJECT == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
ns.isModern  = C_Item ~= nil and _G.GetItemInfo == nil   -- modern client API

local shim = {}

local function Missing(name) return _G[name] == nil end

-- Items ----------------------------------------------------------------------
if C_Item then
    for _, n in ipairs({ "GetItemInfo", "GetItemInfoInstant", "GetItemQualityColor", "GetItemCount",
                         "GetItemSpell", "GetItemCooldown", "IsUsableItem", "GetItemFamily" }) do
        if Missing(n) and C_Item[n] then shim[n] = C_Item[n] end
    end
    if Missing("GetItemIcon") and C_Item.GetItemIconByID then shim.GetItemIcon = C_Item.GetItemIconByID end
end

-- Containers (bags) ------------------------------------------------------------
if C_Container then
    for _, n in ipairs({ "GetContainerNumSlots", "GetContainerNumFreeSlots", "GetContainerItemLink",
                         "PickupContainerItem", "UseContainerItem", "GetContainerItemID", "SplitContainerItem",
                         "GetContainerItemCooldown", "GetBagName", "SortBags", "SortBankBags" }) do
        local modern = C_Container[n] or C_Container[(n:gsub("Container", ""))]
        if Missing(n) and modern then shim[n] = modern end
    end
end

-- Spells ---------------------------------------------------------------------
if Missing("GetSpellInfo") and C_Spell and C_Spell.GetSpellInfo then
    local Get = C_Spell.GetSpellInfo
    shim.GetSpellInfo = function(spell)
        if spell == nil then return end
        local t = Get(spell)
        if t then return t.name, nil, t.iconID, t.castTime, t.minRange, t.maxRange, t.spellID, t.originalIconID end
    end
end
if Missing("GetSpellTexture") and C_Spell and C_Spell.GetSpellTexture then shim.GetSpellTexture = C_Spell.GetSpellTexture end
if Missing("GetSpellBookItemName") and C_SpellBook and C_SpellBook.GetSpellBookItemName then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    shim.GetSpellBookItemName = function(i) return C_SpellBook.GetSpellBookItemName(i, bank) end
end
if Missing("IsSpellKnown") and C_SpellBook and C_SpellBook.IsSpellKnown then shim.IsSpellKnown = C_SpellBook.IsSpellKnown end

-- Auras ----------------------------------------------------------------------
-- WoW Forever (like Midnight) hides aura data from addons at times, e.g. in
-- combat: reading it then raises an error. ns.SafeAura reads one aura and
-- answers (nil, true) when the game does not allow it right now, so callers
-- can keep what they last knew and look again later.
do
    local Get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    local secret = _G.issecretvalue
    function ns.SafeAura(unit, i, filter)
        if not Get then return nil end
        local ok, a = pcall(Get, unit, i, filter)
        if not ok then return nil, true end
        if a and secret and (secret(a.name) or secret(a.expirationTime)) then return nil, true end
        return a
    end
end

if Missing("UnitAura") and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local GetAura = ns.SafeAura
    local function Unpack(a)
        if not a then return end
        return a.name, a.icon, a.applications, a.dispelName, a.duration, a.expirationTime, a.sourceUnit,
            a.isStealable, a.nameplateShowPersonal, a.spellId
    end
    shim.UnitAura   = function(unit, i, filter) return Unpack(GetAura(unit, i, filter)) end
    shim.UnitBuff   = function(unit, i, filter) return Unpack(GetAura(unit, i, filter or "HELPFUL")) end
    shim.UnitDebuff = function(unit, i, filter) return Unpack(GetAura(unit, i, filter or "HARMFUL")) end
end

-- Quest log --------------------------------------------------------------------
if Missing("GetNumQuestLogEntries") and C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    shim.GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
end
if Missing("GetQuestLogTitle") and C_QuestLog and C_QuestLog.GetInfo then
    local IsComplete = C_QuestLog.IsComplete
    shim.GetQuestLogTitle = function(i)
        local q = C_QuestLog.GetInfo(i)
        if not q then return end
        local done = q.questID and IsComplete and IsComplete(q.questID) and 1 or nil
        return q.title, q.level, nil, q.isHeader, q.isCollapsed, done, q.frequency, q.questID
    end
end

-- Add-ons, friends, gossip ---------------------------------------------------------
if C_AddOns then
    for _, n in ipairs({ "IsAddOnLoaded", "GetAddOnMetadata", "LoadAddOn", "GetAddOnInfo" }) do
        if Missing(n) and C_AddOns[n] then shim[n] = C_AddOns[n] end
    end
end
if C_FriendList then
    if Missing("GetNumFriends") and C_FriendList.GetNumFriends then shim.GetNumFriends = C_FriendList.GetNumFriends end
    if Missing("GetFriendInfo") and C_FriendList.GetFriendInfoByIndex then
        shim.GetFriendInfo = function(i)
            local f = C_FriendList.GetFriendInfoByIndex(i)
            if f then return f.name, f.level, f.className, f.area, f.connected, f.notes end
        end
    end
end
if Missing("SelectGossipActiveQuest") and C_GossipInfo and C_GossipInfo.SelectActiveQuest then
    shim.SelectGossipActiveQuest = C_GossipInfo.SelectActiveQuest
end
if Missing("SelectGossipAvailableQuest") and C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
    shim.SelectGossipAvailableQuest = C_GossipInfo.SelectAvailableQuest
end
if Missing("GetNumPartyMembers") and GetNumSubgroupMembers then shim.GetNumPartyMembers = GetNumSubgroupMembers end
if Missing("GetNumRaidMembers") and GetNumGroupMembers then
    shim.GetNumRaidMembers = function() return IsInRaid and IsInRaid() and GetNumGroupMembers() or 0 end
end

-- Only when something had to be rebuilt does AllInOne get its own view of
-- the globals: shims first, then the real global table. Assignments still
-- go to the real global table (slash commands, the AllInOne global).
if next(shim) then
    setmetatable(shim, { __index = _G })
    ns.env = setmetatable({}, { __index = shim, __newindex = _G })
    ns.shim = shim

    -- Some game functions build their result from a Blizzard mixin they look
    -- up by name in the caller's own globals, without following __index
    -- (C_Map.GetPlayerMapPosition needs Vector2DMixin, and so on). So every
    -- mixin is put into AllInOne's view directly: now, and again at login for
    -- those Blizzard loads later. Only references are copied; costs nothing.
    local env = ns.env
    local function SyncMixins()
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "table" and k:sub(-5) == "Mixin" and rawget(env, k) == nil then
                rawset(env, k, v)
            end
        end
    end
    SyncMixins()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self) SyncMixins(); self:UnregisterAllEvents() end)
end
