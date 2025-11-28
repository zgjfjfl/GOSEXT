local Version = 2025.49
--[[ AutoUpdate ]]
do
	local Files = {
		Lua = {
			Path = SCRIPT_PATH,
			Name = "SimpleMarksmen.lua",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/SimpleMarksmen.lua"
	   },
		Version = {
			Path = SCRIPT_PATH,
			Name = "SimpleMarksmen.version",
			Url = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/main/SimpleMarksmen.version"
		}
	}

	DownloadFileAsync(Files.Version.Url, Files.Version.Path .. Files.Version.Name, function()
		local file = io.open(Files.Version.Path .. Files.Version.Name, "r")
		if file then
			local NewVersion = tonumber(file:read("*a"))
			file:close()
			if NewVersion and NewVersion > Version then
				print("SimpleMarksmen: Found update! Downloading...")
				DownloadFileAsync(Files.Lua.Url, Files.Lua.Path .. Files.Lua.Name, function()
					print("SimpleMarksmen: Successfully updated. Press 2x F6!")
				end)
			end
		end
	end)
end

local Heroes = {"Nilah", "Smolder", "Zeri", "Lucian", "Jinx", "Tristana", "MissFortune", "Jayce", "Kalista", "Ashe", "Corki", "Caitlyn", "Yunara"}

if not table.contains(Heroes, myHero.charName) then
	print('SimpleMarksmen not supported ' .. myHero.charName)
	return 
end

require "GGPrediction"

local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameParticleCount = Game.ParticleCount
local GameParticle = Game.Particle
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local GameObjectCount = Game.ObjectCount
local GameObject = Game.Object
local GameCampCount = Game.CampCount
local GameCamp = Game.Camp
local GameWardCount = Game.WardCount
local GameWard = Game.Ward
local GameTimer = Game.Timer
local GameIsWall = Game.isWall
local GameCanUseSpell = Game.CanUseSpell
local GamemapID = Game.mapID
local GameIsChatOpen = Game.IsChatOpen
local GameLatency = Game.Latency

local TableInsert = table.insert
local TableRemove = table.remove
local TableSort = table.sort
local MathHuge = math.huge
local MathMin = math.min
local MathMax = math.max
local MathFloor = math.floor
local MathSqrt = math.sqrt
local MathDeg = math.deg
local MathAbs = math.abs
local MathAcos = math.acos
local MathPi = math.pi

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0

local Orbwalker, TargetSelector, ObjectManager, HealthPrediction, Attack, Damage, Spell, Data

local Menu, championIcon

local blockFlag = false -- Prevent recursive callback
local function CheckChatBlock(menuElement, newValue) -- Block menu toggle when chat is open
    if GameIsChatOpen() and not blockFlag then
        blockFlag = true
        if menuElement then
            menuElement:Value(not newValue)
        end
        blockFlag = false
        return true
    end
    return false
end

local function IsReady(spell)
	local spellData = myHero:GetSpellData(spell)
	return spellData.currentCd == 0 and spellData.level > 0 and spellData.mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

local function IsValid(unit)
	return unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead
end

local function GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

local function GetDistance(Pos1, Pos2)
	return MathSqrt(GetDistanceSqr(Pos1, Pos2))
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

local function IsUnderTurret(unit)
	for _, turret in ipairs(ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
		if not turret.dead then 
			if turret.pos:DistanceTo(unit.pos) < range then
				return true
			end
		end
	end
	return false
end

local function IsUnderTurret2(pos)
	for _, turret in ipairs(ObjectManager:GetEnemyTurrets()) do
		local range = (turret.boundingRadius + 750)
		if not turret.dead then 
			if turret.pos:DistanceTo(pos) < range then
				return true
			end
		end
	end
	return false
end

local function HaveBuff(unit, buffName)
	buffName = buffName:lower()
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name:lower() == buffName and buff.count > 0 then
			return true
		end
	end
	return false
end

local function HasBuffContainsName(unit, name)
	name = name:lower()
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name:lower():find(name) and buff.count > 0 then
			return true
		end
	end
	return false
end

local function HaveBuffContainsNameNums(unit, name)
	name = name:lower()
	local count = 0
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name:lower():find(name) and buff.count > 0 then
			count = count + buff.count
		end
	end
	return count
end

local function GetBuffData(unit, buffName)
	buffName = buffName:lower()
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name:lower() == buffName and buff.count > 0 then 
			return true, buff
		end
	end
	return false, {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function GetEnemyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(ObjectManager:GetEnemyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function GetMinionCount(range, unit)
	local count = 0
	local Range = range * range
	for _, minion in ipairs(ObjectManager:GetEnemyMinions()) do
		if IsValid(minion) and GetDistanceSqr(unit, minion.pos) < Range then
			count = count + 1
		end
	end
	return count
end

local function GetAllyCount(range, unit)
	local count = 0
	local Range = range * range
	for _, hero in ipairs(ObjectManager:GetAllyHeroes()) do
		if IsValid(hero) and GetDistanceSqr(unit, hero.pos) < Range then
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

local function Recalling(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.name == "recall" and buff.count > 0 then
			return true
		end
	end
	return false
end

local function HasInvalidDashBuff(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 31 or buff.name == "ThreshQ") and buff.count > 0 then
			return true
		end
	end
	return false
end

local function GetMode()
	if _G.SDK then
		return 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
		or 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
		or 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
		or 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
		or 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
		or 
			Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or
			nil
	end
	return nil
end

local function GetTarget(range) 
	if _G.SDK then
		return TargetSelector:GetTarget(range)
	end
end

local function IsFacingMe(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(unit.dir)
	local Angle = 180 - MathDeg(MathAcos(V*D/(V:Len()*D:Len())))
	if MathAbs(Angle) < 80 then 
		return true
	end
	return false
end

local function CircleCircleIntersection(c1, c2, r1, r2)
	local D = GetDistance(c1,c2)
	if D > r1 + r2 or D <= MathAbs(r1 - r2) then return nil end
	local A = (r1 * r1 - r2 * r2 + D * D) / (2 * D)
	local H = MathSqrt(r1 * r1 - A * A)
	local Direction = (c2 - c1):Normalized()
	local PA = c1 + A * Direction
	local S1 = PA + H * Direction:Perpendicular()
	local S2 = PA - H * Direction:Perpendicular()
	return S1, S2
end

local function FindFirstWallCollision(startPos, endPos)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local step = 10
	for i = 0, distance, step do
		local checkPos = startPos + direction * i
		if MapPosition:inWall(checkPos) then -- GameIsWall(checkPos)
			return checkPos
		end
	end
	return nil
end

local function FindFirstWallCollisionInRectangle(startPos, endPos, width)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	local perpDirection = direction:Perpendicular()
	for i = 0, distance, 10 do
		local centerPos = startPos + direction * i
		for j = -width/2, width/2, 10 do
			local checkPos = centerPos + perpDirection * j
			if MapPosition:inWall(checkPos) then -- GameIsWall(checkPos)
				return checkPos
			end
		end
	end 
	return nil
end

local function IsCasting()
	if myHero.activeSpell.valid then
		if myHero.activeSpell.isCharging or
			(GameTimer() >= myHero.activeSpell.startTime and GameTimer() <= myHero.activeSpell.castEndTime)
		then
			return true
		end
	end
	return false
end

local epicMonsters = {
	["sru_baron"] = true,
	["sru_atakhan"] = true,
	["sru_riftherald"] = true,
	["sru_horde"] = true,
	["sru_dragon_water"] = true,
	["sru_dragon_fire"] = true,
	["sru_dragon_earth"] = true,
	["sru_dragon_air"] = true,
	["sru_dragon_chemtech"] = true,
	["sru_dragon_hextech"] = true,
	["sru_dragon_elder"] = true
}

local slots = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}
	
local function HasItem(unit, itemId)
	for i = 1, #slots do
		local slot = slots[i]
		local item = unit:GetItemData(slot)
		if item and item.itemID == itemId then
			return true
		end
	end
	return false
end

local function ShouldWait() 
	return myHero.dead or GameIsChatOpen() or 
			(_G.JustEvade and _G.JustEvade:Evading()) or  
			Recalling(myHero) or 
			Control.IsKeyDown(0x11) or 
			Control.IsKeyDown(0x12)
end

local function CastSpellAOE(spellSlot, spellData, minHitCount, source)
	local SpellPred = GGPrediction:SpellPrediction(spellData)
	local aoeResults = SpellPred:GetAOEPrediction(source)
	if #aoeResults == 0 then
		return false
	end
	TableSort(aoeResults, function(a, b) return a.Count > b.Count end)
	for i, result in ipairs(aoeResults) do
		if result.Count >= minHitCount then
			Control.CastSpell(spellSlot, result.CastPosition)
			return true
		end
	end
	return false
end

---------------------------------

class "zgNilah"

function zgNilah:__init()		 
	print("Marksmen Nilah Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 600, Speed = MathHuge, Collision = false}
	self.ESpell = { Range = 550 }
	self.RSpell = { Range = 450 }
end

function zgNilah:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Eammo", name = "[E] Save 1 stock for Kills or Flee or Manual", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ETHP", name = "Use E| when target HP %", value = 60, min=5, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| when can hit >= X enemies", min = 1, max = 5, value = 2})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 20, min = 0, max = 100})

	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
	Menu.Auto:MenuElement({id = "W", name = "Auto W| when enemyattackself", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "WHP", name = "when self HP %", value = 60, min = 5, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "QT", name = "Use Q| Turret, Barrack, Nexus", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
	Menu.KS:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KS:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "[E] To Mouse direction's Target", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgNilah:Tick()
	if ShouldWait() then
		return
	end
	self:AutoW()
	if IsCasting() then return end
	self:KillSteal()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LastHit()
		self:QBuildings()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	elseif Mode == "Flee" then
		self:Flee()
	end	
end

function zgNilah:OnPreAttack(args)
	local Mode = GetMode()
	if (Mode == "Combo" or Mode == "Harass") and IsReady(_Q) then
		args.Process = false
	end
end

function zgNilah:Combo()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and GetDistance(myHero.pos, target.pos) <= self.ESpell.Range and target.health/target.maxHealth <= Menu.Combo.ETHP:Value()/100 then
			if Menu.Combo.Eammo:Value() then
				if myHero:GetSpellData(_E).ammo > 1 then
					Control.CastSpell(HK_E, target)
				end
			else
				if myHero:GetSpellData(_E).ammo > 0 then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) and GetEnemyCount(self.RSpell.Range-50, myHero.pos) >= Menu.Combo.RCount:Value() then
		Control.CastSpell(HK_R)
	end
end

function zgNilah:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) then	
		if Menu.Harass.Q:Value() and IsReady(_Q) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 ]]then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgNilah:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgNilah:AutoW()
	if Menu.Auto.W:Value() and IsReady(_W) then
		for i, hero in pairs(ObjectManager:GetEnemyHeroes()) do
			if IsValid(hero) and hero.activeSpell.isAutoAttack then
				if hero.activeSpell.target == myHero.handle and myHero.health/myHero.maxHealth <= Menu.Auto.WHP:Value()/100 then
					Control.CastSpell(HK_W)
				end
			end
		end
	end
end

function zgNilah:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.pos2D.onScreen and minion.team ~= 300 then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
					end
				end
			end
		end
	end
end

function zgNilah:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgNilah:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local AARange = myHero.range + myHero.boundingRadius + minion.boundingRadius
				local QDmg = self:GetQDmg(minion)
				if QDmg >= HealthPrediction:GetPrediction(minion, self.QSpell.Delay) and GetDistance(myHero.pos, minion.pos) > AARange then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgNilah:QBuildings()
	if Menu.Clear.QT:Value() and IsReady(_Q) then
		local turrets = ObjectManager:GetEnemyTurrets(self.QSpell.Range)
		for i, turret in ipairs(turrets) do
			if turret then
				Control.CastSpell(HK_Q, turret)
			end
		end
		local buildings = ObjectManager:GetEnemyBuildings(self.QSpell.Range+250)
		for i, building in ipairs(buildings) do
			if building and building.type == Obj_AI_Barracks then
				Control.CastSpell(HK_Q, building)
			end
		end
		local buildings = ObjectManager:GetEnemyBuildings(self.QSpell.Range+350)
		for i, building in ipairs(buildings) do
			if building and building.type == Obj_AI_Nexus then
				Control.CastSpell(HK_Q, building)
			end
		end
	end
end
	
function zgNilah:KillSteal()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) then
		local QDmg = self:GetQDmg(target)
		local EDmg = self:GetEDmg(target)		
		if IsReady(_Q) and Menu.KS.Q:Value() then
			if QDmg > target.health and GetDistance(myHero.pos, target.pos) <= self.QSpell.Range then
				self:CastGGPred(HK_Q, target)
			end	
		end
		if IsReady(_E) and Menu.KS.E:Value() and not IsReady(_Q) then 
			if target.health <= EDmg and GetDistance(myHero.pos, target.pos) <= self.ESpell.Range then
				Control.CastSpell(HK_E, target)	
			end	
		end
	end
end

function zgNilah:GetQDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 5 * qlvl
	local qadDmg = myHero.totalDamage * (0.05 *qlvl + 0.85 )
	local qDmg = qbaseDmg * (myHero.critChance + 1) + qadDmg * (myHero.critChance + 1)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
end

function zgNilah:GetEDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 50 + elvl * 10
	local eadDmg = myHero.bonusDamage * 0.2
	local eDmg = ebaseDmg + eadDmg
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg)
end

function zgNilah:GetFleeETarget()
	local bestTarget = nil
	local potentialTargets = {}
	for _, hero in ipairs(ObjectManager:GetHeroes()) do
		if IsValid(hero) and not hero.isMe then
			TableInsert(potentialTargets, hero)
		end
	end
	for _, minion in ipairs(ObjectManager:GetMinions()) do
		if IsValid(minion) and minion.maxHealth ~= 1 then
			TableInsert(potentialTargets, minion)
		end
	end
	for _, target in ipairs(potentialTargets) do
		if IsValid(target) then
			local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(target.pos, myHero.pos, mousePos)
			if isOnSegment then
				bestTarget = target
			end
		end
	end
	return bestTarget
end

function zgNilah:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 1000 < GetTickCount() then
		local FleeETarget = self:GetFleeETarget()
		if IsValid(FleeETarget) and FleeETarget.distance <= self.ESpell.Range then
			Control.CastSpell(HK_E, FleeETarget)
			lastE = GetTickCount()
		end
	end
end

function zgNilah:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function zgNilah:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q)then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E)then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R)then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

