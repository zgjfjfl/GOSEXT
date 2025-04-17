local Version = 2025.15
--[[ AutoUpdate ]]
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

	DownloadFileAsync(Files.Version.Url, Files.Version.Path .. Files.Version.Name, function()
		local file = io.open(Files.Version.Path .. Files.Version.Name, "r")
		if not file then
			return
		end
		local NewVersion = tonumber(file:read("*a"))
		file:close()
		if NewVersion and NewVersion > Version then
			print("SimpleAio: Found update! Downloading...")
			DownloadFileAsync(Files.Lua.Url, Files.Lua.Path .. Files.Lua.Name, function()
				print("SimpleAio: Successfully updated. Press 2x F6!")
			end)
		end
	end)
end

local Heroes = {"Ornn", "JarvanIV", "Poppy", "Shyvana", "Trundle", "Rakan", "Belveth", "Nasus", "Singed", "Udyr", "Galio", "Yorick", "Ivern", 
				"Bard", "Taliyah", "Lissandra", "Sejuani", "KSante", "Skarner", "Maokai", "Gragas", "Milio", "AurelionSol", "Heimerdinger", 
				"Briar", "Urgot", "Aurora", "Ambessa", "Mel"}

if not table.contains(Heroes, myHero.charName) then
	print('SimpleAio not supported ' .. myHero.charName)
	return 
end

require "GGPrediction"

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

local Orbwalker, TargetSelector, ObjectManager, HealthPrediction, ItemManager, Attack, Damage, Spell, Data, Cursor

Callback.Add("Load", function()

	Orbwalker = _G.SDK.Orbwalker
	TargetSelector = _G.SDK.TargetSelector
	ObjectManager = _G.SDK.ObjectManager
	HealthPrediction = _G.SDK.HealthPrediction
	ItemManager = _G.SDK.ItemManager
	Attack = _G.SDK.Attack
	Damage = _G.SDK.Damage
	Spell = _G.SDK.Spell
	Data = _G.SDK.Data
	Cursor = _G.SDK.Cursor

	if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
	end
end)

local function IsReady(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 
		and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 and Cursor.Step == 0
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

local function GetEnemyHeroesWithinDistanceOfUnit(location, distance)
	local EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local Hero = GameHero(i)
		if Hero.isEnemy and not Hero.dead and Hero.pos:DistanceTo(location) < distance then
			TableInsert(EnemyHeroes, Hero)
		end
	end
	return EnemyHeroes
end

local function GetEnemyHeroesWithinDistance(distance)
	return GetEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
end

local function getEnemyCount(range, unit)
	local count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
		local Range = range * range
		if GetDistanceSqr(unit, hero.pos) < Range and IsValid(hero) then
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
		if hero.team ~= myHero.team and hero.dead == false and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function getAllyCount(range, unit)
	local count = 0
	for i, hero in ipairs(getAllyHeroes()) do
		local Range = range * range
		if GetDistanceSqr(unit, hero.pos) < Range and IsValid(hero) then
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

local function Recalling(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == "recall" and buff.duration > 0 then
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
	if math.abs(Angle) < 80 then 
		return true
	end
	return false
end

local function AmIFacing(unit)
	local V = Vector((myHero.pos - unit.pos))
	local D = Vector(myHero.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 80 then
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

local function GetEnemiesAtPos(checkrange, range, pos, target)
	local enemies = ObjectManager:GetEnemyHeroes(checkrange)
	local results = {}
	for i = 1, #enemies do 
		local enemy = enemies[i]
		local Range = range * range
		if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) and enemy ~= target then
			table.insert(results, enemy)
		end
	end
	table.insert(results, target)
	return results
end

local function IsCasting()
	if myHero.activeSpell.valid then
		if myHero.activeSpell.isCharging or
			(Game.Timer() >= myHero.activeSpell.startTime and Game.Timer() <= myHero.activeSpell.castEndTime)
		then
			return true
		end
	end
	return false
end

local function FindFirstWallCollision(startPos, endPos)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local step = 10
	for i = 0, distance, step do
		local checkPos = startPos + direction * i
		if GameIsWall(checkPos) then
			return checkPos
		end
	end
	return nil
end

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7 }

local function HasItem(unit, itemId)
    for i = 1, #ItemSlots do
        local slot = ItemSlots[i]
        local item = unit:GetItemData(slot)
        if item and item.itemID == itemId then
            return true
        end
    end
    return false
end

local function ShouldWait() 
	return myHero.dead or Game.IsChatOpen() or 
			(_G.JustEvade and _G.JustEvade:Evading()) or 
			(_G.ExtLibEvade and _G.ExtLibEvade.Evading) or 
			Recalling(myHero) or 
			Control.IsKeyDown(0x11) or 
			Control.IsKeyDown(0x12)
end

------------------------------------

Menu = MenuElement({type = MENU, id = "zg"..myHero.charName, name = "Simple "..myHero.charName, leftIcon = "http://ddragon.leagueoflegends.com/cdn/15.2.1/img/champion/"..myHero.charName..".png"})
	Menu:MenuElement({name = " ", drop = {"AIO-Version: " .. Version}})

------------------------------------

class "Ornn"

function Ornn:__init()		 
	print("Simple Ornn Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:onTick() end)
	Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 65, Range = 800, Speed = 1800, Collision = false}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 750, Speed = 1600, Collision = false}
	self.r1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 170, Range = 2500, Speed = 1200, Collision = false}
	self.qPos = {}
	self.qTimer = 0
	self.qPosToRemove = nil
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
	if ShouldWait() then
		return
	end
	if self.qTimer and Game.Timer() > self.qTimer then
		self:GetQPos()
		self.qTimer = 0
	end
	self:UpdateQPos()
	if IsCasting() then return end
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

function Ornn:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if Menu.Combo.DisableAA:Value() and (IsReady(_Q) or IsReady(_W)) then
			args.Process = false
		end
	end
end

function Ornn:OnWndMsg(msg, wParam)
	if Game.CanUseSpell(_Q) == 0 and msg == KEY_DOWN and wParam == HK_Q then
		self.qTimer = Game.Timer() + 1.25
	end
end

function Ornn:GetQPos()
	for i = GameParticleCount(), 1, -1 do
		local particle = GameParticle(i)
		local Name = particle.name
		if particle and Name:find("Ornn") and Name:find("Q_Indicator") then
			TableInsert(self.qPos, {pos = particle.pos, Timer = Game.Timer()})
			break
		end
	end
end

function Ornn:UpdateQPos()
	for i = #self.qPos, 1, -1 do
		local qPos = self.qPos[i]
		if Game.Timer() - qPos.Timer > 4.5 then
			TableRemove(self.qPos, i)
		end
		-- if qPos then
			-- Draw.Circle(qPos.pos)
		-- end
	end
end

function Ornn:Combo()
	if Menu.Combo.R2:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "OrnnRCharge" then
		local Rtarget = TargetSelector:GetTarget(2500)
		if Rtarget and IsValid(Rtarget) and Rtarget.pos2D.onScreen then
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
	if Menu.Combo.R:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "OrnnR" then
		local enemies = ObjectManager:GetEnemyHeroes(self.r1Spell.Range)
		for i, enemy in ipairs(enemies) do
			if getEnemyCount(170, enemy.pos) >= Menu.Combo.Rcount:Value() then
				castSpellHigh(self.r1Spell, HK_R, enemy)
			end
		end
	end
	if myHero:GetSpellData(_R).name == "OrnnRCharge" then return end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local extPos = target.pos:Extended(myHero.pos, -Menu.Combo.ED:Value())
			if FindFirstWallCollision(target.pos, extPos) == nil or not IsReady(_E) then
				castSpellHigh(self.qSpell, HK_Q, target)
			end
		end
	end
	if Menu.Combo.EQ:Value() and IsReady(_E) then
		local castPos = nil
		for i, qPos in ipairs(self.qPos) do
			if qPos then
				local checkWall = FindFirstWallCollision(myHero.pos, qPos.pos)
				if checkWall == nil and getEnemyCount(Menu.Combo.ED:Value(), qPos.pos) >= 1 and myHero.pos:DistanceTo(qPos.pos) <= self.eSpell.Range then
					castPos = qPos.pos
					break
				end
			end
		end
		if castPos then
			Control.CastSpell(HK_E, castPos)
			self.qPos = {}
		end
	end
	if Menu.Combo.EWall:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local extPos = target.pos:Extended(myHero.pos, -Menu.Combo.ED:Value())
			local wallPos1 = FindFirstWallCollision(myHero.pos, target.pos)
			local wallPos2 = FindFirstWallCollision(target.pos, extPos)
			if wallPos1 == nil then
				if wallPos2 ~= nil and myHero.pos:DistanceTo(wallPos2) < self.eSpell.Range then
					Control.CastSpell(HK_E, wallPos2)
				end
			else
				if target.pos:DistanceTo(wallPos1) < Menu.Combo.ED:Value() and myHero.pos:DistanceTo(wallPos1) < self.eSpell.Range then
					Control.CastSpell(HK_E, wallPos1)
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
end

function Ornn:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.Clear.W:Value() and IsReady(_W) then
			bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
			if bestCount > 0 then 
				Control.CastSpell(HK_W, bestPosition)
			end
		end
	end
end

