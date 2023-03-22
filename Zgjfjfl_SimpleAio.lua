
local Heroes ={"Ornn", "JarvanIV", "Poppy", "Shyvana", "Trundle", "Rakan", "Belveth", "Nasus", "Singed", "Udyr", "Galio", "Yorick", "Ivern", "Bard", "Taliyah", "Lissandra", "Sejuani", "KSante", "Skarner", "Maokai", "Gragas"}

if not table.contains(Heroes, myHero.charName) then 
    print('SimpleAio not supported ' .. myHero.charName)
    return 
end

require "GGPrediction"
require "2DGeometry"
require "MapPositionGOS"

local GameTurretCount     = Game.TurretCount
local GameTurret          = Game.Turret
local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion
local TableInsert          = table.insert

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0

Callback.Add("Load", function()

    orbwalker = _G.SDK.Orbwalker

    HealthPrediction = _G.SDK.HealthPrediction

    if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
    end

end)

local function isSpellReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
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
        if Hero.isEnemy and not Hero.dead then
            TableInsert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getAllyHeroes()
    local AllyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isAlly and not Hero.isMe then
            TableInsert(AllyHeroes, Hero)
        end
    end
    return AllyHeroes
end 

local function getEnemyMinionsWithinDistanceOfLocation(location, distance)
    local EnemyMinions = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.isEnemy and not minion.dead and minion.pos:DistanceTo(location) < distance then
            TableInsert(EnemyMinions, minion)
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

local function doesMyChampionHaveBuff(buffName)
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function haveBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

function getBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function getEnemyHeroesWithinDistanceOfUnit(location, distance)
    local EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isEnemy and not Hero.dead and Hero.pos:DistanceTo(location) < distance then
            TableInsert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyHeroesWithinDistance(distance)
    return getEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
end

local function getEnemyCount(range, unit)
	local count = 0
	for i, hero in ipairs(getEnemyHeroes()) do
	local Range = range * range
		if unit ~= hero and getDistanceSqr(unit, hero.pos) < Range and isValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function getMinionCount(range, unit)
	local count = 0
	for i = 1,GameMinionCount() do
	local hero = GameMinion(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and hero.dead == false and getDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function getAllyCount(range, unit)
	local count = 0
	for i, hero in ipairs(getAllyHeroes()) do
	local Range = range * range
		if unit ~= hero and getDistanceSqr(unit, hero.pos) < Range and isValid(hero) then
		count = count + 1
		end
	end
	return count
end


local function isImmobile(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false
end

local function isInvulnerable(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.type == 18 and buff.count > 0 then
			return true
            	end
	end
	return false
end

local vectorCast = {}
local mouseReturnPos = mousePos
local mouseCurrentPos = mousePos
local nextVectorCast = 0
function CastVectorSpell(key, pos1, pos2)
	if nextVectorCast > Game.Timer() then return end
	nextVectorCast = Game.Timer() + 1.5
	orbwalker:SetMovement(false)
	orbwalker:SetAttack(false)
	vectorCast[#vectorCast + 1] = function () 
		mouseReturnPos = mousePos
		mouseCurrentPos = pos1
		Control.SetCursorPos(pos1)
	end
	vectorCast[#vectorCast + 1] = function () 
		Control.KeyDown(key)
	end
	vectorCast[#vectorCast + 1] = function () 
		local deltaMousePos =  mousePos-mouseCurrentPos
		mouseReturnPos = mouseReturnPos + deltaMousePos
		Control.SetCursorPos(pos2)
		mouseCurrentPos = pos2
	end
	vectorCast[#vectorCast + 1] = function ()
		Control.KeyUp(key)
	end
	vectorCast[#vectorCast + 1] = function ()	
		local deltaMousePos =  mousePos -mouseCurrentPos
		mouseReturnPos = mouseReturnPos + deltaMousePos
		Control.SetCursorPos(mouseReturnPos)
	end
	vectorCast[#vectorCast + 1] = function () 
		orbwalker:SetMovement(true)
		orbwalker:SetAttack(true)
	end		
end
------------------------------------

class "Ornn"
        
function Ornn:__init()	     
    print("Zgjfjfl-Ornn Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 800, Speed = 1800, Collision = false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 750, Speed = 1600, Collision = false}

  end

function Ornn:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgOrnn", name = "Zgjfjfl Ornn"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
	self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 0, max = 300, value = 300, step = 10})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function Ornn:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
   
end

function Ornn:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then

        local ecastpos = myHero.pos + (target.pos - myHero.pos):Normalized() * self.eSpell.Range
        local objpos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())
        local lineE = LineSegment(target.pos, objpos)

        if not MapPosition:intersectsWall(lineE) or not isSpellReady(_E) then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 400 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end
        end

        for i = 1, Game.ParticleCount() do
        local particle = Game.Particle(i)
            if particle and particle.name:find("Object") then
                if not MapPosition:intersectsWall(lineE) and self.Menu.Combo.EQ:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and getEnemyCount(300, particle.pos) >= 1 and myHero.pos:DistanceTo(particle.pos) <= self.eSpell.Range then
                    Control.CastSpell(HK_E, particle)
                    lastE = GetTickCount()
                end
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
            lastW = GetTickCount()
        end

        if MapPosition:intersectsWall(myHero.pos, ecastpos) and MapPosition:intersectsWall(lineE) and self.Menu.Combo.EWall:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            Control.CastSpell(HK_E, ecastpos)
            lastE = GetTickCount()
        end
    end
end	

function Ornn:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_W, bestPosition)
                lastW = GetTickCount()
            end
        end
    end
end

function Ornn:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 400 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
        if self.Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            castSpellHigh(self.wSpell, HK_W, target)
            lastW = GetTickCount()
        end
    end
end

function Ornn:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------
class "JarvanIV"
        
function JarvanIV:__init()	     
    print("Zgjfjfl-JarvanIV Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 70, Range = 770, Speed = math.huge, Collision = false}
    self.wSpell = { Range = 600 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 200, Range = 860, Speed = math.huge, Collision = false}
    self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 350, Range = 650, Speed = math.huge, Collision = false}
  end

function JarvanIV:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgJarvanIV", name = "Zgjfjfl JarvanIV"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EQ", name = "[EQ]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "WHp", name = "use W when self HP %", value =  40, min=5, max = 100, step = 5})
        self.Menu.Combo:MenuElement({id = "WCount", name = "or use W when can hit >= X enemies", value=2, min = 1, max = 5})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHp", name = "use R when target HP %", value =  40, min=5, max = 100, step = 5})
        self.Menu.Combo:MenuElement({id = "RCount", name = "or use R when can hit >= X enemies", value=2, min = 1, max = 5})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "EQ", name = "[EQ] to mouse", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "W", name = "[W] slow enemy", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function JarvanIV:onTickEvent()

    if haveBuff(myHero, "JarvanIVCataclysm") and getEnemyCount(self.rSpell.Radius, myHero.pos) == 0 then
        Control.CastSpell(HK_R)
    end

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

function JarvanIV:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -100)
            if self.Menu.Combo.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
                self:CastE(castPos)
                orbwalker:SetMovement(false)
                orbwalker:SetAttack(false)
                DelayAction(function() Control.CastSpell(HK_Q, castPos) end, 0.1)
                orbwalker:SetMovement(true)
                orbwalker:SetAttack(true)
            end
        end
		        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and not isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and ((myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero.health/myHero.maxHealth <= self.Menu.Combo.WHp:Value()/100) or getEnemyCount(self.wSpell.Range, myHero.pos) >= self.Menu.Combo.WCount:Value()) then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end

        if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() and not haveBuff(myHero, "JarvanIVCataclysm") and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and (target.health/target.maxHealth <= self.Menu.Combo.RHp:Value()/100 or getEnemyCount(self.rSpell.Radius, target.pos) >= self.Menu.Combo.RCount:Value()) then
            Control.CastSpell(HK_R, target)
            lastR = GetTickCount()
        end

    end
end	

function JarvanIV:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
                lastQ = GetTickCount()
            end
        end
    end

end

function JarvanIV:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

    end
end

function JarvanIV:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if isSpellReady(_Q) and lastQ + 500 < GetTickCount() and self.Menu.KS.Q:Value() then
            if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end	
        end

        if isSpellReady(_E) and lastE + 250 < GetTickCount() and self.Menu.KS.E:Value() then
            if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                castSpellHigh(self.eSpell, HK_E, target)
                lastE = GetTickCount()
            end	
        end

        if isSpellReady(_R) and lastR + 250 < GetTickCount() and self.Menu.KS.R:Value() and not haveBuff(myHero, "JarvanIVCataclysm") then
            if self:getrDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
                Control.CastSpell(HK_R, target)
                lastR = GetTickCount()
            end	
        end

    end
end

function JarvanIV:CastE(unit)
    if lastE + 250 < GetTickCount() then
        Control.CastSpell(HK_E, unit)
        lastE = GetTickCount()
    end
end

function JarvanIV:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 40 * qlvl + 50
    local qadDmg = myHero.bonusDamage * 1.4
    local qDmg = qbaseDmg + qadDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function JarvanIV:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 40 * elvl + 40
    local eapDmg = myHero.ap * 0.8
    local eDmg = ebaseDmg + eapDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function JarvanIV:getrDmg(target)
    local rlvl = myHero:GetSpellData(_R).level
    local rbaseDmg  = 125 * rlvl + 75
    local radDmg = myHero.bonusDamage * 1.8
    local rDmg = rbaseDmg + radDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg) 
end


function JarvanIV:Flee()
    if self.Menu.Flee.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
        self:CastE(pos)
        orbwalker:SetMovement(false)
        DelayAction(function() Control.CastSpell(HK_Q, pos) end, 0.1)
        orbwalker:SetMovement(true)
    end

    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then
        if isSpellReady(_W) and lastW + 250 < GetTickCount() and self.Menu.Flee.W:Value() then
            if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
                Control.CastSpell(HK_W)
                lastW = GetTickCount()
            end	
        end
    end
end

function JarvanIV:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------

class "Poppy"
        
function Poppy:__init()	     
    print("Zgjfjfl-Poppy Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 430, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 475 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 450, Speed = 2500, Collision = false}
    self.r2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 1200, Speed = 2500, Collision = false}
  end

function Poppy:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgPoppy", name = "Zgjfjfl Poppy"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min =0, max = 400, value = 400})
        self.Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP %", value = 30, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "W", name = "W Setting "})
        self.Menu.W:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.W.WB:MenuElement({id = Hero.charName, name =Hero.charName, value = false})		
                end		
            end,0.2)
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Poppy:onTickEvent()

    if haveBuff(myHero, "PoppyR") then
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if isSpellReady(_W) then
        self:AutoW()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end

end

function Poppy:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
	
        local endPos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())
        if MapPosition:inWall(endPos) and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
            Control.CastSpell(HK_E, target)
            lastE = GetTickCount()
        end
				        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount()and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
		
        if self.Menu.Combo.RF:Value() and isSpellReady(_R) and lastR + 350 < GetTickCount()and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth <= self.Menu.Combo.RFHP:Value()/100 then
            Control.KeyDown(HK_R)
            lastR = GetTickCount()
            if Control.IsKeyDown(HK_R) then
                Control.SetCursorPos(target)
                DelayAction(function() Control.SetCursorPos(mousePos) end, 0.1)
                DelayAction(function() Control.KeyUp(HK_R) end, 0.1)
            end
        end
    end
end	

function Poppy:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function Poppy:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

    end
end

function Poppy:AutoW()

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
    local blockobj = self.Menu.W.WB[target.charName] and self.Menu.W.WB[target.charName]:Value()
        if blockobj and target.pathing.isDashing then
        local vct = Vector(target.pathing.endPos.x, target.pathing.endPos.y, target.pathing.endPos.z)
            if vct:DistanceTo(myHero.pos) < 400 and lastW + 250 < GetTickCount() then
                Control.CastSpell(HK_W)
                lastW = GetTickCount()
            end
        end
    end
end

function Poppy:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.r2Spell.Range)
    if target and isValid(target) then
        if isSpellReady(_R) and lastR + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.r2Spell.Range then
            Control.KeyDown(HK_R)
            lastR = GetTickCount()
            if Control.IsKeyDown(HK_R) then
                Control.SetCursorPos(target)
                DelayAction(function() Control.SetCursorPos(mousePos) end, 1)
                DelayAction(function() Control.KeyUp(HK_R) end, 1)
            end
        end
    end
end

function Poppy:Draw()
   if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.r2Spell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Shyvana"
        
function Shyvana:__init()	     
    print("Zgjfjfl-Shyvana Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 925, Speed = 1600, Collision = false}
    self.e2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.333, Radius = 345, Range = 925, Speed = 1575, Collision = false}
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 160, Range = 850, Speed = 700, Collision = false}
end