--------------------------------------

class "zgSmolder"

function zgSmolder:__init()
	print("Marksmen Smolder Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = { Delay = 0.25, Range = 550, Speed = 1800}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 115, Range = 1200, Speed = 2000, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Radius = 300, Range = 3650, Speed = 1700, Collision = false}
end

function zgSmolder:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RHp", name = "Use R| Self Hp <= x%", value = 50, min = 0, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| Aoe Hit Count >= x", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RRange", name = "Max R Range", value = 2600, min = 1500, max = 3650, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q(Clear/Harass/LastHit Modes)", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E to mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Q", name = "Q priority AA in combat", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Wcc", name = "Auto W on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "E", name = "No cast other spells while E flight", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rmin", name = "Draw R Range on minimap", toggle = true, value = false})
end

function zgSmolder:OnPreAttack(args)
	local target = args.Target
	local Mode = GetMode()
	if HaveBuff(myHero, "SmolderE") then
		args.Process = false
		return
	end
	if target and target.type == Obj_AI_Hero then
		if Menu.Misc.Q:Value() and IsReady(_Q) then
			args.Process = false
		end
		return
	end
	if target and target.type == Obj_AI_Minion then
		if (Mode == "LaneClear" or Mode == "Harass" or Mode == "LastHit") then
			local QTotalDmg = self:GetQDmg(target) + self:GetPQDmg(target)
			if IsReady(_Q) and target.health < QTotalDmg and target.maxHealth > 8 then
				args.Process = false
			end
		end
	end
end

function zgSmolder:Tick()
	self.QSpell.Range = myHero.range + myHero.boundingRadius * 2
	if ShouldWait() then
		return
	end
	
	if IsCasting() then return end
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
	
	if Menu.Misc.E:Value() and HaveBuff(myHero, "SmolderE") then return end

	self:Auto()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LastHit()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

--[[function zgSmolder:OnPostAttack()
	if GetMode() == "Combo" then
		local target = Orbwalker:GetTarget()
		if IsValid(target) and target.type == Obj_AI_Hero then
			if Menu.Combo.Q:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
	if GetMode() == "LaneClear" then
		local target = Orbwalker:GetTarget()
		if IsValid(target) and target.type == Obj_AI_Minion and target.team == 300 then
			if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end
	end
end]]

function zgSmolder:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E)
	end
end

function zgSmolder:OneKeyCastR()
	local Rtarget = GetTarget(Menu.Combo.RRange:Value())
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		self:CastGGPred(HK_R, Rtarget)
	end
end

function zgSmolder:Auto()	
	if Menu.Misc.Wcc:Value() and IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsImmobile(target) then
				self:CastGGPred(HK_W, target)
			end
		end
	end
end

function zgSmolder:Combo()
	local Wtarget = GetTarget(self.WSpell.Range)
	if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
		if Menu.Combo.W:Value() and IsReady(_W) then
			self:CastGGPred(HK_W, Wtarget)	
		end
	end

	local Qtarget = GetTarget(self.QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			-- self:QLogic(target, Menu.Combo.Q2:Value())
			Control.CastSpell(HK_Q, Qtarget)
		end
	end

	local Rtarget = GetTarget(Menu.Combo.RRange:Value())
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		if Menu.Combo.R:Value() and IsReady(_R) then
			if myHero.health/myHero.maxHealth < Menu.Combo.RHp:Value()/100 and myHero.pos:DistanceTo(Rtarget.pos) < self.WSpell.Range then
				self:CastGGPred(HK_R, Rtarget)
			else
				local minHitCount = Menu.Combo.RCount:Value()
				local source = myHero.pos:Extended(Rtarget.pos, -600)
				CastSpellAOE(HK_R, self.RSpell, minHitCount, source)
			end
		end
	end
end

function zgSmolder:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local Wtarget = GetTarget(self.WSpell.Range)
		if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
			if Menu.Harass.W:Value() and IsReady(_W) then
				self:CastGGPred(HK_W, Wtarget)
			end
		end

		local Qtarget = GetTarget(self.QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				-- self:QLogic(target, Menu.Harass.Q2:Value())
				Control.CastSpell(HK_Q, Qtarget)
			end
		end
	-- end
end

function zgSmolder:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgSmolder:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level > 0 then
		local QDmg = (({65, 80, 95, 110, 125})[level] + 1.3 * myHero.bonusDamage) * (1 + 0.75 * myHero.critChance)
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
	else
		return 0
	end
end

function zgSmolder:GetPQDmg(target)
	local buff, buffData = GetBuffData(myHero, "SmolderQPassive")
	if buff then
		local Dmg = (0.4 * (1 + 0.75 * myHero.critChance)) * buffData.stacks
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
	else
		return 0
	end
end

function zgSmolder:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local QTotalDmg = self:GetQDmg(minion) + self:GetPQDmg(minion)
				local hp = HealthPrediction:GetPrediction(minion, self.QSpell.Delay + myHero.pos:DistanceTo(minion.pos)/self.QSpell.Speed)
				if QTotalDmg > hp then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgSmolder:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(self.WSpell.Range)
			TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgSmolder:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(self.WSpell.Range)
			TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgSmolder:CastGGPred(spell, target)
	if spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		local source = myHero.pos:Extended(target.pos, -600)
		RPrediction:GetPrediction(target, source)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end	
	end
end

function zgSmolder:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 1500, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
	if Menu.Draw.Rmin:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, self.RSpell.Range, 1, Draw.Color(200, 14, 194, 255))
	end
end

-----------------------------------------

class "zgZeri"

function zgZeri:__init()
	require "MapPositionGOS"
	print("Marksmen Zeri Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.237, Radius = 40, Range = 750, Speed = 2600, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 40, Range = 1150, Speed = 2500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 100, Range = 2500, Speed = 2500, Collision = false}
	self.ESpell = { Range = 300 }
	self.RSpell = { Delay = 0.25, Range = 825 }
end

function zgZeri:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W | No QRange or Through Wall", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Wwall", name = "Use W | Only Through Wall", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| Aoe Hit Count >= x", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "QHarass", name = "Use Q Harass(In LaneClear Mode)", toggle = true, value = true})
	Menu.Clear:MenuElement({id = "QBuildings", name = "Use Q on Buildings", toggle = true, value = true})
	Menu.Clear:MenuElement({id = "QWards", name = "Use Q on Wards", toggle = true, value = true})
	Menu.Clear:MenuElement({id = "QPlants", name = "Use Q on Plants", toggle = true, value = false})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q(Clear/Harass/LastHit Modes)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QhitChance", name = "Q | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "QRange", name = "Q Range = RealRange + X", value = 0, min = -50, max = 50, step = 5})
	Menu.Misc:MenuElement({id = "QBarrel", name = "Q Attack GP's Barrel", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "ComboAA", name = "Disable AA when no Qpassive in combo", toggle = true, value = true, key = string.byte("T")})
	Menu.Misc:MenuElement({id = "ClearAA", name = "Disable AA when in Clear(Mouse Scroll)", toggle = true, value = true, key = 4})	

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "ComboAA", name = "Draw Combo AA Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "ClearAA", name = "Draw Clear AA Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgZeri:OnPreAttack(args)
	local Mode = GetMode()
	local target = args.Target 
	if Mode == "Combo" then
		local AADamage = Damage:GetAutoAttackDamage(myHero, target)
		if Menu.Misc.ComboAA:Value() and not HaveBuff(myHero, "ZeriQPassiveReady") and target.health > AADamage then
			args.Process = false
		else
			args.Process = true
		end
	end

	if Mode == "LaneClear" and target.type == Obj_AI_Minion then
		local AADamage = Damage:GetAutoAttackDamage(myHero, target)
		if Menu.Misc.ClearAA:Value() then
			args.Process = false
			if target.maxHealth <= 8 then
				args.Process = true
			end
			if IsValid(target) and target.health < AADamage and Data:IsInAutoAttackRange(myHero, target) then
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount > 0 or not IsReady(_Q) then
					args.Process = true
				end
			end
		else
			args.Process = true
		end
	end
end

function zgZeri:Tick()
	self.QSpell.Delay = myHero.attackData.windUpTime
	if myHero.range == 650 then
		self.QSpell.Range = 900 + Menu.Misc.QRange:Value()
	else
		self.QSpell.Range = 750 + Menu.Misc.QRange:Value()
	end

	if HaveBuff(myHero, "ZeriR") then
		self.QSpell.Speed = 3400
	else
		self.QSpell.Speed = 2600
	end

	self.WSpell.Delay = MathMax(MathFloor((0.55 - 0.09 * (myHero.attackSpeed - 1)) * 100) / 100, 0.3)
	self.W2Spell.Delay = self.WSpell.Delay
	
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:QBarrel()
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:QBarrel()
		self:FarmHarass()
		self:LastHit()
		self:QObject()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	end
end

function zgZeri:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * self.ESpell.Range
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function zgZeri:QBarrel()
	if not Menu.Misc.QBarrel:Value() or not IsReady(_Q) then
		return
	end

	local enemyHeroes = ObjectManager:GetEnemyHeroes()
	local gangplank = nil

	for _, enemy in ipairs(enemyHeroes) do
		if enemy and enemy.charName == "Gangplank" then
			gangplank = enemy
			break
		end
	end

	if not gangplank then
		return
	end

	local plants = ObjectManager:GetPlants(750)
	local level = gangplank.levelData.lvl
	local healthDecayRate = level >= 13 and 0.5 or (level >= 7 and 1 or 2)
	local currentTime = GameTimer()

	for _, obj in ipairs(plants) do
		if obj and obj.charName:lower() == "gangplankbarrel" then
			local barrelHealth = obj.health
			local barrelBuff, barrelBuffData = GetBuffData(obj, "gangplankebarrelactive")
			local barrelBuffStartTime = barrelBuff and barrelBuffData.startTime or 0
			local time = obj.distance / self.QSpell.Speed

			if barrelHealth <= 1 then
				Control.CastSpell(HK_Q, obj)
			elseif barrelHealth <= 2 then
				if Data:IsInAutoAttackRange(myHero, obj) then
					Control.CastSpell(HK_Q, obj)
				else
					local nextHealthDecayTime = currentTime < barrelBuffStartTime + healthDecayRate and barrelBuffStartTime + healthDecayRate or barrelBuffStartTime + healthDecayRate * 2
					if nextHealthDecayTime <= currentTime + time then
						Control.CastSpell(HK_Q, obj)
					end
				end
			end
		end
	end
end

