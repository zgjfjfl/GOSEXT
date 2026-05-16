local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgBelveth"

function zgBelveth:__init()		 
	print("Zgjfjfl AIO - Belveth Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(...) self:OnWndMsg(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 400, Speed = 800, Collision = false}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 100, Range = 660, Speed = math.huge, Collision = false}
	self.eSpell = {Range = 500}
	self.qDirections = {45, 135, 225, 315}
	self.qCooldowns = {[45] = 0, [135] = 0, [225] = 0, [315] = 0}
	self.qCdDuration = 16
	self.wasDead = false
end

function zgBelveth:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EHP", name = "[E] Use when self HP %", value = 30, min = 0, max = 100 })	
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function zgBelveth:Tick()
	local qLevel = myHero:GetSpellData(_Q).level
	self.qSpell.Speed = 750 + (qLevel * 50) + myHero.ms
	local baseCD = 17 - (qLevel * 1)	
	local bonusAttackSpeed = (myHero.attackSpeed - 1) * 100
	local abilityHaste = bonusAttackSpeed * 0.25
	self.qCdDuration = baseCD / (1 + abilityHaste/100)
	
	-- Reset Q cooldowns on respawn
	local isDead = myHero.dead
	if self.wasDead and not isDead then
		for _, dir in ipairs(self.qDirections) do
			self.qCooldowns[dir] = 0
		end
	end
	self.wasDead = isDead
	
	if ShouldWait() then
		return
	end
	local castingE = HaveBuff(myHero, "BelvethE")
	if castingE then
		if GetEnemyCount(self.eSpell.Range, myHero.pos) == 0 and GetMinionCount(self.eSpell.Range, myHero.pos) == 0 and Game.CanUseSpell(_E) == 0 then
			Control.CastSpell(HK_E)
		end
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
		self:JungleClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
	self:KillSteal()
end

function zgBelveth:OnWndMsg(msg, wParam)
	if Game.CanUseSpell(_Q) == 0 then
		if msg == KEY_DOWN and wParam == HK_Q then
			local qDir = self:GetQDirection(mousePos)
			if qDir and self:IsAnyQReady(qDir) then
				self.qCooldowns[qDir] = Game.Timer()
			end
		end
	end
end

function zgBelveth:CastQ(unit)
	local pred = GGPrediction:SpellPrediction(self.qSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		local qDir = self:GetQDirection(pred.CastPosition)
		if qDir ~= nil then
			if self:IsAnyQReady(qDir) then
				if Control.CastSpell(HK_Q, pred.CastPosition) then
					self.qCooldowns[qDir] = Game.Timer()
				end
			end
		end
	end
end

function zgBelveth:GetQDirection(targetPos)
	local targetAngle = math.deg(math.atan2(targetPos.z - myHero.pos.z, targetPos.x - myHero.pos.x))
	if targetAngle < 0 then targetAngle = targetAngle + 360 end

	local bestDir = self.qDirections[1]
	local bestAngleDiff = 360

	for _, dir in ipairs(self.qDirections) do
		local angleDiff = math.abs(targetAngle - dir)
		if angleDiff > 180 then angleDiff = 360 - angleDiff end
		if angleDiff < bestAngleDiff then
			bestAngleDiff = angleDiff
			bestDir = dir
		end
	end

	return bestDir
end

function zgBelveth:CastW(unit)
	local pred = GGPrediction:SpellPrediction(self.wSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_W, pred.CastPosition)
	end
end

function zgBelveth:Combo()
	local castingE = HaveBuff(myHero, "BelvethE")
	if castingE then return end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			self:CastW(target)
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then			
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		if GetEnemyCount(self.eSpell.Range, myHero.pos) > 0 and myHero.health/myHero.maxHealth < Menu.Combo.EHP:Value()/100 then
			Control.CastSpell(HK_E)
			lastE = GetTickCount()
		end
	end
end

function zgBelveth:Harass()
	local target = GetTarget(self.wSpell.Range)
	if IsValid(target) then
		if Menu.Harass.W:Value() and IsReady(_W) then
			self:CastW(target)
		end
	end
end

function zgBelveth:JungleClear()
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.wSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) then
			if Menu.Clear.W:Value() and IsReady(_W) then
				Control.CastSpell(HK_W, monster)
			end
			if Menu.Clear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.qSpell.Range then
				local qDir = self:GetQDirection(monster.pos)
				if qDir ~= nil and self:IsAnyQReady(qDir) then
					if Control.CastSpell(HK_Q, monster.pos) then
						self.qCooldowns[qDir] = Game.Timer()
					end
				end
			end
		end
	end
end

function zgBelveth:Flee()
	if Menu.Flee.Q:Value() and IsReady(_Q) then
		local qDir = self:GetQDirection(mousePos)
		if qDir ~= nil and self:IsAnyQReady(qDir) then
			if Control.CastSpell(HK_Q, mousePos) then
				self.qCooldowns[qDir] = Game.Timer()
			end
		end
	end
end

function zgBelveth:KillSteal()
	if not Menu.KS.E:Value() or not IsReady(_E) then return end
	local target = GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if lastE + 250 < GetTickCount() then
			if self:GetEDmg(target) >= target.health and not HaveBuff(myHero, "BelvethE") then
				Control.CastSpell(HK_E)
				lastE = GetTickCount()
			end
		end
	end
end

function zgBelveth:IsAnyQReady(checkDir)
	local currentTime = Game.Timer()
	if checkDir then
		return currentTime - self.qCooldowns[checkDir] > self.qCdDuration + 1
	end
	return false
end

function zgBelveth:GetEDmg(target)
	local missingHP = (1 - (target.health / target.maxHealth))	
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = elvl + 5
	local eadDmg = myHero.totalDamage * 0.08
	local exttimes = math.floor(((myHero.attackSpeed - 1) / 0.333) + 0.5)
	local eDmg = (ebaseDmg + eadDmg) * (1 + missingHP * 3) * (6 + exttimes)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, eDmg) 
end

function zgBelveth:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end


zgBelveth()