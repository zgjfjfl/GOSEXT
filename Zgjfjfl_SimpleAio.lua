local Heroes ={"Ornn", "JarvanIV", "Poppy", "Shyvana", "Trundle", "Rakan", "Belveth", "Nasus", "Singed", "Udyr", "Galio", "Yorick", "Ivern", "Bard", "Taliyah", "Lissandra", "Sejuani", "KSante", "Skarner", "Maokai", "Gragas", "Milio", "AurelionSol", "Heimerdinger", "Briar"}

if not table.contains(Heroes, myHero.charName) then 
    print('SimpleAio not supported ' .. myHero.charName)
    return 
end

require "GGPrediction"
require "2DGeometry"
require "MapPositionGOS"

local GameParticleCount = Game.ParticleCount
local GameParticle = Game.Particle
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local TableInsert = table.insert
local TableRemove = table.remove

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0

local Orbwalker, TargetSelector, ObjectManager, HealthPrediction, Attack, Damage, Spell, Data

Callback.Add("Load", function()

    Orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    ObjectManager = _G.SDK.ObjectManager
    HealthPrediction = _G.SDK.HealthPrediction
    Attack = _G.SDK.Attack
    Damage = _G.SDK.Damage
    Spell = _G.SDK.Spell
    Data = _G.SDK.Data

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
        if Hero.isAlly then
            TableInsert(AllyHeroes, Hero)
        end
    end
    return AllyHeroes
end

local function getEnemyTurrets()
    local EnemyTurrets = {}
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.isEnemy then
            TableInsert(EnemyTurrets, turret)
        end
    end
    return EnemyTurrets
end

local function isUnderTurret(unit)
    for i, turret in ipairs(getEnemyTurrets()) do
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if not turret.dead then 
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
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
    for i = 1, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function haveBuff(unit, buffName)
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

local function getBuffData(unit, buffname)
    for i = 1, unit.buffCount do
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
        if getDistanceSqr(unit, hero.pos) < Range and isValid(hero) then
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
        if getDistanceSqr(unit, hero.pos) < Range and isValid(hero) then
            count = count + 1
        end
    end
    return count
end

local function isImmobile(unit)
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35) and buff.count > 0 then
            return true
        end
    end
    return false
end

local function isInvulnerable(unit)
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.type == 18 and buff.count > 0 then
            return true
        end
    end
    return false
end

local function recalling()
    for i, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

local function isInRange(v1, v2, range)
    v1 = v1.pos or v1
    v2 = v2.pos or v2
    local dx = v1.x - v2.x
    local dz = (v1.z or v1.y) - (v2.z or v2.y)
    if dx * dx + dz * dz <= range * range then
        return true
    end
    return false
end

local function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 90 then 
        return true  
    end
    return false
end

local function FindFurthestTargetFromMe(targets)	
	local furthestTarget = targets[1]
	local furthestDist = 0
	for _, target in pairs(targets) do
		local dist = myHero.pos:DistanceTo(target.pos)
		if(dist >= furthestDist) then
			furthestTarget = target
			furthestDist = dist
		end
	end
	
	return furthestTarget
end

local function CalculateBoundingBoxAvg(targets, predSpeed, predDelay)
	local highestX, lowestX, highestZ, lowestZ = 0, math.huge, 0, math.huge
	local avg = {x = 0, y = 0, z = 0}
	for k, v in pairs(targets) do
		local vPos = v.pos
		if(predDelay) then
			if(predDelay > 0) then
				vPos = v:GetPrediction(predSpeed, predDelay)
			end
		end
		
		if(vPos.x >= highestX) then
			highestX = vPos.x
		end
		
		if(vPos.z >= highestZ) then
			highestZ = vPos.z
		end
		
		if(vPos.x < lowestX) then
			lowestX = vPos.x
		end
		
		if(vPos.z < lowestZ) then
			lowestZ = vPos.z
		end
	end
	
	local vec1 = Vector(highestX, myHero.pos.y, highestZ)
	local vec2 = Vector(highestX, myHero.pos.y, lowestZ)
	local vec3 = Vector(lowestX, myHero.pos.y, highestZ)
	local vec4 = Vector(lowestX, myHero.pos.y, lowestZ)
	
	avg = (vec1 + vec2 + vec3 + vec4) /4
	
	return avg
end

local function CalculateBestCirclePosition(targets, radius, edgeDetect, spellRange, spellSpeed, spellDelay)
	local avgCastPos = CalculateBoundingBoxAvg(targets, spellSpeed, spellDelay)
	local newCluster = {}
	local distantEnemies = {}

	for _, enemy in pairs(targets) do
		if(enemy.pos:DistanceTo(avgCastPos) > radius) then
			table.insert(distantEnemies, enemy)
		else
			table.insert(newCluster, enemy)
		end
	end
	
	if(#distantEnemies > 0) then
		local closestDistantEnemy = nil
		local closestDist = 10000
		for _, distantEnemy in pairs(distantEnemies) do
			local dist = distantEnemy.pos:DistanceTo(avgCastPos)
			if( dist < closestDist ) then
				closestDistantEnemy = distantEnemy
				closestDist = dist
			end
		end
		if(closestDistantEnemy ~= nil) then
			table.insert(newCluster, closestDistantEnemy)
		end
		
		--Recursion, we are discarding the furthest target and recalculating the best position
		if(#newCluster ~= #targets) then
			return CalculateBestCirclePosition(newCluster, radius)
		end
	end
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > spellRange then

		local checkPos = myHero.pos:Extended(avgCastPos, spellRange)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, spellRange)
		end
		
		local hitAllCheck = true
		for _, v in pairs(newCluster) do
			if(v:GetPrediction(math.huge, 0.25):DistanceTo(checkPos) >= radius + 5) then -- the +5 is to fix a precision issue
				hitAllCheck = false
			end
		end
		
		if hitAllCheck then 
			return checkPos, #newCluster, newCluster
		end

	end
	
	return avgCastPos, #targets, targets
end

function GetEnemiesAtPos(checkrange, range, pos, target)
    local enemies = ObjectManager:GetEnemyHeroes(checkrange)
    local results = {}
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if getDistanceSqr(pos, enemy.pos) < Range and isValid(enemy) and enemy ~= target then
            table.insert(results, enemy)
        end
    end
    table.insert(results, target)
    return results
end

------------------------------------

class "Ornn"
        
function Ornn:__init()	     
    print("Zgjfjfl-Ornn Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
    Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 800, Speed = 1800, Collision = false}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 750, Speed = 1600, Collision = false}
    self.r1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 170, Range = 2500, Speed = 1200, Collision = false}
    self.qPos = {}
    self.qTimer = nil
  end

function Ornn:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgOrnn", name = "Zgjfjfl Ornn"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ED", name = "E KnockUp Range", min = 0, max = 360, value = 300, step = 10})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "Rcount", name = "UseR1 when hit X enemies inrange", min = 1, max = 5, value = 2, step = 1})
        self.Menu.Combo:MenuElement({id = "R2", name = "[R2]", toggle = true, value = false})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function Ornn:onTick()
    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end

    if self.qTimer and Game.Timer() >= self.qTimer then
        self:GetQpos()
        self.qTimer = nil
    end

    self:UpdateQpos()

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
   
end

function Ornn:OnWndMsg(msg, wParam)
    if msg == 257 then
        if wParam == HK_Q then
            --print('1')
            self.qTimer = Game.Timer() + 1
        end
    end
end


function Ornn:GetQpos()
    for i = GameParticleCount(), 1, -1 do
        local particle = GameParticle(i)
        local Name = particle.name
        if particle and Name:find("Ornn") and Name:find("Q_Indicator") then
            TableInsert(self.qPos, {pos = particle.pos, Timer = Game.Timer()})
            break
        end
    end
end

function Ornn:UpdateQpos()
    for k, qPos in pairs(self.qPos) do
        if Game.Timer() - qPos.Timer > 5 then
            TableRemove(self.qPos, k)
        end
	--Draw.Circle(qPos.pos, 100, Draw.Color(192, 255, 255, 255))
    end
end

