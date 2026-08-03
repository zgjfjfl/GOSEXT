local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicRyze"

function ClassicRyze:__init()
	print("Classic AIO - Ryze Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Range = 600}
	self.WSpell = {Range = 615}
	self.ESpell = {Range = 615, BounceRange = 400}
	self.comboTarget = nil
	self.comboTargetExpire = 0
end

function ClassicRyze:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable AA While Spells Ready", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RHP", name = "Use R | Self HP <= x%", value = 35, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "When Mana Percent >= x%", value = 40, min = 0, max = 100, step = 5})

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
	Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When Mana Percent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function ClassicRyze:OnPreAttack(args)
	if GetMode() ~= "Combo" or not Menu.Combo.DisableAA:Value() then return end
	local target = args.Target
	if not IsValid(target) or target.type ~= Obj_AI_Hero then return end
	local distance = myHero.pos:DistanceTo(target.pos)
	if (Menu.Combo.Q:Value() and IsReady(_Q) and distance <= self.QSpell.Range)
		or (Menu.Combo.W:Value() and IsReady(_W) and distance <= self.WSpell.Range)
		or (Menu.Combo.E:Value() and IsReady(_E) and distance <= self.ESpell.Range)
	then
		args.Process = false
	end
end

function ClassicRyze:Tick()
	if ShouldWait() then return end
	if IsCasting() then return end
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

function ClassicRyze:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicRyze:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2500
end

function ClassicRyze:Combo()
	local target = self:GetComboTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	self:SetComboTarget(target)

	if Menu.Combo.R:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_RyzeR") then
		local hpPercent = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
		if GetEnemyCount(700, myHero.pos) >= Menu.Combo.RCount:Value() or hpPercent <= Menu.Combo.RHP:Value() then
			Control.CastSpell(HK_R)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) and not HaveBuff(target, "Jade_RyzeE") then
		Control.CastSpell(HK_E, target)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicRyze:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end

	if Menu.Harass.E:Value() and IsReady(_E) and not HaveBuff(target, "Jade_RyzeE") then
		Control.CastSpell(HK_E, target)
		return
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicRyze:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicRyze:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.LaneClear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(self.ESpell.BounceRange, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion)
					return
				end
			end
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and myHero.pos:DistanceTo(minion.pos) <= self.QSpell.Range then
				local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.25)
				if hp > 0 and self:GetQDmg(minion) >= hp then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicRyze:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, monster)
	end
end

function ClassicRyze:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			local magicHealth = target.health + target.hpRegen + target.shieldAP
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				if self:GetQDmg(target) >= magicHealth then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			if Menu.KillSteal.W:Value() and IsReady(_W) then
				if self:GetWDmg(target) >= magicHealth then
					Control.CastSpell(HK_W, target)
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) then
				if self:GetEDmg(target) >= magicHealth then
					Control.CastSpell(HK_E, target)
					return
				end
			end
		end
	end
end

function ClassicRyze:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.40 + myHero.maxMana * 0.065
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({60, 95, 130, 165, 200})[level] + myHero.ap * 0.60 + myHero.maxMana * 0.045
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({50, 70, 90, 110, 130})[level] + myHero.ap * 0.35 + myHero.maxMana * 0.01
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicRyze:Draw()
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

ClassicRyze()
