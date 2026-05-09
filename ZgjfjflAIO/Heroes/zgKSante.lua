local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgKSante"

function zgKSante:__init()
	print("Zgjfjfl AIO - KSante Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 50, Range = 450, Speed = math.huge, Collision = false}
	self.wSpell = { Range = 600 }
	self.eSpell = { Range1 = 250, Range2 = 550 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 350, Speed = 2000, Collision = false}
end

function zgKSante:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WTime", name = "W Channel time(s)", value = 0.7, min = 0.4, max = 1, step = 0.05})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RT", name = "[R] enemy close to allyturret", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual R key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear1", name = "Lane Clear"})
		Menu.Clear1:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear2", name = "Jungle Clear"})
		Menu.Clear2:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = true})
end

function zgKSante:Tick()
	if ShouldWait() then
		return
	end
	local bonusResist = myHero.bonusArmor + myHero.bonusMagicResist
	local time = math.floor((math.min(bonusResist, 120) * (1 / 1200)) * 100) / 100
	self.qSpell.Delay = math.max(0.35, 0.45 - time)
	local qData = myHero:GetSpellData(_Q)
	local wData = myHero:GetSpellData(_W)
	if qData and qData.name == "KSanteQ3" then
		self.qSpell.Range = 800
		self.qSpell.Speed = (wData and wData.name == "KSanteW_AllOut") and 1600 or 1500
	else
		self.qSpell.Range = 450
		self.qSpell.Speed = math.huge
	end
	if HaveBuff(myHero, "KSanteW") or HaveBuff(myHero, "KSanteW_AllOut") then
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
	elseif Mode == "LaneClear" then
		self:LastHit()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	end
	if Menu.Combo.RM:Value() and IsReady(_R) then
		self:RSemiManual()
	end
end

function zgKSante:Combo()
	local target = GetTarget(self.qSpell.Range + self.eSpell.Range1)
	if IsValid(target) then
		-- Q技能逻辑
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			self:CastQ(target)
		end
		-- E技能逻辑
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
			local shouldCastE = false
			-- 距离判断
			if IsReady(_Q) and myHero.pos:DistanceTo(target.pos) > self.qSpell.Range then
				shouldCastE = true
			end
			-- 被动标记判断
			if HaveBuff(target, "KSantePMark") then
				local AARange = myHero.range + myHero.boundingRadius + target.boundingRadius
				if myHero.pos:DistanceTo(target.pos) > AARange and myHero.pos:DistanceTo(target.pos) <= AARange + self.eSpell.Range1 then
					shouldCastE = true
				end
			end
			if shouldCastE then
				Control.CastSpell(HK_E, target)
				lastE = GetTickCount()
			end
		end
		
		-- W技能逻辑合并
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 1100 < GetTickCount() then
			local shouldCastW = false
			local castTime = Menu.Combo.WTime:Value()
			
			-- 基础W逻辑：AllOut状态或目标被减速
			if myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
				if (IsSlow(target) or IsHardCC(target)) then
					shouldCastW = true
				end
			end
			
			-- 推塔/推队友逻辑
			if myHero.pos:DistanceTo(target.pos) < 450 then
				-- 检查防御塔
				local turrets = _G.SDK.ObjectManager:GetAllyTurrets(2000)
				for i, turret in ipairs(turrets) do
					if turret.pos:DistanceTo(target.pos) < 1200 and turret.pos:DistanceTo(target.pos) < turret.pos:DistanceTo(myHero.pos) then
						shouldCastW = true
						break
					end
				end
				-- 检查队友
				if not shouldCastW then
					local allies = _G.SDK.ObjectManager:GetAllyHeroes(2000)
					for k, ally in ipairs(allies) do
						if not ally.isMe and ally.pos:DistanceTo(target.pos) < 1000 and ally.pos:DistanceTo(target.pos) < ally.pos:DistanceTo(myHero.pos) then
							shouldCastW = true
							break
						end
					end
				end
			end
			
			if shouldCastW then
				self:CastW(target, castTime)
				lastW = GetTickCount()
			end
		end
		if Menu.Combo.RT:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "KSanteR" then
			local turrets = _G.SDK.ObjectManager:GetAllyTurrets(2000)
			for i, turret in ipairs(turrets) do
				local Pos = target.pos:Extended(myHero.pos, -300)
				if turret.pos:DistanceTo(Pos) < 800 and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and turret.pos:DistanceTo(Pos) < turret.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_R, target)
				end
			end
		end
	end
end

function zgKSante:Harass()
	local target = GetTarget(self.qSpell.Range + self.eSpell.Range1)
	if IsValid(target) then
		-- Q技能逻辑
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			self:CastQ(target)
		end
		-- E技能逻辑
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
			local shouldCastE = false
			-- 距离判断
			if IsReady(_Q) and myHero.pos:DistanceTo(target.pos) > self.qSpell.Range then
				shouldCastE = true
			end
			-- 被动标记判断
			if HaveBuff(target, "KSantePMark") then
				local AARange = myHero.range + myHero.boundingRadius + target.boundingRadius
				if myHero.pos:DistanceTo(target.pos) > AARange and myHero.pos:DistanceTo(target.pos) <= AARange + self.eSpell.Range1 then
					shouldCastE = true
				end
			end
			if shouldCastE then
				Control.CastSpell(HK_E, target)
				lastE = GetTickCount()
			end
		end
	end
end

function zgKSante:CastQ(target)
	local pred = GGPrediction:SpellPrediction(self.qSpell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_Q, pred.CastPosition)
	end
end

function zgKSante:CastW(target, time)
	local mPos = mousePos
	Control.SetCursorPos(target.pos)
	Control.KeyDown(HK_W)
	DelayAction(function() Control.SetCursorPos(mPos) end, 0.2)
	DelayAction(function() Control.KeyUp(HK_W) end, time)
end

function zgKSante:RSemiManual()
	local target = GetTarget(self.rSpell.Range)
	if IsValid(target) and lastR + 500 < GetTickCount() then
		if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and myHero:GetSpellData(_R).name == "KSanteR" then
			if Control.CastSpell(HK_R, target) then
				lastR = GetTickCount()
			end
		end
	end
end

function zgKSante:LaneClear()
	if Menu.Clear1.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range)
		local bestTarget = nil
		local maxCollisions = 0
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) and minion.team ~= 300 then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount > maxCollisions then
					maxCollisions = collisionCount
					bestTarget = minion
				end
			end
		end
		if bestTarget and maxCollisions >= 1 then
			Control.CastSpell(HK_Q, bestTarget)
		end
	end
end

function zgKSante:JungleClear()
	if Menu.Clear2.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		local bestTarget = nil
		local maxCollisions = 0
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) and minion.team == 300 then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount > maxCollisions then
					maxCollisions = collisionCount
					bestTarget = minion
				end
			end
		end
		if bestTarget and maxCollisions >= 1 then
			Control.CastSpell(HK_Q, bestTarget)
		end
	end
end

function zgKSante:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range)
		for i = 1, #minions do
			local minion = minions[i]
			if IsValid(minion) and self:GetQDmg(minion) >= minion.health and not minion.dead then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgKSante:GetQDmg(unit)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 30 * qlvl + 40
	local qextDmg = myHero.bonusArmor * 0.40 + myHero.bonusMagicResist * 0.40
	local qDmg = qbaseDmg + qextDmg
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function zgKSante:Draw()
	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, self.qSpell.Range, 0.5, Draw.Color(255, 225, 255, 10))
	end
end

zgKSante()