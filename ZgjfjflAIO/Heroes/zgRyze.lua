local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgRyze"

function zgRyze:__init()
	print("Zgjfjfl AIO - Ryze Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1000, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Range = 550}
	self.ESpell = {Range = 550}
	self.RSpell = {Range = 3000}
end

function zgRyze:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q | Max Range", value = 900, min = 550, max = 1000, step = 25})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "WMode", name = "Use W | Mode Toggle", toggle = true, value = true, key = string.byte("T"), tooltip = "Enable: Always | Disable: Only Root"})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q | Max Range", value = 950, min = 550, max = 1000, step = 25})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawWMode", name = "Draw W Mode Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", value = false})
end

function zgRyze:OnPreAttack(args)
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() and ((IsReady(_Q) and not self:QBlocked(args.Target)) or IsReady(_W) or IsReady(_E)) then
			args.Process = false
		end
	end
end

function zgRyze:Tick()
	if ShouldWait() or IsCasting() then return end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	end
end

function zgRyze:QBlocked(target)
	local isWall, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, self.QSpell.CollisionTypes, target.networkID)
	return isWall or collisionCount > 0
end

function zgRyze:Combo()
	local wModeEnabled = Menu.Combo.WMode:Value()
	
	-- Q Logic
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if IsValid(target) then
			local canCastQ = wModeEnabled or (not IsReady(_W) or ((GetTickCount() - lastE > 1000) and not HaveBuff(target, "ryzee")))
			if canCastQ then
				self:CastQ(target)
			end
		end
	end
	
	-- W Logic
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(750)
		if IsValid(target) and target.pos:DistanceTo(myHero.pos) <= (self.WSpell.Range + myHero.boundingRadius + target.boundingRadius) then
			if wModeEnabled and (not IsReady(_Q) or (self:QBlocked(target) and not IsReady(_E))) then
				if Control.CastSpell(HK_W, target) then
					lastW = GetTickCount()
				end
			elseif not wModeEnabled and HaveBuff(target, "ryzee") then
				Control.CastSpell(HK_W, target)
			end
		end
	end
	
	-- E Logic
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(750)
		if IsValid(target) and target.pos:DistanceTo(myHero.pos) <= (self.ESpell.Range + myHero.boundingRadius + target.boundingRadius) then 
			local canCastE = wModeEnabled and (GetTickCount() - lastW > 1000)
			if (not IsReady(_Q) or self:QBlocked(target)) and (canCastE or not wModeEnabled) then
				if Control.CastSpell(HK_E, target) then
					lastE = GetTickCount()
				end
			end
		end
	end
end

function zgRyze:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(750)
		if IsValid(target) and target.pos:DistanceTo(myHero.pos) <= (self.ESpell.Range + myHero.boundingRadius + target.boundingRadius) then
			Control.CastSpell(HK_E, target)
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(750)
		if IsValid(target) and target.pos:DistanceTo(myHero.pos) <= (self.WSpell.Range + myHero.boundingRadius + target.boundingRadius) then
			Control.CastSpell(HK_W, target)
		end
	end
end

function zgRyze:LaneClear()
	if IsUnderTurret(myHero) then return end
	if not Menu.Clear.SpellFarm:Value() then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)
	local qReady = Menu.Clear.LaneClear.Q:Value() and IsReady(_Q)
	local eReady = Menu.Clear.LaneClear.E:Value() and IsReady(_E)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
			if eReady then
				Control.CastSpell(HK_E, minion)
			end
			if qReady and HaveBuff(minion, "ryzee") then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgRyze:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end

	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local qReady = Menu.Clear.JungleClear.Q:Value() and IsReady(_Q)
	local eReady = Menu.Clear.JungleClear.E:Value() and IsReady(_E)
	local wReady = Menu.Clear.JungleClear.W:Value() and IsReady(_W)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.pos2D.onScreen then
			if qReady then
				Control.CastSpell(HK_Q, monster)
			end
			if wReady then
				if Control.CastSpell(HK_W, monster) then
					lastW = GetTickCount()
				end
			end
			if eReady and (GetTickCount() - lastW > 1000) then
				Control.CastSpell(HK_E, monster)
			end
		end
	end

	if qBestTarget and qMaxHits >= 1 then
		Control.CastSpell(HK_Q, qBestTarget)
	end
	if eBestTarget and eMaxHits >= 1 then
		Control.CastSpell(HK_E, eBestTarget)
	end
end

function zgRyze:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		if Control.CastSpell(HK_Q, QPrediction.CastPosition) then
			return true
		end
	end
	return false
end

function zgRyze:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.DrawWMode:Value() then
		if Menu.Combo.WMode:Value() then
			Draw.Text("W Mode: Always", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("W Mode: Only Root", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgRyze()