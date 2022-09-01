
local Heroes ={"Nilah"}

require "GGPrediction"

local GameTurret = Game.Turret
local GameTurretCount = Game.TurretCount
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local orbwalker         = _G.SDK.Orbwalker
local HealthPrediction         = _G.SDK.HealthPrediction


local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
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

local function getEnemyMinionsWithinDistanceOfLocation(location, distance)
    local EnemyMinions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and not minion.dead and minion.pos:DistanceTo(location) < distance then
            table.insert(EnemyMinions, minion)
        end
    end
    return EnemyMinions
end

local function getAOEMinion(maxRange, abilityRadius) 
    local bestCount = 0
    local bestPosition = nil
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        local count = 0
        if minion and not minion.dead and minion.isEnemy and myHero.pos:DistanceTo(minion.pos) < maxRange then 
            local count = #getEnemyMinionsWithinDistanceOfLocation(minion.pos, abilityRadius)
            if count > bestCount then
                bestCount = count
                bestPosition = minion.pos
            end
        end
    end
    return bestPosition, bestCount
end

local function getEnemyHeroesWithinDistance(distance)
    return getEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
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

class "Nilah"
        
function Nilah:__init()	     
    print("Zgjfjfl_Nilah Loaded")
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)    
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 665, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 550 }
    self.rSpell = { Range = 425 }  
end

function Nilah:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgNilah", name = "Zgjfjfl Nilah"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "WRange", name = "Use W when enemies within X range", min=0, max = 1000, value = 500})
        self.Menu.Combo:MenuElement({id = "WCount", name = "Use W when X enemies within range", min = 0, max = 5, value=2})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "Eammo", name = "[E] Save 1 stock for Kills or Flee or Manual", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ETHP", name = "Use E when target HP %", value =  50, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RCount", name = "Use R when can hit >= X enemies", min = 0, max = 5, value=2})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 30, min = 0, max = 100})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "QT", name = "[Q] Turret", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 30, min = 0, max = 100})
			
    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function Nilah:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

    self:KillSteal()
    
end

function Nilah:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
        local numEnemies = getEnemyHeroesWithinDistance(self.Menu.Combo.WRange:Value())
        if  #numEnemies >= self.Menu.Combo.WCount:Value() and isSpellReady(_W) and self.Menu.Combo.W:Value() then
            Control.CastSpell(HK_W)
        end
                
        if self.Menu.Combo.Eammo:Value() then
            if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero:GetSpellData(_E).ammo > 1 and target.health/target.maxHealth <= self.Menu.Combo.ETHP:Value()/100 then
                Control.CastSpell(HK_E, target)
            end
        elseif not self.Menu.Combo.Eammo:Value() then
            if self.Menu.Combo.E:Value() and isSpellReady(_E) and myHero:GetSpellData(_E).ammo > 0 and target.health/target.maxHealth <= self.Menu.Combo.ETHP:Value()/100 then
                Control.CastSpell(HK_E, target)
            end
        end

        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
			        
	    local numEnemies = getEnemyHeroesWithinDistance(self.rSpell.Range)
		if self.Menu.Combo.R:Value() and isSpellReady(_R) and #numEnemies >= self.Menu.Combo.RCount:Value() then
            Control.CastSpell(HK_R)
        end
    end
end


function Nilah:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

    end
end

function Nilah:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end
        for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
            if turret.isEnemy and not turret.dead and not turret.isImmortal then
                   if isSpellReady(_Q) and myHero.pos:DistanceTo(turret.pos) <= self.qSpell.Range and self.Menu.Clear.QT:Value() then 
                       Control.CastSpell(HK_Q, turret.pos)
                   end
            end
        end
end
	
function Nilah:KillSteal()
    
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target then
		
    	if isSpellReady(_Q) and self.Menu.KS.Q:Value() then
			if self:getqDmg(target) > target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
		             castSpellHigh(self.qSpell, HK_Q, target)
			end	
	    end
		if isSpellReady(_E) and self.Menu.KS.E:Value() and not isSpellReady(_Q) then 
			if target.health <= self:geteDmg(target) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				Control.CastSpell(HK_E, target)	
			end	
	    end

	end
end

function Nilah:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 5 * qlvl
    local qadDmg = myHero.totalDamage * (0.1 *qlvl + 0.8 )
    local qDmg = qbaseDmg * (myHero.critChance + 1) + qadDmg * (myHero.critChance + 1)
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
end

function Nilah:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 40 + elvl * 25
    local eadDmg = myHero.bonusDamage * 0.2
    local eDmg = ebaseDmg + eadDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg)
end

function Nilah:Flee()
    local FleeETarget, FleeEDistance = self:getFleeETarget()
    local distance = FleeETarget.pos:DistanceTo(myHero.pos)
    if FleeETarget and FleeEDistance < mousePos:DistanceTo(myHero.pos) and distance <= 550 and isSpellReady(_E) then
        Control.CastSpell(HK_E, FleeETarget)
    end
end

function Nilah:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then

            Draw.Circle(myHero.pos, self.qSpell.Range-65, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end

function Nilah:getFleeETarget()
    local FleeETarget = nil
    local FleeEDistance = math.huge
    
    if self.Menu.Flee.E:Value() then
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and not hero.dead and (hero.isAlly or hero.isEnemy) and not hero.isMe then
                local distance = mousePos:DistanceTo(hero.pos)
                
                if distance < FleeEDistance then
                    FleeEDistance = distance
                    FleeETarget = hero
                end
            end
        end
    end
    
    if self.Menu.Flee.E:Value() then
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and (minion.isAlly or minion.isEnemy or minion.isJungle) and not minion.dead then
                local distance = mousePos:DistanceTo(minion.pos)
                
                if distance < FleeEDistance then
                    FleeEDistance = distance
                    FleeETarget = minion
                end
            end
        end
    end

    return FleeETarget, FleeEDistance
end


function onLoadEvent()
    if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
    end
end


Callback.Add('Load', onLoadEvent)