function Shyvana:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgShyvana", name = "Zgjfjfl Shyvana"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use on target HP %", value = 50, min=0, max = 100 })
        self.Menu.Combo:MenuElement({id = "RC", name = "[R] Use X enemies in range", value = 1, min = 1, max = 5})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "R", name = "[R] to mouse", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Shyvana:onTickEvent()

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

end

function Shyvana:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < 400 and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount()then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount()then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end

        local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
        if DragonForm then
            if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() then
                castSpellHigh(self.e2Spell, HK_E, target)
                lastE = GetTickCount()
            end
        end

        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 350 < GetTickCount() and (target.health/target.maxHealth <= self.Menu.Combo.RHP:Value() / 100) then
        local numEnemies = getEnemyHeroesWithinDistance(self.rSpell.Range)
            if #numEnemies >= self.Menu.Combo.RC:Value() then
                castSpellHigh(self.rSpell, HK_R, target)
                lastR = GetTickCount()
            end
        end
    end
end	

function Shyvana:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < 400 and self.Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end
        if self.Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_E, bestPosition)
                lastE = GetTickCount()
            end
        end
    end
end

function Shyvana:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then

        local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
        if DragonForm then
            if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() then
                castSpellHigh(self.e2Spell, HK_E, target)
                lastE = GetTickCount()
            end
        end
            
        if self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end

    end
end
function Shyvana:Flee()
    if self.Menu.Flee.W:Value() and isSpellReady(_W) then
        Control.CastSpell(HK_W)
    end
    if self.Menu.Flee.R:Value() and isSpellReady(_R) then
        Control.CastSpell(HK_R, mousePos)
    end
end

function Shyvana:Draw()
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R)then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Trundle"
        
function Trundle:__init()	     
    print("Zgjfjfl-Trundle Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 775, Range = 750, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1000, Speed = math.huge, Collision = false}
    self.rSpell = { Range = 650 }
end

function Trundle:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgTrundle", name = "Zgjfjfl Trundle"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value = 60, min=0, max = 100, step=5})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Trundle:onTickEvent()

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

end

function Trundle:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            Control.CastSpell(HK_W, target)
            lastW = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) > 300 and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
	local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) + 100)
            Control.CastSpell(HK_E, castPos)
            lastE = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 350 < GetTickCount() and (myHero.health/myHero.maxHealth <= self.Menu.Combo.RHP:Value() / 100) then
            Control.CastSpell(HK_R, target)
            lastR = GetTickCount()
        end
    end
end	

function Trundle:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount()then
            Control.CastSpell(HK_W, myHero)
            lastW = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount()then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end
    end

end

function Trundle:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(500)
    if target and isValid(target) then

        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= 300 then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end

    end
end
function Trundle:Flee()   
    if self.Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
        Control.CastSpell(HK_W, mousePos)
        lastW = GetTickCount()
    end
    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if self.Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
	local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) - 100)
            Control.CastSpell(HK_E, castPos)
            lastE = GetTickCount()
        end
    end
end

function Trundle:Draw()   
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Rakan"
        
