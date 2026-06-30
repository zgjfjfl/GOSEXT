local Version = 1.03

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local CCSpells = {
	["AatroxW"] = {charName = "Aatrox", displayName = "Infernal Chains", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, collision = true},
	["AhriE"] = {charName = "Ahri", displayName = "Seduce", slot = _E, type = "linear", speed = 1500, range = 975, delay = 0.25, radius = 60, collision = true},
	["AkaliR"] = {charName = "Akali", displayName = "Perfect Execution [First]", slot = _R, type = "linear", speed = 1800, range = 525, delay = 0, radius = 65, collision = false},
	["AkaliE"] = {charName = "Akali", displayName = "Shuriken Flip", slot = _E, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 70, collision = true},
	["Pulverize"] = {charName = "Alistar", displayName = "Pulverize", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 365, collision = false},
	["BandageToss"] = {charName = "Amumu", displayName = "Bandage Toss", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, collision = true},
	["CurseoftheSadMummy"] = {charName = "Amumu", displayName = "Curse of the Sad Mummy", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, collision = false},
	["FlashFrostSpell"] = {charName = "Anivia", displayName = "Flash Frost", missileName = "FlashFrostSpell", slot = _Q, type = "linear", speed = 850, range = 1100, delay = 0.25, radius = 110, collision = false},
	["EnchantedCrystalArrow"] = {charName = "Ashe", displayName = "Enchanted Crystal Arrow", slot = _R, type = "linear", speed = 1600, range = 25000, delay = 0.25, radius = 130, collision = false},
	["ApheliosR"] = {charName = "Aphelios", displayName = "Moonlight Vigil", slot = _R, type = "linear", speed = 2050, range = 1600, delay = 0.5, radius = 125, collision = false},
	["AurelionSolQ"] = {charName = "AurelionSol", displayName = "Starsurge", slot = _Q, type = "linear", speed = 850, range = 25000, delay = 0, radius = 110, collision = false},
	["AzirR"] = {charName = "Azir", displayName = "Emperor's Divide", slot = _R, type = "linear", speed = 1400, range = 500, delay = 0.3, radius = 250, collision = false},
	["BardQ"] = {charName = "Bard", displayName = "Cosmic Binding", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, collision = true},
	["BardR"] = {charName = "Bard", displayName = "Tempered Fate", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, collision = false},
	["RocketGrab"] = {charName = "Blitzcrank", displayName = "Rocket Grab", slot = _Q, type = "linear", speed = 1800, range = 1150, delay = 0.25, radius = 140, collision = true},
	["BrandQ"] = {charName = "Brand", displayName = "Sear", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, collision = true},	
	["BraumQ"] = {charName = "Braum", displayName = "Winter's Bite", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, collision = true},
	["BraumR"] = {charName = "Braum", displayName = "Glacial Fissure", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, collision = false},
	["CamilleE"] = {charName = "Camille", displayName = "Hookshot [First]", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, collision = false},
	["CamilleEDash2"] = {charName = "Camille", displayName = "Hookshot [Second]", slot = _E, type = "linear", speed = 1900, range = 400, delay = 0, radius = 60, collision = false},
	["CaitlynE"] = {charName = "Caitlyn", displayName = "Entrapment", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.15, radius = 70, collision = true},
	["CassiopeiaW"] = {charName = "Cassiopeia", displayName = "Miasma", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.75, radius = 160, collision = false},
	["Rupture"] = {charName = "Chogath", displayName = "Rupture", slot = _Q, type = "circular", speed = math.huge, range = 950, delay = 1.2, radius = 250, collision = false},
	["DrMundoQ"] = {charName = "DrMundo", displayName = "Infected Cleaver", slot = _Q, type = "linear", speed = 2000, range = 975, delay = 0.25, radius = 60, collision = true},
	["DianaQ"] = {charName = "Diana", displayName = "Crescent Strike", slot = _Q, type = "circular", speed = 1900, range = 900, delay = 0.25, radius = 185, collision = true},	
	["DravenDoubleShot"] = {charName = "Draven", displayName = "Double Shot", slot = _E, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 130, collision = false},
	["DravenRCast"] = {charName = "Draven", displayName = "Whirling Death", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 0.25, radius = 160, collision = false},
	["EkkoQ"] = {charName = "Ekko", displayName = "Timewinder", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 60, collision = false},
	["EkkoW"] = {charName = "Ekko", displayName = "Parallel Convergence", slot = _W, type = "circular", speed = math.huge, range = 1600, delay = 3.35, radius = 400, collision = false},
	["EliseHumanE"] = {charName = "Elise", displayName = "Cocoon", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, collision = true},
	["EzrealR"] = {charName = "Ezreal", displayName = "Trueshot Barrage", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 1, radius = 160, collision = true},
	["FizzR"] = {charName = "Fizz", displayName = "Chum the Waters", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 150, collision = false},
	["GalioE"] = {charName = "Galio", displayName = "Justice Punch", slot = _E, type = "linear", speed = 2300, range = 650, delay = 0.4, radius = 160, collision = false},
	["GarenQ"] = {charName = "Garen", displayName = "Decisive Strike", slot = _Q, type = "targeted", range = 225},
	["GnarQMissile"] = {charName = "Gnar", displayName = "Boomerang Throw", slot = _Q, type = "linear", speed = 2500, range = 1125, delay = 0.25, radius = 55, collision = false},
	["GnarBigQMissile"] = {charName = "Gnar", displayName = "Boulder Toss", slot = _Q, type = "linear", speed = 2100, range = 1125, delay = 0.5, radius = 90, collision = true},
	["GnarBigW"] = {charName = "Gnar", displayName = "Wallop", slot = _W, type = "linear", speed = math.huge, range = 575, delay = 0.6, radius = 100, collision = false},
	["GnarR"] = {charName = "Gnar", displayName = "GNAR!", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 475, collision = false},
	["GragasQ"] = {charName = "Gragas", displayName = "Barrel Roll", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 275, collision = false},
	["GragasR"] = {charName = "Gragas", displayName = "Explosive Cask", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, collision = false},
	["GravesSmokeGrenade"] = {charName = "Graves", displayName = "Smoke Grenade", slot = _W, type = "circular", speed = 1500, range = 950, delay = 0.15, radius = 250, collision = false},
	["HeimerdingerE"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
	["HeimerdingerEUlt"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
	["HecarimUlt"] = {charName = "Hecarim", displayName = "Onslaught of Shadows", slot = _R, type = "linear", speed = 1100, range = 1650, delay = 0.2, radius = 280, collision = false},	
	["BlindMonkQOne"] = {charName = "Leesin", displayName = "Sonic Wave", slot = _Q, type = "linear", speed = 1800, range = 1100, delay = 0.25, radius = 60, collision = true},	
	["IllaoiE"] = {charName = "Illaoi", displayName = "Test of Spirit", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, collision = true},	
	["IreliaW2"] = {charName = "Irelia", displayName = "Defiant Dance", slot = _W, type = "linear", speed = math.huge, range = 775, delay = 0.25, radius = 120, collision = false},
	["IreliaR"] = {charName = "Irelia", displayName = "Vanguard's Edge", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.4, radius = 160, collision = false},
	["IvernQ"] = {charName = "Ivern", displayName = "Rootcaller", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, collision = true},
	["JarvanIVDragonStrike"] = {charName = "JarvanIV", displayName = "Dragon Strike", slot = _Q, type = "linear", speed = math.huge, range = 770, delay = 0.4, radius = 70, collision = false},
	["HowlingGaleSpell"] = {charName = "Janna", displayName = "Howling Gale", slot = _Q, type = "linear", speed = 1167, range = 1750, delay = 0, radius = 120, collision = false},
	["JhinW"] = {charName = "Jhin", displayName = "Deadly Flourish", slot = _W, type = "linear", speed = 5000, range = 2550, delay = 0.75, radius = 40, collision = false},
	["JhinRShot"] = {charName = "Jhin", displayName = "Curtain Call", slot = _R, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, collision = false},
	["JinxWMissile"] = {charName = "Jinx", displayName = "Zap!", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, collision = true},
	["KarmaQ"] = {charName = "Karma", displayName = "Inner Flame", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, collision = true},
	["KarmaQMantra"] = {charName = "Karma", displayName = "Inner Flame [Mantra]", slot = _Q, origin = "linear", type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, collision = true},
	["KayleQ"] = {charName = "Kayle", displayName = "Radiant Blast", slot = _Q, type = "linear", speed = 2000, range = 850, delay = 0.5, radius = 60, collision = false},
	["KaynW"] = {charName = "Kayn", displayName = "Blade's Reach", slot = _W, type = "linear", speed = math.huge, range = 700, delay = 0.55, radius = 90, collision = false},
	["KhazixWLong"] = {charName = "Khazix", displayName = "Void Spike [Threeway]", slot = _W, type = "threeway", speed = 1700, range = 1000, delay = 0.25, radius = 70,angle = 23, collision = true},
	["KledQ"] = {charName = "Kled", displayName = "Beartrap on a Rope", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, collision = true},
	["KogMawVoidOozeMissile"] = {charName = "KogMaw", displayName = "Void Ooze", slot = _E, type = "linear", speed = 1400, range = 1360, delay = 0.25, radius = 120, collision = false},
	["LeblancE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Standard]", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
	["LeblancRE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Ultimate]", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
	["LeonaZenithBlade"] = {charName = "Leona", displayName = "Zenith Blade", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, collision = false},
	["LeonaSolarFlare"] = {charName = "Leona", displayName = "Solar Flare", slot = _R, type = "circular", speed = math.huge, range = 1200, delay = 0.85, radius = 300, collision = false},
	["LilliaE"] = {charName = "Lillia", displayName = "Lillia E", slot = _E, type = "linear", speed = 1500, range = 750, delay = 0.4, radius = 150, collision = false},
	["LissandraQMissile"] = {charName = "Lissandra", displayName = "Ice Shard", slot = _Q, type = "linear", speed = 2200, range = 750, delay = 0.25, radius = 75, collision = false},
	["LuluQ"] = {charName = "Lulu", displayName = "Glitterlance", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, collision = false},
	["LuxLightBinding"] = {charName = "Lux", displayName = "Light Binding", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 50, collision = false},
	["LuxLightStrikeKugel"] = {charName = "Lux", displayName = "Light Strike Kugel", slot = _E, type = "circular", speed = 1200, range = 1100, delay = 0.25, radius = 300, collision = true},
	["Landslide"] = {charName = "Malphite", displayName = "Ground Slam", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.242, radius = 400, collision = false},
	["UFSlash"] = {charName = "Malphite", displayName = "Unstoppable Force", slot = _R, type = "circular", speed = 1835, range = 1000, delay = 0, radius = 300, collision = false},	
	["MalzaharQ"] = {charName = "Malzahar", displayName = "Call of the Void", slot = _Q, type = "rectangular", speed = 1600, range = 900, delay = 0.5, radius = 400, radius2 = 100, collision = false},
	["MaokaiQ"] = {charName = "Maokai", displayName = "Bramble Smash", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, collision = false},
	["MorganaQ"] = {charName = "Morgana", displayName = "Dark Binding", slot = _Q, type = "linear", speed = 1200, range = 1250, delay = 0.25, radius = 70, collision = true},
	["MordekaiserE"] = {charName = "Mordekaiser", displayName = "Death's Grasp", slot = _E, type = "linear", speed = math.huge, range = 900, delay = 0.9, radius = 140, collision = false},	
	["NamiQ"] = {charName = "Nami", displayName = "Aqua Prison", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 1, radius = 180, collision = false},
	["NamiRMissile"] = {charName = "Nami", displayName = "Tidal Wave", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, collision = false},
	["NautilusAnchorDragMissile"] = {charName = "Nautilus", displayName = "Dredge Line", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 90, collision = true},
	["NeekoQ"] = {charName = "Neeko", displayName = "Blooming Burst", slot = _Q, type = "circular", speed = 1500, range = 800, delay = 0.25, radius = 200, collision = false},
	["NeekoE"] = {charName = "Neeko", displayName = "Tangle-Barbs", slot = _E, type = "linear", speed = 1400, range = 1000, delay = 0.25, radius = 65, collision = false},
	["NunuR"] = {charName = "Nunu", displayName = "Absolute Zero", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 3, radius = 650, collision = false},
	["OlafAxeThrowCast"] = {charName = "Olaf", displayName = "Undertow", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, collision = false},
	["OrnnQ"] = {charName = "Ornn", displayName = "Volcanic Rupture", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, collision = false},
	["OrnnE"] = {charName = "Ornn", displayName = "Searing Charge", slot = _E, type = "linear", speed = 1600, range = 800, delay = 0.35, radius = 150, collision = false},
	["OrnnRCharge"] = {charName = "Ornn", displayName = "Call of the Forge God", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, collision = false},
	["PoppyQSpell"] = {charName = "Poppy", displayName = "Hammer Shock", slot = _Q, type = "linear", speed = math.huge, range = 430, delay = 0.332, radius = 100, collision = false},
	["PoppyRSpell"] = {charName = "Poppy", displayName = "Keeper's Verdict", slot = _R, type = "linear", speed = 2000, range = 1200, delay = 0.33, radius = 100, collision = false},
	["PykeQMelee"] = {charName = "Pyke", displayName = "Bone Skewer [Melee]", slot = _Q, type = "linear", speed = math.huge, range = 400, delay = 0.25, radius = 70, collision = false},
	["PykeQRange"] = {charName = "Pyke", displayName = "Bone Skewer [Range]", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, collision = true},
	["PykeE"] = {charName = "Pyke", displayName = "Phantom Undertow", slot = _E, type = "linear", speed = 3000, range = 25000, delay = 0, radius = 110, collision = false},
	["QiyanaR"] = {charName = "Qiyana", displayName = "Supreme Display of Talent", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 190, collision = false},	
	["RakanW"] = {charName = "Rakan", displayName = "Grand Entrance", slot = _W, type = "circular", speed = math.huge, range = 650, delay = 0.7, radius = 265, collision = false},
	["RengarE"] = {charName = "Rengar", displayName = "Bola Strike", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = true},
	["RumbleGrenade"] = {charName = "Rumble", displayName = "Electro Harpoon", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, collision = true},
	["SeraphineE"] = {charName = "Seraphine", displayName = "Beat Drop", slot = _E, type = "linear", speed = 500, range = 1300, delay = 0.25, radius = 35, collision = false},
	["SettE"] = {charName = "Sett", displayName = "Facebreaker", slot = _E, type = "linear", speed = math.huge, range = 490, delay = 0.25, radius = 175, collision = false},
	["SennaW"] = {charName = "Senna", displayName = "Last Embrace", slot = _W, type = "linear", speed = 1150, range = 1300, delay = 0.25, radius = 60, collision = true},	
	["SejuaniR"] = {charName = "Sejuani", displayName = "Glacial Prison", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, collision = false},
	["ShyvanaTransformLeap"] = {charName = "Shyvana", displayName = "Transform Leap", slot = _R, type = "linear", speed = 700, range = 850, delay = 0.25, radius = 150, collision = false},
	["ShenE"] = {charName = "Shen", displayName = "Shadow Dash", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, collision = false},	
	["SionQ"] = {charName = "Sion", displayName = "Decimating Smash", slot = _Q, origin = "", type = "linear", speed = math.huge, range = 750, delay = 2, radius = 150, collision = false},
	["SionE"] = {charName = "Sion", displayName = "Roar of the Slayer", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.25, radius = 80, collision = false},
	["SkarnerFractureMissile"] = {charName = "Skarner", displayName = "Fracture", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = false},
	["SonaR"] = {charName = "Sona", displayName = "Crescendo", slot = _R, type = "linear", speed = 2400, range = 1000, delay = 0.25, radius = 140, collision = false},
	["SorakaQ"] = {charName = "Soraka", displayName = "Starcall", slot = _Q, type = "circular", speed = 1150, range = 810, delay = 0.25, radius = 235, collision = false},
	["SwainW"] = {charName = "Swain", displayName = "Vision of Empire", slot = _W, type = "circular", speed = math.huge, range = 3500, delay = 1.5, radius = 300, collision = false},
	["SwainE"] = {charName = "Swain", displayName = "Nevermove", slot = _E, type = "linear", speed = 1800, range = 850, delay = 0.25, radius = 85, collision = false},
	["SylasE2"] = {charName = "Sylas", displayName = "Abduct", slot = _E, type = "linear", speed = 1600, range = 850, delay = 0.25, radius = 60, collision = true},	
	["TahmKenchQ"] = {charName = "TahmKench", displayName = "Tongue Lash", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.25, radius = 70, collision = true},
	["TaliyahWVC"] = {charName = "Taliyah", displayName = "Seismic Shove", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 150, collision = false},
	["TaliyahR"] = {charName = "Taliyah", displayName = "Weaver's Wall", slot = _R, type = "linear", speed = 1700, range = 3000, delay = 1, radius = 120, collision = false},
	["ThreshE"] = {charName = "Thresh", displayName = "Flay", slot = _E, type = "linear", speed = math.huge, range = 500, delay = 0.389, radius = 110, collision = true},
	["ThreshQ"] = {charName = "Thresh", displayName = "Death Sentence", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, collision = true},	
	["TristanaW"] = {charName = "Tristana", displayName = "Rocket Jump", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 300, collision = false},
	["UrgotQ"] = {charName = "Urgot", displayName = "Corrosive Charge", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.6, radius = 180, collision = false},
	["UrgotE"] = {charName = "Urgot", displayName = "Disdain", slot = _E, type = "linear", speed = 1540, range = 475, delay = 0.45, radius = 100, collision = false},
	["UrgotR"] = {charName = "Urgot", displayName = "Fear Beyond Death", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.4, radius = 80, collision = false},
	["VarusE"] = {charName = "Varus", displayName = "Hail of Arrows", slot = _E, type = "linear", speed = 1500, range = 925, delay = 0.242, radius = 260, collision = false},
	["VarusR"] = {charName = "Varus", displayName = "Chain of Corruption", slot = _R, type = "linear", speed = 1950, range = 1200, delay = 0.25, radius = 120, collision = false},
	["VelkozQ"] = {charName = "Velkoz", displayName = "Plasma Fission", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.25, radius = 50, collision = true},
	["VelkozE"] = {charName = "Velkoz", displayName = "Tectonic Disruption", slot = _E, type = "circular", speed = math.huge, range = 800, delay = 0.8, radius = 185, collision = false},
	["ViQ"] = {charName = "Vi", displayName = "Vault Breaker", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, collision = false},	
	["ViktorGravitonField"] = {charName = "Viktor", displayName = "Graviton Field", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 1.75, radius = 270, collision = false},
	["WarwickR"] = {charName = "Warwick", displayName = "Infinite Duress", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 55, collision = false},
	["XerathArcaneBarrage2"] = {charName = "Xerath", displayName = "Arcane Barrage", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.75, radius = 235, collision = false},
	["XerathMageSpear"] = {charName = "Xerath", displayName = "Mage Spear", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, collision = true},
	["XinZhaoW"] = {charName = "XinZhao", displayName = "Wind Becomes Lightning", slot = _W, type = "linear", speed = 5000, range = 900, delay = 0.5, radius = 40, collision = false},
	["YasuoQ3Mis"] = {charName = "Yasuo", displayName = "Yasuo Q3", slot = _Q, type = "linear", speed = 1200, range = 1000, delay = 0.339, radius = 90, collision = false},	
	["ZacQ"] = {charName = "Zac", displayName = "Stretching Strikes", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 120, collision = false},
	["ZiggsW"] = {charName = "Ziggs", displayName = "Satchel Charge", slot = _W, type = "circular", speed = 1750, range = 1000, delay = 0.25, radius = 240, collision = false},
	["ZiggsE"] = {charName = "Ziggs", displayName = "Hexplosive Minefield", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, collision = false},
	["ZileanQ"] = {charName = "Zilean", displayName = "Time Bomb", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 150, collision = false},
	["ZoeE"] = {charName = "Zoe", displayName = "Sleepy Trouble Bubble", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, collision = true},
	["ZyraE"] = {charName = "Zyra", displayName = "Grasping Roots", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, collision = false},
	["ZyraR"] = {charName = "Zyra", displayName = "Stranglethorns", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 2, radius = 500, collision = false},
	["BrandConflagration"] = {charName = "Brand", slot = _R, type = "targeted", displayName = "Conflagration", range = 625, cc = true},
	["JarvanIVCataclysm"] = {charName = "JarvanIV", slot = _R, type = "targeted", displayName = "Cataclysm", range = 650},
	["JayceThunderingBlow"] = {charName = "Jayce", slot = _E, type = "targeted", displayName = "Thundering Blow", range = 240},
	["BlindMonkRKick"] = {charName = "LeeSin", slot = _R, type = "targeted", displayName = "Dragon's Rage", range = 375},
	["LissandraR"] = {charName = "Lissandra", slot = _R, type = "targeted", displayName = "Frozen Tomb", range = 550},
	["SeismicShard"] = {charName = "Malphite", slot = _Q, type = "targeted", displayName = "Seismic Shard", range = 625, cc = true},
	["AlZaharNetherGrasp"] = {charName = "Malzahar", slot = _R, type = "targeted", displayName = "Nether Grasp", range = 700},
	["MaokaiW"] = {charName = "Maokai", slot = _W, type = "targeted", displayName = "Twisted Advance", range = 525},
	["NautilusR"] = {charName = "Nautilus", slot = _R, type = "targeted", displayName = "Depth Charge", range = 825},
	["PoppyE"] = {charName = "Poppy", slot = _E, type = "targeted", displayName = "Heroic Charge", range = 475},
	["RyzeW"] = {charName = "Ryze", slot = _W, type = "targeted", displayName = "Rune Prison", range = 615},
	["Fling"] = {charName = "Singed", slot = _E, type = "targeted", displayName = "Fling", range = 125},
	["SkarnerImpale"] = {charName = "Skarner", slot = _R, type = "targeted", displayName = "Impale", range = 350},
	["TahmKenchW"] = {charName = "TahmKench", slot = _W, type = "targeted", displayName = "Devour", range = 250},
	["TristanaR"] = {charName = "Tristana", slot = _R, type = "targeted", displayName = "Buster Shot", range = 669},
	["TeemoQ"] = {charName = "Teemo", slot = _Q, type = "targeted", displayName = "Blinding Dart", range = 680},	
	["VeigarPrimordialBurst"] = {charName = "Veigar", slot = _R, type = "targeted", displayName = "Primordial Burst", range = 650},
	["VolibearQ"] = {charName = "Volibear", displayName = "Thundering Smash", slot = _Q, type = "targeted", range = 200},
	["YoneQ3"] = {charName = "Yone", displayName = "Mortal Steel [Storm]", slot = _Q, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, collision = false},
	["YoneR"] = {charName = "Yone", displayName = "Fate Sealed", slot = _R, type = "linear", speed = math.huge, range = 1000, delay = 0.75, radius = 112.5, collision = false}
}

local function VectorPointProjectionOnLineSegment(v1, v2, v)
	local cx, cy, ax, ay, bx, by = v.x, v.z, v1.x, v1.z, v2.x, v2.z
	local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
	local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
	local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
	local isOnSegment = rS == rL
	local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
	return pointSegment, pointLine, isOnSegment
end

local function CalculateEndPos(startPos, placementPos, unitPos, range, radius, collision, type)
	local range = range or 3000; local endPos = startPos:Extended(placementPos, range)
	if type == "circular" or type == "rectangular" then
		if range > 0 then if GetDistance(unitPos, placementPos) < range then endPos = placementPos end
		else endPos = unitPos end
	elseif collision then
		for i = 1, Game.MinionCount() do
			local minion = Game.Minion(i)
			if minion and minion.team == myHero.team and minion.alive and GetDistance(minion.pos, startPos) < range then
				local col = VectorPointProjectionOnLineSegment(startPos, placementPos, minion.pos)
				if col and GetDistance(col, minion.pos) < (radius + minion.boundingRadius / 2) then
					range = GetDistance(startPos, col); endPos = startPos:Extended(placementPos, range); break
				end
			end
		end
	end
	return endPos, range
end

local function CalculateCollisionTime(startPos, endPos, unitPos, startTime, speed, delay, origin)
	local pos = startPos:Extended(endPos, speed * (Game.Timer() - delay - startTime))
	return GetDistance(unitPos, pos) / speed
end

class "zgSamira"

function zgSamira:__init()
	print("Zgjfjfl AIO - Samira Loaded")
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 950, Speed = 2600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Range = 390}
	self.ESpell = {Range = 650}
	self.RSpell = {Range = 600}
	self.DetectedSpells = {}
	self.ProcessedSpells = {}
end

function zgSamira:LoadMenu()                     	
	--MainMenu
local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
Menu:MenuElement({name = " ", drop = {"Version 0.04"}})

	--AutoW
Menu:MenuElement({type = MENU, id = "WSet", name = "AutoW Incomming CC Spells"})
	Menu.WSet:MenuElement({name = " ", drop = {"After 30sec CCSpells are loaded"}})	
	Menu.WSet:MenuElement({id = "UseW", name = "UseW Anti CC", value = true})	
	Menu.WSet:MenuElement({id = "BlockList", name = "Spell List", type = MENU})	

	--ComboMenu
Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})	
	Menu.Combo:MenuElement({id = "UseW", name = "[W]", value = true})
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	Menu.Combo:MenuElement({id = "UseR", name = "[R]", value = true})	

	--HarassMenu
Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})		
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q]", value = true})

	--Lane/JungleClear
Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})

	--LaneClear Menu
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "Lane Clear"})
	Menu.Clear.LaneClear:MenuElement({id = "UseQ", name = "[Q2]", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "min Minions for [Q2]", value = 3, min = 1, max = 7, step = 1})	
	
	--JungleClear Menu
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "Jungle Clear"})
	Menu.Clear.JungleClear:MenuElement({id = "UseQ", name = "[Q1]", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "UseQ2", name = "[Q2]", value = true})

	--KillSteal
Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})	
	Menu.ks:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.ks:MenuElement({id = "UseE", name = "[E]", value = true})

	--Drawing 
 Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})	
	
	Slot = {[_Q] = "Q", [_W] = "W", [_E] = "E", [_R] = "R"}
	if Game.Timer() < 30 then
		DelayAction(function()
			for i, spell in pairs(CCSpells) do
				if not CCSpells[i] then return end
				for j, k in pairs(GetEnemyHeroes()) do
					if spell.charName == k.charName and not Menu.WSet.BlockList["Dodge"..i] then
						Menu.WSet.BlockList:MenuElement({id = "Dodge"..i, name = ""..spell.charName.." "..Slot[spell.slot].." | "..spell.displayName, value = true})
					end
				end
			end				
		end, 30)
	else
		DelayAction(function()
			for i, spell in pairs(CCSpells) do
				if not CCSpells[i] then return end
				for j, k in pairs(GetEnemyHeroes()) do
					if spell.charName == k.charName and not Menu.WSet.BlockList["Dodge"..i] then
						Menu.WSet.BlockList:MenuElement({id = "Dodge"..i, name = ""..spell.charName.." "..Slot[spell.slot].." | "..spell.displayName, value = true})
					end
				end
			end				
		end, 0.02)
	end	
