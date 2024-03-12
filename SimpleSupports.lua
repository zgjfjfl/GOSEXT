local Version = 2024.08

--[ AutoUpdate ]

do

	local Files = {
		Lua = {
			Path = SCRIPT_PATH,
			Name = "SimpleSupports.lua",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/SimpleSupports.lua"
		},
		Version = {
			Path = SCRIPT_PATH,
			Name = "SimpleSupports.version",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/SimpleSupports.version"
		}
	}

	local function AutoUpdate()

		local function DownloadFile(url, path, fileName)
			DownloadFileAsync(url, path .. fileName, function() end)
			while not FileExist(path .. fileName) do end
		end

		local function ReadFile(path, fileName)
			local file = io.open(path .. fileName, "r")
			local result = file:read()
			file:close()
			return result
		end
		
		DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
		DelayAction(function()
			local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
			if NewVersion > Version then
				print("SimpleSupports: Found update! Downloading...")
				DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
				DelayAction(function()
					print("SimpleSupports: Successfully updated. Press 2x F6!")
				end, 3)
			end
		end, 3)

	end

	AutoUpdate()

end

local Heroes = {"Lux", "Zyra", "Brand", "Velkoz", "Ziggs", "Swain", "Seraphine", "Neeko"}

if not table.contains(Heroes, myHero.charName) then 
	print('SimpleSupports not supported ' .. myHero.charName)
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
local MathSqrt = math.sqrt
local MathSort = table.sort

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
	for i = 0, unit.buffCount do
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

local function GetImmobileDuration(unit)
	local MaxDuration = 0
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35) and buff.count > 0 then
			local BuffDuration = buff.duration
			if BuffDuration > MaxDuration then
				MaxDuration = BuffDuration
			end
		end
	end
	return MaxDuration
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

local function IsSlow(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.type == 11 and buff.count > 0 then
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

local function CalculateBestCirclePosition(targets, radius, edgeDetect, RSpellange, spellSpeed, spellDelay)
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
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > RSpellange then

		local checkPos = myHero.pos:Extended(avgCastPos, RSpellange)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, RSpellange + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, RSpellange + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, RSpellange)
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
	Menu:MenuElement({name = " ", drop = {"Version: " .. Version}})
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
	if not Orbwalker:CanMove() then
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
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and not IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
			self:CastGGPred(HK_E, target)
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
	QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 100, Range = 800, Speed = MathHuge, Collision = false}
	WSpell = {Range = 850}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1100, Speed = 1150, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 500, Range = 950, Speed = MathHuge, Collision = false}
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
	if not Orbwalker:CanMove() then
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
			if myHero.pos:DistanceTo(pos) > WSpell.Range then
				pos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), WSpell.Range)
			end
			if Menu.Auto.W:Value() and IsReady(_W) then
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
			local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius/2, true, 700, RSpell.Speed, RSpell.Delay)
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
				local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius/2, true, 700, RSpell.Speed, RSpell.Delay)
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
	local QDmg = ({60, 100, 140, 180, 220})[level] + 0.65 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Zyra:GetPDmg(target)
	local level = myHero.levelData.lvl
	local PDmg = (16 + 4 * level) + 0.18 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function Zyra:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({60, 95, 130, 165, 200})[level] + 0.6 * myHero.ap
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
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
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
	if not Orbwalker:CanMove() then
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
end

function Brand:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if Menu.Combo.DisableAA:Value() and (IsReady(_Q) or IsReady(_W) or IsReady(_E)) then
			args.Process = false
		end
	end
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
	local target = TargetSelector:GetTarget(1200)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.W:Value() and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
			self:CastWAoE(target)
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
		if #enemies >= 2 then
			local AoEPos = CalculateBestCirclePosition(enemies, WSpell.Radius/2, true, 900, WSpell.Speed, WSpell.Delay)
			Control.CastSpell(HK_W, AoEPos)
			lastW = GetTickCount()
		elseif #enemies == 1 then
			self:CastGGPred(HK_W, target)
		end
	end
end

function Brand:GetPDmg(target)
	local PDmg = target.maxHealth * 0.02
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function Brand:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({70, 100, 130, 160, 190})[level] + 0.65 * myHero.ap
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

--------------------------------------

class "Velkoz"

function Velkoz:__init()
	print("Support Velkoz Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 1100, Speed = 1300, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}}
	QSplit = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 45, Range = 1000, Speed = 2100, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	QDummy = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 45, Range = MathSqrt(QSpell.Range^2 + QSplit.Range^2), Speed = 1200, Collision = false}
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 85, Range = 1000, Speed = 1700, Collision = false}
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.0, Radius = 225, Range = 800, Speed = MathHuge, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 80, Range = 1500, Speed = MathHuge, Collision = false}
end

