local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgNilah"

function zgNilah:__init()		 
	print("Zgjfjfl AIO - Nilah Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 600, Speed = math.huge, Collision = false}
	self.ESpell = { Range = 550 }
	self.RSpell = { Range = 450 }
end

function zgNilah:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	
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
		for i, hero in pairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
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
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
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
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
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
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local AARange = myHero.range + myHero.boundingRadius + minion.boundingRadius
				local QDmg = self:GetQDmg(minion)
				if QDmg >= _G.SDK.HealthPrediction:GetPrediction(minion, self.QSpell.Delay) and GetDistance(myHero.pos, minion.pos) > AARange then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgNilah:QBuildings()
	if Menu.Clear.QT:Value() and IsReady(_Q) then
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(self.QSpell.Range)
		for i, turret in ipairs(turrets) do
			if turret then
				Control.CastSpell(HK_Q, turret)
			end
		end
		local buildings = _G.SDK.ObjectManager:GetEnemyBuildings(self.QSpell.Range+250)
		for i, building in ipairs(buildings) do
			if building and building.type == Obj_AI_Barracks then
				Control.CastSpell(HK_Q, building)
			end
		end
		local buildings = _G.SDK.ObjectManager:GetEnemyBuildings(self.QSpell.Range+350)
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
	local hasIE = HasItem(myHero, 3031)
	local qDmg = (qbaseDmg + qadDmg) * (1 + myHero.critChance * (hasIE and 0.7 or 0.91))
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
end

function zgNilah:GetEDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 50 + elvl * 10
	local eadDmg = myHero.bonusDamage * 0.2
	local eDmg = ebaseDmg + eadDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg)
end

function zgNilah:GetFleeETargets()
	local fleeTargets = {}
	local potentialTargets = {}
	for _, hero in ipairs(_G.SDK.ObjectManager:GetHeroes()) do
		if IsValid(hero) and not hero.isMe then
			table.insert(potentialTargets, hero)
		end
	end
	for _, minion in ipairs(_G.SDK.ObjectManager:GetMinions()) do
		if IsValid(minion) and minion.maxHealth ~= 1 then
			table.insert(potentialTargets, minion)
		end
	end
	for _, target in ipairs(potentialTargets) do
		if IsValid(target) then
			local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(target.pos, myHero.pos, mousePos)
			if isOnSegment then
				table.insert(fleeTargets, target)
			end
		end
	end
	return fleeTargets
end

function zgNilah:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 1000 < GetTickCount() then
		local FleeETargets = self:GetFleeETargets()
		table.sort(FleeETargets, function(a, b) return a.distance < b.distance end)
		local nearest = FleeETargets[1]
		if IsValid(nearest) and nearest.distance <= self.ESpell.Range then
			Control.CastSpell(HK_E, nearest)
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

zgNilah()