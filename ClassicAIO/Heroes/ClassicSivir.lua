local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

local shellSpells = {
    ["Jade_AlistarW"] = {charName = "Jade_Alistar", slot = "W", speed = math.huge, delay = 0.51},
    ["Jade_AniviaFrostbite"] = {charName = "Jade_Anivia", slot = "E", speed = 1600, delay = 0.25},
    ["Jade_AnnieQ"] = {charName = "Jade_Annie", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_BlitzcrankPowerFistAttack"] = {charName = "Jade_Blitzcrank", slot = "E", speed = math.huge, delay = 0.34},
    ["Jade_BrandE"] = {charName = "Jade_Brand", slot = "E", speed = 1800, delay = 0.25},
    ["Jade_BrandR"] = {charName = "Jade_Brand", slot = "R", speed = 1000, delay = 0.25},
    ["Jade_ChogathR"] = {charName = "Jade_Chogath", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_EvelynnE"] = {charName = "Jade_Evelynn", slot = "E", speed = 902, delay = 0.25},
    ["Jade_FiddlesticksQ"] = {charName = "Jade_Fiddlesticks", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_FiddlesticksW"] = {charName = "Jade_Fiddlesticks", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_FiddlesticksE"] = {charName = "Jade_Fiddlesticks", slot = "E", speed = 1800, delay = 0.40},
    ["Jade_GangplankQ"] = {charName = "Jade_Gangplank", slot = "Q", speed = 2000, delay = 0.25},
    ["Jade_GarenQAttack"] = {charName = "Jade_Garen", slot = "Q", speed = math.huge, delay = 0.39},
    ["Jade_GarenR"] = {charName = "Jade_Garen", slot = "R", speed = math.huge, delay = 0.44},
    ["Jade_JannaSowTheWind"] = {charName = "Jade_Janna", slot = "W", speed = 1600, delay = 0.25},
    ["Jade_JarvanIVCataclysm"] = {charName = "Jade_JarvanIV", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_JaxQ"] = {charName = "Jade_Jax", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_JaxWAttack"] = {charName = "Jade_Jax", slot = "W", speed = math.huge, delay = 0},
    ["Jade_KassadinQ"] = {charName = "Jade_Kassadin", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_KatarinaQ"] = {charName = "Jade_Katarina", slot = "Q", speed = 1600, delay = 0.25},
    ["Jade_KatarinaE"] = {charName = "Jade_Katarina", slot = "E", speed = math.huge, delay = 0},
    ["Jade_KayleQ"] = {charName = "Jade_Kayle", slot = "Q", speed = 1000, delay = 0.25},
    ["Jade_KogMawQ"] = {charName = "Jade_KogMaw", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_LeeSinQTwo"] = {charName = "Jade_LeeSin", slot = "Q2", speed = 2200, delay = 0.25},
    ["Jade_LeeSinR"] = {charName = "Jade_LeeSin", slot = "R", speed = 1500, delay = 0.25},
    ["Jade_LeonaShieldOfDaybreakAttack"] = {charName = "Jade_Leona", slot = "Q", speed = math.huge, delay = 0.39},
    ["Jade_LuluW"] = {charName = "Jade_Lulu", slot = "W", speed = 2000, delay = 0.175},
    ["Jade_LuluE"] = {charName = "Jade_Lulu", slot = "E", speed = math.huge, delay = 0.175},
    ["Jade_MalphiteSeismicShard"] = {charName = "Jade_Malphite", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_MalzaharE"] = {charName = "Jade_Malzahar", slot = "E", speed = 1400, delay = 0.25},
    ["Jade_MalzaharR"] = {charName = "Jade_Malzahar", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_MasterYiAlphaStrike"] = {charName = "Jade_MasterYi", slot = "Q", speed = 4000, delay = 0.10},
    ["Jade_MissFortuneRicochetShot"] = {charName = "Jade_MissFortune", slot = "Q", speed = 1400, delay = 0.25},
    ["Jade_NasusSiphoningStrikeAttack"] = {charName = "Jade_Nasus", slot = "Q", speed = math.huge, delay = 0.52},
    ["Jade_NasusW"] = {charName = "Jade_Nasus", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_NidaleeCougarTakedownAttack"] = {charName = "Jade_Nidalee", slot = "Q2", speed = math.huge, delay = 0.35},
    ["Jade_NunuE"] = {charName = "Jade_Nunu", slot = "E", speed = 1000, delay = 0.25},
    ["Jade_OlafE"] = {charName = "Jade_Olaf", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_PantheonQ"] = {charName = "Jade_Pantheon", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_PantheonW"] = {charName = "Jade_Pantheon", slot = "W", speed = math.huge, delay = 0.125},
    ["Jade_RammusE"] = {charName = "Jade_Rammus", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_RyzeQ"] = {charName = "Jade_Ryze", slot = "Q", speed = 1700, delay = 0.25},
    ["Jade_RyzeW"] = {charName = "Jade_Ryze", slot = "W", speed = math.huge, delay = 0.25},
    ["Jade_RyzeE"] = {charName = "Jade_Ryze", slot = "E", speed = 1000, delay = 0.25},
    ["Jade_ShacoTwoShivPoison"] = {charName = "Jade_Shaco", slot = "E", speed = 1500, delay = 0.25},
    ["Jade_SingedFling"] = {charName = "Jade_Singed", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_SionQ"] = {charName = "Jade_Sion", slot = "Q", speed = 1600, delay = 0.25},
    ["Jade_SkarnerR"] = {charName = "Jade_Skarner", slot = "R", speed = math.huge, delay = 0.25},
    ["Jade_SorakaE"] = {charName = "Jade_Soraka", slot = "E", speed = math.huge, delay = 0.25},
    ["Jade_TaricE"] = {charName = "Jade_Taric", slot = "E", speed = 1750, delay = 0.25},
    ["Jade_TeemoQ"] = {charName = "Jade_Teemo", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_TristanaE"] = {charName = "Jade_Tristana", slot = "E", speed = 1400, delay = 0.25},
    ["Jade_TristanaR"] = {charName = "Jade_Tristana", slot = "R", speed = 1600, delay = 0.25},
    ["Jade_TwistedFate_BlueCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Blue W", speed = 1500, delay = 0.125},
    ["Jade_TwistedFate_GoldCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Gold W", speed = 1500, delay = 0.125},
    ["Jade_TwistedFate_RedCardPreAttack"] = {charName = "Jade_TwistedFate", slot = "Red W", speed = 1500, delay = 0.125},
    ["Jade_VayneE"] = {charName = "Jade_Vayne", slot = "E", speed = 1200, delay = 0.25},
    ["Jade_VeigarBalefulStrike"] = {charName = "Jade_Veigar", slot = "Q", speed = 1200, delay = 0.25},
    ["Jade_VeigarR"] = {charName = "Jade_Veigar", slot = "R", speed = 1400, delay = 0.25},
    ["Jade_WarwickQ"] = {charName = "Jade_Warwick", slot = "Q", speed = 1500, delay = 0.25},
    ["Jade_WarwickR"] = {charName = "Jade_Warwick", slot = "R", speed = math.huge, delay = 0.10},
    ["Jade_WukongQAttack"] = {charName = "Jade_Wukong", slot = "Q", speed = math.huge, delay = 0.35},
    ["Jade_WukongE"] = {charName = "Jade_Wukong", slot = "E", speed = 2200, delay = 0},
    ["Jade_ZileanQ"] = {charName = "Jade_Zilean", slot = "Q", speed = math.huge, delay = 0.25},
    ["Jade_ZileanE"] = {charName = "Jade_Zilean", slot = "E", speed = math.huge, delay = 0.515},
}

class "ClassicSivir"

function ClassicSivir:__init()
    print("Classic AIO - Sivir Loaded")
    self.Q = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1250, Speed = 1350, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
    self:LoadMenu()
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function ClassicSivir:LoadMenu()

    local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
    Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

    Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
        Menu.combo:MenuElement({id = "Q", name = "Use Q Combo", value = true})
        Menu.combo:MenuElement({id = "maxRange", name = "Max Q Range", value = 1150, min = 0, max = 1250, step = 10})
        Menu.combo:MenuElement({id = "W", name = "Use W AOE (2+ Enemy Heroes)", value = true})

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

function ClassicSivir:Draw()
    if myHero.dead then return end
    if Menu.draw.Q:Value() and IsReady(_Q) then
        Draw.Circle(myHero.pos, self.Q.Range,Draw.Color(255,255, 162, 000))
    end

end

function ClassicSivir:Tick()
    if ShouldWait() or IsCasting() then return end

    local mode = GetMode()
    if mode == "Combo" then 
        self:Combo()
    elseif mode == "Harass" then 
        self:Harass()
    end
    if mode ~= "LaneClear" and IsReady(_W) and myHero:GetSpellData(_W).toggleState == 2 and lastW + 300 < GetTickCount() then
        local target = GetTarget(self.Q.Range)
        if mode ~= "Combo" or not Menu.combo.W:Value() or not target or not IsValid(target) or not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or GetEnemyCount(450, target.pos) < 2 then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
    end
    self:BlockSpell()
    self:AutoQ()
end

function ClassicSivir:Combo() 
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) then
        if Menu.combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).toggleState == 1 and lastW + 300 < GetTickCount() and _G.SDK.Data:IsInAutoAttackRange(myHero, target) and GetEnemyCount(450, target.pos) >= 2 then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
        if Menu.combo.Q:Value() and myHero.pos:DistanceTo(target.pos) < Menu.combo.maxRange:Value() then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:Harass() 
    local manaPer = myHero.mana/myHero.maxMana
    local target = GetTarget(self.Q.Range)
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) < Menu.harass.maxRange:Value() and Menu.harass.mana:Value()/100 < manaPer then
        if Menu.harass.Q:Value() then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:CastQ(target)
    if IsReady(_Q) and target.pos2D.onScreen then
        local Pred = GGPrediction:SpellPrediction(self.Q)
        Pred:GetPrediction(target, myHero)
        if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_Q, Pred.CastPosition)
        end
    end
end

function ClassicSivir:AutoQ()
    for k , target in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do 
        if Menu.auto.Q:Value() and myHero.pos:DistanceTo(target.pos) < self.Q.Range and IsValid(target) and IsHardCC(target) then
            self:CastQ(target)
        end
    end
end

function ClassicSivir:BlockSpell()
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

ClassicSivir()
