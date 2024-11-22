local Version = 2024.19

--[ AutoUpdate ]

do

	local Files = {
		Lua = {
			Path = SCRIPT_PATH,
			Name = "Zgjfjfl_SimpleAio.lua",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/Zgjfjfl_SimpleAio.lua"
		},
		Version = {
			Path = SCRIPT_PATH,
			Name = "Zgjfjfl_SimpleAio.version",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/Zgjfjfl_SimpleAio.version"
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
				print("SimpleAio: Found update! Downloading...")
				DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
				DelayAction(function()
					print("SimpleAio: Successfully updated. Press 2x F6!")
				end, 3)
			end
		end, 3)

	end

	AutoUpdate()

end

local Heroes = {"Ornn", "JarvanIV", "Poppy", "Shyvana", "Trundle", "Rakan", "Belveth", "Nasus", "Singed", "Udyr", "Galio", "Yorick", "Ivern", 
				"Bard", "Taliyah", "Lissandra", "Sejuani", "KSante", "Skarner", "Maokai", "Gragas", "Milio", "AurelionSol", "Heimerdinger", 
				"Briar", "Urgot", "Aurora"}

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
local GameIsWall = Game.isWall
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

local function isUnderTurret2(pos)
	for i, turret in ipairs(getEnemyTurrets()) do
		local range = (turret.boundingRadius + 750)
		if not turret.dead then 
			if turret.pos:DistanceTo(pos) < range then
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

local function getBuffData(unit, buffname)
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
		if hero.team ~= myHero.team and hero.dead == false and getDistanceSqr(unit, hero.pos) < Range then
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
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 8 or buff.type == 12 or buff.type == 22 or buff.type == 23 or buff.type == 25 or buff.type == 30 or buff.type == 35) and buff.count > 0 then
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

Menu = MenuElement({type = MENU, id = "zg"..myHero.charName, name = "Simple "..myHero.charName, leftIcon = "http://ddragon.leagueoflegends.com/cdn/14.17.1/img/champion/"..myHero.charName..".png"})
	Menu:MenuElement({name = " ", drop = {"Version: " .. Version}})

------------------------------------

class "Ornn"
		
function Ornn:__init()		 
	print("Simple Ornn Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 65, Range = 800, Speed = 1800, Collision = false}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 750, Speed = 1600, Collision = false}
	self.r1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 170, Range = 2500, Speed = 1200, Collision = false}
	self.qPos = {}
	self.qTimer = nil
end

function Ornn:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ED", name = "E KnockUp Range", min = 0, max = 360, value = 300, step = 10})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR1 when hit X enemies inrange", min = 1, max = 5, value = 2, step = 1})
		Menu.Combo:MenuElement({id = "R2", name = "[R2]", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

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
	if isSpellReady(_Q) then
		if msg == KEY_UP and wParam == HK_Q then
			--print("1")
			self.qTimer = Game.Timer() + 1.25
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
		if Game.Timer() - qPos.Timer > 4.5 then
			TableRemove(self.qPos, k)
		end
	--Draw.Circle(qPos.pos, 100)
	end
end

function Ornn:Combo()

	if myHero.activeSpell.valid then return end

	local target = TargetSelector:GetTarget(800)
	if target and isValid(target) and target.pos2D.onScreen then

		local objpos = target.pos:Extended(myHero.pos, -Menu.Combo.ED:Value())

		if (not MapPosition:intersectsWall(target.pos, objpos) or not isSpellReady(_E)) and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
			if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 400 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
			end
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero:GetSpellData(_R).name ~= "OrnnRCharge"then
			castSpellHigh(self.wSpell, HK_W, target)
			lastW = GetTickCount()
		end

		if Menu.Combo.EQ:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
			local castPos = nil
			for _, qPos in pairs(self.qPos) do
				if not MapPosition:intersectsWall(myHero.pos, qPos.pos) and getEnemyCount(Menu.Combo.ED:Value(), qPos.pos) >= 1 and myHero.pos:DistanceTo(qPos.pos) <= self.eSpell.Range then
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

		if Menu.Combo.EWall:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero:GetSpellData(_R).name ~= "OrnnRCharge" then
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
				if target.pos:DistanceTo(ECastPos2) < Menu.Combo.ED:Value() and myHero.pos:DistanceTo(ECastPos2) < self.eSpell.Range then
					Control.CastSpell(HK_E, ECastPos2)
					lastE = GetTickCount()
				end
			end
		end
	end
	
	local Rtarget = TargetSelector:GetTarget(2500)
	if Rtarget and isValid(Rtarget) and Rtarget.pos2D.onScreen then
		if Menu.Combo.R2:Value() and isSpellReady(_R) and myHero:GetSpellData(_R).name == "OrnnRCharge" then
			for i = GameParticleCount(), 1, -1 do
				local particle = GameParticle(i)
				if particle and particle.name:find("Ornn") and particle.name:find("R_Wave_Mis") then
					local closePoint, isOnSegment = GGPrediction:ClosestPointOnLineSegment(particle.pos, Rtarget.pos, myHero.pos)
					if isOnSegment and myHero.pos:DistanceTo(particle.pos) < 700 then
						Control.CastSpell(HK_R, Rtarget)
					end
				end
			end
		end
	end

	if Menu.Combo.R:Value() and isSpellReady(_R) and myHero:GetSpellData(_R).name == "OrnnR" and lastR + 600 < GetTickCount() then
		local enemies = ObjectManager:GetEnemyHeroes(self.r1Spell.Range)
		for i, enemy in ipairs(enemies) do
			if getEnemyCount(170, enemy.pos) >= Menu.Combo.Rcount:Value() then
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
		if Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
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
			
		if Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 400 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end
		if Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
			castSpellHigh(self.wSpell, HK_W, target)
			lastW = GetTickCount()
		end
	end
end

function Ornn:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.Circle(myHero.pos, self.r1Spell.Range, Draw.Color(192, 255, 255, 255))
	end
end
------------------------------
class "JarvanIV"
		
function JarvanIV:__init()		 
	print("Simple JarvanIV Loaded") 
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
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EQ", name = "[EQ]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WHp", name = "use W when self HP %", value = 40, min=5, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "WCount", name = "or use W when can hit >= X enemies", value=2, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHp", name = "use R when target HP %", value = 40, min=5, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "RCount", name = "or use R when can hit >= X enemies", value=2, min = 1, max = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "EQ", name = "[EQ] to mouse", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "W", name = "[W] slow enemy", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
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
			if Menu.Combo.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
				if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
					Control.SetCursorPos(castPos)
					DelayAction(function() 
						Control.KeyDown(HK_E)
						Control.KeyUp(HK_E)
						Orbwalker:SetMovement(false)
						Orbwalker:SetAttack(false)
						DelayAction(function()
							Control.KeyDown(HK_Q)
							Control.KeyUp(HK_Q)
							Control.SetCursorPos(mousePos)
							Orbwalker:SetMovement(true)
							Orbwalker:SetAttack(true)
						end, 0.05)
					end, 0.05)
				end
			end
		end
				
		if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and not isSpellReady(_E) and myHero:GetSpellData(_E).currentCd > 2 and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and ((myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero.health/myHero.maxHealth <= Menu.Combo.WHp:Value()/100) or getEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value()) then
			Control.CastSpell(HK_W)
		end

		if Menu.Combo.R:Value() and isSpellReady(_R) and not CastingQ and not isDash and not haveBuff(myHero, "JarvanIVCataclysm") then
			if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and (target.health/target.maxHealth <= Menu.Combo.RHp:Value()/100 or getEnemyCount(self.rSpell.Radius, target.pos) >= Menu.Combo.RCount:Value()) then
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
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() then
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
		if Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end

	end
end

function JarvanIV:KillSteal()
	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if target and isValid(target) then
		if isSpellReady(_Q) and lastQ + 500 < GetTickCount() and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
			end	
		end

		if isSpellReady(_E) and Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
			end	
		end

		if isSpellReady(_R) and Menu.KS.R:Value() and not haveBuff(myHero, "JarvanIVCataclysm") and not CastingQ and not isDash then
			if self:getrDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
				Control.CastSpell(HK_R, target)
			end	
		end

	end
end

function JarvanIV:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 40 * qlvl + 50
	local qadDmg = myHero.bonusDamage * 1.4
	local qDmg = qbaseDmg + qadDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function JarvanIV:geteDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 40 * elvl + 40
	local eapDmg = myHero.ap * 0.8
	local eDmg = ebaseDmg + eapDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function JarvanIV:getrDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local rbaseDmg = 125 * rlvl + 75
	local radDmg = myHero.bonusDamage * 1.8
	local rDmg = rbaseDmg + radDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg) 
end

function JarvanIV:Flee()
	if Menu.Flee.EQ:Value() and isSpellReady(_Q) and isSpellReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
		local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
		Control.SetCursorPos(pos)
		DelayAction(function() 
			Control.KeyDown(HK_E)
			Control.KeyUp(HK_E)
			DelayAction(function()
				Control.KeyDown(HK_Q)
				Control.KeyUp(HK_Q)
				Control.SetCursorPos(mousePos)
			end, 0.05)
		end, 0.05)
	end

	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if target and isValid(target) then
		if isSpellReady(_W) and not isSpellReady(_Q) and Menu.Flee.W:Value() then
			if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
				Control.CastSpell(HK_W)
			end	
		end
	end
end

function JarvanIV:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end
------------------------------

class "Poppy"
		
function Poppy:__init()		 
	print("Simple Poppy Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 430, Speed = math.huge, Collision = false}
	self.eSpell = { Range = 475 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 450, Speed = 2500, Collision = false}
	self.r2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 1200, Speed = 2500, Collision = false}
end

function Poppy:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 50, max = 400, value = 400, step = 50})
		Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP %", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		
	Menu:MenuElement({type = MENU, id = "Antidash", name = "W Setting "})
		Menu.Antidash:MenuElement({id = "W", name = "[W] Anti-Dash", toggle = true, value = true})
		Menu.Antidash:MenuElement({type = MENU, id = "Wtarget", name = "Use On"})
			DelayAction(function()
				for i, Hero in pairs(getEnemyHeroes()) do
					Menu.Antidash.Wtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = false})		
				end		
			end,0.2)
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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
	if Menu.Antidash.W:Value() then
		self:AutoW()
	end
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end

