-- AllInOne: map symbols. Dungeon and raid entrances, flight masters, boats,
-- zeppelins, trams and portals, spirit healers and zone exits on the world map.
--
-- Written for AllInOne. The positions are game facts (where an entrance or a
-- flight master stands); the code, the format and the icons are our own.
--
-- Memory: the positions sit in one short string per zone and are only read
-- for the zone the map is showing. Pins are reused, never thrown away.

local ADDON, ns = ...
if ns.env then setfenv(1, ns.env) end
local AIO, L = ns.AIO, ns.L

if GetLocale() == "deDE" then
    L["Map symbols"]           = "Kartensymbole"
    L["Dungeon and raid entrances, flight masters, boats, zeppelins and portals, spirit healers and zone exits on the world map."] =
        "Dungeon- und Raideingänge, Flugmeister, Schiffe, Zeppeline und Portale, Geisterheiler und Zonenübergänge auf der Weltkarte."
    L["Show on the map"]       = "Auf der Karte zeigen"
    L["Dungeons & raids"]      = "Dungeons & Raids"
    L["Flight masters"]        = "Flugmeister"
    L["Boats, zeppelins & portals"] = "Schiffe, Zeppeline & Portale"
    L["Spirit healers"]        = "Geisterheiler"
    L["Zone exits"]            = "Zonenübergänge"
    L["Only my faction"]       = "Nur meine Fraktion"
    L["Icon size"]             = "Symbolgrösse"
    L["Dungeon"]               = "Dungeon"
    L["Raid"]                  = "Schlachtzug"
    L["Level %s"]              = "Stufe %s"
    L["Flight master"]         = "Flugmeister"
    L["Spirit healer"]         = "Geisterheiler"
    L["Boat"]                  = "Schiff"
    L["Zeppelin"]              = "Zeppelin"
    L["Tram"]                  = "Tiefenbahn"
    L["Portal"]                = "Portal"
    L["Orb of Translocation"]  = "Translokationskugel"
    L["To: %s"]                = "Nach: %s"
    L["Click: show this map"]  = "Klicken: diese Karte zeigen"
    L["Neutral"]               = "Neutral"
    L["Main gate"]             = "Haupttor"
    L["Service gate"]          = "Dienstboteneingang"
    L["North"]                 = "Nord"
    L["West"]                  = "West"
    L["East"]                  = "Ost"
    L["Blackrock Mountain"]    = "Der Schwarzfels"
    L["Coilfang Reservoir"]    = "Echsenkessel"
    L["Caverns of Time"]       = "Höhlen der Zeit"
    L["Ahn'Qiraj"]             = "Ahn'Qiraj"
end

local P = AIO:NewModule("mappoi", {
    title     = L["Map symbols"],
    short     = L["Dungeon and raid entrances, flight masters, boats, zeppelins and portals, spirit healers and zone exits on the world map."],
    desc      = L["Dungeon and raid entrances, flight masters, boats, zeppelins and portals, spirit healers and zone exits on the world map."],
    category  = "maps",
    default   = true,
    defaults  = { dungeons = true, flights = true, travel = true, spirits = false, exits = true, faction = true, size = 1 },
    options   = {
        { type = "header", label = L["Show on the map"] },
        { type = "toggle", key = "dungeons", label = L["Dungeons & raids"], half = true },
        { type = "toggle", key = "flights",  label = L["Flight masters"], half = true },
        { type = "toggle", key = "travel",   label = L["Boats, zeppelins & portals"], half = true },
        { type = "toggle", key = "spirits",  label = L["Spirit healers"], half = true },
        { type = "toggle", key = "exits",    label = L["Zone exits"], half = true },
        { type = "toggle", key = "faction",  label = L["Only my faction"], half = true },
        { type = "slider", key = "size", label = L["Icon size"], min = 0.5, max = 2, step = 0.05,
          format = function(v) return ("%d%%"):format(v * 100 + 0.5) end },
    },
})

-- ---------------------------------------------------------------------------
-- Data. One string per zone (uiMapID), entries separated by ";":
--   D x,y,instances[,tag]   entrance; instances "36" or "230/229" (a group)
--   F<f>x,y,name            flight master, f = A(lliance), H(orde), N(eutral)
--   T<k><f>x,y,maps         k = b(oat) z(eppelin) t(ram) p(ortal) o(rb)
--   S x,y                   spirit healer
--   A x,y,map,turn          zone exit towards map, arrow turned (radians)
-- ---------------------------------------------------------------------------

