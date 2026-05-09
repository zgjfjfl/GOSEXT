local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgCorki"

function zgCorki:__init()
	print("Zgjfjfl AIO - Corki Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 275, Range = 950, Speed = 1100, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Range = 690}
	self.R1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1250, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.R2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.175, Radius = 40, Range = 1450, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgCorki:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Rammo", name = "Minimum R ammo harass", value = 2, min = 0, max = 3, step = 1})
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
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "RCount", name = "If R CanHit Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q On 'CC'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgCorki:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) and target.type == Obj_AI_Hero and not self:HaveSheenBuff() then
		if GetMode() == "Combo" and Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, target)
		end
		if GetMode() == "Harass" --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then 
			if Menu.Harass.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function zgCorki:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SemiR()
	self:AutoQ()
	if self:HaveSheenBuff() then return end
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

function zgCorki:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(1500)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastR(target)
		end
	end
end

function zgCorki:AutoQ()
	if Menu.Misc.Qcc:Value() and IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsHardCC(target) then
				self:CastQ(target)
			end
		end
	end
end

function zgCorki:CastQ(target)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(target, myHero)
	if QPrediction:CanHit(3) then
		local castPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 825)
		if myHero.pos:DistanceTo(QPrediction.CastPosition) <= 825 then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		elseif myHero.pos:DistanceTo(QPrediction.CastPosition) > 825 and myHero.pos:DistanceTo(QPrediction.CastPosition) <= 950 then
			Control.CastSpell(HK_Q, castPos)
		end
	end
end

function zgCorki:CastR(target)
	if HaveBuff(myHero, "mbcheck2") then
		local R2Prediction = GGPrediction:SpellPrediction(self.R2Spell)
		R2Prediction:GetPrediction(target, myHero)
		if R2Prediction:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R2Prediction.CastPosition, self.R2Spell.Speed, self.R2Spell.Delay, self.R2Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R2Prediction.CastPosition) < 250 then
					Control.CastSpell(HK_R, R2Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R2Prediction.CastPosition)
			end
		end
	else
		local R1Prediction = GGPrediction:SpellPrediction(self.R1Spell)
		R1Prediction:GetPrediction(target, myHero)
		if R1Prediction:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, R1Prediction.CastPosition, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(R1Prediction.CastPosition) < 100 then
					Control.CastSpell(HK_R, R1Prediction.CastPosition)
				end
			else
				Control.CastSpell(HK_R, R1Prediction.CastPosition)
			end
		end
	end
end

function zgCorki:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(self.QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastQ(target)
			end
		end

		if Menu.Harass.R:Value() and IsReady(_R) then
			local target = GetTarget(1500)
			if IsValid(target) and target.pos2D.onScreen and myHero:GetSpellData(_R).ammo > Menu.Harass.Rammo:Value() then
				self:CastR(target)
			end
		end
	-- end
end

function zgCorki:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgCorki:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
					end
				end
				if Menu.Clear.LaneClear.R:Value() and IsReady(_R) then
					if GetMinionCount(150, minion.pos) >= Menu.Clear.LaneClear.RCount:Value() then
						local endPos = minion.pos:Extended(myHero.pos, 150)
						local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.R1Spell.Speed, self.R1Spell.Delay, self.R1Spell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if collisionCount == 0 then
							Control.CastSpell(HK_R, minion)
						end
					end
				end
			end
		end
	end
end

function zgCorki:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
				if Menu.Clear.JungleClear.R:Value() and IsReady(_R) then
					Control.CastSpell(HK_R, minion)
				end
			end
		end
	end
end

function zgCorki:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(1500)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function zgCorki:HaveSheenBuff()
	local target = _G.SDK.Orbwalker:GetTarget()
	if IsValid(target) and (HaveBuff(myHero, "sheen") or HaveBuff(myHero, "6662buff") or HaveBuff(myHero, "3078trinityforce") or HaveBuff(myHero, "lichbane")) then
		return true
	else
		return false
	end
end

function zgCorki:Draw()
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

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		if HaveBuff(myHero, "mbcheck2") then
			Draw.Circle(myHero.pos, self.R2Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		else
			Draw.Circle(myHero.pos, self.R1Spell.Range+50, 1, Draw.Color(255, 244, 66, 104))
		end
	end
end

zgCorki()