end

function zgSamira:Tick()
	
	local hasSamiraW = HaveBuff(myHero, "samiraw")
	local hasSamiraR = HaveBuff(myHero, "samirar")
	_G.SDK.Orbwalker:SetAttack(not (hasSamiraW or hasSamiraR))
	self.CastedR = hasSamiraR

	if Menu.WSet.UseW:Value() and IsReady(_W) then
		self:ScanEnemySpells()
		for i, spell in pairs(self.DetectedSpells) do
			self:UseW(i, spell)
		end		
	end	

	if ShouldWait() then return end
	if IsCasting() then return end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
		self:LastHit()
	elseif Mode == "LaneClear" then
		self:JungleClear()
		self:LaneClear()
		self:LastHit()
	elseif Mode == "LastHit" then
		self:LastHit()
	end	
	self:KillSteal()
end

function zgSamira:ScanEnemySpells()
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if enemy and enemy.isEnemy and IsValid(enemy) then
			local spell = enemy.activeSpell
			if spell and spell.valid and spell.name and CCSpells[spell.name] then
				local key = tostring(enemy.networkID or enemy.handle or i).."|"..spell.name.."|"..tostring(spell.startTime or spell.castEndTime or 0)
				if not self.ProcessedSpells[key] then
					self.ProcessedSpells[key] = Game.Timer()
					self:ProcessSpell(enemy, spell)
				end
			end
		end
	end

	for key, time in pairs(self.ProcessedSpells) do
		if Game.Timer() - time > 3 then
			self.ProcessedSpells[key] = nil
		end		
	end	