function zgZeri:Combo()
	local Etarget = GetTarget(self.ESpell.Range + self.QSpell.Range - 50)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, Etarget)
		end
	end

	local Qtarget = GetTarget(self.QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
			QPrediction:GetPrediction(Qtarget, myHero)
			if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	end

	local Wtarget = GetTarget(self.W2Spell.Range)
	if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
		if Menu.Combo.W:Value() and IsReady(_W) then
			if myHero.pos:DistanceTo(Wtarget.pos) > self.QSpell.Range and GetEnemyCount(self.QSpell.Range, myHero.pos) == 0 then
				self:CastW(Wtarget)
			end
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local Count = 0
		for i, enemy in ipairs(ObjectManager:GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(MathHuge, self.RSpell.Delay)
				if myHero.pos:DistanceTo(enemyPred) < self.RSpell.Range - 50 then
					Count = Count + 1
				end
			end
		end
		
		if Count >= Menu.Combo.RCount:Value() then
			Control.CastSpell(HK_R)
		end
	end
end

function zgZeri:CastW(target)
	local pred = GGPrediction:SpellPrediction(self.W2Spell)
	pred:GetPrediction(target, myHero)
	if not pred:CanHit(Menu.Misc.WhitChance:Value() + 1) then return end
		
	local predPos = Vector(pred.UnitPosition)
	local castPos = Vector(pred.CastPosition)
	local wallColPos = FindFirstWallCollisionInRectangle(myHero.pos, predPos, self.WSpell.Radius)

	if wallColPos and myHero.pos:DistanceTo(wallColPos) < self.WSpell.Range and wallColPos:DistanceTo(castPos) < 1400 then
		local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, wallColPos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
		if collisionCount == 0 then
			Control.CastSpell(HK_W, castPos)
		end
	elseif not Menu.Combo.Wwall:Value() then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	end
end

function zgZeri:Harass()
	local Qtarget = GetTarget(self.QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
			QPrediction:GetPrediction(Qtarget, myHero)
			if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	end
end

function zgZeri:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.QHarass:Value() then
		self:Harass()
	end
end

function zgZeri:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local baseDmg = {15, 17, 19, 21, 23}
	local bonusDmg = {1.04, 1.08, 1.12, 1.16, 1.2}
	local QDmg = baseDmg[level] + bonusDmg[level] * myHero.totalDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgZeri:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local Hp = HealthPrediction:GetPrediction(minion, myHero.pos:DistanceTo(minion.pos) / self.QSpell.Speed)
				local QDmg = self:GetQDmg(minion)
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
				if QDmg > Hp and collisionCount == 0 then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgZeri:LaneClear()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		--TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgZeri:JungleClear()
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgZeri:QObject()
	if not IsReady(_Q) then return end

	local QRange = 750
	local targets = {}

	if Menu.Clear.QBuildings:Value() then
		local turrets = ObjectManager:GetEnemyTurrets(QRange)
		local buildings = ObjectManager:GetEnemyBuildings(QRange + 350)

		for i = 1, #turrets do
			local turret = turrets[i]
			if turret then
				TableInsert(targets, turret)
			end
		end

		for i = 1, #buildings do
			local building = buildings[i]
			if building and (building.type == Obj_AI_Nexus or (building.type == Obj_AI_Barracks and building.distance < QRange + 250)) then
				TableInsert(targets, building)
			end
		end
	end

	if Menu.Clear.QWards:Value() then
		local wards = ObjectManager:GetOtherEnemyMinions(QRange)
		for i = 1, #wards do
			local ward = wards[i]
			if ward then
				TableInsert(targets, ward)
			end
		end
	 end

	local plants = ObjectManager:GetPlants(QRange)
	for i = 1, #plants do
		local plant = plants[i]
		if plant then
			local objName = plant.charName:lower()
			if objName ~= "sennasoul" and objName ~= "gangplankbarrel" then
				if Menu.Clear.QPlants:Value() or plant.team ~= 300 or objName == "sru_plant_demon" then
					TableInsert(targets, plant)
				end
			end
		end
	end

	if #targets > 0 then
		Control.CastSpell(HK_Q, targets[1])
	end
end

function zgZeri:Draw()
	if myHero.dead then return end

	if Menu.Draw.ComboAA:Value() then
		if not Menu.Misc.ComboAA:Value() then
			Draw.Text("Combo AA: On", 16, myHero.pos2D.x-47, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Combo AA: Off", 16, myHero.pos2D.x-47, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.ClearAA:Value() then
		if not Menu.Misc.ClearAA:Value() then
			Draw.Text("Clear AA: On", 16, myHero.pos2D.x-37, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Clear AA: Off", 16, myHero.pos2D.x-37, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, self.QSpell.Range, 0.5, Draw.Color(255, 66, 244, 113))
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

-----------------------------------------

class "zgLucian"

function zgLucian:__init()
	require "MapPositionGOS"
	print("Marksmen Lucian Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 500, Speed = MathHuge, Collision = false}
	self.Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 1100, Speed = MathHuge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 1000, Speed = 1600, Collision = false}
	self.ESpell = { Range = 425 }
	self.RSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 110, Range = 1200, Speed = 2800, Collision = false }
end

function zgLucian:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Combo:MenuElement({id = "EsafeCheck", name = "E-dash Point Safe Check", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "enemyCheck", name = "Block E-dash in X enemies", value = 3, min = 0, max = 5, step = 1})	
	Menu.Combo:MenuElement({id = "Echeck", name = "Block E-dash inWall / underTurret", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Edis", name = "Use E | To Side - hold distance", value = 550, min = 300, max = 650, step = 50})
	Menu.Combo:MenuElement({id = "Priority", name = "Combo Abilities Priority",	value = 1, drop = {"Q-W-E", "W-Q-E", "E-Q-W", "E-W-Q"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Clear.JungleClear:MenuElement({id = "Priority", name = "JungleClear Abilities Priority", value = 3, drop = {"Q-W-E", "W-Q-E", "E-Q-W"}})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QhitChance", name = "Q | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgLucian:Tick()
	self.QSpell.Delay = 0.4 - 0.15 / 17 * (myHero.levelData.lvl - 1)
	self.Q2Spell.Delay = self.QSpell.Delay
	if self:CastingR() then
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetAttack(true)
	end
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	if lastQ + self.QSpell.Delay * 2 > GameTimer() then return end
	if IsCasting() or self:HavePassive() or self:Dashing() or self:CastingR() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function zgLucian:CastingR()
	return HaveBuff(myHero, "LucianR")
end
function zgLucian:Dashing()
	return myHero.pathing.isDashing and myHero.pathing.dashSpeed > 0
end
function zgLucian:HavePassive()
	return HaveBuff(myHero, "LucianPassiveBuff")
end
function zgLucian:EToSideHoldDis()
	local Edis = Menu.Combo.Edis:Value()
	return myHero.range == 650 and Edis + 150 or Edis
end

function zgLucian:Combo()
	local target = GetTarget(self.Q2Spell.Range)
	if IsValid(target) then
		local eCastSuccess = false
		if Menu.Combo.Priority:Value() == 1 then
			if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = GameTimer()
			end
			if not Menu.Combo.Q:Value() or not IsReady(_Q) then
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
				if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
					eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
				end
			end
		end

		if Menu.Combo.Priority:Value() == 2 then
			if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				self:CastW(target)
			end
			if not Menu.Combo.W:Value() or not IsReady(_W) then
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					Control.CastSpell(HK_Q, target)
					lastQ = GameTimer()
				end
				if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
					eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
				end
			end
		end

		if Menu.Combo.Priority:Value() == 3 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
				eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
			if not Menu.Combo.E:Value() or not IsReady(_E) or not eCastSuccess then
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					Control.CastSpell(HK_Q, target)
					lastQ = GameTimer()
				end
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
			end
		end

		if Menu.Combo.Priority:Value() == 4 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
				eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
			if not Menu.Combo.E:Value() or not IsReady(_E) or not eCastSuccess then
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					Control.CastSpell(HK_Q, target)
					lastQ = GameTimer()
				end
			end
		end

		if Menu.Combo.QExt:Value() and IsReady(_Q) then 
			self:CastQExt(target)
		end
	end	
end

function zgLucian:CastERange(target)
	local range = myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() and 200 or 425
	return range
end

function zgLucian:CastE(target, mode, range)
	local castPos = nil
	if mode == 1 then
		--local targetPred = target:GetPrediction(MathHuge, 0.25)
		local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, self.ESpell.Range, self:EToSideHoldDis())
		if intPos1 and intPos2 then
			local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
			if IsFacingMe(target) then
				castPos = myHero.pos:Extended(closest, range)
			else
				castPos = myHero.pos:Extended(target.pos, range)
			end
		end
	elseif mode == 2 then 
		castPos = myHero.pos:Extended(mousePos, range)
	elseif mode == 3 then 
		castPos = myHero.pos:Extended(target.pos, range)
	end
	
	if castPos ~= nil then
		local underTurret = IsUnderTurret2(castPos)
		local inWall = MapPosition:inWall(castPos) -- GameIsWall(castPos)
		local enemyCheck = Menu.Combo.enemyCheck:Value()
		local enemyCount = GetEnemyCount(600, castPos)

		if Menu.Combo.Echeck:Value() and (underTurret or inWall) then return false end
		if Menu.Combo.EsafeCheck:Value() and enemyCount >= enemyCheck then return false end

		Control.CastSpell(HK_E, castPos)
		return true
	end
	return false
end

function zgLucian:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, WPrediction.CastPosition, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount == 0 or Data:IsInAutoAttackRange(myHero, target) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	end
end

function zgLucian:CastQExt(target)
	local pred = GGPrediction:SpellPrediction(self.Q2Spell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(Menu.Misc.QhitChance:Value() + 1) then
		local predPos = Vector(pred.CastPosition)
		
		local targetPos = myHero.pos:Extended(predPos, GetDistance(myHero.pos, predPos))

		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		
		local objTable = {}
		for i = 1, #minions do
			local minion = minions[i]
			TableInsert(objTable, minion)
		end
		for i = 1, #enemies do
			local enemy = enemies[i]
			if enemy.networkID ~= target.networkID then
				TableInsert(objTable, enemy)
			end
		end

		for i = 1, #objTable do
			local obj = objTable[i]
			local objPos = myHero.pos:Extended(obj.pos, GetDistance(myHero.pos, predPos))
			if GetDistance(targetPos, objPos) < (self.Q2Spell.Radius/2 + target.boundingRadius) then
				Control.CastSpell(HK_Q, obj.pos)
				lastQ = GameTimer()
			end
		end
	end
end

function zgLucian:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) then
			if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = GameTimer()
			end
			if Menu.Harass.QExt:Value() and IsReady(_Q) then 
				self:CastQExt(target)
			end
			if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				self:CastW(target)
			end
		end
	-- end
end

function zgLucian:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgLucian:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.Q2Spell.Range)
		TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						local hitCount = 1
						for j, otherMinion in ipairs(minions) do
							if IsValid(otherMinion) and otherMinion.networkID ~= minion.networkID then
								local endPos = myHero.pos:Extended(minion.pos, self.Q2Spell.Range)
								local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(otherMinion.pos, minion.pos, endPos)
								local width = self.Q2Spell.Radius/2 + otherMinion.boundingRadius
								if isOnSegment and GGPrediction:IsInRange(point, otherMinion.pos, width) then
									hitCount = hitCount + 1
								end
							end
						end
						if hitCount >= Menu.Clear.LaneClear.QCount:Value() then
							Control.CastSpell(HK_Q, minion)
							lastQ = GameTimer()
						end
					end
				end

				if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
					if Data:IsInAutoAttackRange(myHero, minion) and GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgLucian:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.WSpell.Range)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Priority:Value() == 1 then
					if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = GameTimer()
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 2 then
					if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = GameTimer()
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 3 then
					if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = GameTimer()
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgLucian:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then -- Data:GetAutoAttackRange(myHero, target)
					--local castPos = Vector(myHero.pos) + (Vector(target.pathing.endPos) - Vector(target.pathing.startPos)):Normalized() * self.ESpell.Range
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * self.ESpell.Range
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function zgLucian:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
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

-----------------------------------------

class "zgJinx"

function zgJinx:__init()
	print("Marksmen Jinx Loaded") 
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = { Range = 525 }
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 60, Range = 1450, Speed = 3300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 115, Range = 925, Speed = MathHuge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 140, Range = 25000, Speed = 1700, Collision = false}
end

function zgJinx:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "EhitChance", name = "E | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "RhitChance", name = "R | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "Ecc", name = "Auto E On 'CC'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Etp", name = "Auto E On 'TP'", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "Rmin", name = "Use R| MinRange >= X", value = 1000, min = 500, max = 2500, step = 100})
	Menu.Misc:MenuElement({id = "Rmax", name = "Use R| MaxRange <= X", value = 3000, min = 1500, max = 3500, step = 100})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function zgJinx:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) then
		if GetMode() == "LaneClear" and IsReady(_Q) and not IsCasting() then
			if target.type == Obj_AI_Minion then
				if Menu.Clear.SpellFarm:Value() then
					if target.team ~= 300 and Menu.Clear.LaneClear.Q:Value() then
						-- if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 then
							if GetMinionCount(300, target.pos) >= Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(300, target.pos) < Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						-- else
							-- if HaveBuff(myHero, "JinxQ") then
								-- Control.CastSpell(HK_Q)
							-- end
						-- end
					end
					if target.team == 300 and Menu.Clear.JungleClear.Q:Value() then
						-- if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 then
							if GetMinionCount(300, target.pos) >= 2 and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(300, target.pos) < 2 and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						-- else
							-- if HaveBuff(myHero, "JinxQ") then
								-- Control.CastSpell(HK_Q)
							-- end
						-- end
					end
				end
			elseif target.type == Obj_AI_Nexus or target.type == Obj_AI_Barracks or target.type == Obj_AI_Turret then
				if myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgJinx:Tick()
	self.WSpell.Delay = MathMax(MathFloor((0.6 - 0.02 * ((myHero.attackSpeed - 1)/0.25)) * 100) / 100, 0.4)
	
	if ShouldWait() then
		return
	end
	if IsCasting() then return end

	self:AutoE()
	self:SemiR()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
		self:ComboQ()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		--self:LaneClear()
		self:JungleClear()
	end
end

function zgJinx:Combo()
	local target = GetTarget(self.WSpell.Range)
	if IsValid(target) then
		if Menu.Combo.W:Value() and IsReady(_W) then
			if myHero.pos:DistanceTo(target.pos) > Data:GetAutoAttackRange(myHero, target) then
				self:CastW(target)
			end
		end
		if Menu.Combo.E:Value() and IsReady(_E) then
			if myHero.pos:DistanceTo(target.pos) < self.ESpell.Range then
				self:CastE(target)
			end
		end
	end
end

function zgJinx:ComboQ()	
	local target = GetTarget(900)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			if myHero.pos:DistanceTo(target.pos) > self:QbaseRange(target) and HaveBuff(myHero, "jinxqicon") then
				if myHero.pos:DistanceTo(target.pos) <= self:QmaxRange(target) then
					Control.CastSpell(HK_Q)
				end
			elseif myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
				Control.CastSpell(HK_Q)
			end
		end
	elseif HaveBuff(myHero, "JinxQ") and GetEnemyCount(1500, myHero.pos) == 0 and IsReady(_Q) then
		Control.CastSpell(HK_Q)
	end
end

function zgJinx:QbaseRange(unit)
	return self.QSpell.Range + myHero.boundingRadius + unit.boundingRadius
end

function zgJinx:QmaxRange(unit)
	local level = myHero:GetSpellData(_Q).level
	return self.QSpell.Range + myHero.boundingRadius + unit.boundingRadius + ({100, 125, 150, 175, 200})[level]
end

function zgJinx:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgJinx:CastE(target)
	local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
	EPrediction:GetPrediction(target, myHero)
	if EPrediction:CanHit(Menu.Misc.EhitChance:Value() + 1) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function zgJinx:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(Menu.Misc.RhitChance:Value() + 1) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgJinx:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) > self:QmaxRange(target) then
				self:CastW(target)
			end
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				if myHero.pos:DistanceTo(target.pos) <= self:QmaxRange(target) then
					if myHero.pos:DistanceTo(target.pos) > self:QbaseRange(target) and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	-- end
end

function zgJinx:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

--[[ function zgJinx:LaneClear()
	if IsUnderTurret(myHero) then return end
	if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range + 130)
			TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if GetMinionCount(250, minion.pos) < Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
					if minion.health < Damage:GetAutoAttackDamage(myHero, minion) then
						if myHero.pos:DistanceTo(minion.pos) > self:QbaseRange() and HaveBuff(myHero, "jinxqicon") then
							Control.CastSpell(HK_Q)
						end
					end
				else
					if HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end ]]