function Ornn:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then	
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
end

function Ornn:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
		if IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
			args.Process = false
		end
	end
end

function JarvanIV:onTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if haveBuff(myHero, "JarvanIVCataclysm") and getEnemyCount(self.rSpell.Radius, myHero.pos) == 0 then
		Control.CastSpell(HK_R)
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

function JarvanIV:Combo()
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.eSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local offset = IsFacing(target) and -100 or -200
			local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), offset)
			if Menu.Combo.EQ:Value() and IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
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
		if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) and myHero:GetSpellData(_E).currentCd > 2 and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
			if ((myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero.health/myHero.maxHealth <= Menu.Combo.WHp:Value()/100) or getEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value()) then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
		if Menu.Combo.R:Value() and IsReady(_R) and not haveBuff(myHero, "JarvanIVCataclysm") then
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
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) then
			bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
			if bestCount > 0 then
				Control.CastSpell(HK_Q, bestPosition)
			end
		end
	end

end

function JarvanIV:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function JarvanIV:KillSteal()
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
			end
		end
		if IsReady(_E) and Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
			end
		end
		if IsReady(_R) and Menu.KS.R:Value() and not haveBuff(myHero, "JarvanIVCataclysm") then
			if self:getrDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
				Control.CastSpell(HK_R, target)
			end
		end
	end
end

function JarvanIV:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 40 * qlvl + 50
	local qadDmg = myHero.bonusDamage * 1.45
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
	if Menu.Flee.EQ:Value() and IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
		local pos = myHero.pos:DistanceTo(Vector(mousePos)) > self.eSpell.Range and myHero.pos + (mousePos - myHero.pos)
					or myHero.pos + (mousePos - myHero.pos):Normalized() * (self.eSpell.Range + 100)
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
	if IsValid(target) then
		if IsReady(_W) and not IsReady(_Q) and lastW + 250 < GetTickCount() and Menu.Flee.W:Value() then
			if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
	end
end

function JarvanIV:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
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
	self.rCastTimer = 0
end


function Poppy:LoadMenu()	
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 50, max = 400, value = 400, step = 50})
		Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP % < X", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Antidash", name = "W Setting "})
		Menu.Antidash:MenuElement({id = "W", name = "[W] Anti-Dash", toggle = true, value = true})
		Menu.Antidash:MenuElement({type = MENU, id = "Wtarget", name = "Use On"})
			ObjectManager:OnEnemyHeroLoad(function(args)
				Menu.Antidash.Wtarget:MenuElement({id = args.charName, name = args.charName, value = false})				
			end)
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Poppy:onTick()
	if ShouldWait() then
		return
	end
	if haveBuff(myHero, "PoppyR") then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if Menu.Antidash.W:Value() then
		self:AutoW()
	end
	if Control.IsKeyDown(HK_R) then
		DelayAction(function()
			if myHero.activeSpell.isCharging == false then
				Control.KeyUp(HK_R)
			end
		end, 0.45)
	end
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
	self:R2()
	if IsCasting() then return end
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

function Poppy:Combo()
	local target = TargetSelector:GetTarget(500)
	if IsValid(target) then
		for dis = 20, Menu.Combo.ED:Value(), 20 do
			local endPos = target.pos:Extended(myHero.pos, -dis)
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				if GameIsWall(endPos) then
					Control.CastSpell(HK_E, target)
				end
			end
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if Menu.Combo.RF:Value() and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth < Menu.Combo.RFHP:Value()/100 then
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
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) then
			bestPosition, bestCount = getAOEMinion(self.qSpell.Range, self.qSpell.Radius)
			if bestCount > 0 then
				Control.CastSpell(HK_Q, bestPosition)
			end
		end
	end
end

function Poppy:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Poppy:AutoW()
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) then
			local blockobj = Menu.Antidash.Wtarget[enemy.charName] and Menu.Antidash.Wtarget[enemy.charName]:Value()
			if blockobj and enemy.pathing.isDashing then
				local vct = Vector(enemy.pathing.endPos.x, enemy.pathing.endPos.y, enemy.pathing.endPos.z)
				if vct:DistanceTo(myHero.pos) < 400 then
					if IsReady(_W) and lastW + 250 < GetTickCount() then
						Control.CastSpell(HK_W)
						lastW = GetTickCount()
					end
				end
			end
		end
	end
end

function Poppy:RSemiManual()
	if IsReady(_R) and getEnemyCount(self.r2Spell.Range, myHero.pos) > 0 and lastR + 450 < GetTickCount() then
		if not (myHero.activeSpell.isCharging and Control.IsKeyDown(HK_R)) then
			Control.KeyDown(HK_R)
			self.rCastTimer = GetTickCount()
			lastR = GetTickCount()
		end
	end
end

function Poppy:R2()
	if GetTickCount() > self.rCastTimer + 450 and myHero.activeSpell.isCharging then
		local buff = getBuffData(myHero, "PoppyR")
		if buff and buff.duration < 2.9 then
			local target = TargetSelector:GetTarget(self.r2Spell.Range)
			if IsValid(target) then
				castSpellHigh(self.r2Spell, HK_R, target)
			end
		end
	end
end

function Poppy:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	if Menu.Combo.E:Value() and IsReady(_E) then
		local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
		if DragonForm then
			local target = TargetSelector:GetTarget(self.e2Spell.Range)
			if IsValid(target) then
				castSpellHigh(self.e2Spell, HK_E, target)
			end
		else
			local target = TargetSelector:GetTarget(self.eSpell.Range)
			if IsValid(target) then
				castSpellHigh(self.eSpell, HK_E, target)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount()then
		local target = TargetSelector:GetTarget(400)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R)  then
		local target = TargetSelector:GetTarget(self.rSpell.Range)
		if IsValid(target) and (target.health/target.maxHealth <= Menu.Combo.RHP:Value() / 100) then
			local numEnemies = GetEnemyHeroesWithinDistance(self.rSpell.Range)
			if #numEnemies >= Menu.Combo.RC:Value() then
				castSpellHigh(self.rSpell, HK_R, target)
			end
		end
	end
end

function Shyvana:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < 400 and Menu.Clear.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.E:Value() and IsReady(_E) then
			bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
			if bestCount > 0 then
				Control.CastSpell(HK_E, bestPosition)
			end
		end
	end
end

function Shyvana:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local DragonForm = doesMyChampionHaveBuff("ShyvanaTransform")
		if DragonForm then
			local target = TargetSelector:GetTarget(self.e2Spell.Range)
			if IsValid(target) then
				castSpellHigh(self.e2Spell, HK_E, target)
			end
		else
			local target = TargetSelector:GetTarget(self.eSpell.Range)
			if IsValid(target) then
				castSpellHigh(self.eSpell, HK_E, target)
			end
		end
	end
end

function Shyvana:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
	end
	if Menu.Flee.R:Value() and IsReady(_R) then
		Control.CastSpell(HK_R, mousePos)
	end
end

function Shyvana:Draw()
	if Menu.Draw.E:Value() and IsReady(_E)then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R)then
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
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value = 60, min = 0, max = 100, step = 5})	
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) > 350 then
			local offset = IsFacing(target) and 100 or 200
			local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) + offset)
			if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
				Control.CastSpell(HK_E, castPos)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = TargetSelector:GetTarget(self.rSpell.Range)
		if IsValid(target) and (myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value() / 100) then
			Control.CastSpell(HK_R, target)
		end
	end
end

function Trundle:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Clear.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount()then
			Control.CastSpell(HK_W, myHero)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount()then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function Trundle:Harass()
	local target = TargetSelector:GetTarget(350)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function Trundle:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W, mousePos)
		lastW = GetTickCount()
	end
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if Menu.Flee.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) - 100)
			Control.CastSpell(HK_E, castPos)
		end
	end
end

function Trundle:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 725, Speed = 1700, Collision = false}
end

function Rakan:LoadMenu()	
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] to ally close enemy ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] when enemies within Wrange", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "[R] X enemies within Wrange", value = 2, min = 1, max = 5, step = 1})	
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoE"})	
		Menu.Auto:MenuElement({id = "E", name = "[E] auto ally shield", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W] to mouse", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "E", name = "[E] to ally(mouse near)", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function Rakan:onTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AutoE()
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

function Rakan:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if IsReady(_Q) or IsReady(_W) then
			args.Process = false
		end
	end
end

function Rakan:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local allies = ObjectManager:GetAllyHeroes(1000)
		for i, ally in ipairs(allies) do
			if not ally.isMe then
				if ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000 or myHero.pos:DistanceTo(ally.pos) <= 700 then
					if IsReady(_W) and getEnemyCount(self.wSpell.Range, myHero.pos) == 0 and getEnemyCount(self.wSpell.Range, ally.pos) >= 1 then
						Control.CastSpell(HK_E, ally)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and not IsReady(_W) and lastR + 600 < GetTickCount() then
		if getEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.Rcount:Value() then
			Control.CastSpell(HK_R)
			lastR = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_W) then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Rakan:AutoE()
	if Menu.Auto.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local enemies = ObjectManager:GetEnemyHeroes(2500)
		local allies = ObjectManager:GetAllyHeroes(1000)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				for j, ally in ipairs(allies) do
					if IsValid(ally) and not ally.isMe and self:attackedcheck(enemy, ally) and not haveBuff(ally, "RakanEShield") then
						if ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000 or myHero.pos:DistanceTo(ally.pos) <= 700 then
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
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
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
				local endPos = enemy.activeSpell.startPos:Extended(enemy.activeSpell.placementPos, enemy.activeSpell.range)
				local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
				local width = ally.boundingRadius + (enemy.activeSpell.width > 0 and enemy.activeSpell.width or 0)
				if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
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
	if Menu.Flee.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.wSpell.Range
		Control.CastSpell(HK_W, pos)
		lastW = GetTickCount()
	end

	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() and (not Menu.Flee.W:Value() or not IsReady(_W)) then
		local allies = ObjectManager:GetAllyHeroes(1000)
		for i, ally in ipairs(allies) do
			if IsValid(ally) and not ally.isMe then
				local distance = ally.pos:DistanceTo(myHero.pos)
				if mousePos:DistanceTo(ally.pos) < 500 then
					if ally.charName == "Xayah" and distance <= 1000 or distance <= 700 then
						Control.CastSpell(HK_E, hero)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