local DATA = {
    [1411] = "TzH50.9,13.9,1420;TzH50.6,12.6,1434;S47.4,17.9;S53.5,44.5;S44.2,69.4;S57.2,73.3;A35.1,42.4,1413,1.5;A45.5,12.3,1454,0",
    [1412] = "S46.5,55.5;S42.6,78.1;A69,60.5,1413,4.9;A37.7,32.9,1456,0.9;A40.5,20.1,1456,2.8",
    [1413] = "D46,36.4,43;D42.9,90.2,47;D49,93.9,129;FN63.1,37.2,Ratchet;FH51.5,30.3,The Crossroads;FH44.4,59.2,Camp Taurajo;TbN63.7,38.6,1434;S50.7,32.6;S60.2,39.7;S45.3,61;S45.8,82.7;A41.2,58.6,1412,1.6;A49.8,78.4,1445,4.7;A44.1,91.5,1441,3;A36.3,27.5,1442,1.5;A48.8,7.1,1440,0;A62.6,19.2,1411,4.6",
    [1416] = "S42.9,38;A80.7,34.2,1422,0;A51.8,68.8,1424,3;A81.7,77.5,1424,2.2",
    [1417] = "FA45.8,46.1,Refuge Pointe;FH73.1,32.7,Hammerfall;S48.8,55.6;A45.4,88.9,1437,3.2;A20.9,30.6,1424,1;A29.6,67.5,1417,1.9",
    [1418] = "D44.6,12.1,70;FH4,44.8,Kargath;S56.7,23.7;S8.4,55.3;S56.7,73.3;A51.1,14.8,1432,0.8;A5.3,61.1,1427,1.5",
    [1419] = "FA65.5,24.3,Nethergarde Keep;S51.1,12.1;A52.2,10.7,1435,0",
    [1420] = "D82.6,33.8,189;TzH60.7,58.8,1411;TzH61.9,59.1,1434;S30.8,64.9;S56.2,49.4;S79,41;S62.3,67;S82,69.6;A83.4,70.6,1422,4.7;A61.9,65,1458,3;A54.9,72.7,1421,3",
    [1421] = "D44.8,67.8,33;FH45.6,42.6,The Sepulcher;S44.1,42.5;S55.6,73.2;A66.3,79.8,1424,4.3;A67.7,5,1420,5.7",
    [1422] = "D69.7,73.2,289;FA42.9,85.1,Chillwind Camp;S59.7,53.2;S65.8,74.2;S45,86;A44.1,87.1,1416,3;A28.6,57.5,1420,1.6;A69.7,50.3,1423,4.7;A65.3,86.4,1425,3",
    [1423] = "D31.3,15.7,329,m;D47.9,23.9,329,s;D39.9,25.9,533;FA81.6,59.3,Light's Hope Chapel;FH80.2,57,Light's Hope Chapel;S47.3,44.9;S37.8,70.1;S39.2,93.7;S80.4,65.3;A11.8,72.7,1422,1.6;A58.7,17.5,1942,0.4",
    [1424] = "FA49.3,52.3,Southshore;FH60.1,18.6,Tarren Mill;S64.5,19.7;S51.8,52.5;A84.6,31.8,1425,5.4;A54.8,11.3,1416,0;A13.7,46.2,1421,1.5;A81,56.1,1417,4.1;A75.5,24.6,1416,0",
    [1425] = "FA11.1,46.2,Aerie Peak;FH81.7,81.8,Revantusk Village;S16.9,44.5;S73.1,68.2;A24.1,30.4,1422,0;A6.4,61.5,1424,2.3;A70.6,63.7,1425,4.1;A76.9,61,1425,1.8",
    [1426] = "D24.3,39.8,90;S30,69.5;S47.3,54.6;S54.4,39.2;A84.3,31.1,1432,0;A82.2,53.5,1432,5;A30.5,34.5,1437,6.2;A53.3,35.1,1455,5.4",
    [1427] = "D34.8,85.3,230/229/409/469,b;FA37.9,30.8,Thorium Point;FH34.8,30.9,Thorium Point;S35.5,22.8;S54.4,51.3;A78.5,17.4,1432,5.4;A33.6,79,1428,3;A68.8,53.9,1418,4.5",
    [1428] = "D29.4,38.3,230/229/409/469,b;FA84.3,68.3,Morgan's Vigil;FH65.7,24.2,Flame Crest;S64.1,24.1;A78.3,77.8,1433,3.3;A31.9,50.4,1427,0.8",
    [1429] = "S39.5,60.5;S49.7,42.5;S83.6,69.8;A21,79.6,1436,2.2;A93.2,72.3,1433,4.7;A32.2,49.7,1453,0.6",
    [1430] = "S40,74.2;D46.9,74.7,532;A32,35.3,1431,1.5;A58.8,42.2,1435,5.2",
    [1431] = "FA77.5,44.3,Darkshire;S20,49.2;S75.1,59;A7.9,63.8,1436,1.7;A44.6,87.9,1434,3;A94.2,10.3,1433,5.8;A88.4,40.9,1430,4.6",
    [1432] = "FA33.9,50.9,Thelsamar;S32.6,47;A18.4,83,1427,2.6;A20.4,17.4,1426,1.1;A46.8,76.9,1418,3.2;A21.5,66.2,1426,0.5;A25.4,10.9,1437,0.1",
    [1433] = "FA30.6,59.4,Lake Everstill;S20.8,56.6;A8.5,88.1,1431,2.2;A3.3,73.1,1429,2.1;A47.3,14.3,1428,5.9",
    [1434] = "D53.9,17.6,309;FA27.5,77.8,Booty Bay;FA38.2,4,Rebel Camp;FH26.9,77.1,Booty Bay;FH32.5,29.4,Grom'gol Base Camp;TbN25.9,73.1,1413;TzH31.4,30.2,1411;TzH31.6,29.1,1420;S38.4,9;S30.4,73.3;A39.2,6.5,1431,0",
    [1435] = "D69.9,53.6,109;FH46.1,54.8,Stonard;S50.3,62.4;A3.7,61.1,1430,1.5;A33.4,74.8,1419,3.1",
    [1436] = "D42.5,71.7,36;FA56.6,52.6,Sentinel Hill;S51.7,49.7;A62,17.9,1429,5.4;A67.9,62.8,1431,4.7",
    [1437] = "FA9.5,59.7,Menethil Harbor;TbA5,63.5,1445;TbA4.6,57.1,1439;S11,43.8;S49.3,41.8;A51.3,10.3,1417,0;A56,70.3,1432,1.8",
    [1438] = "FA58.4,94,Rut'theran Village;TbA54.9,96.8,1439;A55.9,89.7,1457,0.3;S58.7,42.3;S56.2,63.3;A36.2,54.4,1457,1.5",
    [1439] = "FA36.3,45.6,Auberdine;TbA32.4,43.8,1437;TbA33.2,40.1,1438;TbA30.7,41,1943;S41.8,36.6;S43.6,92.4;A43.3,94,1440,4",
    [1440] = "D14.5,14.2,48;FA34.4,48,Astranaar;FA85,43.4,Forest Song;FH73.2,61.6,Splintertree Post;FH12.2,33.8,Zoram'gar Outpost;S40.5,52.8;S80.7,58.4;A29.1,14.8,1439,0;A42.3,71.1,1442,2.7;A55.8,30.2,1448,0;A94.2,47.3,1447,4.4;A68.6,86.8,1413,3.2",
    [1441] = "FH45.1,49.1,Freewind Post;S30.6,23;S68.7,53.3;A74.9,93.3,1446,3.2;A8.3,11.9,1444,0.7;A32.2,23.9,1413,5.4",
    [1442] = "FA36.4,7.2,Stonetalon Peak;FH45.1,59.8,Sun Rock Retreat;S40.3,5.6;S36.4,75.2;S57.5,61.3;A80.2,92.4,1413,3.4;A30.4,75.4,1443,2.7;A78.2,42.8,1440,6.1;A37.9,67.8,1442,4.1",
    [1443] = "D29.1,62.5,349;FA64.7,10.5,Nijel's Point;FH21.6,74.1,Shadowprey Village;S50.4,62.9;A53.4,5.9,1442,5.9;A41.6,94.4,1444,3.3",
    [1444] = "FA30.2,43.2,Feathermoon Stronghold;FH75.4,44.4,Camp Mojache;FA89.5,45.9,Thalanaar;D62.5,24.9,429,n;D60.3,30.2,429,w;D64.8,30.2,429,e;TbA43.3,42.8,1444;TbA31,39.8,1444;S31.8,48.2;S54.8,48.1;S73,44.5;A44.9,7.7,1443,6;A88.7,41.1,1441,4.5;D77.1,36.9,429,e",
    [1445] = "D52.6,76.8,249;FA67.5,51.3,Theramore Isle;FH35.6,31.9,Brackenwall Village;FN42.8,72.5,Mudsprocket;TbA71.6,56.4,1437;S39.5,31.4;S46.6,57.1;S41.2,74.4;S63.6,42.4;A30,47.1,1413,1.6",
    [1446] = "D38.7,20,209;D65.7,49.9,269/560/534,t;FA51,29.3,Gadgetzan;FH51.6,25.4,Gadgetzan;S53.9,28.8;S49.4,59;S69,40.7;S63.6,49.4;A50.6,24.4,1441,5.7;A27.1,57.7,1449,0.5",
    [1447] = "FA11.9,77.6,Talrendis Point;FH22,49.6,Valormok;S70.4,16.1;S54.3,71.5;S14,78.6;A10.6,75.3,1440,0.9",
    [1448] = "FA62.5,24.2,Talonbranch Glade;FH34.4,54,Bloodvenom Post;FN51.4,82.2,Emerald Sanctuary;S49.5,31.1;S56.8,87;A65,8.3,1452,5.9;A54.5,89.2,1440,3",
    [1449] = "FN45.2,5.8,Marshal's Refuge;S45.3,7.6;S50,56;S80.3,50.3;A71.4,77.3,1446,4.3;A29.4,22.3,1451,0.9",
    [1450] = "FA48.1,67.4,Lake Elune'ara;FH32.1,66.6,Moonglade;S62.2,70.1;A35.7,72.4,1448,3",
    [1451] = "D28.6,92.4,509/531,a;FA50.6,34.5,Cenarion Hold;FH48.7,36.7,Cenarion Hold;S47.2,37.3;S28.2,87.1;S81.2,20.8;A82.4,16,1449,5.4",
    [1452] = "FA62.3,36.6,Everlook;FH60.5,36.3,Everlook;S29,43;S61.5,35.4;S62.7,61.3;A27.9,34.5,1448,0.7",
    [1453] = "D42.3,59,34;FA66.3,62.1,Trade District;TtA60.5,12.4,1455;A62.3,72.3,1429,3.8",
    [1454] = "D52.6,49,389;FH45.1,63.9,Valley of Strength;A52.4,83.7,1411,3;A18.1,60.6,1413,2.1",
    [1455] = "FA55.5,47.8,The Great Forge;TtA73,50.2,1453;A21.9,77.5,1426,2.2",
    [1456] = "FH47,49.8,Central Mesa;S56.7,19.1;A35.7,62.8,1412,2;A51.3,31.3,1412,5.7",
    [1457] = "S77.7,25.9;A30.3,41.4,1438,1.5;A86.9,35.8,1438,4.8",
    [1458] = "FH63.3,48.5,Trade Quarter;S67.9,14;A66.2,5.2,1420,0;ToH54.9,11.3,1954",
    [1941] = "FH54.4,50.7,Silvermoon City;S38.2,17.6;S48,49.5;S44.3,71.2;S60,64;A48.7,91,1942,3;A56.7,49.7,1954,0",
    [1942] = "FH45.4,30.5,Tranquillien;FN74.7,67.1,Zul'Aman;D82.3,64.3,568;S43.9,25.7;S61.5,57;S80.5,69.1;A47.5,84,1423,3;A48.4,13.2,1941,0",
    [1943] = "FA31.9,46.4,The Exodar;TbA20.3,54.2,1439;S39.2,19.7;S47.2,55.7;S77.7,48.8;A36.9,47,1947,1.5;A24.7,49.4,1947,5.8;A42.5,5.4,1950,0.2",
    [1944] = "D47.7,53.6,543;D47.7,52,540;D46,51.8,542;D46.6,52.8,544;FA25.2,37.2,Temple of Telhamat;FA54.6,62.4,Honor Hold;FA87.4,52.4,The Dark Portal;FA78.4,34.9,Shatter Point;FH56.2,36.2,Thrallmar;FH27.8,60,Falcon Watch;FH87.4,48.2,The Dark Portal;FH61.6,81.2,Spinebreaker Ridge;TpA88.6,52.8,1453;TpH88.6,47.7,1454;S22.8,38;S27.7,63.3;S60,79.8;S54.5,66.7;S57.5,38.1;S64.3,22.8;S86.8,51.2;S68.7,27.1;A40.3,85.9,1952,2.7;A6.7,50.4,1946,1.6",
    [1946] = "D50.4,40.9,547/546/545/548,c;FA41.2,28.8,Orebor Harborage;FA67.8,51.4,Telredor;FH33,51,Zabra'jin;FH84.8,55,Swamprat Post;S17,48.1;S36.8,47.7;S43.6,31.7;S47.5,50.3;S65.1,50.9;S77.2,64.1;A81.2,64.4,1944,5.4;A82,90.8,1952,3.3;A69.6,35.3,1949,5.4;A40.8,31,1949,5.4;A21.1,70.5,1951,3.1;A67.9,86.9,1951,2.6",
    [1947] = "FA68.5,63.7,The Exodar;A76,55.5,1943,4.5;A35,74.8,1943,0.9",
    [1948] = "D71,46.4,564;FA37.6,55.4,Wildhammer Stronghold;FH30.2,29.2,Shadowmoon Village;FN63.4,30.4,Altar of Sha'tar;FN56.2,57.8,Sanctum of the Stars;S32.2,28.6;S39.5,56.2;S57.5,59.3;S63.6,32.2;S65.5,43;S65.7,45.7;A22.7,28.6,1952,0.8",
    [1949] = "D68.7,24.3,565;FA37.8,61.4,Sylvanaar;FA61,70.4,Toshley's Station;FH52,54.2,Thunderlord Stronghold;FH76.4,65.8,Mok'Nathal Village;FN61.6,39.6,Evergrove;S37.2,24.6;S33.6,58.4;S38.3,67.8;S52.1,60.5;S60.4,66.2;S69.3,58;S74.6,26.7;S62.8,37.4;S61.8,14.7;A37.3,80.5,1946,3;A51.7,74.7,1946,3;A82.4,28.7,1953,4.7",
    [1950] = "FA57.7,53.9,Blood Watch;S30.1,45.9;S58.1,57.7;A65.4,92.6,1943,3",
    [1951] = "FA54.2,75,Telaar;FH57.2,35.2,Garadar;S20.4,36.3;S32.8,56.1;S39.8,30.2;S42.5,46.4;S66.6,24.7;S63.1,69.3;A33.5,17.8,1946,0;A77.5,77,1952,3.7;A72.3,36.6,1946,5.4;A77.5,55.7,1955,5.4",
    [1952] = "D43.2,65.6,556;D36.1,65.6,558;D39.6,71,555;D39.7,60.2,557;FA59.4,55.4,Allerian Stronghold;FH49.2,43.4,Stonebreaker Hold;FN33.1,23.1,Shattrath City;S39.9,21.8;S44.8,40;S59.5,42.6;S44.6,71.2;S62.9,81.2;A70.6,49.4,1948,3.9;A58.3,19.3,1944,5;A20.3,56.3,1951,0.3;A33.1,6.2,1946,0.6;A34.8,13.4,1955,2.4;A38.2,26.6,1955,1.4",
    [1953] = "D71.7,55,553;D74.4,57.7,552;D70.6,69.7,554;D73.7,63.7,550;FN33.8,64,Area 52;FN45.2,34.8,The Stormspire;FN65.2,66.6,Cosmowrench;S42.9,29.4;S33.8,65.7;S64.8,66.6;S56.6,83.1;A22.7,55.6,1949,1.5",
    [1954] = "ToH49.5,14.8,1458;A72.6,85.9,1941,3.2",
    [1955] = "FN64.1,41.1,Shattrath City;TpN48.5,42,1957;TpA55.8,36.5,1453/1455/1457;TpH52.2,52.9,1456/1454/1458;TpA59.6,46.7,1947;TpH59.2,48.4,1954;A62.3,7.9,1952,6.1;A79,57.5,1952,4;A23,49.5,1951,1.9;A68.3,65.1,1952,3.9;A71.1,21.9,1952,5.8;A76.3,43.2,1952,4.7",
    [1957] = "S46.6,32.7;D61.2,30.9,585;D44.3,45.6,580;FA48.5,25.2,Shattered Sun Staging Area;FH48.4,25.1,Shattered Sun Staging Area",
}