function Rakan:__init()	     
    print("Zgjfjfl-Rakan Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 600, Speed = 1700, Collision = false}
    self.eSpell = {Range = 700}
end

function Rakan:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgRakan", name = "Zgjfjfl Rakan"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E2", name = "[E2] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R] when enemies>=2 within Wrange", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Flee:MenuElement({id = "E", name = "[E] to Ally", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Rakan:onTickEvent()
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and not hero.dead and hero.isAlly and not hero.isMe and hero.charName == "Xayah" then
            self.eSpell.Rang = 1000
        end
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Rakan:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1500)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero:GetSpellData(_E).name == "RakanE" then
            for i = 1, GameHeroCount() do
                local hero = GameHero(i)
                if hero and not hero.dead and hero.isAlly and not hero.isMe then
                    if myHero.pos:DistanceTo(hero.pos) <= self.eSpell.Range then
                        if isSpellReady(_W) and getEnemyCount(self.wSpell.Range, myHero.pos) == 0 and getEnemyCount(self.wSpell.Range, hero.pos) >= 1 then
                            Control.CastSpell(HK_E, hero)
                            lastE = GetTickCount()
                        elseif getEnemyCount(self.wSpell.Range, myHero.pos) >= 1 and not isSpellReady(_W) then
                            Control.CastSpell(HK_E, hero)
                            lastE = GetTickCount()
                        end
                    end
                end
            end
        end
        if self.Menu.Combo.E2:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero:GetSpellData(_E).name == "RakanERecast" and not isSpellReady(_W) then
            for i = 1, GameHeroCount() do
                local hero = GameHero(i)
                if hero and not hero.dead and hero.isAlly and not hero.isMe then
                    if myHero.pos:DistanceTo(hero.pos) <= self.eSpell.Range then
                        if not haveBuff(hero, "RakanEShield") then
                            Control.CastSpell(HK_E, hero)
                            lastE = GetTickCount()
                        end
                    end
                end
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end

        if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and getEnemyCount(self.wSpell.Range, myHero.pos) >= 2 then
             Control.CastSpell(HK_R)
             lastR = GetTickCount()
        end
    end
end	

function Rakan:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
    end
end
function Rakan:Flee()   
    if self.Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.wSpell.Range
            Control.CastSpell(HK_W, pos)
            lastW = GetTickCount()
    end

    if self.Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and not isSpellReady(_W) then
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and not hero.dead and hero.isAlly and not hero.isMe then
            local distance1 = hero.pos:DistanceTo(myHero.pos)
            local distance2 = mousePos:DistanceTo(hero.pos)
                 if  distance2 < mousePos:DistanceTo(myHero.pos) and distance1 <= self.eSpell.Range then
                    Control.CastSpell(HK_E, hero)
                    lastE = GetTickCount()
                 end
            end
        end
    end
end

function Rakan:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
------------------------------
class "Belveth"
        
function Belveth:__init()	     
    print("Zgjfjfl-Belveth Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 450, Speed = myHero:GetSpellData(_E).speed, Collision =false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 100, Range = 660, Speed = math.huge, Collision = false}
    self.eSpell = {Range = 500}
end

function Belveth:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgBelveth", name = "Zgjfjfl Belveth"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EHP", name = "[E] Use when self HP %", value = 30, min=0, max = 100 })
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Belveth:onTickEvent()
    local castingE = doesMyChampionHaveBuff("BelvethE")
    if castingE then 
        if getEnemyCount(self.eSpell.Range, myHero.pos) == 0 and getMinionCount(self.eSpell.Range, myHero.pos) == 0 and Game.CanUseSpell(_E) == 0 then
            Control.CastSpell(HK_E)
        end
        orbwalker:SetMovement(false)
        orbwalker:SetAttack(false)
    else
        orbwalker:SetMovement(true)
        orbwalker:SetAttack(true)
    end

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

function Belveth:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
    local castingE = doesMyChampionHaveBuff("BelvethE")
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and not castingE then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and not castingE then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and getEnemyCount(self.eSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < self.Menu.Combo.EHP:Value()/100 then
             Control.CastSpell(HK_E)
             lastE = GetTickCount()
        end

    end
end	

function Belveth:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then

        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end
    end
end

function Belveth:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_W, bestPosition)
                lastW = GetTickCount()
            end
        end
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            Control.CastSpell(HK_Q, target)
            lastQ = GetTickCount()
        end
    end
end

function Belveth:Flee()   
    if self.Menu.Flee.Q:Value() and isSpellReady(_Q) then
        Control.CastSpell(HK_Q, mousePos)
    end
end

function Belveth:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then

        if isSpellReady(_E) and lastE + 250 < GetTickCount() and self.Menu.KS.E:Value() then
            if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and not doesMyChampionHaveBuff("BelvethE") then
                Control.CastSpell(HK_E)
                lastE = GetTickCount()
            end	
        end
    end
end

function Belveth:geteDmg(target)
    local missingHP = (1 - (target.health / target.maxHealth))	
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 2 * elvl + 6
    local eadDmg = myHero.totalDamage * 0.06
    local exttimes = math.floor(((myHero.attackSpeed - 1) / 0.333) + 0.5)
    local eDmg = (ebaseDmg + eadDmg) * (1 + missingHP * 3) * (6 + exttimes)
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg) 
end

function Belveth:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
    end

end
-------------------------------
class "Nasus"
        