end

function Rakan:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
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
	if ShouldWait() then
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
	if IsCasting() then return end
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
	local castingE = doesMyChampionHaveBuff("BelvethE")
	if Menu.Combo.W:Value() and IsReady(_W) and not castingE then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not castingE then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) then			
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		if getEnemyCount(self.eSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < Menu.Combo.EHP:Value()/100 then
			Control.CastSpell(HK_E)
			lastE = GetTickCount()
		end
	end
end

function Belveth:Harass()
	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if IsValid(target) then
		if Menu.Harass.W:Value() and IsReady(_W) then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
end

function Belveth:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.Clear.W:Value() and IsReady(_W) then
			bestPosition, bestCount = getAOEMinion(self.wSpell.Range, self.wSpell.Radius)
			if bestCount > 0 then
				Control.CastSpell(HK_W, bestPosition)
			end
		end
		if Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			Control.CastSpell(HK_Q, target)
			lastQ = GetTickCount()
		end
	end
end

function Belveth:Flee()
	if Menu.Flee.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
	end
end

function Belveth:KillSteal()
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if IsReady(_E) and lastE + 250 < GetTickCount() and Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and not doesMyChampionHaveBuff("BelvethE") then
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local numEnemies = GetEnemyHeroesWithinDistance(700)
	if #numEnemies >= 1 and myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value()/100 and Menu.Combo.R:Value() and IsReady(_R) then
		Control.CastSpell(HK_R)
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
		self:LastHit()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
		self:LaneClear()
		self:LastHit()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
		self:LastHit()
	end
	self:KillSteal()
end

function Nasus:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function Nasus:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(300)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
end

function Nasus:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.Clear.E:Value() and IsReady(_E) then
			bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
			if bestCount >= Menu.Clear.EH:Value() then
				Control.CastSpell(HK_E, bestPosition)
			end
		end
		if Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 350 and self:getqDmg(target) >= target.health then
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
	if IsValid(target) then
		if Menu.LastHit.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < 350 and self:getqDmg(target) >= target.health then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
			Control.Attack(target)
		end
	end
end

function Nasus:KillSteal()
	if IsReady(_E) and Menu.KS.E:Value() then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) and self:geteDmg(target) >= target.health then
			Control.CastSpell(HK_E, target)
		end
	end
	if IsReady(_Q) and lastQ + 250 < GetTickCount() and Menu.KS.Q:Value() then
		local target = TargetSelector:GetTarget(350)
		if IsValid(target) and self:getqDmg(target) >= target.health then			
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
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
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 265, Range = 1000, Speed = 700, Collision =false}
	self.poisonTime = 0
end

function Singed:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR when X enemies inWrange ", value = 2, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoQ"})
		Menu.Auto:MenuElement({id = "Q", name = "Auto Q when enemies nearby", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Qrange", name = "turn on Q enemy distance", value = 300, min = 200, max = 600, step = 50})
		Menu.Auto:MenuElement({id = "DontOffQ", name = "Do not turn off Q", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
end

function Singed:onTick()
	if ShouldWait() then
		return
	end
	self:AutoQ()
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
end

function Singed:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if Menu.Combo.DisableAA:Value() then
			args.Process = false
		end
	end
end

function Singed:AutoQ()
	if IsReady(_Q) and lastQ + 250 < GetTickCount() then
		if Menu.Auto.Q:Value() then
			if getEnemyCount(Menu.Auto.Qrange:Value(), myHero.pos) >= 1 then
				if myHero:GetSpellData(_Q).toggleState == 1 then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
				if myHero:GetSpellData(_Q).toggleState == 2 then
					self.poisonTime = GetTickCount() + 1200
				end
			end
		end
		if Menu.Auto.DontOffQ:Value() then return end
		if myHero:GetSpellData(_Q).toggleState == 2 and GetTickCount() - self.poisonTime > 1200 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function Singed:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
		if getEnemyCount(1000, myHero.pos) >= Menu.Combo.Rcount:Value() then
			Control.CastSpell(HK_R)
			lastR = GetTickCount()
		end
	end
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) then
		if Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < 1000 then
			self:CastW(target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= Data:GetAutoAttackRange(myHero, target) then
			Control.CastSpell(HK_E, target)
		end
	end
end

function Singed:CastW(target)
	if IsReady(_W) then
		local pred = GGPrediction:SpellPrediction(self.wSpell)
		pred:GetPrediction(target, myHero)
		if self.wSpell.Range - 80 > myHero.pos:DistanceTo(pred.CastPosition) then
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_W, pred.CastPosition)
			end
		end
	end
end

function Singed:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
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
	Menu.Style:MenuElement({id = "MainR", name = "Main R Playstyle", value = true,
		callback = function(val)
			if val and Menu.Style.MainQ then Menu.Style.MainQ:Value(false) end
		end})
	Menu.Style:MenuElement({id = "MainQ", name = "Main Q Playstyle", value = false,
		callback = function(val)
			if val and Menu.Style.MainR then Menu.Style.MainR:Value(false) end
		end})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Whp", name = "[W] use when self hp% < X ", value = 50, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "W2hp", name = "use AwakenedW when self hp% < X ", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "Whp", name = "[W] use when self X% hp", value = 30, min = 0, max = 100, step = 5})
		Menu.Clear:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
end

function Udyr:onTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
		self:JungleClear()
	end
end

function Udyr:Combo()
	local target = TargetSelector:GetTarget(800)
	if IsValid(target) then
		local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
		local hasAwakenedW = doesMyChampionHaveBuff("udyrwrecastready")
		local hasAwakenedE = doesMyChampionHaveBuff("udyrerecastready")
		local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
		local R1 = getBuffData(myHero, "UdyrRActivation")
		local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() and not hasAwakenedE and not hasAwakenedR then
			Control.CastSpell(HK_E)
			lastE = GetTickCount()
		end
		if Menu.Style.MainR:Value() then
			if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE or hasAwakenedR) and R1.duration < 1.5 and myHero.pos:DistanceTo(target.pos) < 450 then
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end
			end
			if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE) and (not IsReady(_R) or not hasAwakenedR) and not hasAwakenedQ and myHero.pos:DistanceTo(target.pos) < 300 then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			end
		end
		if Menu.Style.MainQ:Value() then
			if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE or (hasAwakenedQ and not haspassiveAA)) and myHero.pos:DistanceTo(target.pos) < 300 then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			end
			if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE) and (not IsReady(_Q) or not hasAwakenedQ) and not hasAwakenedR and myHero.pos:DistanceTo(target.pos) < 450 then
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end
			end
		end
		if myHero.health/myHero.maxHealth <= Menu.Combo.Whp:Value()/100 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and getEnemyCount(600, myHero.pos) >= 1 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.health/myHero.maxHealth <= Menu.Combo.W2hp:Value()/100 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and hasAwakenedW and getEnemyCount(600, myHero.pos) >= 1 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
end

function Udyr:JungleClear()
	local count = getMinionCount(450, myHero.pos)
	local hasAwakenedQ = doesMyChampionHaveBuff("udyrqrecastready")
	local hasAwakenedR = doesMyChampionHaveBuff("udyrrrecastready")
	local haspassiveAA = doesMyChampionHaveBuff("UdyrPAttackReady")
	local R1 = getBuffData(myHero, "UdyrRActivation")
	local target = HealthPrediction:GetJungleTarget()
	if target and not haspassiveAA then
		if Menu.Clear.Q:Value() and IsReady(_Q) and count == 1 then
			Control.CastSpell(HK_Q)
				if hasAwakenedQ then
					Control.CastSpell(HK_Q)
				end
		elseif not hasAwakenedR and IsReady(_R) and not IsReady(_Q) then
			Control.CastSpell(HK_R)
		end
		if Menu.Clear.R:Value() and IsReady(_R) and count > 1 then
			Control.CastSpell(HK_R)
				if hasAwakenedR and R1.duration < 0.5 then
					Control.CastSpell(HK_R)
				end
		elseif not hasAwakenedQ and IsReady(_Q) and not IsReady(_R) then
			Control.CastSpell(HK_Q)
		end
		if myHero.health/myHero.maxHealth <= Menu.Clear.Whp:Value()/100 and Menu.Clear.W:Value() and IsReady(_W) then
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
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 825, Speed = 1400, Collision = false}
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
		Menu.Auto:MenuElement({type = MENU, id = "WB", name = "Auto W If Enemy dash to ME"})
			ObjectManager:OnEnemyHeroLoad(function(args)
				Menu.Auto.WB:MenuElement({id = args.charName, name = args.charName, value = false})				
			end)
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q] auto kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "[E] to mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range in minimap", toggle = true, value = true})
end

