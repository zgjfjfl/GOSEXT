local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgUrgot"

function zgUrgot:__init()		 
	print("Zgjfjfl AIO - Urgot Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.Q = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.55, Radius = 210, Range = 800, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.W = { Range = 500 } 
	self.E = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 100, Range = 450, Speed = 1500, Collision = false}
	self.R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 80, Range = 2500, Speed = 3200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}}
end

function zgUrgot:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		-- Menu.Combo:MenuElement({id = "AWA", name = "Use [AWA] When W 5 levels", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rkill", name = "UseR if can kill target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rsm", name = "UseR Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgUrgot:Tick()
	if ShouldWait() then
		return
	end
	if myHero:GetSpellData(_W).name == "UrgotWCancel" then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	if Menu.Combo.Rsm:Value() then
		self:SemiManualR()
	end
	self:AutoR2()
    local Mode = GetMode()
	if Mode == "Combo" then
		-- self:AWA()
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgUrgot:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
	if IsValid(target) and target.type == Obj_AI_Hero then
		if GetMode() == "Combo" then
			if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and myHero:GetSpellData(_W).name == "UrgotW" then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
	end
end

-- function zgUrgot:AWA()
	-- local target = _G.SDK.Orbwalker:GetTarget()
	-- if IsValid(target) and target.type == Obj_AI_Hero then
		-- if Menu.Combo.AWA:Value() and IsReady(_W) then
			-- if myHero:GetSpellData(_W).level == 5 and myHero:GetSpellData(_W).name == "UrgotWCancel" and myHero.attackData.state == 1 then
				-- Control.CastSpell(HK_W)
			-- end
		-- end
	-- end
-- end

function zgUrgot:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.Q.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.E.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		if Menu.Combo.Rkill:Value() then
			local target = GetTarget(self.R.Range)
			if IsValid(target) and (target.health - self:GetRDmg(target))/target.maxHealth < 0.25 then
				self:CastR(target)
			end
		end
	end
end

function zgUrgot:Harass()
	local target = GetTarget(self.Q.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function zgUrgot:SemiManualR()
	local target = GetTarget(self.R.Range)
	if IsValid(target) then
		if IsReady(_R) and myHero:GetSpellData(_R).name == "UrgotR" then
			self:CastR(target)
		end
	end
end

function zgUrgot:AutoR2()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.R.Range)
	for i, target in ipairs(enemies) do
		if IsValid(target) and HaveBuff(target, "urgotrslow") and target.health/target.maxHealth < 0.25 then
			if IsReady(_R) and myHero:GetSpellData(_R).name == "UrgotRRecast" then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function zgUrgot:CastQ(target)
	local pred = GGPrediction:SpellPrediction(self.Q)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_Q, pred.CastPosition)	
	end
end

function zgUrgot:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.E)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function zgUrgot:CastR(target)
	local pred = GGPrediction:SpellPrediction(self.R)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_R, pred.CastPosition)	
	end
end

function zgUrgot:GetRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 125 * rlvl - 25
	local adDmg = myHero.bonusDamage * 0.5
	local rDmg = baseDmg + adDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg)
end

function zgUrgot:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.R.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

zgUrgot()