end

function zgSamira:ProcessSpell(unit, spell)
	if not Menu.WSet.UseW:Value() or not IsReady(_W) then return end
	if not unit or not unit.isEnemy or not spell or not spell.name then return end

	local Detected = CCSpells[spell.name]
	if not Detected then return end
	if myHero.pos:DistanceTo(unit.pos) > 3000 then return end

	local menuItem = Menu.WSet.BlockList["Dodge"..spell.name]
	if menuItem and not menuItem:Value() then return end

	if Detected.type == "targeted" then
		local target = spell.target
		if target == myHero.handle then
			Control.CastSpell(HK_W)
		end
		return
	end

	local placement = spell.placementPos or spell.endPos or spell.pos
	if not placement then return end

	local startPos = Vector(spell.startPos or unit.pos)
	local placementPos = Vector(placement)

	local radius = Detected.radius or 0
	local range = Detected.range or GetDistance(startPos, placementPos)
	local endPos, range2 = CalculateEndPos(startPos, placementPos, unit.pos, range, radius, Detected.collision, Detected.type)

	local detectedSpell = {
		startPos = startPos,
		endPos = endPos,
		startTime = Game.Timer(),
		speed = Detected.speed or math.huge,
		range = range2 or range,
		delay = Detected.delay or 0,
		radius = radius,
		radius2 = Detected.radius2,
		angle = Detected.angle,
		type = Detected.type,
		collision = Detected.collision
	}

	if Detected.type == "threeway" and Detected.angle then
		detectedSpell.type = "linear"
		local direction = (placementPos - startPos):Normalized()
		local angle = Detected.angle * math.pi / 180
		local cos, sin = math.cos(angle), math.sin(angle)
		local leftDir = Vector(direction.x * cos - direction.z * sin, direction.y, direction.x * sin + direction.z * cos)
		local rightDir = Vector(direction.x * cos + direction.z * sin, direction.y, -direction.x * sin + direction.z * cos)
		local leftEndPos = startPos + leftDir * range
		local rightEndPos = startPos + rightDir * range

		table.insert(self.DetectedSpells, detectedSpell)
		table.insert(self.DetectedSpells, {
			startPos = startPos,
			endPos = leftEndPos,
			startTime = detectedSpell.startTime,
			speed = detectedSpell.speed,
			range = range,
			delay = detectedSpell.delay,
			radius = detectedSpell.radius,
			radius2 = detectedSpell.radius2,
			angle = detectedSpell.angle,
			type = "linear",
			collision = detectedSpell.collision
		})
		table.insert(self.DetectedSpells, {
			startPos = startPos,
			endPos = rightEndPos,
			startTime = detectedSpell.startTime,
			speed = detectedSpell.speed,
			range = range,
			delay = detectedSpell.delay,
			radius = detectedSpell.radius,
			radius2 = detectedSpell.radius2,
			angle = detectedSpell.angle,
			type = "linear",
			collision = detectedSpell.collision
		})
		return
	end

	table.insert(self.DetectedSpells, detectedSpell)
