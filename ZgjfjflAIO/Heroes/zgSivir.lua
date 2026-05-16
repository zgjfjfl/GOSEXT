local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local shellSpells = {
    ["NidaleeTakedownAttack"] = {charName = "Nidalee", slot = "Q2",  speed = math.huge, delay = 0.25},
    ["BriarQ"] = {charName = "Briar", slot = "Q",  speed = 1500, delay = 0.25},
    ["KSanteR"] = {charName = "KSante", slot = "R",  speed = math.huge, delay = 0.4},
    ["UdyrE"] = {charName = "Udyr", slot = "E",  speed = math.huge, delay = 0.25},
    ["NautilusAnchorDragMissile"] = {charName = "Nautilus", slot = "Q", speed = 2000 , delay = 0.25 },
    ["NautilusRavageStrikeAttack"] = {charName = "Nautilus", slot = "Passive", speed = math.huge, delay = 0.25},
    ["RekSaiWUnburrowLockout"] = {charName = "RekSai",  slot = "W", speed = math.huge, delay = 0.25},
    ["SkarnerPassiveAttack"] = {charName = "Skarner", slot = "E Passive", speed = math.huge, delay = 0.25},
    ["WarwickE"] = {charName = "Warwick",  slot = "E", speed = 1600, delay = 0},  -- need test
    ["WarwickRChannel"] = {charName = "Warwick",  slot = "R", speed = math.huge, delay = 0.1},  -- need test
    ["XinZhaoQThrust3"] = {charName = "XinZhao",  slot = "Q3", speed = math.huge, delay = 0.25},
    ["VolibearQAttack"]  = {charName = "Volibear",  slot = "Q", speed = math.huge, delay = 0.25},
    ["LeonaShieldOfDaybreakAttack"] = {charName = "Leona", slot = "Q", speed = math.huge, delay = 0.25},
    ["GoldCardPreAttack"] = {charName = "TwistedFate", slot = "GoldW", speed = math.huge, delay = 0.25},
    ["PowerFistAttack"] = {charName = "Blitzcrank", slot = "E", speed = math.huge, delay = 0.25},
    ["ViegoW"] = {charName = "Viego"  , slot = "W" , delay = 0   , speed = 1300   },
    ["RenataR"] = {charName = "Renata" , slot = "R" , delay = 0.75, speed = 1000   },
    ["FlashFrostSpell"] = {charName = "Anivia" , slot = "Q" , delay = 0.25, speed = 950    },
    ["Frostbite"]= {charName = "Anivia", slot = "E", delay = 0.25, speed = 1600  },
    ["AnnieQ"] = {charName = "Annie" , slot = "Q" , delay = 0.25, speed = 1400  },
    ["BrandE"] = {charName = "Brand" , slot = "E", delay = 0.25, speed = math.huge  },
    ["BrandR"] = {charName = "Brand" , slot = "R" , delay = 0.25, speed = 1000  },   -- to be comfirm brand R delay 0.25 or 0.5
    ["CassiopeiaE"] = {charName = "Cassiopeia", slot = "E", delay = 0.15, speed = 2500  },   -- delay to be comfirm
    ["CamilleR"] = {charName = "Camille", slot = "R", delay = 0, speed = math.huge  },   -- delay to be comfirm
    ["Feast"] = {charName = "Chogath", slot = "R" , delay = 0.25, speed = math.huge  },
    ["DariusNoxianTacticsONHAttack"] = {charName = "Darius" , slot = "W" , delay = 0.25, speed = math.huge  },
    ["DariusExecute"] = {charName = "Darius" , slot = "R" , delay = 0.36, speed = math.huge  }, 
    ["EliseHumanQ"]   = {charName = "Elise"  , slot = "Q1", delay = 0.25, speed = 2200  },
    ["EliseSpiderQCast"]   = {charName = "Elise"  , slot = "Q2", delay = 0.25, speed = math.huge  },
    ["Terrify"]  = {charName = "FiddleSticks", slot = "Q" , delay = 0.25, speed = math.huge  },
    ["GangplankQProceed"]  = {charName = "Gangplank"   , slot = "Q" , delay = 0.25, speed = 2600  },
    ["GarenQAttack"]  = {charName = "Garen"  , slot = "Q" , delay = 0.25, speed = math.huge  },
    ["GarenR"]   = {charName = "Garen"  , slot = "R" , delay = 0.25, speed = math.huge  },
    ["SowTheWind"]    = {charName = "Janna"  , slot = "W" , delay = 0.25, speed = 1600  },
    ["JarvanIVCataclysm"]  = {charName = "JarvanIV"    , slot = "R" , delay = 0.25, speed = math.huge  },
    ["JayceToTheSkies"]    = {charName = "Jayce"  , slot = "Q2", delay = 0.25, speed = math.huge  }, -- seems speed base on distance, lazy to find the forumla , maybe fixed delay
    ["JayceThunderingBlow"]= {charName = "Jayce"  , slot = "E2", delay = 0.25, speed = math.huge  },
    ["KatarinaQ"]= {charName = "Katarina"    , slot = "Q" , delay = 0.25, speed = 1600  },
    ["KatarinaE"]= {charName = "Katarina"    , slot = "E" , delay = 0.1 , speed = math.huge  }, -- delay to be comfirm
    ["NullLance"]= {charName = "Kassadin"    , slot = "Q" , delay = 0.25, speed = 1400  },
    ["KhazixQ"]  = {charName = "Khazix" , slot = "Q1", delay = 0.25, speed = math.huge  },
    ["KhazixQLong"]   = {charName = "Khazix" , slot = "Q2", delay = 0.25, speed = math.huge  },
    ["BlindMonkQOne"]= {charName = "LeeSin" , slot = "Q" , delay = 0.25, speed = 1800  },
    ["BlindMonkRKick"]= {charName = "LeeSin" , slot = "R" , delay = 0.25, speed = math.huge  },
    ["LeblancQ"] = {charName = "Leblanc", slot = "Q" , delay = 0.25, speed = 2000  },
    ["LeblancRQ"]= {charName = "Leblanc", slot = "RQ", delay = 0.25, speed = 2000  },
    ["LissandraREnemy"]    = {charName = "Lissandra"   , slot = "R" , delay = 0.5 , speed = math.huge  },
    ["LucianQ"]  = {charName = "Lucian" , slot = "Q" , delay = 0.25, speed = math.huge  }, --  delay = 0.4 − 0.25 (based on level)
    ["LuluWTwo"] = {charName = "Lulu"   , slot = "W" , delay = 0.25, speed = 2250  },
    ["SeismicShard"]  = {charName = "Malphite"    , slot = "Q" , delay = 0.25, speed = 1200  },
    ["MalzaharE"]= {charName = "Malzahar"    , slot = "E" , delay = 0.25, speed = math.huge  },
    ["MalzaharR"]= {charName = "Malzahar"    , slot = "R" , delay = 0   , speed = math.huge  },
    ["AlphaStrike"]   = {charName = "MasterYi"    , slot = "Q" , delay = 0   , speed = 4000  },
    ["MissFortuneRicochetShot"] = {charName = "MissFortune" , slot = "Q" , delay = 0.25, speed = 1400  },
    ["NasusW"]   = {charName = "Nasus"  , slot = "W" , delay = 0.25, speed = math.huge  },
    ["NautilusGrandLine"]  = {charName = "Nautilus"    , slot = "R" , delay = 0.46, speed = 1400  }, 
    ["NunuQ"]    = {charName = "Nunu"   , slot = "Q" , delay = 0.25, speed = math.huge  },
    ["OlafRecklessStrike"] = {charName = "Olaf"   , slot = "E" , delay = 0.25, speed = math.huge  },
    ["PantheonW"]= {charName = "Pantheon"    , slot = "W" , delay = 0   , speed = math.huge  },
    ["RekSaiE"]  = {charName = "RekSai" , slot = "E" , delay = 0.25, speed = math.huge  },
    ["RekSaiR"]  = {charName = "RekSai" , slot = "R" , delay = 1.5 , speed = math.huge  },
    ["PuncturingTaunt"]    = {charName = "Rammus" , slot = "E" , delay = 0.25, speed = math.huge  },
    ["RenektonExecute"]    = {charName = "Renekton"    , slot = "W1", delay = 0.25, speed = math.huge  },
    ["RenektonSuperExecute"]    = {charName = "Renekton"    , slot = "W2", delay = 0.25, speed = math.huge  },
    ["RyzeW"]    = {charName = "Ryze"   , slot = "W" , delay = 0.25, speed = math.huge  },
    ["Fling"]    = {charName = "Singed" , slot = "E" , delay = 0.25, speed = math.huge  },
    ["SyndraR"]  = {charName = "Syndra" , slot = "R" , delay = 0.25, speed = 1400  },
    ["TwoShivPoison"] = {charName = "Shaco"  , slot = "E" , delay = 0.25, speed = 1500  },
    ["TahmKenchW"]    = {charName = "TahmKench"   , slot = "W" , delay = 0.25, speed = math.huge  },
    ["TalonQAttack"]  = {charName = "Talon"  , slot = "Q1", delay = 0.25, speed = math.huge  },
    ["BlindingDart"]  = {charName = "Teemo"  , slot = "Q" , delay = 0.25, speed = 1500  },
    ["TristanaR"]= {charName = "Tristana"    , slot = "R" , delay = 0.25, speed = 2000  },
    ["TrundlePain"]   = {charName = "Trundle", slot = "R" , delay = 0.25, speed = math.huge  },
    ["ViR"] = {charName = "Vi", slot = "R" , delay = 0.25, speed = 800   },
    ["VayneCondemn"]  = {charName = "Vayne"  , slot = "E" , delay = 0.25, speed = 2200  },
    ["VolibearQAttack"]    = {charName = "Volibear"    , slot = "Q" , delay = 0   , speed = math.huge  },
    ["VeigarR"]  = {charName = "Veigar" , slot = "R" , delay = 0.25, speed = math.huge  },
    ["VladimirQ"]= {charName = "Vladimir"    , slot = "Q" , delay = 0.25, speed = math.huge  },
    ["SylasR"]   = {charName = "Sylas"  , slot = "R" , delay = 0.25, speed = 2200  },

}

