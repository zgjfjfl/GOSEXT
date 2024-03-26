local Version = 2024.16

--[ AutoUpdate ]

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
				print("SimpleMarksmen: Found update! Downloading...")
				DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
				DelayAction(function()
					print("SimpleMarksmen: Successfully updated. Press 2x F6!")
				end, 3)
			end
		end, 3)

	end

	AutoUpdate()

end

local Heroes = {"Nilah", "Smolder", "Zeri", "Lucian", "Jinx"}

if not table.contains(Heroes, myHero.charName) then
	print('SimpleMarksmen not supported ' .. myHero.charName)
	return 
end

require "GGPrediction"
require "2DGeometry"
require "MapPositionGOS"

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
local GameIsWall = Game.isWall

local TableInsert = table.insert
local TableRemove = table.remove
local MathHuge = math.huge
local MathMin = math.min
local MathMax = math.max
local MathFloor = math.floor
local MathSqrt = math.sqrt
local MathSort = table.sort
local MathDeg = math.deg
local MathAbs = math.abs

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
end)

local function IsReady(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0 and Cursor.Step == 0
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

local function IsUnderTurret2(pos)
	for i, turret in ipairs(GetEnemyTurrets()) do
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
		if hero.team ~= myHero.team and hero.dead == false and GetDistanceSqr(unit, hero.pos) < Range then
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
	local Angle = 180 - MathDeg(math.acos(V*D/(V:Len()*D:Len())))
	if MathAbs(Angle) < 90 then 
		return true  
	end
	return false
end

local function CircleCircleIntersection(c1, c2, r1, r2)
	local D = GetDistance(c1,c2)
	if D > r1 + r2 or D <= MathAbs(r1 - r2) then return nil end
	local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D)
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
		if GameIsWall(checkPos) then
			return checkPos
		end
	end
	return nil
end

local function IsWall(pos)
	if GameIsWall == nil then
		if MapPosition:inWall(pos) then
			return true
		else
			return false
		end
	else
		return GameIsWall(pos)
	end
end

local slots = {}
	TableInsert(slots, ITEM_1);
	TableInsert(slots, ITEM_2);
	TableInsert(slots, ITEM_3);
	TableInsert(slots, ITEM_4);
	TableInsert(slots, ITEM_5);
	TableInsert(slots, ITEM_6);

---------------------------------

Menu = MenuElement({type = MENU, id = "Marksmen "..myHero.charName, name = "Marksmen "..myHero.charName, leftIcon = "http://ddragon.leagueoflegends.com/cdn/14.5.1/img/champion/"..myHero.charName..".png"})
	Menu:MenuElement({name = " ", drop = {"Version: " .. Version}})

---------------------------------

class "Nilah"
        
function Nilah:__init()	     
    print("Marksmen Nilah Loaded")
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:OnTick() end)    
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 600, Speed = math.huge, Collision = false}
    self.eSpell = { Range = 550 }
    self.rSpell = { Range = 400 }  
end

function Nilah:LoadMenu()
            
    Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Eammo", name = "[E] Save 1 stock for Kills or Flee or Manual", toggle = true, value = true})
        Menu.Combo:MenuElement({id = "ETHP", name = "Use E when target HP %", value =  60, min=5, max = 100, step = 5})
        Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
        Menu.Combo:MenuElement({id = "RCount", name = "Use R when can hit >= X enemies", min = 1, max = 5, value=2})

    Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 20, min = 0, max = 100})

    Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
        Menu.Auto:MenuElement({id = "W", name = "[W] auto use when enemyattackself", toggle = true, value = false})
        Menu.Auto:MenuElement({id = "WHP", name = "when self HP %", value =  50, min=5, max = 100, step = 5})

    Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
        Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        Menu.Clear:MenuElement({id = "QR", name = "[Q] lasthit no aarange minion", toggle = true, value = true})
        Menu.Clear:MenuElement({id = "QT", name = "[Q] Turret, Barrack, Nexus", toggle = true, value = true})
        Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to LaneClear", value = 30, min = 0, max = 100})
			
    Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
        Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})

    Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
        Menu.Flee:MenuElement({id = "E", name = "[E] to mouse near target", toggle = true, value = true})

    Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function Nilah:OnTick()

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

    if myHero.activeSpell.valid then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and IsValid(target) then

        if Menu.Combo.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, target.pos) <= self.qSpell.Range then
            self:CastGGPred(HK_Q, target)
        end

        if Menu.Combo.E:Value() and IsReady(_E) and GetDistance(myHero.pos, target.pos) <= self.eSpell.Range and target.health/target.maxHealth <= Menu.Combo.ETHP:Value()/100 then
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

        if Menu.Combo.R:Value() and IsReady(_R) and GetEnemyCount(self.rSpell.Range, myHero.pos) >= Menu.Combo.RCount:Value() then
            Control.CastSpell(HK_R)
        end
    end