end

function Poppy:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(500)
	if target and isValid(target) then
	
		for dis = 20, Menu.Combo.ED:Value(), 20 do
			local endPos = target.pos:Extended(myHero.pos, -dis)
			if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				if GameIsWall == nil then
					if MapPosition:inWall(endPos) then
						Control.CastSpell(HK_E, target)
						lastE = GetTickCount()
					end
				else
					if GameIsWall(endPos) then
						Control.CastSpell(HK_E, target)
						lastE = GetTickCount()
					end
				end
			end
		end
						
		if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end
		
		if Menu.Combo.RF:Value() and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth <= Menu.Combo.RFHP:Value()/100 then
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
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
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
			
		if Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end

	end
end

function Poppy:AutoW()
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if isValid(enemy) then
			local blockobj = Menu.Antidash.Wtarget[enemy.charName] and Menu.Antidash.Wtarget[enemy.charName]:Value()
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
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, self.r2Spell.Range, Draw.Color(192, 255, 255, 255))
	end

end
------------------------------
class "Shyvana"
		
function Shyvana:__init()		 
	print("Simple Shyvana Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 925, Speed = 1600, Collision = false}
	self.e2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.333, Radius = 345, Range = 1200, Speed = 1575, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 160, Range = 850, Speed = 700, Collision = false}
end

function Shyvana:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Use on target HP %", value = 50, min=0, max = 100 })
		Menu.Combo:MenuElement({id = "RC", name = "[R] Use X enemies in range", value = 1, min = 1, max = 5})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "R", name = "[R] to mouse", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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
		if myHero.pos:DistanceTo(target.pos) < 400 and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount()then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			castSpellHigh(self.eSpell, HK_E, target)
			lastE = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount()then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end

		local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
		if DragonForm then
			if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() then
				castSpellHigh(self.e2Spell, HK_E, target)
				lastE = GetTickCount()
			end
		end

		if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 350 < GetTickCount() and (target.health/target.maxHealth <= Menu.Combo.RHP:Value() / 100) then
		local numEnemies = getEnemyHeroesWithinDistance(self.rSpell.Range)
			if #numEnemies >= Menu.Combo.RC:Value() then
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
		if myHero.pos:DistanceTo(target.pos) < 400 and Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
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
			if myHero.pos:DistanceTo(target.pos) < self.e2Spell.Range and Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() then
				castSpellHigh(self.e2Spell, HK_E, target)
				lastE = GetTickCount()
			end
		end
			
		if Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			castSpellHigh(self.eSpell, HK_E, target)
			lastE = GetTickCount()
		end

	end
end
function Shyvana:Flee()
	if Menu.Flee.W:Value() and isSpellReady(_W) then
		Control.CastSpell(HK_W)
	end
	if Menu.Flee.R:Value() and isSpellReady(_R) then
		Control.CastSpell(HK_R, mousePos)
	end
end

function Shyvana:Draw()
	if Menu.Draw.E:Value() and isSpellReady(_E)then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R)then
			Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
	end

end
------------------------------
class "Trundle"
		
function Trundle:__init()		 
	print("Simple Trundle Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 775, Range = 750, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1000, Speed = math.huge, Collision = false}
	self.rSpell = { Range = 650 }
end

function Trundle:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value = 60, min=0, max = 100, step=5})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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
		if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) > 300 then
			local offset = IsFacing(target) and 100 or 200
			local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) + offset)
			if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
				Control.CastSpell(HK_E, castPos)
				lastE = GetTickCount()
			end
		end

		if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 350 < GetTickCount() and (myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value() / 100) then
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
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount()then
			Control.CastSpell(HK_W, myHero)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount()then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end

end

function Trundle:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(500)
	if target and isValid(target) then

		if Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= 300 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end

	end
end
function Trundle:Flee()
	if Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W, mousePos)
		lastW = GetTickCount()
	end
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if target and isValid(target) then
		if Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
	local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) - 100)
			Control.CastSpell(HK_E, castPos)
			lastE = GetTickCount()
		end
	end
end

function Trundle:Draw()
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
	end

end
------------------------------
class "Rakan"
		
function Rakan:__init()		 
	print("Simple Rakan Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 725, Speed = 1700, Collision = false}
end

function Rakan:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E2", name = "[E] on allies taking damage", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] when enemies>=2 within Wrange", toggle = true, value = true})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "E", name = "[E] to Ally", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
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
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
			 castSpellHigh(self.wSpell, HK_W, target)
			 lastW = GetTickCount()
		end
	end

	if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 600 < GetTickCount() and getEnemyCount(self.wSpell.Range, myHero.pos) >= 2 then
		 Control.CastSpell(HK_R)
		 lastR = GetTickCount()
	end

	if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
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

	if Menu.Combo.E2:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
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

		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
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
	if Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
		local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.wSpell.Range
			Control.CastSpell(HK_W, pos)
			lastW = GetTickCount()
	end

	if Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and not isSpellReady(_W) then
		for i = 1, GameHeroCount() do
			local hero = GameHero(i)
			if hero and not hero.dead and hero.isAlly and not hero.isMe then
			local distance1 = hero.pos:DistanceTo(myHero.pos)
			local distance2 = mousePos:DistanceTo(hero.pos)
				 if distance2 < mousePos:DistanceTo(myHero.pos) and (distance1 <= 700 or (hero.charName == "Xayah" and distance1 <= 1000)) then
					Control.CastSpell(HK_E, hero)
					lastE = GetTickCount()
				 end
			end
		end
	end
end

function Rakan:Draw()
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end

end
------------------------------
class "Belveth"

function Belveth:__init()		 
	print("Simple Belveth Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 450, Speed = myHero:GetSpellData(_E).speed, Collision =false}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 100, Range = 660, Speed = math.huge, Collision = false}
	self.eSpell = {Range = 500}
end

function Belveth:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EHP", name = "[E] Use when self HP %", value = 30, min=0, max = 100 })
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
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
		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and not castingE then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and not castingE then
			 castSpellHigh(self.wSpell, HK_W, target)
			 lastW = GetTickCount()
		end

		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and getEnemyCount(self.eSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < Menu.Combo.EHP:Value()/100 then
			 Control.CastSpell(HK_E)
			 lastE = GetTickCount()
		end
	end
end	

function Belveth:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1000)
	if target and isValid(target) then

		if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() then
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
		if Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 600 < GetTickCount() then
			bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
			if bestCount > 0 then 
				Control.CastSpell(HK_W, bestPosition)
				lastW = GetTickCount()
			end
		end
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			Control.CastSpell(HK_Q, target)
			lastQ = GetTickCount()
		end
	end
end

function Belveth:Flee()
	if Menu.Flee.Q:Value() and isSpellReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
	end
end

function Belveth:KillSteal()
	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if target and isValid(target) then

		if isSpellReady(_E) and lastE + 250 < GetTickCount() and Menu.KS.E:Value() then
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
	local ebaseDmg = elvl + 5
	local eadDmg = myHero.totalDamage * 0.08
	local exttimes = math.floor(((myHero.attackSpeed - 1) / 0.333) + 0.5)
	local eDmg = (ebaseDmg + eadDmg) * (1 + missingHP * 3) * (6 + exttimes)
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg) 
end

function Belveth:Draw()

	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end

end
-------------------------------
class "Nasus"
		
function Nasus:__init()		 
	print("Simple Nasus Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.wSpell = { Range = 700 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 650, Speed = math.huge, Collision =false}
end

function Nasus:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value=30, min=10, max=100})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "EH", name = "E hits x minions", value = 3, min = 1, max = 6})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function Nasus:onTick()

	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end
	local numEnemies = getEnemyHeroesWithinDistance(700)
	if #numEnemies >= 1 and myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value()/100 and Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 300 < GetTickCount() then
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
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
			 Control.CastSpell(HK_Q)
			 lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			 Control.CastSpell(HK_W, target)
			 lastW = GetTickCount()
		end

		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			 castSpellHigh(self.eSpell, HK_E, target)
			 lastE = GetTickCount()
		end

	end
end	

function Nasus:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1000)
	if target and isValid(target) then
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
			 Control.CastSpell(HK_Q)
			 lastQ = GetTickCount()
		end

		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
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
		if Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
			if bestCount >= Menu.Clear.EH:Value() then 
				Control.CastSpell(HK_E, bestPosition)
				lastE = GetTickCount()
			end
		end
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
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
	
		if Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 300 and self:getqDmg(target) >= target.health then
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

		if isSpellReady(_E) and lastE + 350 < GetTickCount() and Menu.KS.E:Value() and self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			Control.CastSpell(HK_E, target)
			lastE = GetTickCount()
		end

		if isSpellReady(_Q) and lastQ + 250 < GetTickCount() and Menu.KS.Q:Value() and self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < 300 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
			Control.Attack(target)
		end	
	end
end 

function Nasus:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 20 * qlvl + 15
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
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end
------------------------------

class "Singed"
		