function Velkoz:LoadMenu() 

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "W", name = "Auto [W] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function Velkoz:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end

	if HaveBuff(myHero, "VelkozR") then
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
	self:AutoW()
	self:AutoE()
end

function Velkoz:Combo()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QDummy.Range then
			self:CastQ(target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range - 50 then
			self:CastGGPred(HK_W, target)
		end
		if Menu.Combo.R:Value() and IsReady(_R) and lastR + 350 < GetTickCount() and GetEnemyCount(400, myHero.pos) == 0 and myHero.pos:DistanceTo(target.pos) < RSpell.Range - 50 and not IsUnderTurret(myHero) then
			if target.health < self:GetRDmg(target) then
				Control.CastSpell(HK_R, target)
				lastR = GetTickCount()
			end
		end				
	end
end

function Velkoz:Harass()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QDummy.Range then
			self:CastQ(target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range - 50 then
			self:CastGGPred(HK_W, target)
		end
	end
end

function Velkoz:AutoW()
	if IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.W:Value() and IsImmobile(target) then
					self:CastGGPred(HK_W, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.W:Value() and Hp < self:GetWDmg(target) then
					self:CastGGPred(HK_W, target)
				end
			end
		end
	end	
end

function Velkoz:AutoE()
	if IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.E:Value() and IsImmobile(target) then
					self:CastGGPred(HK_E, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.E:Value() and Hp < self:GetEDmg(target) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end	
end

function Velkoz:CastGGPred(spell, unit)
	if spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) and lastW + 350 < GetTickCount() and Orbwalker:CanMove() then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
			lastW = GetTickCount()
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) and lastE + 350 < GetTickCount() and Orbwalker:CanMove() then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end	
	end
end

function Velkoz:CastQ(target)
	if myHero:GetSpellData(_Q).toggleState == 0 and lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
		if myHero.pos:DistanceTo(target.pos) <= QSpell.Range then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius, QSpell.CollisionTypes, target.networkID)
			if collisionCount == 0 then
				local QPrediction = GGPrediction:SpellPrediction(QSpell)
				QPrediction:GetPrediction(target, myHero)
				if QPrediction:CanHit(3) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					lastQ = GetTickCount()
					return
				end
			else
				local QDummyPrediction = GGPrediction:SpellPrediction(QDummy)
				QDummyPrediction:GetPrediction(target, myHero)
				if QDummyPrediction:CanHit(3) then
					self:BestAim(QDummyPrediction.CastPosition)
				end
			end
		else
			local QDummyPrediction = GGPrediction:SpellPrediction(QDummy)
			QDummyPrediction:GetPrediction(target, myHero)
			if QDummyPrediction:CanHit(3) then
				self:BestAim(QDummyPrediction.CastPosition)
			end
		end		
	end
	self:DetonateQ(target)
end

function Velkoz:DetonateQ(target)
	if myHero:GetSpellData(_Q).toggleState == 1 then
		for i = GameParticleCount(), 1, -1 do
			local particle = GameParticle(i)
			local Name = particle.name
			if particle and Name:find("Velkoz") and Name:find("Q_mis") then
				local realPos = particle.pos + (particle.pos - myHero.pos):Normalized()*50
				local dir = (realPos - myHero.pos):Normalized()
				local pDir = dir:Perpendicular()
				local leftEndPos = realPos + pDir * 1000
				local rightEndPos = realPos - pDir * 1000

				local lEndPos = Vector(leftEndPos.x, realPos.y, leftEndPos.z)
				local rEndPos = Vector(rightEndPos.x, realPos.y, rightEndPos.z)

				local Prediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 45, Range = MathSqrt(QSpell.Range^2 + QSplit.Range^2), Speed = 2100, Collision = false})
				Prediction:GetPrediction(target, realPos)
				if Prediction:CanHit(3) then
					local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(Prediction.CastPosition, realPos, lEndPos)
					if isOnSegment and GGPrediction:IsInRange(Prediction.CastPosition, point, (QSplit.Radius + target.boundingRadius)) then
						Control.CastSpell(HK_Q)
						return
					end
					local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(Prediction.CastPosition, realPos, rEndPos)
					if isOnSegment and GGPrediction:IsInRange(Prediction.CastPosition, point, (QSplit.Radius + target.boundingRadius)) then
						Control.CastSpell(HK_Q)
						return
					end
				end
			end
		end
	end
end