end

function zgSamira:UseW(i, s)
	local startPos = s.startPos; local endPos = s.endPos; local travelTime = 0
	if s.speed == math.huge then travelTime = s.delay else travelTime = s.range / s.speed + s.delay end
	if s.type == "rectangular" then
		local StartPosition = endPos-Vector(endPos-startPos):Normalized():Perpendicular()*(s.radius2 or 400)
		local EndPosition = endPos+Vector(endPos-startPos):Normalized():Perpendicular()*(s.radius2 or 400)
		startPos = StartPosition; endPos = EndPosition
	end
	if s.startTime + travelTime > Game.Timer() then
		local Col = VectorPointProjectionOnLineSegment(startPos, endPos, myHero.pos)
		if s.type == "circular" or s.type == "linear" or s.type == "rectangular" then 
			if GetDistanceSqr(myHero.pos, endPos) < (s.radius + myHero.boundingRadius) ^ 2 or GetDistanceSqr(myHero.pos, Col) < (s.radius + myHero.boundingRadius * 1.25) ^ 2 then
				local t = s.speed ~= math.huge and CalculateCollisionTime(startPos, endPos, myHero.pos, s.startTime, s.speed, s.delay) or 0.29
				if t < 0.7 then
					if Control.CastSpell(HK_W) then
						table.remove(self.DetectedSpells, i)
					end
				end				
			end
		end	
	else table.remove(self.DetectedSpells, i) end