function Ornn:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(3000)
    if target and isValid(target) and target.pos2D.onScreen then

        local objpos = target.pos:Extended(myHero.pos, -self.Menu.Combo.ED:Value())

        if (not MapPosition:intersectsWall(target.pos, objpos) or not isSpellReady(_E)) and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
            if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero:GetSpellData(_R).name ~= "OrnnRCharge"then
            castSpellHigh(self.wSpell, HK_W, target)
            lastW = GetTickCount()
        end

        if self.Menu.Combo.EQ:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
            local castPos = nil
            for _, qPos in pairs(self.qPos) do
                if not MapPosition:intersectsWall(myHero.pos, qPos.pos) and getEnemyCount(self.Menu.Combo.ED:Value(), qPos.pos) >= 1 and myHero.pos:DistanceTo(qPos.pos) <= self.eSpell.Range then
                    castPos = qPos.pos
                    break
                end
            end
            if castPos then
                Control.CastSpell(HK_E, castPos)
                lastE = GetTickCount()
		self.qPos = {}
            end
        end

        if self.Menu.Combo.EWall:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
            if not MapPosition:intersectsWall(myHero.pos, target.pos) then
                if MapPosition:intersectsWall(target.pos, objpos) then
                    local ECastPos = MapPosition:getIntersectionPoint3D(target.pos, objpos)
                    if myHero.pos:DistanceTo(ECastPos) < self.eSpell.Range then
                        Control.CastSpell(HK_E, ECastPos)
                        lastE = GetTickCount()
                    end
                end
            else
                local ECastPos2 = MapPosition:getIntersectionPoint3D(myHero.pos, target.pos)
                if target.pos:DistanceTo(ECastPos2) < self.Menu.Combo.ED:Value() and myHero.pos:DistanceTo(ECastPos2) < self.eSpell.Range then
                    Control.CastSpell(HK_E, ECastPos2)
                    lastE = GetTickCount()
                end
            end
        end

        if self.Menu.Combo.R2:Value() and isSpellReady(_R) and myHero:GetSpellData(_R).name == "OrnnRCharge" then
            for i = GameParticleCount(), 1, -1 do
            local particle = GameParticle(i)
                if particle and particle.name:find("Ornn") and particle.name:find("R_Wave_Mis") and myHero.pos:DistanceTo(target.pos) < 2500 then
                    local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(particle.pos, target.pos, myHero.pos)
                    if isOnSegment and myHero.pos:DistanceTo(point) < 700 then
                        Control.CastSpell(HK_R, target)
                    end
                end
            end
        end
    end
    if self.Menu.Combo.R:Value() and isSpellReady(_R) and myHero:GetSpellData(_R).name == "OrnnR" and lastR + 600 < GetTickCount() then
        local enemies = ObjectManager:GetEnemyHeroes(self.r1Spell.Range)
        for i, enemy in ipairs(enemies) do
            if getEnemyCount(170, enemy.pos) >= self.Menu.Combo.Rcount:Value() then
                castSpellHigh(self.r1Spell, HK_R, enemy)
                lastR = GetTickCount()
            end
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) and target.pos2D.onScreen then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
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
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.r1Spell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------
class "JarvanIV"
        
function JarvanIV:__init()	     
    print("Zgjfjfl-JarvanIV Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
    Orbwalker:OnPreMovement(function(...) self:OnPreMovement(...) end)
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

function JarvanIV:OnPreMovement(args)
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        if isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
            args.Process = false
        end
    end
end

function JarvanIV:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if haveBuff(myHero, "JarvanIVCataclysm") and getEnemyCount(self.rSpell.Radius, myHero.pos) == 0 then
        Control.CastSpell(HK_R)
    end

    CastingQ = myHero.activeSpell.name == "JarvanIVDragonStrike"
    isDash = myHero.pathing.isDashing

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
   self:KillSteal()
end

function JarvanIV:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then

        local pred = GGPrediction:SpellPrediction(self.eSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local offset = IsFacing(target) and -100 or -200
            local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), offset)
            if self.Menu.Combo.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
                if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
                    Control.CastSpell(HK_E, castPos)
                    Orbwalker:SetMovement(false)
                    Orbwalker:SetAttack(false)
                    DelayAction(function() Control.CastSpell(HK_Q, castPos) end, 0.1)
                    Orbwalker:SetMovement(true)
                    Orbwalker:SetAttack(true)
                end
            end
        end
		        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and not isSpellReady(_E) and myHero:GetSpellData(_E).currentCd > 2 and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and ((myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero.health/myHero.maxHealth <= self.Menu.Combo.WHp:Value()/100) or getEnemyCount(self.wSpell.Range, myHero.pos) >= self.Menu.Combo.WCount:Value()) then
            Control.CastSpell(HK_W)
        end

        if self.Menu.Combo.R:Value() and isSpellReady(_R) and not CastingQ and not isDash and not haveBuff(myHero, "JarvanIVCataclysm") then
            if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and (target.health/target.maxHealth <= self.Menu.Combo.RHp:Value()/100 or getEnemyCount(self.rSpell.Radius, target.pos) >= self.Menu.Combo.RCount:Value()) then
                Control.CastSpell(HK_R, target)
            end
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then       
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

    end
end

function JarvanIV:KillSteal()
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
    if target and isValid(target) then
        if isSpellReady(_Q) and lastQ + 500 < GetTickCount() and self.Menu.KS.Q:Value() then
            if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
                castSpellHigh(self.qSpell, HK_Q, target)
                lastQ = GetTickCount()
            end	
        end

        if isSpellReady(_E) and self.Menu.KS.E:Value() then
            if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                castSpellHigh(self.eSpell, HK_E, target)
            end	
        end

        if isSpellReady(_R) and self.Menu.KS.R:Value() and not haveBuff(myHero, "JarvanIVCataclysm") and not CastingQ and not isDash then
            if self:getrDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
                Control.CastSpell(HK_R, target)
            end	
        end

    end
end

function JarvanIV:getqDmg(target)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 40 * qlvl + 50
    local qadDmg = myHero.bonusDamage * 1.4
    local qDmg = qbaseDmg + qadDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function JarvanIV:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 40 * elvl + 40
    local eapDmg = myHero.ap * 0.8
    local eDmg = ebaseDmg + eapDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function JarvanIV:getrDmg(target)
    local rlvl = myHero:GetSpellData(_R).level
    local rbaseDmg  = 125 * rlvl + 75
    local radDmg = myHero.bonusDamage * 1.8
    local rDmg = rbaseDmg + radDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg) 
end

function JarvanIV:Flee()
    if self.Menu.Flee.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
        Control.CastSpell(HK_E, pos)
        DelayAction(function() Control.CastSpell(HK_Q, pos) end, 0.1)
    end

    local target = TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then
        if isSpellReady(_W) and not isSpellReady(_Q) and self.Menu.Flee.W:Value() then
            if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
                Control.CastSpell(HK_W)
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
    Callback.Add("Tick", function() self:onTick() end)
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
        self.Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 50, max = 400, value = 400, step = 50})
        self.Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP %", value = 30, min = 0, max = 100, step = 5})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
		
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
    self.Menu:MenuElement({type = MENU, id = "Antidash", name = "W Setting "})
        self.Menu.Antidash:MenuElement({id = "W", name = "[W] Anti-Dash", toggle = true, value = true})
        self.Menu.Antidash:MenuElement({type = MENU, id = "Wtarget", name = "Use On"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.Antidash.Wtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = false})		
                end		
            end,0.2)
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Poppy:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if haveBuff(myHero, "PoppyR") then
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if self.Menu.Antidash.W:Value() then
        self:AutoW()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end

end

function Poppy:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then
	
	for dis = 20, self.Menu.Combo.ED:Value(), 20 do
            local endPos = target.pos:Extended(myHero.pos, -dis)
            if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
                if MapPosition:inWall(endPos) then
                    Control.CastSpell(HK_E, target)
                    lastE = GetTickCount()
                end
            end
        end
				        
        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
		
        if self.Menu.Combo.RF:Value() and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth <= self.Menu.Combo.RFHP:Value()/100 then
            Control.KeyDown(HK_R)
            DelayAction(function()
                castSpellHigh(self.rSpell, HK_R, target)
                Control.KeyUp(HK_R)
            end, 0.1)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
            
        if self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end

    end
end

function Poppy:AutoW()
    local enemies = ObjectManager:GetEnemyHeroes(1000)
    for i, enemy in ipairs(enemies) do
        if isValid(enemy) then
            local blockobj = self.Menu.Antidash.Wtarget[enemy.charName] and self.Menu.Antidash.Wtarget[enemy.charName]:Value()
            if blockobj and enemy.pathing.isDashing then
                local vct = Vector(enemy.pathing.endPos.x, enemy.pathing.endPos.y, enemy.pathing.endPos.z)
                if vct:DistanceTo(myHero.pos) < 400 then
                    if isSpellReady(_W) and lastW + 250 < GetTickCount() then
                        Control.CastSpell(HK_W)
                        lastW = GetTickCount()
                    end
                end
            end
        end
    end
end

function Poppy:RSemiManual()
    local target = TargetSelector:GetTarget(self.r2Spell.Range)
    if target and isValid(target) then
        if isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.r2Spell.Range then
            Control.KeyDown(HK_R)
            DelayAction(function()
                castSpellHigh(self.r2Spell, HK_R, target)
                Control.KeyUp(HK_R)
            end, 1)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 925, Speed = 1600, Collision = false}
    self.e2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.333, Radius = 345, Range = 1200, Speed = 1575, Collision = false}
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

function Shyvana:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Shyvana:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1300)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
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

function Trundle:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Trundle:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(500)
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
    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 725, Speed = 1700, Collision = false}
end

function Rakan:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgRakan", name = "Zgjfjfl Rakan"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E2", name = "[E] on allies taking damage", toggle = true, value = true})
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

function Rakan:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end

end

function Rakan:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end
    end

    if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 600 < GetTickCount() and getEnemyCount(self.wSpell.Range, myHero.pos) >= 2 then
         Control.CastSpell(HK_R)
         lastR = GetTickCount()
    end

    if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
        local allies = ObjectManager:GetAllyHeroes(1000)
        for i, ally in ipairs(allies) do
            if not ally.isMe then
                if (ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000) or myHero.pos:DistanceTo(ally.pos) <= 700 then
                    if isSpellReady(_W) and getEnemyCount(self.wSpell.Range, myHero.pos) == 0 and getEnemyCount(self.wSpell.Range, ally.pos) >= 1 then
                        Control.CastSpell(HK_E, ally)
                        lastE = GetTickCount()
                    end
                end
            end
        end
    end

    if self.Menu.Combo.E2:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
        local enemies = ObjectManager:GetEnemyHeroes(2500)
        local allies = ObjectManager:GetAllyHeroes(1000)
        for i, enemy in ipairs(enemies) do
            if isValid(enemy) then
                for j, ally in ipairs(allies) do
                    if not ally.isMe and self:attackedcheck(enemy, ally) and not haveBuff(ally, "RakanEShield") then
                        if (ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000) or myHero.pos:DistanceTo(ally.pos) <= 700 then
                            Control.CastSpell(HK_E, ally)
                            lastE = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end	

