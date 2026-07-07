local Version = 1.09

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local lastR2 = 0
local lastWE = 0
local lastEQ = 0

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7 }

local StationaryCastSpells = {
	AurelionSolQ = true, -- Aurelion Sol Q | Breath of Light
	BelvethE = true, -- Bel'Veth E | Royal Maelstrom
	BriarE = true, -- Briar E | Chilling Scream
	CaitlynR = true, -- Caitlyn R | Ace in the Hole
	FiddleSticksW = true, -- Fiddlesticks W | Bountiful Harvest
	IreliaW = true, -- Irelia W | Defiant Dance
	ReapTheWhirlwind = true, -- Janna R | Monsoon
	KarthusFallenOne = true, -- Karthus R | Requiem
	KatarinaR = true, -- Katarina R | Death Lotus
	MalzaharR = true, -- Malzahar R | Nether Grasp
	Meditate = true, -- Master Yi W | Meditate
	MissFortuneBulletTime = true, -- Miss Fortune R | Bullet Time
	NunuR = true, -- Nunu R | Absolute Zero
	recall = true, -- Recall
	SionQ = true, -- Sion Q | Decimating Smash
	SuperRecall = true, -- Super Recall
	VelkozR = true, -- Vel'Koz R | Life Form Disintegration Ray
	XerathArcanopulseChargeUp = true, -- Xerath Q | Arcanopulse
	XerathLocusOfPower2 = true, -- Xerath R | Rite of the Arcane
	JhinR = true, -- Jhin R | Curtain Call
}

local function FacingMe(unit)
	local V = Vector((unit.pos - myHero.pos))
	local D = Vector(unit.dir)
	local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
	if math.abs(Angle) < 60 then 
		return true
	end
	return false
end

local function IsStationaryCasting(unit)
	local spell = unit.activeSpell
	return spell and spell.valid and spell.name and StationaryCastSpells[spell.name]
end

---------------------------------

class "zgHwei"

function zgHwei:__init()		 
	print("Zgjfjfl AIO - Hwei Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QQSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 970, Radius = 70, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.QWSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.0, Range = 1900, Radius = 225, Speed = math.huge, Collision = false}
	self.QESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Range = 1250, Radius = 200, Speed = 800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.EQSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1050, Radius = 70, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}}
	self.EWSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.45, Range = 900, Radius = 350, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.EESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.35, Range = 925, Radius = 125, Speed = math.huge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Range = 1300, Radius = 90, Speed = 1400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.QEEndPos = nil
	self.QEStartPos = nil
	self.castQETime = 0
	self.EEPos = nil
	self.castEETime = 0
end