function Velkoz:AimQ(finalPos)
	local CircleLineSegmentN = 36
	local radius = 500
	local position = myHero.pos
	local points = {}

	for i = 1, CircleLineSegmentN do
		local angle = i * 2 * math.pi / CircleLineSegmentN
		local x = position.x + radius * math.cos(angle)
		local z = position.z + radius * math.sin(angle)
		local y = position.y
		local point = Vector(x, y, z)

		if point:DistanceTo(myHero.pos:Extended(finalPos, radius)) < 430 then
			TableInsert(points, point)
		end
	end

	table.sort(points, function(a, b)
		return a:DistanceTo(finalPos) < b:DistanceTo(finalPos)
	end)

	TableRemove(points, 1)
	TableRemove(points, 1)

	return points
end

function Velkoz:BestAim(predictionPos)
	local pointList = Velkoz:AimQ(predictionPos)
	local c1 = Vector(predictionPos):DistanceTo(myHero.pos)
	for _, point in ipairs(pointList) do
		for j = 400, 1100, 50 do
			local posExtend = myHero.pos:Extended(point, j)
			local a1 = myHero.pos:DistanceTo(posExtend)
			local b1 = math.sqrt(c1 * c1 - a1 * a1)

			if b1 < QSplit.Range then
				local pointA = myHero.pos:Extended(point, a1)
				local endPos = Vector(pointA.x,myHero.pos.y,pointA.z)
				local dir = (endPos - myHero.pos):Normalized()
				local pDir = dir:Perpendicular()
				local leftEndPos = endPos + pDir * b1
				local rightEndPos = endPos - pDir * b1

				local lEndPos = Vector(leftEndPos.x,myHero.pos.y,leftEndPos.z)
				local rEndPos = Vector(rightEndPos.x,myHero.pos.y,rightEndPos.z)

				if lEndPos:DistanceTo(predictionPos) < QSplit.Radius then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > 0 then
						break
					end
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(endPos, lEndPos, QSplit.Speed, QSplit.Delay, QSplit.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > 0 then
						break
					end
					Control.CastSpell(HK_Q, endPos)
					lastQ = GetTickCount()
					return
				end

				if rEndPos:DistanceTo(predictionPos) < QSplit.Radius then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > 0 then
						break
					end
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(endPos, rEndPos, QSplit.Speed, QSplit.Delay, QSplit.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > 0 then
						break
					end
					Control.CastSpell(HK_Q, endPos)
					lastQ = GetTickCount()
					return
				end
			end
		end
	end
end

function Velkoz:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({30, 50, 70, 90, 110})[level] + 0.2 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function Velkoz:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 100, 130, 160, 190})[level] + 0.3 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function Velkoz:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = ({450, 625, 800})[level] + 1.25 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function Velkoz:Draw()
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

------------------------------------

class "Ziggs"

function Ziggs:__init()
	print("Support Ziggs Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Q1Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 180, Range = 850, Speed = 1700, Collision = false}
	Q2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 180, Range = 1400, Speed = 1700, Collision = false}
	WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 1200, Speed = 1750, Collision = false}
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 325, Range = 1000, Speed = 1750, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.375, Radius = 230, Range = 5000, Speed = 1750, Collision = false}
end

function Ziggs:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W] on long-range Enemy", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] hit x targets", value = 3, min=1, max=5, step=1})
	Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W2", name = "Auto [W2]", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W2time", name = "Auto [W2] Delay X time(ms)", value = 500, min=0,max=1000,step=50})
	Menu.Auto:MenuElement({id = "WTurret", name = "Auto [W] low turret", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "WPeel", name = "Auto [W] Peel", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RCC", name = "Auto [R] On 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RKill", name = "Auto [R] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "W", name = "[W] to mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rmini", name = "Draw [R] Range in minimap", toggle = true, value = false})
end

function Ziggs:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if Menu.Auto.W2:Value() then
		if myHero:GetSpellData(_W).name == "ZiggsWToggle" and IsReady(_W) then
			if lastW + Menu.Auto.W2time:Value() < GetTickCount() then
				Control.CastSpell(HK_W)
			end
		end
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
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:SemiManualR()
	end
	self:Auto()
end