function Singed:__init()		 
	print("Simple Singed Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 265, Range = 1000, Speed = 700, Collision =false}
end

function Singed:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR when X enemies inWrange ", value = 2, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})

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
	if #enemies == 0 and #minions == 0 and haveBuff(myHero, "PoisonTrail") and lastQ +250 < GetTickCount() then
		Control.CastSpell(HK_Q)
		lastQ = GetTickCount()
	end
end

function Singed:Combo()

	local target = TargetSelector:GetTarget(1000)
	if target and isValid(target) then
		if Menu.Combo.Q:Value() and myHero.pos:DistanceTo(target.pos) <= 500 then
			if isSpellReady(_Q) and lastQ +250 < GetTickCount() and myHero:GetSpellData(_Q).toggleState == 1 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
		end
		if Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < 1000 then
			self:CastW(target)
		end
		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE +350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= 300 then
			Control.CastSpell(HK_E, target)
			lastE = GetTickCount()
		end
	end
	if #enemies >= Menu.Combo.Rcount:Value() then
		if Menu.Combo.R:Value() and isSpellReady(_R) and lastR +250 < GetTickCount() then
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
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end
------------------------------
class "Udyr"
		
function Udyr:__init()		 
	print("Simple Udyr Loaded") 
	self:LoadMenu()

	Callback.Add("Tick", function() self:onTick() end)

end

function Udyr:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Style", name = "Playstyle Set"})
		Menu.Style:MenuElement({id = "MainR", name = "Main R Playstyle", value = true})
		Menu.Style:MenuElement({id = "MainQ", name = "Main Q Playstyle", value = false})
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Whp", name = "[W] use when X% hp ", value = 50, min = 0, max = 100})
		Menu.Combo:MenuElement({id = "W2hp", name = "use AwakenedW when self X% hp ", value = 30, min = 0, max = 100})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "Whp", name = "[W] use when self X% hp", value = 30, min = 0, max = 100})
		Menu.Clear:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

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

		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and not hasAwakenedE and not hasAwakenedR then
			Control.CastSpell(HK_E)
			lastE = GetTickCount()
		end

		if Menu.Style.MainR:Value() then
			if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE or hasAwakenedR) and R1.duration < 1.5 and myHero.pos:DistanceTo(target.pos) < 450 then
				Control.CastSpell(HK_R)
				lastR = GetTickCount()
			end
			if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_R) or not hasAwakenedR) and not hasAwakenedQ and myHero.pos:DistanceTo(target.pos) < 300 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
		end

		if Menu.Style.MainQ:Value() then
			if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE or (hasAwakenedQ and not haspassiveAA)) and myHero.pos:DistanceTo(target.pos) < 300 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
			if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() and (not isSpellReady(_E) or hasAwakenedE) and (not isSpellReady(_Q) or not hasAwakenedQ) and not hasAwakenedR and myHero.pos:DistanceTo(target.pos) < 450 then
				Control.CastSpell(HK_R)
				lastR = GetTickCount()
			end
		end

		if myHero.health/myHero.maxHealth <= Menu.Combo.Whp:Value()/100 and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and getEnemyCount(600, myHero.pos) >= 1 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.health/myHero.maxHealth <= Menu.Combo.W2hp:Value()/100 and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and hasAwakenedW and getEnemyCount(600, myHero.pos) >= 1 then
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
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and c == 1 then
			Control.CastSpell(HK_Q)
				if hasAwakenedQ then
					Control.CastSpell(HK_Q)
				end
		elseif not hasAwakenedR and isSpellReady(_R) and not isSpellReady(_Q) then
				Control.CastSpell(HK_R)
		end
		if Menu.Clear.R:Value() and isSpellReady(_R) and c > 1 then
			Control.CastSpell(HK_R)
				if hasAwakenedR and R1.duration < 0.5 then
					Control.CastSpell(HK_R)
				end
		elseif not hasAwakenedQ and isSpellReady(_Q) and not isSpellReady(_R) then
				Control.CastSpell(HK_Q)
		end
		if myHero.health/myHero.maxHealth <= Menu.Clear.Whp:Value()/100 and Menu.Clear.W:Value() and isSpellReady(_W) then
			Control.CastSpell(HK_W)
		end
	end
end

------------------------------
class "Galio"
		