function Rakan:Harass()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then

        if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and self.Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            castSpellHigh(self.qSpell, HK_Q, target)
            lastQ = GetTickCount()
        end
    end
end

function Rakan:attackedcheck(enemy, ally)
    local canuse = false
    if not ally.isMe then
        if enemy.isChanneling then 
            if enemy.activeSpell.target == ally.handle then
                canuse = true
            else
                local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, enemy.activeSpell.placementPos, enemy.pos)
                local width = ally.boundingRadius
                if enemy.activeSpell.width > 0 then
                    width = width + enemy.activeSpell.width
                end
                if isOnSegment and isInRange(point, ally.pos, width) then
                    canuse = true
                end
            end
        elseif enemy.activeSpell.target == ally.handle then --autoattack
            canuse = true
        end
        if canuse then
            return true
        end
    end
    return false
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
                 if  distance2 < mousePos:DistanceTo(myHero.pos) and (distance1 <= 700 or (hero.charName == "Xayah" and distance1 <= 1000)) then
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
    Callback.Add("Tick", function() self:onTick() end)
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

function Belveth:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    castingE = doesMyChampionHaveBuff("BelvethE")
    if castingE then 
        if getEnemyCount(self.eSpell.Range, myHero.pos) == 0 and getMinionCount(self.eSpell.Range, myHero.pos) == 0 and Game.CanUseSpell(_E) == 0 then
            Control.CastSpell(HK_E)
        end
        Orbwalker:SetMovement(false)
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetMovement(true)
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:KillSteal()

end

function Belveth:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    local ebaseDmg  = elvl + 5
    local eadDmg = myHero.totalDamage * 0.08
    local exttimes = math.floor(((myHero.attackSpeed - 1) / 0.333) + 0.5)
    local eDmg = (ebaseDmg + eadDmg) * (1 + missingHP * 3) * (6 + exttimes)
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg) 
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
    Callback.Add("Tick", function() self:onTick() end)
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

function Nasus:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    local numEnemies = getEnemyHeroesWithinDistance(700)
    if #numEnemies >= 1 and myHero.health/myHero.maxHealth <= self.Menu.Combo.RHP:Value()/100 and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 300 < GetTickCount() then
        Control.CastSpell(HK_R)
        lastR = GetTickCount()
   end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    self:KillSteal()

end

function Nasus:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Nasus:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg = 40 * elvl + 15
    local eapDmg = 0.6 * myHero.ap
    local eDmg = ebaseDmg + eapDmg
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
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
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 265, Range = 1000, Speed = 700, Collision =false}
end

function Singed:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgSinged", name = "Zgjfjfl Singed"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Rcount", name = "UseR when X enemies inWrange ", value = 2, min = 1, max = 5, step = 1})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})

end

function Singed:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetAttack(true)
    end

    enemies = ObjectManager:GetEnemyHeroes(1000)
    minions = ObjectManager:GetEnemyMinions(1000)
    if #enemies == 0 and #minions == 0  and haveBuff(myHero, "PoisonTrail") and lastQ +250 < GetTickCount() then
        Control.CastSpell(HK_Q)
        lastQ = GetTickCount()
    end
end

function Singed:Combo()

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if self.Menu.Combo.Q:Value() and myHero.pos:DistanceTo(target.pos) <= 500 then
            if isSpellReady(_Q) and lastQ +250 < GetTickCount() and myHero:GetSpellData(_Q).toggleState == 1 then
                Control.CastSpell(HK_Q)
                lastQ = GetTickCount()
            end
        end
        if self.Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < 1000 then
            self:CastW(target)
        end
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE +350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= 300 then
            Control.CastSpell(HK_E, target)
            lastE = GetTickCount()
        end
    end
    if #enemies >= self.Menu.Combo.Rcount:Value() then
        if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR +250 < GetTickCount() then
            Control.CastSpell(HK_R)
            lastR = GetTickCount()
        end
    end
end

function Singed:CastW(target)
    if isSpellReady(_W) and lastW +350 < GetTickCount() then
        local pred = GGPrediction:SpellPrediction(self.wSpell)
        pred:GetPrediction(target, myHero)
        if self.wSpell.Range - 80 > myHero.pos:DistanceTo(pred.CastPosition) then
            if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                Control.CastSpell(HK_W, pred.CastPosition)
                lastW = GetTickCount()
            end
        end
    end
end

function Singed:Draw()
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
    end
end
------------------------------
class "Udyr"
        
function Udyr:__init()	     
    print("Zgjfjfl-Udyr Loaded") 
    self:LoadMenu()

    Callback.Add("Tick", function() self:onTick() end)

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

function Udyr:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
        self:JungleClear()
    end

   end

function Udyr:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(800)
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
    Callback.Add("Tick", function() self:onTick() end)
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
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range in minimap", toggle = true, value = true})
end

function Galio:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end     
    if doesMyChampionHaveBuff("GalioW") then
          Orbwalker:SetAttack(false)
     else
          Orbwalker:SetAttack(true)
     end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:AutoW()
    self:KillSteal()

end

function Galio:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
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

    local enemies = ObjectManager:GetEnemyHeroes(1000)
    for i, enemy in ipairs(enemies) do
        if isValid(enemy) then
            local obj = self.Menu.Auto.WB[enemy.charName] and self.Menu.Auto.WB[enemy.charName]:Value()
            if obj and enemy.pathing.isDashing then
                local vct = Vector(enemy.pathing.endPos.x, enemy.pathing.endPos.y, enemy.pathing.endPos.z)
                if vct:DistanceTo(myHero.pos) < self.wSpell.Range then
                    self:CastW(self.Menu.Auto.Wtime:Value())
                end
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
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
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
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg) 
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
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.CircleMinimap(myHero.pos, 3250 + 750*myHero:GetSpellData(_R).level, 1, Draw.Color(200,50,180,230))
    end
end
------------------------------
class "Yorick"
        
function Yorick:__init()	     
    print("Zgjfjfl-Yorick Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
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

function Yorick:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    self:KillSteal()
    self:AutoW()
end

function Yorick:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1100)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    local target = TargetSelector:GetTarget(self.wSpell.Range)
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
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Yorick:geteDmg(target)
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 35 * elvl + 35
    local eapDmg = myHero.ap * 0.7
    local eDmg = ebaseDmg + eapDmg
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function Yorick:AutoW()
    if Attack:IsActive() then return end
    for i, target in pairs(getEnemyHeroes()) do
        if self.Menu.Auto.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and isInvulnerable(target) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
            Control.CastSpell(HK_W, target)
            lastW = GetTickCount()
        end
    end
			
    local target = TargetSelector:GetTarget(self.wSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)

    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1150, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.eSpell = { Range = 750, Radius = 500 }
    self.rSpell = { Range = 800 }
end

function Ivern:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgIvern", name = "Zgjfjfl Ivern"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R1]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
        self.Menu.AutoE:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
            DelayAction(function()
                for i, Hero in pairs(getAllyHeroes()) do
                    self.Menu.AutoE.Etarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "Daisy", name = "Daisy Setting"})
        self.Menu.Daisy:MenuElement({id = "R1", name = "Control 'Daisy' attack target", key = string.byte("T")})
        self.Menu.Daisy:MenuElement({id = "R2", name = "Control 'Daisy' follow self", key = string.byte("Z")})

    self.Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
        self.Menu.Misc:MenuElement({id = "disableAA", name = "Disable AA", toggle = true, value = true})
        self.Menu.Misc:MenuElement({id = "count", name = "DisableAA when >= X enemies inQrange", value = 3, min = 1 , max = 5 , step = 1})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Ivern:onTick()
  
    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

    if self.Menu.AutoE.E:Value() then
        self:AutoE()
    end

    if myHero:GetSpellData(_R).name == "IvernRRecast" then
        self:DaisyControl()
    end

    if self.Menu.Misc.disableAA:Value() and getEnemyCount(self.qSpell.Range, myHero.pos) >= self.Menu.Misc.count:Value() then
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetAttack(true)
    end
end

function Ivern:CastQ(target)
    if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "IvernQ"and lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
        local Pred = GGPrediction:SpellPrediction(self.qSpell)
        Pred:GetPrediction(target, myHero)
        if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Ivern:Combo()

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() then
            self:CastQ(target)
        end
        if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and myHero:GetSpellData(_R).name == "IvernR" and self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
             Control.CastSpell(HK_R, target)
            lastR = GetTickCount()
        end
    end
end

function Ivern:AutoE()
    if isSpellReady(_E) and lastE + 250 < GetTickCount() then
        local enemies = ObjectManager:GetEnemyHeroes(2500)
        for i, enemy in ipairs(enemies) do
            if isValid(enemy) then
                local allies = ObjectManager:GetAllyHeroes(self.eSpell.Range)
                for i, ally in ipairs(allies) do
                    if #allies == 1 and ally.isMe and self.Menu.AutoE.Etarget[ally.charName]:Value() then
                        if ally.pos:DistanceTo(enemy.pos) < self.eSpell.Radius then 
                            Control.CastSpell(HK_E, ally)
                            lastE = GetTickCount()
                        end
                    elseif #allies > 1 and not ally.isMe and self.Menu.AutoE.Etarget[ally.charName]:Value() then
                        if ally.pos:DistanceTo(enemy.pos) < self.eSpell.Radius then
                            if ally.pos:DistanceTo(enemy.pos) < myHero.pos:DistanceTo(enemy.pos) or (self.Menu.AutoE.Etarget[myHero.charName]:Value() == false) then
                                Control.CastSpell(HK_E, ally)
                                lastE = GetTickCount()
                            else
                                Control.CastSpell(HK_E, myHero)
                                lastE = GetTickCount()
                            end
                        end
                    end
                end
            end
        end
    end