function zgJinx:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range + 130)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_W, minion)
					end
				end
				--[[ if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(250, minion.pos) >= 2 and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if GetMinionCount(250, minion.pos) < 2 and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			else
				if HaveBuff(myHero, "JinxQ") then
					Control.CastSpell(HK_Q)
				end ]]
			end
		end
	end
end

local lastParticleCheckTime = 0
local particleCheckInterval = 1.0
function zgJinx:AutoE()
	if Menu.Misc.Ecc:Value() and IsReady(_E) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then
				if
					GetImmobileDuration(target) > 0.5 --cc
					or IsInvulnerable(target) --zhonya
					or HaveBuff(target, "LissandraRSelf")
					or HaveBuff(target, "Meditate") --yi w
					or HaveBuff(target, "ChronoRevive") --zilean r
				then
					Control.CastSpell(HK_E, target)
				end

				for j, slot in ipairs(slots) do
					local Data = target:GetSpellData(slot)
					if Data.name == "GuardianAngel" and Data.currentCd == 0 and not target.alive then --G A
						Control.CastSpell(HK_E, target)
					end
				end
			end
		end
	end
	
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_E, target.pathing.endPos)
				end
			end	
		end
	end

	if Menu.Misc.Etp:Value() and IsReady(_E) then
		local now = GetTickCount() / 1000
		if now - lastParticleCheckTime > particleCheckInterval then
			lastParticleCheckTime = now
			for i = GameParticleCount(), 1, -1 do
				local par = GameParticle(i)
				if
					par and par.pos:DistanceTo(myHero.pos) <= self.ESpell.Range
					and ((par.name:lower():find("teledash_end") and par.name:lower():find("wardenemy")) or par.name:lower():find("gatemarker_red")) -- TP or TF-R
				then
					Control.CastSpell(HK_E, par)
					break
				end
			end
		end
	end
end

function zgJinx:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(Menu.Misc.Rmax:Value())
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function zgJinx:KillSteal()
	local enemies = ObjectManager:GetEnemyHeroes(Menu.Misc.Rmax:Value())
	for i, enemy in ipairs(enemies) do
		if enemy and not enemy.dead and enemy.pos2D.onScreen then
			if Menu.KillSteal.W:Value() and IsReady(_W) and lastR + 1500 < GetTickCount() then
				local Wdmg = self:GetWDmg(enemy)
				if Wdmg >= enemy.health + enemy.hpRegen * 1 then
					if myHero.pos:DistanceTo(enemy.pos) < self.WSpell.Range then
						if myHero.pos:DistanceTo(enemy.pos) > Data:GetAutoAttackRange(myHero, enemy) then 
							self:CastW(enemy)
							lastW = GetTickCount()
						end	
					end
				end
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and lastW + 1500 < GetTickCount() then
				local Rdmg = self:GetRDmg(enemy)
				local IsSionPassive = HaveBuff(enemy, "sionpassivezombie")
				if not IsSionPassive and Rdmg >= enemy.health + enemy.hpRegen * 2 and myHero.pos:DistanceTo(enemy.pos) >= Menu.Misc.Rmin:Value() then
					self:CastR(enemy)
					lastR = GetTickCount()
				end
			end
		end
	end
end

function zgJinx:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({10, 60, 110, 160, 210})[level] + 1.4 * myHero.totalDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
end

function zgJinx:GetRDmg(target)
	local d = target.pos:DistanceTo(myHero.pos)
	local level = myHero:GetSpellData(_R).level
	local RDmg = (({250, 400, 550})[level] + 1.3 * myHero.bonusDamage) * (0.06 * MathMin(MathFloor(d/100), 15) + 0.1) + ({0.25, 0.3, 0.35})[level] * (target.maxHealth - target.health)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, RDmg)
end

function zgJinx:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

-----------------------------------------

class "zgTristana"

function zgTristana:__init()
	print("Marksmen Tristana Loaded") 
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
end

function zgTristana:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q| Near Minion Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E On Turret", toggle = true, value = true})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal(E+R calculation)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "ForceE", name = "Focus target with E", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Rgap", name = "Auto R Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "RgapRange", name = "AntiGap R Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
end

function zgTristana:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and target.type == Obj_AI_Hero then
		if GetMode() == "Combo" then
			if Menu.Combo.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E, target)
			end
		end
		if GetMode() == "Harass" then
			-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
				if Menu.Harass.E:Value() and IsReady(_E) then
					Control.CastSpell(HK_E, target)
				end
			-- end
		end
		if GetMode() == "LaneClear" then
			-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
				if Menu.Clear.SpellHarass:Value() and Menu.Harass.E:Value() and IsReady(_E) then
					Control.CastSpell(HK_E, target)
				end
			-- end
		end
	end

	if target and target.type == Obj_AI_Turret then
		if GetMode() == "LaneClear" then
			if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgTristana:OnPostAttack()
	local target = Orbwalker:GetTarget()
	if IsValid(target) and target.type == Obj_AI_Hero then
		if GetMode() == "Combo" then
			if Menu.Combo.Q:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q)
			end
		end
	end
	if IsValid(target) and target.type == Obj_AI_Minion and target.team ~= 300 then
		if GetMode() == "LaneClear" then
			if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and GetMinionCount(700, myHero.pos) >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgTristana:Tick()

	AAERRange = 550 + (150 / 17 * (myHero.levelData.lvl - 1)) + myHero.boundingRadius
	--E.Delay = myHero.attackData.windUpTime
	
	self:ForceE()

	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AntiGapcloser()
	self:SemiR()
	self:KillSteal()

	if GetMode() == "LaneClear" then
		self:JungleClear()
	end
end

function zgTristana:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(AAERRange)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_E, minion)
					end
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgTristana:ForceE()
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Misc.ForceE:Value() and HaveBuff(enemy, "tristanaechargesound") and myHero.pos:DistanceTo(enemy.pos) <= AAERRange + enemy.boundingRadius then
				Orbwalker.ForceTarget = enemy
				return
			end
		end
	end
	Orbwalker.ForceTarget = nil
end

function zgTristana:AntiGapcloser()
	if Menu.Misc.Rgap:Value() and IsReady(_R) then
		local enemies = ObjectManager:GetEnemyHeroes(1000)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < Menu.Misc.RgapRange:Value() and IsFacingMe(target) then
					Control.CastSpell(HK_R, target)
				end
			end	
		end
	end
end

function zgTristana:SemiR()
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	TableSort(enemies, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Misc.SemiR:Value() and IsReady(_R) and myHero.pos:DistanceTo(enemy.pos) <= AAERRange + enemy.boundingRadius then
				Control.CastSpell(HK_R, enemy)
			end
		end
	end
end

function zgTristana:KillSteal()
	local enemies = ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.KillSteal.R:Value() and IsReady(_R) and myHero.pos:DistanceTo(enemy.pos) <= AAERRange + enemy.boundingRadius then
				local Edmg = self:GetEDmg(enemy)
				local Rdmg = self:GetRDmg(enemy)
				local hasbuff = HaveBuff(enemy, "sionpassivezombie")
				if not hasbuff and Edmg + Rdmg > enemy.health and Edmg < enemy.health and enemy.health > Damage:GetAutoAttackDamage(myHero, enemy) then
					Control.CastSpell(HK_R, enemy)
				end
			end
		end
	end
end

function zgTristana:GetEDmg(unit)
	local Edmg = 0
	local hasbuff, buffData = GetBuffData(unit, "tristanaecharge")
	local hasIE = HasItem(myHero, 3031)

	if hasbuff then
		local EbaseDmg = ({60, 70, 80, 90, 100})[myHero:GetSpellData(_E).level]
		local Ead = myHero.bonusDamage * ({1.0, 1.1, 1.2, 1.3, 1.4})[myHero:GetSpellData(_E).level]
		local Eap = myHero.ap * 0.5
		local Evalue = (EbaseDmg + Ead+ Eap) * (buffData.count * 0.25 + 1) * (myHero.critChance * (hasIE and 1.15 or 0.75) + 1)
		Edmg = Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, Evalue)
	end
	return Edmg
end

function zgTristana:GetRDmg(unit)
	local baseDmg = ({225, 275, 325})[myHero:GetSpellData(_R).level]
	local bonusDmg = myHero.bonusDamage * 0.7 + myHero.ap * 1
	local Rvalue = baseDmg + bonusDmg
	local Rdmg = Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, Rvalue)
	return Rdmg
end

function zgTristana:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
end

--------------------------------------

class "zgMissFortune"

