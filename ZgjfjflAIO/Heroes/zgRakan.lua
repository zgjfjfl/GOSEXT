local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgRakan"

function zgRakan:__init()		 
	print("Zgjfjfl AIO - Rakan Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 900, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 250, Range = 725, Speed = 1700, Collision = false}
end

function zgRakan:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = true})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] to ally close enemy ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] when enemies within Wrange", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "[R] X enemies within Wrange", value = 2, min = 1, max = 5, step = 1})	
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoE"})	
		Menu.Auto:MenuElement({id = "E", name = "[E] auto ally shield", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W] to mouse", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "E", name = "[E] to ally(mouse near)", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
end

function zgRakan:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AutoE()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgRakan:OnPreAttack(args)
	local Mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and Mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
	if Mode == "Combo" then
		if IsReady(_Q) or IsReady(_W) then
			args.Process = false
		end
	end
end

function zgRakan:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(1000)
		for i, ally in ipairs(allies) do
			if not ally.isMe then
				if ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000 or myHero.pos:DistanceTo(ally.pos) <= 700 then
					if IsReady(_W) and GetEnemyCount(self.wSpell.Range, myHero.pos) == 0 and GetEnemyCount(self.wSpell.Range, ally.pos) >= 1 then
						Control.CastSpell(HK_E, ally)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			self:CastW(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and not IsReady(_W) and lastR + 600 < GetTickCount() then
		if GetEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.Rcount:Value() then
			Control.CastSpell(HK_R)
			lastR = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_W) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgRakan:AutoE()
	if Menu.Auto.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(1000)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				for j, ally in ipairs(allies) do
					if IsValid(ally) and not ally.isMe and self:attackedcheck(enemy, ally) and not HaveBuff(ally, "RakanEShield") then
						if ally.charName == "Xayah" and myHero.pos:DistanceTo(ally.pos) <= 1000 or myHero.pos:DistanceTo(ally.pos) <= 700 then
							Control.CastSpell(HK_E, ally)
							lastE = GetTickCount()
						end
					end
				end
			end
		end
	end
end

function zgRakan:Harass()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function zgRakan:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgRakan:CastW(target)
	local Pred = GGPrediction:SpellPrediction(self.wSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_W, Pred.CastPosition)
	end
end

function zgRakan:attackedcheck(enemy, ally)
	local canuse = false
	if not ally.isMe then
		if enemy.activeSpell.valid then
			if enemy.activeSpell.target == ally.handle then
				canuse = true
			else
				local endPos = enemy.activeSpell.startPos:Extended(enemy.activeSpell.placementPos, enemy.activeSpell.range)
				local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
				local width = ally.boundingRadius + (enemy.activeSpell.width > 0 and enemy.activeSpell.width or 0)
				if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
					canuse = true
				end
			end
		end
		if canuse then
			return true
		end
	end
	return false
end

function zgRakan:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * self.wSpell.Range
		Control.CastSpell(HK_W, pos)
		lastW = GetTickCount()
	end

	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() and (not Menu.Flee.W:Value() or not IsReady(_W)) then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(1000)
		for i, ally in ipairs(allies) do
			if IsValid(ally) and not ally.isMe then
				local distance = ally.pos:DistanceTo(myHero.pos)
				if mousePos:DistanceTo(ally.pos) < 500 then
					if ally.charName == "Xayah" and distance <= 1000 or distance <= 700 then
						Control.CastSpell(HK_E, ally)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
end

function zgRakan:Draw()
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

zgRakan()