end

function Nilah:Harass()

    if myHero.activeSpell.valid then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and IsValid(target) then
            
        if Menu.Harass.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, target.pos) <= self.qSpell.Range and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 then
            self:CastGGPred(HK_Q, target)
        end
    end
end

function Nilah:AutoW()
    if Menu.Auto.W:Value() and IsReady(_W) then
        for i, hero in pairs(GetEnemyHeroes()) do
            if hero.alive and hero.visible then
                if hero.activeSpell.target == myHero.handle and myHero.health/myHero.maxHealth <= Menu.Auto.WHP:Value()/100 then
                    Control.CastSpell(HK_W)
                end
            end
        end
    end
end

function Nilah:LaneClear()
  if IsReady(_Q) and myHero.mana/myHero.maxMana >= Menu.Clear.Mana:Value() / 100 then
    if Menu.Clear.Q:Value() then
        local minions = ObjectManager:GetEnemyMinions(self.qSpell.Range)
        MathSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
        for i, minion in ipairs(minions) do
            if IsValid(minion) and minion.pos2D.onScreen then
                local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
                if collisionCount >= 0 then
                    Control.CastSpell(HK_Q, minion)
                end
            end
        end
	end

    if Menu.Clear.QR:Value() then
        local minionInRange = ObjectManager:GetEnemyMinions(self.qSpell.Range)
        if next(minionInRange) == nil then end
        for i = 1, #minionInRange do
        local minion = minionInRange[i]
            local AARange = myHero.range + myHero.boundingRadius
            local QDmg = self:getqDmg(minion)
            if GetDistance(myHero.pos, minion.pos) <= self.qSpell.Range and GetDistance(myHero.pos, minion.pos) > AARange then
                if QDmg >= HealthPrediction:GetPrediction(minion, self.qSpell.Delay) then
                    Control.CastSpell(HK_Q, minion)
                end
            end
        end
    end
  end
end

function Nilah:QBuildings()
  if IsReady(_Q) and myHero.mana/myHero.maxMana >= Menu.Clear.Mana:Value() / 100 then
    if Menu.Clear.QT:Value() then
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

	if myHero.activeSpell.valid then return end

    local target = TargetSelector:GetTarget(self.qSpell.Range)
    if target and IsValid(target) then

        local Qdmg = self:getqDmg(target)
        local Edmg = self:geteDmg(target)		
        if IsReady(_Q) and Menu.KS.Q:Value() then
            if Qdmg > target.health and GetDistance(myHero.pos, target.pos) <= self.qSpell.Range then
                self:CastGGPred(HK_Q, target)
            end	
        end
        if IsReady(_E) and Menu.KS.E:Value() and not IsReady(_Q) then 
            if target.health <= Edmg and GetDistance(myHero.pos, target.pos) <= self.eSpell.Range then
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
	if Menu.Flee.E:Value() and IsReady(_E) then
		local FleeETarget, FleeEDistance = self:getFleeETarget()
		local distance = GetDistance(myHero.pos, mousePos)
		if FleeETarget and FleeEDistance < distance then
        		Control.CastSpell(HK_E, FleeETarget)
    		end
	end
end

function Nilah:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.qSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function Nilah:Draw()
    if Menu.Draw.Q:Value() and IsReady(_Q)then
        Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
    end
    if Menu.Draw.E:Value() and IsReady(_E)then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if Menu.Draw.R:Value() and IsReady(_R)then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

function Nilah:getFleeETarget()
    local FleeETarget = nil
    local FleeEDistance = math.huge
    
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and not hero.dead and (hero.isAlly or hero.isEnemy) and not hero.isMe then
                local distance = GetDistance(hero.pos, mousePos)
                local distance2 = GetDistance(myHero.pos, hero.pos)
                if distance < FleeEDistance and distance2 <= 550 then
                    FleeEDistance = distance
                    FleeETarget = hero
                end
            end
        end
    
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and (minion.isAlly or minion.isEnemy or minion.isJungle) and not minion.dead then
                local distance = GetDistance(minion.pos, mousePos)
                local distance2 = GetDistance(myHero.pos, minion.pos)
                if distance < FleeEDistance and distance2 <= 550 then
                    FleeEDistance = distance
                    FleeETarget = minion
                end
            end
        end

    return FleeETarget, FleeEDistance
end

--------------------------------------

class "Smolder"

function Smolder:__init()
	print("Marksmen Smolder Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	QSpell = { Delay = 0.25, Range = 550, Speed = 1800}
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 115, Range = 1200, Speed = 2000, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Radius = 300, Range = 3650, Speed = 1700, Collision = false}
end