function Galio:__init()		 
	print("Simple Galio Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 825, Speed = 1400, Collision =false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 650, Speed = 2300, Collision = false}
	self.wSpell = {Range = 480}
end

function Galio:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
		Menu.Auto:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
		Menu.Auto:MenuElement({id = "WHP", name = "Auto W self HP%&enemies inwrange", value = 30, min=0, max = 100 })
		Menu.Auto:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash on ME"})
			DelayAction(function()
				for i, Hero in pairs(getEnemyHeroes()) do
					Menu.Auto.WB:MenuElement({id = Hero.charName, name = Hero.charName, value = false})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range in minimap", toggle = true, value = true})
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
		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end

		local pred = GGPrediction:SpellPrediction(self.eSpell)
		pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local lineE = LineSegment(myHero.pos, pred.CastPosition)
				if not MapPosition:intersectsWall(lineE) then
					if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 500 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
						 castSpellHigh(self.eSpell, HK_E, target)
						 lastE = GetTickCount()
					end
				end
			end

		if Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			 self:CastW(Menu.Combo.Wtime:Value())
		end
	end
end	

function Galio:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if target and isValid(target) then

		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end
	end
end

function Galio:AutoW()

	if Menu.Auto.W:Value() and getEnemyCount(self.wSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < Menu.Auto.WHP:Value()/100 then
		self:CastW(Menu.Auto.Wtime:Value())
	end

	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if isValid(enemy) then
			local obj = Menu.Auto.WB[enemy.charName] and Menu.Auto.WB[enemy.charName]:Value()
			if obj and enemy.pathing.isDashing then
				local vct = Vector(enemy.pathing.endPos.x, enemy.pathing.endPos.y, enemy.pathing.endPos.z)
				if vct:DistanceTo(myHero.pos) < self.wSpell.Range then
					self:CastW(Menu.Auto.Wtime:Value())
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
	if Menu.Flee.E:Value() and isSpellReady(_E) then
		local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.eSpell.Range
			Control.CastSpell(HK_E, pos)
	end
end

function Galio:KillSteal()
	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if target and isValid(target) then

		if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
			end	
		end
	end
end

function Galio:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 35 * qlvl + 35
	local qapDmg = myHero.ap * 0.7
	local qDmg = qbaseDmg + qapDmg
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg) 
end


function Galio:Draw()
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
	end
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(225, 225, 0, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.CircleMinimap(myHero.pos, 3250 + 750*myHero:GetSpellData(_R).level, 1, Draw.Color(200,50,180,230))
	end
end
------------------------------
class "Yorick"
		
function Yorick:__init()		 
	print("Simple Yorick Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 225, Range = 600, Speed = math.huge, Collision =false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = 1800, Collision = false}
	self.rSpell = {Range = 600}
end

function Yorick:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R1", name = "[R1] ", toggle = true, value = true})
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "Q2", name = "[Q2] activate Mist Walker", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
		Menu.Auto:MenuElement({id = "W", name = "AutoW on Immobile Target", value = true})

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
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
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 250 < GetTickCount() then
			 Control.CastSpell(HK_Q)
			 lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			 castSpellHigh(self.wSpell, HK_W, target)
			 lastW = GetTickCount()
		end

		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			 castSpellHigh(self.eSpell, HK_E, target)
			 lastE = GetTickCount()
		end

		if Menu.Combo.R1:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "YorickR" and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range then
			 Control.CastSpell(HK_R, target)
			 lastR = GetTickCount()
		end

	end
end	

function Yorick:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if target and isValid(target) then

		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() then
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
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
			Control.Attack(target)
		end

		if Menu.Clear.Q2:Value() and myHero:GetSpellData(_Q).name == "YorickQ2" then
			Control.CastSpell(HK_Q)
		end

		if Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 450 < GetTickCount() then
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
		if Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" and myHero.pos:DistanceTo(target.pos) <= 300 and self:getqDmg(target) >= target.health then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
			Control.Attack(target)
		end
	end
end

function Yorick:Flee()
	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if target and isValid(target) then

		if Menu.Flee.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
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

		if isSpellReady(_Q) and lastQ + 250 < GetTickCount() and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= 300 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				Control.Attack(target)
			end	
		end

		if isSpellReady(_E) and lastE + 450 < GetTickCount() and Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
				lastE = GetTickCount()
			end	
		end
	end
end

function Yorick:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 25 * qlvl + 5
	local qadDmg = myHero.totalDamage * 0.4
	local qDmg = qbaseDmg + qadDmg + myHero.totalDamage
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function Yorick:geteDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 35 * elvl + 35
	local eapDmg = myHero.ap * 0.7
	local eDmg = ebaseDmg + eapDmg
return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function Yorick:AutoW()
	if Attack:IsActive() then return end
	for i, target in pairs(getEnemyHeroes()) do
		if Menu.Auto.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and isInvulnerable(target) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
	end
			
	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if target and isValid(target) then
		if Menu.Auto.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and isImmobile(target) then
			if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
				castSpellHigh(self.wSpell, HK_W, target)
				lastW = GetTickCount()
			end
		end
	end
end

function Yorick:Draw()
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
	end

end
------------------------------
class "Ivern"
		
function Ivern:__init()		 
	print("Simple Ivern Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)

	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1150, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.eSpell = { Range = 750, Radius = 500 }
	self.rSpell = { Range = 800 }
end

function Ivern:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R1]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
		Menu.AutoE:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
			DelayAction(function()
				for i, Hero in pairs(getAllyHeroes()) do
					Menu.AutoE.Etarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "Daisy", name = "Daisy Setting"})
		Menu.Daisy:MenuElement({id = "R1", name = "Control 'Daisy' attack target", key = string.byte("T")})
		Menu.Daisy:MenuElement({id = "R2", name = "Control 'Daisy' follow self", key = string.byte("Z")})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
		Menu.Misc:MenuElement({id = "disableAA", name = "Disable AA", toggle = true, value = true})
		Menu.Misc:MenuElement({id = "count", name = "DisableAA when >= X enemies inQrange", value = 3, min = 1 , max = 5 , step = 1})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
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

	if Menu.AutoE.E:Value() then
		self:AutoE()
	end

	if myHero:GetSpellData(_R).name == "IvernRRecast" then
		self:DaisyControl()
	end

	if Menu.Misc.disableAA:Value() and getEnemyCount(self.qSpell.Range, myHero.pos) >= Menu.Misc.count:Value() then
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
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() then
			self:CastQ(target)
		end
		if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and myHero:GetSpellData(_R).name == "IvernR" and Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
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
					if #allies == 1 and ally.isMe and Menu.AutoE.Etarget[ally.charName]:Value() then
						if ally.pos:DistanceTo(enemy.pos) < self.eSpell.Radius then 
							Control.CastSpell(HK_E, ally)
							lastE = GetTickCount()
						end
					elseif #allies > 1 and not ally.isMe and Menu.AutoE.Etarget[ally.charName]:Value() then
						if ally.pos:DistanceTo(enemy.pos) < self.eSpell.Radius then
							if ally.pos:DistanceTo(enemy.pos) < myHero.pos:DistanceTo(enemy.pos) or (Menu.AutoE.Etarget[myHero.charName]:Value() == false) then
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
		if Menu.Daisy.R1:Value() then
			Control.CastSpell(HK_R, target)
		end
	end
	if Menu.Daisy.R2:Value() then
		 Control.CastSpell(HK_R, myHero)
	end
end

function Ivern:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if target and isValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and myHero:GetSpellData(_Q).name == "IvernQ" and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end
	end
end

function Ivern:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end
------------------------------
class "Bard"
		
function Bard:__init()		 
	print("Simple Bard Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 850, Speed = 1500, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.qextSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1150, Speed = 1500, Collision = false}
	self.wSpell = { Range = 800 }
end

function Bard:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q] Single", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q2", name = "[Q] Stun with minion or enemyteam", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q3", name = "[Q] Stun with wall", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
		Menu.Auto:MenuElement({id = "W", name = "[W] Auto", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Whp", name = "[W] auto on ally or self X hp%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
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

	local target = TargetSelector:GetTarget(self.qextSpell.Range)
	if target and isValid(target) then
		if isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			if Menu.Combo.Q:Value() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
				return
			end

			if Menu.Combo.Q3:Value() then
				local pred = GGPrediction:SpellPrediction(self.qSpell)
				pred:GetPrediction(target, myHero)
				if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
					local extendPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -300)
					local lineQ = LineSegment(pred.CastPosition, extendPos)
					if MapPosition:intersectsWall(lineQ) then
						Control.CastSpell(HK_Q, pred.CastPosition)
						lastQ = GetTickCount()
						return
					end
				end
			end

			if Menu.Combo.Q2:Value() then
				local pred2 = GGPrediction:SpellPrediction(self.qextSpell)
				pred2:GetPrediction(target, myHero)
				if pred2:CanHit(GGPrediction.HITCHANCE_HIGH) then
					local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, pred2.CastPosition, self.qextSpell.Speed, self.qextSpell.Delay, self.qextSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
					if collisionCount == 1 then
						local unit = collisionObjects[1]
						if isValid(unit) and unit.pos:DistanceTo(pred2.CastPosition) < 300 and unit.pos:DistanceTo(myHero.pos) < self.qSpell.Range then
							Control.CastSpell(HK_Q, pred2.CastPosition)
							lastQ = GetTickCount()
							return
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
			if getDistance(myHero.pos, hero.pos) <= self.wSpell.Range and Menu.Auto.W:Value() and hero.health/hero.maxHealth <= Menu.Auto.Whp:Value()/100 and isSpellReady(_W) and lastW + 350 < GetTickCount() then
				Control.CastSpell(HK_W, hero)
				lastW = GetTickCount()
			end
		end
	end
end

function Bard:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end

------------------------------
class "Taliyah"
		
function Taliyah:__init()		 
	print("Simple Taliyah Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = 3600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 225, Range = 900, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1700, Collision = false}
end

function Taliyah:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Wpush", name = "[W] push range", value = 400, min = 100, max = 600, step = 50})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Erange", name = "[E] cast range", value = 900, min = 100, max = 950, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
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
		local deltaMousePos = mousePos-mouseCurrentPos
		mouseReturnPos = mouseReturnPos + deltaMousePos
		Control.SetCursorPos(pos2)
		mouseCurrentPos = pos2
	end
	vectorCast[#vectorCast + 1] = function ()
		Control.KeyUp(key)
	end
	vectorCast[#vectorCast + 1] = function ()	
		local deltaMousePos = mousePos -mouseCurrentPos
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
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end

		if myHero.pos:DistanceTo(target.pos) < Menu.Combo.Erange:Value() and Menu.Combo.E:Value() and isSpellReady(_E) and not isSpellReady(_W) and lastE + 350 < GetTickCount() then
			 Control.CastSpell(HK_E, target)
			 lastE = GetTickCount()
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) then
			local predPos = target:GetPrediction(self.wSpell.Speed, self.wSpell.Delay)
			local d = myHero.pos:DistanceTo(predPos)
			if d < self.wSpell.Range then
				local endPos = predPos + (myHero.pos - predPos):Normalized() * 225
				if d <= Menu.Combo.Wpush:Value() then
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
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end
	end
end

function Taliyah:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end

------------------------------
class "Lissandra"
		
function Lissandra:__init()		 
	print("Simple Lissandra Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range =825, Speed = 2200, Collision = false}
	self.q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range =950, Speed = 2200, Collision = false}
	self.wSpell = { Radius = 450 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 125, Range = 1050, Speed = 1200, Collision = false}
	self.rSpell = { Range = 550, Radius = 550 }
end

function Lissandra:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E1", name = "[E1]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E2", name = "[E2]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E2Hp", name = "Use E2 when self Hp > X%", value = 50, min = 1, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "ecountW", name = "E2+W when enemies count <= X", value = 2, min = 1, max = 5, step = 1})
		Menu.Combo:MenuElement({id = "ecountR", name = "E2+R when enemies count <= X", value = 2, min = 1, max = 5, step = 1})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R2Hp", name = "Use R self when Hp <= X%", value = 40, min = 1, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "R2count", name = "or R self when enemies count >= X", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "Mana", name = "Harass min Mana", value = 50, min = 1, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "[E] to mouse", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q2", name = "[Q2] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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

		if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() then
			if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and self:R1Health() and getEnemyCount(self.rSpell.Radius, myHero.pos) < Menu.Combo.R2count:Value() then
				Control.CastSpell(HK_R, target)
				lastR = GetTickCount()
			end
		end

		if Menu.Combo.Q:Value() then
			self:CastQ(target)
		end

		if Menu.Combo.E1:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			if not self:E2Ready() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range-100 then
				castSpellHigh(self.eSpell, HK_E, target)
				lastE = GetTickCount()
			end
		end

		if Menu.Combo.E2:Value() and self:E2Health() and self:E2Ready() and isSpellReady(_E) then
			self:CastE2(target)
		end
	end

	if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() then
		if (self:R2Health() and getEnemyCount(self.rSpell.Radius, myHero.pos) > 0) or getEnemyCount(self.rSpell.Radius, myHero.pos) >= Menu.Combo.R2count:Value() then
			Control.CastSpell(HK_R, myHero)
			lastR = GetTickCount()
		end
	end

	if getEnemyCount(self.wSpell.Radius, myHero.pos) >= 1 and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W)
		lastW = GetTickCount()
	end
end

function Lissandra:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1000)
	if target and isValid(target) then
		if Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana > Menu.Harass.Mana:Value()/100 then
			self:CastQ(target)
		end
	end
end

function Lissandra:Flee()
	if not self:E2Ready() then
		if Menu.Flee.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			 Control.CastSpell(HK_E, mousePos)
			 lastE = GetTickCount()
			 DelayAction(function() Control.CastSpell(HK_E) end, 1.3)
		end
	end
end

function Lissandra:CheckEPos()
	local EmissilePos = nil

	local particle = nil
	for i = 1, GameParticleCount() do
		local p = GameParticle(i)
		if p and p.name:find("Lissandra") and p.name:find("E_Missile") then
			particle = p
			break
		end
	end
	if particle then
		EmissilePos = particle.pos:Extended(myHero.pos, 100)
	else
		EmissilePos = nil
	end
	return EmissilePos
end

function Lissandra:CastQ(target)
	local dis = myHero.pos:DistanceTo(target.pos)
	if isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
		if dis > self.qSpell.Range and dis < self.q2Spell.Range then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
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
	local missilePos = self:CheckEPos()
	local dist1 = myHero.pos:DistanceTo(target.pos)
	local enemyCount = getEnemyCount(600, target.pos)

	if missilePos then
		local dist2 = missilePos:DistanceTo(target.pos)

		if dist1 > dist2 and not isUnderTurret2(missilePos) then
			local shouldCastE = false

			if isSpellReady(_R) then
				if isSpellReady(_W) then
					if dist2 < self.wSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				else
					if dist2 < self.rSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				end
			else
				if isSpellReady(_W) then
					if dist2 < self.wSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountW:Value())
					end
				end
			end

			if shouldCastE then
				Control.CastSpell(HK_E)
			end
		end
	end
end

function Lissandra:E2Health()
	return myHero.health / myHero.maxHealth > Menu.Combo.E2Hp:Value()/100
end

function Lissandra:R1Health()
	return myHero.health / myHero.maxHealth > Menu.Combo.R2Hp:Value()/100
end

function Lissandra:R2Health()
	return myHero.health / myHero.maxHealth <= Menu.Combo.R2Hp:Value()/100
end

function Lissandra:E2Ready()
	return haveBuff(myHero, "LissandraE")
end

function Lissandra:Draw()

	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.Q2:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.q2Spell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Radius, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end
------------------------------
class "Sejuani"
		
function Sejuani:__init()		 
	print("Simple Sejuani Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 650, Speed = 1000, Collision = false}
	self.wSpell = { Range = 600 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1300, Speed = 1600, Collision = false}
	self.eSpell = { Range = 600 }
end

function Sejuani:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
end

function Sejuani:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if target and isValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 1000 < GetTickCount() then
			 castSpellHigh(self.wSpell, HK_W, target)
			 lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			 Control.CastSpell(HK_E)
			 lastE = GetTickCount()
		end
	end
end

function Sejuani:Harass()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if target and isValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and Menu.Harass.W:Value() and isSpellReady(_W) and lastW + 1000 < GetTickCount() then
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
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end
------------------------------
class "KSante"
		
function KSante:__init()		 
	print("Simple KSante Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 50, Range = 450, Speed = math.huge, Collision = false}
	self.q3Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 70, Range = 800, Speed = 1600, Collision = false}
	self.wSpell = { Range = 600 }
	self.e1Spell = { Range = 250 }
	self.e2Spell = { Range = 400 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 350, Speed = 2000, Collision = false}
end

function KSante:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W1", name = "Use W1 push target to tower/ally", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "W1Time", name = "W1 Channel time(s)", value = 0.75, min = 0.75, max = 1, step = 0.05})
		Menu.Combo:MenuElement({id = "W2", name = "[W] AllOut W", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W2Time", name = "AllOut W Channel time(s)", value = 0.75, min = 0.75, max = 1, step = 0.05})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EA", name = "use E close to enemy AApassive", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ET", name = "use E close to enemy useQ", toggle = true, value = true})
		--Menu.Combo:MenuElement({id = "EM", name = "use E allyminion close to enemy", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EH", name = "use E allyhero close to enemy", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RT", name = "[R] enemy close to allyturret (not near wall)", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Manual R when enemy near wall ", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear1", name = "Lane Clear"})
		Menu.Clear1:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear1:MenuElement({id = "QCount", name = "hit >=x minions", value = 2, min = 1, max = 6})

	Menu:MenuElement({type = MENU, id = "Clear2", name = "Jungle Clear"})
		Menu.Clear2:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = true})
end

function KSante:onTick()

	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end
	-- local baseHP, hpPerLevel = myHero.baseHP, myHero.hpPerLevel
	-- local bonusHealth = math.min(math.floor(myHero.maxHealth - (baseHP + hpPerLevel * (myHero.levelData.lvl - 1) * (0.7025 + 0.0175 * (myHero.levelData.lvl - 1)))), 1600)
	-- local time = math.floor(bonusHealth / 8000 * 100) / 100
	local bonusResist = myHero.bonusArmor + myHero.bonusMagicResist
	local time = math.floor((math.min(bonusResist, 120) * 0.00083) * 100) / 100
	--print(time)
	self.q1Spell.Delay = math.max(0.35, 0.45 - time)
	self.q3Spell.Delay = math.max(0.35, 0.45 - time)
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
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
end

function KSante:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(self.qSpell.Range + self.eSpell.Range)
	if target and isValid(target) then
		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and isSpellReady(_Q) then
			if Menu.Combo.EH:Value() then
				local allies = ObjectManager:GetAllyHeroes(550)
				for i, ally in ipairs(allies) do
					if not ally.isMe and getEnemyCount(self.qSpell.Range, myHero.pos) == 0 and getEnemyCount(self.qSpell.Range, ally.pos) >= 1 then
						Control.CastSpell(HK_E, ally)
						lastE = GetTickCount()
					end
				end
			end
			if Menu.Combo.ET:Value() then
				if myHero.pos:DistanceTo(target.pos) > self.qSpell.Range and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range + self.eSpell.Range then
					Control.CastSpell(HK_E, target)
					lastE = GetTickCount()
				end
			end
			--[[if Menu.Combo.EM:Value() then
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

		if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			 castSpellHigh(self.qSpell, HK_Q, target)
			 lastQ = GetTickCount()
		end

		if Menu.Combo.W:Value() and Menu.Combo.W2:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			if doesMyChampionHaveBuff("KSanteRTransform") then
				 self:CastW(target,Menu.Combo.W2Time:Value())
			end
		end

		if Menu.Combo.W:Value() and Menu.Combo.W1:Value() and myHero.pos:DistanceTo(target.pos) < 450 then
			local turrets = ObjectManager:GetAllyTurrets(2000)
			for i, turret in ipairs(turrets) do
				if turret.pos:DistanceTo(target.pos) < 1200 and turret.pos:DistanceTo(target.pos) < turret.pos:DistanceTo(myHero.pos) then
					self:CastW(target,Menu.Combo.W1Time:Value())
				end
			end
			local allies = ObjectManager:GetAllyHeroes(2000)
			for k, ally in ipairs(allies) do
				if not ally.isMe and ally.pos:DistanceTo(target.pos) < 1000 and ally.pos:DistanceTo(target.pos) < ally.pos:DistanceTo(myHero.pos) then
					self:CastW(target,Menu.Combo.W1Time:Value())
				end
			end
		end

		if Menu.Combo.RT:Value() and isSpellReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
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
				if Menu.Combo.E:Value() and Menu.Combo.EA:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
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
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
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
	if Menu.Clear1.Q:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
		for i = 1, #minions do
			local minion = minions[i]
			if isValid(minion) and minion.team ~= 300 then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount >= Menu.Clear1.QCount:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
					Control.CastSpell(HK_Q, minion)
					lastQ = GetTickCount()
				end
			end
		end
	end
end

function KSante:JungleClear()
	if Attack:IsActive() then return end
	if Menu.Clear1.Q:Value() then
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
		if Menu.LastHit.Q:Value() and isSpellReady(_Q) and lastQ + 350 < GetTickCount() then
			if self:getqDmg(minion) >= minion.health and not minion.dead then
				Control.CastSpell(HK_Q, minion)
				lastQ = GetTickCount()
			end
		end
	end
end

function KSante:getqDmg(unit)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 30 * qlvl + 40
	local qextDmg = myHero.bonusArmor * 0.40 + myHero.bonusMagicResist * 0.40
	local qDmg = qbaseDmg + qextDmg
return Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function KSante:Draw()
	if doesMyChampionHaveBuff("KSanteQ3") then
		self.qSpell = self.q3Spell
	else
		self.qSpell = self.q1Spell
	end
	if Menu.Draw.Q:Value() then
			Draw.Circle(myHero.pos, self.qSpell.Range, 0.5, Draw.Color(255, 225, 255, 10))
	end
end
------------------------------
class "Skarner"
		
function Skarner:__init()		 
	print("Simple Skarner Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1050, Speed = 1600, Collision = false}
	self.wSpell = {Range = 650}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.65, Radius = 150, Range = 625, Speed = math.huge, Collision = false}
end

function Skarner:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WCount", name = "Use W when can hit >= X enemies", value = 1, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RCount", name = "R hit x enemies", value = 2, min = 1, max = 5 })
		
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Skarner:onTick()

	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end	
	if haveBuff(myHero, "SkarnerR") then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
    if myHero.activeSpell.valid then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
		self:LaneClear()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Skarner:Combo()
	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if Qtarget and isValid(Qtarget) then
		if Menu.Combo.Q:Value() and isSpellReady(_Q) then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(Qtarget.pos) > Data:GetAutoAttackRange(myHero, Qtarget) then
					self:CastQ2(Qtarget)
				end
			end
		end
	end
	
	local Rtarget = TargetSelector:GetTarget(self.rSpell.Range)
	if Rtarget and isValid(Rtarget) then
		if Menu.Combo.R:Value() and isSpellReady(_R) then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, self.rSpell.Speed, self.rSpell.Delay, self.rSpell.Radius, {GGPrediction.COLLISION_ENEMYHERO}, nil)
			if collisionCount >= Menu.Combo.RCount:Value() then
				castSpellHigh(self.rSpell, HK_R, Rtarget)
			end
		end
	end

	if Menu.Combo.W:Value() and isSpellReady(_W) and getEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value() then
		Control.CastSpell(HK_W)
	end
end

function Skarner:CastQ2(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, Pred.CastPosition, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount > 0 then
			local minion = collisionObjects[1]
			if minion.pos:DistanceTo(Pred.CastPosition) < 250 then
				Control.CastSpell(HK_Q, Pred.CastPosition)
			end
		else
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function Skarner:Harass()
	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if Qtarget and isValid(Qtarget) then
		if Menu.Harass.Q:Value() and isSpellReady(_Q) then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(Qtarget.pos) > Data:GetAutoAttackRange(myHero, Qtarget) then
					self:CastQ2(Qtarget)
				end
			end
		end
	end
end

function Skarner:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if target and isValid(target) then
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(target.pos) > Data:GetAutoAttackRange(myHero, target) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end

		if Menu.Clear.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			Control.CastSpell(HK_W)
		end
	end
end

function Skarner:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

------------------------------
class "Maokai"
		
function Maokai:__init()		 
	print("Simple Maokai Loaded") 
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
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "InsecQ", name = "InsecQ to ally", value = false, key = string.byte("T"), toggle = true})
		Menu.Combo:MenuElement({id = "InsecRange", name = "allies in x range use insecQ", value = 1500, min = 500, max = 3000, step = 100 })
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "R hit x enemies", value = 2, min = 1, max = 5 })
		Menu.Combo:MenuElement({id = "Rrange", name = "R max range", value = 2000, min = 500, max = 3000, step = 100 })

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "InsecQ", name = "InsecQ", toggle = true, value = true})
end

