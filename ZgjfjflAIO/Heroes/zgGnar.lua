local Version = 1.03

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

local function FindClosestWall(Pos, range, stepSize)
	local startPos = Pos.pos or Pos
	local closestWallPos = nil
	local closestDistance = math.huge
	for i = 30, 360, 30 do
		local rotatedVector = Vector(0, 0, stepSize):Rotated(0, i * math.pi / 180, 0)
		local currentPos = startPos
		for steps = 1, range/stepSize do
			currentPos = currentPos + rotatedVector
			if MapPosition:inWall(currentPos) then
				local distance = startPos:DistanceTo(currentPos)
				if distance < closestDistance then
					closestDistance = distance
					closestWallPos = currentPos
				end
				break
			end
		end
	end
	return closestWallPos
end

-- local function FindClosestWall(Pos, range)
-- 	local startPos = Pos.pos or Pos
-- 	local closestWallPos = nil
-- 	local closestDistance = math.huge
	
-- 	for i = 0, 360, 30 do
-- 		local angle = i * math.pi / 180
-- 		local dirVector = Vector(math.cos(angle), 0, math.sin(angle)):Normalized()
-- 		local endPos = startPos + dirVector * range

-- 		local intersectionPoint = MapPosition:getIntersectionPoint3D(startPos, endPos)
		
-- 		if intersectionPoint then
-- 			local distance = startPos:DistanceTo(intersectionPoint)
-- 			if distance < closestDistance and distance <= range then
-- 				closestDistance = distance
-- 				closestWallPos = intersectionPoint
-- 			end
-- 		end
-- 	end
	
-- 	return closestWallPos
-- end

local function FindFirstWallCollision(startPos, endPos, step)
	local direction = (endPos - startPos):Normalized()
	local distance = startPos:DistanceTo(endPos)
	for i = 0, distance, step do
		local checkPos = startPos + direction * i
		if MapPosition:inWall(checkPos) then
			return checkPos
		end
	end
	return nil
end


---------------------------------------------

class "zgGnar"

function zgGnar:__init()
	print("Zgjfjfl AIO - Gnar Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QMini = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1100, Speed = 1200, Collision = false}
	EMini = {Radius = 150, Range = 475}
	QMega = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 90, Range = 1100, Speed = 2100, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	WMega = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 100, Range = 550, Speed = math.huge, Collision = false}
	EMega = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 375, Range = 675, Speed = math.huge, Collision = false}
	R = {Delay = 0.25, Range = 420}
end

