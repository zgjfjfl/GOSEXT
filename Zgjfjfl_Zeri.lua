
local Heroes ={"Zeri"}

require "MapPositionGOS"
require "GGPrediction"

local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local orbwalker         = _G.SDK.Orbwalker
local HealthPrediction         = _G.SDK.HealthPrediction


local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and Game.CanUseSpell(spell) == 0
end

local function getDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function getDistance(Pos1, Pos2)
    return math.sqrt(getDistanceSqr(Pos1, Pos2))
end

local function isValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function getEnemyHeroesWithinDistanceOfUnit(location, distance)
    local EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy and not Hero.dead and Hero.pos:DistanceTo(location) < distance then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyHeroesWithinDistance(distance)
    return getEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
end

local function doesMyChampionHaveBuff(buffName)
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function castSpell(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_NORMAL) then
        if myHero.pos:DistanceTo(pred.CastPosition) <= spellData.Range + 15 then
            Control.CastSpell(hotkey, pred.CastPosition)	
        end
    end
end

local function castSpellHigh(spellData, hotkey, target)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(hotkey, pred.CastPosition)	
    end
end
local function castSpellExtended(spellData, hotkey, target, extendAmount)
    local pred = GGPrediction:SpellPrediction(spellData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_NORMAL) then
        local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), extendAmount) 
        Control.CastSpell(hotkey, castPos)	
    end
end

class "Zeri"
        
function Zeri:__init()	     
    print("devX-Zeri Loaded") 
    self:LoadMenu()
   
    Callback.Add("Draw", function() self:Draw() end)           
    Callback.Add("Tick", function() self:onTickEvent() end)    
    self.qRange = 825
    self.aaRange = myHero.range
    
    _G.SDK.Spell:SpellClear(_Q, 
                            {Range=825, Speed = 2600, Delay = 0.1, Radius = 40 },
                            function ()
                                return isSpellReady(_Q)
                            end,
                            function ()
                                return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and self.Menu.QSpell.QLHEnabled:Value() and isSpellReady(_Q)
                            end,
                            function ()
                                return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and self.Menu.QSpell.QLCEnabled:Value()  and isSpellReady(_Q)
                            end,
                            function () 
                                local levelDmgTbl  = {8 , 11 , 14 , 17 , 20}
                                local levelPctTbl  = {1.05 , 1.1 , 1.15 , 1.2 , 1.25}
                                local levelDmg = levelDmgTbl[myHero:GetSpellData(_Q).level]
                                local levelPct = levelPctTbl[myHero:GetSpellData(_Q).level]
                                local dmg = levelDmg + myHero.totalDamage*levelPct
                                return dmg
                            end
    )
    
end


function Zeri:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgZeri", name = "Zgjfjfl Zeri"})
    
    self.Menu:MenuElement({type = MENU, id = "BlockAA", name = "Block AA without Q passive"})
        self.Menu.BlockAA:MenuElement({id = "enabled", name = "Enabled", value = true, key = string.byte("T"), toggle = true})

    self.Menu:MenuElement({type = MENU, id = "QSpell", name = "Q"})
        self.Menu.QSpell:MenuElement({ id = "QEnabled", name = "Combo Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QHEnabled", name = "Harass Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QLCEnabled", name = "Lane Clear Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QLHEnabled", name = "LastHit Enabled", value = true})

    self.Menu:MenuElement({type = MENU, id = "WSpell", name = "W"})
        self.Menu.WSpell:MenuElement({ id = "WEnabled", name = "Combo Enabled", value = true})
        self.Menu.WSpell:MenuElement({ id = "WTerrain", name = "Use only through Walls", value = true})

    self.Menu:MenuElement({type = MENU, id = "ESpell", name = "E"})
        self.Menu.ESpell:MenuElement({ id = "EEnabled", name = "Combo Enabled", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "RSpell", name = "R"})
        self.Menu.RSpell:MenuElement({ id = "RCount", name = "Use Ultimate when can hit >= X enemies", min = 0, max = 5, value=2})

    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
        self.Menu.Drawing:MenuElement({id = "DrawBlockAA", name = "Draw Block AA", value = true})
end