-- Instance levels (and 1 = raid). Names come from the game in its language.
local INST = {
    [389] = { 13, 18 }, [36] = { 17, 26 }, [43] = { 17, 24 }, [33] = { 22, 30 }, [48] = { 24, 32 },
    [34] = { 24, 32 }, [90] = { 29, 38 }, [47] = { 29, 38 }, [189] = { 34, 45 }, [129] = { 37, 46 },
    [70] = { 41, 51 }, [209] = { 44, 54 }, [349] = { 46, 55 }, [109] = { 50, 60 }, [230] = { 52, 60 },
    [229] = { 55, 60 }, [429] = { 56, 60 }, [329] = { 58, 60 }, [289] = { 58, 60 },
    [409] = { 60, 60, 1 }, [469] = { 60, 60, 1 }, [249] = { 60, 60, 1 }, [309] = { 60, 60, 1 },
    [509] = { 60, 60, 1 }, [531] = { 60, 60, 1 }, [533] = { 60, 60, 1 },
    [543] = { 58, 67 }, [542] = { 61, 68 }, [547] = { 62, 69 }, [546] = { 63, 70 }, [557] = { 64, 70 },
    [558] = { 65, 70 }, [560] = { 66, 70 }, [556] = { 67, 70 }, [269] = { 66, 70 }, [585] = { 68, 70 },
    [540] = { 69, 70 }, [545] = { 69, 70 }, [555] = { 69, 70 }, [553] = { 70, 70 }, [552] = { 70, 70 },
    [554] = { 70, 70 },
    [532] = { 70, 70, 1 }, [565] = { 70, 70, 1 }, [544] = { 70, 70, 1 }, [548] = { 70, 70, 1 },
    [550] = { 70, 70, 1 }, [534] = { 70, 70, 1 }, [564] = { 70, 70, 1 }, [568] = { 70, 70, 1 },
    [580] = { 70, 70, 1 },
}