end
 
function zgSamira:Combo()
	local level = myHero.levelData.lvl
	local passiveDis = math.min(950, 650 + 75 * math.floor(level / 4))
	local target = GetTarget(1000)
	if target == nil then return end
	if IsValid(target) then
		if IsHardCC(target) and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) and myHero.pos:DistanceTo(target.pos) <= passiveDis and not HaveBuff(target, "samirapcooldown") then
			Control.Attack(target)
		end
		if IsReady(_R) and Menu.Combo.UseR:Value() then					
			if GetEnemyCount(self.RSpell.Range, myHero.pos) >= 1 then
				Control.CastSpell(HK_R)
			end
		end

		if Menu.Combo.UseW:Value() and IsReady(_W) then
			if myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then					
				Control.CastSpell(HK_W)
			end
		end
		
		if Menu.Combo.UseE:Value() and IsReady(_E) and not IsReady(_W) then
			if myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then					
				Control.CastSpell(HK_E, target)
			end
		end
		
		if Menu.Combo.UseQ:Value() and IsReady(_Q) then
			if myHero.pos:DistanceTo(target.pos) < self.QSpell.Range and myHero.pos:DistanceTo(target.pos) > self.WSpell.Range then
				self:CastQ(target)		
			end
			if myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				Control.CastSpell(HK_Q, target)
			end				
		end
	end	
