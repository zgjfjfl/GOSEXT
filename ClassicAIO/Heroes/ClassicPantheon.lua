local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicPantheon"

function ClassicPantheon:__init()
	print("Classic AIO - Pantheon Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 600}
	self.WSpell = {Range = 600}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Angle = 32, Range = 400, Speed = math.huge, Collision = false}
	self.RSpell = {Range = 5500}
	self.comboTarget = nil
	self.comboTargetExpire = 0
end

function ClassicPantheon:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q Last Hit", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R To Mouse", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "RMinRange", name = "Semi R | Minimum Range", value = 1000, min = 0, max = 3000, step = 100})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function ClassicPantheon:IsChanneling()
	local activeSpell = myHero.activeSpell
	return HaveBuff(myHero, "Jade_PantheonEChannel")
		or HaveBuff(myHero, "Jade_PantheonR")
		or (activeSpell and activeSpell.valid and (activeSpell.name == "Jade_PantheonE" or activeSpell.name == "Jade_PantheonR"))
end

function ClassicPantheon:Tick()
	local channeling = self:IsChanneling()
	_G.SDK.Orbwalker:SetAttack(not channeling)
	_G.SDK.Orbwalker:SetMovement(not channeling)
	if channeling then return end
	if ShouldWait() then return end
	if IsCasting() then return end

	self:SemiR()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicPantheon:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicPantheon:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2000
end

function ClassicPantheon:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = self:GetComboTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_W, target)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = self:GetComboTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = self:GetComboTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
		end
	end
end

function ClassicPantheon:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
			return
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_W, target)
			return
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastE(target)
		end
	end
end

function ClassicPantheon:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicPantheon:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and myHero.pos:DistanceTo(minion.pos) <= self.ESpell.Range then
				if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion.pos)
					return
				end
			end
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.25)
				if hp > 0 and self:GetQDmg(minion) >= hp then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicPantheon:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, monster)
		return
	end
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(monster.pos) <= self.ESpell.Range then
		Control.CastSpell(HK_E, monster.pos)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, monster)
	end
end

function ClassicPantheon:SemiR()
	if not Menu.Misc.SemiR:Value() or not IsReady(_R) then return end
	local distance = myHero.pos:DistanceTo(mousePos)
	if distance < Menu.Misc.RMinRange:Value() then return end
	local castPosition = mousePos
	if distance > self.RSpell.Range then
		castPosition = myHero.pos:Extended(mousePos, self.RSpell.Range)
	end
	Control.CastSpell(HK_R, castPosition)
end

function ClassicPantheon:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.KillSteal.Q:Value() and IsReady(_Q) then
				if self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAD then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			if Menu.KillSteal.W:Value() and IsReady(_W) then
				if self:GetWDmg(target) >= target.health + target.hpRegen + target.shieldAP then
					Control.CastSpell(HK_W, target)
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then
				if self:GetEDmg(target) >= target.health + target.hpRegen + target.shieldAD then
					if self:CastE(target) then return end
				end
			end
		end
	end
end

function ClassicPantheon:CastE(target)
	local prediction = GGPrediction:SpellPrediction(self.ESpell)
	prediction:GetPrediction(target, myHero)
	if prediction:CanHit(2) then
		Control.CastSpell(HK_E, prediction.CastPosition)
		return true
	end
	return false
end

function ClassicPantheon:IsExecuteTarget(target)
	return target.maxHealth > 0 and target.health / target.maxHealth < 0.15
end

function ClassicPantheon:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({65, 105, 145, 185, 225})[level] + myHero.bonusDamage * 1.40
	if self:IsExecuteTarget(target) then damage = damage * 2 end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicPantheon:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({50, 75, 100, 125, 150})[level] + myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicPantheon:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = (({26, 46, 66, 86, 106})[level] + myHero.bonusDamage * 1.20) * 3
	if self:IsExecuteTarget(target) then damage = damage * 2 end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicPantheon:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
end

ClassicPantheon()