local TAG = {
    m = L["Main gate"], s = L["Service gate"], n = L["North"], w = L["West"], e = L["East"],
    b = L["Blackrock Mountain"], c = L["Coilfang Reservoir"], t = L["Caverns of Time"], a = L["Ahn'Qiraj"],
}
local TRAVEL = { b = L["Boat"], z = L["Zeppelin"], t = L["Tram"], p = L["Portal"], o = L["Orb of Translocation"] }

-- Icons: all our own (the Media\\poi sheet and Media\\mapicons).
local SHEET = "Interface\\AddOns\\" .. ADDON .. "\\Media\\poi"
local CELL  = { b = 0, z = 1, t = 2, p = 3, o = 3, S = 4, A = 5 }
local BASE  = { D = 22, R = 24, F = 18, T = 20, S = 16, A = 20 }
local FACTION_COLOR = { A = "|cff4a9eff", H = "|cffff4a4a", N = "|cffffd100" }

-- Entrances and flight masters have their own pictures (Media\mapicons): the
-- atlas names of the modern client point elsewhere on this one.
local OWN = {
    D = "Interface\\AddOns\\" .. ADDON .. "\\Media\\mapicons\\dungeon",
    R = "Interface\\AddOns\\" .. ADDON .. "\\Media\\mapicons\\raid",
    FA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\mapicons\\flight_a",
    FH = "Interface\\AddOns\\" .. ADDON .. "\\Media\\mapicons\\flight_h",
    FN = "Interface\\AddOns\\" .. ADDON .. "\\Media\\mapicons\\flight_n",
}