class "zgSivir"

function zgSivir:__init()
    print("Zgjfjfl AIO - Sivir Loaded")
    self.Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1250, Speed = 1450, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
    self:LoadMenu()
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    _G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
end

function zgSivir:LoadMenu()

    local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
    Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

    Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
        Menu.combo:MenuElement({id = "Q", name = "Use Q Combo", value = true})
        Menu.combo:MenuElement({id = "maxRange", name = "Max Q Range", value = 1150, min = 0, max = 1250, step = 10})
        Menu.combo:MenuElement({id = "WAA", name = "use W AA reset", value = true})

    Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
        Menu.harass:MenuElement({id = "Q", name = "Use Q Harass", value = true})
        Menu.harass:MenuElement({id = "maxRange", name = "Max Q Range", value = 1150, min = 0, max = 1250, step = 10})
        Menu.harass:MenuElement({id = "mana", name = "Only cast spell if mana >", value = 30, min = 0, max = 100, step = 1})

    Menu:MenuElement({type = MENU, id = "auto", name = "Auto Q"})
        Menu.auto:MenuElement({id = "Q", name = "Use Q in Immobile Target", value = true})

    Menu:MenuElement({type = MENU, id = "eSetting", name = "E Setting"})
        Menu.eSetting:MenuElement({id = "eDelay", name = "Xs before Spell hit", value = 0.2, min = 0, max = 1.5, step = 0.01})
        Menu.eSetting:MenuElement({type = MENU, id = "blockSpell", name = "Auto E Block Spell"})
        _G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
            for k, v in pairs(shellSpells) do
                if v.charName == args.charName then
                    Menu.eSetting.blockSpell:MenuElement({id = k, name = v.charName.." | "..v.slot, value = true})
                end
            end
        end)
        Menu.eSetting:MenuElement({type = MENU, id = "dash", name = "Auto E If Enemy dash on ME"})
        _G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
            Menu.eSetting.dash:MenuElement({id = args.charName, name = args.charName, value = false})
        end)

    Menu:MenuElement({type = MENU, id = "draw", name = "Draw Setting"})
        Menu.draw:MenuElement({id = "Q", name = "Draw Q", value = false})

