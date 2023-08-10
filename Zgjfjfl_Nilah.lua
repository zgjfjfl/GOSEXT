local Heroes ={"Nilah"}

if not table.contains(Heroes, myHero.charName) then return end

require "GGPrediction"

local GameTurret = Game.Turret
local GameTurretCount = Game.TurretCount
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local Orbwalker, TargetSelector, ObjectManager, HealthPrediction, Damage

Callback.Add("Load", function()

    Orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    ObjectManager = _G.SDK.ObjectManager
    HealthPrediction = _G.SDK.HealthPrediction
    Damage = _G.SDK.Damage

    if table.contains(Heroes, myHero.charName) then
        _G[myHero.charName]()
    end

end)


local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function isValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead) then
        return true
    end
    return false
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

local function getEnemyHeroes()
	local EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local Hero = GameHero(i)
		if Hero.isEnemy then
			table.insert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

local function getEnemyHeroesWithinDistanceOfUnit(location, distance)
    local EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isEnemy and not Hero.dead and getDistance(Hero.pos, location) < distance then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyMinionsWithinDistanceOfLocation(location, distance)
    local EnemyMinions = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.isEnemy and not minion.dead and getDistance(minion.pos, location) < distance then
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
        if minion and not minion.dead and minion.isEnemy and getDistance(myHero.pos, minion.pos) < maxRange then 
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
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 600, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 550 }
    self.rSpell = { Range = 400 }  
end