function zgGnar:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({name = " ", drop = {"Mini Gnar"}})
	Menu.Combo:MenuElement({id = "QMini", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QStack", name = "Only Q if Target Has 2 W Stacks", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "EMini", name = "Use E When Ready to Transform", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "EQ", name = "Use E to Gapclose if Can Kills", toggle = true, value = false})
	Menu.Combo:MenuElement({name = " ", drop = {"Mega Gnar"}})
	Menu.Combo:MenuElement({id = "QMega", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "EMega", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WMega", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| X enemiesInRange", value = 1, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E| Jump to mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
end

function zgGnar:IsMiniGnar()
	return myHero:GetSpellData(_Q).name == "GnarQ"
end

function zgGnar:IsTransFormSoon()
	return myHero:GetSpellData(_Q).name == "GnarBigQ" and HaveBuff(myHero, "gnartransformsoon")
end

function zgGnar:IsMegaGnar()
	return myHero:GetSpellData(_Q).name == "GnarBigQ" and HaveBuff(myHero, "gnartransform")
end

function zgGnar:OnTick()
	if IsCasting() or ShouldWait() then return end
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function zgGnar:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		local castDir = myHero.pos + (mousePos - myHero.pos)
		Control.CastSpell(HK_E, castDir)
	end
end

function zgGnar:Combo()
	if self:IsTransFormSoon() then
		local target = GetTarget(EMini.Range + EMini.Radius/2)
		if IsValid(target) then
			if Menu.Combo.EMini:Value() and IsReady(_E) then
				local endPos = myHero.pos:Extended(target.pos, (myHero.pos:DistanceTo(target.pos) + EMini.Range))
				if not IsUnderTurret2(endPos) and GetEnemyCount(500, endPos) < 3 and myHero.health/myHero.maxHealth > target.health/target.maxHealth then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end

	if self:IsMegaGnar() then
		local Count = 0
		local enemiesInRange = {}
		for i, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(math.huge, R.Delay)
				if myHero.pos:DistanceTo(enemyPred) < R.Range then
					Count = Count + 1
					table.insert(enemiesInRange, enemy)
				end
			end
		end
		if  Menu.Combo.R:Value() and IsReady(_R) and Count >= Menu.Combo.RCount:Value() then
			local target = GetTarget(enemiesInRange)
			local wallPos = FindClosestWall(myHero, 1000, 25)
			if wallPos ~= nil then
				local castDir = target.pos + (wallPos - myHero.pos):Normalized()
				if FindFirstWallCollision(target.pos, castDir * 500, 25) ~= nil and FindFirstWallCollision(myHero.pos, target.pos, 25) == nil then
				-- if MapPosition:intersectsWall(target.pos, castDir * R.Range) and not MapPosition:intersectsWall(myHero.pos, target.pos) then
					Control.CastSpell(HK_R, wallPos)
					lastR = GetTickCount()
				end
			end

			local allyTurrets = _G.SDK.ObjectManager:GetAllyTurrets(2000)
			for _, turret in ipairs(allyTurrets) do
				if turret then
					local turretRange = 750
					local targetToDist = turret.pos:DistanceTo(target.pos)
					if targetToDist > turretRange and targetToDist < turretRange + R.Range then
						local castDir = (turret.pos - target.pos):Normalized()
						local pushEndPos = target.pos + (castDir * R.Range)
						if turret.pos:DistanceTo(pushEndPos) < turretRange then
							local castPos = target.pos + castDir * 500
							Control.CastSpell(HK_R, castPos)
							lastR = GetTickCount()
							return
						end
					end
				end
			end
		end
		
		local target = GetTarget(QMega.Range)
		if IsValid(target) then
			if myHero.pos:DistanceTo(target.pos) > 500 and Menu.Combo.EMega:Value() and IsReady(_E) then
				if myHero.health/myHero.maxHealth > target.health/target.maxHealth then
					if IsReady(_R) then
						self:CastEMega(target)
					else
						if GetEnemyCount(500, target.pos) < 3 then
							self:CastEMega(target)
						end
					end						
				end
			end
			
			if Menu.Combo.WMega:Value() and IsReady(_W) and lastR + 600 < GetTickCount() then
				self:CastWMega(target)
			end
			
			if Menu.Combo.QMega:Value() and IsReady(_Q) and lastR + 700 < GetTickCount() then
				self:CastQMega(target)
			end
		end
	end

	if self:IsMiniGnar() then
		local target = GetTarget(QMini.Range-50)
		if IsValid(target) then
			if Menu.Combo.QMini:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) > 450 then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, QMini.Speed, QMini.Delay, QMini.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount > 0 then
					local minion = collisionObjects[1]
					if minion.pos:DistanceTo(target.pos) <= 350 then
						if not Menu.Combo.QStack:Value() then
							self:CastQMini(target)
						else
							if myHero:GetSpellData(_W).level == 0 or GetBuffData(target, "gnarwproc").count == 2 then
								self:CastQMini(target)
							end
						end
					end
				else
					if not Menu.Combo.QStack:Value() then
						self:CastQMini(target)
					else
						if myHero:GetSpellData(_W).level == 0
							or (HaveBuff(target, "gnarwproc") and GetBuffData(target, "gnarwproc").count == 2)
						then
							self:CastQMini(target)
						end
					end
				end
			end
			
			if Menu.Combo.EQ:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < EMini.Range + EMini.Radius/2 then
				if target.health/target.maxHealth < 0.1 then
					local endPos = myHero.pos:Extended(target.pos, (myHero.pos:DistanceTo(target.pos) + EMini.Range))
					if not IsUnderTurret2(endPos) and GetEnemyCount(500, endPos) < 3 and myHero.health/myHero.maxHealth > target.health/target.maxHealth then
						Control.CastSpell(HK_E, target)
					end
				end
			end
		end
	end
end

function zgGnar:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		if self:IsMiniGnar() then
			local target = GetTarget(QMini.Range-50)
			if IsValid(target) then
				local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, QMini.Speed, QMini.Delay, QMini.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount > 0 then
					local minion = collisionObjects[1]
					if minion.pos:DistanceTo(target.pos) <= 350 then
						self:CastQMini(target)
					end
				else
					self:CastQMini(target)
				end
			end
		end
	
		if self:IsTransFormSoon() or self:IsMegaGnar() then
			local target = GetTarget(QMega.Range)
			if IsValid(target) then
				self:CastQMega(target)
			end
		end
	end
end

function zgGnar:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgGnar:LaneClear()
	if IsUnderTurret(myHero) or not Menu.Clear.SpellFarm:Value() then return end
	local isMini = self:IsMiniGnar()
	local Q = isMini and QMini or QMega
	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				local condition = false
				if isMini then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, Q.Speed, Q.Delay, Q.Radius, {GGPrediction.COLLISION_MINION}, nil)
					condition = collisionCount >= Menu.Clear.LaneClear.QCount:Value()
				else
					condition = GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value()
				end
				if condition then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
	if not isMini and Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(WMega.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, WMega.Speed, WMega.Delay, WMega.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount >= Menu.Clear.LaneClear.WCount:Value() then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
	end
end

function zgGnar:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local isMini = self:IsMiniGnar()
	local Q = isMini and QMini or QMega
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetMonsters(Q.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
	if not isMini and Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
		local minions = _G.SDK.ObjectManager:GetMonsters(WMega.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				Control.CastSpell(HK_W, minion)
			end
		end
	end
end

function zgGnar:CastQMini(target)
	local Pred = GGPrediction:SpellPrediction(QMini)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgGnar:CastQMega(target)
	local Pred = GGPrediction:SpellPrediction(QMega)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgGnar:CastWMega(target)
	local Pred = GGPrediction:SpellPrediction(WMega)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_W, Pred.CastPosition)
	end
end

function zgGnar:CastEMega(target)
	local Pred = GGPrediction:SpellPrediction(EMega)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.CastPosition)
	end
end

function zgGnar:Draw()
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
	if Menu.Draw.Q:Value() then
		if myHero:GetSpellData(_Q).name == "GnarQ" then
			Draw.Circle(myHero.pos, QMini.Range, 1, Draw.Color(255, 66, 229, 244))
		elseif myHero:GetSpellData(_Q).name == "GnarBigQ" then
			Draw.Circle(myHero.pos, QMega.Range, 1, Draw.Color(255, 66, 229, 244))
		end
	end
	if Menu.Draw.W:Value() then
		if myHero:GetSpellData(_Q).name == "GnarBigW" then
			Draw.Circle(myHero.pos, WMega.Range, 1, Draw.Color(255, 66, 229, 244))
		end
	end
end

zgGnar()