end

function zgSivir:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
    if GetMode() == "Combo" then
        if target and target.type == Obj_AI_Hero and Menu.combo.WAA:Value() and IsReady(_W) and lastW + 300 < GetTickCount() then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
    end
end

function zgSivir:Draw()
    if myHero.dead then return end
    if Menu.draw.Q:Value() and IsReady(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(255,255, 162, 000))
    end

end

function zgSivir:Tick()
    local bonusAS = math.min(myHero.attackSpeed - 1, 1.2)
    self.Q.Delay = 0.25 * (1 - 0.5 * bonusAS)
    if ShouldWait() or IsCasting() then return end

    if GetMode() == "Combo" then 
        self:Combo()
    elseif GetMode() == "Harass" then 
        self:Harass()
    end
    self:BlockSpell()
    self:AutoQ()
end

function zgSivir:Combo() 
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < Menu.combo.maxRange:Value() then
        if Menu.combo.Q:Value() then
            self:CastQ(target)
        end
    end
end

function zgSivir:Harass() 
    local manaPer = myHero.mana/myHero.maxMana
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < Menu.harass.maxRange:Value() and Menu.harass.mana:Value()/100 < manaPer then
        if Menu.harass.Q:Value() then
            self:CastQ(target)
        end
    end
end

function zgSivir:CastQ(target)
    if IsReady(_Q) and target.pos2D.onScreen then
        local Pred = GGPrediction:SpellPrediction(self.Q)
        Pred:GetPrediction(target, myHero)
        if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_Q, Pred.CastPosition)
        end
    end