function zgMissFortune:__init()
	print("Marksmen MissFortune Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Delay = 0.25, Range = 550, Speed = 1400}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 200, Range = 1150, Speed = MathHuge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.375, Radius = 40, Range = 1350, Speed = 2000, Collision = false}
	-- LastAttackId = 0
end

function zgMissFortune:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 5, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qangle", name = "Bounce Q's Angle", value = 60, min = 60, max = 80, step = 5})
	-- Menu.Misc:MenuElement({id = "newTarget", name = "Try change focus after attack(Combo)", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "R", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgMissFortune:Tick()
	if ShouldWait() then
		return
	end

	self.QSpell.Range = myHero.range + myHero.boundingRadius*2
	self.QSpell.Delay = myHero.attackData.windUpTime

	if HaveBuff(myHero, "missfortunebulletsound") then
		Orbwalker:SetAttack(false)
		Orbwalker:SetMovement(false)
	else
		Orbwalker:SetAttack(true)
		Orbwalker:SetMovement(true)
	end
	
	-- self:newTarget()

	if IsCasting() then return end

	self:SemiRLogic()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function zgMissFortune:OnPreAttack(args)
	local target = args.Target
	-- local manaPercentage = myHero.mana / myHero.maxMana
	if GetMode() == "Combo" and IsValid(target) and target.type == Obj_AI_Hero then
		if Menu.Combo.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W)
		end
	end
	if GetMode() == "LaneClear" and IsValid(target) and target.type == Obj_AI_Minion then
		local isJungleMinion = target.team == 300
		local isLaneMinion = target.team ~= 300
		-- local minMana = isJungleMinion and Menu.Clear.JungleClear.Mana:Value() or Menu.Clear.LaneClear.Mana:Value()
		if --[[manaPercentage >= minMana / 100 and ]]Menu.Clear.SpellFarm:Value() then
			if (isJungleMinion and Menu.Clear.JungleClear.W:Value() or isLaneMinion and Menu.Clear.LaneClear.W:Value()) and IsReady(_W) then
				Control.CastSpell(HK_W)
			end
		end
	end
end

-- function zgMissFortune:OnPostAttack()
	-- local target = Orbwalker:GetTarget()
	-- if target then
		-- LastAttackId = target.networkID
	-- end
-- end

function zgMissFortune:SemiRLogic()
	if Menu.Misc.R:Value() and IsReady(_R) and lastR + 3000 < GetTickCount() then
		local Rtarget = GetTarget(self.RSpell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			Control.CastSpell(HK_R, Rtarget)
			lastR = GetTickCount()
		end
	end
end

function zgMissFortune:KillSteal()
	if Menu.KillSteal.Q:Value() and IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range+500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < self:GetQDmg(target) then
				self:QLogic(target, true)
			end
		end
	end
end

-- function zgMissFortune:newTarget()
	-- if Menu.Misc.newTarget:Value() and GetMode() == "Combo" then
		-- local orbT = Orbwalker:GetTarget()
		-- if IsValid(orbT) and orbT.type == Obj_AI_Hero and orbT.networkID == LastAttackId then
			-- if orbT.health > Damage:GetAutoAttackDamage(myHero, orbT) * 2 then
				-- local ta = nil
				-- local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)				--aarange == qrange
				-- for _, enemy in ipairs(enemies) do
					-- if IsValid(enemy) and enemy.networkID ~= LastAttackId then
						-- ta = enemy
						-- break
					-- end
				-- end
				-- if ta then
					-- Orbwalker.ForceTarget = ta
				-- else
					-- Orbwalker.ForceTarget = nil
				-- end
			-- else
				-- Orbwalker.ForceTarget = nil
			-- end
		-- end
	-- else
		-- Orbwalker.ForceTarget = nil
	-- end
	-- if Orbwalker.ForceTarget and not Data:IsInAutoAttackRange(myHero, Orbwalker.ForceTarget) then
		-- Orbwalker.ForceTarget = nil
	-- end
-- end

function zgMissFortune:Combo()
	if IsReady(_Q) then
		local Qtarget = GetTarget(self.QSpell.Range+500)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Combo.Q:Value() then
				self:QLogic(Qtarget, Menu.Combo.Q2:Value())
			end
		end
	end

	local Etarget = GetTarget(self.ESpell.Range)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and not Data:IsInAutoAttackRange(myHero, Etarget) then
			if myHero.mana > myHero:GetSpellData(_R).mana + myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_W).mana + myHero:GetSpellData(_E).mana then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	end
end

function zgMissFortune:Harass()
	--if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if IsReady(_Q) then
			local Qtarget = GetTarget(self.QSpell.Range+500)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
				if Menu.Harass.Q:Value() then
					self:QLogic(Qtarget, Menu.Harass.Q2:Value())
				end
			end
		end

		local Etarget = GetTarget(self.ESpell.Range)
		if IsValid(Etarget) and Etarget.pos2D.onScreen then
			if Menu.Harass.E:Value() and IsReady(_E) then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	--end
end

function zgMissFortune:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgMissFortune:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
		TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					if GetMinionCount(self.ESpell.Radius, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E, minion)
					end
				end
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if #minions > 2 and minions[1].pos:DistanceTo(myHero.pos) < self.QSpell.Range then
						Control.CastSpell(HK_Q, minions[1])
					end
				end
			end
		end
	end
end

function zgMissFortune:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_E, minion)
					else
						if GetMinionCount(self.ESpell.Radius, minion.pos) > 2 then
							Control.CastSpell(HK_E, minion)
						end
					end
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) < self.QSpell.Range then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgMissFortune:QLogic(target, UseQBounce)
	if target == nil then return end
	if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
	else
		if UseQBounce then
			local tarPred = target:GetPrediction(self.QSpell.Speed, self.QSpell.Delay)
			local bounceFirstTar = {}
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
			
			local objTable = {}
			for i = 1, #minions do
				local minion = minions[i]
				TableInsert(objTable, minion)
			end
			for i = 1, #enemies do
				local enemy = enemies[i]
				TableInsert(objTable, enemy)
			end
			
			for i = 1, #objTable do
				local obj = objTable[i]
				if IsValid(obj) and obj.networkID ~= target.networkID then
					local angle = Menu.Misc.Qangle:Value()/2
					local objPred = obj:GetPrediction(self.QSpell.Speed, self.QSpell.Delay)
					local middlePos = myHero.pos:Extended(objPred, myHero.pos:DistanceTo(objPred) + 500)
					local leftVector = (middlePos - objPred):Rotated(0, angle * MathPi / 180, 0)
					local rightVector = (middlePos - objPred):Rotated(0, -angle * MathPi / 180, 0)
					local targetVector = tarPred - objPred
					-- Method 1 -- EXT API: Vector:Angle(Vector) broken, so use Method 2
					-- local Angle1 = leftVector:Angle(rightVector)
					-- local Angle2 = leftVector:Angle(targetVector)
					-- local Angle3 = rightVector:Angle(targetVector)
					-- if objPred:DistanceTo(tarPred) < 420 and Angle2 < Angle1 and Angle3 < Angle1 then
					-- Method 2
					local dotLeft = targetVector:DotProduct(leftVector)
					local dotRight = targetVector:DotProduct(rightVector)
					local crossLeft = targetVector:CrossProduct(leftVector)
					local crossRight = rightVector:CrossProduct(targetVector)
					if objPred:DistanceTo(tarPred) < 420 and dotLeft > 0 and dotRight > 0 and crossLeft * crossRight > 0 then
						bounceFirstTar[#bounceFirstTar + 1] = {tar = obj, dis = objPred:DistanceTo(tarPred)}
					end
				end
			end

			if #bounceFirstTar > 0 then
				TableSort(bounceFirstTar, function(a, b) return a.dis < b.dis end)
				local starTar = bounceFirstTar[1].tar
				local starPos = starTar.pos:Extended(tarPred, starTar.boundingRadius*2)
				local _, _, collisionCount = GGPrediction:GetCollision(starPos, tarPred, self.QSpell.Speed, self.QSpell.Delay, 60, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount == 0 then
					Control.CastSpell(HK_Q, starTar)
				end
			end
		end
	end
end

function zgMissFortune:CastGGPred(spell, unit)
	if spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function zgMissFortune:GetQDmg(target)
		local level = myHero:GetSpellData(_Q).level
		local QDmg = ({20, 45, 70, 95, 120})[level] + myHero.totalDamage + 0.35 * myHero.ap
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgMissFortune:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

--------------------------------------

class "zgJayce"

function zgJayce:__init()
	print("Jayce Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(...) self:OnWndMsg(...) end)
	-- Spell:OnSpellCast(function(...) self:OnSpellCast(...) end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.Q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1050, Speed = 1450, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.Q1extSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 1600, Speed = 2350, Collision = false}
	self.Q1extColSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 1600, Speed = 2350, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.Q2Spell = {Range = 600}
	self.W2Spell = {Radius = 350}
	self.E1Spell = {Range = 650}
	self.E2Spell = {Delay = 0.25, Range = 240}
end

function zgJayce:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Q", name = "Q Config"})
	Menu.Q:MenuElement({id = "Qr", name = "Use Q range", toggle = true, value = true})
	Menu.Q:MenuElement({id = "Qm", name = "Use Q melee", toggle = true, value = true})
	Menu.Q:MenuElement({id = "QEsplash", name = "Q + E splash minion damage", toggle = true, value = true})
	Menu.Q:MenuElement({id = "useQE", name = "Semi-manual Q + E Target near mouse", key = string.byte("T")})
	
	Menu:MenuElement({type = MENU, id = "W", name = "W Config"})
	Menu.W:MenuElement({id = "Wr", name = "Use W range", toggle = true, value = true})
	Menu.W:MenuElement({id = "Wm", name = "Use W melee", toggle = true, value = true})
	Menu.W:MenuElement({id = "Wmove", name = "Disable move if W range active", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "E", name = "E Config"})
	Menu.E:MenuElement({id = "Er", name = "Use E range (Q + E)", toggle = true, value = true})
	Menu.E:MenuElement({id = "Esm", name = "Use E When Manual RangeQ", toggle = true, value = false})
	Menu.E:MenuElement({id = "Em", name = "Use E melee", toggle = true, value = true})
	Menu.E:MenuElement({id = "Eks", name = "E melee ks only", toggle = true, value = false})
	Menu.E:MenuElement({id = "gapE", name = "Gapcloser R + E", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "R", name = "R Config"})
	Menu.R:MenuElement({id = "Rr", name = "Use R range", toggle = true, value = true})
	Menu.R:MenuElement({id = "Rm", name = "Use R melee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass Mana", value = 80, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Enable", name = "Flee Mode(A)", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Farm", name = "Farm"})
	Menu.Farm:MenuElement({id = "spellFarm", name = "Spells Farm Key toggle", toggle = true, value = false, key = string.byte("N")})
	Menu.Farm:MenuElement({id = "farmQ", name = "Lane clear Q + E range", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "farmW", name = "Lane clear W range && melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "LCminions", name = "Lane clear minimum minions", value = 3, min = 0, max = 10, step = 1})
	-- Menu.Farm:MenuElement({id = "Mana", name = "LaneClear Mana", value = 50, min = 0, max = 100, step = 5})
	Menu.Farm:MenuElement({id = "jungleC", name = "Jungle Clear Key toggle", toggle = true, value = false, key = string.byte("M")})
	Menu.Farm:MenuElement({id = "jungleQ", name = "Jungle clear Q", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleW", name = "Jungle clear W", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleE", name = "Jungle clear E", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleR", name = "Jungle clear R", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleQm", name = "Jungle clear Q melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleWm", name = "Jungle clear W melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleEm", name = "Jungle clear E melee", toggle = true, value = true})


	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawJungle", name = "Draw Jungle Clear Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "showcd", name = "Show cooldown", toggle = true, value = false})
end

function SetPlus(valus)
	if valus < 0 then
		return 0
	else
		return valus
	end
end

local Q1mana, W1mana, E1mana, Q2mana, W2mana, E2mana= 0, 0, 0, 0, 0, 0
local Q1cdt, W1cdt, E1cdt, Q2cdt, W2cdt, E2cdt= 0, 0, 0, 0, 0, 0
local Q1cd, W1cd, E1cd, Q2cd, W2cd, E2cd= 0, 0, 0, 0, 0, 0
function zgJayce:SetValue()
	if self:IsRange() then
		Q1cdt = myHero:GetSpellData(_Q).castTime
		W1cdt = myHero:GetSpellData(_W).castTime
		E1cdt = myHero:GetSpellData(_E).castTime
		
		Q1mana = myHero:GetSpellData(_Q).mana
		W1mana = myHero:GetSpellData(_W).mana
		E1mana = myHero:GetSpellData(_E).mana
	else
		Q2cdt = myHero:GetSpellData(_Q).castTime
		W2cdt = myHero:GetSpellData(_W).castTime
		E2cdt = myHero:GetSpellData(_E).castTime

		Q2mana = myHero:GetSpellData(_Q).mana
		W2mana = myHero:GetSpellData(_W).mana
		E2mana = myHero:GetSpellData(_E).mana
	end
	Q1cd = SetPlus(Q1cdt - GameTimer())
	W1cd = SetPlus(W1cdt - GameTimer())
	E1cd = SetPlus(E1cdt - GameTimer())
	Q2cd = SetPlus(Q2cdt - GameTimer())
	W2cd = SetPlus(W2cdt - GameTimer())
	E2cd = SetPlus(E2cdt - GameTimer())
end

local isQmanualCast = false
local QmanualTimer = nil
function zgJayce:OnWndMsg(msg, wParam)
	if self:IsRange() and GameCanUseSpell(_Q) == 0 then
		if msg == KEY_DOWN and wParam == HK_Q then
		-- print('q')
			isQmanualCast = true
			QmanualTimer = GetTickCount()
		end
	end
end

-- function zgJayce:OnSpellCast(spell)
	-- if not self:IsRange() then
		-- if spell == _Q then
			-- if IsReady(_W) and Menu.W.Wm:Value() and myHero.mana > 80 then
				-- Control.CastSpell(HK_W)
			-- end
		-- end
	-- end	
-- end

function zgJayce:OnPreAttack(args)
	if IsReady(_W) and Menu.W.Wr:Value() and self:IsRange() and args.Target.type == Obj_AI_Hero then
		if GetMode() == "Combo" then
			Control.CastSpell(HK_W)
		else
			if args.Target.pos:DistanceTo(myHero.pos) < 500 then
				Control.CastSpell(HK_W)
			end
		end
	end
end

local Etick = 0
function zgJayce:Tick()
	if ShouldWait() then
		return
	end
	if QmanualTimer and GetTickCount() > QmanualTimer + 1000 then
		isQmanualCast = false
		QmanualTimer = nil
	end

	if Menu.E.Esm:Value() and isQmanualCast == true or isQmanualCast == false then
		if myHero.activeSpell.name == "JayceShockBlast" then
			Etick = GetTickCount()
			if self:IsRange() and IsReady(_E) and Menu.E.Er:Value() and GetTickCount() < Etick + 250 + GameLatency() then
				local EcastPos = Vector(myHero.pos):Extended(Vector(myHero.activeSpell.placementPos), 150 + GameLatency()/2)
				Control.CastSpell(HK_E, EcastPos)
			end
		end	
	end

	self:SetValue()
	self:Gapcloser()
	if GetMode() == "Flee" and Menu.Flee.Enable:Value() then
		self:Flee()
	end

	if IsCasting() then return end

	if self:IsRange() then
		if Menu.W.Wmove:Value() and Orbwalker:GetTarget() ~= nil and HaveBuff(myHero, "jaycehypercharge") then
			Orbwalker:SetMovement(false)
		else
			Orbwalker:SetMovement(true)
		end
		if IsReady(_Q) and Menu.Q.Qr:Value() then
			self:Q1Logic()
		end
		if IsReady(_W) and Menu.W.Wr:Value() then
			self:W1Logic()
		end
	else
		Orbwalker:SetMovement(true)
		if IsReady(_E) and Menu.E.Em:Value() then
			self:E2Logic()
		end
		if IsReady(_Q) and Menu.Q.Qm:Value() then
			self:Q2Logic()
		end
		if IsReady(_W) and Menu.W.Wm:Value() then
			self:W2Logic()
		end
	end
	
	if IsReady(_R) then
		self:RLogic()
	end

	self:JungleClear()
	self:LaneClear()
end

function zgJayce:Gapcloser()
	if not Menu.E.gapE:Value() or E2cd > 0.1 then
		return
	end
	if self:IsRange() and not IsReady(_R) then
		return
	end
	
	local enemies = ObjectManager:GetEnemyHeroes(1500)
	for i, target in ipairs(enemies) do
		if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
			if myHero.pos:DistanceTo(target.pathing.endPos) <= 400 then
				if self:IsRange() then
					Control.CastSpell(HK_R)
				else
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgJayce:Flee()
	if self:IsRange() then
		if IsReady(_E) then
			Control.CastSpell(HK_E, myHero.pos:Extended(mousePos, 150))
		else
			if IsReady(_R) then
				Control.CastSpell(HK_R)
			end
		end
	else
		if IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.Q2Spell.Range)
			TableSort(minions, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
			if #minions > 0 then
				local best = minions[1]
				if best.pos:DistanceTo(mousePos) + 200 < myHero.pos:DistanceTo(mousePos) then
					Control.CastSpell(HK_Q, best)
				end
			else
				if IsReady(_R) then
					Control.CastSpell(HK_R)
				end
			end
		else
			if IsReady(_R) then
				Control.CastSpell(HK_R)
			end
		end
	end	
end

function zgJayce:Q1Logic()
	local Qtype = self.Q1Spell
	if self:CanUseQE() then Qtype = self.Q1extSpell end
	
	if Menu.Q.useQE:Value() then
		local enemies = ObjectManager:GetEnemyHeroes(Qtype.Range)
		TableSort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) then
			self:CastQ1(enemies[1])
			return
		end
	end
	
	local target = GetTarget(Qtype.Range)
	if IsValid(target) then
		local qDmg = self:GetQ1Dmg(target)
		if self:CanUseQE() then qDmg = qDmg * 1.4 end
		if qDmg > target.health then
			self:CastQ1(target)
		elseif GetMode() == "Combo" and myHero.mana > Q1mana + E1mana then
			self:CastQ1(target)
		elseif GetMode() == "Harass" --[[and myHero.mana/myHero.maxMana > Menu.Harass.Mana:Value()/100 ]]then
			self:CastQ1(target)
		end
	end
	
	-- if (GetMode() ~= "Combo" or GetMode() ~= "Harass") and myHero.mana > Q1mana + E1mana then
		-- local enemies = ObjectManager:GetEnemyHeroes(Qtype.Range)
		-- for i, enemy in ipairs(enemies) do
			-- if IsValid(enemy) and IsImmobile(enemy) then
				-- self:CastQ1(enemy)
			-- end
		-- end
	-- end
end

function zgJayce:W1Logic()
	if GetMode() == "Combo" and IsReady(_W) and Orbwalker:GetTarget() ~= nil and Orbwalker:GetTarget().type == Obj_AI_Hero then
		Control.CastSpell(HK_W)
	end
end

function zgJayce:Q2Logic()
	local target = GetTarget(self.Q2Spell.Range)
	if IsValid(target) then
		if self:GetQ2Dmg(target) > target.health then
			Control.CastSpell(HK_Q, target)
		else
			if GetMode() == "Combo" then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
end

function zgJayce:W2Logic()
	if GetEnemyCount(300, myHero.pos) > 0 and myHero.mana > 80 then
		Control.CastSpell(HK_W)
	end
end

function zgJayce:E2Logic()
	local target = GetTarget(self.E2Spell.Range+150)
	if IsValid(target) then
		if self:GetE2Dmg(target) > target.health then
			Control.CastSpell(HK_E, target)
		else
			if GetMode() == "Combo" and not Menu.E.Eks:Value() and not HaveBuff(myHero, "jaycehypercharge") then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function zgJayce:RLogic()
	if self:IsRange() and Menu.R.Rm:Value() then
		local target = GetTarget(self.Q2Spell.Range+200)
		if GetMode() == "Combo" and Q1cd > 0.5 and IsValid(target) and
			((not IsReady(_W) and target.range > 300) or (not IsReady(_W) and not HaveBuff(myHero, "jaycehypercharge") and target.range < 300))
		then
			if Q2cd < 0.5 and GetEnemyCount(800, target.pos) < 3 then
				Control.CastSpell(HK_R)
			else
				if GetEnemyCount(300, myHero.pos) > 0 and E2cd < 0.5 then
					Control.CastSpell(HK_R)
				end
			end
		end
	else
		if GetMode() == "Combo" and Menu.R.Rr:Value() then
			local target = GetTarget(1400)
			if IsValid(target) and target.pos:DistanceTo(myHero.pos) > self.Q2Spell.Range + 200 then
				if Q1cd < 0.5 and E1cd < 0.5 then -- and self:GetQ1Dmg(target) * 1.4 > target.health
					Control.CastSpell(HK_R)
				end
			end
			if not IsReady(_Q) and (not IsReady(_E) or Menu.E.Eks:Value()) then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function zgJayce:CastQ1(target)
	if not self:CanUseQE() then
		local Pred = GGPrediction:SpellPrediction(self.Q1Spell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
			return
		end
	end

	if Menu.Q.QEsplash:Value() then
		local Pred = GGPrediction:SpellPrediction(self.Q1extSpell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, Pred.CastPosition, self.Q1extSpell.Speed, self.Q1extSpell.Delay, self.Q1extSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(Pred.CastPosition) < 150 then
					Control.CastSpell(HK_Q, Pred.CastPosition)
				end
			else
				Control.CastSpell(HK_Q, Pred.CastPosition)
			end
		end
	else
		local Pred = GGPrediction:SpellPrediction(self.Q1extColSpell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function zgJayce:CanUseQE()
	if IsReady(_E) and myHero.mana > Q1mana + E1mana and Menu.E.Er:Value() then
		return true
	else
		return false
	end
end

function zgJayce:IsRange()
	return myHero:GetSpellData(_Q).name:lower() == "jayceshockblast"
end

function zgJayce:LaneClear()
	if GetMode() ~= "LaneClear" then return end
	if IsUnderTurret(myHero) then return end
	if Menu.Farm.spellFarm:Value() --[[and myHero.mana/myHero.maxMana > Menu.Farm.Mana:Value()/100 ]]then
		if self:IsRange() and IsReady(_Q) and IsReady(_E) and Menu.Farm.farmQ:Value() then
			local minions = ObjectManager:GetEnemyMinions(self.Q1Spell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					if GetMinionCount(250, minion.pos) >= Menu.Farm.LCminions:Value() then
						local endPos = minion.pos:Extended(myHero.pos, 150)
						local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.Q1extSpell.Speed, self.Q1extSpell.Delay, self.Q1extSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if collisionCount == 0 then
							Control.CastSpell(HK_Q, minion)
						end
					end
				end
			end
		end
		if IsReady(_W) and Menu.Farm.farmW:Value() then
			if self:IsRange() then
				local minions = ObjectManager:GetEnemyMinions(550)
				for i = 1, #minions do
					local minion = minions[i]
					if minion.team ~= 300 and #minions >= Menu.Farm.LCminions:Value() then
						Control.CastSpell(HK_W)
					end
				end
			else
				local minions = ObjectManager:GetEnemyMinions(300)
				for i = 1, #minions do
					local minion = minions[i]
					if minion.team ~= 300 and #minions >= Menu.Farm.LCminions:Value() then
						Control.CastSpell(HK_W)
					end
				end
			end
		end
	end
end

function zgJayce:JungleClear()
	if GetMode() == "LaneClear" and Menu.Farm.jungleC:Value() then
		local minions = ObjectManager:GetEnemyMinions(700)
		for i = 1, #minions do
			local minion = minions[i]
			if minion.team == 300 and #minions > 0 then
				if self:IsRange() then
					if IsReady(_Q) and Menu.Farm.jungleQ:Value() then
						Control.CastSpell(HK_Q, minion)
						return
					end
					if IsReady(_W) and Menu.Farm.jungleW:Value() then
						if Data:IsInAutoAttackRange(myHero, minion) then
							Control.CastSpell(HK_W)
							return
						end
					end
					if IsReady(_R) and Menu.Farm.jungleR:Value() then
						Control.CastSpell(HK_R)
					end
				else
					if IsReady(_Q) and Menu.Farm.jungleQm:Value() then
						Control.CastSpell(HK_Q, minion)
						return
					end
					if IsReady(_W) and Menu.Farm.jungleWm:Value() then
						if myHero.pos:DistanceTo(minion.pos) <= 300 then
							Control.CastSpell(HK_W)
							return
						end
					end
					if IsReady(_E) and Menu.Farm.jungleEm:Value() then
						if myHero.pos:DistanceTo(minion.pos) <= 300 then
							Control.CastSpell(HK_E, minion)
							return
						end
					end
					if IsReady(_R) and Menu.Farm.jungleR:Value() then
						Control.CastSpell(HK_R)
					end
				end
			end
		end
	end
end

function zgJayce:GetQ1Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({60, 110, 160, 210, 260, 310})[level] + 1.40 * myHero.bonusDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgJayce:GetQ2Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({60, 105, 150, 195, 240, 285})[level] + 1.35 * myHero.bonusDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgJayce:GetE2Dmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({8, 10.8, 13.6, 16.4, 19.2, 22})[level]/100 * target.maxHealth + myHero.bonusDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgJayce:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Farm.spellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.DrawJungle:Value() then
		if Menu.Farm.jungleC:Value() then
			Draw.Text("Jungle Clear: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Jungle Clear: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.showcd:Value() then
		local msg = " "
		if self:IsRange() then
			msg = "Q2 " .. MathFloor(Q2cd) .. " W2 " .. MathFloor(W2cd) .. " E2 " .. MathFloor(E2cd)
			Draw.Text(msg, 22, myHero.pos2D.x-50, myHero.pos2D.y-120, Draw.Color(255, 255, 165, 0))
		else
			msg = "Q1 " .. MathFloor(Q1cd) .. " W1 " .. MathFloor(W1cd) .. " E1 " .. MathFloor(E1cd)
			Draw.Text(msg, 22, myHero.pos2D.x-50, myHero.pos2D.y-120, Draw.Color(255, 0, 255, 255))
		end
	end
	
	if Menu.Draw.Q:Value() then
		if self:IsRange() then
			if self:CanUseQE() then
				Draw.Circle(myHero.pos, self.Q1extSpell.Range, 1, Draw.Color(255, 66, 244, 113))
			else
				Draw.Circle(myHero.pos, self.Q1Spell.Range, 1, Draw.Color(255, 66, 244, 113))
			end
		else
			Draw.Circle(myHero.pos, self.Q2Spell.Range, 1, Draw.Color(255, 66, 244, 113))
		end
	end
end

--------------------------------------

class "zgKalista"

function zgKalista:__init()
	print("Marksmen Kalista Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 40, Range = 1150, Speed = 2400, Collision = false}
	self.ESpell = {Range = 1000}
	self.RSpell = {Range = 1150}
end

function zgKalista:LoadMenu()
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E| If Can Kill Minion And Slow Target", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E| If Can Kill Minion And Slow Target", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanKill Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "QMana", name = "UseQ When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanKill Counts >= ", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QhitChance", name = "Q| hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "E", name = "Auto E Kill EpicMonster", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "R", name = "Auto R Ally LowHp", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	-- Menu.Draw:MenuElement({id = "DragonBuffNums", name = "Draw Duplicate dragon buffs Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgKalista:Tick()
	if ShouldWait() then
		return
	end
	self:KillSteal()
	self:AutoKillEpicMonster()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
	self:AutoR()
end

function zgKalista:KillSteal()
	if Menu.KillSteal.E:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and HaveBuff(target, "kalistaexpungemarker") then
				local EDmg = self:GetEDmg(target)
				-- print(EDmg)
				if EDmg >= target.health + target.hpRegen + target.shieldAD then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				local QDmg = self:GetQDmg(target)
				local EDmg = self:GetEDmg(target)
				local hp = target.health + target.shieldAD
				if QDmg >= hp and (EDmg < hp or not IsReady(_E)) then
					self:CastQ(target)
				elseif QDmg + EDmg > hp and EDmg < hp and Data:IsInAutoAttackRange(myHero, target) then
					self:CastQ(target)
				end
			end
		end
	end
end

function zgKalista:CastQ(target)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(target, myHero)
	if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) and not IsCasting() and not myHero.pathing.isDashing then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount > 0 then
			local allColCanKill = true
			for _, col in ipairs(collisionObjects) do
				if IsValid(col) then
					local QDmg = self:GetQDmg(col)
					if col.health > QDmg then
						allColCanKill = false
						break
					end
				end
			end
			if allColCanKill then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		else
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function zgKalista:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
		local Qtarget = GetTarget(self.QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			self:CastQ(Qtarget)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local targets = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for _, Etarget in ipairs(targets) do 
			if IsValid(Etarget) and HaveBuff(Etarget, "kalistaexpungemarker") then
				local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
				for _, minion in ipairs(minions) do
					if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
						local EDmg = self:GetEDmg(minion)
						if minion.health <= EDmg then
							Control.CastSpell(HK_E)
						end
					end
				end
			end
		end
	end
end

function zgKalista:Harass()
	if IsUnderTurret(myHero) then return end
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
			local Qtarget = GetTarget(self.QSpell.Range)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen and not Data:IsInAutoAttackRange(myHero, Qtarget) then
				self:CastQ(Qtarget)
			end
		end
		if Menu.Harass.E:Value() and IsReady(_E) then
			local targets = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
			for _, Etarget in ipairs(targets) do 
				if IsValid(Etarget) and HaveBuff(Etarget, "kalistaexpungemarker") then
					local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
					for i, minion in ipairs(minions) do
						if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
							local EDmg = self:GetEDmg(minion)
							if minion.health <= EDmg then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
	-- end
end

function zgKalista:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgKalista:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
			local killCount = 0
			local minions = ObjectManager:GetEnemyMinions(self.ESpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and HaveBuff(minion, "kalistaexpungemarker") then
					local EDmg = self:GetEDmg(minion)
					if minion.health <= EDmg then
						killCount = killCount + 1
						if not Data:IsInAutoAttackRange(myHero, minion) then
							Control.CastSpell(HK_E)
						end
						if minion.charName:lower():find("siege") or minion.name:lower():find("super") then
							Control.CastSpell(HK_E)
						end
					end
					if killCount >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
		if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.QMana:Value()/100 and ]]Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and not IsCasting() and not myHero.pathing.isDashing then
					local QDmg = self:GetQDmg(minion)
					if minion.health <= QDmg then
						local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if Menu.Clear.LaneClear.QCount:Value() == 1 then
							if collisionCount == 0 then
								Control.CastSpell(HK_Q, minion)
							end
						else
							if collisionCount == Menu.Clear.LaneClear.QCount:Value() - 1 then
								local allColCanKill = true
								for _, col in ipairs(collisionObjects) do
									if IsValid(col) then
										local QDmg = self:GetQDmg(col)
										if col.health > QDmg then
											allColCanKill = false
											break
										end
									end
								end
								if allColCanKill then
									Control.CastSpell(HK_Q, minion)
								end
							end
						end
					end
				end
			end
		end
	end
end

function zgKalista:JungleClear()
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		local minions = ObjectManager:GetMonsters(self.ESpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
				local minionName = minion.charName:lower()
				if not epicMonsters[minionName] then
					local EDmg = self:GetEDmg(minion)
					if EDmg >= minion.health then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
	end
end

function zgKalista:AutoKillEpicMonster()
	if Menu.Misc.E:Value() and IsReady(_E) then
		local minions = ObjectManager:GetMonsters(self.ESpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
				local minionName = minion.charName:lower()
				if epicMonsters[minionName] then
					local EDmg = self:GetEDmg(minion, true)
					if EDmg >= (minion.health + minion.hpRegen + minion.shieldAD) then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
	end
end

function zgKalista:AutoR()
	if Menu.Misc.R:Value() and IsReady(_R) then
		local allies = ObjectManager:GetAllyHeroes(self.RSpell.Range)
		for i, ally in ipairs(allies) do
			if IsValid(ally) and not ally.isMe and HaveBuff(ally, "kalistacoopstrikeally") then
				if ally.health < GetEnemyCount(600, ally.pos) * ally.levelData.lvl * 30 then
					Control.CastSpell(HK_R)
				end
			end
		end
	end
end

function zgKalista:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level > 0 then
		local QDmg = ({10, 75, 140, 205, 270})[level] + 1.05 * myHero.totalDamage
		if GamemapID == HOWLING_ABYSS then
			if target.type == Obj_AI_Hero then
				QDmg = QDmg * 1.1
			end
		end
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
	else
		return 0
	end
end

function zgKalista:GetEDmg(target, isEpicMonster)
	local buff, buffData = GetBuffData(target, "kalistaexpungemarker")
	local level = myHero:GetSpellData(_E).level
	local targetName = target.charName:lower()
	if buff and level > 0 then
		local baseDmg = ({5, 15, 25, 35, 45})[level] + 0.7 * myHero.totalDamage + 0.65 * myHero.ap
		local bonusDmg = (buffData.count - 1) * (({7, 14, 21, 28, 35})[level] + ({0.2, 0.25, 0.3, 0.35, 0.4})[level] * myHero.totalDamage + 0.5 * myHero.ap)
		local totalDmg = baseDmg + bonusDmg
		if HasBuffContainsName(myHero, "PressTheAttackLockout") then
			totalDmg = totalDmg * 1.08
		end
		if HaveBuff(myHero, "SummonerExhaust") then
			totalDmg = totalDmg * 0.65
		end
		if HaveBuff(myHero, "SRX_DragonSoulBuffChemtech") and myHero.health/myHero.maxHealth < 0.5 then
			totalDmg = totalDmg * 1.11
		elseif HaveBuff(target, "SRX_DragonSoulBuffChemtech") and target.health/target.maxHealth < 0.5 then
			totalDmg = totalDmg * 0.89
		end
		if GamemapID == HOWLING_ABYSS then
			if target.type == Obj_AI_Hero then
				totalDmg = totalDmg * 1.1
			else
				totalDmg = totalDmg * 0.75
			end
		end
		if isEpicMonster then
			totalDmg = totalDmg * 0.5
			if targetName == "sru_baron" and HaveBuff(myHero, "BaronTarget") then
				totalDmg = totalDmg * 0.5
			end
			if targetName:find("sru_dragon") and targetName ~= "sru_dragon_elder" then
				local buffNums = HaveBuffContainsNameNums(myHero, "SRX_DragonBuff")
				totalDmg = totalDmg * (1 - 0.07 * buffNums)
			end
		end
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, totalDmg)
	else
		return 0
	end
end

function zgKalista:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

--------------------------------------

class "zgAshe"

function zgAshe:__init()
	print("Marksmen Ashe Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 20, Range = 1200, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 130, Range = 12500, Speed = 1600, Collision = false}
end

function zgAshe:LoadMenu()
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Raoe", name = "Use R| AOE", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "Count", name = "If LaneClear Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W| hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "RhitChance", name = "R| hitChance", value = 2, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Target near mouse", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function zgAshe:OnPostAttack()
	local target = Orbwalker:GetTarget()
	if IsValid(target) and IsReady(_Q) then
		if target.type == Obj_AI_Hero then
			if GetMode() == "Combo" and Menu.Combo.Q:Value() or (GetMode() == "Harass" and Menu.Harass.Q:Value()--[[ and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100]]) then
				Control.CastSpell(HK_Q)
			end
		elseif target.type == Obj_AI_Minion then
			if GetMode() == "LaneClear" and Menu.Clear.SpellFarm:Value() then
				if target.team ~= 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.Q:Value() then
					if GetMinionCount(600, myHero.pos) > Menu.Clear.LaneClear.Count:Value() then
						Control.CastSpell(HK_Q)
					end
				elseif target.team == 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.JungleClear.Q:Value() then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgAshe:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiManualR()
	self:KillSteal()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function zgAshe:KillSteal()
	if Menu.KillSteal.W:Value() and IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				local WDmg = self:GetWDmg(target)
				if WDmg >= target.health + target.hpRegen + target.shieldAD then
					self:CastW(target)
				end
			end
		end
	end
end

function zgAshe:SemiManualR()
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		local enemies = ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		TableSort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) and enemies[1].pos2D.onScreen then
			self:CastR(enemies[1])
		end
	end
end

function zgAshe:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgAshe:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(Menu.Misc.RhitChance:Value() + 1) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgAshe:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
	if Menu.Combo.Raoe:Value() and IsReady(_R) then
		local target = GetTarget(2000)
		if IsValid(target) and target.pos2D.onScreen and GetEnemyCount(250, target.pos) > 2 then
			self:CastR(target)
		end
	end
end

function zgAshe:Harass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.W:Value() and IsReady(_W) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
end

function zgAshe:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgAshe:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(self.WSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 then
					if GetMinionCount(300, minion.pos) >= Menu.Clear.LaneClear.Count:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgAshe:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(600)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
	end
end

function zgAshe:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level > 0 then
		local WDmg = ({20, 35, 50, 65, 80})[level] + myHero.totalDamage
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
	else
		return 0
	end
end

function zgAshe:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

-----------------------------------------

class "zgCorki"

function zgCorki:__init()
	print("Marksmen Corki Loaded") 
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 950, Speed = 1100, Collision = false}
	self.ESpell = {Range = 690}
	self.R1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1250, Speed = 2000, Collision = false}
	self.R2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1450, Speed = 2000, Collision = false}
end

function zgCorki:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Rammo", name = "Minimum R ammo harass", value = 2, min = 0, max = 3, step = 1})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "RCount", name = "If R CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QhitChance", name = "Q | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "RhitChance", name = "R | hitChance", value = 2, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q On 'CC'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgCorki:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and target.type == Obj_AI_Hero and not self:HaveSheenBuff() then
		if GetMode() == "Combo" and Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, target)
		end
		if GetMode() == "Harass" --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then 
			if Menu.Harass.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function zgCorki:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiR()
	self:AutoQ()
	if self:HaveSheenBuff() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function zgCorki:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(1500)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastR(target)
		end
	end
end

function zgCorki:AutoQ()
	if Menu.Misc.Qcc:Value() and IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsImmobile(target) then
				self:CastQ(target)
			end
		end
	end
end

function zgCorki:CastQ(target)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(target, myHero)
	if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) then
		local castPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 825)
		if myHero.pos:DistanceTo(QPrediction.CastPosition) <= 825 then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		elseif myHero.pos:DistanceTo(QPrediction.CastPosition) > 825 and myHero.pos:DistanceTo(QPrediction.CastPosition) <= 950 then
			Control.CastSpell(HK_Q, castPos)
		end
	end
end

function zgCorki:CastR(target)
	if HaveBuff(myHero, "mbcheck2") then
		local R2Prediction = GGPrediction:SpellPrediction(self.R2Spell)
		R2Prediction:GetPrediction(target, myHero)
		if R2Prediction:CanHit(Menu.Misc.RhitChance:Value() + 1) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R2Prediction.CastPosition, self.R2Spell.Speed, self.R2Spell.Delay, self.R2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R2Prediction.CastPosition) < 250 then
					Control.CastSpell(HK_R, R2Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R2Prediction.CastPosition)
			end
		end
	else
		local R1Prediction = GGPrediction:SpellPrediction(self.R1Spell)
		R1Prediction:GetPrediction(target, myHero)
		if R1Prediction:CanHit(Menu.Misc.RhitChance:Value() + 1) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R1Prediction.CastPosition, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R1Prediction.CastPosition) < 100 then
					Control.CastSpell(HK_R, R1Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R1Prediction.CastPosition)
			end
		end
	end
end

function zgCorki:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(self.QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastQ(target)
			end
		end

		if Menu.Harass.R:Value() and IsReady(_R) then
			local target = GetTarget(1500)
			if IsValid(target) and target.pos2D.onScreen and myHero:GetSpellData(_R).ammo > Menu.Harass.Rammo:Value() then
				self:CastR(target)
			end
		end
	-- end
end

function zgCorki:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgCorki:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
					end
				end
				if Menu.Clear.LaneClear.R:Value() and IsReady(_R) then
					if GetMinionCount(150, minion.pos) >= Menu.Clear.LaneClear.RCount:Value() then
						local endPos = minion.pos:Extended(myHero.pos, 150)
						local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if collisionCount == 0 then
							Control.CastSpell(HK_R, minion)
						end
					end
				end
			end
		end
	end
end

function zgCorki:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
		TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
				if Menu.Clear.JungleClear.R:Value() and IsReady(_R) then
					Control.CastSpell(HK_R, minion)
				end
			end
		end
	end
end

function zgCorki:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(1500)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function zgCorki:HaveSheenBuff()
	local target = Orbwalker:GetTarget()
	if IsValid(target) and (HaveBuff(myHero, "sheen") or HaveBuff(myHero, "6662buff") or HaveBuff(myHero, "3078trinityforce") or HaveBuff(myHero, "lichbane")) then
		return true
	else
		return false
	end
end

function zgCorki:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		if HaveBuff(myHero, "mbcheck2") then
			Draw.Circle(myHero.pos, self.R2Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		else
			Draw.Circle(myHero.pos, self.R1Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		end
	end
end

---------------------------------------------

class "zgCaitlyn"

function zgCaitlyn:__init()
	print("Marksmen Caitlyn Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.625, Radius = 60, Range = 1240, Speed = 2200, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.25, Radius = 15, Range = 800, Speed = MathHuge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.15, Radius = 70, Range = 750, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.375, Radius = 40, Range = 3500, Speed = 3200, Collision = false}
end

function zgCaitlyn:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QSlow", name = "Use Q| Slow", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QAoe", name = "Use Q| Aoe", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QRange", name = "Use Q| Min Range >= x", value = 750, min = 500, max = 1000, step = 50})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WCount", name = "Use W| Keep Ammo Count == x", value = 1, min = 1, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "Use E| Max Range <= x", value = 750, min = 250, max = 750, step = 50})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RSafe", name = "Use R| Safe Check?", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RRange", name = "Use R| Min Range >= x", value = 900, min = 500, max = 1500, step = 100})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 5, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E Dash to Mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "E + AA KillSteal", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Wcc", name = "Auto W on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Wtp", name = "Auto W on TP", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "Wgap", name = "Auto W Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "EgapRange", name = "AntiGap E Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "EQKey", name = "One Key EQ target(In E Range)", key = string.byte("G")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rmin", name = "Draw R Range on minimap", toggle = true, value = false})
end

function zgCaitlyn:Tick()
	if ShouldWait() then
		return
	end

	if myHero.activeSpell.valid and (myHero.activeSpell.name == "CaitlynQ" or myHero.activeSpell.name == "CaitlynR") then
		Orbwalker:SetMovement(false)
		Orbwalker:SetAttack(false)
	else
		Orbwalker:SetMovement(true)
		Orbwalker:SetAttack(true)
	end
	if IsCasting() or myHero.activeSpell.name == "CaitlynR" then return end
	if Menu.Misc.EQKey:Value() then
		self:OneKeyEQ()
	end
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
	self:AntiGapcloser()
	self:Auto()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

_G.CTRLCait = true
_G.lastEProc = 0
_G.lastWProc = {}
local currentBuffTarget = nil

function zgCaitlyn:OnPreAttack(args)
	local heroes = ObjectManager:GetEnemyHeroes(1300)
	local Buff = _G.SDK.BuffManager
	local bestTarget = nil
	local shortestBuffTime = MathHuge
	for i, enemy in pairs(heroes) do
		if enemy then
			if Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker") 
			   and _G.lastEProc + 3 < GameTimer() 
			then
				local buffTime = Buff:GetBuffDuration(enemy, "eternals_caitlyneheadshottracker")
				if buffTime < shortestBuffTime then
					bestTarget = enemy
					shortestBuffTime = buffTime
					currentBuffTarget = {target = enemy, buffType = "E"}
				end
			end
			
			if Buff:HasBuff(enemy, "caitlynwsight") 
			   and (_G.lastWProc[enemy.networkID] == nil or _G.lastWProc[enemy.networkID] + 3 < GameTimer())
			then
				local buffTime = Buff:GetBuffDuration(enemy, "caitlynwsight")
				if buffTime < shortestBuffTime then
					bestTarget = enemy
					shortestBuffTime = buffTime
					currentBuffTarget = {target = enemy, buffType = "W"}
				end
			end
		end
	end
	if bestTarget then
		args.Target = bestTarget
	end
end

function zgCaitlyn:OnPostAttack()
	if currentBuffTarget and currentBuffTarget.target then
		local target = currentBuffTarget.target
		if currentBuffTarget.buffType == "E" then
			_G.lastEProc = GameTimer()
		elseif currentBuffTarget.buffType == "W" then
			_G.lastWProc[target.networkID] = GameTimer()
		end
		currentBuffTarget = nil
	end
end

function zgCaitlyn:OneKeyCastR()
	local Rtarget = GetTarget(self.RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		Control.CastSpell(HK_R, Rtarget)
	end
end

local lastWcc = 0
local lastWgap = 0
local lastWtp = 0
local lastWtfr = 0
-- Separate timestamps for different WCC scenarios
local lastWInvulnerable = 0
local lastWLissandraR = 0
local lastWMeditate = 0
local lastWChronoRevive = 0
local lastWGA = 0
local lastParticleCheckTime = 0
local particleCheckInterval = 1.0
function zgCaitlyn:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				local endPos = Vector(target.pathing.endPos)
				if myHero.pos:DistanceTo(endPos) < Menu.Misc.EgapRange:Value() and IsFacingMe(target) then
					self:CastGGPred(HK_E, target)
				end
			end	
		end
	elseif Menu.Misc.Wgap:Value() and IsReady(_W) and lastWgap + 3000 < GetTickCount() then
		local enemies = ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_W, target.pathing.endPos)
					lastWgap = GetTickCount()
				end
			end	
		end
	end
end

function zgCaitlyn:Auto()
	if Menu.Misc.Qcc:Value() and IsReady(_Q) and GetMode() ~= "Combo" and GetMode() ~= "Harass" then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsImmobile(target) then
				if not IsReady(_W) then
					self:CastGGPred(HK_Q, target)
				else
					if myHero.pos:DistanceTo(target.pos) > self.WSpell.Range then
						self:CastGGPred(HK_Q, target)
					end
				end
			end
		end
	end
	
	-- WCC for various scenarios with independent timing
	if Menu.Misc.Wcc:Value() and IsReady(_W) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
				local isKillableByAA = Data:IsInAutoAttackRange(myHero, target) and (target.health + target.shieldAD) <= Damage:GetAutoAttackDamage(myHero, target)
				
				-- Immobile targets (CC)
				if (not HaveBuff(target, "caitlynwsight") and GetImmobileDuration(target) > 0.5) then
					if not isKillableByAA and lastWcc + 3000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWcc = GetTickCount()
					end
				end
				
				-- General invulnerable targets
				if IsInvulnerable(target) then
					if lastWInvulnerable + 2500 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWInvulnerable = GetTickCount()
					end
				end
				
				-- Lissandra R targets
				if HaveBuff(target, "LissandraRSelf") then
					if lastWccLissandraR + 2500 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWLissandraR = GetTickCount()
					end
				end
				
				-- Meditate targets (Master Yi)
				if HaveBuff(target, "Meditate") then
					if not isKillableByAA and lastWMeditate + 4000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWMeditate = GetTickCount()
					end
				end
				
				-- Chrono Revive targets (Zilean R)
				if HaveBuff(target, "ChronoRevive") then
					if lastWChronoRevive + 3000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWChronoRevive = GetTickCount()
					end
				end
				
				-- Guardian Angel targets
				for j, slot in ipairs(slots) do
					local Data = target:GetSpellData(slot)
					if Data.name == "GuardianAngel" and Data.currentCd == 0 and not target.alive then
						if lastWGA + 4000 < GetTickCount() then
							Control.CastSpell(HK_W, target)
							lastWGA = GetTickCount()
						end
					end
				end
			end
		end
	end

	if Menu.Misc.Wtp:Value() and IsReady(_W) then
		local now = GetTickCount() / 1000
		if now - lastParticleCheckTime > particleCheckInterval then
			lastParticleCheckTime = now
			for i = GameParticleCount(), 1, -1 do
				local par = GameParticle(i)
				if par and par.pos:DistanceTo(myHero.pos) <= self.WSpell.Range then
					local name = par.name:lower()
					if name:find("teledash_end") and name:find("wardenemy") and lastWtp + 8000 < GetTickCount() then -- TP
						Control.CastSpell(HK_W, par)
						lastWtp = GetTickCount()
					end
					if name:find("gatemarker_red") and lastWtfr + 3000 < GetTickCount() then -- TF-R
						Control.CastSpell(HK_W, par)
						lastWtfr = GetTickCount()
					end
						-- (name:find("viego") and name:find("p_spiritshader_inworld_enemy")) -- viego passive
						-- (name:find("yone") and name:find("e_invulnerable_buf")) -- yone E
				end
			end
		end
	end
end

function zgCaitlyn:KillSteal()
	if Menu.KillSteal.Q:Value() and IsReady(_Q) then
		local enemies = ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < self:GetQDmg(target) then
				if Data:IsInAutoAttackRange(myHero, target) and target.health <= Damage:GetAutoAttackDamage(myHero, target) then
					return
				end
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.KillSteal.E:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < (self:GetEDmg(target) + Damage:GetAutoAttackDamage(myHero, target)) then
				self:CastGGPred(HK_E, target)
			end
		end
	end
end

function zgCaitlyn:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) <= Menu.Combo.ERange:Value() then
			if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
				self:CastEQ(target)
			else
				self:CastGGPred(HK_E, target)
			end
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) > Menu.Combo.QRange:Value() then
			if Menu.Combo.QSlow:Value() and IsSlow(target) then
				self:CastGGPred(HK_Q, target)
			end
			if Menu.Combo.QAoe:Value() then
				CastSpellAOE(HK_Q, self.QSpell, 2, myHero)
			end
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).ammo > Menu.Combo.WCount:Value() then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_W, target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) and lastQ + 1500 < GetTickCount() and lastE + 1500 < GetTickCount() then
		local Rtarget = GetTarget(self.RSpell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			if Menu.Combo.RSafe:Value() and (IsUnderTurret(myHero) or GetEnemyCount(Menu.Combo.RRange:Value(), myHero.pos) > 0) then
				return
			end
			if myHero.pos:DistanceTo(Rtarget.pos) < Menu.Combo.RRange:Value() then
				return
			end
			if (Rtarget.health + Rtarget.shieldAD + Rtarget.hpRegen * 3) > self:GetRDmg(Rtarget) then
				return
			end
			if GetEnemyCount(400, Rtarget.pos) > 1 then
				return
			end
			Control.CastSpell(HK_R, Rtarget)
		end
	end
end

function zgCaitlyn:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(self.QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_Q, target)
			end
		end
	-- end
end

function zgCaitlyn:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(self.QSpell.Range)
			TableSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
						lastQ = GetTickCount()
					end
				end
			end
		end
	end
end

function zgCaitlyn:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(800)
			TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
					lastQ = GetTickCount()
				end
			end
		end
	end
end

function zgCaitlyn:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		local castPos = myHero.pos - (mousePos - myHero.pos):Normalized() * 200
		if castPos:To2D().onScreen then
			Control.CastSpell(HK_E, castPos)
			lastE = GetTickCount()
		end
	end
end

function zgCaitlyn:OneKeyEQ()
	if IsReady(_E) and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, self.ESpell.CollisionTypes, target.networkID)
			if collisionCount == 0 then
				self:CastEQ(target)
			end
		end
	end