end

function Ivern:DaisyControl()

    local target = TargetSelector:GetTarget(2500)
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
    local target = TargetSelector:GetTarget(self.qSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 850, Speed = 1500, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
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

function Bard:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    self:AutoW()
end

function Bard:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1500)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        local pred = GGPrediction:SpellPrediction(self.qSpell)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            local extendPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -250)
            local lineQ = LineSegment(pred.CastPosition, extendPos)
            if MapPosition:intersectsWall(lineQ) and self.Menu.Combo.Q3:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
                Control.CastSpell(HK_Q, target)
                lastQ = GetTickCount()
            end
        end

        local pred2 = target:GetPrediction(self.qSpell.Speed, self.qSpell.Delay)
        if pred2 == nil then return end
        local d = getDistance(myHero.pos, pred2)
        local targetPos = Vector(myHero.pos):Extended(pred2, self.qSpell.Range+250) 
        if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and self.Menu.Combo.Q2:Value() then 
            for i = 1, GameMinionCount() do
            local minion = GameMinion(i) 
                if minion and minion.isEnemy and not minion.dead then
                local minionPos = Vector(myHero.pos):Extended(Vector(minion.pos), self.qSpell.Range+300)
                    if getDistance(targetPos, minionPos) <= 30 then
                    local d2 = getDistance(myHero.pos, minion.pos)
                        if d2 <= self.qSpell.Range and d <= self.qSpell.Range+250 and d > d2 then 
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
                        if d3 <= self.qSpell.Range and d <= self.qSpell.Range+250 and d > d3 then 
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
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = 3600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 225, Range = 900, Speed = math.huge, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1700, Collision = false}
end

function Taliyah:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgTaliyah", name = "Zgjfjfl Taliyah"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Wpush", name = "[W] push range", value = 400, min = 100, max = 600, step = 50})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Erange", name = "[E] cast range", value = 900, min = 100, max = 950, step = 50})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

local vectorCast = {}
local mouseReturnPos = mousePos
local mouseCurrentPos = mousePos
local nextVectorCast = 0
function Taliyah:CastVectorSpell(key, pos1, pos2)
	if nextVectorCast > Game.Timer() then return end
	nextVectorCast = Game.Timer() + 1.5
	Orbwalker:SetMovement(false)
	Orbwalker:SetAttack(false)
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
		Orbwalker:SetMovement(true)
		Orbwalker:SetAttack(true)
	end		
end

function Taliyah:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    

    if #vectorCast > 0 then
        vectorCast[1]()
        table.remove(vectorCast, 1)
        return
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
end

function Taliyah:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.Erange:Value() and self.Menu.Combo.E:Value() and isSpellReady(_E) and not isSpellReady(_W) and lastE + 350 < GetTickCount() then
             Control.CastSpell(HK_E, target)
             lastE = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and isSpellReady(_W) then
            local predPos = target:GetPrediction(self.wSpell.Speed, self.wSpell.Delay)
            local d = myHero.pos:DistanceTo(predPos)
            if d < self.wSpell.Range then
                local endPos = predPos + (myHero.pos - predPos):Normalized() * 225
                if d <= self.Menu.Combo.Wpush:Value() then
                    endPos = predPos + (predPos - myHero.pos):Normalized() * 225
                end
                self:CastVectorSpell(HK_W, predPos, endPos)
                return
            end
        end
    end
end

function Taliyah:Harass()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range =825, Speed = 2200, Collision = false}
    self.q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range =950, Speed = 2200, Collision = false}
    self.wSpell = { Range = 450 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 125, Range = 1050, Speed = 1200, Collision = false}
    self.rSpell = { Range = 550 }
end

function Lissandra:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgLissandra", name = "Zgjfjfl Lissandra"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E1", name = "[E1]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E2", name = "[E2]", toggle = true, value = true})
	self.Menu.Combo:MenuElement({name = " ", drop = {"if enemy isUnderTurret wont E2 "}})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "healthy", name = "Define self healthy%", value = 50, min = 1, max = 100, step = 5})
	self.Menu.Combo:MenuElement({name = " ", drop = {"greater than healthy to do:"}})
        self.Menu.Combo:MenuElement({id = "ecountW", name = "Enemies count for E2 (W)", value = 2, min = 1, max = 5, step = 1})
        self.Menu.Combo:MenuElement({id = "ecountR", name = "Enemies count for E2 (R)", value = 2, min = 1, max = 5, step = 1})
        self.Menu.Combo:MenuElement({id = "R1count", name = "Enemies count for Ult them", value = 2, min = 1, max = 5, step = 1})
	self.Menu.Combo:MenuElement({name = " ", drop = {"less than healthy to do:"}})
        self.Menu.Combo:MenuElement({id = "R2count", name = "Enemies count for self Ult", value = 2, min = 1, max = 5, step = 1})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Mana", name = "Harass min Mana", value = 50, min = 1, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        self.Menu.Flee:MenuElement({id = "E", name = "[E] to mouse", toggle = true, value = true})
	
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "Q2", name = "[Q2] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
       self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
       self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Lissandra:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
  
    if doesMyChampionHaveBuff("LissandraRSelf") then
        Orbwalker:SetMovement(false)
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetMovement(true)
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
end

function Lissandra:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then

	if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
		if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
			if getEnemyCount(self.rSpell.Range, target.pos) >= self.Menu.Combo.R1count:Value() and self:IsHealthy() then
				Control.CastSpell(HK_R, target)
				lastR = GetTickCount()
			end
		end
	end

	if self.Menu.Combo.Q:Value() then
		self:CastQ(target)
	end

	if self.Menu.Combo.E1:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
		if not self:E2Ready() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range-100 then
			castSpellHigh(self.eSpell, HK_E, target)
			lastE = GetTickCount()
		end
	end
        self:CastE2(target)
    end

	if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() then
		if getEnemyCount(self.rSpell.Range, myHero.pos) >= self.Menu.Combo.R2count:Value() and not self:IsHealthy() then
			Control.CastSpell(HK_R, myHero)
			lastR = GetTickCount()
		end
	end

    if getEnemyCount(self.wSpell.Range, myHero.pos) >= 1 and self.Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
        Control.CastSpell(HK_W)
        lastW = GetTickCount()
    end
end

function Lissandra:Harass()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if target and isValid(target) then
        if self.Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana > self.Menu.Harass.Mana:Value()/100 then
            self:CastQ(target)
        end
    end
end

function Lissandra:Flee()
    if not self:E2Ready() then
        if self.Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
             Control.CastSpell(HK_E, mousePos)
             lastE = GetTickCount()
             DelayAction(function() Control.CastSpell(HK_E) end, 1.3)
        end
    end
end

local EmissilePos = nil
function Lissandra:CheckEPos()
    if EmissilePos ~= nil then
        return EmissilePos
    end
    local particle = nil
    for i = 1, GameParticleCount() do
        local p = GameParticle(i)
        if p and p.name:find("Lissandra") and p.name:find("E_Missile") then
            particle = p
            break
        end
    end
    if particle then
        missilePos = particle
    else
        missilePos = nil
    end
    return missilePos
end

function Lissandra:CastQ(target)
	local dis = myHero.pos:DistanceTo(target.pos)
	if isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
		if dis > self.qSpell.Range and dis < self.q2Spell.Range then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
			if collisionCount > 0 then
				local unit = collisionObjects[1]
				if isValid(unit) and myHero.pos:DistanceTo(unit.pos) <= self.qSpell.Range then
					local q2Pred = GGPrediction:SpellPrediction(self.q2Spell)
					q2Pred:GetPrediction(target, myHero) 
					if q2Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
						Control.CastSpell(HK_Q, q2Pred.CastPosition)
						lastQ = GetTickCount()
					end
				end
			end
		elseif dis < self.qSpell.Range then
			local qPred = GGPrediction:SpellPrediction(self.qSpell)
    			qPred:GetPrediction(target, myHero)
			if qPred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_Q, qPred.CastPosition)
				lastQ = GetTickCount()
			end
		end  
	end
end

function Lissandra:CastE2(target)
        if self:E2Ready() then
		--self:CheckEPos()
		local EmissilePos = self:CheckEPos()
		local dis1 = myHero.pos:DistanceTo(target.pos)
		if EmissilePos ~= nil then
			local dis2 = EmissilePos.pos:DistanceTo(target.pos)
			if self.Menu.Combo.E2:Value() and self:IsHealthy() and self:E2Ready() and isSpellReady(_E) then
				if dis1 > dis2 and not isUnderTurret(EmissilePos) then
					if getEnemyCount(self.rSpell.Range-100, EmissilePos.pos) >= self.Menu.Combo.ecountR:Value() and isSpellReady(_R) then
						Control.CastSpell(HK_E)
					elseif getEnemyCount(self.wSpell.Range-100, EmissilePos.pos) >= self.Menu.Combo.ecountW:Value() and isSpellReady(_W) then
						Control.CastSpell(HK_E)
					end
				end 
			end
		end
	end
end

function Lissandra:IsHealthy()
	return myHero.health / myHero.maxHealth > self.Menu.Combo.healthy:Value()/100
end

function Lissandra:E2Ready()
  return haveBuff(myHero, "LissandraE")
end

