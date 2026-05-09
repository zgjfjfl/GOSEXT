local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgBrand"

function zgBrand:__init()
	print("Zgjfjfl AIO - Brand Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1100, Speed = 1600, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.877, Radius = 260, Range = 1030, Speed = math.huge, Collision = false}
	self.ESpell = {Range = 675}
	self.RSpell = {Range = 750}
end

function zgBrand:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QStun", name = "Combo [Q] Only Can Stun", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] If Hit X Enemies", value = 2, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Eminion", name = "Harass [E] minion if have passive", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "W", name = "Auto [W] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function zgBrand:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
    local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	end
	self:AutoQ()
	self:AutoW()
end

function zgBrand:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if mode == "Harass" and Menu.SupportMode:Value() and target.type ~= Obj_AI_Hero then
		args.Process = false
	end
	if mode == "Combo" and Menu.Combo.DisableAA:Value() and (IsReady(_Q) or IsReady(_W) or IsReady(_E)) then
		args.Process = false
	end
end

function zgBrand:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.Combo.QStun:Value() then
				if HaveBuff(target, "BrandAblaze") then
					self:CastGGPred(HK_Q, target)
				end
			else
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			CastSpellAOE(HK_W, self.WSpell, 1, myHero, target)
		end					
	end
	local bounceRange = 400
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range + bounceRange)
	for i, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and Menu.Combo.R:Value() and IsReady(_R) then
			if myHero.pos:DistanceTo(target.pos) <= self.RSpell.Range and GetEnemyCount(bounceRange, target.pos) >= Menu.Combo.RCount:Value() then
				Control.CastSpell(HK_R, target)
				break
			end
		end
	end
end

function zgBrand:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			CastSpellAOE(HK_W, self.WSpell, 1, myHero, target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_E, target)
		end
	end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	for i, minion in ipairs(minions) do
		if IsValid(minion) and minion.pos2D.onScreen and IsReady(_E) then
			if Menu.Harass.E:Value() and Menu.Harass.Eminion:Value() and HaveBuff(minion, "BrandAblaze") and GetEnemyCount(self.ESpell.Range, myHero.pos) == 0 and GetEnemyCount(600, minion.pos) > 0 then
				Control.CastSpell(HK_E, minion)
				break
			end
		end
	end
end

function zgBrand:AutoQ()
	if IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.Q:Value() and IsHardCC(target) then
					self:CastGGPred(HK_Q, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.Q:Value() and Hp < self:GetQDmg(target) + self:GetPDmg(target) - target.hpRegen*5 then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function zgBrand:AutoW()
	if IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.W:Value() and IsHardCC(target) then
					self:CastGGPred(HK_W, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.W:Value() and Hp < self:GetWDmg(target) + self:GetPDmg(target) - target.hpRegen*5 then
					self:CastGGPred(HK_W, target)
				end
			end
		end
	end	
end

function zgBrand:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) then
			local castPos = Vector(myHero.pos):Extended(Vector(WPrediction.CastPosition), 900)
			if myHero.pos:DistanceTo(unit.pos) <= 900 then
				Control.CastSpell(HK_W, WPrediction.CastPosition)
			elseif myHero.pos:DistanceTo(unit.pos) > 900 and myHero.pos:DistanceTo(unit.pos) <= 1030 then
				Control.CastSpell(HK_W, castPos)
			end
		end	
	end
end

function zgBrand:GetPDmg(target)
	local PDmg = target.maxHealth * 0.02
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function zgBrand:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({70, 100, 130, 160, 190})[level] + 0.65 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgBrand:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({75, 120, 165, 210, 255})[level] + 0.6 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function zgBrand:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
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

zgBrand()