end

function zgSamira:Harass()
local target = GetTarget(1000)     	
if target == nil then return end 
	if IsValid(target) then
		if Menu.Harass.UseQ:Value() and IsReady(_Q) then
			if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range and myHero.pos:DistanceTo(target.pos) > self.WSpell.Range then
				self:CastQ(target)		
			end
			if myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				Control.CastSpell(HK_Q, target.pos)		
			end
		end	
	end	
end

function zgSamira:KillSteal()
	for i, target in ipairs(GetEnemyHeroes()) do     	
		if target and myHero.pos:DistanceTo(target.pos) <= 1000 and IsValid(target) then
			local QDmg = self:GetQDmg(target)
			local EDmg = self:GetEDmg(target)			
			
			if Menu.ks.UseQ:Value() and Menu.ks.UseE:Value() and IsReady(_Q) and IsReady(_E) then
				if myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then
					if QDmg + EDmg > target.health then
						if Control.CastSpell(HK_E, target) then
							Control.CastSpell(HK_Q)
						end	
					end
				end
			end
									
			if IsReady(_Q) and Menu.ks.UseQ:Value() then	 
				if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range and myHero.pos:DistanceTo(target.pos) > self.WSpell.Range and QDmg > target.health then
					self:CastQ(target)	
				end	
				if myHero.pos:DistanceTo(target.pos) < self.WSpell.Range and QDmg > target.health then
					Control.CastSpell(HK_Q, target)	
				end
			end
			
			if IsReady(_E) and Menu.ks.UseE:Value() then
				if myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range and EDmg > target.health then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end	