function Lissandra:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.Q2:Value() and isSpellReady(_Q) then
            Draw.Circle(myHero.pos, self.q2Spell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
            Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
            Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
            Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
    end
end
------------------------------
class "Sejuani"
        
function Sejuani:__init()	     
    print("Zgjfjfl-Sejuani Loaded") 
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
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

function Sejuani:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
end

function Sejuani:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.wSpell.Range)
    if target and isValid(target) then
        if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and self.Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 1000 < GetTickCount() then
             castSpellHigh(self.wSpell, HK_W, target)
             lastW = GetTickCount()
        end
    end
end

function Sejuani:RSemiManual()
    local target = TargetSelector:GetTarget(self.rSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 75, Range = 450, Speed = math.huge, Collision = false}
    self.q3Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 70, Range = 800, Speed = 1600, Collision = false}
    self.wSpell = { Range = 600 }
    self.e1Spell = { Range = 250 }
    self.e2Spell = { Range = 400 }
    self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 350, Speed = 2000, Collision = false}
end

function KSante:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgKSante", name = "Zgjfjfl KSante"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W1", name = "Use W1 push target to tower/ally", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "W1Time", name = "W1 Channel time(s)", value = 0.75, min = 0.75, max= 1.5, step = 0.05})
        self.Menu.Combo:MenuElement({id = "W2", name = "[W] AllOut W", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W2Time", name = "AllOut W Channel time(s)", value = 0.5, min = 0.5, max= 1.5, step = 0.05})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "EA", name = "use E close to enemy AApassive", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "ET", name = "use E close to enemy useQ", toggle = true, value = true})
        --self.Menu.Combo:MenuElement({id = "EM", name = "use E allyminion close to enemy", toggle = true, value = true})
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

function KSante:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    local bonusHealth = math.min(math.floor(myHero.maxHealth - (570 + 115 * (myHero.levelData.lvl - 1) * (0.7025 + 0.0175 * (myHero.levelData.lvl - 1)))), 1600)
    local time = math.floor(bonusHealth / 8000 * 100) / 100
    --print(time)
    self.q1Spell.Delay = 0.45 - time
    self.q3Spell.Delay = 0.45 - time
    if doesMyChampionHaveBuff("KSanteQ3") then
        self.qSpell = self.q3Spell
    else
        self.qSpell = self.q1Spell
    end
    if doesMyChampionHaveBuff("KSanteRTransform") then
        self.qSpell.Delay = self.qSpell.Delay - 0.08
        self.eSpell = self.e2Spell
    else
        self.eSpell = self.e1Spell
    end
    --print(self.qSpell.Delay)
    if doesMyChampionHaveBuff("KSanteW") or doesMyChampionHaveBuff("KSanteW_AllOut") then
        Orbwalker:SetMovement(false)
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetMovement(true)
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LastHit()
        self:LaneClear()
        self:JungleClear()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:LastHit()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
end

function KSante:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range + self.eSpell.Range)
    if target and isValid(target) then
        if self.Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and isSpellReady(_Q) then
            if self.Menu.Combo.EH:Value() then
                local allies = ObjectManager:GetAllyHeroes(550)
                for i, ally in ipairs(allies) do
                    if not ally.isMe and getEnemyCount(self.qSpell.Range, myHero.pos) == 0 and getEnemyCount(self.qSpell.Range, ally.pos) >= 1 then
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
            --[[if self.Menu.Combo.EM:Value() then
                local Minions = ObjectManager:GetAllyMinions(550)
                for i = 1, #Minions do
                    local minion = Minions[i]
                    if getEnemyCount(self.qSpell.Range, myHero.pos) == 0 and getEnemyCount(self.qSpell.Range, minion.pos) >= 1 then
                        Control.CastSpell(HK_E, minion)
                        lastE = GetTickCount()
                    end
                end
            end]]
        end

        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
             castSpellHigh(self.qSpell, HK_Q, target)
             lastQ = GetTickCount()
        end

        if self.Menu.Combo.W:Value() and self.Menu.Combo.W2:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
            if doesMyChampionHaveBuff("KSanteRTransform") then
                 self:CastW(target,self.Menu.Combo.W2Time:Value())
            end
        end

        if self.Menu.Combo.W:Value() and self.Menu.Combo.W1:Value() and myHero.pos:DistanceTo(target.pos) < 450 then
            local turrets = ObjectManager:GetAllyTurrets(2000)
            for i, turret in ipairs(turrets) do
                if turret.pos:DistanceTo(target.pos) < 1200 and turret.pos:DistanceTo(target.pos) < turret.pos:DistanceTo(myHero.pos) then
                    self:CastW(target,self.Menu.Combo.W1Time:Value())
                end
            end
            local allies = ObjectManager:GetAllyHeroes(2000)
            for k, ally in ipairs(allies) do
                if not ally.isMe and ally.pos:DistanceTo(target.pos) < 1000 and ally.pos:DistanceTo(target.pos) < ally.pos:DistanceTo(myHero.pos) then
                    self:CastW(target,self.Menu.Combo.W1Time:Value())
                end
            end
        end

        if self.Menu.Combo.RT:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
            local turrets = ObjectManager:GetAllyTurrets(2000)
            for i, turret in ipairs(turrets) do
                local Pos = target.pos:Extended(myHero.pos, -300)
                if turret.pos:DistanceTo(Pos) < 800 and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and turret.pos:DistanceTo(Pos) < turret.pos:DistanceTo(target.pos) then
                    Control.CastSpell(HK_R, target)
                    lastR = GetTickCount()
                end
            end
        end
        if haveBuff(target, "KSantePMark") then
            local AARange = myHero.range + myHero.boundingRadius + target.boundingRadius + 25
            if myHero.pos:DistanceTo(target.pos) > AARange and myHero.pos:DistanceTo(target.pos) <= AARange + self.eSpell.Range then
                if self.Menu.Combo.E:Value() and self.Menu.Combo.EA:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
                    Control.CastSpell(HK_E, target)
                    lastE = GetTickCount()
                end
            end
        end
    end
end

function KSante:Harass()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
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
            DelayAction(function()
                Control.CastSpell(HK_W, target)
                Control.KeyUp(HK_W)
            end, time + Game.Latency()/1000)
    end
end
function KSante:RSemiManual()
    local target = TargetSelector:GetTarget(self.rSpell.Range)
    if target and isValid(target) then
        local Pos = target.pos:Extended(myHero.pos, -300)
        if MapPosition:intersectsWall(target.pos, Pos) and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
             Control.CastSpell(HK_R, target)
             lastR = GetTickCount()
        end
    end
end

function KSante:LaneClear()
    if Attack:IsActive() then return end
    if self.Menu.Clear1.Q:Value() then
        local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
        for i = 1, #minions do
            local minion = minions[i]
            if isValid(minion) and minion.team ~= 300 then
                local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
                if collisionCount >= self.Menu.Clear1.QCount:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
                    Control.CastSpell(HK_Q, minion)
                    lastQ = GetTickCount()
                end
            end
        end
    end
end

function KSante:JungleClear()
    if Attack:IsActive() then return end
    if self.Menu.Clear1.Q:Value() then
        local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
        for i = 1, #minions do
            local minion = minions[i]
            if isValid(minion) and minion.team == 300 and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
                Control.CastSpell(HK_Q, minion)
                lastQ = GetTickCount()
            end
        end
    end
end

function KSante:LastHit()
    if Attack:IsActive() then return end
    local minionInRange = ObjectManager:GetEnemyMinions(self.qSpell.Range)
    if next(minionInRange) == nil then return end
    for i = 1, #minionInRange do
        local minion = minionInRange[i]
        if self.Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
            if self:getqDmg(minion) >= minion.health and not minion.dead then
                Control.CastSpell(HK_Q, minion)
                lastQ = GetTickCount()
            end
        end
    end
end

function KSante:getqDmg(unit)
    local qlvl = myHero:GetSpellData(_Q).level
    local qbaseDmg  = 30 * qlvl
    local qadDmg = myHero.totalDamage * 0.4
    local qextDmg = myHero.bonusArmor * 0.3 + myHero.bonusMagicResist * 0.3
    local qDmg = qbaseDmg + qadDmg + qextDmg
return Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = { Range = 350 }
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 950, Speed = 1200, Collision = false}
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

function Skarner:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    if haveBuff(myHero, "skarnerimpalebuff") then
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:LaneClear()
    end
end

function Skarner:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
            -- Orbwalker.ForceTarget = enemy
        -- else
            -- Orbwalker.ForceTarget = nil
        -- end
    -- end
end

function Skarner:LaneClear()
    if Attack:IsActive() then return end
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
    Callback.Add("Tick", function() self:onTick() end)
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

function Maokai:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end    
    if self.Menu.Combo.InsecQ:Value() then
        local allies = ObjectManager:GetAllyHeroes(self.Menu.Combo.InsecRange:Value())
        for i, ally in ipairs(allies) do
            if not ally.isMe then
                Qtoward = ally.pos
            end
        end
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
end

function Maokai:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.Menu.Combo.Rrange:Value())
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

    if Attack:IsActive() then return end
    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    Callback.Add("Tick", function() self:onTick() end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 850, Speed = 1000, Collision = false}
    self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 800, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
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

function Gragas:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
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

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
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

    if Attack:IsActive() then return end
    local target = TargetSelector:GetTarget(self.eSpell.Range)
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
    local target = TargetSelector:GetTarget(1000)
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
    local heroes = ObjectManager:GetEnemyHeroes(self.rSpell.Range - 150)
    for i, hero in ipairs(heroes) do
        if not MapPosition:intersectsWall(myHero.pos, hero.pos) and isSpellReady(_R) and lastR + 350 < GetTickCount() and isImmobile(hero) then
            Control.CastSpell(HK_R, Vector(hero.pos):Extended(Vector(myHero.pos), -150))
            lastR = GetTickCount()
        end
    end