function Maokai:onTick()

	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end	
	if Menu.Combo.InsecQ:Value() then
		local allies = ObjectManager:GetAllyHeroes(Menu.Combo.InsecRange:Value())
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

	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if Qtarget and isValid(Qtarget) then
		if Menu.Combo.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() and not isSpellReady(_W) then
			if (not Menu.Combo.InsecQ:Value()) or (Menu.Combo.InsecQ:Value() and Qtoward == nil) then
				castSpellHigh(self.qSpell, HK_Q, Qtarget)
				lastQ = GetTickCount()
			end

			if Menu.Combo.InsecQ:Value() and Qtoward ~= nil then
				local Pos = Qtarget.pos + (Qtarget.pos - Qtoward):Normalized() * 250
				if MapPosition:inWall(Pos) then
					castSpellHigh(self.qSpell, HK_Q, Qtarget)
					lastQ = GetTickCount()
				else
					if myHero.pos:DistanceTo(Pos) < 100 then
						castSpellHigh(self.qSpell, HK_Q, Qtarget)
						lastQ = GetTickCount()
					end
				end
			end
		end
	end

	local Wtarget = TargetSelector:GetTarget(self.wSpell.Range)
	if Wtarget and isValid(Wtarget) then
		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
			Control.CastSpell(HK_W, Wtarget)
			lastW = GetTickCount()
		end
	end

	local Etarget = TargetSelector:GetTarget(self.eSpell.Range)
	if Etarget and isValid(Etarget) then
		if Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			Control.CastSpell(HK_E, Etarget)
			lastE = GetTickCount()
		end
	end

	local Rtarget = TargetSelector:GetTarget(Menu.Combo.Rrange:Value())
	if Rtarget and isValid(Rtarget) then
		if isSpellReady(_R) and lastR + 600 < GetTickCount() and Menu.Combo.R:Value() then
			if getEnemyCount(self.rSpell.Radius, Rtarget.pos) >= Menu.Combo.Rcount:Value() then
				castSpellHigh(self.rSpell, HK_R, Rtarget)
				lastR = GetTickCount()
			end
		end
	end