end	

function zgSamira:JungleClear()
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)

		if minion.team == 300 and IsValid(minion) and myHero.pos:DistanceTo(minion.pos) < self.QSpell.Range then          			
			
			if myHero.pos:DistanceTo(minion.pos) < self.QSpell.Range and myHero.pos:DistanceTo(minion.pos) > self.WSpell.Range and Menu.Clear.JungleClear.UseQ:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q, minion)
			end	
			
			if myHero.pos:DistanceTo(minion.pos) < self.WSpell.Range and Menu.Clear.JungleClear.UseQ2:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q, minion)
			end			
        end
    end
end
			
function zgSamira:LaneClear()
	if Menu.Clear.LaneClear.UseQ:Value() and IsReady(_Q) then
		for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)

			if minion.team ~= 300 and IsValid(minion) and myHero.pos:DistanceTo(minion.pos) < self.WSpell.Range then				
				local Count = GetMinionCount(300, minion.pos)
				if Count >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell(HK_Q, minion.pos)
				end			
			end
		end
	end	
end

function zgSamira:LastHit()
	local minionInRange = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	if next(minionInRange) == nil then return end

	for i = 1, #minionInRange do
        	local minion = minionInRange[i]

		local AARange = myHero.range + myHero.boundingRadius
		if IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) > AARange then
			local QDmg = self:GetQDmg(minion)
			if QDmg >= _G.SDK.HealthPrediction:GetPrediction(minion, 0.25+myHero.pos:DistanceTo(minion.pos)/2600) then
				Control.CastSpell(HK_Q, minion.pos)
			end
		end
	end