end

function Gragas:JungleClear()
    if Attack:IsActive() then return end
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

    for i = GameParticleCount(), 1, -1 do
    local particle = GameParticle(i)
        if particle and particle.name:find("Gragas") and particle.name:find("_Q_Ally") and getEnemyCount(300, particle.pos) >= 1 then
            Control.CastSpell(HK_Q)
        end
    end
end

function Gragas:KillSteal()
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(self.rSpell.Range)
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
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg)
end

function Gragas:getEDmg(target)	
    local elvl = myHero:GetSpellData(_E).level
    local ebaseDmg  = 35 * elvl + 45
    local eapDmg = myHero.ap * 0.6
    local eDmg = ebaseDmg + eapDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg)
end

function Gragas:getRDmg(target)	
    local rlvl = myHero:GetSpellData(_R).level
    local rbaseDmg  = 100 * rlvl + 100
    local rapDmg = myHero.ap * 0.8
    local rDmg = rbaseDmg + rapDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg)
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

--------------------------------

class "Milio"
        
function Milio:__init()
    print("Zgjfjfl_Milio Loaded")
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)    
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1000, Speed = 1200, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.qnocolSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1000, Speed = 1200, Collision = false}
	self.qnocolSpellextended = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 45, Range = 1500, Speed = 1200, Collision = false}
	self.qantidashSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius =35, Range = 1000, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = { Range = 650 }
    self.eSpell = { Range = 650 }
    self.rSpell = { Range = 700 }  
end

function Milio:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgMilio", name = "Zgjfjfl Milio"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "QBD", name = "[Q] ball collision minion bounces distance", value = 400, min = 100, max = 500, step = 50})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "RHP", name = "UseR when ally or self <= X hp%", value = 20, min = 0, max = 100, step = 5})
        self.Menu.Combo:MenuElement({type = MENU,id = "Rhealtarget", name = "UseR On"})
            DelayAction(function()
                for i, Hero in pairs(getAllyHeroes()) do
                    self.Menu.Combo.Rhealtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 30, min = 0, max = 100})

    self.Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
        self.Menu.AutoW:MenuElement({id = "W", name = "[W]Auto heal", toggle = true, value = true})
        self.Menu.AutoW:MenuElement({id = "WHP", name = "When ally or self <= X hp%", value = 50, min = 0, max = 100, step = 5})
        self.Menu.AutoW:MenuElement({type = MENU,id = "Wtarget", name = "Use On"})
            DelayAction(function()
                for i, Hero in pairs(getAllyHeroes()) do
                    self.Menu.AutoW.Wtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
        self.Menu.AutoE:MenuElement({id = "E", name = "[E]Auto shield", toggle = true, value = true})
        self.Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
            DelayAction(function()
                for i, Hero in pairs(getAllyHeroes()) do
                    self.Menu.AutoE.Etarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
        self.Menu.AutoR:MenuElement({id = "R", name = "[R]Auto clears ally CC", toggle = true, value = true})
            self.Menu.AutoR:MenuElement({type = MENU, id = "CC", name = "CC Types"})			
            self.Menu.AutoR.CC:MenuElement({ id = "Stun", name = "Use on Stun", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Taunt", name = "Use on Taunt", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Berserk", name = "Use on Berserk", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Snare", name = "Use on Snare", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Fear", name = "Use on Fear", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Charm", name = "Use on Charm", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Suppression", name = "Use on Suppression", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Disarm", name = "Use on Disarm", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Asleep", name = "Use on Asleep", value = true})
        self.Menu.AutoR:MenuElement({type = MENU,id = "Rclearstarget", name = "Clears target"})
            DelayAction(function()
                for i, Hero in pairs(getAllyHeroes()) do
                    self.Menu.AutoR.Rclearstarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "AutoQ", name = "AutoQ"})
        self.Menu.AutoQ:MenuElement({id = "AntiDash", name = "AutoQ Anti-Dash",toggle = true, value = true})
        self.Menu.AutoQ:MenuElement({type = MENU,id = "AntiTarget", name = "Use On"})
            DelayAction(function()
                for i, Hero in pairs(getEnemyHeroes()) do
                    self.Menu.AutoQ.AntiTarget:MenuElement({id = Hero.charName, name = Hero.charName, value = false})		
                end		
            end,0.2)

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function Milio:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if self.Menu.AutoW.W:Value() then
        self:AutoW()
    end
    if self.Menu.AutoE.E:Value() then
        self:AutoE()
    end
    if self.Menu.AutoR.R:Value() then
        self:AutoR()
    end
    if self.Menu.AutoQ.AntiDash:Value() then
        self:AutoQAntiDash()
    end    
end

function Milio:Combo()

    local target = TargetSelector:GetTarget(1500)
    if isValid(target) and target.pos2D.onScreen then

        if self.Menu.Combo.Q:Value() then
            self:CastQ(target)
        end
    end

    if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() then
    local heroes = ObjectManager:GetAllyHeroes(self.rSpell.Range)
        for i, hero in ipairs(heroes) do
            if self.Menu.Combo.Rhealtarget[hero.charName] and self.Menu.Combo.Rhealtarget[hero.charName]:Value() then 
                if hero.health/hero.maxHealth <= self.Menu.Combo.RHP:Value()/100 and getEnemyCount(1200, hero.pos) > 0 then
                    Control.CastSpell(HK_R)
                    lastR = GetTickCount()
                end
            end
        end
    end
end

function Milio:Harass()

    local target = TargetSelector:GetTarget(1500)
    if isValid(target) and target.pos2D.onScreen then
            
        if self.Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
            self:CastQ(target)
        end
    end
end

function Milio:CastQ(target)
    if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
        local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, self.qSpell.CollisionTypes, target.networkID)
        if collisionCount >= 1 and myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.QBD:Value() + 1000 then
            local minion = collisionObjects[1]
            if isValid(minion) and minion.pos:DistanceTo(target.pos) < 400 and minion.pos:DistanceTo(myHero.pos) < 1000 then
                if myHero.pos:DistanceTo(target.pos) < 1000 then
                    local Pred = GGPrediction:SpellPrediction(self.qnocolSpell)
                    Pred:GetPrediction(target, myHero)
                    if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                        Control.CastSpell(HK_Q, Pred.CastPosition)
                        lastQ = GetTickCount()
                    end
                else
                    local Pred = GGPrediction:SpellPrediction(self.qnocolSpellextended)
                    Pred:GetPrediction(target, myHero)
                    if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                        Control.CastSpell(HK_Q, minion)
                        lastQ = GetTickCount()
                    end
                end
            end
        elseif collisionCount <= 1 and myHero.pos:DistanceTo(target.pos) < 1000 then
            local Pred = GGPrediction:SpellPrediction(self.qSpell)
            Pred:GetPrediction(target, myHero)
            if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                Control.CastSpell(HK_Q, Pred.CastPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function Milio:AutoW()
    if isSpellReady(_W) and myHero:GetSpellData(_W).name == "MilioW" and lastW + 350 < GetTickCount() then
    local heroes = ObjectManager:GetAllyHeroes(self.wSpell.Range)
        for i, hero in ipairs(heroes) do
            if self.Menu.AutoW.Wtarget[hero.charName] and self.Menu.AutoW.Wtarget[hero.charName]:Value() then
                if hero.health/hero.maxHealth <= self.Menu.AutoW.WHP:Value()/100 and getEnemyCount(1200, hero.pos) > 0 then
                    Control.CastSpell(HK_W, hero)
                    lastW = GetTickCount()
                end
            end
        end
    end
end

function Milio:AutoE()
    if isSpellReady(_E) and lastE + 250 < GetTickCount() then
        local enemies = ObjectManager:GetEnemyHeroes(2500)
        local allies = ObjectManager:GetAllyHeroes(self.eSpell.Range)
        for i, enemy in ipairs(enemies) do
            if isValid(enemy) then
                for j, ally in ipairs(allies) do
                    if self.Menu.AutoE.Etarget[ally.charName] and self.Menu.AutoE.Etarget[ally.charName]:Value() then
                        local canuse = false
                        if enemy.isChanneling then 
                            if enemy.activeSpell.target == ally.handle then
                                canuse = true
                            else
                                local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, enemy.activeSpell.placementPos, enemy.pos)
                                local width = ally.boundingRadius
                                if enemy.activeSpell.width > 0 then
                                    width = width + enemy.activeSpell.width
                                end
                                if isOnSegment and isInRange(point, ally.pos, width) then
                                    canuse = true
                                end
                            end
                        elseif enemy.activeSpell.target == ally.handle then --autoattack
                            canuse = true
                        end
                        if canuse then
                            Control.CastSpell(HK_E, ally)
                            lastE = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end

function Milio:AutoR()
    if isSpellReady(_R) and lastR + 250 < GetTickCount() then
        local heroes = ObjectManager:GetAllyHeroes(self.rSpell.Range)
        for i, hero in ipairs(heroes) do
            if self.Menu.AutoR.Rclearstarget[hero.charName] and self.Menu.AutoR.Rclearstarget[hero.charName]:Value() and self:RCleans(hero) then
                Control.CastSpell(HK_R)
                lastR = GetTickCount()
            end  
        end
    end
end