function zgHwei:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q| Combo", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E| Combo(Facing EQ or EE)", value = true})
	Menu.Combo:MenuElement({id = "QW", name = "Use QW| Alone", value = true})
	Menu.Combo:MenuElement({id = "QWHp", name = "Alone QW| target isolated and Hp < X%", value = 50, min = 0, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "aoeQE", name = "Use QE| AOE", value = true})
	Menu.Combo:MenuElement({id = "aoeCount", name = "Use QE| AOE CanHit Counts >= ", value = 2, min = 2, max = 5, step = 1})
	Menu.Combo:MenuElement({ id = "smQW", name = "Semi-manual QW Key", key = string.byte("M")})
	Menu.Combo:MenuElement({ id = "smR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q| Harass", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E| Harass(EE Priority)", value = true})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "QQ", name = "Auto QQ kills", value = true})
	Menu.Misc:MenuElement({type = MENU, id = "AutoWE", name = "Auto WE"})
	Menu.Misc.AutoWE:MenuElement({id = "Enabled", name = "Enable Auto WE", value = true})
	Menu.Misc.AutoWE:MenuElement({id = "Q", name = "Before Q", value = true})
	Menu.Misc.AutoWE:MenuElement({id = "Attack", name = "Before AA", value = true})
	Menu.Misc:MenuElement({type = MENU, id = "AutoEQ", name = "Auto EQ"})
	Menu.Misc.AutoEQ:MenuElement({id = "Enabled", name = "Enable Auto EQ", value = true})
	Menu.Misc.AutoEQ:MenuElement({id = "Gapcloser", name = "On Gapcloser Target", value = true})
	Menu.Misc.AutoEQ:MenuElement({id = "Melee", name = "On Melee Target", value = true})
	Menu.Misc.AutoEQ:MenuElement({id = "HardCC", name = "On Hard CC Target", value = true})
	Menu.Misc:MenuElement({type = MENU, id = "AutoQW", name = "Auto QW"})
	Menu.Misc.AutoQW:MenuElement({id = "Enabled", name = "Enable Auto QW", value = true})
	Menu.Misc.AutoQW:MenuElement({id = "Kill", name = "On Killable Target", value = true})
	Menu.Misc.AutoQW:MenuElement({id = "RTarget", name = "On Hwei R Target", value = true})
	Menu.Misc.AutoQW:MenuElement({id = "HardCC", name = "On Hard CC Target", value = true})
	Menu.Misc.AutoQW:MenuElement({id = "Stationary", name = "On Stationary Cast Target", value = true})
	Menu.Misc.AutoQW:MenuElement({id = "Slow", name = "On Slow Target", value = false})
	Menu.Misc:MenuElement({type = MENU, id = "AutoWW", name = "Auto WW"})
	Menu.Misc.AutoWW:MenuElement({id = "Enabled", name = "Enable Auto WW", value = true})
	Menu.Misc.AutoWW:MenuElement({id = "Poison", name = "On Poison Ally", value = true})
	Menu.Misc.AutoWW:MenuElement({id = "EnemyAround", name = "On Low HP Ally Near Enemy", value = true})
	Menu.Misc:MenuElement({type = MENU, id = "AutoEW", name = "Auto EW"})
	Menu.Misc.AutoEW:MenuElement({id = "Enabled", name = "Enable Auto EW", value = true})
	Menu.Misc.AutoEW:MenuElement({id = "RTarget", name = "On Hwei R Target", value = true})
	Menu.Misc.AutoEW:MenuElement({id = "Invulnerable", name = "On Invulnerable Target", value = true})
	Menu.Misc:MenuElement({type = MENU, id = "AutoR", name = "Auto R"})
	Menu.Misc.AutoR:MenuElement({id = "Enabled", name = "Enable Auto R", value = true})
	Menu.Misc.AutoR:MenuElement({id = "HardCC", name = "On Hard CC or EE Target", value = true})
	Menu.Misc.AutoR:MenuElement({id = "RHP", name = "Hard CC HP > X%", value = 50, min = 0, max = 100, step = 5})
	Menu.Misc.AutoR:MenuElement({id = "AOE", name = "On AOE Target", value = true})
	Menu.Misc.AutoR:MenuElement({id = "RCount", name = "AOE Count >= X", value = 3, min = 1, max = 5, step = 1})
	Menu.Misc:MenuElement({id = "Flee", name = "Flee WQ(flee mode)", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "QE", name = "Use QE", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QECount", name = "If QE CanHit Counts >= ", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "QE", name = "Use QE", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "WE", name = "Use WE", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "EE", name = "Use EE", value = false})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "QQ", name = "[QQ] Range", value = false})
	Menu.Draw:MenuElement({id = "QW", name = "[QW] Range", value = false})
	Menu.Draw:MenuElement({id = "QE", name = "[QE] Range", value = false})
	Menu.Draw:MenuElement({id = "EQ", name = "[EQ] Range", value = false})
	Menu.Draw:MenuElement({id = "EE", name = "[EE] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
end

local cantCastTime = 0
local isWaiting = false
function zgHwei:Tick()
	if ShouldWait() then return end
	self:CastSpellPos()
	if not self:CanCast() then
		if not isWaiting then
			isWaiting = true
			cantCastTime = GetTickCount()
		end
	else
		isWaiting = false
	end
	if isWaiting then
		if GetMode() ~= nil or Menu.Combo.smR:Value() then
			if GetTickCount() - cantCastTime > 600 then
				if lastR + 300 < GetTickCount() then
					if Control.CastSpell(HK_R) then
						lastR = GetTickCount()
					end
				end
			end
		end
	end
	if IsCasting() then return end
	self:AntiGapcloser()
	self:Auto()
	self:smR()
	self:smQW()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgHwei:CanCast()
	if myHero:GetSpellData(_R).name == "HweiWashBrush" then
		return false
	end
	return true
end

function zgHwei:CastSpellPos()
	if myHero.activeSpell.name == "HweiQE" then
		if self.castQETime == 0 then
			self.castQETime = Game.Timer()
		end
		self.QEStartPos = myHero.activeSpell.startPos
		self.QEEndPos = myHero.pos:Extended(myHero.activeSpell.placementPos, self.QESpell.Range)
	end
	if Game.Timer() - self.castQETime > 2.25 then
		self.castQETime = 0
		self.QEStartPos = nil
		self.QEEndPos = nil
	end
	if myHero.activeSpell.name == "HweiEE" then
		if self.castEETime == 0 then
			self.castEETime = Game.Timer()
		end
		self.EEPos = {Vector(myHero.activeSpell.placementPos), myHero.pos}
	end
	if Game.Timer() - self.castEETime > 0.75 then
		self.castEETime = 0
		self.EEPos = nil
	end
end

function zgHwei:smR()
	if Menu.Combo.smR:Value() and IsReady(_R) then
		if self:CanCast() then
			local target = GetTarget(self.RSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_R, target)
			end
		else
			if lastR + 300 < GetTickCount() then 
				if Control.CastSpell(HK_R) then
					lastR = GetTickCount()
				end
			end
		end
	end
end

function zgHwei:smQW()
	if Menu.Combo.smQW:Value() and IsReady(_Q) and self:CanCast() then
		local target = GetTarget(self.QWSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred('QW', target)
		end
	end
end

function zgHwei:OnPreAttack(args)
	if not self:CanCast() then
		args.Process = false
		return
	end
	local mode = GetMode()
	if (mode == "Combo" or mode == "Harass") and args.Target.type == Obj_AI_Hero then
		local useQ = Menu[mode].Q:Value()
		local useE = Menu[mode].E:Value()
		if (IsReady(_Q) and useQ or IsReady(_E) and useE) and self:CanCast() then
			args.Process = false
		end
	end
end

function zgHwei:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
	if target and (target.type == Obj_AI_Hero or target.type == Obj_AI_Turret or target.type == Obj_AI_Barracks or target.type == Obj_AI_Nexus) then
		self:CastWE()
	end
end

function zgHwei:GetRBuffTarget()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QWSpell.Range)) do
		if IsValid(target) and HaveBuff(target, "HweiR") then
			return target
		end
	end
	return nil
end

function zgHwei:AntiGapcloser()
	if Menu.Misc.AutoEQ.Enabled:Value() and IsReady(_E) and self:CanCast() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.EQSpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) then
				if Menu.Misc.AutoEQ.Gapcloser:Value() and target.pathing.isDashing then
					local endPos = Vector(target.pathing.endPos)
					if myHero.pos:DistanceTo(endPos) < 400 and FacingMe(target) then
						self:CastGGPred('EQ', target)
						return
					end
				end
				local shouldCastHardCC = Menu.Misc.AutoEQ.HardCC:Value() and IsHardCC(target) and GetEnemyCount(500, myHero.pos) == 0
				local shouldCastMelee = Menu.Misc.AutoEQ.Melee:Value() and myHero.pos:DistanceTo(target.pos) < 350
				if shouldCastHardCC or shouldCastMelee then
					if GetEnemyCount(500, target.pos) > 1 then
						self:CastGGPred('EE', target)
					else
						self:CastGGPred('EQ', target)
					end
					return
				end
			end
		end
	end
end

function zgHwei:GetAutoQWTarget()
	if not Menu.Misc.AutoQW.Enabled:Value() then return nil end
	local rTarget = self:GetRBuffTarget()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QWSpell.Range)
	local killTarget, hardCCTarget, stationaryTarget, slowTarget = nil, nil, nil, nil

	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and (target.distance > self.QQSpell.Range or self:IsQQBlocked(target)) then
			local isRTarget = rTarget and target.networkID == rTarget.networkID
			local isKill = Menu.Misc.AutoQW.Kill:Value() and (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 2) < self:GetQWDmg(target)
			if isKill and GetEnemyCount(500, myHero.pos) < 2 then
				killTarget = target
				if not isRTarget then
					break
				end
			elseif not isRTarget and GetEnemyCount(500, myHero.pos) == 0 then
				if Menu.Misc.AutoQW.HardCC:Value() and hardCCTarget == nil and IsHardCC(target) then
					hardCCTarget = target
				elseif Menu.Misc.AutoQW.Stationary:Value() and stationaryTarget == nil and IsStationaryCasting(target) then
					stationaryTarget = target
				elseif Menu.Misc.AutoQW.Slow:Value() and slowTarget == nil and IsSlow(target) then
					slowTarget = target
				end
			end
		end
	end
	if killTarget and (not rTarget or killTarget.networkID ~= rTarget.networkID) then
		return killTarget
	end
	if Menu.Misc.AutoQW.RTarget:Value() and rTarget and IsValid(rTarget) and rTarget.pos2D.onScreen and (rTarget.distance > 800 or self:IsQQBlocked(rTarget)) then
		local buff, buffData = GetBuffData(rTarget, "HweiR")
		if buff and buffData.duration < 0.9 and self:GetRDmg(rTarget) < rTarget.health + rTarget.shieldAD + rTarget.shieldAP + rTarget.hpRegen * 2 then
			return rTarget
		end
	end
	if hardCCTarget then return hardCCTarget end
	if stationaryTarget then return stationaryTarget end
	if slowTarget then return slowTarget end
	return nil
end

function zgHwei:Auto()
	if Menu.Misc.QQ:Value() and IsReady(_Q) and self:CanCast() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QQSpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 1) < self:GetQQDmg(target) then
				self:CastGGPred('QQ', target)
				break
			end
		end
	end
	if Menu.Misc.AutoR.Enabled:Value() and IsReady(_R) and self:CanCast() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		table.sort(enemies, function(a, b) return a.distance < b.distance end)
		for _, target in ipairs(enemies) do
			if IsValid(target) then
				local aoeTarget = Menu.Misc.AutoR.AOE:Value() and GetEnemyCount(250, target.pos) >= Menu.Misc.AutoR.RCount:Value() and target.distance < 800
				local hardCCTarget = Menu.Misc.AutoR.HardCC:Value() and (IsHardCC(target) or self:IsUnitInEE(target)) and target.health > target.maxHealth * (Menu.Misc.AutoR.RHP:Value() / 100)
				if aoeTarget or hardCCTarget then
					self:CastGGPred(HK_R, target)
				end
			end
		end
	end
	if Menu.Misc.AutoQW.Enabled:Value() and IsReady(_Q) and self:CanCast() and lastR2 < GetTickCount() then
		local qwTarget = self:GetAutoQWTarget()
		if qwTarget ~= nil then
			self:CastGGPred('QW', qwTarget)
		end
	end
	if Menu.Misc.AutoWW.Enabled:Value() and IsReady(_W) and self:CanCast() then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(850)
		for _, ally in ipairs(allies) do
			if IsValid(ally) then
				local poisonTarget = Menu.Misc.AutoWW.Poison:Value() and IsPoison(ally)
				local enemyAroundTarget = Menu.Misc.AutoWW.EnemyAround:Value() and GetEnemyCount(300, ally.pos) >= 1 and ally.health/ally.maxHealth < 0.5
				if poisonTarget or enemyAroundTarget then
					self:CastWW(ally)
					break
				end
			end
		end
	end
	if Menu.Misc.AutoEW.Enabled:Value() and IsReady(_E) and self:CanCast() then
		for _, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= self.EWSpell.Range then
				if Menu.Misc.AutoEW.RTarget:Value() and HaveBuff(target, "HweiR") then
					if self:CastGGPred('EW', target) then
						return
					end
				end
				if Menu.Misc.AutoEW.Invulnerable:Value() then
					if IsInvulnerable(target) or HaveBuff(target, "ChronoRevive") or HaveBuff(target, "LissandraRSelf") then
						if Control.CastSpell({HK_E, HK_W}, target) then
							return
						end
					end
					for _, slot in ipairs(ItemSlots) do
						local spellData = target:GetSpellData(slot)
						if spellData.name == "GuardianAngel" and spellData.currentCd == 0 and not target.alive then
							if Control.CastSpell({HK_E, HK_W}, target) then
								return
							end
						end
					end
				end
			end
		end
	end
end

function zgHwei:Isolated(target)
	local range = self.QWSpell.Radius + target.boundingRadius
	if GetEnemyCount(range, target.pos) == 1 and GetMinionCount(range, target.pos) == 0 then
		return true
	end
	return false
end

function zgHwei:GetQQDmg(target)
	local spellData = myHero:GetSpellData(_Q)
	local level = spellData.name == "HweiQ" and spellData.level or 0
	if level == 0 then return 0 end
	local QQDmg = ({50, 80, 110, 140, 170})[level] + 0.8 * myHero.ap + ({3, 4, 5, 6, 7})[level] / 100 * target.maxHealth
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		QQDmg = QQDmg * 1.2
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QQDmg)
end

function zgHwei:GetQWDmg(target)
	local spellData = myHero:GetSpellData(_Q)
	local level = spellData.name == "HweiQ" and spellData.level or 0
	if level == 0 then return 0 end
	local missingHp = 1 - (target.health / target.maxHealth)
	local QWDmg = ({60, 85, 110, 135, 160})[level] + 0.30 * myHero.ap
	local multiplier = (({2.0, 2.375, 2.75, 3.125, 3.5})[level] - 1) * missingHp
	if IsHardCC(target) or self:Isolated(target) then
		QWDmg = QWDmg * (1 + multiplier)
	end
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		QWDmg = QWDmg * 1.2
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QWDmg)
end