end

function zgSamira:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		  QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end	
end

function zgSamira:GetQDmg(unit)
	local qlvl = myHero:GetSpellData(_Q).level
	local baseDmg  = 5 * qlvl - 5
	local adDmg = 1.1 * myHero.totalDamage
	local Dmg = baseDmg + adDmg
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, Dmg) 
end

function zgSamira:GetEDmg(unit)
	local elvl = myHero:GetSpellData(_E).level
	local baseDmg  = 10 * elvl + 40
	local adDmg = myHero.bonusDamage * 0.2
	local Dmg = baseDmg + adDmg
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg) 	
end
 
function zgSamira:Draw()
	if myHero.dead then return end
	
	if Menu.Drawing.DrawQ:Value() and IsReady(_Q) then
    Draw.Circle(myHero, self.QSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end                                                 
	if Menu.Drawing.DrawW:Value() and IsReady(_W) then
    Draw.Circle(myHero, self.WSpell.Range, 1, Draw.Color(225, 225, 0, 10))
	end
	if Menu.Drawing.DrawE:Value() and IsReady(_E) then
    Draw.Circle(myHero, self.ESpell.Range, 1, Draw.Color(225, 225, 125, 10))
	end
	if Menu.Drawing.DrawR:Value() then
    Draw.Circle(myHero, self.RSpell.Range, 1, Draw.Color(225, 225, 125, 10))
	end
end

zgSamira()
