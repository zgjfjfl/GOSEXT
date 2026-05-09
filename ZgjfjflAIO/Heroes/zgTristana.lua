local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgTristana"

function zgTristana:__init()
	print("Zgjfjfl AIO - Tristana Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function() self:OnPostAttack() end)

	self.ERRange = 0 
end

function zgTristana:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

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
	local target = _G.SDK.Orbwalker:GetTarget()
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
	self.ERRange = 550 + (150 / 17 * (myHero.levelData.lvl - 1)) + myHero.boundingRadius
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
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERRange)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
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
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes()
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Misc.ForceE:Value() and HaveBuff(enemy, "tristanaechargesound") and _G.SDK.Data:IsInAutoAttackRange(myHero, enemy) then
				Orbwalker.ForceTarget = enemy
				return
			end
		end
	end
	Orbwalker.ForceTarget = nil
end

function zgTristana:AntiGapcloser()
	if Menu.Misc.Rgap:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
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
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
	table.sort(enemies, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Misc.SemiR:Value() and IsReady(_R) and myHero.pos:DistanceTo(enemy.pos) <= self.ERRange + enemy.boundingRadius then
				Control.CastSpell(HK_R, enemy)
			end
		end
	end
end

function zgTristana:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.KillSteal.R:Value() and IsReady(_R) and myHero.pos:DistanceTo(enemy.pos) <= self.ERRange + enemy.boundingRadius then
				local Edmg = self:GetEDmg(enemy) - enemy.shieldAD
				local Rdmg = self:GetRDmg(enemy) - enemy.shieldAP
				local hasbuff = HaveBuff(enemy, "sionpassivezombie")
				if not hasbuff and (Edmg + Rdmg) > (enemy.health + enemy.hpRegen * 4) and Edmg < (enemy.health + enemy.hpRegen * 4) and enemy.health > _G.SDK.Damage:GetAutoAttackDamage(myHero, enemy) then
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
		local EbaseDmg = ({60, 85, 110, 135, 160})[myHero:GetSpellData(_E).level]
		local Ead = myHero.bonusDamage * 0.8
		local Eap = myHero.ap * 0.5
		local Evalue = (EbaseDmg + Ead+ Eap) * (buffData.count * 0.25 + 1) * (myHero.critChance * (hasIE and 0.52 or 0.4) + 1)
		Edmg = _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, Evalue)
	end
	return Edmg
end

function zgTristana:GetRDmg(unit)
	local baseDmg = ({225, 275, 325})[myHero:GetSpellData(_R).level]
	local bonusDmg = myHero.bonusDamage * 0.7 + myHero.ap * 1
	local Rvalue = baseDmg + bonusDmg
	local Rdmg = _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, Rvalue)
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

zgTristana()