function Galio:onTick()
	if ShouldWait() then
		return
	end
	if doesMyChampionHaveBuff("GalioW") then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
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

function Galio:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if IsReady(_Q) or IsReady(_W) or IsReady(_E) then
			args.Process = false
		end
	end
end

function Galio:Combo()
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.eSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		local wallPos = FindFirstWallCollision(myHero.pos, pred.CastPosition)
			if wallPos == nil then
				if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
					castSpellHigh(self.eSpell, HK_E, target)
				end
			end
		end
		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Combo.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if Menu.Combo.W:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			self:CastW(Menu.Combo.Wtime:Value())
		end
	end
end

function Galio:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range and Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Galio:AutoW()
	if Menu.Auto.W:Value() and getEnemyCount(self.wSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < Menu.Auto.WHP:Value()/100 then
		self:CastW(Menu.Auto.Wtime:Value())
	end
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) then
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
	if IsReady(_W) and lastW + 2000 < GetTickCount() then
		Control.KeyDown(HK_W)
		lastW = GetTickCount()
		DelayAction(function() Control.KeyUp(HK_W) end, time)
	end
end

function Galio:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		local pos = myHero.pos + (mousePos - myHero.pos)
		Control.CastSpell(HK_E, pos)
	end
end

function Galio:KillSteal()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(225, 225, 0, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.wSpell, HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
	if Menu.Combo.R1:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "YorickR" then
		local target = TargetSelector:GetTarget(self.rSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_R, target)
		end
	end
end

function Yorick:Harass()
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.eSpell.Range and Menu.Harass.E:Value() and IsReady(_E) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
end

function Yorick:LaneClear()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" then
			if myHero.pos:DistanceTo(target.pos) <= 350 and self:getqDmg(target) >= target.health then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				Control.Attack(target)
			end
		end
		if Menu.Clear.Q2:Value() and myHero:GetSpellData(_Q).name == "YorickQ2" and lastQ + 300 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.E:Value() and IsReady(_E) then
			bestPosition, bestCount = getAOEMinion(self.eSpell.Range, self.eSpell.Radius)
			if bestCount > 0 then
				Control.CastSpell(HK_E, bestPosition)
			end
		end
	end
end

function Yorick:LastHit()
	local target = HealthPrediction:GetJungleTarget()
	if not target then
		target = HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.LastHit.Q:Value() and IsReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" then
			if myHero.pos:DistanceTo(target.pos) <= 350 and self:getqDmg(target) >= target.health then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				Control.Attack(target)
			end
		end
	end
end

function Yorick:Flee()
	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if IsValid(target) then
		if Menu.Flee.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
			if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
				castSpellHigh(self.wSpell, HK_W, target)
				lastW = GetTickCount()
			end
		end
	end
end

function Yorick:KillSteal()
	local target = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) and lastQ + 250 < GetTickCount() and Menu.KS.Q:Value() then
			if self:getqDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= 350 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				Control.Attack(target)
			end
		end
		if IsReady(_E) and Menu.KS.E:Value() then
			if self:geteDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
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
	local eDmg = target.maxHealth * ((0.5 * elvl + 5.5)/100 + 0.0003 * myHero.ap)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function Yorick:AutoW()
	for _, target in pairs(GetEnemyHeroes()) do
		if Menu.Auto.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and isInvulnerable(target) or isImmobile(target) then
			if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
				Control.CastSpell(HK_W, target)
				lastW = GetTickCount()
			end
		end
	end
end

function Yorick:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
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
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoE.Etarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
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
	if ShouldWait() then
		return
	end
	if Menu.Misc.disableAA:Value() and getEnemyCount(self.qSpell.Range, myHero.pos) >= Menu.Misc.count:Value() then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
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
end

function Ivern:CastQ(target)
	if IsReady(_Q) and myHero:GetSpellData(_Q).name == "IvernQ" then
		local Pred = GGPrediction:SpellPrediction(self.qSpell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function Ivern:Combo()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Combo.Q:Value() then
			self:CastQ(target)
		end
		if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and myHero:GetSpellData(_R).name == "IvernR" and Menu.Combo.R:Value() and IsReady(_R) then
			 Control.CastSpell(HK_R, target)
		end
	end
end

function Ivern:AutoE()
	if IsReady(_E) and lastE + 250 < GetTickCount() then
		local enemies = ObjectManager:GetEnemyHeroes(2500)
		local bestAlly, minDist = nil, math.huge
		for _, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				local allies = ObjectManager:GetAllyHeroes(self.eSpell.Range)
				local validAllies = {}
				for _, ally in ipairs(allies) do
					if Menu.AutoE.Etarget[ally.charName] and Menu.AutoE.Etarget[ally.charName]:Value() then
						table.insert(validAllies, ally)
					end
				end
				for _, ally in ipairs(validAllies) do
					local dist = ally.pos:DistanceTo(enemy.pos)
					if dist < self.eSpell.Radius and dist < minDist then
						bestAlly = ally
						minDist = dist
					end
				end
			end
		end
		if bestAlly then
			Control.CastSpell(HK_E, bestAlly)
			lastE = GetTickCount()
		end
	end
end

function Ivern:DaisyControl()
	local target = TargetSelector:GetTarget(2500)
	if IsValid(target) and lastR + 250 < GetTickCount() then
		if Menu.Daisy.R1:Value() and target.pos2D.onScreen then
			Control.CastSpell(HK_R, target)
			lastR = GetTickCount()
		end
	end
	if Menu.Daisy.R2:Value() and lastR + 250 < GetTickCount() then
		Control.CastSpell(HK_R, myHero)
		lastR = GetTickCount()
	end
end

function Ivern:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if myHero:GetSpellData(_Q).name == "IvernQ" and Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Ivern:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	self:AutoW()
end

function Bard:Combo()
	local target = TargetSelector:GetTarget(self.qextSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) then
			if Menu.Combo.Q:Value() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
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
						if IsValid(unit) and unit.pos:DistanceTo(pred2.CastPosition) < 300 and unit.pos:DistanceTo(myHero.pos) < self.qSpell.Range then
							Control.CastSpell(HK_Q, pred2.CastPosition)
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
			if GetDistance(myHero.pos, hero.pos) <= self.wSpell.Range and Menu.Auto.W:Value() and hero.health/hero.maxHealth <= Menu.Auto.Whp:Value()/100 and IsReady(_W) then
				Control.CastSpell(HK_W, hero)
			end
		end
	end
end

function Bard:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
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
	if ShouldWait() then
		return
	end
	if #vectorCast > 0 then
		vectorCast[1]()
		table.remove(vectorCast, 1)
		return
	end
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Taliyah:Combo()
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < self.qSpell.Range and Menu.Combo.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if myHero.pos:DistanceTo(target.pos) < Menu.Combo.Erange:Value() and Menu.Combo.E:Value() and IsReady(_E) and not IsReady(_W) then
			Control.CastSpell(HK_E, target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 1100 < GetTickCount() then
			local predPos = target:GetPrediction(self.wSpell.Speed, self.wSpell.Delay)
			local d = myHero.pos:DistanceTo(predPos)
			if d < self.wSpell.Range then
				local endPos = predPos + (myHero.pos - predPos):Normalized() * 225
				if d <= Menu.Combo.Wpush:Value() then
					endPos = predPos + (predPos - myHero.pos):Normalized() * 225
				end
				self:CastVectorSpell(HK_W, predPos, endPos)
				lastW = GetTickCount()
				return
			end
		end
	end
end

function Taliyah:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Taliyah:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
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
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 725, Speed = 2200, Collision = false}
	self.q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 900, Speed = 2200, Collision = false}
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
		-- Menu.Harass:MenuElement({id = "Mana", name = "Harass min Mana", value = 50, min = 1, max = 100, step = 5})
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
	if ShouldWait() then
		return
	end
	if doesMyChampionHaveBuff("LissandraRSelf") then
		Orbwalker:SetMovement(false)
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetMovement(true)
		Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
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
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = TargetSelector:GetTarget(self.rSpell.Range)
		if IsValid(target) then
			if self:R1Health() and getEnemyCount(self.rSpell.Radius, myHero.pos) < Menu.Combo.R2count:Value() then
				Control.CastSpell(HK_R, target)
			end
		end
	end
	if Menu.Combo.Q:Value() then
		local target = TargetSelector:GetTarget(self.q2Spell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E1:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			if not self:E2Ready() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range-100 then
				castSpellHigh(self.eSpell, HK_E, target)
			end
		end
	end
	if Menu.Combo.E2:Value() and self:E2Health() and self:E2Ready() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE2(target)
			lastE = GetTickCount()
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
		if (self:R2Health() and getEnemyCount(self.rSpell.Radius, myHero.pos) > 0) or getEnemyCount(self.rSpell.Radius, myHero.pos) >= Menu.Combo.R2count:Value() then
			Control.CastSpell(HK_R, myHero)
			lastR = GetTickCount()
		end
	end
	if getEnemyCount(self.wSpell.Radius, myHero.pos) >= 1 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W)
		lastW = GetTickCount()
	end