function Zeri:onTickEvent()
    self.hasPassive = doesMyChampionHaveBuff("zeriqpassiveready")
    if self.hasPassive and self.Menu.BlockAA.enabled:Value() then
        orbwalker:SetAttack(true)
    elseif not self.hasPassive and self.Menu.BlockAA.enabled:Value() then
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end

    self.hasRbuff = doesMyChampionHaveBuff("ZeriR")
    if self.hasRbuff then
        qData = {Type = GGPrediction.SPELLTYPE_LINE, Range=self.qRange, Speed = 3400, Delay = 0.1, Radius = 40,  Collision = false}
    end

    if myHero.range == 575 then
        self.qRange = 900
    else
        self.qRange = 825
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
	
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

end

function Zeri:castQ(target)
    local qData = {Type = GGPrediction.SPELLTYPE_LINE, Range=self.qRange, Speed = 2600, Delay = 0.1, Radius = 40,  Collision = false}
    castSpell(qData,HK_Q, target)
end

function Zeri:assessWOptions(target)
    local wData = {Type = GGPrediction.SPELLTYPE_LINE, Range= 1200, Speed = 2200, Delay = 0.6, Radius = 40,  Collision = false}
    local w2Data = {Type = GGPrediction.SPELLTYPE_LINE, Range= 2700, Speed = 2200, Delay = 0.6, Radius = 100,  Collision = false}
    local direction = (target.pos - myHero.pos):Normalized()
    for distance = 50, 1100, 50 do
        local testPosition = myHero.pos + direction * distance
        if testPosition:ToScreen().onScreen then
            
            for i = 1, GameMinionCount() do -- blocked by minion
                local minion = GameMinion(i)
                if minion and minion.isEnemy and isValid(minion) and minion.pos:DistanceTo(testPosition) < 50 then
                    return false
                end 
            end
            if target.pos:DistanceTo(testPosition) < 50 then
                if not self.Menu.WSpell.WTerrain:Value() then
                    castSpellHigh(wData,HK_W, target)
                    return true
                else
                    return false
                end
            end
            if MapPosition:inWall(testPosition) then
                if target.pos:DistanceTo(testPosition) > 1500 then
                    return false
                end
                castSpellHigh(w2Data,HK_W, target)
                return true
            end
        end
    end
    return false
end

function Zeri:Combo()
    local target = orbwalker:GetTarget()
    
    if not target then
        target = _G.SDK.TargetSelector:GetTarget(2700, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    end
    if target then
        local distance = myHero.pos:DistanceTo(target.pos) 
        if self.hasPassive and distance <= self.aaRange then return end --lets use charged auto instead
        
        if isSpellReady(_W) and self.Menu.WSpell.WEnabled:Value() then
            self:assessWOptions(target)
        end
        if self.Menu.QSpell.QEnabled:Value() and distance < self.qRange and isSpellReady(_Q) and not orbwalker:IsAutoAttacking() then
            self:castQ(target)
        end

        if self.Menu.ESpell.EEnabled:Value() and isSpellReady(_E) then
            local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * 300
            Control.CastSpell(HK_E, pos)
        end

        local closeEnemies = getEnemyHeroesWithinDistance(825)
        if #closeEnemies >= self.Menu.RSpell.RCount:Value() and isSpellReady(_R) then
            Control.CastSpell(HK_R, myHero)
        end
    end
end

function Zeri:Harass()
    local target = orbwalker:GetTarget()
    if not target then
        target = _G.SDK.TargetSelector:GetTarget(1000, _G.SDK.DAMAGE_TYPE_PHYSICAL);
    end
    if target then
        local distance = myHero.pos:DistanceTo(target.pos) 
        if self.hasPassive and distance <= self.aaRange then return end --lets use charged auto instead
        
        if self.Menu.QSpell.QHEnabled:Value() and myHero.pos:DistanceTo(target.pos) < self.qRange and isSpellReady(_Q) and not orbwalker:IsAutoAttacking()  then
            self:castQ(target)
        end

    end
   
end

function Zeri:Draw()
    if self.Menu.Drawing.DrawBlockAA:Value() then
    else 
        return
    end
    if self.Menu.BlockAA.enabled:Value() then
        Draw.Text("Block AA:ON", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 000, 255, 000))
    else
        Draw.Text("Block AA:OFF", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 255, 000, 000))
    end
end

function onLoadEvent()
    if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
    end
end


Callback.Add('Load', onLoadEvent)
