

local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero

local GameMissileCount  = Game.MissileCount
local GameMissile       = Game.Missile

local orbwalker         = _G.SDK.Orbwalker
local TargetSelector    = _G.SDK.TargetSelector

local lastQ = 0
local lastW = 0
local lastE = 0
local lastMove = 0
local lastAttack = 0

local Enemys =   {}
local Allys  =   {}

require 'GamsteronPrediction'

local shellSpells = {
    ["NilahR"] = {charName = "Nilah", slot = "R",  speed = math.huge, delay = 1, isMissile = false},
    ["NautilusAnchorDragMissile"]   = {charName = "Nautilus"    ,   slot = "Q", speed = 2000 , delay = 0.25, isMissile = true },
    ["NautilusRavageStrikeAttack"]  = {charName = "Nautilus"    ,   slot = "Passive", speed = math.huge, delay = 0.25} ,
    ["RekSaiWUnburrowLockout"]      = {charName = "RekSai"      ,   slot = "W", speed = math.huge, delay = 0.25},
    ["SkarnerPassiveAttack"]        = {charName = "Skarner"     ,   slot = "E Passive", speed = math.huge, delay = 0.25},
    ["WarwickE"]             = {charName = "Warwick"     ,   slot = "E", speed = 1600, delay = 0},  -- need test
    ["WarwickRChannel"]             = {charName = "Warwick"     ,   slot = "R", speed = math.huge, delay = 0.1},  -- need test
    ["XinZhaoQThrust3"]             = {charName = "XinZhao"     ,   slot = "Q3", speed = math.huge, delay = 0.25},
    ["VolibearQAttack"]             = {charName = "Volibear"    ,   slot = "Q", speed = math.huge, delay = 0.25},
    ["LeonaShieldOfDaybreakAttack"] = {charName = "Leona"       ,   slot = "Q", speed = math.huge, delay = 0.25},
    ["GoldCardPreAttack"]           = {charName = "TwistedFate" ,   slot = "GoldW", speed = math.huge, delay = 0.25},
    ["PowerFistAttack"]             = {charName = "Blitzcrank"  ,   slot = "E", speed = math.huge, delay = 0.25},
    ["BelvethW"]                = {charName = "Belveth"     , slot = "W" , delay = 0.5 , speed = math.huge  , isMissile = false},
    ["ViegoWMis"]               = {charName = "Viego"       , slot = "W" , delay = 0   , speed = 1300       , isMissile = true },
    ["RenataR"]                 = {charName = "Renata"      , slot = "R" , delay = 0.75, speed = 1000       , isMissile = true },
    ["FlashFrostSpell"]         = {charName = "Anivia"      , slot = "Q" , delay = 0.25, speed = 950        , isMissile = true },
    ["Frostbite"]               = {charName = "Anivia"      , slot = "E" , delay = 0.25, speed = 1600       , isMissile = true },
    ["AnnieQ"]                  = {charName = "Annie"       , slot = "Q" , delay = 0.25, speed = 1400       , isMissile = true },
    ["BrandQ"]                  = {charName = "Brand"       , slot = "Q" , delay = 0.25, speed = 1600       , isMissile = true },
    ["BrandE"]                  = {charName = "Brand"       , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["BrandR"]                  = {charName = "Brand"       , slot = "R" , delay = 0.25, speed = 1000       , isMissile = true },   -- to be comfirm brand R delay 0.25 or 0.5
    ["CassiopeiaE"]             = {charName = "Cassiopeia"  , slot = "E" , delay = 0.15, speed = 2500       , isMissile = true },   -- delay to be comfirm
    ["CamilleR"]                = {charName = "Camille"     , slot = "R" , delay = 0   , speed = math.huge  , isMissile = false},   -- delay to be comfirm
    ["Feast"]                   = {charName = "Chogath"     , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["DariusExecute"]           = {charName = "Darius"      , slot = "R" , delay = 0.36, speed = math.huge  , isMissile = false}, 
    ["EliseHumanQ"]             = {charName = "Elise"       , slot = "Q1", delay = 0.25, speed = 2200       , isMissile = true },
    ["EliseSpiderQCast"]        = {charName = "Elise"       , slot = "Q2", delay = 0.25, speed = math.huge  , isMissile = false},
    ["Terrify"]                 = {charName = "FiddleSticks", slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["FiddleSticksDarkWind"]    = {charName = "FiddleSticks", slot = "E" , delay = 0.25, speed = 1100       , isMissile = true },
    ["GangplankQProceed"]       = {charName = "Gangplank"   , slot = "Q" , delay = 0.25, speed = 2600       , isMissile = true },
    ["GarenQAttack"]            = {charName = "Garen"       , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["GarenR"]                  = {charName = "Garen"       , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["SowTheWind"]              = {charName = "Janna"       , slot = "W" , delay = 0.25, speed = 1600       , isMissile = true },
    ["JarvanIVCataclysm"]       = {charName = "JarvanIV"    , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["JayceToTheSkies"]         = {charName = "Jayce"       , slot = "Q2", delay = 0.25, speed = math.huge  , isMissile = false}, -- seems speed base on distance, lazy to find the forumla , maybe fixed delay
    ["JayceThunderingBlow"]     = {charName = "Jayce"       , slot = "E2", delay = 0.25, speed = math.huge  , isMissile = false},
    ["KatarinaQ"]               = {charName = "Katarina"    , slot = "Q" , delay = 0.25, speed = 1600       , isMissile = true },
    ["KatarinaE"]               = {charName = "Katarina"    , slot = "E" , delay = 0.1 , speed = math.huge  , isMissile = false}, -- delay to be comfirm
    ["NullLance"]               = {charName = "Kassadin"    , slot = "Q" , delay = 0.25, speed = 1400       , isMissile = true },
    ["KhazixQ"]                 = {charName = "Khazix"      , slot = "Q1", delay = 0.25, speed = math.huge  , isMissile = false},
    ["KhazixQLong"]             = {charName = "Khazix"      , slot = "Q2", delay = 0.25, speed = math.huge  , isMissile = false},
    ["BlindMonkRKick"]          = {charName = "LeeSin"      , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["LeblancQ"]                = {charName = "Leblanc"     , slot = "Q" , delay = 0.25, speed = 2000       , isMissile = true },
    ["LeblancRQ"]               = {charName = "Leblanc"     , slot = "RQ", delay = 0.25, speed = 2000       , isMissile = true },
    ["LissandraREnemy"]         = {charName = "Lissandra"   , slot = "R" , delay = 0.5 , speed = math.huge  , isMissile = false},
    ["LucianQ"]                 = {charName = "Lucian"      , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false}, --  delay = 0.4 − 0.25 (based on level)
    ["LuluWTwo"]                = {charName = "Lulu"        , slot = "W" , delay = 0.25, speed = 2250       , isMissile = true },
    ["SeismicShard"]            = {charName = "Malphite"    , slot = "Q" , delay = 0.25, speed = 1200       , isMissile = true },
    ["MalzaharE"]               = {charName = "Malzahar"    , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["MalzaharR"]               = {charName = "Malzahar"    , slot = "R" , delay = 0   , speed = math.huge  , isMissile = false},
    ["AlphaStrike"]             = {charName = "MasterYi"    , slot = "Q" , delay = 0   , speed = math.huge  , isMissile = false},
    ["MissFortuneRicochetShot"] = {charName = "MissFortune" , slot = "Q" , delay = 0.25, speed = 1400       , isMissile = true },
    ["NasusW"]                  = {charName = "Nasus"       , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["NautilusGrandLine"]       = {charName = "Nautilus"    , slot = "R" , delay = 0.46, speed = 1400       , isMissile = true }, 
    ["NunuQ"]                   = {charName = "Nunu"        , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["OlafRecklessStrike"]      = {charName = "Olaf"        , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["PantheonW"]               = {charName = "Pantheon"    , slot = "W" , delay = 0   , speed = math.huge  , isMissile = false},
    ["RekSaiE"]                 = {charName = "RekSai"      , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["RekSaiR"]                 = {charName = "RekSai"      , slot = "R" , delay = 1.5 , speed = math.huge  , isMissile = false},
    ["PuncturingTaunt"]         = {charName = "Rammus"      , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["RenektonExecute"]         = {charName = "Renekton"    , slot = "W1", delay = 0.25, speed = math.huge  , isMissile = false},
    ["RenektonSuperExecute"]    = {charName = "Renekton"    , slot = "W2", delay = 0.25, speed = math.huge  , isMissile = false},
    ["RyzeW"]                   = {charName = "Ryze"        , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["RyzeE"]                   = {charName = "Ryze"        , slot = "E" , delay = 0.25, speed = 3500       , isMissile = true },
    ["Fling"]                   = {charName = "Singed"      , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["SyndraR"]                 = {charName = "Syndra"      , slot = "R" , delay = 0.25, speed = 1400       , isMissile = true },
    ["TwoShivPoison"]           = {charName = "Shaco"       , slot = "E" , delay = 0.25, speed = 1500       , isMissile = true },
    ["SkarnerImpale"]           = {charName = "Skarner"     , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["TahmKenchW"]              = {charName = "TahmKench"   , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["TalonQAttack"]            = {charName = "Talon"       , slot = "Q1", delay = 0.25, speed = math.huge  , isMissile = false},
    ["BlindingDart"]            = {charName = "Teemo"       , slot = "Q" , delay = 0.25, speed = 1500       , isMissile = true },
    ["TristanaR"]               = {charName = "Tristana"    , slot = "R" , delay = 0.25, speed = 2000       , isMissile = true },
    ["TrundlePain"]             = {charName = "Trundle"     , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["ViR"]                     = {charName = "Vi"          , slot = "R" , delay = 0.25, speed = 800        , isMissile = false},
    ["VayneCondemn"]            = {charName = "Vayne"       , slot = "E" , delay = 0.25, speed = 2200       , isMissile = true },
    ["VolibearW"]               = {charName = "Volibear"    , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = true },
    ["VeigarR"]                 = {charName = "Veigar"      , slot = "R" , delay = 0.25, speed = 500        , isMissile = true },
    ["VladimirQ"]               = {charName = "Vladimir"    , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["SylasR"]                  = {charName = "Sylas"       , slot = "R" , delay = 0.25, speed = 2200       , isMissile = true },
    ["AatroxW"]                 = {charName = "Aatrox"      , slot = "W" , delay = 0.25, speed = 1800       , isMissile = true },
    ["AhriSeduce"]              = {charName = "Ahri"        , slot = "E" , delay = 0.25, speed = 1500       , isMissile = true },
    ["AkaliR"]                  = {charName = "Akali"       , slot = "R" , delay = 0.25, speed = 1500       , isMissile = true },
    ["AkaliRb"]                 = {charName = "Akali"       , slot = "Rb", delay = 0   , speed = 3000       , isMissile = true },
    ["AkaliE"]                  = {charName = "Akali"       , slot = "E" , delay = 0.4 , speed = 1800       , isMissile = true },
    ["Pulverize"]               = {charName = "Alistar"     , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["BandageToss"]             = {charName = "Amumu"       , slot = "Q" , delay = 0.25, speed = 2000       , isMissile = true },
    ["CurseoftheSadMummy"]      = {charName = "Amumu"       , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["EnchantedCrystalArrow"]   = {charName = "Ashe"        , slot = "R" , delay = 0.25, speed = 1600       , isMissile = true },
    ["ApheliosR"]               = {charName = "Aphelios"    , slot = "R" , delay = 0.6 , speed = 2050       , isMissile = true },
    ["AurelionSolQ"]            = {charName = "AurelionSol" , slot = "Q" , delay = 0   , speed = 850        , isMissile = true },
    ["AzirR"]                   = {charName = "Azir"        , slot = "R" , delay = 0.3 , speed = 1400       , isMissile = false},
    ["BardQ"]                   = {charName = "Bard"        , slot = "Q" , delay = 0.25, speed = 1500       , isMissile = true },
    ["BardR"]                   = {charName = "Bard"        , slot = "R" , delay = 0.5 , speed = 2100       , isMissile = false},
    ["RocketGrab"]              = {charName = "Blitzcrank"  , slot = "Q" , delay = 0.25, speed = 1800       , isMissile = true },
    ["BraumQ"]                  = {charName = "Braum"       , slot = "Q" , delay = 0.25, speed = 1700       , isMissile = true },
    ["BraumR"]                  = {charName = "Braum"       , slot = "R" , delay = 0.5 , speed = 1400       , isMissile = false},
    ["CamilleE"]                = {charName = "Camille"     , slot = "E" , delay = 0   , speed = 1900       , isMissile = false},
    ["CamilleEDash2"]           = {charName = "Camille"     , slot = "E2", delay = 0   , speed = 1900       , isMissile = false},
    ["CaitlynE"]                = {charName = "Caitlyn"     , slot = "E" , delay = 0.15, speed = 1600       , isMissile = true },
    ["CassiopeiaW"]             = {charName = "Cassiopeia"  , slot = "W" , delay = 0.75, speed = 2500       , isMissile = false},
    ["Rupture"]                 = {charName = "Chogath"     , slot = "Q" , delay = 1.2 , speed = math.huge  , isMissile = false},
    ["DrMundoQ"]                = {charName = "DrMundo"     , slot = "Q" , delay = 0.25, speed = 2000       , isMissile = true },
    ["DianaQ"]                  = {charName = "Diana"       , slot = "Q" , delay = 0.25, speed = 1900       , isMissile = false},
    ["DravenDoubleShot"]        = {charName = "Draven"      , slot = "E" , delay = 0.25, speed = 1400       , isMissile = true },
    ["DravenRCast"]             = {charName = "Draven"      , slot = "R" , delay = 0.5 , speed = 2000       , isMissile = true },
    ["EkkoQ"]                   = {charName = "Ekko"        , slot = "Q" , delay = 0.25, speed = 1650       , isMissile = true },
    ["EkkoW"]                   = {charName = "Ekko"        , slot = "W" , delay = 3.25, speed = math.huge  , isMissile = false},
    ["EliseHumanE"]             = {charName = "Elise"       , slot = "E" , delay = 0.25, speed = 1600       , isMissile = true },
    ["EzrealR"]                 = {charName = "Ezreal"      , slot = "R" , delay = 1   , speed = 2000       , isMissile = true },
    ["FizzR"]                   = {charName = "Fizz"        , slot = "R" , delay = 0.25, speed = 1300       , isMissile = true },
    ["GalioW2"]                  = {charName = "Galio"       , slot = "W2" , delay = 0 , speed = math.huge       , isMissile = false},
    ["GalioE"]                  = {charName = "Galio"       , slot = "E" , delay = 0.4 , speed = 2300       , isMissile = false},
    ["GnarQMissile"]            = {charName = "Gnar"        , slot = "Q" , delay = 0.25, speed = 2500       , isMissile = true },
    ["GnarBigQMissile"]         = {charName = "Gnar"        , slot = "Q2", delay = 0.5 , speed = 2100       , isMissile = true },
    ["GnarBigW"]                = {charName = "Gnar"        , slot = "W" , delay = 0.6 , speed = math.huge  , isMissile = false},
    ["GnarR"]                   = {charName = "Gnar"        , slot = "R" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["GragasQ"]                 = {charName = "Gragas"      , slot = "Q" , delay = 0.25, speed = 1000       , isMissile = false },
    ["GragasR"]                 = {charName = "Gragas"      , slot = "R" , delay = 0.25, speed = 1800       , isMissile = false},
    ["GravesSmokeGrenade"]      = {charName = "Graves"      , slot = "W" , delay = 0.15, speed = 1500       , isMissile = false},
    ["HeimerdingerE"]           = {charName = "Heimerdinger", slot = "E" , delay = 0.25, speed = 1200       , isMissile = true },
    ["HeimerdingerEUlt"]        = {charName = "Heimerdinger", slot = "RE", delay = 0.25, speed = 1200       , isMissile = true },
    ["HecarimUlt"]              = {charName = "Hecarim"     , slot = "R" , delay = 0.2 , speed = 1100       , isMissile = false},
    ["BlindMonkQOne"]           = {charName = "Leesin"      , slot = "Q" , delay = 0.25, speed = 1800       , isMissile = true },
    ["IllaoiE"]                 = {charName = "Illaoi"      , slot = "E" , delay = 0.25, speed = 1900       , isMissile = true },
    ["IreliaW2"]                = {charName = "Irelia"      , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["IreliaR"]                 = {charName = "Irelia"      , slot = "R" , delay = 0.4 , speed = 2000       , isMissile = true },
    ["IvernQ"]                  = {charName = "Ivern"       , slot = "Q" , delay = 0.25, speed = 1300       , isMissile = true },
    ["JarvanIVDragonStrike"]    = {charName = "JarvanIV"    , slot = "Q" , delay = 0.4 , speed = math.huge  , isMissile = false},
    ["HowlingGale"]        = {charName = "Janna"       , slot = "Q" , delay = 0   , speed = 1167       , isMissile = true },
    ["JhinW"]                   = {charName = "Jhin"        , slot = "W" , delay = 0.75, speed = 5000       , isMissile = false },
    ["JhinRShot"]               = {charName = "Jhin"        , slot = "R" , delay = 0.25, speed = 5000       , isMissile = true },
    ["JinxWMissile"]            = {charName = "Jinx"        , slot = "W" , delay = 0.6 , speed = 3300       , isMissile = true },
    ["KarmaQ"]                  = {charName = "Karma"       , slot = "Q" , delay = 0.25, speed = 1700       , isMissile = true },
    ["KarmaQMantra"]            = {charName = "Karma"       , slot = "RQ", delay = 0.25, speed = 1700       , isMissile = true },
    ["KayleQ"]                  = {charName = "Kayle"       , slot = "Q" , delay = 0.5 , speed = 2000       , isMissile = true },
    ["KaynW"]                   = {charName = "Kayn"        , slot = "W" , delay = 0.55, speed = math.huge  , isMissile = false},
    ["KhazixWLong"]             = {charName = "Khazix"      , slot = "W" , delay = 0.25, speed = 1700       , isMissile = true },
    ["KledQ"]                   = {charName = "Kled"        , slot = "Q" , delay = 0.25, speed = 1600       , isMissile = true },
    ["KogMawVoidOozeMissile"]   = {charName = "KogMaw"      , slot = "E" , delay = 0.25, speed = 1400       , isMissile = true },
    ["LeblancE"]                = {charName = "Leblanc"     , slot = "E" , delay = 0.25, speed = 1750       , isMissile = true },
    ["LeblancRE"]               = {charName = "Leblanc"     , slot = "RE", delay = 0.25, speed = 1750       , isMissile = true },
    ["LeonaZenithBlade"]        = {charName = "Leona"       , slot = "E" , delay = 0.25, speed = 2000       , isMissile = true },
    ["LeonaSolarFlare"]         = {charName = "Leona"       , slot = "R" , delay = 0.85, speed = math.huge  , isMissile = false},
    ["LilliaE"]                 = {charName = "Lillia"      , slot = "E" , delay = 0.4 , speed = 1500       , isMissile = true },
    ["LissandraQMissile"]       = {charName = "Lissandra"   , slot = "Q" , delay = 0.25, speed = 2200       , isMissile = true },
    ["LuluQ"]                   = {charName = "Lulu"        , slot = "Q" , delay = 0.25, speed = 1450       , isMissile = true },
    ["LuxLightBinding"]         = {charName = "Lux"         , slot = "Q" , delay = 0.25, speed = 1200       , isMissile = true },
    ["Landslide"]               = {charName = "Malphite"    , slot = "E" , delay = 0.24, speed = math.huge  , isMissile = false},
    ["UFSlash"]                 = {charName = "Malphite"    , slot = "R" , delay = 0   , speed = 1835       , isMissile = false},
    ["MalzaharQ"]               = {charName = "Malzahar"    , slot = "Q" , delay = 0.5 , speed = math.huge  , isMissile = false},
    ["MaokaiQ"]                 = {charName = "Maokai"      , slot = "Q" , delay = 0.39, speed = math.huge  , isMissile = false},
    ["MorganaQ"]                = {charName = "Morgana"     , slot = "Q" , delay = 0.25, speed = 1200       , isMissile = true },
    ["MordekaiserE"]            = {charName = "Mordekaiser" , slot = "E" , delay = 0.9 , speed = math.huge  , isMissile = false},
    ["NamiQ"]                   = {charName = "Nami"        , slot = "Q" , delay = 0.25, speed = 1750  , isMissile = false},
    ["NamiRMissile"]            = {charName = "Nami"        , slot = "R" , delay = 0.5 , speed = 850        , isMissile = true },
    ["NeekoQ"]                  = {charName = "Neeko"       , slot = "Q" , delay = 0.25, speed = 1500       , isMissile = false},
    ["NeekoE"]                  = {charName = "Neeko"       , slot = "E" , delay = 0.25, speed = 1400       , isMissile = true },
    ["NunuR"]                   = {charName = "Nunu"        , slot = "R" , delay = 3   , speed = math.huge  , isMissile = false},
    ["OlafAxeThrowCast"]        = {charName = "Olaf"        , slot = "Q" , delay = 0.25, speed = 1600       , isMissile = true },
    ["OrnnQ"]                   = {charName = "Ornn"        , slot = "Q" , delay = 0.3 , speed = 1800       , isMissile = true },
    ["OrnnE"]                   = {charName = "Ornn"        , slot = "E" , delay = 0.35, speed = 1600       , isMissile = true },
    ["OrnnRCharge"]             = {charName = "Ornn"        , slot = "R" , delay = 0.5 , speed = 1650       , isMissile = true },
    ["PoppyQSpell"]             = {charName = "Poppy"       , slot = "Q" , delay = 0.33, speed = math.huge  , isMissile = false},
    ["PoppyRSpell"]             = {charName = "Poppy"       , slot = "R" , delay = 0.33, speed = 2000       , isMissile = true },
    ["PykeQMelee"]              = {charName = "Pyke"        , slot = "Q1", delay = 0.25, speed = math.huge  , isMissile = false},
    ["PykeQRange"]              = {charName = "Pyke"        , slot = "Q2", delay = 0.25 , speed = 2000       , isMissile = true },
    ["PykeEMissile"]                   = {charName = "Pyke"        , slot = "E" , delay = 0   , speed = 3000       , isMissile = true },
    ["PykeRTrail"]              = {charName = "Pyke"        , slot = "R", delay = 0.5 , speed = 3000       , isMissile = false },
    ["QiyanaR"]                 = {charName = "Qiyana"      , slot = "R" , delay = 0.25, speed = 2000       , isMissile = true },
    ["RakanW"]                  = {charName = "Rakan"       , slot = "W" , delay = 0   , speed = math.huge  , isMissile = false},
    ["RakanR"]                  = {charName = "Rakan"       , slot = "R" , delay = 0.5 , speed = math.huge  , isMissile = false},
    ["RengarE"]                 = {charName = "Rengar"      , slot = "E" , delay = 0.25, speed = 1500       , isMissile = true },
    ["RumbleGrenade"]           = {charName = "Rumble"      , slot = "E" , delay = 0.25, speed = 2000       , isMissile = true },
    ["SeraphineE"]              = {charName = "Seraphine"   , slot = "E" , delay = 0.25, speed = 1200       , isMissile = true },
    ["SettE"]                   = {charName = "Sett"        , slot = "E" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["SennaW"]                  = {charName = "Senna"       , slot = "W" , delay = 0.25, speed = 1150       , isMissile = true },
    ["SejuaniR"]                = {charName = "Sejuani"     , slot = "R" , delay = 0.25, speed = 1600       , isMissile = true },
    ["ShyvanaFireballDragon2"]  = {charName = "Shyvana"     , slot = "E2", delay = 0.33, speed = 1575       , isMissile = true },
    ["ShenE"]                   = {charName = "Shen"        , slot = "E" , delay = 0   , speed = 1200       , isMissile = true },
    ["SionQ"]                   = {charName = "Sion"        , slot = "Q" , delay = 2   , speed = math.huge  , isMissile = false},
    ["SionE"]                   = {charName = "Sion"        , slot = "E" , delay = 0.25, speed = 1800       , isMissile = true },
    ["SonaR"]                   = {charName = "Sona"        , slot = "R" , delay = 0.25, speed = 2400       , isMissile = true },
    ["SorakaQ"]                 = {charName = "Soraka"      , slot = "Q" , delay = 0.25, speed = 1150       , isMissile = true },
    ["SwainE"]                  = {charName = "Swain"       , slot = "E" , delay = 0.25, speed = 1800       , isMissile = true },
    ["SylasE2"]                 = {charName = "Sylas"       , slot = "E" , delay = 0.25, speed = 1600       , isMissile = true },
    ["TahmKenchQ"]              = {charName = "TahmKench"   , slot = "Q" , delay = 0.25, speed = 2800       , isMissile = true },
    ["TaliyahWVC"]              = {charName = "Taliyah"     , slot = "W" , delay = 0.25, speed = math.huge  , isMissile = false},
    ["ThreshE"]                 = {charName = "Thresh"      , slot = "E" , delay = 0.39, speed = math.huge  , isMissile = false},
    ["ThreshQInternal"]          = {charName = "Thresh"      , slot = "Q" , delay = 0.5 , speed = 1900       , isMissile = true },
    ["UrgotQ"]                  = {charName = "Urgot"       , slot = "Q" , delay = 0.25, speed = math.huge  , isMissile = fasle},
    ["UrgotE"]                  = {charName = "Urgot"       , slot = "E" , delay = 0.45, speed = 1540       , isMissile = false},
    ["UrgotR"]                  = {charName = "Urgot"       , slot = "R" , delay = 0.5 , speed = 3200       , isMissile = true },
    ["VarusE"]                  = {charName = "Varus"       , slot = "E" , delay = 0.24, speed = 1500       , isMissile = false},
    ["VarusR"]                  = {charName = "Varus"       , slot = "R" , delay = 0.25, speed = 1950       , isMissile = true },
    ["VelkozQ"]                 = {charName = "Velkoz"      , slot = "Q" , delay = 0.25, speed = 1300       , isMissile = true },
    ["VelkozE"]                 = {charName = "Velkoz"      , slot = "E" , delay = 0.8 , speed = math.huge  , isMissile = false},
    ["ViQ"]                     = {charName = "Vi"          , slot = "Q" , delay = 0   , speed = 1500       , isMissile = true },
    ["ViktorGravitonField"]     = {charName = "Viktor"      , slot = "W" , delay = 1.75, speed = math.huge  , isMissile = false},
    ["XerathArcaneBarrage2"]    = {charName = "Xerath"      , slot = "W" , delay = 0.75, speed = math.huge  , isMissile = false},
    ["XerathMageSpear"]         = {charName = "Xerath"      , slot = "E" , delay = 0.2 , speed = 1400       , isMissile = true },
    ["XinZhaoW"]                = {charName = "XinZhao"     , slot = "W" , delay = 0.5 , speed = 6250       , isMissile = true },
    ["YasuoQ3"]                 = {charName = "Yasuo"       , slot = "Q3", delay = 0.34, speed = 1200       , isMissile = true },
    ["ZacQ"]                    = {charName = "Zac"         , slot = "Q" , delay = 0.33, speed = 2800       , isMissile = true },
    ["ZiggsW"]                  = {charName = "Ziggs"       , slot = "W" , delay = 0.25, speed = 1750       , isMissile = true },
    ["ZileanQ"]                 = {charName = "Zilean"      , slot = "Q" , delay = 0.8 , speed = math.huge  , isMissile = false},
    ["ZoeE"]                    = {charName = "Zoe"         , slot = "E" , delay = 0.3 , speed = 1700       , isMissile = true },
    ["ZyraE"]                   = {charName = "Zyra"        , slot = "E" , delay = 0.25, speed = 1150       , isMissile = true },
    ["ZyraR"]                   = {charName = "Zyra"        , slot = "R" , delay = 2   , speed = math.huge  , isMissile = false},
    ["YoneQ3"]                  = {charName = "Yone"        , slot = "Q" , delay = 0.25, speed = 1500       , isMissile = true },
    ["YoneR"]                   = {charName = "Yone"        , slot = "R" , delay = 0.75, speed = math.huge  , isMissile = false}
}
local function IsValid(unit)
    return  unit 
            and unit.valid 
            and unit.isTargetable 
            and unit.alive 
            and unit.visible 
            and unit.networkID 
            and unit.health > 0
            and not unit.dead
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 
    and myHero:GetSpellData(spell).level > 0 
    and myHero:GetSpellData(spell).mana <= myHero.mana 
    and Game.CanUseSpell(spell) == 0
end

local function OnAllyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isAlly then
            cb(obj)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isEnemy then
            cb(obj)
        end
    end
end

class "Sivir"

function Sivir:__init()
    print("Sivir init")

    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1250, Speed = 1450, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_YASUOWALL} }

    self:LoadMenu()

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)

    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)

    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)

    orbwalker:OnPostAttackTick(function(...) self:OnPostAttack(...) end)

    orbwalker:OnPreAttack(
        function(args)
            if args.Process then
                if lastAttack + self.tyMenu.Human.AA:Value() > GetTickCount() then
                    args.Process = false
                    print("block aa")
                else
                    args.Process = true
                    self.AttackTarget = args.Target
                    lastAttack = GetTickCount()
                end
            end
        end
    )

    orbwalker:OnPreMovement(
        function(args)
            if args.Process then
                if (lastMove + self.tyMenu.Human.Move:Value() > GetTickCount()) or (ExtLibEvade and ExtLibEvade.Evading == true) then
                    args.Process = false
                else
                    args.Process = true
                    lastMove = GetTickCount()
                end
            end
        end 
    )


end

function Sivir:LoadMenu()

    self.tyMenu = MenuElement({type = MENU, id = "14Sivir", name = "14Sivir"})

    self.tyMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
        self.tyMenu.combo:MenuElement({id = "Q", name = "Use Q Combo", value = true})
        self.tyMenu.combo:MenuElement({id = "maxRange", name = "Max Q Range", value = 1250, min = 0, max = 1250, step = 10})
        self.tyMenu.combo:MenuElement({id = "WAA", name = "use W AA reset", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "harass", name = "Harass"})
        self.tyMenu.harass:MenuElement({id = "Q", name = "Use Q Harass", value = true})
        self.tyMenu.harass:MenuElement({id = "maxRange", name = "Max Q Range", value = 1250, min = 0, max = 1250, step = 10})
        self.tyMenu.harass:MenuElement({id = "mana", name = "Only cast spell if mana >", value = 30, min = 0, max = 100, step = 1})

    self.tyMenu:MenuElement({type = MENU, id = "auto", name = "Auto Q"})
        self.tyMenu.auto:MenuElement({id = "Q", name = "Use Q in Immobile Target", value = true})

    self.tyMenu:MenuElement({type = MENU, id = "eSetting", name = "E Setting"})
        self.tyMenu.eSetting:MenuElement({id = "eDelay", name = "Xs before Spell hit", value = 0.1, min = 0, max = 1.5, step = 0.01})
        self.tyMenu.eSetting:MenuElement({type = MENU, id = "blockSpell", name = "Auto E Block Spell"})
        OnEnemyHeroLoad(function(hero)
            for k, v in pairs(shellSpells) do
                if v.charName == hero.charName then
                    self.tyMenu.eSetting.blockSpell:MenuElement({id = k, name = v.charName.." | "..v.slot, value = true})
                end
            end
        end)
        self.tyMenu.eSetting:MenuElement({type = MENU, id = "dash", name = "Auto E If Enemy dash on ME"})
        OnEnemyHeroLoad(function(hero)
            self.tyMenu.eSetting.dash:MenuElement({id = hero.charName, name = hero.charName, value = false})
        end)
    
    self.tyMenu:MenuElement({type = MENU, id = "Human", name = "Humanizer"})
        self.tyMenu.Human:MenuElement({id = "Move", name = "Only allow 1 movement in X Tick ", value = 180, min = 1, max = 500, step = 1})
        self.tyMenu.Human:MenuElement({id = "AA", name = "Only allow 1 AA in X Tick", value = 180, min = 1, max = 500, step = 1})

    self.tyMenu:MenuElement({type = MENU, id = "draw", name = "Draw Setting"})
        self.tyMenu.draw:MenuElement({id = "Q", name = "Draw Q", value = true})

end

function Sivir:OnPostAttack()
    if orbwalker.Modes[0] then
        if self.tyMenu.combo.WAA:Value() and Ready(_W) and lastW + 250 < GetTickCount() then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
    end
end

function Sivir:Draw()
    if myHero.dead then return end

    if self.tyMenu.draw.Q:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(255,255, 162, 000))
    end

end

function Sivir:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end

    if orbwalker.Modes[0] then 
        self:Combo()
    elseif orbwalker.Modes[1] then 
        self:Harass()
    end

    self:BlockSpell()
    self:AutoQ()
end

function Sivir:Combo() 
    local target = TargetSelector:GetTarget(self.Q.Range, 0)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < self.tyMenu.combo.maxRange:Value() then
        if self.tyMenu.combo.Q:Value() then
            self:CastQ(target)
        end
    end
end

function Sivir:Harass() 
    local manaPer = myHero.mana/myHero.maxMana
    local target = TargetSelector:GetTarget(self.Q.Range, 0)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < self.tyMenu.harass.maxRange:Value() and self.tyMenu.harass.mana:Value()/100 < manaPer then
        if self.tyMenu.harass.Q:Value() then
            self:CastQ(target)
        end
    end
end

function Sivir:CastQ(target)
    if Ready(_Q) and lastQ +350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GetGamsteronPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= 3 then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Sivir:AutoQ()
    if self.tyMenu.auto.Q:Value() and Ready(_Q) and lastQ +350 < GetTickCount() and orbwalker:CanMove() then
        for k , hero in pairs(Enemys) do 
            local Pred = GetGamsteronPrediction(hero, self.Q, myHero)
            if Pred.Hitchance == 4 then
                Control.CastSpell(HK_Q, Pred.CastPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function Sivir:BlockSpell()
    if Ready(_E) and lastE +1050 < GetTickCount() then
        for k , hero in pairs(Enemys) do 
            if hero.activeSpell.valid and shellSpells[hero.activeSpell.name] ~= nil then
                if hero.activeSpell.target == myHero.handle and self.tyMenu.eSetting.blockSpell[hero.activeSpell.name]:Value() then
                    local dt = hero.pos:DistanceTo(myHero.pos)
                    local spell = shellSpells[hero.activeSpell.name]
                    local hitTime = spell.delay + dt/spell.speed
        
                    DelayAction(function()
                            Control.CastSpell(HK_E)
                    end, (hitTime-self.tyMenu.eSetting.eDelay:Value()))
                    lastE = GetTickCount()
                    return
                end
            end

            if hero.pathing.isDashing and self.tyMenu.eSetting.dash[hero.charName]:Value() then
                local vct = Vector(hero.pathing.endPos.x,hero.pathing.endPos.y,hero.pathing.endPos.z)
                if vct:DistanceTo(myHero.pos) < 172 then
                    Control.CastSpell(HK_E)
                    lastE = GetTickCount()
                    return
                end
            end
        end
    end
end



Sivir()