function Nasus:__init()	     
    print("Zgjfjfl-Nasus Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = { Range = 700 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 650, Speed = math.huge, Collision =false}
end

function Nasus:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgNasus", name = "Zgjfjfl Nasus"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value=30, min=10, max=100})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "EH", name = "E hits x minions", value = 3, min = 1, max = 6})

    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Nasus:onTickEvent()

    local numEnemies = getEnemyHeroesWithinDistance(700)
    if #numEnemies >= 1 and myHero.health/myHero.maxHealth <= self.Menu.Combo.RHP:Value()/100 and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 300 < GetTickCount() then
        Control.CastSpell(HK_R)
        lastR = GetTickCount()
   end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    self:KillSteal()

end

function Nasus:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
             Control.CastSpell(HK_Q)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             Control.CastSpell(HK_W, target)
             lastW = GetTickCount()
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
             castSpellHigh(self.eSpell, HK_E, target)
             lastE = GetTickCount()
        end

    end
end	

function Nasus:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < 300 and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
             Control.CastSpell(HK_Q)
             lastQ = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
             castSpellHigh(self.eSpell, HK_E, target)
             lastE = GetTickCount()
        end
    end
end

function Nasus:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount >= self.Menu.Clear.EH:Value() then 
                Control.CastSpell(HK_E, bestPosition)
                lastE = GetTickCount()
            end
        end
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
            Control.Attack(target)
        end
    end
end

function Nasus:LastHit()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
    
        if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
            Control.Attack(target)
        end
    end
end

function Nasus:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then

        if isSpellReady(_E) and lastE + 350 < GetTickCount() and self.Menu.KS.E:Value() and self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
            Control.CastSpell(HK_E, target)
            lastE = GetTickCount()
        end

        if isSpellReady(_Q) and lastQ + 250 < GetTickCount() and self.Menu.KS.Q:Value() and self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < 300 then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
            Control.Attack(target)
        end	
    end
end 

function Nasus:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 20 * qlvl + 10
    local qDmg = qbaseDmg + getBuffData(myHero, "NasusQStacks").stacks + myHero.totalDamage
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Nasus:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg = 40 * elvl + 15
    local eapDmg = 0.6 * myHero.ap
    local eDmg = ebaseDmg + eapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end



function Nasus:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------

class "Singed"
        
function Singed:__init()	     
    print("Zgjfjfl-Singed Loaded") 
    self:LoadMenu()
	
    Callback.Add("Tick", function() self:onTickEvent() end)
end

function Singed:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSinged", name = "Zgjfjfl Singed"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})

end

function Singed:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end

end

function Singed:Combo()

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        
        local wcastpos = myHero.pos:Extended(target.pos, -400)
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 300 then
            if not MapPosition:inWall(wcastpos) then
                self:CastW(wcastpos)
            end
            DelayAction(function() Control.SetCursorPos(target) end, 0.25)
            DelayAction(function() Control.SetCursorPos(mousePos) end, 0.5)
            Control.CastSpell(HK_E)
            lastE = GetTickCount()
        end
        if self.Menu.Combo.W:Value() and not isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < 1000 then
            self:CastW(target)
        end
    end
end

function Singed:CastW(target)
    if isSpellReady(_W) and lastW +350 < GetTickCount() then
        Control.CastSpell(HK_W, target)
        lastW = GetTickCount()
    end
end
------------------------------
class "Udyr"
        
function Udyr:__init()	     
    print("Zgjfjfl-Udyr Loaded") 
    self:LoadMenu()

    Callback.Add("Tick", function() self:onTickEvent() end)

  end

function Udyr:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgUdyr", name = "Zgjfjfl Udyr"})

    self.Menu:MenuElement({type = MENU, id = "Style", name = "Playstyle Set"})
        self.Menu.Style:MenuElement({id = "MainR", name = "Main R Playstyle", value = true})
        self.Menu.Style:MenuElement({id = "MainQ", name = "Main Q Playstyle", value = false})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Whp", name = "[W] use when X% hp ", value = 50, min = 0, max = 100})
        self.Menu.Combo:MenuElement({id = "W2hp", name = "use AwakenedW when self X% hp ", value = 30, min = 0, max = 100})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Whp", name = "[W] use when self X% hp", value = 30, min = 0, max = 100})
        self.Menu.Clear:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

end

function Udyr:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
        self:JungleClear()
    end

   end

function Udyr:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(800)
    if target and isValid(target) then
    local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
    local hasAwakenedW = doesMyChampionHaveBuff("udyrwrecastready")
    local hasAwakenedE = doesMyChampionHaveBuff("udyrerecastready")
    local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
    local R1 = getBuffData(myHero, "UdyrRActivation")
    local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and not hasAwakenedE and not hasAwakenedR then
            Control.CastSpell(HK_E)
            lastE = GetTickCount()
        end

        if self.Menu.Style.MainR:Value() then
            if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE or hasAwakenedR) and R1.duration < 1.5 and myHero.pos:DistanceTo(target.pos) < 450 then
                Control.CastSpell(HK_R)
                lastR = GetTickCount()
            end
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_R) or not hasAwakenedR) and not hasAwakenedQ and myHero.pos:DistanceTo(target.pos) < 300 then
                Control.CastSpell(HK_Q)
                lastQ = GetTickCount()
            end
        end

        if self.Menu.Style.MainQ:Value() then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE or (hasAwakenedQ and not haspassiveAA)) and myHero.pos:DistanceTo(target.pos) < 300 then
                Control.CastSpell(HK_Q)
                lastQ = GetTickCount()
            end
            if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_Q) or not hasAwakenedQ) and not hasAwakenedR and myHero.pos:DistanceTo(target.pos) < 450 then
                Control.CastSpell(HK_R)
                lastR = GetTickCount()
            end
        end

        if myHero.health/myHero.maxHealth <= self.Menu.Combo.Whp:Value()/100 and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and getEnemyCount(600, myHero.pos) >= 1 then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
        if myHero.health/myHero.maxHealth <= self.Menu.Combo.W2hp:Value()/100 and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and hasAwakenedW and getEnemyCount(600, myHero.pos) >= 1 then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
    end
end	

function Udyr:JungleClear()
    local c = getMinionCount(450, myHero.pos)
    local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
    local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
    local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")
    local R1 = getBuffData(myHero, "UdyrRActivation")
    local target = HealthPrediction:GetJungleTarget()
    if target and not haspassiveAA then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and c == 1 then
            Control.CastSpell(HK_Q)
                if hasAwakenedQ then
                    Control.CastSpell(HK_Q)
                end
        elseif not hasAwakenedR and isSpellReady(_R) and not isSpellReady(_Q) then
                Control.CastSpell(HK_R)
        end
        if self.Menu.Clear.R:Value() and isSpellReady(_R) and c > 1 then
            Control.CastSpell(HK_R)
                if hasAwakenedR and R1.duration < 0.5 then
                    Control.CastSpell(HK_R)
                end
        elseif not hasAwakenedQ and isSpellReady(_Q) and not isSpellReady(_R) then
                Control.CastSpell(HK_Q)
        end
        if myHero.health/myHero.maxHealth <= self.Menu.Clear.Whp:Value()/100 and self.Menu.Clear.W:Value() and isSpellReady(_W) then
            Control.CastSpell(HK_W)
        end
    end
end

------------------------------
class "Galio"
        
function Galio:__init()	     
    print("Zgjfjfl-Galio Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 825, Speed = 1400, Collision =false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 650, Speed = 2300, Collision = false}
    self.wSpell = {Range = 480}
end

function Galio:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgGalio", name = "Zgjfjfl Galio"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
        self.Menu.Auto:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
        self.Menu.Auto:MenuElement({id = "WHP", name = "Auto W self HP%&enemies inwrange", value = 30, min=0, max = 100 })
        self.Menu.Auto:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.Auto.WB:MenuElement({id = Hero.charName, name =Hero.charName, value = false})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Galio:onTickEvent()
     if doesMyChampionHaveBuff("GalioW") then
          orbwalker:SetAttack(false)
     else
          orbwalker:SetAttack(true)
     end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:AutoW()
    self:KillSteal()

end

function Galio:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
            if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local lineE = LineSegment(myHero.pos, pred.CastPosition)
                if not MapPosition:intersectsWall(lineE) then
                    if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                         castSpellHigh(self.eSpell, HK_E, target)
                         lastE = GetTickCount()
                    end
                end
            end

        if self.Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             self:CastW(self.Menu.Combo.Wtime:Value())
        end
    end
end	

function Galio:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end
    end
end

function Galio:AutoW()

        if self.Menu.Auto.W:Value() and getEnemyCount(self.wSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < self.Menu.Auto.WHP:Value()/100 then
             self:CastW(self.Menu.Auto.Wtime:Value())
        end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        local obj = self.Menu.Auto.WB[target.charName] and self.Menu.Auto.WB[target.charName]:Value()
        if obj and target.pathing.isDashing then
        local vct = Vector(target.pathing.endPos.x, target.pathing.endPos.y, target.pathing.endPos.z)
            if vct:DistanceTo(myHero.pos) < self.wSpell.Range then
                self:CastW(self.Menu.Auto.Wtime:Value())
            end
        end
    end
end

function Galio:CastW(time)
    if isSpellReady(_W) and lastW + 2000 < GetTickCount() then
        Control.KeyDown(HK_W)
        lastW = GetTickCount()
        DelayAction(function() Control.KeyUp(HK_W) end, time)
    end
end

function Galio:Flee()   
    if self.Menu.Flee.E:Value() and isSpellReady(_E) then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
            Control.CastSpell(HK_E, pos)
    end
end

function Galio:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and self.Menu.KS.Q:Value() then
            if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end	
        end
    end
end

function Galio:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 35 * qlvl + 35
    local qapDmg = myHero.ap * 0.75
    local qDmg = qbaseDmg + qapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg) 
end


function Galio:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
    end
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(225, 225, 0, 10))
    end

end
------------------------------
class "Yorick"
        