end

function Maokai:Harass()

	if Attack:IsActive() then return end
	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if Qtarget and isValid(Qtarget) then
		if Menu.Harass.Q:Value() and isSpellReady(_Q) and lastQ + 500 < GetTickCount() then
			 castSpellHigh(self.qSpell, HK_Q, Qtarget)
			 lastQ = GetTickCount()
		end
	end
		
	local Etarget = TargetSelector:GetTarget(self.eSpell.Range)
	if Etarget and isValid(Etarget) then
		if Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 350 < GetTickCount() then
			 Control.CastSpell(HK_E, Etarget)
			 lastE = GetTickCount()
		end
	end
end

function Maokai:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
			Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
			Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
			Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
			Draw.Circle(myHero.pos, Menu.Combo.Rrange:Value(), 1, Draw.Color(255, 225, 255, 10))
	end

	if Menu.Draw.InsecQ:Value() then
		if Menu.Combo.InsecQ:Value() then
			Draw.Text("InsecQ:ON", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 000, 255, 000))
		else
			Draw.Text("InsecQ:OFF", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 255, 000, 000))
		end
	end
end

------------------------------
class "Gragas"
		
function Gragas:__init()		 
	print("Simple Gragas Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 850, Speed = 1000, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 800, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 1000, Speed = math.huge, Collision = false}
end

function Gragas:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Insec", name = "InsecR Setting"})
		Menu.Insec:MenuElement({id = "R1", name = "Semi-Manual InsecR Target to Self", key = string.byte("T")})
		Menu.Insec:MenuElement({id = "R2", name = "Auto InsecR on Immobile Target", value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
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

	if Menu.Insec.R1:Value() then
		self:InsecR()
	end

	if Menu.Insec.R2:Value() then
		self:AutoR()
	end

	self:KillSteal()
end

function Gragas:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1000)
	if target and isValid(target) then
		if Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and not isSpellReady(_E) then
			if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
			end
		end

		if Menu.Combo.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end

		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Combo.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
			castSpellHigh(self.eSpell, HK_E, target)
			lastE = GetTickCount()
		end

	end
end

function Gragas:Harass()

	if Attack:IsActive() then return end
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if target and isValid(target) then
		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() then
			castSpellHigh(self.qSpell, HK_Q, target)
			lastQ = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Harass.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() then
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
		if Menu.Clear.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_Q, target)
			lastQ = GetTickCount()
		end
		if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQToggle" and getBuffData(myHero, "GragasQ").duration < 2 then
			Control.CastSpell(HK_Q)
		end
		if Menu.Clear.W:Value() and isSpellReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if Menu.Clear.E:Value() and isSpellReady(_E) and lastE + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
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

		if isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and lastQ + 350 < GetTickCount() and Menu.KS.Q:Value() then
			if self:getQDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
				lastQ = GetTickCount()
			end	
		end

		if isSpellReady(_E) and lastE + 250 < GetTickCount() and Menu.KS.E:Value() then
			if self:getEDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
				lastE = GetTickCount()
			end	
		end

		if isSpellReady(_R) and lastR + 350 < GetTickCount() and Menu.KS.R:Value() then
			if self:getRDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
				castSpellHigh(self.rSpell, HK_R, target)
				lastR = GetTickCount()
			end	
		end
	end
end

function Gragas:getQDmg(target)	
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 40 * qlvl + 40
	local qapDmg = myHero.ap * 0.8
	local qDmg = qbaseDmg + qapDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg)
end

function Gragas:getEDmg(target)	
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 35 * elvl + 45
	local eapDmg = myHero.ap * 0.6
	local eDmg = ebaseDmg + eapDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg)
end

function Gragas:getRDmg(target)	
	local rlvl = myHero:GetSpellData(_R).level
	local rbaseDmg = 100 * rlvl + 100
	local rapDmg = myHero.ap * 0.8
	local rDmg = rbaseDmg + rapDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg)
end


function Gragas:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

--------------------------------

class "Milio"
		
function Milio:__init()
	print("Simple Milio Loaded")
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)	
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1200, Speed = 1200, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.qnocolSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1200, Speed = 1200, Collision = false}
	self.qnocolSpellextended = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 45, Range = 1500, Speed = 1200, Collision = false}
	self.qantidashSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 35, Range = 1200, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.wSpell = { Range = 650 }
	self.eSpell = { Range = 650 }
	self.rSpell = { Range = 700 }
end

function Milio:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "QBD", name = "[Q] ball collision minion bounces distance", value = 400, min = 100, max = 500, step = 50})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "RHP", name = "UseR when ally or self <= X hp%", value = 20, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({type = MENU,id = "Rhealtarget", name = "UseR On"})
			DelayAction(function()
				for i, Hero in pairs(getAllyHeroes()) do
					Menu.Combo.Rhealtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 30, min = 0, max = 100})

	Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
		Menu.AutoW:MenuElement({id = "W", name = "[W]Auto heal", toggle = true, value = true})
		Menu.AutoW:MenuElement({id = "WHP", name = "When ally or self <= X hp%", value = 50, min = 0, max = 100, step = 5})
		Menu.AutoW:MenuElement({type = MENU,id = "Wtarget", name = "Use On"})
			DelayAction(function()
				for i, Hero in pairs(getAllyHeroes()) do
					Menu.AutoW.Wtarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
		Menu.AutoE:MenuElement({id = "E", name = "[E]Auto shield", toggle = true, value = true})
		Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
			DelayAction(function()
				for i, Hero in pairs(getAllyHeroes()) do
					Menu.AutoE.Etarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
		Menu.AutoR:MenuElement({id = "R", name = "[R]Auto clears ally CC", toggle = true, value = true})
			Menu.AutoR:MenuElement({type = MENU, id = "CC", name = "CC Types"})			
			Menu.AutoR.CC:MenuElement({ id = "Stun", name = "Use on Stun", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Taunt", name = "Use on Taunt", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Berserk", name = "Use on Berserk", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Snare", name = "Use on Snare", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Fear", name = "Use on Fear", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Charm", name = "Use on Charm", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Suppression", name = "Use on Suppression", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Disarm", name = "Use on Disarm", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Asleep", name = "Use on Asleep", value = true})
		Menu.AutoR:MenuElement({type = MENU,id = "Rclearstarget", name = "Clears target"})
			DelayAction(function()
				for i, Hero in pairs(getAllyHeroes()) do
					Menu.AutoR.Rclearstarget:MenuElement({id = Hero.charName, name = Hero.charName, value = true})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "AutoQ", name = "AutoQ"})
		Menu.AutoQ:MenuElement({id = "AntiDash", name = "AutoQ Anti-Dash",toggle = true, value = true})
		Menu.AutoQ:MenuElement({type = MENU,id = "AntiTarget", name = "Use On"})
			DelayAction(function()
				for i, Hero in pairs(getEnemyHeroes()) do
					Menu.AutoQ.AntiTarget:MenuElement({id = Hero.charName, name = Hero.charName, value = false})		
				end		
			end,0.2)

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

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
	if Menu.AutoW.W:Value() then
		self:AutoW()
	end
	if Menu.AutoE.E:Value() then
		self:AutoE()
	end
	if Menu.AutoR.R:Value() then
		self:AutoR()
	end
	if Menu.AutoQ.AntiDash:Value() then
		self:AutoQAntiDash()
	end	
end

function Milio:Combo()

	local target = TargetSelector:GetTarget(1500)
	if isValid(target) and target.pos2D.onScreen then

		if Menu.Combo.Q:Value() then
			self:CastQ(target)
		end
	end

	if Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() then
	local heroes = ObjectManager:GetAllyHeroes(self.rSpell.Range)
		for i, hero in ipairs(heroes) do
			if Menu.Combo.Rhealtarget[hero.charName] and Menu.Combo.Rhealtarget[hero.charName]:Value() then 
				if hero.health/hero.maxHealth <= Menu.Combo.RHP:Value()/100 and getEnemyCount(1200, hero.pos) > 0 then
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
			
		if Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 then
			self:CastQ(target)
		end
	end
end

function Milio:CastQ(target)
	if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, self.qSpell.CollisionTypes, target.networkID)
		if collisionCount >= 1 and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QBD:Value() + 1200 then
			local minion = collisionObjects[1]
			if isValid(minion) and minion.pos:DistanceTo(target.pos) < Menu.Combo.QBD:Value() and minion.pos:DistanceTo(myHero.pos) < 1100 then
				if myHero.pos:DistanceTo(target.pos) < 1100 then
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
		elseif collisionCount <= 1 and myHero.pos:DistanceTo(target.pos) < 1100 then
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
			if Menu.AutoW.Wtarget[hero.charName] and Menu.AutoW.Wtarget[hero.charName]:Value() then
				if hero.health/hero.maxHealth <= Menu.AutoW.WHP:Value()/100 and getEnemyCount(1200, hero.pos) > 0 then
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
					if Menu.AutoE.Etarget[ally.charName] and Menu.AutoE.Etarget[ally.charName]:Value() then
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
			if Menu.AutoR.Rclearstarget[hero.charName] and Menu.AutoR.Rclearstarget[hero.charName]:Value() and self:RCleans(hero) then
				Control.CastSpell(HK_R)
				lastR = GetTickCount()
			end
		end
	end
