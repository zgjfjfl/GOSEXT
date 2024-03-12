local Version = 2024.05

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
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
			print("SimpleMarksmen: Found update! Downloading...")
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("SimpleMarksmen: Successfully updated. Press 2x F6!")
        end

    end
    
    AutoUpdate()

end

local Heroes = {"Nilah", "Smolder"}

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
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 90 then 
		return true  
	end
	return false
end

---------------------------------

Menu = MenuElement({type = MENU, id = "Marksmen "..myHero.charName, name = "Marksmen "..myHero.charName})
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
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 125, Range = 1200, Speed = 2000, Collision = false}
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
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_W, target)	
		end
	end
	
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			-- self:QLogic(target, Menu.Combo.Q2:Value())
			Control.CastSpell(HK_Q, target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local Rtarget = GetTarget(Menu.Combo.RRange:Value())
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
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
		if Menu.Harass.W:Value() and IsReady(_W) then
			local target = GetTarget(WSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_W, target)
			end
		end

		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				-- self:QLogic(target, Menu.Harass.Q2:Value())
				Control.CastSpell(HK_Q, target)
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
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+48, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+48, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+68, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+68, Draw.Color(200, 242, 120, 34))
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