function Yorick:__init()	     
    print("Zgjfjfl-Yorick Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 225, Range = 600, Speed = math.huge, Collision =false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.33, Radius = 80, Range = 1000, Speed = 1800, Collision = false}
    self.rSpell = {Range = 600}
end

function Yorick:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgYorick", name = "Zgjfjfl Yorick"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R1", name = "[R1] ", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "Q2", name = "[Q2] activate Mist Walker", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
	
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
        self.Menu.Auto:MenuElement({id = "W", name = "AutoW on Immobile Target", value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Yorick:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:KillSteal()
    self:AutoW()
end

function Yorick:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1100)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) <= 300 and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
             Control.CastSpell(HK_Q)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
             castSpellHigh(self.eSpell, HK_E, target)
             lastE = GetTickCount()
        end

        if self.Menu.Combo.R1:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "YorickR" and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range then
             Control.CastSpell(HK_R, target)
             lastR = GetTickCount()
        end

    end
end	

function Yorick:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then

        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() then
             castSpellHigh(self.eSpell, HK_E, target)
             lastE = GetTickCount()
        end
    end
end

function Yorick:LaneClear()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
            Control.Attack(target)
        end

        if self.Menu.Clear.Q2:Value() and myHero:GetSpellData(_Q).name == "YorickQ2" then
            Control.CastSpell(HK_Q)
        end

        if self.Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_E, bestPosition)
                lastE = GetTickCount()
            end
        end
    end
end

function Yorick:LastHit()
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
            Control.Attack(target)
        end
    end
end

function Yorick:Flee()
    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then

        if self.Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
                 castSpellHigh(self.wSpell, HK_W, target)
                 lastW = GetTickCount()
            end
         end
    end
end

function Yorick:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then

        if isSpellReady(_Q) and lastQ + 250 < GetTickCount() and self.Menu.KS.Q:Value() then
            if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= 300 then
                Control.CastSpell(HK_Q)
                lastQ = GetTickCount()
                Control.Attack(target)
            end	
        end

        if isSpellReady(_E) and lastE + 450 < GetTickCount() and self.Menu.KS.E:Value() then
            if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                castSpellHigh(self.eSpell, HK_E, target)
                lastE = GetTickCount()
            end	
        end
    end
end

function Yorick:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 25 * qlvl + 5
    local qadDmg = myHero.totalDamage * 0.4
    local qDmg = qbaseDmg + qadDmg + myHero.totalDamage
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Yorick:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 35 * elvl + 35
    local eapDmg = myHero.ap * 0.7
    local eDmg = ebaseDmg + eapDmg
return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function Yorick:AutoW()
    if _G.SDK.Attack:IsActive() then return end
    for i, target in pairs(getEnemyHeroes()) do
        if self.Menu.Auto.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and isInvulnerable(target) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            Control.CastSpell(HK_W, target)
            lastW = GetTickCount()
        end
    end
			
    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then
        if self.Menu.Auto.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and isImmobile(target) then
            if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
                castSpellHigh(self.wSpell, HK_W, target)
                lastW = GetTickCount()
            end
        end
    end
end

function Yorick:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
    end

end
------------------------------
class "Ivern"
        
function Ivern:__init()	     
    print("Zgjfjfl-Ivern Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)

    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1100, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.eSpell = { Range = 750, Radius = 500 }
    self.rSpell = { Range = 800 }
end

function Ivern:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgIvern", name = "Zgjfjfl Ivern"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Eally", name = "E on ally,when enemies inRadius", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Eself", name = "E on self,when enemies inRadius", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R1]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Daisy", name = "Daisy Setting"})
        self.Menu.Daisy:MenuElement({id = "R1", name = "Control 'Daisy' attack target", key = string.byte("T")})
        self.Menu.Daisy:MenuElement({id = "R2", name = "Control 'Daisy' follow self", key = string.byte("Z")})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Ivern:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

    if myHero:GetSpellData(_R).name == "IvernRRecast" then
        self:DaisyControl()
    end

    if (myHero:GetSpellData(_Q).name == "IvernQ" and isSpellReady(_Q)) or (haveBuff(myHero, "ivernqallyjump")) then
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end
end

function Ivern:Combo()

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and myHero:GetSpellData(_Q).name == "IvernQ" and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and myHero:GetSpellData(_R).name == "IvernR" and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
             Control.CastSpell(HK_R, target)
            lastR = GetTickCount()
        end
    end

    if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
        if self.Menu.Combo.Eself:Value() then 
            if getEnemyCount(500, myHero.pos) >= 1 and getAllyCount(500, myHero.pos) == 0 then
                Control.CastSpell(HK_E, myHero)
                lastE = GetTickCount()
            end
        end

        if self.Menu.Combo.Eally:Value() then
            local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.eSpell.Range)
            for i = 1, #allies do
                local ally = allies[i]
                if not ally.isMe then
                    if getEnemyCount(500, ally.pos) >= 1 then
                        Control.CastSpell(HK_E, ally)
                        lastE = GetTickCount()
                    end
                end
            end
        end
    end
end

function Ivern:DaisyControl()

    local target = _G.SDK.TargetSelector:GetTarget(2000)
    if target and isValid(target) then
        if self.Menu.Daisy.R1:Value() then
            Control.CastSpell(HK_R, target)
        end
    end
    if self.Menu.Daisy.R2:Value() then
         Control.CastSpell(HK_R, myHero)
    end
end

function Ivern:Harass()
    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and myHero:GetSpellData(_Q).name == "IvernQ" and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
    end
end

function Ivern:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Bard"
        