local function Paint(t, key, cell)
    local own = OWN[key]
    if own then
        t:SetTexture(own)
        t:SetTexCoord(0, 1, 0, 1)
    else
        t:SetTexture(SHEET)
        cell = cell or 3
        t:SetTexCoord(cell / 8, (cell + 1) / 8, 0, 1)
    end
end

local function ZoneName(id)
    local info = id and C_Map.GetMapInfo(id)
    return info and info.name or "?"
end

local function InstName(id)
    local n = GetRealZoneText and GetRealZoneText(id)
    return (n and n ~= "") and n or L["Dungeon"]
end

local function LevelLine(lo, hi)
    local txt = ns.MapLevelText and ns.MapLevelText({ lo, hi }) or ("(" .. lo .. "-" .. hi .. ")")
    return L["Level %s"]:format(txt:gsub("[()]", ""))
end

-- ---------------------------------------------------------------------------
-- Tooltip and click
-- ---------------------------------------------------------------------------

local function AddInstance(id, tag)
    local lv = INST[id]
    local name = InstName(id)
    if tag then name = name .. " (" .. tag .. ")" end
    if lv then
        GameTooltip:AddDoubleLine(name, LevelLine(lv[1], lv[2]), 1, 1, 1)
    else
        GameTooltip:AddLine(name, 1, 1, 1)
    end