end

function Milio:RCleans(unit)
	local CleanBuffs = {
		[5] = Menu.AutoR.CC.Stun:Value(),
		[8] = Menu.AutoR.CC.Taunt:Value(),
		[9] = Menu.AutoR.CC.Berserk:Value(),
		[12] = Menu.AutoR.CC.Snare:Value(),
		[22] = Menu.AutoR.CC.Fear:Value(),
		[23] = Menu.AutoR.CC.Charm:Value(),
		[25] = Menu.AutoR.CC.Suppression:Value(),
		[32] = Menu.AutoR.CC.Disarm:Value(),
		[35] = Menu.AutoR.CC.Asleep:Value()
	}	
	
	for i = 0, unit.buffCount do
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
		if isValid(enemy) and Menu.AutoQ.AntiTarget[enemy.charName] and Menu.AutoQ.AntiTarget[enemy.charName]:Value()then
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
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, 1000, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 0, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

----------------------------------------

class "AurelionSol"
		
function AurelionSol:__init()		 
	print("Simple AurelionSol Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 75, Range = 750, Speed = 1500, Collision = false}
	self.wSpell = { Range = 1500 } 
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 750, Speed = 1300, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 275, Range = 1250, Speed = 500, Collision = false}
end

function AurelionSol:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR when hit X enemies", value = 3, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W2", name = "[W] Range in minimap", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function AurelionSol:onTick()

	passivecount = getBuffData(myHero, "AurelionSolPassive").stacks
	self.qSpell.Range = 740 + 10 * myHero.levelData.lvl
	self.eSpell.Range = 740 + 10 * myHero.levelData.lvl
	self.wSpell.Range = 1400 + 100 * myHero:GetSpellData(_W).level + 7.5 * passivecount
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

	if Menu.Combo.Rsm:Value() then
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
		if Menu.Combo.DisableAA:Value() then
			args.Process = false
		end
	end
end

function AurelionSol:Combo()
	if isValid(Rtarget) then
		if Menu.Combo.R:Value() and myHero.activeSpell.isCharging == false then 
			self:CastRAoE(Rtarget)
		end
	end
	if isValid(Etarget) then
		if Menu.Combo.Q:Value() and not isSpellReady(_E) then
			self:CastQ(Etarget)
		end
		if Menu.Combo.E:Value() and myHero.activeSpell.isCharging == false then
			self:CastEAoE(Etarget)
		end
	end
end

function AurelionSol:Harass()
	if isValid(Etarget) then
		if Menu.Harass.E:Value() then
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
		local Rcount = Menu.Combo.Rcount:Value()
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
		Control.SetCursorPos(target.pos)
		DelayAction(function()
			Control.KeyUp(HK_Q)
		end, 9999)
	end
end

function AurelionSol:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.W2:Value() and isSpellReady(_W) then
		Draw.CircleMinimap(myHero.pos, self.wSpell.Range, 1, Draw.Color(200, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

------------------------------------

class "Heimerdinger"
		
function Heimerdinger:__init()		 
	print("Simple Heimerdinger Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)	
	Q = {Delay = 0.25, Range = 350}
	W = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 1200, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}} 
	E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 970, Speed = 1200, Collision = false}
	E2 = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1500, Speed = 1200, Collision = false}
end

function Heimerdinger:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "QRange1", name = "QTurret distance self", value = 300, min = 100, max = 350, step = 10})
		Menu.Combo:MenuElement({id = "QRange2", name = "Cast[Q] distance target ", value = 700, min = 500, max = 1000, step = 50})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RQ", name = "[RQ]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RQCount", name = "UseRQ when X enemies near", value = 2, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "RW", name = "[RW] UseRW if can kill target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RE", name = "[RE]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RECount", name = "UseRE when X enemies near", value = 3, min = 1, max = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
		Menu.Misc:MenuElement({id = "QAmmo", name = "Save 1 QTurret in Combo", toggle = true, value = false})
		Menu.Misc:MenuElement({id = "QAHp", name = "When target <=HP% use last QTurret", value = 20, min = 0, max = 100, step = 5})
		Menu.Misc:MenuElement({id = "Flee", name = "Flee [RE] or [E]", toggle = true, value = false})
		Menu.Misc:MenuElement({id = "RW", name = "Semi-Manual [RW] Key", key = string.byte("Z")})
		Menu.Misc:MenuElement({id = "RE", name = "Semi-Manual [RE] Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E2", name = "[E2] Range", toggle = true, value = false})
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
	if Menu.Misc.RW:Value() then
		self:SemiManualRW()
	end
	if Menu.Misc.RE:Value() then
		self:SemiManualRE()
	end
end

function Heimerdinger:Combo()
	if Attack:IsActive() then return end
	local target = TargetSelector:GetTarget(1500)
	if isValid(target) then
		if Menu.Combo.RQ:Value() and isSpellReady(_Q) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and getEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= Menu.Combo.RQCount:Value() then
			self:CastR()
			self:CastQ(target)
		elseif Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and getEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= 1 then
			if not Menu.Misc.QAmmo:Value() then
				self:CastQ(target)
			else
				if target.health/target.maxHealth >= Menu.Misc.QAHp:Value()/100 then
					if myHero:GetSpellData(_Q).ammo > 1 then
						self:CastQ(target)
					end
				else
					self:CastQ(target)
				end
			end
		end

		if Menu.Combo.RE:Value() and isSpellReady(_E) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < E2.Range and getEnemyCount(275, target.pos) >= Menu.Combo.RECount:Value() then
			self:CastR()
			self:CastE2(target)
		elseif Menu.Combo.E:Value() and isSpellReady(_E) then
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

		if Menu.Combo.RW:Value() and isSpellReady(_W) and isSpellReady(_R) and myHero.pos:DistanceTo(target.pos) < W.Range and self:getRWDmg(target) >= target.health then
			self:CastR()
			self:CastW(target)
		elseif Menu.Combo.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < W.Range then
			self:CastW(target)
		end
	end
end

function Heimerdinger:Harass()
	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1500)
	if isValid(target) then
		if Menu.Harass.E:Value() and isSpellReady(_E) and myHero.pos:DistanceTo(target.pos) < E.Range then
			self:CastE(target)
		end
		if Menu.Harass.W:Value() and isSpellReady(_W) and myHero.pos:DistanceTo(target.pos) < W.Range then
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
	if isValid(target) and Menu.Misc.Flee:Value() then
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
	local Castpos = myHero.pos:Extended(target.pos, Menu.Combo.QRange1:Value())
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
	local baseDmg = 194.5 * rlvl + 308.5
	local apDmg = myHero.ap * 1.83
	local rwDmg = baseDmg + apDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rwDmg)
end

function Heimerdinger:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
		Draw.Circle(myHero.pos, W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.E2:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, E2.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

-----------------------------------

class "Briar"
		
function Briar:__init()		 
	print("Simple Briar Loaded")
	self:LoadMenu()
	Callback.Add("Tick", function() self:onTick() end)	
	Q = {Range = 450}
	W = {Range = 1000}
	E = {Range = 600}
	R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 160, Range = 10000, Speed = 2000, Collision = false} 
end

