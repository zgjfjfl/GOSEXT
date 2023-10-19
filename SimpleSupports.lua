local Heroes ={"Lux", "Zyra", "Brand"}

if not table.contains(Heroes, myHero.charName) then 
	print('Supports SimpleAio not supported ' .. myHero.charName)
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
local MathHuge = math.huge
local MathMin = math.min
local MathMax = math.max
local MathFloor = math.floor

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0

local Orbwalker, TargetSelector, ObjectManager, HealthPrediction, Attack, Damage, Spell, Data, Cursor

Callback.Add("Load", function()

	Orbwalker = _G.SDK.Orbwalker
	TargetSelector = _G.SDK.TargetSelector
	ObjectManager = _G.SDK.ObjectManager
	HealthPrediction = _G.SDK.HealthPrediction
	Attack = _G.SDK.Attack
	Damage = _G.SDK.Damage
	Spell = _G.SDK.Spell
	Data = _G.SDK.Data
	Cursor = _G.SDK.Cursor

    	if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
	end

	Orbwalker:OnPreAttack(function(args)
		if args.Process and Menu.SupportMode:Value() and Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
			if args.Target.type ~= Obj_AI_Hero then
				args.Process = false
                        	return
			end
		end
	end)
end)

local function IsReady(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function IsValid(unit)
	if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead) then
		return true
	end
	return false
end

local function GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