end

local function OnEnter(self)
    local tt = GameTooltip
    tt:SetOwner(self, "ANCHOR_RIGHT")
    local k = self.kind
    if k == "D" or k == "R" then
        local ids = self.ids
        if ids:find("/", 1, true) then
            tt:AddLine(TAG[self.tag] or L["Dungeon"], 1, 0.82, 0)
            for id in ids:gmatch("%d+") do AddInstance(tonumber(id)) end
        else
            local id = tonumber(ids)
            tt:AddLine(InstName(id) .. (self.tag and (" (" .. (TAG[self.tag] or self.tag) .. ")") or ""), 1, 0.82, 0)
            tt:AddLine(k == "R" and L["Raid"] or L["Dungeon"], 1, 1, 1)
            local lv = INST[id]
            if lv then tt:AddLine(LevelLine(lv[1], lv[2]), 1, 1, 1) end
        end
    elseif k == "F" then
        tt:AddLine(self.name, 1, 0.82, 0)
        tt:AddLine(FACTION_COLOR[self.fac] .. L["Flight master"] .. "|r")
    elseif k == "T" then
        tt:AddLine(TRAVEL[self.sub] or L["Portal"], 1, 0.82, 0)
        local list
        for id in self.maps:gmatch("%d+") do
            list = (list and list .. ", " or "") .. ZoneName(tonumber(id))
        end
        tt:AddLine(L["To: %s"]:format(list or "?"), 1, 1, 1)
        if self.fac == "N" then tt:AddLine(FACTION_COLOR.N .. L["Neutral"] .. "|r") end
        tt:AddLine(L["Click: show this map"], 0.6, 0.6, 0.6)
    elseif k == "S" then
        tt:AddLine(L["Spirit healer"], 0.6, 0.85, 1)
    elseif k == "A" then
        tt:AddLine(ZoneName(self.dest), 1, 0.82, 0)
        local lv = ns.MapLevels and ns.MapLevels[self.dest]
        if lv then tt:AddLine(LevelLine(lv[1], lv[2]), 1, 1, 1) end
        tt:AddLine(L["Click: show this map"], 0.6, 0.6, 0.6)
    end
    tt:Show()
end

local function OnLeave() GameTooltip:Hide() end

local function OnClick(self)
    if self.dest and self.dest > 0 then WorldMapFrame:SetMapID(self.dest) end
end