function Bard:__init()	     
    print("Zgjfjfl-Bard Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 850, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = { Range = 800 }
end

function Bard:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgBard", name = "Zgjfjfl Bard"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q] Single", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q2", name = "[Q] Stun with minion or enemyteam", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q3", name = "[Q] Stun with wall", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
        self.Menu.Auto:MenuElement({id = "W", name = "[W] Auto", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Whp", name = "[W] auto on ally or self X hp%", value = 30, min = 0, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Bard:onTickEvent()
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    self:AutoW()
end

function Bard:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1500)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        local pred = GGPrediction:SpellPrediction(self.qSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local extendPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -300)
            local lineQ = LineSegment(pred.CastPosition, extendPos)
            if MapPosition:intersectsWall(lineQ) and self.Menu.Combo.Q3:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
                Control.CastSpell(HK_Q, target)
                lastQ = GetTickCount()
            end
        end

        local pred2 = target:GetPrediction(self.qSpell.Speed, self.qSpell.Delay)
        if pred2 == nil then return end
        local d = getDistance(myHero.pos, pred2)
        local targetPos = Vector(myHero.pos):Extended(pred2, self.qSpell.Range+300) 
        if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and self.Menu.Combo.Q2:Value() then 
            for i = 1, GameMinionCount() do
            local minion = GameMinion(i) 
                if minion and minion.isEnemy and not minion.dead then
                local minionPos = Vector(myHero.pos):Extended(Vector(minion.pos), self.qSpell.Range+300)
                    if getDistance(targetPos, minionPos) <= 30 then
                    local d2 = getDistance(myHero.pos, minion.pos)
                        if d2 <= self.qSpell.Range and d <= self.qSpell.Range+300 and d > d2 then 
                            Control.CastSpell(HK_Q, minion)
                            lastQ = GetTickCount()
                        elseif d2 <= self.qSpell.Range+300 and d <= self.qSpell.Range and d < d2 then
                            Control.CastSpell(HK_Q, pred2)
                            lastQ = GetTickCount()
                        end
                    end
                end 
            end
            for i, Enemy in pairs(getEnemyHeroes()) do
                if Enemy and Enemy ~= target then 
                    local EnemyPos = Vector(myHero.pos):Extended(Vector(Enemy.pos), self.qSpell.Range+300)
                    if getDistance(targetPos, EnemyPos) <= 30 then
                    local d3 = getDistance(myHero.pos, Enemy.pos)
                        if d3 <= self.qSpell.Range and d <= self.qSpell.Range+300 and d > d3 then 
                            Control.CastSpell(HK_Q, Enemy)
                            lastQ = GetTickCount()
                        elseif d3 <= self.qSpell.Range+300 and d <= self.qSpell.Range and d < d3 then
                            Control.CastSpell(HK_Q, pred2)
                            lastQ = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end

function Bard:AutoW()
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and not hero.dead and hero.isAlly then
            if getDistance(myHero.pos, hero.pos) <= self.wSpell.Range and self.Menu.Auto.W:Value() and hero.health/hero.maxHealth <= self.Menu.Auto.Whp:Value()/100 and isSpellReady(_W) and lastW + 350 < GetTickCount() then
                Control.CastSpell(HK_W, hero)
                lastW = GetTickCount()  
            end
        end
    end
end

function Bard:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end

------------------------------
class "Taliyah"
        
function Taliyah:__init()	     
    print("Zgjfjfl-Taliyah Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = myHero:GetSpellData(_Q).speed, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 225, Range = 900, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1700, Collision = false}
end

function Taliyah:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgTaliyah", name = "Zgjfjfl Taliyah"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Wpush", name = "[W] push range", value = 400, min = 100, max = 600, step = 50})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Erange", name = "[E] cast range", value = 950, min = 100, max = 950, step = 50})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

local NextTick = Game.Timer()
function Taliyah:onTickEvent()
    local currentTime = Game.Timer()
    if NextTick > currentTime then return end	
    if #vectorCast > 0 then
        vectorCast[1]()
        table.remove(vectorCast, 1)
        return
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
end

function Taliyah:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.Erange:Value() and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
             Control.CastSpell(HK_E, target)
             lastE = GetTickCount()
        end

        local pred = GGPrediction:SpellPrediction(self.wSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local endPos1 = pred.CastPosition + (myHero.pos - pred.CastPosition):Normalized() * 225
            local endPos2 = pred.CastPosition + (pred.CastPosition - myHero.pos):Normalized() * 225
            local d = myHero.pos:DistanceTo(pred.CastPosition)
            if self.Menu.Combo.W:Value() and isSpellReady(_W) then
                if d < self.wSpell.Range and d > self.Menu.Combo.Wpush:Value() then
                    CastVectorSpell(HK_W, target.pos, endPos1)
                elseif d <= self.Menu.Combo.Wpush:Value() then
                    CastVectorSpell(HK_W, target.pos, endPos2)
                end
            end
        end
    end
end

function Taliyah:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end
    end
end

function Taliyah:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end

------------------------------
class "Lissandra"
        
function Lissandra:__init()	     
    print("Zgjfjfl-Lissandra Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 725, Speed = 2200, Collision = false}
    self.wSpell = { Range = 450 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 125, Range = 1050, Speed = 1200, Collision = false}
    self.rSpell = { Range = 550 }
end

function Lissandra:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgLissandra", name = "Zgjfjfl Lissandra"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q2", name = "[Q] Extended", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E1", name = "[E1]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R] self", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Rself", name = "[R] use onself X enemies inrange", value = 3, min = 0, max = 5, step = 1})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Q2", name = "[Q] Extended", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Auto", name = "Auto setting"})
        self.Menu.Auto:MenuElement({id = "Q", name = "Auto Harass With Extended Q", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Qmana", name = "Q Mana Manager(%)", value = 50, min = 0, max = 100, step = 5})
        self.Menu.Auto:MenuElement({id = "R", name = "Auto R self", toggle = true, value = true})
        self.Menu.Auto:MenuElement({id = "Rhp", name = "AutoR self X hp(%)&enemy inrange", value = 30, min = 0, max = 100, step = 5})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Lissandra:onTickEvent()
    if doesMyChampionHaveBuff("LissandraRSelf") then
        orbwalker:SetMovement(false)
        orbwalker:SetAttack(false)
    else
        orbwalker:SetMovement(true)
        orbwalker:SetAttack(true)
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    self:AutoQ()
    self:AutoR()
end

function Lissandra:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
        if self.Menu.Combo.Q2:Value() then
            self:CastQ2(target)
        end

        local E2ready = doesMyChampionHaveBuff("LissandraE")
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and lastE + 350 < GetTickCount() and not E2ready and self.Menu.Combo.E1:Value() and isSpellReady(_E) then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end
    end
    if getEnemyCount(self.wSpell.Range, myHero.pos) >= 1 and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
        Control.CastSpell(HK_W)
        lastW = GetTickCount()
    end
    if getEnemyCount(self.rSpell.Range, myHero.pos) >= self.Menu.Combo.Rself:Value() and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
        Control.CastSpell(HK_R, myHero)
        lastR = GetTickCount()
    end
end

function Lissandra:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
        if self.Menu.Harass.Q2:Value() then
            self:CastQ2(target)
        end
    end
end

function Lissandra:AutoQ()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if self.Menu.Auto.Q:Value() and myHero.mana/myHero.maxMana >= self.Menu.Auto.Qmana:Value()/100 then
            self:CastQ2(target)
        end
    end
end

function Lissandra:AutoR()
    if getEnemyCount(self.rSpell.Range, myHero.pos) >= 1 and self.Menu.Auto.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount()and myHero.health/myHero.maxHealth <= self.Menu.Auto.Rhp:Value()/100 then
        Control.CastSpell(HK_R, myHero)
        lastR = GetTickCount()
    end
end

function Lissandra:CastQ2(target) 
    local pred = target:GetPrediction(self.qSpell.Speed, self.qSpell.Delay)
    if pred == nil then return end
    local targetPos = Vector(myHero.pos):Extended(pred, 825)
    local d = getDistance(myHero.pos, pred)
    if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and d < 825 then
        for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
            if minion and minion.isEnemy and not minion.dead and getDistance(myHero.pos, minion.pos) <= 725 then
            local minionPos = Vector(myHero.pos):Extended(Vector(minion.pos), 825)
                if d > getDistance(myHero.pos, minion.pos) and getDistance(targetPos, minionPos) <= 45 then
                    Control.CastSpell(HK_Q, minion)
                    lastQ = GetTickCount()
                end
            end
        end
        for i, Enemy in pairs(getEnemyHeroes()) do
            if Enemy and Enemy ~= target and getDistance(myHero.pos, Enemy.pos) <= 725 then
            local EnemyPos = Vector(myHero.pos):Extended(Vector(Enemy.pos), 825)
                if d > getDistance(myHero.pos, Enemy.pos) and getDistance(targetPos, EnemyPos) <= 45 then 
                    Control.CastSpell(HK_Q, Enemy)
                    lastQ = GetTickCount()
                end 
            end 
        end 
    end 
end

function Lissandra:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Sejuani"
        
function Sejuani:__init()	     
    print("Zgjfjfl-Sejuani Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 650, Speed = 1000, Collision = false}
    self.wSpell = { Range = 600 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1300, Speed = 1600, Collision = false}
    self.eSpell = { Range = 600 }
end

function Sejuani:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSejuani", name = "Zgjfjfl Sejuani"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Sejuani:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
end

function Sejuani:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 1000 < GetTickCount() then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
             Control.CastSpell(HK_E)
             lastE = GetTickCount()
        end
    end
end

function Sejuani:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 1000 < GetTickCount() then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end
    end
end

function Sejuani:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and isSpellReady(_R) and lastR + 350 < GetTickCount() then
             castSpellHigh(self.rSpell, HK_R, target)
             lastR = GetTickCount()
        end
    end
end

function Sejuani:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "KSante"
        
function KSante:__init()	     
    print("Zgjfjfl-KSante Loaded")
    self:LoadMenu()
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 75, Range = 450, Speed = math.huge, Collision = false}
    self.q3Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 70, Range = 800, Speed = 1600, Collision = false}
    self.wSpell = { Range = 450 }
    self.e1Spell = { Range = 250 }
    self.e2Spell = { Range = 400 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 350, Speed = 2000, Collision = false}
end

function KSante:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgKSante", name = "Zgjfjfl KSante"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W1", name = "[W] Normal W", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "WTime1", name = "Normal W Channel time(s)", value = 0.7, min = 0.1, max= 1, step = 0.1})
        self.Menu.Combo:MenuElement({id = "W2", name = "[W] AllOut W", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "WTime2", name = "AllOut W Channel time(s)", value = 0.7, min = 0.1, max= 1, step = 0.1})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EA", name = "use E close to enemy AApassive", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ET", name = "use E close to enemy useQ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EM", name = "use E allyminion close to enemy", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EH", name = "use E allyhero close to enemy", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RT", name = "[R] enemy close to allyturret (not near wall)", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Manual R when enemy near wall ", key = string.byte("T")})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear1", name = "Lane Clear"})
        self.Menu.Clear1:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear1:MenuElement({id = "QCount", name = "hit >=x minions", value = 2, min = 1, max = 6})

    self.Menu:MenuElement({type = MENU, id = "Clear2", name = "Jungle Clear"})
        self.Menu.Clear2:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
        self.Menu.LastHit:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = true})
