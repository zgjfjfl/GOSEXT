local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgVelkoz"

function zgVelkoz:__init()
	print("Zgjfjfl AIO - Velkoz Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 50, Range = 1000, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.QSplit = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 45, Range = 1000, Speed = 2100, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 85, Range = 1000, Speed = 1700, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 225, Range = 800, Speed = math.huge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.1, Radius = 80, Range = 1500, Speed = math.huge, Collision = false}
	self.CanCastQ2 = false
end

function zgVelkoz:LoadMenu() 
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RSM", name = "Semi Manual [R] Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "W", name = "Auto [W] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function zgVelkoz:Tick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "VelkozR") then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
		return
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	self:SemiManualR()
	if IsCasting() then return end
	local mode = GetMode()	
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	end
	self:AutoW()
	self:AutoE()
end

function zgVelkoz:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if mode == "Harass" and Menu.SupportMode:Value() and target.type ~= Obj_AI_Hero then
		args.Process = false
	end
end

function zgVelkoz:SemiManualR()
	if Menu.Combo.RSM:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgVelkoz:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range - 100)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_W, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(math.sqrt(self.QSpell.Range^2 + self.QSplit.Range^2))
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end
end

function zgVelkoz:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range - 100)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_W, target)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(math.sqrt(self.QSpell.Range^2 + self.QSplit.Range^2))
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end
end

function zgVelkoz:AutoW()
	if IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.W:Value() and IsHardCC(target) then
					self:CastGGPred(HK_W, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.W:Value() and Hp < self:GetWDmg(target) then
					self:CastGGPred(HK_W, target)
				end
			end
		end
	end	
end

function zgVelkoz:AutoE()
	if IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.E:Value() and IsHardCC(target) then
					self:CastGGPred(HK_E, target)
				end
				local Hp = target.health + target.shieldAD + target.shieldAP
				if Menu.Kill.E:Value() and Hp < self:GetEDmg(target) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end	
end

function zgVelkoz:CastGGPred(spell, unit)
	if spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end	
	end
end

function zgVelkoz:CastQ(target)
	if myHero:GetSpellData(_Q).toggleState == 0 then
		if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
			local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(3) then
				if Control.CastSpell(HK_Q, QPrediction.CastPosition) then
					return
				end
			end
			if self:BestAim(target) then
				self.CanCastQ2 = true
				return
			end
		elseif self:BestAim(target) then
			self.CanCastQ2 = true
			return
		end
	end
	if self.CanCastQ2 then
		self:DetonateQ(target)
	end
end

function zgVelkoz:DetonateQ(target)
	if myHero:GetSpellData(_Q).toggleState == 1 then
		for i = Game.ParticleCount(), 1, -1 do
			local particle = Game.Particle(i)
			local Name = particle.name
			if particle and Name:find("Velkoz") and Name:find("Q_mis") then
				local realPos = particle.pos + (particle.pos - myHero.pos):Normalized() * 50
				local dir = (realPos - myHero.pos):Normalized()
				local pDir = dir:Perpendicular()
				local leftEndPos = realPos + pDir * 1000
				local rightEndPos = realPos - pDir * 1000

				local lEndPos = Vector(leftEndPos.x, target.pos.y, leftEndPos.z)
				local rEndPos = Vector(rightEndPos.x, target.pos.y, rightEndPos.z)

				local predPos = target:GetPrediction(math.huge, 0.25)
				local leftPoint, onLeftSegment = GGPrediction:ClosestPointOnLineSegment(predPos, realPos, lEndPos)
				if onLeftSegment and GGPrediction:IsInRange(predPos, leftPoint, self.QSplit.Radius + target.boundingRadius) then
					if Control.CastSpell(HK_Q) then
						self.CanCastQ2 = false
						return
					end
				end
				local rightPoint, onRightSegment = GGPrediction:ClosestPointOnLineSegment(predPos, realPos, rEndPos)
				if onRightSegment and GGPrediction:IsInRange(predPos, rightPoint, self.QSplit.Radius + target.boundingRadius) then
					if Control.CastSpell(HK_Q) then
						self.CanCastQ2 = false
						return
					end
				end
			end
		end
	end
end

function zgVelkoz:AimQ(finalPos)
	local CircleLineSegmentN = 36
	local radius = 500
	local position = myHero.pos
	local points = {}

	for i = 1, CircleLineSegmentN do
		local angle = i * 2 * math.pi / CircleLineSegmentN
		local x = position.x + radius * math.cos(angle)
		local z = position.z + radius * math.sin(angle)
		local y = position.y
		local point = Vector(x, y, z)

		if point:DistanceTo(myHero.pos:Extended(finalPos, radius)) < 430 then
			table.insert(points, point)
		end
	end

	table.sort(points, function(a, b) return a:DistanceTo(finalPos) < b:DistanceTo(finalPos) end)

	table.remove(points, 1)
	table.remove(points, 1)

	return points
end

function zgVelkoz:BestAim(target)
	local predictionPos = target:GetPrediction(math.huge, 0.5)
	local pointList = self:AimQ(predictionPos)
	local c1 = Vector(predictionPos):DistanceTo(myHero.pos)
	for _, point in ipairs(pointList) do
		for j = 400, 1100, 50 do
			local posExtend = myHero.pos:Extended(point, j)
			local a1 = myHero.pos:DistanceTo(posExtend)
			local b1 = math.sqrt(c1 * c1 - a1 * a1)

			if b1 < self.QSplit.Range then
				local pointA = myHero.pos:Extended(point, a1)
				local endPos = Vector(pointA.x,target.pos.y,pointA.z)
				local dir = (endPos - myHero.pos):Normalized()
				local pDir = dir:Perpendicular()
				local leftEndPos = endPos + pDir * b1
				local rightEndPos = endPos - pDir * b1

				local lEndPos = Vector(leftEndPos.x,target.pos.y,leftEndPos.z)
				local rEndPos = Vector(rightEndPos.x,target.pos.y,rightEndPos.z)

				if lEndPos:DistanceTo(predictionPos) < self.QSplit.Radius then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, self.QSpell.CollisionTypes, target.networkID)
					if not isWall and collisionCount == 0 then
						if Control.CastSpell(HK_Q, endPos) then
							return true
						end
					end
				end
				if rEndPos:DistanceTo(predictionPos) < self.QSplit.Radius then
					local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, self.QSpell.CollisionTypes, target.networkID)
					if not isWall and collisionCount == 0 then
						if Control.CastSpell(HK_Q, endPos) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

function zgVelkoz:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({30, 50, 70, 90, 110})[level] + 0.2 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function zgVelkoz:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 100, 130, 160, 190})[level] + 0.3 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgVelkoz:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = ({450, 625, 800})[level] + 1.25 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgVelkoz:Draw()
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

zgVelkoz()