function Briar:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "W2", name = "[W2] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W2Kill", name = "Auto [W2] can kills", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "EWall", name = "[E] to wall when target isImmobile", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})


	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
		Menu.Clear:MenuElement({id = "W2", name = "[W2]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
		Menu.Clear:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
end

function Briar:onTick()
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
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
	if Menu.Combo.W2Kill:Value() then
		self:AutoW2()
	end
end

function Briar:Combo()

	if Attack:IsActive() then return end

	local target = TargetSelector:GetTarget(1000)
	if isValid(target) then

		if Menu.Combo.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= Q.Range and getDistance(myHero.pos, target.pos) > Data:GetAutoAttackRange(myHero) then
			Control.CastSpell(HK_Q, target)
		end

		if Menu.Combo.W:Value() and not haveBuff(myHero, "BriarRSelf") and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and getDistance(myHero.pos, target.pos) < W.Range then
			Control.CastSpell(HK_W, target)
		end 

		if Menu.Combo.W2:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and getDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
			Control.CastSpell(HK_W)
		end

		if Menu.Combo.EWall:Value() and isSpellReady(_E) then
			local Pos = myHero.pos:Extended(target.pos, E.Range)
			local Pos2 = MapPosition:getIntersectionPoint3D(myHero.pos, Pos)
			if Pos2 and isImmobile(target) and getDistance(myHero.pos, target.pos) < E.Range then
				self:CastE(target)
			end
		end

		if Menu.Combo.E:Value() and isSpellReady(_E) and getDistance(myHero.pos, target.pos) < E.Range and myHero.health/myHero.maxHealth <= Menu.Combo.EHP:Value()/100 then
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
	Control.SetCursorPos(target.pos)
	Control.KeyDown(HK_E)
	DelayAction(function() Control.SetCursorPos(mousePos) end, 0.1)
	DelayAction(function() Control.KeyUp(HK_E) end, 1)
end


function Briar:JungleClear()
	if Attack:IsActive() then return end
	local target = HealthPrediction:GetJungleTarget()
	if isValid(target) then

		if Menu.Clear.Q:Value() and isSpellReady(_Q) and getDistance(myHero.pos, target.pos) <= Q.Range then
			Control.CastSpell(HK_Q, target)
		end

		if Menu.Clear.W:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and getDistance(myHero.pos, target.pos) < W.Range then
			Control.CastSpell(HK_W, target)
		end 

		if Menu.Clear.W2:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and getDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
			Control.CastSpell(HK_W)
		end

		if Menu.Clear.E:Value() and isSpellReady(_E) and getDistance(myHero.pos, target.pos) < E.Range and myHero.health/myHero.maxHealth <= Menu.Clear.EHP:Value()/100 then
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
	local baseDmg = 15 * Wlvl - 10
	local adDmg = myHero.totalDamage * 0.05
	local bonusDmg = (0.09 + 0.025 * math.floor(myHero.bonusDamage/100))* (target.maxHealth - target.health)
	local Dmg = baseDmg + adDmg + bonusDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, Dmg)
end

------------------------------------

class "Urgot"
		
function Urgot:__init()		 
	print("Simple Urgot Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	Orbwalker:OnPostAttackTick(function(...) self:OnPostAttackTick(...) end)
	Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.55, Radius = 210, Range = 800, Speed = math.huge, Collision = false}
	W = { Range = 500 } 
	E = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 100, Range = 450, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO}}
	R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 80, Range = 2500, Speed = 3200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO}}
end

function Urgot:LoadMenu()
			
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "AWA", name = "Use [AWA] When W 5 levels", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rkill", name = "UseR if can kill target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rsm", name = "UseR Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Urgot:onTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end
	
	if myHero:GetSpellData(_W).name == "UrgotWCancel" then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	
	if Menu.Combo.Rsm:Value() then
		self:SemiManualR()
	end
	self:AutoR2()

	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:AWA()
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Urgot:OnPostAttackTick()
	local target = Orbwalker:GetTarget()
	if isValid(target) and target.type == Obj_AI_Hero then
		if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			if Menu.Combo.W:Value() and isSpellReady(_W) and myHero:GetSpellData(_W).name == "UrgotW" then
				Control.CastSpell(HK_W)
			end
		end
	end
end

function Urgot:AWA()
	local target = Orbwalker:GetTarget()
	if isValid(target) and target.type == Obj_AI_Hero then
		if Menu.Combo.AWA:Value() and isSpellReady(_W) then
			if myHero:GetSpellData(_W).level == 5 and myHero:GetSpellData(_W).name == "UrgotWCancel" and myHero.attackData.state == 1 then
				Control.CastSpell(HK_W)
			end
		end
	end
end

function Urgot:Combo()
	if Menu.Combo.Q:Value() and isSpellReady(_Q) then
		local target = TargetSelector:GetTarget(Q.Range)
		if isValid(target) then
			self:CastQ(target)
		end
	end
	
	if Menu.Combo.E:Value() and isSpellReady(_E) then
		local target = TargetSelector:GetTarget(E.Range)
		if isValid(target) then
			self:CastE(target)
		end
	end

	if Menu.Combo.R:Value() and isSpellReady(_R) then
		if Menu.Combo.Rkill:Value() then
			local target = TargetSelector:GetTarget(R.Range)
			if isValid(target) and (target.health - self:getRDmg(target))/target.maxHealth < 0.25 then
				self:CastR(target)
			end
		end
	end
end

function Urgot:Harass()
	local target = TargetSelector:GetTarget(Q.Range)
	if isValid(target) then
		if Menu.Harass.Q:Value() and isSpellReady(_Q) then
			self:CastQ(target)
		end
	end
end

function Urgot:SemiManualR()
	local target = TargetSelector:GetTarget(R.Range)
	if isValid(target) then
		if isSpellReady(_R) and myHero:GetSpellData(_R).name == "UrgotR" then
			self:CastR(target)
		end
	end
end

function Urgot:AutoR2()
	local enemies = ObjectManager:GetEnemyHeroes(R.Range)
	for i, target in ipairs(enemies) do
		if isValid(target) and haveBuff(target, "urgotrslow") and target.health/target.maxHealth < 0.25 then
			if isSpellReady(_R) and myHero:GetSpellData(_R).name == "UrgotRRecast" then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function Urgot:CastQ(target)
	if lastQ + 350 < GetTickCount() and Orbwalker:CanMove() then
		local pred = GGPrediction:SpellPrediction(Q)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_Q, pred.CastPosition)	
			lastQ = GetTickCount()
		end
	end
end

function Urgot:CastE(target)
	if lastE + 550 < GetTickCount() and Orbwalker:CanMove() then
		local pred = GGPrediction:SpellPrediction(E)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_E, pred.CastPosition)	
			lastE = GetTickCount()
		end
	end
end

function Urgot:CastR(target)
	if lastR + 600 < GetTickCount() and Orbwalker:CanMove() then
		local pred = GGPrediction:SpellPrediction(R)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_R, pred.CastPosition)	
			lastR = GetTickCount()
		end
	end
end

function Urgot:getRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 125 * rlvl - 25
	local adDmg = myHero.bonusDamage * 0.5
	local rDmg = baseDmg + adDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg)
end

function Urgot:Draw()
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and isSpellReady(_W) then
		Draw.Circle(myHero.pos, W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and isSpellReady(_R) then
		Draw.Circle(myHero.pos, R.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

-----------------------------------

class "Aurora"

function Aurora:__init()
	print("Simple Aurora Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 900, Speed = 1600, Collision = false}
	ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 80, Range = 825, Speed = MathHuge, Collision = false}
end

function Aurora:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Q Max Range", value = 850, min = 550, max = 900, step = 10})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "E Max Range", value = 775, min = 550, max = 825, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoQ2", name = "Auto Q2", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "EGap", name = "Use E AntiGapcloser", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function Aurora:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if Menu.Combo.DisableAA:Value() and (isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" or isSpellReady(_E)) then
			args.Process = false
		end
	end
end

function Aurora:OnTick()
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
		return
	end
	self:AntiGapcloser()
	self:AutoQ2()
	if myHero.activeSpell.valid then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	elseif Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Aurora:GetQ2Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local missingHpPer = (target.maxHealth - target.health) / target.maxHealth
	local Dmg = (({40, 65, 90, 115, 140})[level] + 0.4 * myHero.ap) * (1 + missingHpPer * 0.5)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
end

function Aurora:GetPDmg(target)
	if getBuffData(target, "AuroraPDebuff").count == 2 then
		local Dmg = (0.025 + myHero.ap / 100 * 0.02) * target.maxHealth
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
	else
		return 0
	end
end

function Aurora:AutoQ2()
	if myHero:GetSpellData(_Q).name == "AuroraQRecast" then
		if Menu.Misc.AutoQ2:Value() and Game.CanUseSpell(_Q) == 0 then
			for i, enemy in ipairs(getEnemyHeroes()) do
				if isValid(enemy) and haveBuff(enemy, "auroraqdebufftracker") then
					local Q2Dmg = self:GetQ2Dmg(enemy) + self:GetPDmg(enemy)
					if (enemy.health + enemy.shieldAD + enemy.shieldAP) <= Q2Dmg or GetBuffData(myHero, "AuroraQRecast").duration < 1 then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end

function Aurora:AntiGapcloser()
	if Menu.Misc.EGap:Value() and isSpellReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(Menu.Combo.Erange:Value())
		for i, target in ipairs(enemies) do
			if isValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					self:CastE(target)
				end
			end
		end
	end
end

function Aurora:Combo()
	if Menu.Combo.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = TargetSelector:GetTarget(Menu.Combo.Qrange:Value())
		if isValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and isSpellReady(_E) then
		local target = TargetSelector:GetTarget(Menu.Combo.Erange:Value())
		if isValid(target) then 
			self:CastE(target)
		end
	end
end

function Aurora:Harass()
	if Menu.Harass.Q:Value() and isSpellReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = TargetSelector:GetTarget(Menu.Combo.Qrange:Value())
		if isValid(target) then
			self:CastQ(target)
		end
	end
end

function Aurora:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end

function Aurora:CastE(unit)
	local EPrediction = GGPrediction:SpellPrediction(ESpell)
	EPrediction:GetPrediction(unit, myHero)
	if EPrediction:CanHit(3) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function Aurora:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and isSpellReady(_Q) then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and isSpellReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end