function Milio:RCleans(unit)
    local CleanBuffs = {
        [5]  = self.Menu.AutoR.CC.Stun:Value(),
        [8]  = self.Menu.AutoR.CC.Taunt:Value(),
        [9]  = self.Menu.AutoR.CC.Berserk:Value(),
        [12] = self.Menu.AutoR.CC.Snare:Value(),
        [22] = self.Menu.AutoR.CC.Fear:Value(),
        [23] = self.Menu.AutoR.CC.Charm:Value(),
        [25] = self.Menu.AutoR.CC.Suppression:Value(),
        [32] = self.Menu.AutoR.CC.Disarm:Value(),
        [35] = self.Menu.AutoR.CC.Asleep:Value()
    }    
	
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.duration > 0.5 then
            if CleanBuffs[buff.type] then
                return true
            end
        end
    end
    return false
end

function Milio:AutoQAntiDash()
    local enemies = ObjectManager:GetEnemyHeroes(self.qSpell.Range)
    for i, enemy in ipairs(enemies) do
        if isValid(enemy) and self.Menu.AutoQ.AntiTarget[enemy.charName] and self.Menu.AutoQ.AntiTarget[enemy.charName]:Value()then
            if enemy.pathing.isDashing and enemy.pathing.hasMovePath and enemy.pathing.dashSpeed > 0 then
                if myHero.pos:DistanceTo(enemy.pathing.startPos) > myHero.pos:DistanceTo(enemy.pathing.endPos) then
                    if isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
                        local Pred = GGPrediction:SpellPrediction(self.qantidashSpell)
                        Pred:GetPrediction(enemy, myHero)
                        if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                            Control.CastSpell(HK_Q, Pred.CastPosition)
                            lastQ = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end

function Milio:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
        Draw.Circle(myHero.pos, 1000, 1, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
        Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 0, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

----------------------------------------

class "AurelionSol"
        
function AurelionSol:__init()	     
    print("Zgjfjfl_AurelionSol Loaded")
    self:LoadMenu()

    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)
    Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 75, Range = 750, Speed = 1500, Collision = false}
    self.wSpell = { Range = 1200 } 
    self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 750, Speed = 1300, Collision = false}
    self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 275, Range = 1250, Speed = 500, Collision = false}
end

function AurelionSol:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgAurelionSol", name = "Zgjfjfl AurelionSol"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "Rcount", name = "UseR when hit X enemies", value = 3, min = 1, max = 5})
        self.Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W2", name = "[W] Range in minimap", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function AurelionSol:onTick()

    passivecount = getBuffData(myHero, "AurelionSolPassive").stacks
    self.qSpell.Range = 740 + 10 * myHero.levelData.lvl
    self.eSpell.Range = 740 + 10 * myHero.levelData.lvl
    self.wSpell.Range = 1200 + 7.5 * passivecount
    self.eSpell.Radius = math.sqrt(275^2+16.93^2 * passivecount)
    self.rSpell.Radius = math.sqrt(275^2+16.93^2 * passivecount)
    if myHero:GetSpellData(_R).name == "AurelionSolR2" then
        self.rSpell.Radius = math.sqrt(388.91^2+21.85^2 * passivecount)
    end

    Etarget = TargetSelector:GetTarget(self.eSpell.Range)
    Rtarget = TargetSelector:GetTarget(self.rSpell.Range)

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end

    if self.Menu.Combo.Rsm:Value() then
        self:SemiManualR()
    end

    if haveBuff(myHero, "AurelionSolQ") or myHero:GetSpellData(_W).name == "AurelionSolWToggle" then
        Orbwalker:SetMovement(false)
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetMovement(true)
        Orbwalker:SetAttack(true)
    end

    if Control.IsKeyDown(HK_Q) then
        DelayAction(function()
            if myHero.activeSpell.isCharging == false then
                Control.KeyUp(HK_Q)
            end
        end, 0.35)
    end
end

function AurelionSol:OnPreAttack(args)
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        if self.Menu.Combo.DisableAA:Value() then
            args.Process = false
        end
    end
end

function AurelionSol:Combo()
    if isValid(Rtarget) then
        if self.Menu.Combo.R:Value() and myHero.activeSpell.isCharging == false then 
            self:CastRAoE(Rtarget)
        end
    end
    if isValid(Etarget) then
        if self.Menu.Combo.Q:Value() and not isSpellReady(_E) then
            self:CastQ(Etarget)
        end
        if self.Menu.Combo.E:Value() and myHero.activeSpell.isCharging == false then
            self:CastEAoE(Etarget)
        end
    end
end

function AurelionSol:Harass()
    if isValid(Etarget) then
        if self.Menu.Harass.E:Value() then
            self:CastEAoE(Etarget)
        end
    end
end

function AurelionSol:SemiManualR()
    if isValid(Rtarget) then
        if isSpellReady(_R) and lastR + 250 < GetTickCount() then
            local enemies = GetEnemiesAtPos(self.rSpell.Range + self.rSpell.Radius/2, self.rSpell.Radius, Rtarget.pos,Rtarget)
            if #enemies >= 2 then
                local AoEPos = CalculateBestCirclePosition(enemies, self.rSpell.Radius/2, true, self.rSpell.Range, self.rSpell.Speed, self.rSpell.Delay)
                Control.CastSpell(HK_R, AoEPos)
                lastR = GetTickCount()
            else
                castSpellHigh(self.rSpell, HK_R, Rtarget)
                lastR = GetTickCount()
            end
        end
    end
end

function AurelionSol:CastEAoE(target)
    if isSpellReady(_E) and lastE + 350 < GetTickCount() then
        local enemies = GetEnemiesAtPos(self.eSpell.Range + self.eSpell.Radius/2, self.eSpell.Radius, target.pos,target)
        if #enemies >= 2 then
            local AoEPos = CalculateBestCirclePosition(enemies, self.eSpell.Radius/2, true, self.eSpell.Range, self.eSpell.Speed, self.eSpell.Delay)
            Control.CastSpell(HK_E, AoEPos)
            lastE = GetTickCount()
        else
            castSpellHigh(self.eSpell, HK_E, target)
            lastE = GetTickCount()
        end
    end
end

function AurelionSol:CastRAoE(target)
    if isSpellReady(_R) and lastR + 250 < GetTickCount() then
        local enemies = GetEnemiesAtPos(self.rSpell.Range + self.rSpell.Radius/2, self.rSpell.Radius, target.pos,target)
        local Rcount = self.Menu.Combo.Rcount:Value()
        if Rcount > 1 and #enemies >= Rcount then
            local AoEPos = CalculateBestCirclePosition(enemies, self.rSpell.Radius/2, true, self.rSpell.Range, self.rSpell.Speed, self.rSpell.Delay)
            Control.CastSpell(HK_R, AoEPos)
            lastR = GetTickCount()
        elseif Rcount == 1 and #enemies > 0 then
            castSpellHigh(self.rSpell, HK_R, target)
            lastR = GetTickCount()
        end
    end
end

function AurelionSol:CastQ(target)
    if isSpellReady(_Q) then
        Control.KeyDown(HK_Q)
        Control.SetCursorPos(target)
        DelayAction(function()
            Control.KeyUp(HK_Q)
        end, 9999)
    end
end

function AurelionSol:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
        Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
        Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 255, 255))
    end
    if self.Menu.Draw.W2:Value() and isSpellReady(_W) then
        Draw.CircleMinimap(myHero.pos, self.wSpell.Range, 1, Draw.Color(200, 0, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R) then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

------------------------------------

class "Heimerdinger"
        
function Heimerdinger:__init()	     
    print("Zgjfjfl_Heimerdinger Loaded")
    self:LoadMenu()

    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)    
    Q = {Delay = 0.25, Range = 350}
    W = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 1200, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}} 
    E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 970, Speed = 1200, Collision = false}
    E2 = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1500, Speed = 1200, Collision = false}
end

function Heimerdinger:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgHeimerdinger", name = "Zgjfjfl Heimerdinger"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "QRange1", name = "QTurret distance self", value = 300, min = 100, max = 350, step = 10})
        self.Menu.Combo:MenuElement({id = "QRange2", name = "Cast[Q] distance target ", value = 700, min = 500, max = 1000, step = 50})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RQ", name = "[RQ]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RQCount", name = "UseRQ when X enemies near", value = 2, min = 1, max = 5})
        self.Menu.Combo:MenuElement({id = "RW", name = "[RW] UseRW if can kill target", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RE", name = "[RE]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "RECount", name = "UseRE when X enemies near", value = 3, min = 1, max = 5})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
        self.Menu.Misc:MenuElement({id = "QAmmo", name = "Save 1 QTurret in Combo", toggle = true, value = false})
        self.Menu.Misc:MenuElement({id = "QAHp", name = "When target <=HP% use last QTurret", value = 20, min = 0, max = 100, step = 5})
        self.Menu.Misc:MenuElement({id = "Flee", name = "Flee [RE] or [E]", toggle = true, value = false})
        self.Menu.Misc:MenuElement({id = "RW", name = "Semi-Manual [RW] Key", key = string.byte("Z")})
        self.Menu.Misc:MenuElement({id = "RE", name = "Semi-Manual [RE] Key", key = string.byte("T")})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E2", name = "[E2] Range", toggle = true, value = false})
end

function Heimerdinger:onTick()
    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end
    if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.spellWasCast then return end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
        self:Flee()
    end
    if self.Menu.Misc.RW:Value() then
        self:SemiManualRW()
    end
    if self.Menu.Misc.RE:Value() then
        self:SemiManualRE()
    end
end