-- ---------------------------------------------------------------------------
-- Pins: Blizzard's own map pin system (a data provider and a pin template
-- from MapPOI.xml). The map places, layers and scales the pins itself, the
-- same way it does for its own symbols and for HandyNotes or Questie.
-- ---------------------------------------------------------------------------

local TEMPLATE = "AllInOnePOIPinTemplate"
local myFaction

-- Frame layer per kind, the first one this game knows.
local LAYERS = {
    D = { "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE", "PIN_FRAME_LEVEL_AREA_POI" },
    F = { "PIN_FRAME_LEVEL_FLIGHT_POINT", "PIN_FRAME_LEVEL_AREA_POI" },
    other = { "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_LANDMARK" },
}
local layerOf = {}
local function Layer(map, kind)
    local key = (kind == "R" and "D") or (LAYERS[kind] and kind) or "other"
    if layerOf[key] ~= nil then return layerOf[key] end
    local mgr = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
    local found = false
    if mgr then
        for _, t in ipairs(LAYERS[key]) do
            local ok, v = pcall(mgr.GetValidFrameLevel, mgr, t)
            if ok and type(v) == "number" then found = t break end
        end
    end
    layerOf[key] = found
    return found
end

-- Localised flight master names, where the game can tell us.
local taxiNames
local function TaxiName(mapID, x, y, fallback)
    if not taxiNames then return fallback end
    local list = taxiNames[mapID]
    if list == nil then
        list = (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_TaxiMap.GetTaxiNodesForMap(mapID)) or false
        taxiNames[mapID] = list
    end
    if not list then return fallback end
    local best, bd = nil, 0.0009   -- within 3 % of the map
    for i = 1, #list do
        local n = list[i]
        local p = n.position
        if p and n.name then
            local dx, dy = p.x - x, p.y - y
            local d = dx * dx + dy * dy
            if d < bd then best, bd = n.name, d end
        end
    end
    return best or fallback
end

-- The entries of one map, read from its string once and kept.
local parsed = {}
local function Entries(mapID)
    local list = parsed[mapID]
    if list then return list end
    list = {}
    local s = DATA[mapID]
    if s then
        for e in s:gmatch("[^;]+") do
            local k = e:sub(1, 1)
            local t
            if k == "D" then
                local x, y, ids, tag = e:match("^D([%d.]+),([%d.]+),([%d/]+),?(%a?)")
                if x then
                    local raid = true
                    for id in ids:gmatch("%d+") do
                        local lv = INST[tonumber(id)]
                        if not (lv and lv[3]) then raid = false break end
                    end
                    t = { kind = raid and "R" or "D", group = "dungeons", x = x, y = y, ids = ids,
                          tag = tag ~= "" and tag or nil }
                end
            elseif k == "F" then
                local f, x, y, name = e:match("^F(%a)([%d.]+),([%d.]+),(.+)")
                if x then t = { kind = "F", group = "flights", fac = f, x = x, y = y, name = name } end
            elseif k == "T" then
                local sub, f, x, y, maps = e:match("^T(%a)(%a)([%d.]+),([%d.]+),([%d/]+)")
                if x then
                    t = { kind = "T", group = "travel", sub = sub, fac = f, x = x, y = y, maps = maps,
                          dest = tonumber(maps:match("%d+")) }
                end
            elseif k == "S" then
                local x, y = e:match("^S([%d.]+),([%d.]+)")
                if x then t = { kind = "S", group = "spirits", x = x, y = y } end
            elseif k == "A" then
                local x, y, dest, rot = e:match("^A([%d.]+),([%d.]+),(%d+),([%d.]+)")
                if x then t = { kind = "A", group = "exits", x = x, y = y, dest = tonumber(dest), rot = tonumber(rot) } end
            end
            if t then
                t.x, t.y = tonumber(t.x) / 100, tonumber(t.y) / 100
                list[#list + 1] = t
            end
        end
    end
    parsed[mapID] = list
    return list
end

local function FactionOK(f)
    return not f or f == "N" or not P.db.faction or f == myFaction
end

-- The pin: one map symbol.
local PinMixin = {}

local function PinClick(self, button)
    if button == "RightButton" then
        -- Right click keeps zooming the map out, as everywhere on the map.
        local map = self:GetMap()
        if map and map.NavigateToParentMap then map:NavigateToParentMap() end
    elseif self.dest and self.dest > 0 then
        WorldMapFrame:SetMapID(self.dest)
    end
end

function PinMixin:OnLoad()
    self.aioLoaded = true
    if MapCanvasPinMixin and MapCanvasPinMixin.OnLoad then MapCanvasPinMixin.OnLoad(self) end
    -- Keep their size on screen while zooming, a little larger zoomed in.
    if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.25) end
    -- No mouse scripts of our own: the map adds its own and calls the
    -- OnMouseEnter / OnMouseLeave / OnClick methods below (it refuses pins
    -- that bring their own).
    self:EnableMouse(true)