end

function zgCaitlyn:CastEQ(target)
	local Prediction = GGPrediction:SpellPrediction(self.ESpell)
	Prediction:GetPrediction(target, myHero)
	if Prediction:CanHit(3) then
		Control.CastSpell({HK_E, HK_Q}, Prediction.CastPosition)
	end
end

function zgCaitlyn:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) and lastW + 3000 < GetTickCount() then
			local isKillableByAA = Data:IsInAutoAttackRange(myHero, unit) and (unit.health + unit.shieldAD) <= Damage:GetAutoAttackDamage(myHero, unit)
			local finalCastPos = nil
			if IsFacingMe(unit) then
				if unit.range < 300 and myHero.pos:DistanceTo(unit.pos) < Data:GetAutoAttackRange(unit, myHero) + 100 then
					finalCastPos = myHero.pos
				else
					finalCastPos = WPrediction.CastPosition
				end
			else
				local castPos = WPrediction.CastPosition + (unit.pos - myHero.pos):Normalized() * 100
				if myHero.pos:DistanceTo(castPos) <= self.WSpell.Range then
					finalCastPos = castPos
				end
			end
			if finalCastPos and not isKillableByAA and not self:IsTrapParticleNearby(finalCastPos, 200) then
				Control.CastSpell(HK_W, finalCastPos)
				lastW = GetTickCount()
			end
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end	
	end