local function GetDistance(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

local function GetEnemyHeroes()
	local EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local Hero = GameHero(i)
		if Hero.isEnemy and not Hero.dead then
			TableInsert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

local function GetAllyHeroes()
	local AllyHeroes = {}
	for i = 1, GameHeroCount() do
		local Hero = GameHero(i)
		if Hero.isAlly then
			TableInsert(AllyHeroes, Hero)
		end
	end
	return AllyHeroes
end

local function GetEnemyTurrets()
	local EnemyTurrets = {}
	for i = 1, GameTurretCount() do
		local turret = GameTurret(i)
		if turret and turret.isEnemy then
			TableInsert(EnemyTurrets, turret)
		end
	end
	return EnemyTurrets
end

local function IsUnderTurret(unit)
	for i, turret in ipairs(GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then 
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

local function HaveBuff(unit, buffName)
	for i = 1, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffName and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function GetBuffData(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return buff
		end
	end
	return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function GetEnemyCount(range, unit)
	local count = 0
		for i, hero in ipairs(GetEnemyHeroes()) do
		local Range = range * range
		if GetDistanceSqr(unit, hero.pos) < Range and IsValid(hero) then
			count = count + 1
		end
	end
	return count
end

local function GetMinionCount(range, unit)
	local count = 0
	for i = 1,GameMinionCount() do
		local hero = GameMinion(i)
		local Range = range * range
		if hero.team ~= TEAM_ALLY and hero.dead == false and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function GetAllyCount(range, unit)
	local count = 0
	for i, hero in ipairs(GetAllyHeroes()) do
		local Range = range * range
		if GetDistanceSqr(unit, hero.pos) < Range and IsValid(hero) then
			count = count + 1
		end
	end
	return count
end

local function IsImmobile(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35) and buff.count > 0 then
			return true
		end
	end
	return false
end

local function IsInvulnerable(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.type == 18 and buff.count > 0 then
			return true
		end
	end
	return false
end

local function Recalling()
	for i, Buff in pairs(GetBuffs(myHero)) do
		if Buff.name == "recall" and Buff.duration > 0 then
			return true
		end
	end
	return false
end

local function IsInRange(v1, v2, range)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	if dx * dx + dz * dz <= range * range then
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
			TableInsert(distantEnemies, enemy)
		else
			TableInsert(newCluster, enemy)
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
			TableInsert(newCluster, closestDistantEnemy)
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

local function GetEnemiesAtPos(checkrange, range, pos, target)
	local enemies = ObjectManager:GetEnemyHeroes(checkrange)
	local results = {}
	for i = 1, #enemies do 
		local enemy = enemies[i]
		local Range = range * range
		if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) and enemy ~= target then
			TableInsert(results, enemy)
		end
	end
	TableInsert(results, target)
	return results
end

--------------------------------------

Menu = MenuElement({type = MENU, id = "Support "..myHero.charName, name = "Support "..myHero.charName})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)",value = true})

--------------------------------------
class "Lux"
        
function Lux:__init()	     
	print("Support Lux Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1300, Speed = 1200, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	WSpell = { Range = 1200 }
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 310, Range = 1250, Speed = 1200, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 100, Range = 3400, Speed = MathHuge, Collision = false}
end

function Lux:LoadMenu() 
            
    	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R when hit X enemies", min = 1, max = 5, value = 3, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Shield", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Whp", name = "Auto [W] allies or self Low hp%", value = true, min = 0, max = 100, value = 30, step = 5})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "R", name = "Auto [R] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "R", name = "Auto [R] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function Lux:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.spellWasCast then
		return
	end
	if Cursor.Step > 0 then
		return
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	self:AutoQ()
	self:AutoW()
	self:AutoE()
	self:AutoR()  
end

function Lux:Combo()
	local target = TargetSelector:GetTarget(1500)
    	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
    	end

	if Menu.Combo.R:Value() and IsReady(_R) then						
		local RPrediction = GGPrediction:SpellPrediction(RSpell)
		local minhitchance = 2
		local aoeresult = RPrediction:GetAOEPrediction(myHero)
		local bestaoe = nil
		local bestcount = 0
		local bestdistance = 1000
		for i = 1, #aoeresult do
			local aoe = aoeresult[i]
			if aoe.HitChance >= minhitchance and aoe.TimeToHit <= 3 and aoe.Count >= Menu.Combo.RCount:Value() then
				if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
					bestdistance = aoe.Distance
					bestcount = aoe.Count
					bestaoe = aoe
				end
			end
		end
		if bestaoe and lastR + 1100 < GetTickCount() then
			Control.CastSpell(HK_R, bestaoe.CastPosition)
			lastR = GetTickCount()
		end
	end
end

function Lux:Harass()
	local target = TargetSelector:GetTarget(ESpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
			self:CastGGPred(HK_E, target)
		end
	end
end

function Lux:AutoQ()
	if IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.Q:Value() and IsImmobile(target) then
					self:CastGGPred(HK_Q, target)
				end
				if Menu.Kill.Q:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetQDmg(target) then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function Lux:AutoW()
	if Menu.Auto.W:Value() and IsReady(_W) and lastW + 350 < GetTickCount() then
		if myHero.health/myHero.maxHealth <= Menu.Auto.Whp:Value()/100 and GetEnemyCount(1000, myHero.pos) > 0 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		local allies = ObjectManager:GetAllyHeroes(WSpell.Range)
		for i, ally in ipairs(allies) do			
			if IsValid(ally) and not ally.isMe and ally.health/ally.maxHealth <= Menu.Auto.Whp:Value()/100 and GetEnemyCount(1000, ally.pos) > 0 then
				Control.CastSpell(HK_W, ally.pos)
				lastW = GetTickCount()
			end
		end
	end
end

function Lux:AutoE()
	if IsReady(_E) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if IsValid(target) and target.pos2D.onScreen then
				local LuxBuff = HaveBuff(myHero, "LuxLightStrikeKugel")
				local targetBuff = HaveBuff(target, "luxeslow")
				if LuxBuff and targetBuff then
					Control.CastSpell(HK_E)
				end
				if myHero.pos:DistanceTo(target.pos) < ESpell.Range then
					if Menu.Auto.E:Value() and IsImmobile(target) then
						self:CastGGPred(HK_E, target)
					end
					if Menu.Kill.E:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetEDmg(target) then
						self:CastGGPred(HK_E, target)
					end
				end
			end
		end
	end	
end

function Lux:AutoR()
	if IsReady(_R) then
		local enemies = ObjectManager:GetEnemyHeroes(RSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.R:Value() and IsImmobile(target) then
					self:CastGGPred(HK_R, target)
				end
				if Menu.Kill.R:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetRDmg(target) then
					self:CastGGPred(HK_R, target)
				end
			end
		end
	end
end

function Lux:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) and lastQ + 350 < GetTickCount() then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) and myHero:GetSpellData(_E).name == "LuxLightStrikeKugel" and lastE + 350 < GetTickCount() then
			local castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), 1100)
			if myHero.pos:DistanceTo(unit.pos) <= 1100 then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
				lastE = GetTickCount()
			elseif myHero.pos:DistanceTo(unit.pos) > 1100 and myHero.pos:DistanceTo(unit.pos) <= 1250 then
				Control.CastSpell(HK_E, castPos)
				lastE = GetTickCount()
			end
		end		
	
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) and lastR + 1100 < GetTickCount() then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
			lastR = GetTickCount()
		end	
	end