function Ziggs:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= Q2Spell.Range then
			self:CastQ(target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
			self:CastE(target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" and myHero.pos:DistanceTo(target.pos) <= WSpell.Range then
			local IsRange = target.range > 300
			if IsRange then
 				self:CastW(target)
			end
		end
	end

	local Rtarget = TargetSelector:GetTarget(5000)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		if Menu.Combo.R:Value() and IsReady(_R) then
			self:CastRAoE(Rtarget)
		end
	end
end	

function Ziggs:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then

		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= Q2Spell.Range then
			self:CastQ(target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" and myHero.pos:DistanceTo(target.pos) <= WSpell.Range then
			self:CastW(target)
		end
		if Menu.Harass.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
			self:CastE(target)
		end
	end
end

function Ziggs:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and lastW + 350 < GetTickCount() and myHero:GetSpellData(_W).name == "ZiggsW" then
		local castPos = myHero.pos:Extended(mousePos,-100)
		if castPos:To2D().onScreen then
			Control.CastSpell(HK_W, castPos)
			astW = GetTickCount()
		end
	end
end

function Ziggs:SemiManualR()
	local Rtarget = TargetSelector:GetTarget(5000)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		local enemies = GetEnemiesAtPos(RSpell.Range + RSpell.Radius, RSpell.Radius*2, Rtarget.pos, Rtarget)
		if #enemies >= 2 and lastR + 500 < GetTickCount() then
			local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius, true, RSpell.Range, RSpell.Speed, RSpell.Delay)
			if AoEPos:To2D().onScreen then
				Control.CastSpell(HK_R, AoEPos)
				lastR = GetTickCount()
			end
		elseif #enemies == 1 then
			self:CastR(Rtarget)
		end
	end
end

function Ziggs:Auto()
	local enemies = ObjectManager:GetEnemyHeroes(RSpell.Range)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Auto.WPeel:Value() and IsReady(_W) and lastW + 350 < GetTickCount() and myHero:GetSpellData(_W).name == "ZiggsW" then
				local IsMelee = enemy.range < 300
				if IsMelee and myHero.pos:DistanceTo(enemy.pos) <= enemy.boundingRadius + enemy.range + myHero.boundingRadius then
					local castPos = Vector(myHero.pos):Extended(Vector(enemy.pos), MathMin(200, myHero.pos:DistanceTo(enemy.pos)/2))
					Control.CastSpell(HK_W, castPos)
					lastW = GetTickCount()
				end
			end
			if Menu.Auto.RCC:Value() and IsReady(_R) and GetImmobileDuration(enemy) > 0.5 then
				self:CastR(enemy)
			end
			if Menu.Auto.RKill:Value() and IsReady(_R) then
				local Rdmg = self:GetRDmg(enemy)
				if Rdmg > enemy.health + enemy.shieldAP + enemy.shieldAD then
					self:CastR(enemy)
				end
			end
		end
	end
	if Menu.Auto.WTurret:Value() and IsReady(_W) and lastW + 350 < GetTickCount() and myHero:GetSpellData(_W).name == "ZiggsW" then
	local turrets = ObjectManager:GetEnemyTurrets(1000)
	for i, turret in ipairs(turrets) do
			if turret and turret.health/turret.maxHealth < (myHero:GetSpellData(_W).level*2.5 + 22.5)/100 then
				Control.CastSpell(HK_W, turret)
				lastW = GetTickCount()
			end
		end
	end
end

function Ziggs:CastQ(unit)
	if myHero.pos:DistanceTo(unit.pos) > 850 then
		local QPrediction = GGPrediction:SpellPrediction(Q2Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local startPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 600)
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(startPos, QPrediction.CastPosition, Q2Spell.Speed, Q2Spell.Delay, Q2Spell.Radius/2, {GGPrediction.COLLISION_MINION}, unit.networkID)
			if collisionCount == 0 then
				local endPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 850)
				if Vector(QPrediction.CastPosition):To2D().onScreen and not MapPosition:inWall(endPos) and lastQ + 350 < GetTickCount() then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
					lastQ = GetTickCount()
				end
			end
		end
	else
		local QPrediction = GGPrediction:SpellPrediction(Q1Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) and lastQ + 350 < GetTickCount() then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	end
end

function Ziggs:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) and lastW + 350 < GetTickCount() then
		local castPos1 = Vector(Vector(WPrediction.CastPosition)):Extended(Vector(myHero.pos), 100)
		local castPos2 = Vector(myHero.pos):Extended(Vector(WPrediction.CastPosition), 1000)
		if myHero.pos:DistanceTo(unit.pos) <= 1000 then
			Control.CastSpell(HK_W, castPos1)
			lastW = GetTickCount()
		elseif myHero.pos:DistanceTo(unit.pos) > 1000 and myHero.pos:DistanceTo(unit.pos) <= 1200 then
			Control.CastSpell(HK_W, castPos2)
			lastW = GetTickCount()
		end
	end
end