function zgHwei:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	local baseDmg = ({200, 325, 450})[level] + 0.8 * myHero.ap
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		baseDmg = baseDmg * 1.2
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, baseDmg)
end

function zgHwei:IsUnitInEE(unit)
	if IsValid(unit) then
		if(self.EEPos and self.EEPos[1]) then
			local ePos = self.EEPos[1]
			local line = Vector(self.EEPos[2] - ePos):Normalized()
			local lineL = Vector(line.z, line.y, -line.x)
			local lineR = Vector(line.z, line.y, -line.x)
			local rotLineL1 = lineL:Rotated(0, math.rad(20), 0)*320 + ePos
			local rotLineR1 = lineR:Rotated(0, math.rad(160), 0)*320 + ePos
			local rotLineL2 = lineL:Rotated(0, math.rad(-20), 0)*320 + ePos
			local rotLineR2 = lineR:Rotated(0, math.rad(200), 0)*320 + ePos

			local predPos = unit:GetPrediction(math.huge, 0.25)
			if predPos == nil then predPos = unit.pos end

			local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(predPos, rotLineL1, rotLineR2)
			if isOnSegment and GGPrediction:IsInRange(point, predPos, self.EESpell.Radius) then
				return true
			end

			local point2, isOnSegment2 = GGPrediction:ClosestPointOnLineSegment(predPos, rotLineR1, rotLineL2)
			if isOnSegment2 and GGPrediction:IsInRange(point2, predPos, self.EESpell.Radius) then
				return true
			end
		end
	end
	return false