end

function Lux:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
    	local QDmg = ({80, 120, 160, 200, 240})[level] + 0.6 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Lux:GetEDmg(target)
    	local level = myHero:GetSpellData(_E).level
    	local EDmg = ({70, 120, 170, 220, 270})[level] + 0.8 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function Lux:GetRDmg(target)
	local R2Dmg = 0
	local buff = GetBuffData(target, "LuxIlluminatingFraulein")
	local level = myHero:GetSpellData(_R).level
    	local R1Dmg = ({300, 400, 500})[level] + 1.2 * myHero.ap
	if buff.count > 0 and buff.duration > 1.25 then
 		R2Dmg = 10 + 10 * myHero.levelData.lvl + myHero.ap * 0.2
	end
	local RDmg = R1Dmg + R2Dmg
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function Lux:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

--------------------------------------
class "Zyra"
        
function Zyra:__init()	     
	print("Support Zyra Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 100, Range = 800, Speed = MathHuge, Collision = false}
	WSpell = {Range = 850}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1100, Speed = 1150, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 500, Range = 950, Speed = MathHuge, Collision = false}
end

function Zyra:LoadMenu() 
            
    	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RKill", name = "Combo [R] If TotalDmg Can Kill", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] If Hit X Enemies", value = 2, min = 1, max = 5, step = 1})
        Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Passive when castingQ/E", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function Zyra:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.spellWasCast then
		return
	end
	if Cursor.Step > 0 then
		return
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	self:AutoQ()
	self:AutoE()
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end 
end

function Zyra:Combo()
	local target = TargetSelector:GetTarget(1200)
    	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.R:Value() and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < RSpell.Range then
			local canUseR = true
			if IsReady(_Q) and self:GetQDmg(target) >= target.health then
            			canUseR = false
        		end
			if IsReady(_E) and self:GetEDmg(target) >= target.health then
            			canUseR = false
        		end
			if Menu.Combo.RKill:Value() and canUseR then
				local Hp = (target.health + target.shieldAD + target.shieldAP)
				if Hp < self:ComboDmg(target) then
					self:CastGGPred(HK_R, target)
				end
			end
			self:CastRAoE(target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end						
	end
end

function Zyra:Harass()
	local target = TargetSelector:GetTarget(QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Zyra:AutoQ()
	if IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
				if Menu.Auto.Q:Value() and IsImmobile(target) then
					self:CastGGPred(HK_Q, target)
				end
				if Menu.Kill.Q:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetQDmg(target) then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function Zyra:AutoE()
	if IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
				if Menu.Auto.E:Value() and IsImmobile(target) then
					self:CastGGPred(HK_E, target)
				end
				if Menu.Kill.E:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetEDmg(target) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end	
end

function Zyra:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) and lastQ + 350 < GetTickCount() then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
			local pos = QPrediction.CastPosition
			if Menu.Auto.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(pos) < WSpell.Range then
				DelayAction(function() Control.CastSpell(HK_W, pos) end,0.25)
			end
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) and lastE + 350 < GetTickCount() then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
			local pos = EPrediction.CastPosition
			if myHero.pos:DistanceTo(pos) > WSpell.Range then
				pos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), WSpell.Range)
			end
			if Menu.Auto.W:Value() and IsReady(_W) then
				DelayAction(function() Control.CastSpell(HK_W, pos) end,0.25)
			end
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) and lastR + 350 < GetTickCount() then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
			lastR = GetTickCount()
		end	
	end