function Heimerdinger:Combo()
    if Attack:IsActive() then return end
    local target = TargetSelector:GetTarget(1500)
    if isValid(target) then
        if self.Menu.Combo.RQ:Value() and isSpellReady(_Q) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.QRange2:Value() and getEnemyCount(self.Menu.Combo.QRange2:Value(), myHero.pos) >= self.Menu.Combo.RQCount:Value() then
            self:CastR()
            self:CastQ(target)
        elseif self.Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.QRange2:Value() and getEnemyCount(self.Menu.Combo.QRange2:Value(), myHero.pos) >= 1 then
            if not self.Menu.Misc.QAmmo:Value() then
                self:CastQ(target)
            else
                if target.health/target.maxHealth >= self.Menu.Misc.QAHp:Value()/100 then
                    if myHero:GetSpellData(_Q).ammo > 1 then
                        self:CastQ(target)
                    end
                else
                    self:CastQ(target)
                end
            end
        end

        if self.Menu.Combo.RE:Value() and isSpellReady(_E) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < E2.Range and getEnemyCount(275, target.pos) >= self.Menu.Combo.RECount:Value() then
            self:CastR()
            self:CastE2(target)
        elseif self.Menu.Combo.E:Value() and isSpellReady(_E) then
            if haveBuff(myHero, "HeimerdingerR") then
                if myHero.pos:DistanceTo(target.pos) < E2.Range then
                    self:CastE2(target)
                end
            else
                if myHero.pos:DistanceTo(target.pos) < E.Range then
                    self:CastE(target)
                end
            end
        end

        if self.Menu.Combo.RW:Value() and isSpellReady(_W) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < W.Range and self:getRWDmg(target) >= target.health then
            self:CastR()
            self:CastW(target)
        elseif self.Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < W.Range then
            self:CastW(target)
        end
    end
end

function Heimerdinger:Harass()
    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1500)
    if isValid(target) then
        if self.Menu.Harass.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < E.Range then
            self:CastE(target)
        end
        if self.Menu.Harass.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < W.Range then
            self:CastW(target)
        end
    end
end

function Heimerdinger:SemiManualRW()
    local target = TargetSelector:GetTarget(1500)
    if isValid(target) then
        if isSpellReady(_W) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < W.Range then
            self:CastR()
            self:CastW(target)
        end
    end
end

function Heimerdinger:SemiManualRE()
    local target = TargetSelector:GetTarget(1500)
    if isValid(target) then
        if isSpellReady(_E) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < E2.Range then
            self:CastR()
            self:CastE2(target)
        end
    end
end

function Heimerdinger:Flee()
    local target = TargetSelector:GetTarget(1500)
    if isValid(target) and self.Menu.Misc.Flee:Value() then
        if isSpellReady(_E) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < E2.Range then
            self:CastR()
            self:CastE2(target)
        else
            if isSpellReady(_E) and not isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < E.Range then
                self:CastE(target)
            end
        end
    end
end

function Heimerdinger:CastQ(target)
    local Castpos = myHero.pos:Extended(target.pos, self.Menu.Combo.QRange1:Value())
    if lastQ + 350 < GetTickCount() then
        Control.CastSpell(HK_Q, Castpos)
        lastQ = GetTickCount()
    end
end

function Heimerdinger:CastW(target)
    if lastW + 350 < GetTickCount() then
        local pred = GGPrediction:SpellPrediction(W)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_W, pred.CastPosition)	
            lastW = GetTickCount()
        end
    end
end

function Heimerdinger:CastE(target)
    if lastE + 350 < GetTickCount() then
        local pred = GGPrediction:SpellPrediction(E)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_E, pred.CastPosition)	
            lastE = GetTickCount()
        end
    end
end

function Heimerdinger:CastE2(target)
    if lastE + 350 < GetTickCount() then
        local pred = GGPrediction:SpellPrediction(E2)
        pred:GetPrediction(target, myHero)
        if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
            Control.CastSpell(HK_E, pred.CastPosition)	
            lastE = GetTickCount()
        end
    end
end

function Heimerdinger:CastR()
    if not haveBuff(myHero, "HeimerdingerR") then
        Control.CastSpell(HK_R)
    end
end

function Heimerdinger:getRWDmg(target)
    local rlvl = myHero:GetSpellData(_R).level
    local baseDmg  = 194.5 * rlvl + 308.5
    local apDmg = myHero.ap * 1.83
    local rwDmg = baseDmg + apDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rwDmg)
end

function Heimerdinger:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q) then
        Draw.Circle(myHero.pos, Q.Range, 1, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W) then
        Draw.Circle(myHero.pos, W.Range, 1, Draw.Color(255, 0, 255, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E) then
        Draw.Circle(myHero.pos, E.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if self.Menu.Draw.E2:Value() and isSpellReady(_E) then
        Draw.Circle(myHero.pos, E2.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

-----------------------------------

class "Briar"
        
function Briar:__init()	     
    print("Zgjfjfl_Briar Loaded")
    self:LoadMenu()
    Callback.Add("Tick", function() self:onTickEvent() end)    
    Q = {Range = 450}
    W = {Range = 1000}
    E = {Range = 600}
    R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 160, Range = 10000, Speed = 2000, Collision = false} 
end

function Briar:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgBriar", name = "Zgjfjfl Briar"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "W2", name = "[W2] in Combo", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "W2Kill", name = "Auto [W2] can kills", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
        self.Menu.Combo:MenuElement({id = "EWall", name = "[E] to wall when target isImmobile", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})


    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
        self.Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
        self.Menu.Clear:MenuElement({id = "W2", name = "[W2]", toggle = true, value = true})
        self.Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
        self.Menu.Clear:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
end

function Briar:onTickEvent()
    if haveBuff(myHero, "BriarWFrenzyBuff") or haveBuff(myHero, "BriarRSelf") or myHero.activeSpell.name == "BriarE" then
        Orbwalker:SetMovement(false)
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetMovement(true)
        Orbwalker:SetAttack(true)
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
        self:JungleClear()
    end
    if self.Menu.Combo.RM:Value() then
        self:RSemiManual()
    end
    if self.Menu.Combo.W2Kill:Value() then
        self:AutoW2()
    end
end

function Briar:Combo()

    if Attack:IsActive() then return end

    local target = TargetSelector:GetTarget(1000)
    if isValid(target) then

        if self.Menu.Combo.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= Q.Range and getDistance(myHero.pos, target.pos) > Data:GetAutoAttackRange(myHero) then
            Control.CastSpell(HK_Q, target)
        end

        if self.Menu.Combo.W:Value() and not haveBuff(myHero, "BriarRSelf") and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and getDistance(myHero.pos, target.pos) < W.Range then
            Control.CastSpell(HK_W, target)
        end 
       
        if self.Menu.Combo.W2:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and getDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
            Control.CastSpell(HK_W)
        end

        if self.Menu.Combo.EWall:Value() and isSpellReady(_E) then
            local Pos = myHero.pos:Extended(target.pos, E.Range)
            local Pos2 = MapPosition:getIntersectionPoint3D(myHero.pos, Pos)
            if Pos2 and isImmobile(target) and getDistance(myHero.pos, target.pos) < E.Range then
                self:CastE(target)
            end
        end

        if self.Menu.Combo.E:Value() and isSpellReady(_E) and getDistance(myHero.pos, target.pos) < E.Range and myHero.health/myHero.maxHealth <= self.Menu.Combo.EHP:Value()/100 then
            self:CastE(target)
        end
    end
end

function Briar:RSemiManual()
    local target = TargetSelector:GetTarget(R.Range)
    if isValid(target) then
        if isSpellReady(_R) then
            local pred = GGPrediction:SpellPrediction(R)
            pred:GetPrediction(target, myHero)
            if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                Control.CastSpell(HK_R, pred.CastPosition)
            end
        end
    end
end

function Briar:CastE(target)
    Control.SetCursorPos(target)
    Control.KeyDown(HK_E)
    DelayAction(function() Control.SetCursorPos(mousePos) end, 0.1)
    DelayAction(function() Control.KeyUp(HK_E) end, 1)
end


function Briar:JungleClear()
    if Attack:IsActive() then return end
    local target = HealthPrediction:GetJungleTarget()
    if isValid(target) then

        if self.Menu.Clear.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= Q.Range then
            Control.CastSpell(HK_Q, target)
        end

        if self.Menu.Clear.W:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and getDistance(myHero.pos, target.pos) < W.Range then
            Control.CastSpell(HK_W, target)
        end 
       
        if self.Menu.Clear.W2:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and getDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
            Control.CastSpell(HK_W)
        end

        if self.Menu.Clear.E:Value() and isSpellReady(_E) and getDistance(myHero.pos, target.pos) < E.Range and myHero.health/myHero.maxHealth <= self.Menu.Clear.EHP:Value()/100 then
            self:CastE(target)
        end
    end
end

function Briar:AutoW2()
    local target = TargetSelector:GetTarget(1000)
    if isValid(target) then

        local W2Dmg = self:getW2BonusDmg(target)      
        if isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and getDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and W2Dmg >= (target.health + target.shieldAD) then
            Control.CastSpell(HK_W)
        end
    end
end


function Briar:getW2BonusDmg(target)
    local Wlvl = myHero:GetSpellData(_W).level
    local baseDmg  = 15 * Wlvl - 10
    local adDmg = myHero.totalDamage * 0.05
    local bonusDmg = (0.1 + 0.035 * math.floor(myHero.bonusDamage/100))* (target.maxHealth - target.health)
    local Dmg = baseDmg + adDmg + bonusDmg
    return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, Dmg)
end


