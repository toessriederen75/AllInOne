-- AllInOne for TBC Anniversary: build settings, read before everything else.
-- The bag, bank and guild bank windows use Blizzard's modern bag look, the
-- same as AllInOneForever. Where the game lacks a template or picture for it,
-- the windows fall back on their own and keep working.
local ADDON, ns = ...
ns.skin = "modern"
-- Every other window of the addon (options, menus, side panels) gets the
-- same Blizzard frame, background and buttons as the bags.
ns.ui = "blizzard"