end

-- The map canvas routes the mouse through these methods.
function PinMixin:OnMouseEnter() OnEnter(self) end
function PinMixin:OnMouseLeave() OnLeave(self) end
function PinMixin:OnMouseDown() end
function PinMixin:OnMouseUp() end
function PinMixin:OnClick(button) PinClick(self, button) end

function PinMixin:OnAcquired(e, mapID)
    -- Position first: the map moves every pin it has each frame, and a pin
    -- without one would break that for all of them.
    self:SetPosition(e.x, e.y)
    if not self.aioLoaded then self.aioLoaded = true; PinMixin.OnLoad(self) end
    local key = e.kind
    self.kind, self.dest, self.tag, self.ids, self.fac, self.sub, self.maps =
        e.kind, e.dest, e.tag, e.ids, e.fac, e.sub, e.maps
    self.name = e.name and TaxiName(mapID, e.x, e.y, e.name) or nil
    local px = BASE[e.kind] * (P.db.size or 1)
    self:SetSize(px, px)
    local layer = Layer(self:GetMap(), e.kind)
    if layer and self.UseFrameLevelType then
        self:UseFrameLevelType(layer)
        if self.ApplyFrameLevel then pcall(self.ApplyFrameLevel, self) end
    end
    if e.kind == "F" then key = "F" .. e.fac end
    local cell = (e.kind == "T" and CELL[e.sub]) or CELL[e.kind]
    -- Turning resets the part of the picture shown on this client, so it
    -- comes first (back to straight), then the picture; only the zone exit
    -- arrows are turned afterwards.
    self.Icon:SetRotation(0)
    self.Glow:SetRotation(0)
    Paint(self.Icon, key, cell)
    Paint(self.Glow, key, cell)
    if e.rot and e.rot ~= 0 then
        self.Icon:SetRotation(e.rot)
        self.Glow:SetRotation(e.rot)
    end
end

_G.AllInOnePOIPinMixin = PinMixin   -- read by the template in MapPOI.xml

-- The data provider: puts the pins of the map that is showing.
local Provider
local function MakeProvider()
    if Provider or not (MapCanvasDataProviderMixin and CreateFromMixins) then return Provider end
    Provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function Provider:RemoveAllData()
        local map = self:GetMap()
        if map then map:RemoveAllPinsByTemplate(TEMPLATE) end
    end
    function Provider:RefreshAllData()
        self:RemoveAllData()
        local map = self:GetMap()
        if not (map and P.enabled) then return end
        local mapID = map:GetMapID()
        if not mapID then return end
        local db = P.db
        local n = 0
        for _, e in ipairs(Entries(mapID)) do
            if db[e.group] and FactionOK(e.fac) then
                map:AcquirePin(TEMPLATE, e, mapID)
                n = n + 1
            end
        end
        P.shown = n
    end
    return Provider
end

local added
local function Setup()
    if added then return true end
    local map = _G.WorldMapFrame
    if not (map and map.AddDataProvider) then return false end
    if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(TEMPLATE)) then
        P.problem = "pin template missing"
        return false
    end
    if not MakeProvider() then
        P.problem = "map data providers missing"
        return false
    end
    -- The template's own mixin replaces Blizzard's pin mixin on this client
    -- (it is not merged), so Blizzard's pin functions (GetMap, OnReleased,
    -- SetPosition ...) are copied in here; ours stay where we have one.
    if not MapCanvasPinMixin then
        P.problem = "map pin functions missing"
        return false
    end
    for k, v in pairs(MapCanvasPinMixin) do
        if PinMixin[k] == nil then PinMixin[k] = v end
    end
    myFaction = UnitFactionGroup("player") == "Horde" and "H" or "A"
    if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then taxiNames = {} end
    map:AddDataProvider(Provider)
    added = true
    P.problem = nil
    return true
end

function P:OnEnable()
    if not Setup() then
        if not _G.WorldMapFrame then self.waiting = true end
        return
    end
    if WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end

function P:OnDisable()
    if Provider and added then Provider:RemoveAllData() end
end

function P:OnSettingChanged()
    if Provider and added and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end

AIO:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" and P.enabled and P.waiting then
        P.waiting = nil
        P:OnEnable()
    end
end)

-- /aio poi: what the map symbols are doing, for finding faults.
P.slash = "poi"
function P:Slash()
    local map = _G.WorldMapFrame
    local mapID = map and map.GetMapID and map:GetMapID()
    self:Print("Map symbols: on=%s, provider=%s, map=%s, entries=%d, shown=%s%s",
        tostring(self.enabled), tostring(added and true or false), tostring(mapID),
        mapID and #Entries(mapID) or 0, tostring(self.shown or 0),
        self.problem and (", problem: " .. self.problem) or "")
end