function Ziggs:CastE(unit)
	local EPrediction = GGPrediction:SpellPrediction(ESpell)
	EPrediction:GetPrediction(unit, myHero)
	if EPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) and lastE + 350 < GetTickCount() then
		local castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), 900)
		if myHero.pos:DistanceTo(unit.pos) <= 900 then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		elseif myHero.pos:DistanceTo(unit.pos) > 900 and myHero.pos:DistanceTo(unit.pos) <= 1000 then
			Control.CastSpell(HK_E, castPos)
			lastE = GetTickCount()
		end
	end
end

function Ziggs:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) and lastR + 500 < GetTickCount() then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
		lastR = GetTickCount()
	end
end

function Ziggs:CastRAoE(unit)
	local comboRCount = Menu.Combo.RCount:Value()
	local enemies = GetEnemiesAtPos(RSpell.Range + RSpell.Radius, RSpell.Radius*2, unit.pos, unit)
	if comboRCount > 1 and #enemies >= comboRCount and lastR + 500 < GetTickCount() then
		local AoEPos = CalculateBestCirclePosition(enemies, RSpell.Radius, true, RSpell.Range, RSpell.Speed, RSpell.Delay)
		if AoEPos:To2D().onScreen then
			Control.CastSpell(HK_R, AoEPos)
			lastR = GetTickCount()
		end
	elseif comboRCount == 1 and #enemies > 0 then
		self:CastR(unit)
	end
end

function Ziggs:GetRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 150 * rlvl + 150
	local apDmg = myHero.ap * 1.1
	local Dmg = baseDmg + apDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
end

function Ziggs:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, Q2Spell.Range, 1, Draw.Color(255, 66, 244, 113))
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
	if Menu.Draw.Rmini:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, RSpell.Range, 0.5, Draw.Color(200,50,180,230))
	end
end

------------------------------

class "Swain"

function Swain:__init()
	print("Support Swain Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Angle = 32, Range = 725, Speed = MathHuge, Collision = false}
	WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 325, Range = 5500, Speed = MathHuge, Collision = false}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 85, Range = 950, Speed = MathHuge, Collision = false}
end

function Swain:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Waoe", name = "Combo [W] AoE", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WCount", name = "[W] hit x targets", value = 3, min = 2, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Wsm", name = "W Semi-Manual Key(Only Cursor near)", key = string.byte("T")})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "E Range Set", value = 950, min = 500, max = 950, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Wslow", name = "Auto [W] on Slow", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Wgap", name = "Auto [W] AnitGap", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E2", name = "Auto [E2] pulls", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
end

function Swain:OnTick()
	WSpell.Range = 5000 + 500*myHero:GetSpellData(_W).level

	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	if Menu.Combo.Wsm:Value() and IsReady(_W) then
		self:SemiManualW()
	end
	self:Auto()
end

function Swain:SemiManualW()
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if enemy.pos:DistanceTo(mousePos) < 500 and myHero.pos:DistanceTo(enemy.pos) <= WSpell.Range then
				self:CastGGPred(HK_W, enemy)
				break
			end
		end
	end
end


function Swain:Combo()
	if Attack:IsActive() then return end
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "SwainE" and myHero.pos:DistanceTo(target.pos) < Menu.Combo.ERange:Value() then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
	local Wtarget = TargetSelector:GetTarget(WSpell.Range)
	if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
		if Menu.Combo.Waoe:Value() and IsReady(_W) then
			self:CastWAoE(Wtarget)
		end
	end
end	

