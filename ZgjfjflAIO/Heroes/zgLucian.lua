local Version = 1.04

require("GGPrediction")
-- require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgLucian"

function zgLucian:__init()
	print("Zgjfjfl AIO - Lucian Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 500, Speed = math.huge, Collision = false}
	self.Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 65, Range = 1100, Speed = math.huge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 55, Range = 1000, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = { Range = 425 }
	self.RSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 110, Range = 1200, Speed = 2800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgLucian:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Combo:MenuElement({id = "EsafeCheck", name = "E-dash Point Safe Check", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "enemyCheck", name = "Block E-dash in X enemies", value = 3, min = 0, max = 5, step = 1})	
	Menu.Combo:MenuElement({id = "Echeck", name = "Block E-dash inWall / underTurret", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Edis", name = "Use E | To Side - hold distance", value = 550, min = 300, max = 650, step = 50})
	Menu.Combo:MenuElement({id = "Priority", name = "Combo Abilities Priority",	value = 1, drop = {"Q-W-E", "W-Q-E", "E-Q-W", "E-W-Q"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "QExt", name = "Use Extended Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
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
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Emode", name = "Use E | Mode", value = 1, drop = {"To Side", "To Mouse", "To Target"}})
	Menu.Clear.JungleClear:MenuElement({id = "Priority", name = "JungleClear Abilities Priority", value = 3, drop = {"Q-W-E", "W-Q-E", "E-Q-W"}})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({ id = "smR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgLucian:Tick()
	self.QSpell.Delay = 0.4 - 0.15 / 17 * (myHero.levelData.lvl - 1)
	self.Q2Spell.Delay = self.QSpell.Delay
	if self:CastingR() then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	self:smR()
	if lastQ + self.QSpell.Delay * 2 > Game.Timer() then return end
	if IsCasting() or self:HavePassive() or self:Dashing() or self:CastingR() then return end
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

function zgLucian:CastingR()
	return HaveBuff(myHero, "LucianR")
end
function zgLucian:Dashing()
	return myHero.pathing.isDashing and myHero.pathing.dashSpeed > 0
end
function zgLucian:HavePassive()
	return HaveBuff(myHero, "LucianPassiveBuff")
end
function zgLucian:EToSideHoldDis()
	local Edis = Menu.Combo.Edis:Value()
	return myHero.range == 650 and Edis + 150 or Edis
end

function zgLucian:smR()
	if Menu.Misc.smR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgLucian:Combo()
	local target = GetTarget(self.Q2Spell.Range)
	if IsValid(target) then
		local eCastSuccess = false
		if Menu.Combo.Priority:Value() == 1 then
			if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				if Control.CastSpell(HK_Q, target) then
					lastQ = Game.Timer()
				end
			end
			if not Menu.Combo.Q:Value() or not IsReady(_Q) then
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
				if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
					eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
				end
			end
		end

		if Menu.Combo.Priority:Value() == 2 then
			if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				self:CastW(target)
			end
			if not Menu.Combo.W:Value() or not IsReady(_W) then
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					if Control.CastSpell(HK_Q, target) then
						lastQ = Game.Timer()
					end
				end
				if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
					eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
				end
			end
		end

		if Menu.Combo.Priority:Value() == 3 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
				eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
			if not Menu.Combo.E:Value() or not IsReady(_E) or not eCastSuccess then
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					if Control.CastSpell(HK_Q, target) then
						lastQ = Game.Timer()
					end
				end
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
			end
		end

		if Menu.Combo.Priority:Value() == 4 then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() + self.ESpell.Range then
				eCastSuccess = self:CastE(target, Menu.Combo.Emode:Value(), self:CastERange(target))
			end
			if not Menu.Combo.E:Value() or not IsReady(_E) or not eCastSuccess then
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
					self:CastW(target)
				end
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
					if Control.CastSpell(HK_Q, target) then
						lastQ = Game.Timer()
					end
				end
			end
		end

		if Menu.Combo.QExt:Value() and IsReady(_Q) then 
			self:CastQExt(target)
		end
	end	
end

function zgLucian:CastERange(target)
	local range = myHero.pos:DistanceTo(target.pos) < self:EToSideHoldDis() and 200 or 425
	return range
end

function zgLucian:CastE(target, mode, range)
	local castPos = nil
	if mode == 1 then
		--local targetPred = target:GetPrediction(math.huge, 0.25)
		local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, self.ESpell.Range, self:EToSideHoldDis())
		if intPos1 and intPos2 then
			local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
			if IsFacingMe(target) then
				castPos = myHero.pos:Extended(closest, range)
			else
				castPos = myHero.pos:Extended(target.pos, range)
			end
		end
	elseif mode == 2 then 
		castPos = myHero.pos:Extended(mousePos, range)
	elseif mode == 3 then 
		castPos = myHero.pos:Extended(target.pos, range)
	end
	
	if castPos ~= nil then
		local underTurret = IsUnderTurret2(castPos)
		local inWall = Game.isWall(castPos) -- MapPosition:inWall(castPos)
		local enemyCheck = Menu.Combo.enemyCheck:Value()
		local enemyCount = GetEnemyCount(600, castPos)

		if Menu.Combo.Echeck:Value() and (underTurret or inWall) then return false end
		if Menu.Combo.EsafeCheck:Value() and enemyCount >= enemyCheck then return false end

		Control.CastSpell(HK_E, castPos)
		return true
	end
	return false
end

function zgLucian:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(2) then
		local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, WPrediction.CastPosition, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount == 0 or _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	end
end

function zgLucian:CastQExt(target)
	local pred = GGPrediction:SpellPrediction(self.Q2Spell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(3) then
		local predPos = Vector(pred.UnitPosition)
		
		local targetPos = myHero.pos:Extended(predPos, GetDistance(myHero.pos, predPos))

		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range + myHero.boundingRadius + target.boundingRadius)
		
		local objTable = {}
		for i = 1, #minions do
			local minion = minions[i]
			table.insert(objTable, minion)
		end
		for i = 1, #enemies do
			local enemy = enemies[i]
			if enemy.networkID ~= target.networkID then
				table.insert(objTable, enemy)
			end
		end

		for i = 1, #objTable do
			local obj = objTable[i]
			local objPos = myHero.pos:Extended(obj.pos, GetDistance(myHero.pos, predPos))
			if GetDistance(targetPos, objPos) < (self.Q2Spell.Radius/2 + target.boundingRadius) then
				if Control.CastSpell(HK_Q, obj.pos) then
					lastQ = Game.Timer()
				end
			end
		end
	end
end

function zgLucian:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) then
			if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				if Control.CastSpell(HK_Q, target) then
					lastQ = Game.Timer()
				end
			end
			if Menu.Harass.QExt:Value() and IsReady(_Q) then 
				self:CastQExt(target)
			end
			if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.WSpell.Range then
				self:CastW(target)
			end
		end
	-- end
end

function zgLucian:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgLucian:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q2Spell.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						local hitCount = 1
						for j, otherMinion in ipairs(minions) do
							if IsValid(otherMinion) and otherMinion.networkID ~= minion.networkID then
								local endPos = myHero.pos:Extended(minion.pos, self.Q2Spell.Range)
								local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(otherMinion.pos, minion.pos, endPos)
								local width = self.Q2Spell.Radius/2 + otherMinion.boundingRadius
								if isOnSegment and GGPrediction:IsInRange(point, otherMinion.pos, width) then
									hitCount = hitCount + 1
								end
							end
						end
						if hitCount >= Menu.Clear.LaneClear.QCount:Value() then
							if Control.CastSpell(HK_Q, minion) then
								lastQ = Game.Timer()
							end
						end
					end
				end

				if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
					if _G.SDK.Data:IsInAutoAttackRange(myHero, minion) and GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgLucian:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Priority:Value() == 1 then
					if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						if Control.CastSpell(HK_Q, minion) then
							lastQ = Game.Timer()
						end
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 2 then
					if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						if Control.CastSpell(HK_Q, minion) then
							lastQ = Game.Timer()
						end
					elseif Menu.Clear.JungleClear.E:Value() and (not Menu.Clear.JungleClear.W:Value() or not IsReady(_W)) and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					end
				end

				if Menu.Clear.JungleClear.Priority:Value() == 3 then
					if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
						self:CastE(minion, Menu.Clear.JungleClear.Emode:Value(), self:CastERange(minion))
					elseif Menu.Clear.JungleClear.Q:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) <= (self.QSpell.Range + myHero.boundingRadius + minion.boundingRadius) then
						if Control.CastSpell(HK_Q, minion) then
							lastQ = Game.Timer()
						end
					elseif Menu.Clear.JungleClear.W:Value() and (not Menu.Clear.JungleClear.E:Value() or not IsReady(_E)) and IsReady(_W) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgLucian:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then -- _G.SDK.Data:GetAutoAttackRange(myHero, target)
					--local castPos = Vector(myHero.pos) + (Vector(target.pathing.endPos) - Vector(target.pathing.startPos)):Normalized() * self.ESpell.Range
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * self.ESpell.Range
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function zgLucian:Draw()
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

zgLucian()