end

function Lissandra:Harass()
	local target = TargetSelector:GetTarget(self.q2Spell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() --[[and myHero.mana/myHero.maxMana > Menu.Harass.Mana:Value()/100 ]]then
			self:CastQ(target)
		end
	end
end

function Lissandra:Flee()
	if not self:E2Ready() then
		if Menu.Flee.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, mousePos)
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
	if IsReady(_Q) and lastQ + 350 < GetTickCount() then
		if dis > self.qSpell.Range and dis < self.q2Spell.Range then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
			if collisionCount > 0 then
				local unit = collisionObjects[1]
				if IsValid(unit) and myHero.pos:DistanceTo(unit.pos) <= self.qSpell.Range then
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
			if IsReady(_R) then
				if IsReady(_W) then
					if dist2 < self.wSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				else
					if dist2 < self.rSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				end
			else
				if IsReady(_W) then
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
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.Q2:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.q2Spell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Radius, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = TargetSelector:GetTarget(self.wSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.wSpell, HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_E)
		end
	end
end

function Sejuani:Harass()
	local target = TargetSelector:GetTarget(self.wSpell.Range)
	if IsValid(target) then
		if Menu.Harass.W:Value() and IsReady(_W) then
			castSpellHigh(self.wSpell, HK_W, target)
		end
	end
end

function Sejuani:RSemiManual()
	local target = TargetSelector:GetTarget(self.rSpell.Range)
	if IsValid(target) then
		if IsReady(_R) then
			castSpellHigh(self.rSpell, HK_R, target)
		end
	end
end

function Sejuani:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
		Menu.Combo:MenuElement({id = "W1Time", name = "W1 Channel time(s)", value = 0.7, min = 0.4, max = 1, step = 0.05})
		Menu.Combo:MenuElement({id = "W2", name = "[W] AllOut W", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W2Time", name = "AllOut W Channel time(s)", value = 0.7, min = 0.4, max = 1, step = 0.05})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EA", name = "use E close to enemy AApassive", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ET", name = "use E close to enemy useQ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EM", name = "use E allyminion close to enemy", toggle = true, value = true})
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
	if ShouldWait() then
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
	if IsCasting() then return end
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
	local target = TargetSelector:GetTarget(self.qSpell.Range + self.eSpell.Range)
	if IsValid(target) then
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() and IsReady(_Q) then
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
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
		if Menu.Combo.W:Value() and Menu.Combo.W2:Value() and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			if doesMyChampionHaveBuff("KSanteRTransform") and IsReady(_W) and lastW + 1100 < GetTickCount() then
				self:CastW(target, Menu.Combo.W2Time:Value())
				lastW = GetTickCount()
			end
		end
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 1100 < GetTickCount() and Menu.Combo.W1:Value() and myHero.pos:DistanceTo(target.pos) < 450 then
			local turrets = ObjectManager:GetAllyTurrets(2000)
			for i, turret in ipairs(turrets) do
				if turret.pos:DistanceTo(target.pos) < 1200 and turret.pos:DistanceTo(target.pos) < turret.pos:DistanceTo(myHero.pos) then
					self:CastW(target, Menu.Combo.W1Time:Value())
					lastW = GetTickCount()
				end
			end
			local allies = ObjectManager:GetAllyHeroes(2000)
			for k, ally in ipairs(allies) do
				if not ally.isMe and ally.pos:DistanceTo(target.pos) < 1000 and ally.pos:DistanceTo(target.pos) < ally.pos:DistanceTo(myHero.pos) then
					self:CastW(target, Menu.Combo.W1Time:Value())
					lastW = GetTickCount()
				end
			end
		end
		if Menu.Combo.RT:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "KSanteR" then
			local turrets = ObjectManager:GetAllyTurrets(2000)
			for i, turret in ipairs(turrets) do
				local Pos = target.pos:Extended(myHero.pos, -300)
				if turret.pos:DistanceTo(Pos) < 800 and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and turret.pos:DistanceTo(Pos) < turret.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_R, target)
				end
			end
		end
		if haveBuff(target, "KSantePMark") then
			local AARange = myHero.range + myHero.boundingRadius + target.boundingRadius + 25
			if myHero.pos:DistanceTo(target.pos) > AARange and myHero.pos:DistanceTo(target.pos) <= AARange + self.eSpell.Range then
				if Menu.Combo.E:Value() and Menu.Combo.EA:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
					Control.CastSpell(HK_E, target)
					lastE = GetTickCount()
				end
			end
		end
	end
end

function KSante:Harass()
	local target = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function KSante:CastW(target, time)
	local mPos = mousePos
	Control.SetCursorPos(target.pos)
	Control.KeyDown(HK_W)
	DelayAction(function() Control.SetCursorPos(mPos) end, 0.2)
	DelayAction(function() Control.KeyUp(HK_W) end, time)
end

function KSante:RSemiManual()
	local target = TargetSelector:GetTarget(self.rSpell.Range)
	if IsValid(target) then
		local Pos = target.pos:Extended(myHero.pos, -300)
		if MapPosition:intersectsWall(target.pos, Pos) and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and IsReady(_R) and lastR + 500 < GetTickCount() and myHero:GetSpellData(_R).name == "KSanteR" then
			Control.CastSpell(HK_R, target)
			lastR = GetTickCount()
		end
	end
end

function KSante:LaneClear()
	if Menu.Clear1.Q:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) and minion.team ~= 300 then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount >= Menu.Clear1.QCount:Value() and IsReady(_Q) and lastQ + 350 < GetTickCount() then
					Control.CastSpell(HK_Q, minion)
					lastQ = GetTickCount()
				end
			end
		end
	end
end

function KSante:JungleClear()
	if Menu.Clear1.Q:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) and minion.team == 300 and IsReady(_Q) and lastQ + 350 < GetTickCount() then
				Control.CastSpell(HK_Q, minion)
				lastQ = GetTickCount()
			end
		end
	end
end

function KSante:LastHit()
	local minionInRange = ObjectManager:GetEnemyMinions(self.qSpell.Range)
	if next(minionInRange) == nil then return end
	for i = 1, #minionInRange do
		local minion = minionInRange[i]
		if Menu.LastHit.Q:Value() and IsReady(_Q) and lastQ + 350 < GetTickCount() then
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
	if ShouldWait() then
		return
	end
	if haveBuff(myHero, "SkarnerR") then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
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
	if Qtarget and IsValid(Qtarget) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
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
	if Rtarget and IsValid(Rtarget) then
		if Menu.Combo.R:Value() and IsReady(_R) then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, self.rSpell.Speed, self.rSpell.Delay, self.rSpell.Radius, {GGPrediction.COLLISION_ENEMYHERO}, nil)
			if collisionCount >= Menu.Combo.RCount:Value() then
				castSpellHigh(self.rSpell, HK_R, Rtarget)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and getEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value() then
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
	if Qtarget and IsValid(Qtarget) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
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
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(target.pos) > Data:GetAutoAttackRange(myHero, target) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end
		if Menu.Clear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			Control.CastSpell(HK_W)
		end
	end
end

function Skarner:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.38, Radius = 70, Range = 600, Speed = 1600, Collision = false}
	self.wSpell = { Range = 525 }
	self.eSpell = { Range = 1100 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 600, Range = 3000, Speed = myHero:GetSpellData(_R).speed, Collision = false}
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
	if ShouldWait() then
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
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Maokai:OnPreAttack(args)
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		if IsReady(_Q) or IsReady(_W) then
			args.Process = false
		end
	end
end

function Maokai:Combo()
	local Etarget = TargetSelector:GetTarget(self.eSpell.Range)
	if IsValid(Etarget) then
		if Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, Etarget)
		end
	end
	local Wtarget = TargetSelector:GetTarget(self.wSpell.Range)
	if Wtarget and IsValid(Wtarget) then
		if Menu.Combo.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W, Wtarget)
		end
	end
	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if IsValid(Qtarget) then
		if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_W) then
			if not Menu.Combo.InsecQ:Value() or Qtoward == nil then
				castSpellHigh(self.qSpell, HK_Q, Qtarget)
			elseif Qtoward ~= nil then
				local Pos = Qtarget.pos + (Qtarget.pos - Qtoward):Normalized() * 250
				if GameIsWall(Pos) then
					castSpellHigh(self.qSpell, HK_Q, Qtarget)
				elseif myHero.pos:DistanceTo(Pos) < 100 then
					castSpellHigh(self.qSpell, HK_Q, Qtarget)
				end
			end
		end
	end
	local Rtarget = TargetSelector:GetTarget(Menu.Combo.Rrange:Value())
	if IsValid(Rtarget) then
		if IsReady(_R) and Menu.Combo.R:Value() then
			if getEnemyCount(self.rSpell.Radius, Rtarget.pos) >= Menu.Combo.Rcount:Value() then
				castSpellHigh(self.rSpell, HK_R, Rtarget)
			end
		end
	end
end