function Swain:Harass()
	if Attack:IsActive() then return end
	local target = TargetSelector:GetTarget(QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Swain:CastWAoE(unit)
	local enemies = GetEnemiesAtPos(WSpell.Range + WSpell.Radius/2, WSpell.Radius, unit.pos, unit)
	if #enemies >= Menu.Combo.WCount:Value() then
		local AoEPos = CalculateBestCirclePosition(enemies, WSpell.Radius/2, true, WSpell.Range, WSpell.Speed, WSpell.Delay)
		if AoEPos:To2D().onScreen and lastW + 350 < GetTickCount() then
			Control.CastSpell(HK_W, AoEPos)
			lastW = GetTickCount()
		end
	end
end

function Swain:Auto()
	for i, enemy in ipairs(GetEnemyHeroes()) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			local buff = GetBuffData(enemy, "swaineroot")
			if Menu.Auto.E2:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "SwainE2" and buff.count > 0 and buff.duration < 1 then
				Control.CastSpell(HK_E)
			end
			if Menu.Auto.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(enemy.pos) < QSpell.Range and IsImmobile(enemy) then
				self:CastGGPred(HK_Q, enemy)
			end
			if Menu.Auto.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(enemy.pos) <= WSpell.Range and IsImmobile(enemy) then
				if HaveBuff(enemy, "swaineroot") and myHero:GetSpellData(_E).name == "SwainE2" then
					if myHero.pos:DistanceTo(enemy.pos) < 290 then
						self:CastGGPred(HK_W, enemy)
					else
						local castPos = enemy.pos:Extended(myHero.pos, 250)
						Control.CastSpell(HK_W, castPos)
					end
				else
					self:CastGGPred(HK_W, enemy)
				end
			end
			if Menu.Auto.Wslow:Value() and IsReady(_W) and myHero.pos:DistanceTo(enemy.pos) <= WSpell.Range and IsSlow(enemy) then
				self:CastGGPred(HK_W, enemy)
			end
			if Menu.Auto.Wgap:Value() and myHero.pos:DistanceTo(enemy.pos) < 1500 and enemy.pathing.isDashing then
				if myHero.pos:DistanceTo(enemy.pathing.endPos) < myHero.range and IsReady(_W) and lastW + 350 < GetTickCount() then
					Control.CastSpell(HK_W, enemy.pathing.endPos)
					lastW = GetTickCount()
				end
			end
		end
	end
end

function Swain:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) and lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) and lastW + 350 < GetTickCount() and Orbwalker:CanMove() then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
			lastW = GetTickCount()
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) and lastE + 350 < GetTickCount() and Orbwalker:CanMove() then
			local endPos = myHero.pos + (EPrediction.CastPosition - myHero.pos):Normalized() * ESpell.Range
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(endPos, EPrediction.CastPosition, 1400, 0.1, ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
			if collisionCount == 0 then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
				lastE = GetTickCount()
			end
		end	
	end
end

function Swain:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

--------------------------------------

class "Seraphine"

function Seraphine:__init()
	print("Support Seraphine Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 350, Range = 900, Speed = 1200, Collision = false}
	WSpell = {Range = 800}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1300, Speed = 1200, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 160, Range = 1200*2, Speed = 1600, Collision = false}
end

function Seraphine:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})
	Menu.Combo:MenuElement({name = " ", drop = {"(Can reset distance by hit allies or other enemies)"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Shield", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Whp", name = "Auto [W] allies or self Low hp%", value = true, min = 0, max = 100, value = 30, step = 5})
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

function Seraphine:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if not Orbwalker:CanMove() then
		return
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:SemiManualR()
	end
	self:AutoQ()
	self:AutoW()
	self:AutoE()
end

function Seraphine:Combo()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < ESpell.Range then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Seraphine:Harass()
	local target = TargetSelector:GetTarget(QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function SortByDistance(obj1, obj2)
	return myHero.pos:DistanceTo(obj1.pos) < myHero.pos:DistanceTo(obj2.pos)
end

function Seraphine:SemiManualR()
	local Rtarget = TargetSelector:GetTarget(RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		if myHero.pos:DistanceTo(Rtarget.pos) < 1200 then
			self:CastGGPred(HK_R, Rtarget)
		else
			local isWall1, collisionObjects1, collisionCount1 = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, RSpell.Speed, RSpell.Delay, RSpell.Radius/2, {GGPrediction.COLLISION_ALLYHERO}, myHero.networkID)
			local isWall2, collisionObjects2, collisionCount2 = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, RSpell.Speed, RSpell.Delay, RSpell.Radius/2, {GGPrediction.COLLISION_ENEMYHERO}, Rtarget.networkID)
			MathSort(collisionObjects1, SortByDistance)
			MathSort(collisionObjects2, SortByDistance)
			if (collisionCount1 > 0 and myHero.pos:DistanceTo(collisionObjects1[1].pos) < 1200) or (collisionCount2 > 0 and myHero.pos:DistanceTo(collisionObjects2[1].pos) < 1200) then
				self:CastGGPred(HK_R, Rtarget)
			end
		end
	end
end

function Seraphine:AutoQ()
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

function Seraphine:AutoW()
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

function Seraphine:AutoE()
	if IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
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

function Seraphine:CastGGPred(spell, unit)
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
		if EPrediction:CanHit(3) and lastE + 350 < GetTickCount() then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end		
	
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) and lastR + 600 < GetTickCount() then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
			lastR = GetTickCount()
		end	
	end
end

function Seraphine:GetQDmg(target)
	local missingHp = string.format("%.2f", (1 - target.health / target.maxHealth))
	local level = myHero:GetSpellData(_Q).level
	local QDmg = (({60, 85, 110, 135, 165})[level] + 0.5 * myHero.ap) * (1 + 0.06 * (MathMin(missingHp, 0.75) / 0.075))
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Seraphine:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 100, 130, 160, 190})[level] + 0.5 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function Seraphine:Draw()
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

---------------------------------

class "Neeko"