end

function zgHwei:IsQQBlocked(target)
	local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(
		myHero.pos, target.pos, self.QQSpell.Speed, self.QQSpell.Delay, self.QQSpell.Radius, 
		{GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}, target.networkID)
	if isWall then
		return true
	elseif collisionCount > 0 then
		local firstCollision = collisionObjects[1]
		if firstCollision.pos:DistanceTo(myHero.pos) < 885 and firstCollision.pos:DistanceTo(target.pos) > 150 then
			return true
		end
	end
	return false
end

function zgHwei:CastGGPred(spell, target)
	if spell == 'QQ' then
		local QQPrediction = GGPrediction:SpellPrediction(self.QQSpell)
		QQPrediction:GetPrediction(target, myHero)
		if QQPrediction:CanHit(3) then
			local castPos = QQPrediction.CastPosition
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(
				myHero.pos, castPos, self.QQSpell.Speed, self.QQSpell.Delay, self.QQSpell.Radius, 
				{GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount == 0 or collisionObjects[1].pos:DistanceTo(myHero.pos) > 885 or collisionObjects[1].pos:DistanceTo(castPos) < 150 then
				if self.EEPos and self:IsUnitInEE(target) then
					castPos = self.EEPos[1]
				end
				return self:CastSpellWithWE({HK_Q, HK_Q}, castPos)
			end
		end
		return false
	elseif spell == 'QW' then
		if self.EEPos and Game.Timer() - self.castEETime <= 0.627 then
			return false
		end
		local QWPrediction = GGPrediction:SpellPrediction(self.QWSpell)
		QWPrediction:GetPrediction(target, myHero)
		if QWPrediction:CanHit(3) then
			return self:CastSpellWithWE({HK_Q, HK_W}, QWPrediction.CastPosition)
		end
		return false
	elseif spell == 'QE' then
		local QEPrediction = GGPrediction:SpellPrediction(self.QESpell)
		QEPrediction:GetPrediction(target, myHero)
		if QEPrediction:CanHit(3) then
			local castPos = QEPrediction.CastPosition
			if self.EEPos and self:IsUnitInEE(target) then
				castPos = self.EEPos[1]
			end
			return self:CastSpellWithWE({HK_Q, HK_E}, castPos)
		end
		return false
	elseif spell == 'EQ' then
		local EQPrediction = GGPrediction:SpellPrediction(self.EQSpell)
		EQPrediction:GetPrediction(target, myHero)
		if EQPrediction:CanHit(3) then
			local castPos = EQPrediction.CastPosition
			if Control.CastSpell({HK_E, HK_Q}, castPos) then
				local distance = GetDistance(myHero.pos, castPos)
				local flightTime = (self.EQSpell.Delay + distance / self.EQSpell.Speed) * 1000
				lastEQ = GetTickCount() + flightTime + 70
				return true
			end
		end
		return false
	elseif spell == 'EW' then
		local EWPrediction = GGPrediction:SpellPrediction(self.EWSpell)
		EWPrediction:GetPrediction(target, myHero)
		if EWPrediction:CanHit(3) then
			return Control.CastSpell({HK_E, HK_W}, EWPrediction.UnitPosition)
		end
		return false
	elseif spell == 'EE' then
		local EEPrediction = GGPrediction:SpellPrediction(self.EESpell)
		EEPrediction:GetPrediction(target, myHero)
		if EEPrediction:CanHit(3) then
			local castPosdistance = GetDistanceSqr(myHero.pos, Vector(EEPrediction.CastPosition))
			local unitPositiondistance = GetDistanceSqr(myHero.pos, Vector(EEPrediction.UnitPosition))
			local castPos = castPosdistance > unitPositiondistance and Vector(EEPrediction.CastPosition) or Vector(EEPrediction.UnitPosition)
			local leftCastPos = castPos + (myHero.pos - castPos):Rotated(0, -55 * math.pi / 180, 0):Normalized() * 160
			local rightCastPos = castPos + (myHero.pos - castPos):Rotated(0, 55 * math.pi / 180, 0):Normalized() * 160
			local leftEnemies = GetEnemyCount(320, leftCastPos)
			local rightEnemies = GetEnemyCount(320, rightCastPos)
			castPos = (leftEnemies > rightEnemies and leftCastPos) or 
						(rightEnemies > leftEnemies and rightCastPos) or 
						(myHero.pos:DistanceTo(leftCastPos) < myHero.pos:DistanceTo(rightCastPos) and leftCastPos or rightCastPos)
			if self.QEEndPos and self.QEStartPos then
				local leftPoint, leftIsOnSegment = GGPrediction:ClosestPointOnLineSegment(leftCastPos, self.QEStartPos, self.QEEndPos)
				local leftDistance = GetDistanceSqr(leftCastPos, leftPoint)
				local rightPoint, rightIsOnSegment = GGPrediction:ClosestPointOnLineSegment(rightCastPos, self.QEStartPos, self.QEEndPos)
				local rightDistance = GetDistanceSqr(rightCastPos, rightPoint)
				castPos = leftDistance < rightDistance and leftCastPos or rightCastPos
			end
			if castPos:DistanceTo() <= 800 then
				return Control.CastSpell({HK_E, HK_E}, castPos)
			end
		end
		return false
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			local castPos = RPrediction.CastPosition
			if self.EEPos and self:IsUnitInEE(target) then
				castPos = self.EEPos[1]
			end
			if Control.CastSpell(HK_R, castPos) then
				local distance = GetDistance(myHero.pos, castPos)
				local flightTime = (self.RSpell.Delay + distance / self.RSpell.Speed) * 1000
				lastR2 = GetTickCount() + flightTime + 200
				return true
			end
		end
		return false
	end
	return false
end

function zgHwei:CastWW(target)
	if target.distance > 650 then
		Control.CastSpell({HK_W, HK_W}, myHero.pos:Extended(target.pos, 650))
	else
		Control.CastSpell({HK_W, HK_W}, target)
	end
end

function zgHwei:CastQEAOE()
	local SpellPred = GGPrediction:SpellPrediction(self.QESpell)
	local aoeResults = SpellPred:GetAOEPrediction(myHero)
	if #aoeResults == 0 then
		return false
	end
	for i, result in ipairs(aoeResults) do
		if result.Count >= Menu.Combo.aoeCount:Value() and GetDistance(myHero.pos, result.CastPosition) < self.QESpell.Range - 200 then
			if self.EEPos == nil or GetDistance(self.EEPos[1], result.CastPosition) < 320 then
				return self:CastSpellWithWE({HK_Q, HK_E}, result.CastPosition)
			end
		end
	end
	return false
end

function zgHwei:CastWE()
    if Menu.Misc.AutoWE.Enabled:Value() and Menu.Misc.AutoWE.Attack:Value() and self:CanCast() and IsReady(_W) and lastWE + 300 < GetTickCount() then
        Control.KeyDown(HK_W)
        Control.KeyUp(HK_W)
        Control.KeyDown(HK_E)
        Control.KeyUp(HK_E)
        lastWE = GetTickCount()
    end
end

function zgHwei:CastSpellWithWE(spellKeys, castPos)
    local spell = (spellKeys[1] == HK_Q and _Q) or (spellKeys[1] == HK_E and _E) or (spellKeys == HK_R and _R) or nil
    if spell and Menu.Misc.AutoWE.Enabled:Value() and Menu.Misc.AutoWE.Q:Value() and self:CanCast() and IsReady(_W) and lastWE + 300 < GetTickCount() then
        if myHero.mana > (myHero:GetSpellData(spell).mana + myHero:GetSpellData(_W).mana) then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
            Control.KeyDown(HK_E)
            Control.KeyUp(HK_E)
			lastWE = GetTickCount()
        end
    end
	return Control.CastSpell(spellKeys, castPos)
end

function zgHwei:Combo()
	if not self:CanCast() then return end
	if Menu.Combo.aoeQE:Value() and IsReady(_Q) then
		self:CastQEAOE()
	end
	if IsReady(_E) and Menu.Combo.E:Value() then
		local target = GetTarget(self.EESpell.Range)
		if IsValid(target) then
			local enemyCount = GetEnemyCount(500, target.pos)
			if enemyCount >= 2 or not FacingMe(target) or not self:CastGGPred('EQ', target) then
				self:CastGGPred('EE', target)
			end
		end
	end
	if IsReady(_Q) and Menu.Combo.Q:Value() and lastEQ < GetTickCount() and lastR2 < GetTickCount() then
		local target, isRTarget = GetTarget(self.QQSpell.Range), false
		local rTarget = self:GetRBuffTarget()
		if rTarget ~= nil then
			if rTarget.distance <= 800 then
				target, isRTarget = rTarget, true
			elseif GetEnemyCount(500, myHero.pos) == 0 then
				return
			end
		end
		if IsValid(target) and (isRTarget or not IsReady(_E) or not Menu.Combo.E:Value()) then
			if isRTarget or (IsHardCC(target) and target.distance <= 800) or (target.distance <= myHero.range and target.distance >= 350) then
				if self:CastGGPred('QE', target) then return end
			elseif self:CastGGPred('QQ', target) then
				return
			elseif self:IsUnitInEE(target) then
				if self:CastGGPred('QE', target) then return end
			end
		end
	end
	if IsReady(_Q) and Menu.Combo.QW:Value() and lastR2 < GetTickCount() then
		local target = GetTarget(self.QWSpell.Range)
		if IsValid(target) and target.distance > self.QQSpell.Range and self:GetAutoQWTarget() == nil and self:GetRBuffTarget() == nil then
			local isLowHealth = target.health / target.maxHealth <= Menu.Combo.QWHp:Value()/100
			local isIsolated = self:Isolated(target)
			if ((isLowHealth and isIsolated) or HaveBuff(target, "hweisignature")) and GetEnemyCount(500, myHero.pos) == 0 then
				if self:CastGGPred('QW', target) then
					return
				end
			end
		end
	end
end

function zgHwei:Harass()
	if not self:CanCast() then return end
	if IsReady(_E) and Menu.Harass.E:Value() then
		local target = GetTarget(self.EESpell.Range)
		if IsValid(target) then
			self:CastGGPred('EE', target)
		end
	end
	if IsReady(_Q) and Menu.Harass.Q:Value() and lastR2 < GetTickCount() then
		local target, isRTarget = GetTarget(self.QQSpell.Range), false
		local rTarget = self:GetRBuffTarget()
		if rTarget and IsValid(rTarget) then
			if rTarget.distance <= 800 then
				target, isRTarget = rTarget, true
			elseif GetEnemyCount(500, myHero.pos) == 0 then
				return
			end
		end
		if IsValid(target) then
			if isRTarget or (IsHardCC(target) and target.distance <= 800) or (target.distance <= myHero.range and target.distance >= 350) then
				if self:CastGGPred('QE', target) then return end
			elseif self:CastGGPred('QQ', target) then
				return
			elseif self:IsUnitInEE(target) then	
				if self:CastGGPred('QE', target) then return end
			end
		end
	end
end

function zgHwei:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgHwei:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.QE:Value() and IsReady(_Q) and self:CanCast() then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(1000)
			local bestTarget = nil
			local maxHits = 0
			
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QESpell.Speed, self.QESpell.Delay, self.QESpell.Radius/2, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > maxHits then
						maxHits = collisionCount
						bestTarget = minion
					end
				end
			end
			
			if bestTarget and maxHits >= Menu.Clear.LaneClear.QECount:Value() then
				Control.CastSpell({HK_Q, HK_E}, bestTarget)
			end
		end
	end
end

function zgHwei:JungleClear()
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(800)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.QE:Value() and IsReady(_Q) and self:CanCast() then
					Control.CastSpell({HK_Q, HK_E}, minion)
				end
				if Menu.Clear.JungleClear.WE:Value() and IsReady(_W) and self:CanCast() then
					Control.CastSpell({HK_W, HK_E}, mousePos)
				end
				if Menu.Clear.JungleClear.EE:Value() and IsReady(_E) and self:CanCast() then
					Control.CastSpell({HK_E, HK_E}, minion)
				end
			end
		end
	end
end

function zgHwei:Flee()
	if Menu.Misc.Flee:Value() and IsReady(_W) and self:CanCast() then
		Control.CastSpell({HK_W, HK_Q}, mousePos)
	end
end

function zgHwei:Draw()
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
	if Menu.Draw.QQ:Value() then
		Draw.Circle(myHero.pos, self.QQSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.QW:Value() then
		Draw.Circle(myHero.pos, self.QWSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.QE:Value() then
		Draw.Circle(myHero.pos, self.QESpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.EE:Value() then
		Draw.Circle(myHero.pos, self.EESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.EQ:Value() then
		Draw.Circle(myHero.pos, self.EQSpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgHwei()
