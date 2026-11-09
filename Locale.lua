-- AllInOne: texts. English is the key and the fallback; German is filled in below.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

if GetLocale() == "deDE" then
    L["Bags"]                 = "Taschen"
    L["Bank"]                 = "Bank"
    L["Guild Bank"]           = "Gildenbank"
    L["%s's bags"]            = "Taschen von %s"
    L["%s's bank"]            = "Bank von %s"
    L["(offline)"]            = "(offline)"
    L["Search"]               = "Suchen"
    L["Sort"]                 = "Sortieren"
    L["Sorting..."]           = "Sortiere ..."
    L["Sorted."]              = "Sortiert."
    L["Sorting stopped: %s"]  = "Sortieren abgebrochen: %s"
    L["in combat"]            = "im Kampf"
    L["took too long"]        = "dauerte zu lange"
    L["item on the cursor"]   = "Gegenstand am Mauszeiger"
    L["Can't sort in combat."]        = "Im Kampf kann nicht sortiert werden."
    L["The bank must be open to sort it."] = "Zum Sortieren muss die Bank offen sein."
    L["Characters"]           = "Charaktere"
    L["Choose character"]     = "Charakter wählen"
    L["Choose guild"]         = "Gilde wählen"
    L["Options"]              = "Optionen"
    L["Free: %d/%d"]          = "Frei: %d/%d"
    L["Total"]                = "Gesamt"
    L["Danger alarm"]         = "Gefahren-Alarm"
    L["Gold on this realm"]   = "Gold auf diesem Realm"
    L["bags"]                 = "Taschen"
    L["bank"]                 = "Bank"
    L["guild"]                = "Gilde"
    L["All"]                  = "Alles"
    L["Weapons & Armor"]      = "Waffen & Rüstung"
    L["Consumables"]          = "Verbrauchbar"
    L["Trade Goods"]          = "Handwerk"
    L["Quest"]                = "Quest"
    L["Junk"]                 = "Schrott"
    L["Other"]                = "Sonstiges"
    L["Keyring"]              = "Schlüsselbund"
    L["Deposit"]              = "Einzahlen"
    L["Withdraw"]             = "Abheben"
    L["Withdrawals left: %s"] = "Abhebungen übrig: %s"
    L["unlimited"]            = "unbegrenzt"
    L["Buy bank slot"]        = "Bankfach kaufen"
    L["Buy a bank bag slot for %s?"] = "Ein Bankfach für %s kaufen?"
    L["No data for this guild yet. Open the guild bank once."] =
        "Noch keine Daten für diese Gilde. Öffne die Gildenbank einmal."
    L["No bank data yet. Visit a banker once with this character."] =
        "Noch keine Bankdaten. Besuche mit diesem Charakter einmal einen Bankier."
    L["Not in a guild."]      = "Nicht in einer Gilde."
    L["Tab %d"]               = "Tab %d"
    L["Left-drag: move  ·  Right-click: options"] = "Linksziehen: verschieben  ·  Rechtsklick: Optionen"

    -- options
    L["General"]              = "Allgemein"
    L["Replace the default bags"]       = "Standard-Taschen ersetzen"
    L["Replace the default bank"]       = "Standard-Bank ersetzen"
    L["Replace the default guild bank"] = "Standard-Gildenbank ersetzen"
    L["Needs /reload"]        = "Braucht /reload"
    L["Item counts in tooltips"]        = "Anzahl pro Charakter im Tooltip"
    L["Quality borders"]      = "Qualitätsrahmen"
    L["Show keyring in bags"] = "Schlüsselbund in den Taschen zeigen"
    L["Show or hide the keyring"] = "Schlüsselbund ein- oder ausblenden"
    L["Show empty slots"]     = "Leere Plätze zeigen"
    L["Space between slots"]  = "Abstand zwischen den Plätzen"
    L["Arrangement & sorting"] = "Anordnung & Sortieren"
    L["Unfilled row at the top"] = "Unvollständige Reihe oben"
    L["Like the default bags: the last row is full and the gaps sit at the top."] =
        "Wie bei den Standard-Taschen: die letzte Reihe ist voll, die Lücken sitzen oben."
    L["Sort from the bottom"] = "Von unten her sortieren"
    L["Quest items first"]    = "Questgegenstände zuoberst"
    L["Lock slots from sorting"] = "Plätze vom Sortieren sperren"
    L["Opens your bags; click single slots to keep them out of sorting. They show a small padlock."] =
        "Öffnet deine Taschen; klicke einzelne Plätze an, um sie vom Sortieren auszunehmen. Sie zeigen dann ein kleines Schloss."
    L["Locked slots: %d"]     = "Gesperrte Plätze: %d"
    L["Free all"]             = "Alle freigeben"
    L["Sorting always puts quest items at the very top."] = "Das Sortieren stellt Questgegenstände immer ganz nach oben."
    L["Sorting fills the last slots first, so the free slots stay at the top."] =
        "Das Sortieren füllt zuerst die hintersten Plätze, die freien Plätze bleiben oben."
    L["Lock window positions"]= "Fensterpositionen sperren"
    L["Columns"]              = "Spalten"
    L["Scale"]                = "Grösse"
    L["Background opacity"]   = "Hintergrund-Deckkraft"
    L["Reset positions"]      = "Positionen zurücksetzen"
    L["Forgot %s."]           = "%s vergessen."
    L["No saved character called %s on this realm."] = "Kein gespeicherter Charakter %s auf diesem Realm."
    L["Commands: /aio, /aio bank, /aio guild, /aio sort, /aio config, /aio forget NAME"] =
        "Befehle: /aio, /aio bank, /aio guild, /aio sort, /aio config, /aio forget NAME"

    -- framework, options window, bag page
    L["Merchants & NPCs"]     = "Händler & NPCs"
    L["Quests"]               = "Quests"
    L["Buffs & Consumables"]  = "Buffs & Verbrauchsgüter"
    L["Display"]              = "Anzeige"
    L["Comfort"]              = "Komfort"
    L["Chat"]                 = "Chat"
    L["Overview"]             = "Übersicht"
    L["On"]                   = "An"
    L["Off"]                  = "Aus"
    L["Switch whole modules on and off here. Click a name for its settings."] =
        "Hier schaltest du ganze Module ein und aus. Ein Klick auf einen Namen öffnet seine Einstellungen."
    L["%s is switched off after a /reload."] = "%s ist nach einem /reload ausgeschaltet."
    L["Replace the default windows"] = "Standardfenster ersetzen"
    L["Changes here take effect after a /reload."] = "Änderungen hier wirken nach einem /reload."
    L["Items"]                = "Gegenstände"
    L["Colours the border of an item by its quality; quest items in gold."] =
        "Färbt den Rahmen eines Gegenstands nach seiner Qualität, Questgegenstände golden."
    L["Item level on gear"]   = "Itemlevel auf Ausrüstung"
    L["Coin on junk"]         = "Münze auf Schrott"
    L["Shows how many of an item each character and the guild bank hold."] =
        "Zeigt, wie viele Stück jeder Charakter und die Gildenbank besitzen."
    L["Reset"]                = "Zurücksetzen"
    L["Bags, bank & guild bank"] = "Taschen, Bank & Gildenbank"
    L["One window each, with search, filters, sorting and your other characters."] =
        "Je ein Fenster, mit Suche, Filtern, Sortierung und deinen Twinks."
    L["Bags, bank and guild bank in one window each. The search dims what you are not looking for, the sort button tidies the bags, and the head icon shows the bags and bank of your other characters."] =
        "Taschen, Bank und Gildenbank in je einem Fenster. Die Suche dunkelt ab, was du nicht suchst, der Sortierknopf räumt die Taschen auf, und das Kopf-Symbol zeigt Taschen und Bank deiner Twinks."

    L["Reload UI"]            = "UI neu laden"
    L["Reloads the interface (/reload)."] = "Lädt die Oberfläche neu (/reload)."

    -- sections
    L["Outfits"]              = "Outfits"
    L["Cleansing"]            = "Reinigen"
    L["Maps"]                 = "Karte"
    L["Spell ranks"]          = "Zauberränge"
    L["Cast bar"]             = "Zauberleiste"
    L["Finds spells on your action bars that are not at their highest rank."] =
        "Findet Zauber auf deinen Aktionsleisten, die nicht den höchsten Rang haben."
    L["Bags & Bank"]          = "Taschen & Bank"
    L["Helpers"]              = "Alltagshelfer"
    L["Selling junk, repairing and restocking."] = "Schrott verkaufen, automatisch reparieren und nachkaufen."
    L["Accepting and handing in quests on their own, skipping gossip."] = "Quests automatisch annehmen und abgeben, Gespräche überspringen."
    L["Reminders for missing buffs and a watch on your consumables."] = "Erinnerung an fehlende Buffs und ein Blick auf deine Verbrauchsgüter."
    L["Info bar, tooltips, minimap button and experience."] = "Info-Leiste, Tooltips, Minikarten-Knopf und Erfahrung."
    L["Mail helpers, error filter, looting and small automations."] = "Post-Helfer, Fehlerfilter, Plündern und kleine Automatiken."
    L["Improvements for the chat window."] = "Verbesserungen für das Chatfenster."
    L["Blizzard windows"]     = "Blizzard-Fenster"
    L["Larger quest log, profession and trainer windows."] = "Grösseres Questlog, Berufs- und Lehrerfenster."
    L["%d of %d on"]          = "%d von %d an"
    L["Tick what you want. Point at a name to see what it does; the gear opens its settings."] =
        "Häkchen setzen, was du willst. Zeig auf einen Namen für die Erklärung, das Zahnrad öffnet die Einstellungen."
    L["Settings"]             = "Einstellungen"
    L["All helpers"]          = "Alle Helfer"
    L["Settings for the bag, bank and guild bank windows."] =
        "Einstellungen für die Fenster von Taschen, Bank und Gildenbank."
    L["Windows"]              = "Fenster"
    L["Layout"]               = "Darstellung"
    L["Open"]                 = "Öffnen"
    L["Show window"]          = "Fenster zeigen"
    L["Replacing the default windows, item display, tooltip counts."] =
        "Standardfenster ersetzen, Anzeige der Gegenstände, Anzahl im Tooltip."
    L["Columns, size and keyring of the bag window."] = "Spalten, Grösse und Schlüsselbund des Taschenfensters."
    L["The window for your bags. B or /aio opens it."] = "Das Fenster für deine Taschen. B oder /aio öffnet es."
    L["Columns and size of the bank window."] = "Spalten und Grösse des Bankfensters."
    L["Opens by itself at a banker; elsewhere it shows the bank as last seen. /aio bank"] =
        "Öffnet sich beim Bankier von selbst; anderswo zeigt es den zuletzt gesehenen Stand. /aio bank"
    L["Columns and size of the guild bank window."] = "Spalten und Grösse des Gildenbankfensters."
    L["Opens by itself at the guild vault; elsewhere it shows the tabs as last seen. /aio guild"] =
        "Öffnet sich am Gildentresor von selbst; anderswo zeigt es die Tabs im zuletzt gesehenen Stand. /aio guild"
end

BINDING_HEADER_ALLINONE         = ns.title or "AllInOne"
BINDING_NAME_ALLINONE_INVENTORY = L["Bags"]
BINDING_NAME_ALLINONE_BANK      = L["Bank"]
BINDING_NAME_ALLINONE_GUILD     = L["Guild Bank"]
BINDING_NAME_ALLINONE_SORT      = L["Sort"] .. " (" .. L["Bags"] .. ")"