function Smolder:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Combo:MenuElement({id = "Q2", name = "Use Q Ext", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RHp", name = "Use R| Self Hp <= x%", value = 50, min = 0, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| Aoe Hit Count >= x", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RRange", name = "Max R Range", value = 2600, min = 1500, max = 3650, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Q2", name = "Use Q Ext", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	-- Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q(Clear/Harass/LastHit Modes)", toggle = true, value = true})

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

function Smolder:OnPreAttack(args)
	local Mode = GetMode()
	local target = args.Target 
	if target.type == Obj_AI_Minion then
		if (Mode == "LaneClear" or Mode == "Harass" or Mode == "LastHit") and target.health < self:GetQDmg(target) and IsReady(_Q) then
			args.Process = false
		else
			args.Process = true
		end
	end
	
	if target.type == Obj_AI_Hero then
		if Menu.Misc.Q:Value() and IsReady(_Q) then
			args.Process = false
		else
			args.Process = true
		end
	end

	-- if HaveBuff(myHero, "SmolderE") then
		-- args.Process = false
	-- else
		-- args.Process = true
	-- end
end

function Smolder:OnTick()
	QSpell.Range = myHero.range + myHero.boundingRadius * 2
	if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Recalling() then
		return
	end

	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
	
	if myHero.activeSpell.valid then return end
	
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
	end
end

--[[function Smolder:OnPostAttack()
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

function Smolder:OneKeyCastR()
	local Rtarget = GetTarget(Menu.Combo.RRange:Value())
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		self:CastGGPred(HK_R, Rtarget)
	end
end

function Smolder:Auto()	
	if Menu.Misc.Wcc:Value() and IsReady(_W) then
		local enemies = ObjectManager:GetEnemyHeroes(WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsImmobile(target) then
				self:CastGGPred(HK_W, target)
			end
		end
	end
end

function Smolder:Combo()
	local Wtarget = GetTarget(WSpell.Range)
	if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
		if Menu.Combo.W:Value() and IsReady(_W) then
			self:CastGGPred(HK_W, Wtarget)	
		end
	end

	local Qtarget = GetTarget(QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			-- self:QLogic(target, Menu.Combo.Q2:Value())
			Control.CastSpell(HK_Q, Qtarget)
		end
	end

	local Rtarget = GetTarget(Menu.Combo.RRange:Value())
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		if Menu.Combo.R:Value() and IsReady(_R) then
			if myHero.health/myHero.maxHealth < Menu.Combo.RHp:Value()/100 and myHero.pos:DistanceTo(Rtarget.pos) < WSpell.Range then
				self:CastGGPred(HK_R, Rtarget)
			else
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, RSpell.Speed, RSpell.Delay, RSpell.Radius, {GGPrediction.COLLISION_ENEMYHERO}, nil)
				if collisionCount >= Menu.Combo.RCount:Value() then
					self:CastGGPred(HK_R, Rtarget)
				end
			end
		end
	end
end

function Smolder:Harass()
	if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local Wtarget = GetTarget(WSpell.Range)
		if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
			if Menu.Harass.W:Value() and IsReady(_W) then
				self:CastGGPred(HK_W, Wtarget)
			end
		end

		local Qtarget = GetTarget(QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				-- self:QLogic(target, Menu.Harass.Q2:Value())
				Control.CastSpell(HK_Q, Qtarget)
			end
		end
	end
end

function Smolder:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function Smolder:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local PassiveStacks = GetBuffData(myHero, "SmolderQPassive").stacks
	if level > 0 then
		local QDmg = (({15, 25, 35, 45, 55})[level] + myHero.totalDamage + 0.15 * myHero.ap) + ((0.4 * PassiveStacks) * (1 + 0.3 * myHero.critChance))
		if target.type == Obj_AI_Minion then
			QDmg = QDmg * 1.1
		end
		return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
	else
		return 0
	end
end

function Smolder:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local hp = HealthPrediction:GetPrediction(minion, QSpell.Delay + myHero.pos:DistanceTo(minion.pos)/QSpell.Speed)
				if self:GetQDmg(minion) > hp then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function Smolder:LaneClear()
	if IsUnderTurret(myHero) then return end
	if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(WSpell.Range)
			MathSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, WSpell.Speed, WSpell.Delay, WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function Smolder:JungleClear()
	if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = ObjectManager:GetEnemyMinions(WSpell.Range)
			MathSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(QSpell.Range)
			MathSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

--[[function Smolder:QLogic(target, UseQExt)
	if target == nil then return end
	local PassiveStacks = GetBuffData(myHero, "SmolderQPassive").stacks
	local Angles = (15 * (2 + MathFloor(0.01 * PassiveStacks+0.5)))/2
	if myHero.pos:DistanceTo(target.pos) <= QSpell.Range then
		Control.CastSpell(HK_Q, target)
	else
		if UseQExt then
			local ExtFirstTar = {}
			local minions = ObjectManager:GetEnemyMinions(QSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) then
					local middlePos = myHero.pos:Extended(minion.pos, myHero.pos:DistanceTo(minion.pos) + 500)
					local leftVector = (middlePos - minion.pos):Rotated(0, Angles * math.pi / 180, 0)
					local rightVector = (middlePos - minion.pos):Rotated(0, -Angles * math.pi / 180, 0)
					local targetVector = target.pos - minion.pos
					local crossLeft = targetVector:CrossProduct(leftVector)
					local crossRight = rightVector:CrossProduct(targetVector)
					if PassiveStacks >= 25 and minion.pos:DistanceTo(target.pos) < 200 then
						ExtFirstTar[#ExtFirstTar + 1] = {tar = minion}
					end
					if PassiveStacks >= 125 and crossLeft * crossRight > 0 and minion.pos:DistanceTo(target.pos) < 400 then
						ExtFirstTar[#ExtFirstTar + 1] = {tar = minion}
					end
				end
			end

			local enemies = ObjectManager:GetEnemyHeroes(QSpell.Range)
			for i, enemy in ipairs(enemies) do
				if IsValid(enemy) and enemy.networkID ~= target.networkID then
					local middlePos = myHero.pos:Extended(enemy.pos, myHero.pos:DistanceTo(enemy.pos) + 500)
					local leftVector = (middlePos - enemy.pos):Rotated(0, Angles * math.pi / 180, 0)
					local rightVector = (middlePos - enemy.pos):Rotated(0, -Angles * math.pi / 180, 0)
					local targetVector = target.pos - enemy.pos
					local crossLeft = targetVector:CrossProduct(leftVector)
					local crossRight = rightVector:CrossProduct(targetVector)
					if PassiveStacks >= 25 and enemy.pos:DistanceTo(target.pos) < 200 then
						ExtFirstTar[#ExtFirstTar + 1] = {tar = enemy}
					end
					if PassiveStacks >= 125 and crossLeft * crossRight > 0 and enemy.pos:DistanceTo(target.pos) < 400 then
						ExtFirstTar[#ExtFirstTar + 1] = {tar = enemy}
					end
				end
			end

			if #ExtFirstTar > 0 then
				MathSort(ExtFirstTar, function(a, b) return a.tar.type == Obj_AI_Hero and b.tar.type ~= Obj_AI_Hero end)
				Control.CastSpell(HK_Q, ExtFirstTar[1].tar)
			end
		end
	end
end]]

function Smolder:CastGGPred(spell, target)
	if spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end	
	end
end

function Smolder:Draw()
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
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 1500, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
	if Menu.Draw.Rmin:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, RSpell.Range, 1, Draw.Color(200, 14, 194, 255))
	end
end

-----------------------------------------

class "Zeri"

function Zeri:__init()
	print("Marksmen Zeri Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 40, Range = 750, Speed = 2600, Collision = false}
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 40, Range = 1200, Speed = 2500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 100, Range = 2500, Speed = 2500, Collision = false}
	ESpell = { Range = 300 }
	RSpell = { Delay = 0.25, Range = 825 }
end

function Zeri:LoadMenu()

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
	Menu.Clear:MenuElement({id = "QObj", name = "Use Q on Buildings & Wards", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q(Clear/Harass/LastHit Modes)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QhitChance", name = "Q | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "QRange", name = "Q range manual fine-tuning", value = 0, min = -50, max = 50, step = 5})
	Menu.Misc:MenuElement({id = "AAkills", name = "Use PassiveAA kills target when no Q", toggle = true, value = false})
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

function Zeri:OnPreAttack(args)
	local Mode = GetMode()
	local target = args.Target 
	if Mode == "Combo" then
		if Menu.Misc.ComboAA:Value() and not HaveBuff(myHero, "ZeriQPassiveReady") then
			args.Process = false
		else
			args.Process = true
		end
	end

	if Mode == "LaneClear" and target.type == Obj_AI_Minion then
		local AADamage = Damage:GetAutoAttackDamage(myHero, target)
		if Menu.Misc.ClearAA:Value() then
			args.Process = false
			if IsValid(target) and target.health < AADamage and Data:IsInAutoAttackRange(myHero, target) then
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount > 0 or not IsReady(_Q) then
					args.Process = true
				end
			end
		else
			args.Process = true
		end
	end
end

function Zeri:OnTick()
	if myHero.range == 550 then
		QSpell.Range = 800 + Menu.Misc.QRange:Value()
	else
		QSpell.Range = 750 + Menu.Misc.QRange:Value()
	end

	if HaveBuff(myHero, "ZeriR") then
		QSpell.Speed = 3400
	else
		QSpell.Speed = 2600
	end

	WSpell.Delay = MathMax(MathFloor((0.55 - 0.09 * (myHero.attackSpeed - 1)) * 100) / 100, 0.3)
	W2Spell.Delay = WSpell.Delay
	
	if myHero.dead or Game.IsChatOpen() or Recalling() then
		return
	end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
		self:AAkills()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LastHit()
		self:QObject()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	end
end

function Zeri:AAkills()
	if not Menu.Misc.AAkills:Value() or myHero.activeSpell.valid then return end

	local targets = ObjectManager:GetEnemyHeroes(Data:GetAutoAttackRange(myHero))
	for i, target in ipairs(targets) do
		if IsValid(target) then
			local AADamage = Damage:GetAutoAttackDamage(myHero, target)
			if target.health < AADamage and not IsReady(_Q) then
				_G.Control.Attack(target)
				return
            end
        end
    end
end

function Zeri:Combo()

	local Etarget = GetTarget(ESpell.Range + QSpell.Range - 50)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, Etarget)
		end
	end

	local Qtarget = GetTarget(QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(QSpell)
			QPrediction:GetPrediction(Qtarget, myHero)
			if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	end

	local Wtarget = GetTarget(W2Spell.Range)
	if Menu.Combo.W:Value() and IsReady(_W) then
		if IsValid(Wtarget) and Wtarget.pos2D.onScreen and myHero.pos:DistanceTo(Wtarget.pos) > QSpell.Range and GetEnemyCount(QSpell.Range, myHero.pos) == 0 then
			self:CastW(Wtarget)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local Count = 0
		for i, enemy in ipairs(GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(MathHuge, RSpell.Delay)
				if myHero.pos:DistanceTo(enemyPred) < RSpell.Range - 50 then
					Count = Count + 1
				end
			end
		end
		
		if Count >= Menu.Combo.RCount:Value() then
			Control.CastSpell(HK_R)
		end
	end
end

function Zeri:CastW(target)
	if myHero.activeSpell.valid then return end
	
	local pred = GGPrediction:SpellPrediction(W2Spell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		local castPos = pred.CastPosition
		local unitPos = pred.UnitPosition

		local wallColPos
		if GameIsWall == nil then
			wallColPos = MapPosition:getIntersectionPoint3D(myHero.pos, unitPos)
		else
			wallColPos = FindFirstWallCollision(myHero.pos, unitPos)
		end

		if wallColPos ~= nil then
			if myHero.pos:DistanceTo(wallColPos) < WSpell.Range and wallColPos:DistanceTo(unitPos) < 1400 then
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, wallColPos, WSpell.Speed, WSpell.Delay, WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount == 0 then
					Control.CastSpell(HK_W, castPos)
				end
			end
		else
			if not Menu.Combo.Wwall:Value() then
				local WPrediction = GGPrediction:SpellPrediction(WSpell)
				WPrediction:GetPrediction(target, myHero)
				if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
					Control.CastSpell(HK_W, WPrediction.CastPosition)
				end
			end
		end
	end
end

function Zeri:Harass()
	local Qtarget = GetTarget(QSpell.Range)
	if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(QSpell)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Misc.QhitChance:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	end
end

function Zeri:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.QHarass:Value() then
		self:Harass()
	end
end

-- function Zeri:GetAADmg(target)
	-- local level = myHero.levelData.lvl
	-- local baseDmg, bonusDmg, totalDmg
	-- if HaveBuff(myHero, "ZeriQPassiveReady") then
		-- baseDmg = 90 + (110 / 17) * (level - 1) * (0.7025 + 0.0175 * (level - 1)) + myHero.ap * 1.1
		-- bonusDmg = 0.01 * (1 + (14 / 17) * (level - 1) * (0.7025 + 0.0175 * (level - 1))) * target.maxHealth
	-- else
		-- baseDmg = 10 + (15 / 17) * (level - 1) * (0.7025 + 0.0175 * (level - 1)) + myHero.ap * 0.03
		-- if target.health < 60 + (90 / 17) * (level - 1) + myHero.ap * 0.18 then
			-- baseDmg = 60 + (90 / 17) * (level - 1) + myHero.ap * 0.18
		-- end
	-- end
	-- if target.team == 300 then
		-- totalDmg = MathMin(300, baseDmg + (bonusDmg or 0))
	-- else
		-- totalDmg = baseDmg + (bonusDmg or 0)
	-- end
	-- return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, totalDmg)
-- end

function Zeri:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local baseDmg = {15, 17, 19, 21, 23}
	local bonusDmg = {1.04, 1.08, 1.12, 1.16, 1.2}
	local QDmg = baseDmg[level] + bonusDmg[level] * myHero.totalDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function Zeri:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local Hp = HealthPrediction:GetPrediction(minion, myHero.pos:DistanceTo(minion.pos) / QSpell.Speed)
				local QDmg = self:GetQDmg(minion)
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
				if QDmg > Hp and collisionCount == 0 then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function Zeri:LaneClear()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		MathSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function Zeri:JungleClear()
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = ObjectManager:GetEnemyMinions(750)
		MathSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function Zeri:QObject()
    if not IsReady(_Q) or not Menu.Clear.QObj:Value() then return end

    local QRange = 750
    local targets = {}
    local turrets = ObjectManager:GetEnemyTurrets(QRange)
    local buildings = ObjectManager:GetEnemyBuildings(QRange + 380)
    local wards = ObjectManager:GetOtherEnemyMinions(QRange)

    for _, turret in pairs(turrets) do
        if turret.isTargetable then
            TableInsert(targets, turret)
        end
    end

    for _, building in pairs(buildings) do
        if building.type == Obj_AI_Nexus or (building.type == Obj_AI_Barracks and building.distance < QRange + 270) then
            TableInsert(targets, building)
        end
    end

    for _, ward in pairs(wards) do
        TableInsert(targets, ward)
    end

    if #targets > 0 then
        Control.CastSpell(HK_Q, targets[1])
    end
end

function Zeri:Draw()
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
		Draw.Circle(myHero.pos, QSpell.Range, 0.5, Draw.Color(255, 66, 244, 113))
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

-----------------------------------------

class "Lucian"

function Lucian:__init()
	print("Marksmen Lucian Loaded") 
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 500, Speed = MathHuge, Collision = false}
	Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 1100, Speed = MathHuge, Collision = false}
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 1000, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	ESpell = { Range = 425 }
	RSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 110, Range = 1200, Speed = 2800, Collision = false }
end

function Lucian:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Combo:MenuElement({id = "Echeck", name = "E-dash Point inWall / underTurret Check", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "EsafeCheck", name = "E-dash Point Safe Check", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "CheckRange", name = "Safe Check Range", value = 600, min = 300, max = 900, step = 50})
	Menu.Combo:MenuElement({id = "Edis", name = "Use E | To Side - hold distance", value = 500, min = 300, max = 700, step = 50})
	Menu.Combo:MenuElement({id = "Priority", name = "Combo Abilities Priority",	value = 1, drop = {"Q", "W", "E", "EW"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Clear.JungleClear:MenuElement({id = "Priority", name = "JungleClear Abilities Priority", value = 3, drop = {"Q", "W", "E"}})
	Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

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



function Lucian:OnTick()

	QSpell.Delay = 0.4 - 0.15 / 17 * (myHero.levelData.lvl - 1)
	Q2Spell.Delay = QSpell.Delay
	
	self:AntiGapcloser()

	target = GetTarget(1200)
	HavePassive = HaveBuff(myHero, "LucianPassiveBuff")
	Dashing = myHero.pathing.isDashing
	CastingR = HaveBuff(myHero, "LucianR")
	if lastQ + QSpell.Delay * 2 > Game.Timer() then return end
	if HavePassive or myHero.activeSpell.valid or Dashing or CastingR then return end
	
	if myHero.dead or Game.IsChatOpen() or Recalling() then return end

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

function Lucian:Combo()
	if IsValid(target) then
		if Menu.Combo.Priority:Value() == 1 then
			if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = Game.Timer()
			elseif Menu.Combo.W:Value() and (not Menu.Combo.Q:Value() or not IsReady(_Q)) and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
				self:CastW(target)
			elseif Menu.Combo.E:Value() and (not Menu.Combo.Q:Value() or not IsReady(_Q)) and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.Edis:Value() + ESpell.Range then
				self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
		end

		if Menu.Combo.Priority:Value() == 2 then
			if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
				self:CastW(target)
			elseif Menu.Combo.Q:Value() and (not Menu.Combo.W:Value() or not IsReady(_W)) and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = Game.Timer()
			elseif Menu.Combo.E:Value() and (not Menu.Combo.W:Value() or not IsReady(_W)) and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.Edis:Value() + ESpell.Range then
				self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
		end

		if Menu.Combo.Priority:Value() == 3 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.Edis:Value() + ESpell.Range then
				self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			elseif Menu.Combo.Q:Value() and (not Menu.Combo.E:Value() or not IsReady(_E)) and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = Game.Timer()
			elseif Menu.Combo.W:Value() and (not Menu.Combo.E:Value() or not IsReady(_E)) and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
				self:CastW(target)
			end
		end

		if Menu.Combo.Priority:Value() == 4 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.Edis:Value() + ESpell.Range then
				self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			elseif Menu.Combo.W:Value() and (not Menu.Combo.E:Value() or not IsReady(_E)) and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
				self:CastW(target)
			elseif Menu.Combo.Q:Value() and (not Menu.Combo.E:Value() or not IsReady(_E)) and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = Game.Timer()
			end
		end
		
		if Menu.Combo.QExt:Value() and IsReady(_Q) then 
			self:CastQExt(target)
			lastQ = Game.Timer()
		end
	end	
end

function Lucian:CastERange(target)
	local range = myHero.pos:DistanceTo(target.pos) < (myHero.range + myHero.boundingRadius) and 200 or 425
	return range
end

function Lucian:CastE(target, mode, range)
	local castPos;
	if mode == 1 then
		local targetPred = target:GetPrediction(MathHuge, 0.25)
		local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, targetPred, ESpell.Range, Menu.Combo.Edis:Value())
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
	
	if castPos then
		local underTurret = IsUnderTurret2(castPos)
		local inWall = IsWall(castPos)
		local numEnemies = GetEnemyCount(Menu.Combo.CheckRange:Value(), castPos)
		local numAllies = GetAllyCount(Menu.Combo.CheckRange:Value(), castPos)

		if Menu.Combo.Echeck:Value() and (underTurret or inWall) then return end
		if Menu.Combo.EsafeCheck:Value() and numEnemies >= 3 and numAllies < 3 then return end

		Control.CastSpell(HK_E, castPos)
	end
end

function Lucian:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function Lucian:CastQExt(target)
	local pred = GGPrediction:SpellPrediction(Q2Spell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(Menu.Misc.QhitChance:Value() + 1) then
		local unitPos = pred.UnitPosition
		
		local targetPos = myHero.pos:Extended(unitPos, GetDistance(myHero.pos, unitPos))

		local minions = ObjectManager:GetEnemyMinions(QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		local enemies = ObjectManager:GetEnemyHeroes(QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		
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
			local objPos = myHero.pos:Extended(obj.pos, GetDistance(myHero.pos, unitPos))
			if GetDistance(targetPos, objPos) < (Q2Spell.Radius/2 + target.boundingRadius) then
				Control.CastSpell(HK_Q, obj.pos)
			end
		end
	end
end

function Lucian:Harass()
	if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if IsValid(target) then
			if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
				lastQ = Game.Timer()
			end
			if Menu.Harass.QExt:Value() and IsReady(_Q) then 
				self:CastQExt(target)
				lastQ = Game.Timer()
			end
			if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < WSpell.Range then
				self:CastW(target)
			end
		end
	end
end

function Lucian:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function Lucian:LaneClear()
	if IsUnderTurret(myHero) then return end
	if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(WSpell.Range)
		MathSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q2Spell.Speed, Q2Spell.Delay, Q2Spell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.QCount:Value() then
						local obj = collisionObjects[1]
						if myHero.pos:DistanceTo(obj.pos) <= (QSpell.Range + myHero.boundingRadius + obj.boundingRadius) then
							Control.CastSpell(HK_Q, obj)
							lastQ = Game.Timer()
						end
					end
				end

				if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function Lucian:JungleClear()
	if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(WSpell.Range)
		MathSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Priority:Value() == 1 then
					if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = Game.Timer()
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 2 then
					if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = Game.Timer()
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 3 then
					if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						Control.CastSpell(HK_Q, minion)
						lastQ = Game.Timer()
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function Lucian:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < Data:GetAutoAttackRange(myHero, target) then
					--local castPos = Vector(myHero.pos) + (Vector(target.pathing.endPos) - Vector(target.pathing.startPos)):Normalized() * ESpell.Range
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * ESpell.Range
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function Lucian:Draw()
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

-----------------------------------------

class "Jinx"

function Jinx:__init()
	print("Marksmen Jinx Loaded") 
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	QSpell = { Range = 525 }
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 60, Range = 1450, Speed = 3300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 115, Range = 925, Speed = math.huge, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 140, Range = 12500, Speed = 1700, Collision = false}
end

function Jinx:LoadMenu()

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "WhitChance", name = "W | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "EhitChance", name = "E | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "RhitChance", name = "R | hitChance", value = 1, drop = {"Normal", "High"}})
	Menu.Misc:MenuElement({id = "Ecc", name = "Auto E On 'CC'", toggle = true, value = true})
	--Menu.Misc:MenuElement({id = "Etp", name = "Auto E On 'TP'", toggle = true, value = true})
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

function Jinx:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) then
		if GetMode() == "LaneClear" then
			if target.type == Obj_AI_Minion then
				if Menu.Clear.SpellFarm:Value() and IsReady(_Q) then
					if target.team ~= 300 and Menu.Clear.LaneClear.Q:Value() then
						if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 then
							if GetMinionCount(250, target.pos) >= Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(250, target.pos) < Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						else
							if HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						end
					end
					if target.team == 300 and Menu.Clear.JungleClear.Q:Value() then
						if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 then
							if GetMinionCount(250, target.pos) >= 2 and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(250, target.pos) < 2 and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						else
							if HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						end
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

function Jinx:OnTick()

	WSpell.Delay = math.max(math.floor((0.6 - 0.02 * ((myHero.attackSpeed - 1)/0.25)) * 100) / 100, 0.4)
	
	if myHero.dead or Game.IsChatOpen() or Recalling() then return end
	if myHero.activeSpell.valid then return end
	
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

function Jinx:Combo()
	local target = GetTarget(WSpell.Range)
	if IsValid(target) then
		if Menu.Combo.W:Value() and IsReady(_W) then
			if myHero.pos:DistanceTo(target.pos) > Data:GetAutoAttackRange(myHero, target) then
				self:CastW(target)
			end
		end
		if Menu.Combo.E:Value() and IsReady(_E) then
			if myHero.pos:DistanceTo(target.pos) < ESpell.Range then
				self:CastE(target)
			end
		end
	end
end

function Jinx:ComboQ()	
	local target = GetTarget(900)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			if myHero.pos:DistanceTo(target.pos) > self:QbaseRange(target) and HaveBuff(myHero, "jinxqicon") then
				if myHero.pos:DistanceTo(target.pos) <= self:QmaxRange(target) then
					Control.CastSpell(HK_Q)
				end
			else
				if myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
					Control.CastSpell(HK_Q)
				end
			end
	    end
	end
end

function Jinx:QbaseRange(unit)
	return QSpell.Range + myHero.boundingRadius + unit.boundingRadius
end

function Jinx:QmaxRange(unit)
	local level = myHero:GetSpellData(_Q).level
	return QSpell.Range + myHero.boundingRadius + unit.boundingRadius + ({80, 110, 140, 170, 200})[level]
end

function Jinx:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(Menu.Misc.WhitChance:Value() + 1) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function Jinx:CastE(target)
	local EPrediction = GGPrediction:SpellPrediction(ESpell)
	EPrediction:GetPrediction(target, myHero)
	if EPrediction:CanHit(Menu.Misc.EhitChance:Value() + 1) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function Jinx:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(Menu.Misc.RhitChance:Value() + 1) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function Jinx:Harass()
	if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(WSpell.Range)
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
	end
end

function Jinx:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

--[[ function Jinx:LaneClear()
	if IsUnderTurret(myHero) then return end
	if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = ObjectManager:GetEnemyMinions(QSpell.Range + 130)
			MathSort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
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

function Jinx:JungleClear()
	if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		local minions = ObjectManager:GetEnemyMinions(QSpell.Range + 130)
		MathSort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
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

function Jinx:AutoE()
	if Menu.Misc.Ecc:Value() and IsReady(_E) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= ESpell.Range then
				if
					GetImmobileDuration(target) > 0.5 --cc
					or IsInvulnerable(target) --zhonya
					or HaveBuff(target, "Meditate") --yi w
					or HaveBuff(target, "ChronoRevive") --zilean r
				then
					Control.CastSpell(HK_E, target)
				end

				for j, slot in ipairs(slots) do
					local Data = target:GetSpellData(slot)
					if Data.name == "GuardianAngel" and Data.currentCd == 0 and target.health == 0 then --G A
						Control.CastSpell(HK_E, target)
					end
				end
			end
		end
	end
	
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = ObjectManager:GetEnemyHeroes(ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_E, target.pathing.endPos)
				end
			end	
		end
	end

	--[[ if Menu.Misc.Etp:Value() and IsReady(_E) then
		for i = GameParticleCount(), 1, -1 do
			local par = GameParticle(i)
			if
				par and par.pos:DistanceTo(myHero.pos) <= ESpell.Range
 				and ((par.name:lower():find("teleport") and par.name:lower():find("_red")) or par.name:lower():find("gatemarker_red")) -- TP or TF-R
			then
				Control.CastSpell(HK_W, par)
				break
			end
		end
	end ]]
end

function Jinx:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(Menu.Misc.Rmax:Value())
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function Jinx:KillSteal()
	local enemies = ObjectManager:GetEnemyHeroes(Menu.Misc.Rmax:Value())
	for i, enemy in ipairs(enemies) do
		if enemy and not enemy.dead and enemy.pos2D.onScreen then
			if Menu.KillSteal.W:Value() and IsReady(_W) and lastR + 1500 < GetTickCount() then
				local Wdmg = self:GetWDmg(enemy)
				if Wdmg >= enemy.health + enemy.hpRegen * 1 then
					if myHero.pos:DistanceTo(enemy.pos) < WSpell.Range then
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

function Jinx:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({10, 60, 110, 160, 210})[level] + 1.6 * myHero.totalDamage
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
end

function Jinx:GetRDmg(target)
	local d = target.pos:DistanceTo(myHero.pos)
	local level = myHero:GetSpellData(_R).level
	local RDmg = (({325, 475, 625})[level] + 0.165 * myHero.bonusDamage) * (0.06 * math.min(math.floor(d/100), 15) + 0.1) + ({0.25, 0.3, 0.35})[level] * (target.maxHealth - target.health)
	return Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, RDmg)
end

function Jinx:Draw()
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
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end