function Maokai:Harass()
	local Qtarget = TargetSelector:GetTarget(self.qSpell.Range)
	if Qtarget and IsValid(Qtarget) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			castSpellHigh(self.qSpell, HK_Q, Qtarget)
		end
	end
	local Etarget = TargetSelector:GetTarget(self.eSpell.Range)
	if Etarget and IsValid(Etarget) then
		if Menu.Harass.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, Etarget)
		end
	end
end

function Maokai:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
		self:JungleClear()
	end
	if IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQToggle" then
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
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(1000)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and not IsReady(_E) then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Gragas:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.eSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" then
		local target = TargetSelector:GetTarget(self.qSpell.Range)
		if IsValid(target) then
			castSpellHigh(self.qSpell, HK_Q, target)
		end
	end
end

function Gragas:InsecR()
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) and IsReady(_R) then
		local wallPos = FindFirstWallCollision(myHero.pos, target.pos)
		if wallPos == nil and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range - 150 then
			local pred = GGPrediction:SpellPrediction(self.rSpell)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -150)
				Control.CastSpell(HK_R, castPos)
			end
		end
	end
end

function Gragas:AutoR()
	local heroes = ObjectManager:GetEnemyHeroes(self.rSpell.Range - 150)
	for i, hero in ipairs(heroes) do
		if isImmobile(hero) and FindFirstWallCollision(myHero.pos, hero.pos) == nil and IsReady(_R) then
			Control.CastSpell(HK_R, Vector(hero.pos):Extended(Vector(myHero.pos), -150))
		end
	end
end

function Gragas:JungleClear()
	local target = HealthPrediction:GetJungleTarget()
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_Q, target)
		end
		if IsReady(_Q) and lastQ + 250 < GetTickCount() and myHero:GetSpellData(_Q).name == "GragasQToggle" and getBuffData(myHero, "GragasQ").duration < 2 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if Menu.Clear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			Control.CastSpell(HK_E, target)
		end
	end
end

function Gragas:CastQ2()
	for i = GameParticleCount(), 1, -1 do
	local particle = GameParticle(i)
		if particle and particle.name:find("Gragas") and particle.name:find("_Q_Ally") and getEnemyCount(300, particle.pos) >= 1 and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function Gragas:KillSteal()
	local target = TargetSelector:GetTarget(self.rSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and Menu.KS.Q:Value() then
			if self:getQDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				castSpellHigh(self.qSpell, HK_Q, target)
			end
		end
		if IsReady(_E) and Menu.KS.E:Value() then
			if self:getEDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
				castSpellHigh(self.eSpell, HK_E, target)
			end
		end
		if IsReady(_R) and Menu.KS.R:Value() then
			if self:getRDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
				castSpellHigh(self.rSpell, HK_R, target)
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
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.Combo.Rhealtarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		-- Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 30, min = 0, max = 100})
	Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
		Menu.AutoW:MenuElement({id = "W", name = "[W]Auto heal", toggle = true, value = true})
		Menu.AutoW:MenuElement({id = "WHP", name = "When ally or self <= X hp%", value = 50, min = 0, max = 100, step = 5})
		Menu.AutoW:MenuElement({type = MENU,id = "Wtarget", name = "Use On"})
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoW.Wtarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
		Menu.AutoE:MenuElement({id = "E", name = "[E]Auto shield", toggle = true, value = true})
		Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoE.Etarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
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
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoR.Rclearstarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "AutoQ", name = "AutoQ"})
		Menu.AutoQ:MenuElement({id = "AntiDash", name = "AutoQ Anti-Dash",toggle = true, value = true})
		Menu.AutoQ:MenuElement({type = MENU,id = "AntiTarget", name = "Use On"})
			ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoQ.AntiTarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function Milio:onTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.Q:Value() then
			self:CastQ(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
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
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 ]]then
			self:CastQ(target)
		end
	end
end

function Milio:CastQ(target)
	if IsReady(_Q) then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, self.qSpell.CollisionTypes, target.networkID)
		if collisionCount >= 1 and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QBD:Value() + 1200 then
			local minion = collisionObjects[1]
			if IsValid(minion) and minion.pos:DistanceTo(target.pos) < Menu.Combo.QBD:Value() and minion.pos:DistanceTo(myHero.pos) < 1100 then
				if myHero.pos:DistanceTo(target.pos) < 1100 then
					local Pred = GGPrediction:SpellPrediction(self.qnocolSpell)
					Pred:GetPrediction(target, myHero)
					if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
						Control.CastSpell(HK_Q, Pred.CastPosition)
					end
				else
					local Pred = GGPrediction:SpellPrediction(self.qnocolSpellextended)
					Pred:GetPrediction(target, myHero)
					if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
						Control.CastSpell(HK_Q, minion)
					end
				end
			end
		elseif collisionCount <= 1 and myHero.pos:DistanceTo(target.pos) < 1100 then
			local Pred = GGPrediction:SpellPrediction(self.qSpell)
			Pred:GetPrediction(target, myHero)
			if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_Q, Pred.CastPosition)
			end
		end
	end
end

function Milio:AutoW()
	if IsReady(_W) and myHero:GetSpellData(_W).name == "MilioW" then
	local heroes = ObjectManager:GetAllyHeroes(self.wSpell.Range)
		for i, hero in ipairs(heroes) do
			if Menu.AutoW.Wtarget[hero.charName] and Menu.AutoW.Wtarget[hero.charName]:Value() then
				if hero.health/hero.maxHealth <= Menu.AutoW.WHP:Value()/100 and getEnemyCount(1200, hero.pos) > 0 then
					Control.CastSpell(HK_W, hero)
				end
			end
		end
	end
end

function Milio:AutoE()
	if IsReady(_E) and lastE + 250 < GetTickCount() then
		local enemies = ObjectManager:GetEnemyHeroes(2500)
		local allies = ObjectManager:GetAllyHeroes(self.eSpell.Range)
		local turrets = ObjectManager:GetEnemyTurrets(1500)
		for _, ally in ipairs(allies) do
			if IsValid(ally) and Menu.AutoE.Etarget[ally.charName] and Menu.AutoE.Etarget[ally.charName]:Value() then
				for _, enemy in ipairs(enemies) do
					if IsValid(enemy) then
						local canuse = false
						if enemy.isChanneling then 
							if enemy.activeSpell.target == ally.handle then
								canuse = true
							else
								local endPos = enemy.activeSpell.startPos:Extended(enemy.activeSpell.placementPos, enemy.activeSpell.range)
								local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
								local width = ally.boundingRadius + (enemy.activeSpell.width > 0 and enemy.activeSpell.width or 0)
								if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
									canuse = true
								end
							end
						elseif enemy.activeSpell.target == ally.handle then --autoattack
							canuse = true
						end
						if canuse then
							Control.CastSpell(HK_E, ally)
							lastE = GetTickCount()
							return
						end
					end
				end
				for _, turret in ipairs(turrets) do
					if turret and turret.targetID then
						if turret.targetID == ally.networkID then
							Control.CastSpell(HK_E, ally)
							lastE = GetTickCount()
							return
						end
					end
				end
			end
		end
	end
end

function Milio:AutoR()
	if IsReady(_R) and lastR + 250 < GetTickCount() then
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
		if IsValid(enemy) and Menu.AutoQ.AntiTarget[enemy.charName] and Menu.AutoQ.AntiTarget[enemy.charName]:Value()then
			if enemy.pathing.isDashing and enemy.pathing.hasMovePath and enemy.pathing.dashSpeed > 0 then
				if myHero.pos:DistanceTo(enemy.pathing.startPos) > myHero.pos:DistanceTo(enemy.pathing.endPos) then
					if IsReady(_Q) and lastQ + 350 < GetTickCount() then
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
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, 1000, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 0, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	if myHero.activeSpell.valid and (Game.Timer() >= myHero.activeSpell.startTime and Game.Timer() <= myHero.activeSpell.castEndTime) then
		return
	end
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
	if IsValid(Rtarget) then
		if Menu.Combo.R:Value() and myHero.activeSpell.isCharging == false then 
			self:CastRAoE(Rtarget)
		end
	end
	if IsValid(Etarget) then
		if Menu.Combo.E:Value() and myHero.activeSpell.isCharging == false then
			self:CastEAoE(Etarget)
		end
		if Menu.Combo.Q:Value() and not IsReady(_E) then
			self:CastQ(Etarget)
		end
	end
end

function AurelionSol:Harass()
	if IsValid(Etarget) then
		if Menu.Harass.E:Value() then
			self:CastEAoE(Etarget)
		end
	end
end

function AurelionSol:SemiManualR()
	if IsValid(Rtarget) then
		if IsReady(_R) and lastR + 250 < GetTickCount() then
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
	if IsReady(_E) then
		local enemies = GetEnemiesAtPos(self.eSpell.Range + self.eSpell.Radius/2, self.eSpell.Radius, target.pos,target)
		if #enemies >= 2 then
			local AoEPos = CalculateBestCirclePosition(enemies, self.eSpell.Radius/2, true, self.eSpell.Range, self.eSpell.Speed, self.eSpell.Delay)
			Control.CastSpell(HK_E, AoEPos)
		else
			castSpellHigh(self.eSpell, HK_E, target)
		end
	end
end

function AurelionSol:CastRAoE(target)
	if IsReady(_R) and lastR + 250 < GetTickCount() then
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
	if IsReady(_Q) then
		Control.SetCursorPos(target.pos)
		Control.KeyDown(HK_Q)	
	end