function Neeko:__init()
	print("Support Neeko Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 900, Speed = 2000, Collision = false}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 1300, Collision = false}
end

function Neeko:LoadMenu() 

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "[E] Range Set", value = 1000, min = 500, max = 1000, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
end

function Neeko:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end
	if not Orbwalker:CanMove() then
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
end

function Neeko:Combo()
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.Erange:Value() then
			self:CastGGPred(HK_E, target)
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= QSpell.Range and not IsReady(_E) then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Neeko:Harass()
	local target = TargetSelector:GetTarget(QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Neeko:AutoQ()
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

function Neeko:AutoE()
	if IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(Menu.Combo.Erange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
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

function Neeko:CastGGPred(spell, unit)
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
		if EPrediction:CanHit(3) and lastE + 350 < GetTickCount() then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end
	end
end

function Neeko:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({80, 125, 170, 215, 260})[level] + 0.5 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function Neeko:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 105, 140, 175, 210})[level] + 0.65 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function Neeko:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

---------------------------------

--[[class "Yuumi"

function Yuumi:__init()
	print("Support Yuumi Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 35, Range = 1150, Speed = 1950, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 60, Range = 1700, Speed = 1650, Collision = false}
	WSpell = {Range = 700}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 225, Range = 1100, Speed = 3000, Collision = false}
end

function Yuumi:LoadMenu() 

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] When X Enemies in Range", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RRange", name = "[R] Range set", value = 1100, min = 500, max = 1100, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "QMana", name = "Harass When > X Mana", value = 80, min = 5, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] Harass(Only No Orb Mode)", toggle = true, value = true})	
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] Shield", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "R", name = "Auto [R]", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RCount", name = "Auto [R] When X Enemies in Range", value = 3, min = 1, max = 5, step = 1})
	
	Menu:MenuElement({type = MENU, id = "WSet", name = "WSetting"})
	Menu.WSet:MenuElement({id = "Wsm", name = "W Semi-Manual(attach ally mouse near)", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function Yuumi:IsAttaching()
	if myHero:GetSpellData(_W).name == "YuumiWEndWrapper" then
		return true
	end
	return false
end

function Yuumi:OnTick()
	if myHero.dead or Game.IsChatOpen() or Recalling() then
		return
	end
	
	if self:IsAttaching() then
		Orbwalker:SetAttack(false)
		Orbwalker:SetMovement(false)
	else
		if HaveBuff(myHero, "YuumiR") then
			Orbwalker:SetAttack(false)
		else
			Orbwalker:SetAttack(true)
		end
		Orbwalker:SetMovement(true) 
	end

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	self:AutoQ()
	self:AutoE()
	self:AutoR()
	
	if Menu.WSet.Wsm:Value() then
		self:SemiManualW()
	end
end

function Yuumi:Combo()
	if Menu.Combo.Q:Value() then
		if not self:IsAttaching() then
			local target = TargetSelector:GetTarget(Q1Spell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_Q, target)
			end
		elseif self:IsAttaching() then
			self:CastQ2()
		end
	end
	
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = TargetSelector:GetTarget(Menu.Combo.RRange:Value())
		if IsValid(target) and target.pos2D.onScreen then
			if GetEnemyCount(RSpell.Radius, target.pos) >= Menu.Combo.RCount:Value() then
				if self:IsAttaching() then
					local castPos = myHero.pos:Extended(target.pos, myHero.range)
					Control.SetCursorPos(castPos)
					Control.CastSpell(HK_R)
					DelayAction(function() Control.SetCursorPos(mousePos) end, 3.5)
				else
					if lastR + 3600 < GetTickCount() then
						Control.CastSpell(HK_R, target)
						lastR = GetTickCount()
					end
				end
			end
		end
	end
end

function Yuumi:Harass()
	if Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana >= Menu.Harass.QMana:Value()/100 then
		if not self:IsAttaching() then
			local target = TargetSelector:GetTarget(Q1Spell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_Q, target)
			end
		elseif self:IsAttaching() then
			self:CastQ2()
		end
	end
end

function Yuumi:AutoQ()
	if Menu.Auto.Q:Value() and not (Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] or Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) then
		self:Harass()
	end
end

function Yuumi:AutoE()
	if not (Menu.Auto.E:Value() and IsReady(_E)) then return end

	local allies = ObjectManager:GetAllyHeroes(myHero.range)
	local enemies = ObjectManager:GetEnemyHeroes(2500)
	local turrets = ObjectManager:GetEnemyTurrets(1500)
	
	for _, ally in ipairs(allies) do
		if IsValid(ally) and (not self:IsAttaching() and ally.isMe or HaveBuff(ally, "YuumiWAlly")) then
			for _, enemy in ipairs(enemies) do
				if IsValid(enemy) then
					local canUseE = false
					if enemy.isChanneling and enemy.activeSpell.target == ally.handle then
						canUseE = true
					elseif enemy.activeSpell.isAutoAttack and enemy.activeSpell.target == ally.handle then
						canUseE = true
					elseif enemy.isChanneling then
						local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, enemy.activeSpell.placementPos, enemy.pos)
						local width = ally.boundingRadius + (enemy.activeSpell.width > 0 and enemy.activeSpell.width or 0)
						if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
							canUseE = true
						end
					end
					
					if canUseE then
						Control.CastSpell(HK_E)
						return
					end
				end
			end
			
			for _, turret in ipairs(turrets) do
				if turret and turret.targetID then
					if turret.targetID == ally.networkID then
						Control.CastSpell(HK_E)
						return
					end
				end
			end
		end
	end
