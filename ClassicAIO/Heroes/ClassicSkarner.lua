local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicSkarner"

function ClassicSkarner:__init()
	print("Classic AIO - Skarner Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 350}
	self.WSpell = {Range = 900}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 800, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Range = 500}
end

function ClassicSkarner:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicSkarner:IsImpaling()
	local activeSpell = myHero.activeSpell
	return HaveBuff(myHero, "Jade_SkarnerR_Buff")
		or (activeSpell and activeSpell.valid and activeSpell.name == "Jade_SkarnerR")
end

function ClassicSkarner:Tick()
	local impaling = self:IsImpaling()
	_G.SDK.Orbwalker:SetAttack(not impaling)
	if ShouldWait() then return end
	if IsCasting() then return end
	if impaling then
		self:ImpaleActions()
		return
	end

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

function ClassicSkarner:GetRTarget()
	local selected = _G.SDK.TargetSelector.Selected
	if IsValid(selected) and selected.pos2D.onScreen and myHero.pos:DistanceTo(selected.pos) <= self.RSpell.Range then
		return selected
	end
	return GetTarget(self.RSpell.Range)
end

function ClassicSkarner:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
			Control.CastSpell(HK_Q)
		end
	end
end

function ClassicSkarner:ImpaleActions()
	if Menu.Combo.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and GetEnemyCount(self.QSpell.Range, myHero.pos) > 0 then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if self:CastE(target) then return end
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
			Control.CastSpell(HK_Q)
		end
	end
end

function ClassicSkarner:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicSkarner:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)

	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell(HK_E, minion)
					return
				end
			end
		end
	end

	local nearby = 0
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and myHero.pos:DistanceTo(minion.pos) <= self.QSpell.Range then
			nearby = nearby + 1
		end
	end
	if Menu.Clear.LaneClear.W:Value() and IsReady(_W) and nearby >= Menu.Clear.LaneClear.WCount:Value() then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and nearby >= Menu.Clear.LaneClear.QCount:Value() then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(monster.pos) <= self.WSpell.Range then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q)
	end
end

function ClassicSkarner:SemiR()
	if not Menu.Misc.SemiR:Value() or not IsReady(_R) then return end
	local target = self:GetRTarget()
	if IsValid(target) and target.pos2D.onScreen then
		Control.CastSpell(HK_R, target)
	end
end

function ClassicSkarner:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.KillSteal.E:Value() and IsReady(_E) then
				local magicHealth = target.health + target.hpRegen + target.shieldAP
				if self:GetEDmg(target) >= magicHealth then
					if self:CastE(target) then return end
				end
			end
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				local effectiveHealth = target.health + target.hpRegen + target.shieldAD + target.shieldAP
				if self:GetQDmg(target) >= effectiveHealth then
					Control.CastSpell(HK_Q)
					return
				end
			end
		end
	end
end

function ClassicSkarner:CastE(target)
	local prediction = GGPrediction:SpellPrediction(self.ESpell)
	prediction:GetPrediction(target, myHero)
	if prediction:CanHit(3) then
		Control.CastSpell(HK_E, prediction.CastPosition)
		return true
	end
	return false
end

function ClassicSkarner:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local physical = ({25, 40, 55, 70, 85})[level] + myHero.bonusDamage * 0.80
	local damage = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, physical)
	if HaveBuff(myHero, "Jade_SkarnerQ_Energy1") then
		local magical = ({24, 36, 48, 60, 72})[level] + myHero.ap * 0.40
		damage = damage + _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, magical)
	end
	return damage
end

function ClassicSkarner:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({80, 120, 160, 200, 240})[level] + myHero.ap * 0.70
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicSkarner:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104)) end
end

ClassicSkarner()
