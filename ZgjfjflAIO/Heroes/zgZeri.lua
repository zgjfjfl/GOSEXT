local Version = 1.02

require("GGPrediction")
-- require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgZeri"

function zgZeri:__init()
	print("Zgjfjfl AIO - Zeri Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.237, Radius = 40, Range = 750, Speed = 2600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 40, Range = 1150, Speed = 2500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.55, Radius = 100, Range = 2500, Speed = 2500, Collision = false}
	self.ESpell = { Range = 300 }
	self.RSpell = { Delay = 0.25, Range = 825 }
	self.BonusAttackRange = 0
end

function zgZeri:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

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
	Menu.Misc:MenuElement({id = "QBarrel", name = "Q Attack GP's Barrel", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "ComboAA", name = "Disable AA when no Qpassive in combo", toggle = true, value = true, key = string.byte("T"), callback = function(newValue)
		if CheckChatBlock(Menu.Misc.ComboAA, newValue) then return end
	end})
	Menu.Misc:MenuElement({id = "ClearAA", name = "Disable AA when in Clear(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Misc.ClearAA, newValue) then return end
	end})

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
		local AADamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
		if Menu.Misc.ComboAA:Value() and not HaveBuff(myHero, "ZeriQPassiveReady") and target.health > AADamage then
			args.Process = false
		else
			args.Process = true
		end
	end

	if Mode == "LaneClear" and target.type == Obj_AI_Minion then
		local AADamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
		if Menu.Misc.ClearAA:Value() then
			args.Process = false
			if target.maxHealth <= 8 then
				args.Process = true
			end
			if IsValid(target) and target.health < AADamage and _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount > 0 or (not IsReady(_Q) or not Menu.LastHit.Q:Value()) then
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
	self.BonusAttackRange = myHero.range - 500
	self.QSpell.Range = 750 + self.BonusAttackRange

	if HaveBuff(myHero, "ZeriR") then
		self.QSpell.Speed = 3400
	else
		self.QSpell.Speed = 2600
	end

	self.WSpell.Delay = math.max(math.floor((0.55 - 0.09 * (myHero.attackSpeed - 1)) * 100) / 100, 0.3)
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
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
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

	local enemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes()
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

	local plants = _G.SDK.ObjectManager:GetPlants(self.QSpell.Range)
	local level = gangplank.levelData.lvl
	local healthDecayRate = level >= 13 and 0.5 or (level >= 7 and 1 or 2)
	local currentTime = Game.Timer()

	for _, obj in ipairs(plants) do
		if obj and obj.charName:lower() == "gangplankbarrel" then
			local barrelHealth = obj.health
			local barrelBuff, barrelBuffData = GetBuffData(obj, "gangplankebarrelactive")
			local barrelBuffStartTime = barrelBuff and barrelBuffData.startTime or 0
			local time = obj.distance / self.QSpell.Speed

			if barrelHealth <= 1 then
				Control.CastSpell(HK_Q, obj)
			elseif barrelHealth <= 2 then
				if _G.SDK.Data:IsInAutoAttackRange(myHero, obj) then
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
			if QPrediction:CanHit(2) then
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
		for i, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(math.huge, self.RSpell.Delay)
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
	if not pred:CanHit(3) then return end
		
	local predPos = Vector(pred.UnitPosition)
	local wallColPos = FindFirstWallCollisionInRectangle(myHero.pos, predPos, self.WSpell.Radius)

	if wallColPos and myHero.pos:DistanceTo(wallColPos) < self.WSpell.Range and wallColPos:DistanceTo(predPos) < 1400 then
		local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, wallColPos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
		if collisionCount == 0 then
			Control.CastSpell(HK_W, predPos)
		end
	elseif not Menu.Combo.Wwall:Value() then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
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
			if QPrediction:CanHit(2) then
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
	local baseDmg = {21, 24, 27, 30, 33}
	local bonusDmg = {1.02, 1.04, 1.06, 1.08, 1.10}
	local QDmg = baseDmg[level] + bonusDmg[level] * myHero.totalDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgZeri:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local Hp = _G.SDK.HealthPrediction:GetPrediction(minion, myHero.pos:DistanceTo(minion.pos) / self.QSpell.Speed)
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
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		--table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgZeri:JungleClear()
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgZeri:QObject()
	if not IsReady(_Q) then return end

	local QRange = self.QSpell.Range
	local targets = {}

	if Menu.Clear.QBuildings:Value() then
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(QRange)
		local buildings = _G.SDK.ObjectManager:GetEnemyBuildings(QRange + 350)

		for i = 1, #turrets do
			local turret = turrets[i]
			if turret then
				table.insert(targets, turret)
			end
		end

		for i = 1, #buildings do
			local building = buildings[i]
			if building and (building.type == Obj_AI_Nexus or (building.type == Obj_AI_Barracks and building.distance < QRange + 250)) then
				table.insert(targets, building)
			end
		end
	end

	if Menu.Clear.QWards:Value() then
		local wards = _G.SDK.ObjectManager:GetOtherEnemyMinions(QRange)
		for i = 1, #wards do
			local ward = wards[i]
			if ward then
				table.insert(targets, ward)
			end
		end
	 end

	local plants = _G.SDK.ObjectManager:GetPlants(QRange)
	for i = 1, #plants do
		local plant = plants[i]
		if plant then
			local objName = plant.charName:lower()
			if objName ~= "sennasoul" and objName ~= "gangplankbarrel" then
				if Menu.Clear.QPlants:Value() or plant.team ~= 300 or objName == "sru_plant_demon" then
					table.insert(targets, plant)
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

zgZeri()