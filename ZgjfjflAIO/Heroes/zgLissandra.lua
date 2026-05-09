local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgLissandra"

function zgLissandra:__init()		 
	print("Zgjfjfl AIO - Lissandra Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 725, Speed = 2200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 900, Speed = 2200, Collision = false}
	self.wSpell = { Radius = 450 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 125, Range = 1050, Speed = 1200, Collision = false}
	self.rSpell = { Range = 550, Radius = 550 }
end

function zgLissandra:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E1", name = "[E1]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E2", name = "[E2]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E2Hp", name = "Use E2 when self Hp > X%", value = 50, min = 1, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "ecountW", name = "E2+W when enemies count <= X", value = 2, min = 1, max = 5, step = 1})
		Menu.Combo:MenuElement({id = "ecountR", name = "E2+R when enemies count <= X", value = 2, min = 1, max = 5, step = 1})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R2Hp", name = "Use R self when Hp <= X%", value = 40, min = 1, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "R2count", name = "or R self when enemies count >= X", value = 3, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		-- Menu.Harass:MenuElement({id = "Mana", name = "Harass min Mana", value = 50, min = 1, max = 100, step = 5})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "[E] to mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q2", name = "[Q2] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgLissandra:Tick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "LissandraRSelf") then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgLissandra:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(self.rSpell.Range)
		if IsValid(target) then
			if self:R1Health() and GetEnemyCount(self.rSpell.Radius, myHero.pos) < Menu.Combo.R2count:Value() then
				Control.CastSpell(HK_R, target)
			end
		end
	end
	if Menu.Combo.Q:Value() then
		local target = GetTarget(self.q2Spell.Range)
		if IsValid(target) and IsReady(_Q) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E1:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			if not self:E2Ready() and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range-100 then
				Control.CastSpell(HK_E, target)
			end
		end
	end
	if Menu.Combo.E2:Value() and self:E2Health() and self:E2Ready() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE2(target)
			lastE = GetTickCount()
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
		if (self:R2Health() and GetEnemyCount(self.rSpell.Radius, myHero.pos) > 0) or GetEnemyCount(self.rSpell.Radius, myHero.pos) >= Menu.Combo.R2count:Value() then
			Control.CastSpell(HK_R, myHero)
			lastR = GetTickCount()
		end
	end
	if GetEnemyCount(self.wSpell.Radius, myHero.pos) >= 1 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W)
		lastW = GetTickCount()
	end
end

function zgLissandra:Harass()
	local target = GetTarget(self.q2Spell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) --[[and myHero.mana/myHero.maxMana > Menu.Harass.Mana:Value()/100 ]]then
			self:CastQ(target)
		end
	end
end

function zgLissandra:Flee()
	if myHero:GetSpellData(_E).toggleState == 1 then
		if Menu.Flee.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, mousePos)
		end
	end
	DelayAction(function() Control.CastSpell(HK_E) end, 1.3)
end

function zgLissandra:CheckEPos()
	local EmissilePos = nil
	local particle = nil
	for i = 1, Game.ParticleCount() do
		local p = Game.Particle(i)
		if p and p.name:find("Lissandra") and p.name:find("E_Missile") then
			particle = p
			break
		end
	end
	if particle then
		EmissilePos = particle.pos:Extended(myHero.pos, 100)
	else
		EmissilePos = nil
	end
	return EmissilePos
end

function zgLissandra:CastQ(target)
	local dis = myHero.pos:DistanceTo(target.pos)
	if dis > self.qSpell.Range then
		local q2Pred = GGPrediction:SpellPrediction(self.q2Spell)
		q2Pred:GetPrediction(target, myHero)
		if q2Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, q2Pred.CastPosition, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}, target.networkID)
			if not isWall and collisionCount > 0 then
				local unit = collisionObjects[1]
				if IsValid(unit) and myHero.pos:DistanceTo(unit.pos) < self.qSpell.Range then
					Control.CastSpell(HK_Q, q2Pred.CastPosition)
				end
			end
		end
	else
		local qPred = GGPrediction:SpellPrediction(self.qSpell)
		qPred:GetPrediction(target, myHero)
		if qPred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_Q, qPred.CastPosition)
		end
	end
end

function zgLissandra:CastE2(target)
	local missilePos = self:CheckEPos()
	local dist1 = myHero.pos:DistanceTo(target.pos)
	local enemyCount = GetEnemyCount(600, target.pos)
	if missilePos then
		local dist2 = missilePos:DistanceTo(target.pos)
		if dist1 > dist2 and not IsUnderTurret2(missilePos) then
			local shouldCastE = false
			if IsReady(_R) then
				if IsReady(_W) then
					if dist2 < self.wSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				else
					if dist2 < self.rSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountR:Value())
					end
				end
			else
				if IsReady(_W) then
					if dist2 < self.wSpell.Radius - 100 then
						shouldCastE = (enemyCount == 1 or enemyCount <= Menu.Combo.ecountW:Value())
					end
				end
			end
			if shouldCastE then
				Control.CastSpell(HK_E)
			end
		end
	end
end

function zgLissandra:E2Health()
	return myHero.health / myHero.maxHealth > Menu.Combo.E2Hp:Value()/100
end

function zgLissandra:R1Health()
	return myHero.health / myHero.maxHealth > Menu.Combo.R2Hp:Value()/100
end

function zgLissandra:R2Health()
	return myHero.health / myHero.maxHealth <= Menu.Combo.R2Hp:Value()/100
end

function zgLissandra:E2Ready()
	return HaveBuff(myHero, "LissandraE")
end

function zgLissandra:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.Q2:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.q2Spell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Radius, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

zgLissandra()