end

function KSante:onTickEvent()
    local myHerobounsHealth = math.min(math.floor(myHero.maxHealth - (610 + 108 * (myHero.levelData.lvl - 1) * (0.7025 + 0.0175 * (myHero.levelData.lvl - 1)))), 1800)
    --print(myHerobounsHealth)
    local time = string.format("%.2f", 1/9000 * myHerobounsHealth)
    --print(time)
    self.q1Spell.Delay = 0.45 - time
    self.q3Spell.Delay = 0.45 - time
    if doesMyChampionHaveBuff("KSanteQ3") then
        self.qSpell = self.q3Spell
    else
        self.qSpell = self.q1Spell
    end
    --print(self.qSpell.Delay)
    if haveBuff(myHero, "KSanteW") or haveBuff(myHero, "KSanteW_AllOut") then
        orbwalker:SetMovement(false)
        orbwalker:SetAttack(false)
    else
        orbwalker:SetMovement(true)
        orbwalker:SetAttack(true)
    end
    if doesMyChampionHaveBuff("KSanteRTransform") then
        self.eSpell = self.e2Spell
    else
        self.eSpell = self.e1Spell
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
        self:JungleClear()
        self:LastHit()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
end

function KSante:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range + self.eSpell.Range)
    if target and isValid(target) then
      if not haveBuff(target, "KSantePMark") or (haveBuff(target, "KSantePMark") and myHero:GetSpellData(_Q).name == "KSanteQ3") then
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and isSpellReady(_Q) then
            if self.Menu.Combo.EH:Value() then
                local allies = _G.SDK.ObjectManager:GetAllyHeroes(550)
                for i, ally in ipairs(allies) do
                    if getEnemyCount(self.qSpell.Range, myHero.pos) == 0 and getEnemyCount(self.qSpell.Range, ally.pos) >= 1 then
                        Control.CastSpell(HK_E, ally)
                        lastE = GetTickCount()
                    end
                end
            end
            if self.Menu.Combo.ET:Value() then
                if myHero.pos:DistanceTo(target.pos) > self.qSpell.Range and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range + self.eSpell.Range then
                    Control.CastSpell(HK_E, target)
                    lastE = GetTickCount()
                end
            end
            if self.Menu.Combo.EM:Value() then
                local minions = _G.SDK.ObjectManager:GetAllyMinions(550)
                for i, minion in ipairs(minions) do
                    if getEnemyCount(self.qSpell.Range, myHero.pos) == 0 and getEnemyCount(self.qSpell.Range, minion.pos) >= 1 then
                        Control.CastSpell(HK_E, minion)
                        lastE = GetTickCount()
                    end
                end
            end
        end

        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and not isSpellReady(_Q) then
            if doesMyChampionHaveBuff("KSanteRTransform") and self.Menu.Combo.W2:Value() then
                 self:CastW(target,self.Menu.Combo.WTime2:Value())
            elseif not doesMyChampionHaveBuff("KSanteRTransform") and self.Menu.Combo.W1:Value() then
                 self:CastW(target,self.Menu.Combo.WTime1:Value())
            end
        end

        if self.Menu.Combo.RT:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
            local turrets = _G.SDK.ObjectManager:GetAllyTurrets(2000)
            for i, turret in ipairs(turrets) do
                local Pos = target.pos:Extended(myHero.pos, -400)
                if turret.pos:DistanceTo(Pos) < 800 and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and turret.pos:DistanceTo(Pos) < turret.pos:DistanceTo(target.pos) then
                    Control.CastSpell(HK_R, target)
                    lastR = GetTickCount()
                end
            end
        end
      elseif haveBuff(target, "KSantePMark") then
          local AARange = myHero.range + myHero.boundingRadius + target.boundingRadius + 25
          if myHero.pos:DistanceTo(target.pos) > AARange and myHero.pos:DistanceTo(target.pos) <= AARange + self.eSpell.Range then
              if self.Menu.Combo.EA:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
                  Control.CastSpell(HK_E, target)
                  lastE = GetTickCount()
              end
          end
      end
    end
end

function KSante:Harass()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end
    end
end

function KSante:CastW(target, time)
    if isSpellReady(_W) and lastW + 1000 < GetTickCount() then
        Control.KeyDown(HK_W)
        lastW = GetTickCount() 
        if Control.IsKeyDown(HK_W) then
            Control.SetCursorPos(target)
            DelayAction(function() Control.KeyUp(HK_W) end, time)
            DelayAction(function() Control.SetCursorPos(mousePos) end, time)
        end
    end
end

function KSante:RSemiManual()
    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target and isValid(target) then
        local Pos = target.pos:Extended(myHero.pos, -350)
        if MapPosition:intersectsWall(target.pos, Pos) and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
             Control.CastSpell(HK_R, target)
             lastR = GetTickCount()
        end
    end
end

function KSante:LaneClear()

    if _G.SDK.Attack:IsActive() then return end

    local target = HealthPrediction:GetLaneClearTarget()
    if target and isValid(target) then
        if self.Menu.Clear1.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount >= self.Menu.Clear1.QCount:Value() then 
                Control.CastSpell(HK_Q, bestPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function KSante:JungleClear()

    if _G.SDK.Attack:IsActive() then return end

    local target = HealthPrediction:GetJungleTarget()
    if target and isValid(target) then
        if self.Menu.Clear2.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_Q, bestPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function KSante:LastHit()
    local minionInRange = _G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range)
    if next(minionInRange) == nil then return end
	
    for i = 1, #minionInRange do
        local minion = minionInRange[i]
        local AArange = myHero.range + myHero.boundingRadius
        if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(minion.pos) < self.qSpell.Range and  myHero.pos:DistanceTo(minion.pos) > AArange then
            if self:getqDmg(minion) >= minion.health and not minion.dead then
                Control.CastSpell(HK_Q, minion)
                lastQ = GetTickCount()
            end
        end
    end
end

function KSante:getqDmg(unit)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 25 * qlvl + 25
    local qadDmg = myHero.totalDamage * 0.4
    local qextDmg = myHero.bonusArmor * 0.3 + myHero.bonusMagicResist * 0.3
    local qDmg = qbaseDmg + qadDmg + qextDmg
