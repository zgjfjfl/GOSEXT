local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgCassiopeia"

function zgCassiopeia:__init()
	print("Zgjfjfl AIO - Cassiopeia Loaded")
	self:LoadMenu()
	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 150, Range = 850, Speed = math.huge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.6, Radius = 200, Range = 880, Speed = 3000, Collision = false}
	self.ESpell = {Delay = 0.125, Range = 700, Speed = 2500}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.5, Angle = 80, Range = 825, Speed = 1500, Collision = false}
end

function zgCassiopeia:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| CanHit >= X", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E ", value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "E", name = "Use E", value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "poisonForE", name = "only useE for poison", value = false})
	Menu.Misc:MenuElement({id = "AntiGapW", name = "W Anti Gapcloser", value = true})
	Menu.Misc:MenuElement({id = "AntiGapR", name = "R Anti Gapcloser", value = true})
	Menu.Misc:MenuElement({id = "minHpAntiGapR", name = "R AntiGapcloser| self hp%", value = 40, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", value = false})
end

function zgCassiopeia:OnTick()
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	self:SemiR()
	if IsCasting() then return end
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

function zgCassiopeia:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if not target then return end
	if target.type == Obj_AI_Hero then
		local eReady = self:EIsReady() or (myHero:GetSpellData(_E).currentCd > 0 and (myHero:GetSpellData(_E).currentCd - 0.35) < myHero.attackData.windUpTime)
		local qReady = Game.CanUseSpell(_Q) == 0
		local wReady = Game.CanUseSpell(_W) == 0
		if eReady or qReady or wReady then
			local comboActive = mode == "Combo"
			local harassActive = mode == "Harass"
			if (comboActive or harassActive) then
				args.Process = false
			end
		end
		return
	end
	if target.type == Obj_AI_Minion then
		if (mode == "LastHit" or mode == "LaneClear" or mode == "Harass") and Menu.LastHit.E:Value() and IsReady(_E) then
			local lastHitTarget = _G.SDK.HealthPrediction:GetLastHitTarget()
			if lastHitTarget and target.handle == lastHitTarget.handle then
				args.Process = false
				return
			end
		end
	end
end

function zgCassiopeia:AntiGapcloser()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for i, target in ipairs(enemies) do
		if IsValid(target) and target.pathing.isDashing then
			local endPos = Vector(target.pathing.endPos)
			if myHero.pos:DistanceTo(endPos) < 300 and IsFacingMe(target) then
				if Menu.Misc.AntiGapR:Value() and IsReady(_R) then
					if myHero.health / myHero.maxHealth < Menu.Misc.minHpAntiGapR:Value() / 100 then
						Control.CastSpell(HK_R, enemy)
						return
					end
				end
				if Menu.Misc.AntiGapW:Value() and IsReady(_W) then
					Control.CastSpell(HK_W, endPos)
					lastW = GetTickCount()
					return
				end
			end	
		end
	end
end

function zgCassiopeia:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range - 50)
		if IsValid(target) and target.pos2D.onScreen and IsFacingMe(target) then
			self:CastR(target)
		end
	end
end

function zgCassiopeia:EIsReady()
	local spell = myHero:GetSpellData(_E)
	return spell.currentCd < 0.35 and spell.level > 0 and spell.mana <= myHero.mana
end

function zgCassiopeia:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.WSpell.Range)
		if IsValid(target) and not self:IsPoisoned(target) and lastQ + 1000 < GetTickCount() then
			self:CastW(target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.QSpell.Range)
		if IsValid(target) and not self:IsPoisoned(target) and lastW + 1000 < GetTickCount() then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and self:EIsReady() then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ESpell.Range)
		if IsValid(target) and (not Menu.Misc.poisonForE:Value() or self:IsPoisoned(target) or (myHero:GetSpellData(_Q).level == 0 and myHero:GetSpellData(_W).level == 0)) then
			Control.CastSpell(HK_E, target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range - 50)
		local validTargets = {}
		for _, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(math.huge, 0.25)
				if IsFacingMe(enemy) and myHero.pos:DistanceTo(enemyPred) < myHero.pos:DistanceTo(enemy) then
					table.insert(validTargets, enemy)
				end
			end
		end
		if #validTargets >= Menu.Combo.RCount:Value() then
			Control.CastSpell(HK_R, validTargets[1])
		end
	end
end

function zgCassiopeia:IsPoisoned(target)
	return HaveBuff(target, "cassiopeiaqdebuff") or HaveBuff(target, "cassiopeiawpoison")
end

function zgCassiopeia:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.WSpell.Range)
		if IsValid(target) and target.type == Obj_AI_Hero then
			if not self:IsPoisoned(target) and lastQ + 1000 < GetTickCount() then
				self:CastW(target)
			end
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.QSpell.Range)
		if IsValid(target) and target.type == Obj_AI_Hero then
			if not self:IsPoisoned(target) and lastW + 1000 < GetTickCount() then
				self:CastQ(target)
			end
		end
	end
	if Menu.Harass.E:Value() and self:EIsReady() then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ESpell.Range)
		if IsValid(target) and target.type == Obj_AI_Hero and (self:IsPoisoned(target) or (myHero:GetSpellData(_Q).level == 0 and myHero:GetSpellData(_W).level == 0)) then
			Control.CastSpell(HK_E, target)
		end
	end
end

function zgCassiopeia:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgCassiopeia:LaneClear()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(850)
			table.sort(minions, function(a, b) return a.distance < b.distance end)
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and not self:IsPoisoned(minion) and minion.health > self:GetEDmg(minion) then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
		if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and self:IsPoisoned(minion) then
					Control.CastSpell(HK_E, minion)
				end
			end
		end
	end
end

function zgCassiopeia:JungleClear()
	if Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for _, minion in ipairs(minions) do
				if IsValid(minion) and not self:IsPoisoned(minion) and lastW + 1000 < GetTickCount() then
					Control.CastSpell(HK_Q, minion)
					lastQ = GetTickCount()
				end
			end
		end
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetMonsters(self.WSpell.Range)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for _, minion in ipairs(minions) do
				if IsValid(minion) and not self:IsPoisoned(minion) and lastQ + 1000 < GetTickCount() then
					Control.CastSpell(HK_W, minion)
					lastW = GetTickCount()
				end
			end
		end
		if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
			local minions = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
			for _, minion in ipairs(minions) do
				if IsValid(minion) and self:IsPoisoned(minion) then
					Control.CastSpell(HK_E, minion)
				end
			end
		end
	end
end

function zgCassiopeia:LastHit()
	if Menu.LastHit.E:Value() and IsReady(_E) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				local Hp = _G.SDK.HealthPrediction:GetPrediction(minion, minion.distance / self.ESpell.Speed + self.ESpell.Delay)
				local EDmg = self:GetEDmg(minion)
				if Hp > 0 and EDmg > Hp then
					Control.CastSpell(HK_E, minion)
				end
			end
		end
	end
end

function zgCassiopeia:GetEDmg(unit)
	local lvl = myHero.levelData.lvl
	local elvl = myHero:GetSpellData(_E).level
	local dmg = 48 + 4 * lvl + myHero.ap * 0.1
	if self:IsPoisoned(unit) then
		dmg = dmg + ({20, 40, 60, 80, 100})[elvl] + 0.55 * myHero.ap
	end
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, dmg)
end

function zgCassiopeia:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
		lastQ = GetTickCount()
	end
end

function zgCassiopeia:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
		lastW = GetTickCount()
	end
end

function zgCassiopeia:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgCassiopeia:Draw()
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
	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and self:EIsReady() then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgCassiopeia()
