local Version = 1.06

require("GGPrediction")
-- require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgBard"

function zgBard:__init()
	print("Zgjfjfl AIO - Bard Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1150, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = { Range = 800 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 350, Range = 3400, Speed = 2100, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgBard:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = true})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Qstun", name = "[Q] Use Only Stun", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "Rsm", name = "Semi-manual R Target near mouse", key = string.byte("T")})
		Menu.Combo:MenuElement({id = "RMode", name = "Use R | Mode Toggle", toggle = true, value = true, key = string.byte("M"), tooltip = "Enable: Enemy | Disable: Ally"})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q] ", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
		Menu.Auto:MenuElement({id = "W", name = "[W] Auto", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Whp", name = "[W] auto on ally or self < X hp%", value = 30, min = 0, max = 100, step = 5})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "DrawRMode", name = "Draw R Mode Status", value = true})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
end

function zgBard:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if mode == "Harass" and Menu.SupportMode:Value() and target.type ~= Obj_AI_Hero then
		args.Process = false
	end
	if mode == "Combo" and IsReady(_Q) then
		args.Process = false
	end
end

function zgBard:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:SMR()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
	self:AutoW()
end

function zgBard:SMR()
	if not Menu.Combo.Rsm:Value() or not IsReady(_R) then return end
	local targets
	if Menu.Combo.RMode:Value() then
		targets = _G.SDK.ObjectManager:GetEnemyHeroes(self.rSpell.Range)
	else
		targets = _G.SDK.ObjectManager:GetAllyHeroes(self.rSpell.Range)
	end
	table.sort(targets, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
	if IsValid(targets[1]) and targets[1].pos:DistanceTo(mousePos) < 500 then
		local pred = GGPrediction:SpellPrediction(self.rSpell)
		pred:GetPrediction(targets[1], myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_R, pred.CastPosition)
		end
	end
end

function zgBard:Combo()
	if not Menu.Combo.Q:Value() or not IsReady(_Q) then return end
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.qSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, pred.CastPosition, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}, target.networkID)
			local unit = collisionCount > 0 and collisionObjects[1] or nil
			if isWall then return end
			if myHero.pos:DistanceTo(pred.UnitPosition) < 850 then
				local extendPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -300)
				local canCast = false
				if IsValid(unit) and myHero.pos:DistanceTo(unit.pos) < 300 then
					local _, _, collisionCount2 = GGPrediction:GetCollision(unit.pos, pred.CastPosition, self.qSpell.Speed, 0, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
					canCast = collisionCount2 == 0
				end
				local hitWall = FindFirstWallCollision(Vector(pred.CastPosition), Vector(extendPos)) -- MapPosition:intersectsWall(pred.CastPosition, extendPos)
				if Menu.Combo.Qstun:Value() then
					if canCast or hitWall ~= nil then
						Control.CastSpell(HK_Q, pred.CastPosition)
						return
					end
				else
					if unit == nil or canCast then
						Control.CastSpell(HK_Q, pred.CastPosition)
						return
					end
				end
			else
				if IsValid(unit) and unit.pos:DistanceTo(pred.CastPosition) < 300 and unit.pos:DistanceTo(myHero.pos) < 850 then
					local _, _, collisionCount2 = GGPrediction:GetCollision(unit.pos, pred.CastPosition, self.qSpell.Speed, 0, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
					if collisionCount2 == 0 then
						Control.CastSpell(HK_Q, pred.CastPosition)
						return
					end
				end
			end
		end
	end
end

function zgBard:Harass()
	if not Menu.Harass.Q:Value() or not IsReady(_Q) then return end
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.qSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, pred.CastPosition, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}, target.networkID)
			local unit = collisionCount > 0 and collisionObjects[1] or nil
			if isWall then return end
			if myHero.pos:DistanceTo(pred.UnitPosition) < 850 then
				local canCast = false
				if IsValid(unit) and myHero.pos:DistanceTo(unit.pos) < 300 then
					local _, _, collisionCount2 = GGPrediction:GetCollision(unit.pos, pred.CastPosition, self.qSpell.Speed, 0, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
					canCast = collisionCount2 == 0
				end
				if unit == nil or canCast then
					Control.CastSpell(HK_Q, pred.CastPosition)
					return
				end
			else
				if IsValid(unit) and unit.pos:DistanceTo(pred.CastPosition) < 300 and unit.pos:DistanceTo(myHero.pos) < 850 then
					local _, _, collisionCount2 = GGPrediction:GetCollision(unit.pos, pred.CastPosition, self.qSpell.Speed, 0, self.qSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO}, target.networkID)
					if collisionCount2 == 0 then
						Control.CastSpell(HK_Q, pred.CastPosition)
						return
					end
				end
			end
		end
	end
end

function zgBard:AutoW()
	if not (Menu.Auto.W:Value() and IsReady(_W)) then return end
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.wSpell.Range)
	for _, ally in ipairs(allies) do
		if IsValid(ally) and ally.health/ally.maxHealth <= Menu.Auto.Whp:Value()/100 then
			Control.CastSpell(HK_W, ally)
		end
	end
end

function zgBard:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawRMode:Value() then
		if Menu.Combo.RMode:Value() then
			Draw.Text("Semi-manual R Target: Enemy", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Semi-manual R Target: Ally", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, 850, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

zgBard()