end

function Zyra:CastRAoE(target)
	if IsReady(_R) and lastR + 350 < GetTickCount() then
		local enemies = GetEnemiesAtPos(RSpell.Range, RSpell.Radius, target.pos, target)
		local RCount = Menu.Combo.RCount:Value() 
		if RCount > 1 and #enemies >= RCount then
			local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius, true, 700, RSpell.Speed, RSpell.Delay)
			Control.CastSpell(HK_R, AoEPos)
			lastR = GetTickCount()
		elseif RCount == 1 and #enemies > 0 then
			self:CastGGPred(HK_R, target)
		end
	end
end

function Zyra:RSemiManual()
	local target = TargetSelector:GetTarget(RSpell.Range)
    	if IsValid(target) and target.pos2D.onScreen then
		if IsReady(_R) and lastR + 350 < GetTickCount() then
			local enemies = GetEnemiesAtPos(RSpell.Range, RSpell.Radius, target.pos, target)
			local RCount = Menu.Combo.RCount:Value() 
			if #enemies >= 2 then
				local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius, true, 700, RSpell.Speed, RSpell.Delay)
				Control.CastSpell(HK_R, AoEPos)
				lastR = GetTickCount()
			elseif #enemies == 1 then
				self:CastGGPred(HK_R, target)
			end
		end
	end
end

function Zyra:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
    	local QDmg = ({60, 95, 130, 165, 200})[level] + 0.6 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Zyra:GetPDmg(target)
	local level = myHero.levelData.lvl
    	local PDmg = 40 + 60 / 17 * (level - 1)
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function Zyra:GetEDmg(target)
    	local level = myHero:GetSpellData(_E).level
    	local EDmg = ({60, 105, 150, 195, 240})[level] + 0.5 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function Zyra:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
    	local RDmg = ({180, 265, 350})[level] + 0.7 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function Zyra:ComboDmg(target)
	local Dmg = 0
	if IsReady(_Q) then
		if IsReady(_W) then
			Dmg = Dmg + self:GetQDmg(target) + self:GetPDmg(target)
		else
			Dmg = Dmg + self:GetQDmg(target)
		end
	end
	if IsReady(_E) then
		if IsReady(_W) then
			Dmg = Dmg + self:GetEDmg(target) + self:GetPDmg(target)
		else
			Dmg = Dmg + self:GetEDmg(target)
		end
	end
	if IsReady(_R) then
		Dmg = Dmg + self:GetRDmg(target)
	end
	return Dmg
end

function Zyra:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

--------------------------------------
class "Brand"
        
