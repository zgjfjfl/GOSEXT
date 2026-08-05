local Version = 1.02

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicTristana"

function ClassicTristana:__init()
	print("Classic AIO - Tristana Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.ERange =  550
	self.RRange =  600
end

function ClassicTristana:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

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
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal(E+R calculation)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Rgap", name = "Auto R Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "RgapRange", name = "AntiGap R Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicTristana:Tick()
	self.ERange = myHero.range + myHero.boundingRadius * 2

	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AntiGapcloser()
	self:SemiR()
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	end
end

function ClassicTristana:Combo()
	local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ERange)
	if not target then return end
	if Menu.Combo.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q)
	end
end

function ClassicTristana:Harass()
	local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ERange)
	if not target or target.type ~= "AIHeroClient" then return end
	if Menu.Harass.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, target)
	end
end

function ClassicTristana:LaneClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERange)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if GetMinionsCount(self.ERange, myHero.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end

function ClassicTristana:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERange)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					Control.CastSpell(HK_E, minion)
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function ClassicTristana:AntiGapcloser()
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

function ClassicTristana:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local target = _G.SDK.TargetSelector.Selected
		if target and target.pos2D.onScreen and target.distance <= self.RRange then
			Control.CastSpell(HK_R, target)
			return
		end
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)
		table.sort(enemies, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy.pos2D.onScreen then
				Control.CastSpell(HK_R, enemy)
			end
		end
	end
end

function ClassicTristana:KillSteal()
	if Menu.KillSteal.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy.pos2D.onScreen then
				local Rdmg = self:GetRDmg(enemy) - enemy.shieldAP - enemy.shieldAD
				if Rdmg > (enemy.health + enemy.hpRegen) and enemy.health > _G.SDK.Damage:GetAutoAttackDamage(myHero, enemy) * 2 then
					Control.CastSpell(HK_R, enemy)
				end
			end
		end
	end
end

function ClassicTristana:GetRDmg(unit)
	local baseDmg = ({300, 400, 500})[myHero:GetSpellData(_R).level]
	local bonusDmg = myHero.ap * 1.5
	local Rvalue = baseDmg + bonusDmg
	local Rdmg = _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, Rvalue)
	return Rdmg
end

function ClassicTristana:Draw()
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

	if Menu.Draw.R:Value() then
		Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 66, 229, 244))
	end
end

ClassicTristana()