end

function zgCaitlyn:IsTrapParticleNearby(castPos, radius)
	for i = GameParticleCount(), 1, -1 do
		local par = GameParticle(i)
		if par and par.pos:DistanceTo(castPos) < radius then
			local pName = par.name:lower()
			if pName:find("caitlyn") and (pName:find("trap_idle_ally") or pName:find("trap_idle_green")) then
				return true
			end
		end
	end
	return false 
end

function zgCaitlyn:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({50, 90, 130, 170, 210})[level] + ({1.25, 1.45, 1.65, 1.85, 2.05})[level] * myHero.totalDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgCaitlyn:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = (({300, 475, 650})[level] + 1.0 * myHero.bonusDamage) * (1 + 0.5 * myHero.critChance)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, RDmg)
end

function zgCaitlyn:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({80, 130, 180, 230, 280})[level] + 0.8 * myHero.ap
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgCaitlyn:Draw()
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
	if Menu.Draw.Rmin:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, self.RSpell.Range, 1, Draw.Color(200, 14, 194, 255))
	end
end

--------------------------------------

class "zgYunara"

function zgYunara:__init()

	print("Marksmen Yunara Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 60, Range = 1150, Speed = 2150, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 90, Range = 1150, Speed = MathHuge, Collision = false}
end

function zgYunara:LoadMenu()
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WLogic", name = "W Usage Logic", value = 1, drop = {"Smart", "Always"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "WLogic", name = "W Usage Logic", value = 1, drop = {"Smart", "Always"}})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "W", name = "Use W| LastHit Not In AA Range", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "AntiGapcloser", name = "AntiGapcloser"})
	Menu.AntiGapcloser:MenuElement({id = "E2", name = "Auto E2 AntiGapcloser", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal(not in aa range)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function zgYunara:OnPostAttack()
	local target = Orbwalker:GetTarget()
	if IsValid(target) and (IsReady(_Q) and myHero.hudAmmo == 8) then
		if target.type == Obj_AI_Hero then
			if GetMode() == "Combo" and Menu.Combo.Q:Value() or (GetMode() == "Harass" and Menu.Harass.Q:Value()--[[ and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100]]) then
				Control.CastSpell(HK_Q)
			end
		elseif target.type == Obj_AI_Minion then
			if GetMode() == "LaneClear" and Menu.Clear.SpellFarm:Value() then
				if target.team ~= 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.Q:Value() then
					if GetMinionCount(300, target.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q)
					end
				elseif target.team == 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.JungleClear.Q:Value() then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgYunara:Tick()
	if ShouldWait() then
		return
	end
	self.WSpell.Delay = MathMax(0.225, 0.45 - 0.225 * (myHero.attackSpeed - 1))
	self.W2Spell.Delay = MathMax(0.45, 0.6 - 0.45 * (myHero.attackSpeed - 1))
	self:AntiGapcloser()
	if IsCasting() then return end
	self:KillSteal()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LastHitW()
		self:FarmHarass()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHitW()
	end
end

function zgYunara:KillSteal()
	if Menu.KillSteal.W:Value() and IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(1100)
		for i, target in ipairs(enemies) do
			if IsValid(target) and not Data:IsInAutoAttackRange(myHero, target) then
				local WDmg = self:GetWDmg(target)
				if WDmg >= target.health + target.hpRegen + target.shieldAD then
					self:CastW(target)
				end
			end
		end
	end
end

function zgYunara:CastW(target)
	local wName = myHero:GetSpellData(_W).name
	local spell =  wName == "YunaraW2" and self.W2Spell or self.WSpell
	local WPrediction = GGPrediction:SpellPrediction(spell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgYunara:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(1100)
		if IsValid(target) and target.pos2D.onScreen then
			local wLogic = Menu.Combo.WLogic:Value()
			if wLogic == 1 and self:CanUseW() then
				if not HaveBuff(myHero, "YunaraQ") or not Data:IsInAutoAttackRange(myHero, target) then
					self:CastW(target)
				end
			elseif wLogic == 2 then
				self:CastW(target)
			end
		end
	end
end

function zgYunara:Harass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.W:Value() and IsReady(_W) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then
		local target = GetTarget(1100)
		if IsValid(target) and target.pos2D.onScreen then
			local wLogic = Menu.Harass.WLogic:Value()
			if wLogic == 1 and self:CanUseW() then
				if not HaveBuff(myHero, "YunaraQ") or not Data:IsInAutoAttackRange(myHero, target) then
					self:CastW(target)
				end
			elseif wLogic == 2 then
				self:CastW(target)
			end
		end
	end
end

function zgYunara:AntiGapcloser()
	if Menu.AntiGapcloser.E2:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "YunaraE2" then
		local enemies = ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * 450
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function zgYunara:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgYunara:CanUseW()
	local QData = myHero:GetSpellData(_Q)
	local WData = myHero:GetSpellData(_W)
	local EData = myHero:GetSpellData(_E)
	local RData = myHero:GetSpellData(_R)
	if WData.name == "YunaraW" and 
		myHero.mana < (QData.mana + WData.mana + (EData.currentCd == 0 and EData.mana or 0) + (RData.currentCd == 0 and RData.mana or 0))
	then
		return false
	end
	return true
end

function zgYunara:LastHitW()
	if Menu.LastHit.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "YunaraW" then
		local minions = ObjectManager:GetEnemyMinions(1150)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 then
				local Wdmg = self:GetWDmg(minion)
				if minion.health <= Wdmg and not Data:IsInAutoAttackRange(myHero, minion) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
					if collisionCount == 0 then
						Control.CastSpell(HK_W, minion)
						return
					end
				end
			end
		end
	end
end

function zgYunara:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(600)
			TableSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 then
					if not HaveBuff(myHero, "YunaraQ") or not Data:IsInAutoAttackRange(myHero, minion) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgYunara:GetWDmg(target)
	local wlevel = myHero:GetSpellData(_W).level
	local rlevel = myHero:GetSpellData(_R).level
	local wName = myHero:GetSpellData(_W).name
	if wlevel > 0 then
		if wName == "YunaraW2" then
			local WDmg = ({175, 350, 525})[rlevel] + 1.50 * myHero.bonusDamage + 0.75 * myHero.ap
			return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
		else
			local WDmg = ({55, 95, 135, 170, 215})[wlevel] + 0.85 * myHero.bonusDamage + 0.5 * myHero.ap
			return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
		end
	else
		return 0
	end
end

function zgYunara:Draw()
	if myHero.dead then return end

	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 1150, 1, Draw.Color(255, 66, 229, 244))
	end
end


Callback.Add("Load", function()
	if _G.SDK then
		Orbwalker = _G.SDK.Orbwalker
		TargetSelector = _G.SDK.TargetSelector
		ObjectManager = _G.SDK.ObjectManager
		HealthPrediction = _G.SDK.HealthPrediction
		Attack = _G.SDK.Attack
		Damage = _G.SDK.Damage
		Spell = _G.SDK.Spell
		Data = _G.SDK.Data
	else
		print('GGOrbwalker is not enabled,  SimpleMarksmen will exit')
		return
	end

	championIcon = "http://ddragon.leagueoflegends.com/cdn/15.14.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Marksmen "..myHero.charName, name = "Marksmen "..myHero.charName, leftIcon = championIcon})
		Menu:MenuElement({name = " ", drop = {"AIO-Version: " .. Version}})

	if table.contains(Heroes, myHero.charName) then
		_G["zg" .. myHero.charName]()
	end
end)