function Brand:__init()	     
	print("Support Brand Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1100, Speed = 1600, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.877, Radius = 260, Range = 1030, Speed = MathHuge, Collision = false}
	ESpell = {Range = 675}
	RSpell = {Range = 750}
end

function Brand:LoadMenu() 
            
    	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QStun", name = "Combo [Q] Only Can Stun", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] If Hit X Enemies", value = 2, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Eminion", name = "Harass [E] minion if have passive", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "W", name = "Auto [W] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function Brand:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.spellWasCast then
		return
	end
	if Cursor.Step > 0 then
		return
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if Menu.Combo.DisableAA:Value() and (IsReady(_Q) or IsReady(_W) or IsReady(_E)) then
			Orbwalker:SetAttack(false)
		else
			Orbwalker:SetAttack(true)
		end
		self:Combo()
	else
    		Orbwalker:SetAttack(true)
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	self:AutoQ()
	self:AutoW()
end

function Brand:Combo()
	local target = TargetSelector:GetTarget(1200)
    	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
			Control.CastSpell(HK_E, target)
			lastE = GetTickCount()
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			if Menu.Combo.QStun:Value() then
				if HaveBuff(target, "BrandAblaze") then
					self:CastGGPred(HK_Q, target)
				end
			else
				self:CastGGPred(HK_Q, target)
			end
		end
		if Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
			self:CastWAoE(target)
		end					
	end
	local bounceRange = 400
	local enemies = ObjectManager:GetEnemyHeroes(RSpell.Range + bounceRange)
	for i, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and Menu.Combo.R:Value() and IsReady(_R) and lastR + 350 < GetTickCount() then
			if myHero.pos:DistanceTo(target.pos) <= RSpell.Range and GetEnemyCount(bounceRange, target.pos) >= Menu.Combo.RCount:Value() then
				Control.CastSpell(HK_R, target)
				lastR = GetTickCount()
				break
			end
		end
	end
end

function Brand:Harass()
	local target = TargetSelector:GetTarget(QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
			self:CastGGPred(HK_W, target)
		end
		if Menu.Harass.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
			Control.CastSpell(HK_E, target)
		end
	end
	local minions = ObjectManager:GetEnemyMinions(ESpell.Range)
	for i, minion in ipairs(minions) do
		if IsValid(minion) and minion.pos2D.onScreen and IsReady(_E) and lastE + 350 < GetTickCount() then
			if Menu.Harass.E:Value() and Menu.Harass.Eminion:Value() and HaveBuff(minion, "BrandAblaze") and GetEnemyCount(ESpell.Range, myHero.pos) == 0 and GetEnemyCount(600, minion.pos) > 0 then
				Control.CastSpell(HK_E, minion)
				lastE = GetTickCount()
				break
			end
		end
	end
end

function Brand:AutoQ()
	if IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.Q:Value() and IsImmobile(target) then
					self:CastGGPred(HK_Q, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.Q:Value() and Hp < self:GetQDmg(target) + self:GetPDmg(target) - target.hpRegen*5 then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function Brand:AutoW()
	if IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.W:Value() and IsImmobile(target) then
					self:CastGGPred(HK_W, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.W:Value() and Hp < self:GetWDmg(target) + self:GetPDmg(target) - target.hpRegen*5 then
					self:CastGGPred(HK_W, target)
				end
			end
		end
	end	
end

function Brand:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) and lastQ + 350 < GetTickCount() then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) and lastW + 350 < GetTickCount() then
			local castPos = Vector(myHero.pos):Extended(Vector(WPrediction.CastPosition), 900)
			if myHero.pos:DistanceTo(unit.pos) <= 900 then
				Control.CastSpell(HK_W, WPrediction.CastPosition)
				lastW = GetTickCount()
			elseif myHero.pos:DistanceTo(unit.pos) > 900 and myHero.pos:DistanceTo(unit.pos) <= 1030 then
				Control.CastSpell(HK_W, castPos)
				lastW = GetTickCount()
			end
		end	
	end
end

function Brand:CastWAoE(target)
	if IsReady(_W) and lastW + 350 < GetTickCount() then
		local enemies = GetEnemiesAtPos(WSpell.Range, WSpell.Radius, target.pos, target) 
		if  #enemies >= 2 then
			local AoEPos = CalculateBestCirclePosition(enemies, WSpell.Radius, true, 900, WSpell.Speed, WSpell.Delay)
			Control.CastSpell(HK_W, AoEPos)
			lastW = GetTickCount()
		elseif #enemies == 1 then
			self:CastGGPred(HK_W, target)
		end
	end
end

function Brand:GetPDmg(target)
    	local PDmg = target.maxHealth * 0.025
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function Brand:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
    	local QDmg = ({80, 110, 140, 170, 200})[level] + 0.65 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Brand:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
    	local WDmg = ({75, 120, 165, 210, 255})[level] + 0.6 * myHero.ap
    	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function Brand:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end