end

function zgSivir:AutoQ()
    for k , target in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do 
        if Menu.auto.Q:Value() and myHero.pos:DistanceTo(target.pos) < self.Q.Range and IsValid(target) and IsHardCC(target) then
            self:CastQ(target)
        end
    end
end

function zgSivir:BlockSpell()
    if IsReady(_E) then
        for k , hero in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
            if hero.activeSpell.valid and shellSpells[hero.activeSpell.name] ~= nil then
                if hero.activeSpell.target == myHero.handle and Menu.eSetting.blockSpell[hero.activeSpell.name]:Value() then
                    local dt = hero.pos:DistanceTo(myHero.pos)
                    local spell = shellSpells[hero.activeSpell.name]
                    local hitTime = spell.delay + dt/spell.speed
                    DelayAction(function()
                        Control.CastSpell(HK_E)
                    end, (hitTime-Menu.eSetting.eDelay:Value()))
                    return
                end
            end

            if hero.pathing.isDashing and Menu.eSetting.dash[hero.charName] and Menu.eSetting.dash[hero.charName]:Value() then
                local vct = Vector(hero.pathing.endPos.x,hero.pathing.endPos.y,hero.pathing.endPos.z)
                if vct:DistanceTo(myHero.pos) < 172 then
                    Control.CastSpell(HK_E)
                    return
                end
            end
        end
    end
end

zgSivir()