return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function KSante:Draw()
    if doesMyChampionHaveBuff("KSanteQ3") then
        self.qSpell = self.q3Spell
    else
        self.qSpell = self.q1Spell
    end
    if self.Menu.Draw.Q:Value() then
            Draw.Circle(myHero.pos, self.qSpell.Range, 0.5, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Skarner"
        
function Skarner:__init()	     
    print("Zgjfjfl-Skarner Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = { Range = 350 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1500, Speed = 1000, Collision = false}
end

function Skarner:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSkarner", name = "Zgjfjfl Skarner"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Skarner:onTickEvent()
    if haveBuff(myHero, "skarnerimpalebuff") then
        orbwalker:SetAttack(false)
    else
        orbwalker:SetAttack(true)
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
end

function Skarner:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end
    end
    -- for i, enemy in pairs(getEnemyHeroes()) do
        -- if enemy and isValid(enemy) and getBuffData(enemy, "skarnerpassivebuff").duration > 0.5 then
            -- _G.SDK.Orbwalker.ForceTarget = enemy
        -- else
            -- _G.SDK.Orbwalker.ForceTarget = nil
        -- end
    -- end
end

function Skarner:LaneClear()
    if _G.SDK.Attack:IsActive() then return end
    local target = HealthPrediction:GetJungleTarget()
    if not target then
        target = HealthPrediction:GetLaneClearTarget()
    end
    if target and isValid(target) then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            Control.CastSpell(HK_Q)
            lastQ = GetTickCount()
        end

        if self.Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
            if bestCount > 0 then 
                Control.CastSpell(HK_E, bestPosition)
                lastE = GetTickCount()
            end
        end
    end
end

function Skarner:Draw()
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
end

------------------------------
class "Maokai"
        
function Maokai:__init()	     
    print("Zgjfjfl-Maokai Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.38, Radius = 70, Range = 600, Speed = 1600, Collision = false}
    self.wSpell = { Range = 525 }
    self.eSpell = { Range = 1100 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 600, Range = 3000, Speed = myHero:GetSpellData(_R).speed, Collision = false}
     Qtoward = nil
end

function Maokai:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgMaokai", name = "Zgjfjfl Maokai"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "InsecQ", name = "InsecQ to ally", value = false, key = string.byte("T"), toggle = true})
        self.Menu.Combo:MenuElement({id = "InsecRange", name = "allies in x range use insecQ", value = 1500, min = 500, max = 3000, step = 100 })
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Rcount", name = "R hit x enemies", value = 2, min = 1, max = 5 })
        self.Menu.Combo:MenuElement({id = "Rrange", name = "R max range", value = 2000, min = 500, max = 3000, step = 100 })

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = false})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "InsecQ", name = "InsecQ", toggle = true, value = true})
end

function Maokai:onTickEvent()
    if self.Menu.Combo.InsecQ:Value() then
        local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.Menu.Combo.InsecRange:Value())
        for i, ally in ipairs(allies) do
            if not ally.isMe then
                Qtoward = ally.pos
            end
        end
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
end

function Maokai:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.Menu.Combo.Rrange:Value())
    if target and isValid(target) then
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and not isSpellReady(_W) then
            if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and ((not self.Menu.Combo.InsecQ:Value()) or (self.Menu.Combo.InsecQ:Value() and Qtoward == nil)) then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end

            if self.Menu.Combo.InsecQ:Value() and Qtoward ~= nil then
                local Pos =  target.pos + (target.pos - Qtoward):Normalized() * 250
                if MapPosition:inWall(Pos) then
                    castSpellHigh(self.qSpell, HK_Q, target)
                    lastQ = GetTickCount()
                else
                    if myHero.pos:DistanceTo(Pos) < 100 then
                        castSpellHigh(self.qSpell, HK_Q, target)
                        lastQ = GetTickCount()
                    end
                end
            end
        end

        if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            Control.CastSpell(HK_W, target)
            lastW = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
            Control.CastSpell(HK_E, target)
            lastE = GetTickCount()
        end

        if isSpellReady(_R) and lastR + 600 < GetTickCount() and self.Menu.Combo.R:Value() then
            if getEnemyCount(self.rSpell.Radius, target.pos) >= self.Menu.Combo.Rcount:Value() then
                castSpellHigh(self.rSpell, HK_R, target)
                lastR = GetTickCount()
            end
        end
    end
end

function Maokai:Harass()

    if _G.SDK.Attack:IsActive() then return end
    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
             Control.CastSpell(HK_E, target)
             lastE = GetTickCount()
        end
    end
end

function Maokai:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.Menu.Combo.Rrange:Value(), 1, Draw.Color(255, 225, 255, 10))
    end

    if self.Menu.Draw.InsecQ:Value() then
        if self.Menu.Combo.InsecQ:Value() then
            Draw.Text("InsecQ:ON", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 000, 255, 000))
        else
            Draw.Text("InsecQ:OFF", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 255, 000, 000))
        end
    end
end

------------------------------
class "Gragas"
        
function Gragas:__init()	     
    print("Zgjfjfl-Gragas Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 850, Speed = 1000, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 90, Range = 800, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 1000, Speed = math.huge, Collision = false}
end

function Gragas:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgGragas", name = "Zgjfjfl Gragas"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Insec", name = "InsecR Setting"})
        self.Menu.Insec:MenuElement({id = "R1", name = "Semi-Manual InsecR Target to Self", key = string.byte("T")})
        self.Menu.Insec:MenuElement({id = "R2", name = "Auto InsecR on Immobile Target", value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        self.Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Gragas:onTickEvent()

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
        self:JungleClear()
    end

    if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQToggle" then
        self:CastQ2()
    end

    if self.Menu.Insec.R1:Value() then
        self:InsecR()
    end

    if self.Menu.Insec.R2:Value() then
        self:AutoR()
    end

    self:KillSteal()
end

function Gragas:Combo()

    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and not isSpellReady(_E) then
            if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end

    end
end

function Gragas:Harass()

    if _G.SDK.Attack:IsActive() then return end
    local target = _G.SDK.TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
        if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and self.Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end
    end
end

function Gragas:InsecR()
    local target = _G.SDK.TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        local pred = GGPrediction:SpellPrediction(self.rSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -150)
            if not MapPosition:intersectsWall(myHero.pos, target.pos) and isSpellReady(_R) and lastR + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range - 150 then
                Control.CastSpell(HK_R, castPos)
                lastR = GetTickCount()
            end
        end
    end
end

function Gragas:AutoR()
    local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(self.rSpell.Range - 150)
    for i, hero in ipairs(heroes) do
        if not MapPosition:intersectsWall(myHero.pos, hero.pos) and isSpellReady(_R) and lastR + 350 < GetTickCount() and isImmobile(hero) then
            Control.CastSpell(HK_R, Vector(hero.pos):Extended(Vector(myHero.pos), -150))
            lastR = GetTickCount()
        end
    end
end

function Gragas:JungleClear()
    if _G.SDK.Attack:IsActive() then return end
    local target = HealthPrediction:GetJungleTarget()
    if target and isValid(target) then
        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            Control.CastSpell(HK_Q, target)
            lastQ = GetTickCount()
        end
        if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQToggle" and getBuffData(myHero, "GragasQ").duration < 2 then
            Control.CastSpell(HK_Q)
        end
        if self.Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            Control.CastSpell(HK_W)
            lastW = GetTickCount()
        end
        if self.Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
            Control.CastSpell(HK_E, target)
            lastE = GetTickCount()
        end
    end
end

function Gragas:CastQ2()

    for i = 1, Game.ParticleCount() do
    local particle = Game.Particle(i)
        if particle and particle.name:find("_Q_Ally") and getEnemyCount(300, particle.pos) >= 1 then
            Control.CastSpell(HK_Q)
        end
    end
end

function Gragas:KillSteal()
    if _G.SDK.Attack:IsActive() then return end

    local target = _G.SDK.TargetSelector:GetTarget(self.rSpell.Range)
    if target and isValid(target) then

        if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and self.Menu.KS.Q:Value() then
            if self:getQDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end	
        end

        if isSpellReady(_E) and lastE + 250 < GetTickCount() and self.Menu.KS.E:Value() then
            if self:getEDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
                castSpellHigh(self.eSpell, HK_E, target)
                lastE = GetTickCount()
            end	
        end

        if isSpellReady(_R) and lastR + 350 < GetTickCount() and self.Menu.KS.R:Value() then
            if self:getRDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
                castSpellHigh(self.rSpell, HK_R, target)
                lastR = GetTickCount()
            end	
        end
    end
end

function Gragas:getQDmg(target)	
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 40 * qlvl + 40
    local qapDmg = myHero.ap * 0.8
    local qDmg = qbaseDmg + qapDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg)
end

function Gragas:getEDmg(target)	
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 35 * elvl + 45
    local eapDmg = myHero.ap * 0.6
    local eDmg = ebaseDmg + eapDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg)
end

function Gragas:getRDmg(target)	
    local rlvl = myHero:GetSpellData(_R).level
    local rbaseDmg  = 100 * rlvl + 100
    local rapDmg = myHero.ap * 0.8
    local rDmg = rbaseDmg + rapDmg
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg)
end


function Gragas:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
        Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
end
