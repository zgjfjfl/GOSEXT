local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgViktor"

function zgViktor:__init()		 
	print("Zgjfjfl AIO - Viktor Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 300, Range = 800, Speed = 1200, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.07, Radius = 90, Range = 700, Speed = 1050, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 300, Range = 850, Speed = 1200, Collision = false}
	self.lastE = 0
	self.lastR = 0
	self.isCastingE = false
	self.stage = 0
	self.stageTick = 0
	self.startPos = nil
	self.endPos = nil
	self.mPos = nil
end

function zgViktor:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W| On Rtarget or Slow or CC", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "Use E| MaxRange", value = 1225, min = 0, max = 1225, step = 25})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Harass:MenuElement({id = "ERange", name = "Use E| MaxRange", value = 1225, min = 0, max = 1225, step = 25})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
	Menu.Auto:MenuElement({id = "Wgap", name = "Auto W| Anti Gapcloser or Melee", value = true})
	Menu.Auto:MenuElement({id = "WgapRange", name = "AntiGap W Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Auto:MenuElement({id = "WmeleeRange", name = "AntiMelee W Range(melee form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Q", name = "Use Q| Self Shield Or Move Faster", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "Q", name = "Use Q| LastHit Siege Minion", value = true})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E| Min HitCount", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
end

function zgViktor:OnPreAttack(args)
	local target = args.Target
	local mode = GetMode()
	if (mode == "Combo" or mode == "Harass") and target.type == Obj_AI_Hero then
		if (IsReady(_Q) or IsReady(_E)) and not HaveBuff(myHero, "viktorq") then
			args.Process = false
		end
	end
	if target.type == Obj_AI_Minion and target.charName:find("Siege") then
		if (mode == "LastHit" or mode == "LaneClear" or mode == "Harass") and Menu.Clear.Q:Value() and IsReady(_Q) then
			local lastHitTarget = _G.SDK.HealthPrediction:GetLastHitTarget()
			if lastHitTarget and target.handle == lastHitTarget.handle then
				args.Process = false
			end
		end
	end
end

function zgViktor:Tick()
	self:UpdateCastE()
	if ShouldWait() or IsCasting() then
		return
	end
	self:SemiR()
	self:AutoRGuide()
	self:AutoW()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHitQ()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LastHitQ()
		self:FarmHarass()
		if Menu.Clear.SpellFarm:Value() then
			self:LaneClear()
			self:JungleClear()
		end
	elseif Mode == "LastHit" then
		self:LastHitQ()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgViktor:GetRTarget()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(target) and HaveBuff(target, "viktorrguide") then
			return target
		end
	end
	return nil
end

function zgViktor:AutoRGuide()
	if IsReady(_R) and myHero:GetSpellData(_R).name == "ViktorRGuide" then
		local Rtarget = self:GetRTarget()
		if IsValid(Rtarget) then
			return
		else
			local particleCount = Game.ParticleCount()
			local rPos = nil
			local newTarget = nil
			for i = particleCount, 1, -1 do
				local par = Game.Particle(i)
				if par.name:find("Viktor") and (par.name:find("R_Container_Friendly") or par.name:find("R_ContainerFriendly")) then
					rPos = par.pos
					break
				end
			end
			if rPos then
				local enemies = _G.SDK.ObjectManager:GetEnemyHeroes()
				local closest = nil
				local minDist = math.huge
				for i, enemy in ipairs(enemies) do
					if IsValid(enemy) then
						local dist = GetDistance(rPos, enemy.pos)
						if dist < minDist then
							minDist = dist
							closest = enemy
						end
					end
				end
				newTarget = closest
			end
			if IsValid(newTarget) and not HaveBuff(newTarget, "viktorrguide") and self.lastR + 300 < GetTickCount() then
				if Control.CastSpell(HK_R, newTarget) then
					self.lastR = GetTickCount()
				end
			end
		end
	end
end

function zgViktor:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "ViktorR" then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			return self:CastR(target)
		end
	end
end

function zgViktor:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) and self.lastE + 1100 < GetTickCount() then
		local target = GetTarget(Menu.Combo.ERange:Value())
		if IsValid(target) then
			local EStartPos = myHero.pos + (target.pos - myHero.pos):Normalized() * 525
			if GetDistance(myHero.pos, target.pos) < 525 then
				EStartPos = target.pos
			end
			local pred = GGPrediction:SpellPrediction(self.ESpell)
			pred:GetPrediction(target, EStartPos)
			if pred:CanHit(3) then
				local EEndPos = EStartPos + (pred.CastPosition - EStartPos):Normalized() * 300
				if self:CastE(EStartPos, EEndPos) then
					self.lastE = GetTickCount()
					return true
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and not self.isCastingE then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and (HaveBuff(target, "viktorrguide") or IsSlow(target) or IsHardCC(target)) then
			return self:CastW(target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not self.isCastingE then
		local target = GetTarget(800)
		if IsValid(target) and GetDistance(myHero.pos, target.pos) <= (600 + myHero.boundingRadius + target.boundingRadius) then
			return Control.CastSpell(HK_Q, target)
		end
	end
end

function zgViktor:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) and self.lastE + 1100 < GetTickCount() then
		local target = GetTarget(Menu.Harass.ERange:Value())
		if IsValid(target) then
			local EStartPos = myHero.pos + (target.pos - myHero.pos):Normalized() * 525
			if GetDistance(myHero.pos, target.pos) < 525 then
				EStartPos = target.pos
			end
			local pred = GGPrediction:SpellPrediction(self.ESpell)
			pred:GetPrediction(target, EStartPos)
			if pred:CanHit(3) then
				local EEndPos = EStartPos + (pred.CastPosition - EStartPos):Normalized() * 300
				if self:CastE(EStartPos, EEndPos) then
					self.lastE = GetTickCount()
					return true
				end
			end
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) and not self.isCastingE then
		local target = GetTarget(800)
		if IsValid(target) and GetDistance(myHero.pos, target.pos) <= (600 + myHero.boundingRadius + target.boundingRadius) then
			return Control.CastSpell(HK_Q, target)
		end
	end
end

function zgViktor:LastHitQ()
	if Menu.Clear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.charName:find("Siege") and GetDistance(myHero.pos, minion.pos) <= (600 + myHero.boundingRadius + minion.boundingRadius) then
				if minion.health <= self:QDamage(minion) then
					return Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgViktor:LaneClear()
	if Menu.Clear.LaneClear.E:Value() and IsReady(_E) and self.lastE + 1100 < GetTickCount() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1225)
		table.sort(minions, function(a, b) return a.distance < b.distance end)
		local bestHitCount = 0
		local bestStart = nil
		local bestEnd = nil
		for i, startMinion in ipairs(minions) do
			if IsValid(startMinion) and startMinion.team ~= 300 and GetDistance(myHero.pos, startMinion.pos) <= 525 then
				local EStartPos = myHero.pos + (startMinion.pos - myHero.pos):Normalized() * 525
				if GetDistance(myHero.pos, startMinion.pos) < 525 then
					EStartPos = startMinion.pos
				end
				for j, targetMinion in ipairs(minions) do
					if IsValid(targetMinion) and targetMinion.team ~= 300 and targetMinion.networkID ~= startMinion.networkID then
						local EEndPos = EStartPos + (targetMinion.pos - EStartPos):Normalized() * 700
						local _, _, collisionCount = GGPrediction:GetCollision(EStartPos, EEndPos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
						local hitCount = collisionCount or 0
						if hitCount > bestHitCount then
							bestHitCount = hitCount
							bestStart = EStartPos
							bestEnd = EEndPos
						end
					end
				end
			end
		end
		if bestHitCount >= Menu.Clear.LaneClear.ECount:Value() then
			local castPos = bestStart + (bestEnd - bestStart):Normalized() * 300
			if self:CastE(bestStart, castPos) then
				self.lastE = GetTickCount()
			end
		end
	end
end

function zgViktor:JungleClear()
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and self.lastE + 1100 < GetTickCount() then
		local monsters = _G.SDK.ObjectManager:GetMonsters(800)
		local bestHitCount = 0
		local bestStart = nil
		local bestEnd = nil
		for i, startMonster in ipairs(monsters) do
			if IsValid(startMonster) then
				local EStartPos = myHero.pos + (startMonster.pos - myHero.pos):Normalized() * 525
				if GetDistance(myHero.pos, startMonster.pos) < 525 then
					EStartPos = startMonster.pos
				end
				for j, targetMonster in ipairs(monsters) do
					if IsValid(targetMonster) and targetMonster.networkID ~= startMonster.networkID then
						local EEndPos = EStartPos + (targetMonster.pos - EStartPos):Normalized() * 700
						local _, _, collisionCount = GGPrediction:GetCollision(EStartPos, EEndPos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
						local hitCount = collisionCount or 0
						if hitCount > bestHitCount then
							bestHitCount = hitCount
							bestStart = EStartPos
							bestEnd = EEndPos
						end
					end
				end
			end
		end
		if bestHitCount >= 1 then
			local endPos = bestStart + (bestEnd - bestStart):Normalized() * 300
			if self:CastE(bestStart, endPos) then
				self.lastE = GetTickCount()
			end
		elseif #monsters == 1 and IsValid(monsters[1]) then
			local monster = monsters[1]
			local EStartPos = myHero.pos + (monster.pos - myHero.pos):Normalized() * 525
			if GetDistance(myHero.pos, monster.pos) < 525 then
				EStartPos = monster.pos
			end
			local EEndPos = EStartPos + (monster.pos - EStartPos):Normalized() * 300
			if self:CastE(EStartPos, EEndPos) then
				self.lastE = GetTickCount()
			end
		end
	end
	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and not self.isCastingE then
		local monsters = _G.SDK.ObjectManager:GetMonsters(800)
		for i, monster in ipairs(monsters) do
			if IsValid(monster) and GetDistance(myHero.pos, monster.pos) <= (600 + myHero.boundingRadius + monster.boundingRadius) then
				return Control.CastSpell(HK_Q, monster)
			end
		end
	end
end

function zgViktor:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgViktor:Flee()
	if Menu.Flee.Q:Value() and IsReady(_Q) then
		local target = GetTarget(800)
		if target == nil then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(700)
			target = minions[1]
		end
		if IsValid(target) and GetDistance(myHero.pos, target.pos) <= (600 + myHero.boundingRadius + target.boundingRadius) then
			return Control.CastSpell(HK_Q, target)
		end
	end
end

function zgViktor:AutoW()
	if Menu.Auto.Wgap:Value() and IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				if target.pathing.isDashing then
					local endPos = Vector(target.pathing.endPos)
					if myHero.pos:DistanceTo(endPos) < Menu.Auto.WgapRange:Value() and IsFacingMe(target) then
						local midPos = (myHero.pos + endPos) / 2
						return Control.CastSpell(HK_W, midPos)	
					end
				end
				if myHero.pos:DistanceTo(target.pos) < Menu.Auto.WmeleeRange:Value() then
					if target.range < 300 then
						return Control.CastSpell(HK_W, myHero.pos)
					else
						local midPos = (myHero.pos + target.pos) / 2
						return Control.CastSpell(HK_W, midPos)
					end
				end
			end	
		end
	end
end

function zgViktor:CastE(startPos, endPos)
	if self.isCastingE then return false end
	if _G.SDK.Cursor.Step > 0 then return false end

	self.isCastingE = true
	self.stage = 1
	self.stageTick = GetTickCount()
	self.startPos = startPos
	self.endPos = endPos
	self.mPos = mousePos

	_G.SDK.Orbwalker:SetMovement(false)
	_G.SDK.Orbwalker:SetAttack(false)

	return true
end

function zgViktor:UpdateCastE()
	if not self.isCastingE then return end

	local now = GetTickCount()

	if now > self.stageTick then
		if self.stage == 1 then
			Control.SetCursorPos(self.startPos)
			Control.KeyDown(HK_E)

			self.stage = 2
			self.stageTick = now

		elseif self.stage == 2 then
			Control.SetCursorPos(self.endPos)
			Control.KeyUp(HK_E)

			self.stage = 3
			self.stageTick = now

		elseif self.stage == 3 then
			Control.SetCursorPos(self.mPos)

			self.stage = 4
			self.stageTick = now + 150

		elseif self.stage == 4 then
			_G.SDK.Orbwalker:SetMovement(true)
			_G.SDK.Orbwalker:SetAttack(true)

			self.isCastingE = false
		end
	end
end

function zgViktor:CastW(unit)
	local pred = GGPrediction:SpellPrediction(self.WSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		return Control.CastSpell(HK_W, pred.CastPosition)
	end
	return false
end

function zgViktor:CastR(unit)
	local pred = GGPrediction:SpellPrediction(self.RSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		local predPos = pred.CastPosition
		if GetDistance(myHero.pos, predPos) <= 700 then
			return Control.CastSpell(HK_R, unit)
		else
			local rPos = myHero.pos + (predPos - myHero.pos):Normalized() * 700
			return Control.CastSpell(HK_R, rPos)
		end
	end
	return false
end

function zgViktor:QDamage(unit)
	local level = myHero:GetSpellData(_Q).level
	local baseDamage = {60, 75, 90, 105, 120}
	if level > 0 then
		local damage = baseDamage[level] + myHero.ap * 0.40
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgViktor:Draw()
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
		Draw.Circle(myHero.pos, 700, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, 1225, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 800, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, 700, 1, Draw.Color(255, 66, 244, 113))
	end
end

zgViktor()
