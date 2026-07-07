local Version = 1.02

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgVayne"

function zgVayne:__init()		 
	print("Zgjfjfl AIO - Vayne Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 0, Range = 680, Speed = 2200, Collision = false}
end

function zgVayne:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qmode", name = "Use Q| Cast Mode", value = 1, drop = {"To Side", "To Mouse"}})
	Menu.Combo:MenuElement({id = "Qdistance", name = "To Side - hold distance", value = 400, min = 200, max = 700, step = 50})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Renemies", name = "R|minimum number of enemies near vayne", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Rdistance", name = "R|enemy distance from vayne", value = 500, min = 250, max = 750, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E|only 2 passive", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Eantimelee", name = "Auto E AntiMelee", value = true})
	Menu.Misc:MenuElement({id = "antimeleedis", name = "AntiMelee|enemy distance from vayne", value = 250, min = 200, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "Eantidash", name = "Auto E AntiDash", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})

end

function zgVayne:OnTick()
	if ShouldWait() then
		return
	end
	self:EAntiMelee()
	self:EAntiDash()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgVayne:CheckWall(from, to, distance)
	local startPos = to
	local direction = (to - from):Normalized()
	for i = 0, distance, 25 do
		local checkPos = startPos + direction * i
		if MapPosition:inWall(checkPos) then
			return true
		end
	end
	return false
end

function zgVayne:EAntiMelee()
	if Menu.Misc.Eantimelee:Value() and IsReady(_E) then
		local melees = {}
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Misc.antimeleedis:Value())
		for i = 1, #enemies do
			local enemy = enemies[i]
			if enemy.range < 400 then
				table.insert(melees, enemy)
			end
		end
		if #melees > 0 then
			table.sort(melees, function(a, b)
				return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100)
					> b.health + (b.totalDamage * 2) + (b.attackSpeed * 100)
			end)
			for i = 1, #melees do
				local target = melees[i]
				if IsFacingMe(target) then
					Control.CastSpell(HK_E, target)
					break
				end
			end
		end
	end
end

function zgVayne:EAntiDash()
	if Menu.Misc.Eantidash:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i = 1, #enemies do
			local enemy = enemies[i]
			local path = enemy.pathing
			if path and path.isDashing and enemy.posTo then
				if myHero.pos:DistanceTo(enemy.posTo) < 400 and IsFacingMe(enemy) then
					Control.CastSpell(HK_E, enemy)
					break
				end
			end
		end
	end
end

function zgVayne:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Rdistance:Value())
		if #enemies >= Menu.Combo.Renemies:Value() then
			Control.CastSpell(HK_R)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)) do
			if IsValid(enemy) then
				local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
				EPrediction:GetPrediction(enemy, myHero)
				if EPrediction:CanHit(3) then
					if self:CheckWall(myHero.pos, Vector(EPrediction.UnitPosition), 475) then
					--local endPos = Vector(EPrediction.UnitPosition):Extended(myHero.pos, -475)
					--if MapPosition:getIntersectionPoint3D(myHero.pos, endPos) ~= nil then
						Control.CastSpell(HK_E, enemy)
						break
					end
				end
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		local aaRange = myHero.range + myHero.boundingRadius * 2
		if IsValid(target) then
			if Menu.Combo.Qmode:Value() == 1 then
				local holdDistance = Menu.Combo.Qdistance:Value()
				local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, 300, holdDistance)
				if intPos1 and intPos2 then
					local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
					Control.CastSpell(HK_Q, closest)
				end
			else
				Control.CastSpell(HK_Q)
			end
		end
		if target == nil then target = GetTarget(aaRange + 300) end
		if IsValid(target) and target.distance > aaRange then
			local extended = myHero.pos:Extended(target.pos, 300)
			Control.CastSpell(HK_Q, extended)
		end
	end
end

function zgVayne:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		local aaRange = myHero.range + myHero.boundingRadius * 2
		if IsValid(target) and target.type == Obj_AI_Hero then
			if Menu.Combo.Qmode:Value() == 1 then
				local holdDistance = Menu.Combo.Qdistance:Value()
				local intPos1, intPos2 = CircleCircleIntersection(myHero.pos, target.pos, 300, holdDistance)
				if intPos1 and intPos2 then
					local closest = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos) and intPos1 or intPos2
					Control.CastSpell(HK_Q, closest)
				end
			else
				Control.CastSpell(HK_Q)
			end
		end
		if target == nil then target = GetTarget(aaRange + 300) end
		if IsValid(target) and target.distance > aaRange then
			local extended = myHero.pos:Extended(target.pos, 300)
			Control.CastSpell(HK_Q, extended)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range + myHero.boundingRadius * 2)) do
			if IsValid(target) and target.pos:ToScreen().onScreen then
				local buff, buffData = GetBuffData(target, "VayneSilveredDebuff")
				if buff and buffData.count == 2 then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgVayne:Draw()
	if myHero.dead then return end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgVayne()