end

function Yuumi:AutoR()
	if Menu.Auto.R:Value() and IsReady(_R) then
		if self:IsAttaching() then
			local target = TargetSelector:GetTarget(Menu.Combo.RRange:Value())
			if IsValid(target) and target.pos2D.onScreen then
				if GetEnemyCount(RSpell.Radius, target.pos) >= Menu.Auto.RCount:Value() then
					local castPos = myHero.pos:Extended(target.pos, myHero.range)
					Control.SetCursorPos(castPos)
					Control.CastSpell(HK_R)
					DelayAction(function() Control.SetCursorPos(mousePos) end, 3.5)
				end
			end
		end
	end
end

function Yuumi:SemiManualW()
	if IsReady(_W) then
		local allies = ObjectManager:GetAllyHeroes(WSpell.Range)
		for j, ally in ipairs(allies) do
			if IsValid(ally) and not ally.isMe and not HaveBuff(ally, "YuumiWAlly") then
				if ally.pos:DistanceTo(mousePos) < 350 then
					Control.CastSpell(HK_W, ally.pos)
				end
			end
		end
	end
end

function Yuumi:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(Q1Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) and IsReady(_Q) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function Yuumi:CastQ2()
	local target = TargetSelector:GetTarget(1700)
	if IsValid(target) and target.pos2D.onScreen then
		local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, Q2Spell.Speed, Q2Spell.Delay, Q2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount == 0 then
			if IsReady(_Q) then
				Control.SetCursorPos(target.pos)
				Control.CastSpell(HK_Q)
			elseif Game.CanUseSpell(_Q) == 8 then
				Control.SetCursorPos(target.pos)
				DelayAction(function() Control.SetCursorPos(mousePos) end, 1.2)
			end
		else
			local points = self:AimQ(target.pos)
			for i = 1,#points do
				local point = points[i]
				local _, _, collisionCount1 = GGPrediction:GetCollision(myHero.pos, point, 850, Q2Spell.Delay, Q2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				local _, _, collisionCount2 = GGPrediction:GetCollision(point, target.pos, Q2Spell.Speed, Q2Spell.Delay, Q2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount1 == 0 and collisionCount2 == 0 then
					if myHero.pos:DistanceTo(point) + target.pos:DistanceTo(point) < 1700 and myHero.pos:DistanceTo(target.pos) > 1000 then
						if IsReady(_Q) then
							Control.SetCursorPos(point)
							Control.CastSpell(HK_Q)
						elseif Game.CanUseSpell(_Q) == 8 then
							Control.SetCursorPos(point)
							DelayAction(function() Control.SetCursorPos(target.pos) end, 0.8)
							DelayAction(function() Control.SetCursorPos(mousePos) end, 0.4)
						end
					end
				end
			end
		end
	end
end

function Yuumi:AimQ(finalPos)
	local startPos = Vector(myHero.pos)
	local points = {}

	for j = 10, 360, 10 do 
		local rotatedVector = Vector(0, 0, 800):Rotated(0, j * math.pi / 180, 0)
		local endPos = startPos + rotatedVector

		if endPos:DistanceTo(myHero.pos:Extended(finalPos, 800)) < 400 then
			TableInsert(points, endPos)
		end
	end

	table.sort(points, function(a, b)
		return a:DistanceTo(finalPos) < b:DistanceTo(finalPos)
	end)

	TableRemove(points, 1)
	TableRemove(points, 1)

	return points
end

function Yuumi:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		if not self:IsAttaching() then
			Draw.Circle(myHero.pos, Q1Spell.Range, 1, Draw.Color(255, 66, 244, 113))
		else
			Draw.Circle(myHero.pos, Q2Spell.Range, 1, Draw.Color(255, 66, 244, 113))
		end
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end]]