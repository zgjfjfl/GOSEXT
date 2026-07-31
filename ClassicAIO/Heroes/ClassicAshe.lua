local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicAshe"

function ClassicAshe:__init()
	print("Classic AIO - Ashe Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 20, Range = 1200, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 130, Range = 12500, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function ClassicAshe:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Raoe", name = "Use R| AOE", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "Count", name = "If LaneClear Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Target near mouse", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function ClassicAshe:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and IsReady(_Q) and myHero:GetSpellData(_Q).toggleState == 1 then
		if target.type == Obj_AI_Hero then
			if GetMode() == "Combo" and Menu.Combo.Q:Value() or (GetMode() == "Harass" and Menu.Harass.Q:Value()--[[ and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100]]) then
				Control.CastSpell(HK_Q)
			end
		end
	end
end

function ClassicAshe:Tick()
	if myHero:GetSpellData(_Q).toggleState == 2 and GetMode() ~= "Combo" and GetMode() ~= "Harass" then
		Control.CastSpell(HK_Q)
	end
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiManualR()
	self:KillSteal()
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

function ClassicAshe:KillSteal()
	if Menu.KillSteal.W:Value() and IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				local WDmg = self:GetWDmg(target)
				if WDmg >= target.health + target.hpRegen + target.shieldAD then
					self:CastW(target)
				end
			end
		end
	end
end

function ClassicAshe:SemiManualR()
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		local target = _G.SDK.TargetSelector.Selected
		if target and target.pos2D.onScreen and target.distance <= self.RSpell.Range then
			self:CastR(target)
			return
		end
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		table.sort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) and enemies[1].pos2D.onScreen then
			self:CastR(enemies[1])
		end
	end
end

function ClassicAshe:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(2) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function ClassicAshe:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function ClassicAshe:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
	if Menu.Combo.Raoe:Value() and IsReady(_R) then
		local target = GetTarget(2000)
		if IsValid(target) and target.pos2D.onScreen and GetEnemyCount(250, target.pos) > 2 then
			self:CastR(target)
		end
	end
end

function ClassicAshe:Harass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.W:Value() and IsReady(_W) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
end

function ClassicAshe:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function ClassicAshe:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 then
					if GetMinionCount(300, minion.pos) >= Menu.Clear.LaneClear.Count:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function ClassicAshe:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(600)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
	end
end

function ClassicAshe:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level > 0 then
		local WDmg = ({40, 50, 60, 70, 80})[level] + myHero.totalDamage
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
	else
		return 0
	end
end

function ClassicAshe:Draw()
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
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

ClassicAshe()