end

function AurelionSol:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.W2:Value() and IsReady(_W) then
		Draw.CircleMinimap(myHero.pos, self.wSpell.Range, 1, Draw.Color(200, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
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
	self.Q = {Delay = 0.25, Range = 350}
	self.W = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 1200, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}} 
	self.E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 970, Speed = 1200, Collision = false}
	self.E2 = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1500, Speed = 1200, Collision = false}
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
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
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
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) then
		if Menu.Combo.RQ:Value() and IsReady(_Q) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and getEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= Menu.Combo.RQCount:Value() then
			self:CastR()
			self:CastQ(target)
		elseif Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and getEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= 1 then
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
		if Menu.Combo.RE:Value() and IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range and getEnemyCount(275, target.pos) >= Menu.Combo.RECount:Value() then
			self:CastR()
			self:CastE2(target)
		elseif Menu.Combo.E:Value() and IsReady(_E) then
			if haveBuff(myHero, "HeimerdingerR") then
				if myHero.pos:DistanceTo(target.pos) < self.E2.Range then
					self:CastE2(target)
				end
			else
				if myHero.pos:DistanceTo(target.pos) < self.E.Range then
					self:CastE(target)
				end
			end
		end
		if Menu.Combo.RW:Value() and IsReady(_W) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.W.Range and self:getRWDmg(target) >= target.health then
			self:CastR()
			self:CastW(target)
		elseif Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastW(target)
		end
	end
end

function Heimerdinger:Harass()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) then
		if Menu.Harass.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.E.Range then
			self:CastE(target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastW(target)
		end
	end
end

function Heimerdinger:SemiManualRW()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) then
		if IsReady(_W) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastR()
			self:CastW(target)
		end
	end
end

function Heimerdinger:SemiManualRE()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) then
		if IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range then
			self:CastR()
			self:CastE2(target)
		end
	end
end

function Heimerdinger:Flee()
	local target = TargetSelector:GetTarget(1500)
	if IsValid(target) and Menu.Misc.Flee:Value() then
		if IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range then
			self:CastR()
			self:CastE2(target)
		else
			if IsReady(_E) and not IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E.Range then
				self:CastE(target)
			end
		end
	end
end

function Heimerdinger:CastQ(target)
	local Castpos = myHero.pos:Extended(target.pos, Menu.Combo.QRange1:Value())
	Control.CastSpell(HK_Q, Castpos)
end

function Heimerdinger:CastW(target)
	local pred = GGPrediction:SpellPrediction(self.W)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_W, pred.CastPosition)	
	end
end

function Heimerdinger:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.E)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function Heimerdinger:CastE2(target)
	local pred = GGPrediction:SpellPrediction(self.E2)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function Heimerdinger:CastR()
	if not haveBuff(myHero, "HeimerdingerR") and lastR + 250 < GetTickCount() then
		Control.CastSpell(HK_R)
		lastR = GetTickCount()
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
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.E2:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E2.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

-----------------------------------

class "Briar"
		
function Briar:__init()		 
	print("Simple Briar Loaded")
	self:LoadMenu()
	Callback.Add("Tick", function() self:onTick() end)	
	self.Q = {Range = 450}
	self.W = {Range = 1000}
	self.E = {Range = 600}
	self.R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 160, Range = 10000, Speed = 2000, Collision = false}
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
	if IsCasting() then return end
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
	local target = TargetSelector:GetTarget(1000)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, target.pos) <= self.Q.Range and GetDistance(myHero.pos, target.pos) > Data:GetAutoAttackRange(myHero) then
			Control.CastSpell(HK_Q, target)
		end
		if Menu.Combo.EWall:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() then
			local Pos = myHero.pos:Extended(target.pos, self.E.Range)
			local Pos2 = FindFirstWallCollision(myHero.pos, Pos)
			if Pos2 and isImmobile(target) and GetDistance(myHero.pos, target.pos) < self.E.Range then
				self:CastE(target)
				lastE = GetTickCount()
			end
		end
		if Menu.Combo.W:Value() and not haveBuff(myHero, "BriarRSelf") and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and GetDistance(myHero.pos, target.pos) < self.W.Range then
			Control.CastSpell(HK_W, target)
		end
		if Menu.Combo.W2:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and GetDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
			Control.CastSpell(HK_W)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() and GetDistance(myHero.pos, target.pos) < self.E.Range and myHero.health/myHero.maxHealth <= Menu.Combo.EHP:Value()/100 then
			self:CastE(target)
			lastE = GetTickCount()
		end
	end
end

function Briar:RSemiManual()
	local target = TargetSelector:GetTarget(self.R.Range)
	if IsValid(target) then
		if IsReady(_R) then
			local pred = GGPrediction:SpellPrediction(self.R)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_R, pred.CastPosition)
			end
		end
	end
end

function Briar:CastE(target)
	local mPos = mousePos
	Control.SetCursorPos(target.pos)
	Control.KeyDown(HK_E)
	DelayAction(function() Control.SetCursorPos(mPos) end, 0.1)
	DelayAction(function() Control.KeyUp(HK_E) end, 1)
end

function Briar:JungleClear()
	local target = HealthPrediction:GetJungleTarget()
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, target.pos) <= self.Q.Range then
			Control.CastSpell(HK_Q, target)
		end
		if Menu.Clear.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and GetDistance(myHero.pos, target.pos) < self.W.Range then
			Control.CastSpell(HK_W, target)
		end
		if Menu.Clear.W2:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and GetDistance(myHero.pos, target.pos) < Data:GetAutoAttackRange(myHero) and getBuffData(myHero, "BriarWAttackSpell").duration < 3 then
			Control.CastSpell(HK_W)
		end
		if Menu.Clear.E:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() and GetDistance(myHero.pos, target.pos) < self.E.Range and myHero.health/myHero.maxHealth <= Menu.Clear.EHP:Value()/100 then
			self:CastE(target)
			lastE = GetTickCount()
		end
	end
end

function Briar:AutoW2()
	local target = TargetSelector:GetTarget(Data:GetAutoAttackRange(myHero))
	if IsValid(target) then
		local W2Dmg = self:getW2BonusDmg(target)
		if IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and W2Dmg >= (target.health + target.shieldAD) then
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
	Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.55, Radius = 210, Range = 800, Speed = math.huge, Collision = false}
	self.W = { Range = 500 } 
	self.E = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 100, Range = 450, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO}}
	self.R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 80, Range = 2500, Speed = 3200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO}}
end

function Urgot:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		-- Menu.Combo:MenuElement({id = "AWA", name = "Use [AWA] When W 5 levels", toggle = true, value = true})
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
	if ShouldWait() then
		return
	end
	if myHero:GetSpellData(_W).name == "UrgotWCancel" then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	if Menu.Combo.Rsm:Value() then
		self:SemiManualR()
	end
	self:AutoR2()
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		-- self:AWA()
		self:Combo()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	end
end

function Urgot:OnPostAttack()
	local target = Orbwalker:GetTarget()
	if IsValid(target) and target.type == Obj_AI_Hero then
		if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
			if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and myHero:GetSpellData(_W).name == "UrgotW" then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
	end
end

-- function Urgot:AWA()
	-- local target = Orbwalker:GetTarget()
	-- if IsValid(target) and target.type == Obj_AI_Hero then
		-- if Menu.Combo.AWA:Value() and IsReady(_W) then
			-- if myHero:GetSpellData(_W).level == 5 and myHero:GetSpellData(_W).name == "UrgotWCancel" and myHero.attackData.state == 1 then
				-- Control.CastSpell(HK_W)
			-- end
		-- end
	-- end
-- end