function Nilah:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgNilah", name = "Zgjfjfl Nilah"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "Eammo", name = "[E] Save 1 stock for Kills or Flee or Manual", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ETHP", name = "Use E when target HP %", value =  60, min=5, max = 100, step = 5})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RCount", name = "Use R when can hit >= X enemies", min = 1, max = 5, value=2})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 20, min = 0, max = 100})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
        self.Menu.Auto:MenuElement({id = "W", name = "[W] auto use when enemyattackself", toggle = true, value = false})
        self.Menu.Auto:MenuElement({id = "WHP", name = "when self HP %", value =  50, min=5, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "QR", name = "[Q] lasthit no aarange minion", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "QT", name = "[Q] Turret, Barrack, Nexus", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to LaneClear", value = 30, min = 0, max = 100})
			
    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "E", name = "[E] to mouse near target", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function Nilah:onTickEvent()

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:QBuildings()
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:AutoW()
    self:KillSteal()
    
end

function Nilah:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and getDistance(myHero.pos, target.pos) <= self.eSpell.Range and target.health/target.maxHealth <= self.Menu.Combo.ETHP:Value()/100 then
            if self.Menu.Combo.Eammo:Value() then
                if myHero:GetSpellData(_E).ammo > 1 then
                    Control.CastSpell(HK_E, target)
                end
            else
                if myHero:GetSpellData(_E).ammo > 0 then
                    Control.CastSpell(HK_E, target)
                end
            end
        end
			        
        local numEnemies = getEnemyHeroesWithinDistance(self.rSpell.Range)
        if self.Menu.Combo.R:Value() and isSpellReady(_R) and #numEnemies >= self.Menu.Combo.RCount:Value() then
            Control.CastSpell(HK_R)
        end
    end
end

function Nilah:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= self.qSpell.Range and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
            castSpellHigh(self.qSpell, HK_Q, target)
        end
    end
end

function Nilah:AutoW()
    if self.Menu.Auto.W:Value() and isSpellReady(_W) then
        for i, hero in pairs(getEnemyHeroes()) do
            if hero.alive and hero.visible then
                if hero.activeSpell.target == myHero.handle and myHero.health/myHero.maxHealth <= self.Menu.Auto.WHP:Value()/100 then
                    Control.CastSpell(HK_W)
                end
            end
        end
    end
end

function Nilah:LaneClear()
  if isSpellReady(_Q) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
    if self.Menu.Clear.Q:Value() then
    local target = HealthPrediction:GetJungleTarget()
        if not target then
            target = HealthPrediction:GetLaneClearTarget()
        end
        if target and isValid(target) then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
            end
        end
    end

    if self.Menu.Clear.QR:Value() then
        local minionInRange = ObjectManager:GetEnemyMinions(self.qSpell.Range)
        if next(minionInRange) == nil then end
        for i = 1, #minionInRange do
        local minion = minionInRange[i]
            local AARange = myHero.range + myHero.boundingRadius
            local QDmg = self:getqDmg(minion)
            if getDistance(myHero.pos, minion.pos) <= self.qSpell.Range and getDistance(myHero.pos, minion.pos) > AARange then
                if QDmg >= HealthPrediction:GetPrediction(minion, self.qSpell.Delay) then
                    Control.CastSpell(HK_Q, minion)
                end
            end
        end
    end
  end
end

function Nilah:QBuildings()
  if isSpellReady(_Q) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
    if self.Menu.Clear.QT:Value() then
        local turrets = ObjectManager:GetEnemyTurrets(self.qSpell.Range)
        for i, turret in ipairs(turrets) do
            if turret.isTargetable then
                Control.CastSpell(HK_Q, turret)
            end
        end
        local barracks = ObjectManager:GetEnemyBuildings(self.qSpell.Range+270)
        for i, barrack in ipairs(barracks) do
            if barrack.type == Obj_AI_Barracks then
                Control.CastSpell(HK_Q, barrack)
            end
        end
        local nexus = ObjectManager:GetEnemyBuildings(self.qSpell.Range+380)
        for i, base in ipairs(nexus) do
            if base.type == Obj_AI_Nexus then
                Control.CastSpell(HK_Q, base)
            end
        end
    end
  end
end
	
function Nilah:KillSteal()

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        local Qdmg = self:getqDmg(target)
        local Edmg = self:geteDmg(target)		
        if isSpellReady(_Q) and self.Menu.KS.Q:Value() then
            if Qdmg > target.health and getDistance(myHero.pos, target.pos) <= self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
            end	
        end
        if isSpellReady(_E) and self.Menu.KS.E:Value() and not isSpellReady(_Q) then 
            if target.health <= Edmg and getDistance(myHero.pos, target.pos) <= self.eSpell.Range then
                Control.CastSpell(HK_E, target)	
            end	
        end
    end
end

function Nilah:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 5 * qlvl
    local qadDmg = myHero.totalDamage * (0.075 *qlvl + 0.825 )
    local qDmg = qbaseDmg * (myHero.critChance + 1) + qadDmg * (myHero.critChance + 1)
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
end

function Nilah:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 40 + elvl * 25
    local eadDmg = myHero.bonusDamage * 0.2
    local eDmg = ebaseDmg + eadDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg)
end

function Nilah:Flee()
	if self.Menu.Flee.E:Value() and isSpellReady(_E) then
		local FleeETarget, FleeEDistance = self:getFleeETarget()
		local distance = getDistance(myHero.pos, mousePos)
		if FleeETarget and FleeEDistance < distance then
        		Control.CastSpell(HK_E, FleeETarget)
    		end
	end
end

function Nilah:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then
        Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R)then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

function Nilah:getFleeETarget()
    local FleeETarget = nil
    local FleeEDistance = math.huge
    
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and not hero.dead and (hero.isAlly or hero.isEnemy) and not hero.isMe then
                local distance = getDistance(hero.pos, mousePos)
                local distance2 = getDistance(myHero.pos, hero.pos)
                if distance < FleeEDistance and distance2 <= 550 then
                    FleeEDistance = distance
                    FleeETarget = hero
                end
            end
        end
    
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and (minion.isAlly or minion.isEnemy or minion.isJungle) and not minion.dead then
                local distance = getDistance(minion.pos, mousePos)
                local distance2 = getDistance(myHero.pos, minion.pos)
                if distance < FleeEDistance and distance2 <= 550 then
                    FleeEDistance = distance
                    FleeETarget = minion
                end
            end
        end

    return FleeETarget, FleeEDistance
end