function Urgot:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = TargetSelector:GetTarget(self.Q.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.E.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		if Menu.Combo.Rkill:Value() then
			local target = TargetSelector:GetTarget(self.R.Range)
			if IsValid(target) and (target.health - self:getRDmg(target))/target.maxHealth < 0.25 then
				self:CastR(target)
			end
		end
	end
end

function Urgot:Harass()
	local target = TargetSelector:GetTarget(self.Q.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function Urgot:SemiManualR()
	local target = TargetSelector:GetTarget(self.R.Range)
	if IsValid(target) then
		if IsReady(_R) and myHero:GetSpellData(_R).name == "UrgotR" then
			self:CastR(target)
		end
	end
end

function Urgot:AutoR2()
	local enemies = ObjectManager:GetEnemyHeroes(self.R.Range)
	for i, target in ipairs(enemies) do
		if IsValid(target) and haveBuff(target, "urgotrslow") and target.health/target.maxHealth < 0.25 then
			if IsReady(_R) and myHero:GetSpellData(_R).name == "UrgotRRecast" then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function Urgot:CastQ(target)
	local pred = GGPrediction:SpellPrediction(self.Q)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_Q, pred.CastPosition)	
	end
end

function Urgot:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.E)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function Urgot:CastR(target)
	local pred = GGPrediction:SpellPrediction(self.R)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_R, pred.CastPosition)	
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
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.R.Range, 1, Draw.Color(255, 255, 0, 0))
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
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 900, Speed = 1600, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 80, Range = 825, Speed = MathHuge, Collision = false}
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
		if Menu.Combo.DisableAA:Value() and (IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" or IsReady(_E)) then
			args.Process = false
		end
	end
end

function Aurora:OnTick()
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	self:AutoQ2()
	if IsCasting() then return end
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
			for i, enemy in ipairs(GetEnemyHeroes()) do
				if IsValid(enemy) and haveBuff(enemy, "auroraqdebufftracker") then
					local Q2Dmg = self:GetQ2Dmg(enemy) + self:GetPDmg(enemy)
					if (enemy.health + enemy.shieldAD + enemy.shieldAP) <= Q2Dmg or getBuffData(myHero, "AuroraQRecast").duration < 1 then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end

function Aurora:AntiGapcloser()
	if Menu.Misc.EGap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(Menu.Combo.Erange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					self:CastE(target)
				end
			end
		end
	end
end

function Aurora:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = TargetSelector:GetTarget(Menu.Combo.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) then 
			self:CastE(target)
		end
	end
end

function Aurora:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = TargetSelector:GetTarget(Menu.Combo.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function Aurora:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end

function Aurora:CastE(unit)
	local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
	EPrediction:GetPrediction(unit, myHero)
	if EPrediction:CanHit(3) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function Aurora:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

----------------------------

class "Ambessa"

function Ambessa:__init()
	print("Simple Ambessa Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.Q1Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 100, Range = 375, Speed = MathHuge, Collision = false}
	self.Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.225, Radius = 15, Range = 650, Speed = MathHuge, Collision = false}
	self.WSpell = { Range = 325 }
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 100, Range = 325, Speed = MathHuge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 15, Range = 1250, Speed = MathHuge, Collision = false}
end

function Ambessa:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q2", name = "Use Q2", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q2", name = "Use Q2", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Q", name = "Use Q Dash to Mouse", toggle = true, value = true})
	Menu.Flee:MenuElement({id = "W", name = "Use W Dash to Mouse", toggle = true, value = true})
	Menu.Flee:MenuElement({id = "E", name = "Use E Dash to Mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function Ambessa:OnTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	elseif Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	elseif Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
		self:Flee()
	end
end

function Ambessa:OneKeyCastR()
	local Rtarget = TargetSelector:GetTarget(self.RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		Control.CastSpell(HK_R, Rtarget)
	end
end

function Ambessa:Combo()
	local target = TargetSelector:GetTarget(Data:GetAutoAttackRange(myHero))
	local hasPassiveAA = IsValid(target) and haveBuff(myHero, "AmbessaPassiveAttackEmpower")
	if hasPassiveAA then
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = TargetSelector:GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = TargetSelector:GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = TargetSelector:GetTarget(self.Q1Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Combo.Q2:Value() and IsReady(_Q) and haveBuff(myHero, "AmbessaQEmpowerReady") then
		local target = TargetSelector:GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function Ambessa:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = TargetSelector:GetTarget(self.Q1Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Harass.Q2:Value() and IsReady(_Q) and haveBuff(myHero, "AmbessaQEmpowerReady") then
		local target = TargetSelector:GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

local lastCastTime = 0
local CAST_DELAY = 0.5
function Ambessa:Flee()
	local currentTime = Game.Timer()
	if currentTime - lastCastTime < CAST_DELAY then
		return
	end
	if Menu.Flee.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
		lastCastTime = currentTime
		return 
	end
	if Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, mousePos)
		lastCastTime = currentTime
		return 
	end
	if Menu.Flee.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, mousePos)
		lastCastTime = currentTime
		return 
	end
end

function Ambessa:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(haveBuff(myHero, "AmbessaQEmpowerReady") and self.Q2Spell or self.Q1Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function Ambessa:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, haveBuff(myHero, "AmbessaQEmpowerReady") and self.Q2Spell.Range or self.Q1Spell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

-------------------------------------

class "Mel"

function Mel:__init()
	print("Simple Mel Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 950, Speed = 4500, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 150, Range = 1050, Speed = 1000, Collision = false}
end

function Mel:LoadMenu()
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "AutoW", name = "Auto W"})
	Menu.AutoW:MenuElement({id = "W", name = "Auto W Reflect", toggle = true, value = true})
	Menu.AutoW:MenuElement({name = " ", drop = {"Reflect Abilities: "}})
	ObjectManager:OnEnemyHeroLoad(function(args)
		champName = args.charName
		enemy = args.unit
		Menu.AutoW:MenuElement({id = champName, name = champName, type = MENU})
		if champName == "Hwei" then
			Menu.AutoW[champName]:MenuElement({id = HweiQQ, name = "QQ", value = false})
			Menu.AutoW[champName]:MenuElement({id = HweiQW, name = "QW", value = false})
			Menu.AutoW[champName]:MenuElement({id = HweiQE, name = "QE", value = false})
			Menu.AutoW[champName]:MenuElement({id = HweiEQ, name = "EQ", value = false})
			Menu.AutoW[champName]:MenuElement({id = HweiEW, name = "EW", value = false})
			Menu.AutoW[champName]:MenuElement({id = HweiEE, name = "EE", value = false})
			Menu.AutoW[champName]:MenuElement({id = enemy:GetSpellData(_R).name, name = "R", value = false})
		else
			Menu.AutoW[champName]:MenuElement({id = enemy:GetSpellData(_Q).name, name = "Q", value = false})
			Menu.AutoW[champName]:MenuElement({id = enemy:GetSpellData(_W).name, name = "W", value = false})
			Menu.AutoW[champName]:MenuElement({id = enemy:GetSpellData(_E).name, name = "E", value = false})
			Menu.AutoW[champName]:MenuElement({id = enemy:GetSpellData(_R).name, name = "R", value = false})
		end
	end)
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E AntiGapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Rkill", name = "Auto R Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function Mel:OnTick()
	if ShouldWait() then
		return
	end
	self:AutoQ()
	self:AutoW()
	self:AutoR()
	if IsCasting() then return end
	if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
		self:Combo()
	elseif Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
		self:Harass()
	elseif Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
		self:LaneClear()
		self:JungleClear()
	end
end

function Mel:AutoQ()	
	if Menu.Misc.Qcc:Value() and IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and isImmobile(target) then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
end

function Mel:AutoE()	
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and target.posTo then
				if myHero.pos:DistanceTo(enemy.posTo) < myHero.pos:DistanceTo(target.pos) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end
end

function Mel:GetPDmg(target)
	local rlevel = myHero:GetSpellData(_R).level
	local buffCount = getBuffData(target, "MelPassiveOverwhelm").stacks
	local PDmg = 0
	if buffCount > 0 then
		if rlevel == 0 then
			PDmg = (50 + 0.1 * myHero.ap) + (2 + 0.0075 * myHero.ap) * buffCount
		else
			PDmg = (({60, 70, 80})[rlevel] + 0.1 * myHero.ap) + (({3, 4, 5})[rlevel] + 0.0075 * myHero.ap) * buffCount
		end
	end
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		PDmg = PDmg * 1.2
	end
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function Mel:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local buffCount = getBuffData(target, "MelPassiveOverwhelm").stacks
	local RDmg = (({100, 150, 200})[level] + 0.30 * myHero.ap) + (({4, 7, 10})[level] + 0.035 * myHero.ap) * buffCount
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		RDmg = RDmg * 1.2
	end
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function Mel:AutoR()	
	if Menu.Misc.Rkill:Value() and IsReady(_R) then
		for _, target in ipairs(GetEnemyHeroes()) do
			if IsValid(target) and haveBuff(target, "MelPassiveOverwhelm") then
				local Dmg = self:GetRDmg(target) + self:GetPDmg(target)
				if Dmg > target.health + target.shieldAD + target.shieldAP then
					Control.CastSpell(HK_R)
				end
			end
		end
	end
end

function Mel:Combo()
	local Etarget = TargetSelector:GetTarget(self.ESpell.Range)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) then
			self:CastGGPred(HK_E, Etarget)
		end
	end

	local Qtarget = TargetSelector:GetTarget(self.QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, Qtarget)
		end
	end
end

function Mel:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local Qtarget = TargetSelector:GetTarget(self.QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				self:CastGGPred(HK_Q, Qtarget)
			end
		end
	-- end
end

function Mel:AutoW()
	if not (Menu.AutoW.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount()) then return end
	local enemies = ObjectManager:GetEnemyHeroes(2500)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.isChanneling then
			local spell = enemy.activeSpell
			if spell and spell.valid and Menu.AutoW[enemy.charName] and Menu.AutoW[enemy.charName][spell.name] and Menu.AutoW[enemy.charName][spell.name]:Value() then
				if spell.target == myHero.handle then
					Control.CastSpell(HK_W)
					lastW = GetTickCount()
					return
				else
					local endPos = spell.startPos:Extended(spell.placementPos, spell.range + spell.width)
					local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(myHero.pos, endPos, spell.startPos)
					local width = myHero.boundingRadius + (spell.width > 0 and spell.width or 0)
					if isOnSegment and GGPrediction:IsInRange(myHero.pos, point, width) then
						Control.CastSpell(HK_W)
						lastW = GetTickCount()
						return
					end
				end
			end
		end
	end
end

function Mel:LaneClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					if getMinionCount(self.QSpell.Radius, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
					end
				end
			end
		end
	end
end

function Mel:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
			local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_E, minion)
				end
			end
		end
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function Mel:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function Mel:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end