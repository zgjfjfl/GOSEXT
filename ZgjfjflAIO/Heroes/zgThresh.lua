local Version = 1.03

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgThresh"

function zgThresh:__init()		 
	print("Zgjfjfl AIO - Thresh Loaded")
	self:LoadMenu()
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 70, Range = 1075, Speed = 1900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
end

function zgThresh:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	--ComboMenu  
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q1]", value = true})		
	Menu.Combo:MenuElement({id = "UseQ2", name = "[Q2]", value = true})	
	Menu.Combo:MenuElement({id = "UseW", name = "[W] if [Q1] and Ally out of AArange", value = true})
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	Menu.Combo:MenuElement({id = "EMode", name = "[E] Mode Key Pull/Push", key = string.byte("T"), toggle = true, value = true})	
	Menu.Combo:MenuElement({id = "UseR", name = "[R]", value = true})
	Menu.Combo:MenuElement({id = "UseRE", name = "[R] min Enemies in range", value = 2, min = 1, max = 5})	

	--HarassMenu
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})	
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q1]", value = true})	
	Menu.Harass:MenuElement({id = "UseQ2", name = "[Q2]", value = false})	
	Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"}) 

	--Extra
	Menu:MenuElement({type = MENU, id = "extra", name = "Extra Settings"})	
	Menu.extra:MenuElement({id = "Qmin", name = "[Q1] min range", value = 250, min = 1, max = 500, step = 25})
	Menu.extra:MenuElement({id = "Qmax", name = "[Q1] max range", value = 900, min = 500, max = 1075, step = 25})
	Menu.extra:MenuElement({id = "QTower", name = "[Q2] under enemy Turret ?", value = false})	
	Menu.extra:MenuElement({id = "UseW", name = "Auto [W] Save Ally lower than 30% Hp", value = true})
	Menu.extra:MenuElement({id = "WCount", name = "Auto [W] Save Ally if enemies near", value = 3, min = 1, max = 5})
	Menu.extra:MenuElement({id = "UseW2", name = "Auto [W] CCed Ally", value = true})
	Menu.extra:MenuElement({id = "UseWHook", name = "Auto [W] vs Blitz Hook", value = true})
	Menu.extra:MenuElement({id = "UseWGap", name = "Auto [W] on enemy gap closer", value = true})
	Menu.extra:MenuElement({id = "Epullmin", name = "Auto [E] Pull min range", value = 250, min = 1, max = 500, step = 25})
	Menu.extra:MenuElement({id = "Egap", name = "Auto [E] Anti Gapcloser", value = true})
	Menu.extra:MenuElement({id = "UseR", name = "Auto [R]", value = true})
	Menu.extra:MenuElement({id = "UseRE", name = "Auto [R] min Enemies in range", value = 3, min = 1, max = 5})	
 
	--Drawing 
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings Settings"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
	Menu.Drawing:MenuElement({type = MENU, id = "XY", name = "Text Pos Settings"})	
	Menu.Drawing.XY:MenuElement({id = "Text", name = "Draw EMode Text", value = true})		
	Menu.Drawing.XY:MenuElement({id = "x", name = "Pos: [X]", value = 700, min = 0, max = 1500, step = 10})
	Menu.Drawing.XY:MenuElement({id = "y", name = "Pos: [Y]", value = 0, min = 0, max = 860, step = 10})				
 
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	Callback.Add("Draw", function()
		if Menu.Drawing.XY.Text:Value() then 
			Draw.Text("EMode: ", 15, Menu.Drawing.XY.x:Value(), Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 225, 255, 0))		
			if Menu.Combo.EMode:Value() then
				Draw.Text("Pull", 15, Menu.Drawing.XY.x:Value()+45, Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 0, 255, 0))
			else
				Draw.Text("Push", 15, Menu.Drawing.XY.x:Value()+45, Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 0, 255, 0))
			end
		end
		
		if myHero.dead then return end
		
		if Menu.Drawing.DrawR:Value() and IsReady(_R) then
		Draw.Circle(myHero, 470, 1, Draw.Color(255, 225, 255, 10))
		end
		if Menu.Drawing.DrawQ:Value() and IsReady(_Q) then
		Draw.Circle(myHero, Menu.extra.Qmax:Value(), 1, Draw.Color(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawE:Value() and IsReady(_E) then
		Draw.Circle(myHero, 500, 1, Draw.Color(225, 225, 125, 10))
		end
		if Menu.Drawing.DrawW:Value() and IsReady(_W) then
		Draw.Circle(myHero, 950, 1, Draw.Color(225, 225, 125, 10))
		end
	end)		
end

function zgThresh:OnPreAttack(args)
	local mode = GetMode()
	if (mode == "Combo" or mode == "Harass") and args.Target.type == Obj_AI_Hero then
		local useQ = Menu[mode].UseQ:Value()
		local q2Active = myHero:GetSpellData(_Q).name == "ThreshQLeap"
		local useE = Menu[mode].UseE:Value()
		if (q2Active or (IsReady(_Q) and useQ) or (IsReady(_E) and useE)) then
			args.Process = false
		end
	end
end

function zgThresh:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then 
		return 
	end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
		self:HandleQ2(Mode)
	elseif Mode == "Harass" then
		self:Harass()
		self:HandleQ2(Mode)
	end	
	self:AutoE()
	self:AutoW()
	self:AutoR()	
end
	
function zgThresh:Combo()
	local target = GetTarget(self.QSpell.Range)
	if target == nil then return end
	if IsValid(target) then
		if IsReady(_E) and Menu.Combo.UseE:Value() and myHero.pos:DistanceTo(target.pos) <= 500 and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" and not myHero.pathing.isDashing then
			if Menu.Combo.EMode:Value() then
				if myHero.pos:DistanceTo(target.pos) >= Menu.extra.Epullmin:Value() then
					self:CastE(target)
				end
			else
				Control.CastSpell(HK_E, target.pos)
			end
		end		
		
		if Menu.Combo.UseQ:Value() and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" and myHero.pos:DistanceTo(target.pos) < Menu.extra.Qmax:Value() and myHero.pos:DistanceTo(target.pos) >= Menu.extra.Qmin:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(3) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	   
		if Menu.Combo.UseR:Value() and IsReady(_R) then
		local count = GetEnemyCount(450, myHero.pos)
			if count >= Menu.Combo.UseRE:Value() then
				Control.CastSpell(HK_R)
			end	
		end
	end
end

function zgThresh:Harass()
	local target = GetTarget(self.QSpell.Range)
	if target == nil then return end
	if IsValid(target) then				
		
		if Menu.Harass.UseQ:Value() and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" and myHero.pos:DistanceTo(target.pos) < Menu.extra.Qmax:Value() and myHero.pos:DistanceTo(target.pos) >= Menu.extra.Qmin:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(3) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end	
		end 
	end
end

function zgThresh:AutoE()
	if IsReady(_E) and Menu.extra.Egap:Value() then
		local EnemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
		for i = 1, #EnemyHeroes do
			local target = EnemyHeroes[i]
			if IsValid(target) and target.pathing.isDashing and not HaveBuff(target, "ThreshQ") then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 400 then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgThresh:AutoW()
	if not IsReady(_W) then return end

	local Allies = _G.SDK.ObjectManager:GetAllyHeroes()
	local Enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)

	if Menu.extra.UseWHook:Value() then
		for _, Ally in ipairs(Allies) do
			if self:IsAllyInRange(Ally, 1500, true) and HaveBuff(Ally, "rocketgrab2") then
				local HookPos = self:GetBuffCasterPosition(Ally, "rocketgrab2", Enemies)
				if HookPos and myHero.pos:DistanceTo(HookPos) <= 1500 then
					self:CastW(HookPos)
					return
				end
			end
		end
	end

	if Menu.extra.UseWGap:Value() then
		local GapAlly = self:FindGapAlly(Enemies, Allies)
		if GapAlly then
			self:CastW(GapAlly)
			return
		end
	end

	if Menu.Combo.UseW:Value() and GetMode() == "Combo" then
		local Marked = self:FindQMarkedTarget()
		if not Marked then
			for _, enemy in ipairs(Enemies) do
				if IsValid(enemy) and HaveBuff(enemy, "threshestun") then
					Marked = enemy
					break
				end
			end
		end
		if Marked then
			for _, Ally in ipairs(Allies) do
				if self:IsAllyInRange(Ally, 1450, true) and Marked.pos:DistanceTo(Ally.pos) > 800 and myHero.pos:DistanceTo(Ally.pos) > 600 then
					self:CastW(Ally)
					return
				end
			end
		end
	end

	if Menu.extra.UseW:Value() then
		local LowAlly = self:FindLowestAlly()
		if LowAlly and IsValid(LowAlly) and LowAlly.maxHealth > 0 and LowAlly.health / LowAlly.maxHealth <= 0.3 and GetEnemyCount(950, LowAlly.pos) >= 1 then
			self:CastW(LowAlly)
			return
		end
	end

	for _, Ally in ipairs(Allies) do
		if self:IsAllyInRange(Ally, 1350, false) then
			if Menu.extra.UseW2:Value() and not Ally.isMe and myHero.pos:DistanceTo(Ally.pos) <= 950 and IsHardCC(Ally) then
				self:CastW(Ally)
				return
			end

			local NearEnemies = GetEnemyCount(900, Ally.pos)
			if Menu.extra.WCount:Value() > 0 and NearEnemies >= Menu.extra.WCount:Value() then
				self:CastW(Ally)
				return
			end
		end
	end
end	

function zgThresh:AutoR()
	if Menu.extra.UseR:Value() and IsReady(_R) then
		local count = GetEnemyCount(450, myHero.pos)
		if count >= Menu.extra.UseRE:Value() then
			Control.CastSpell(HK_R)
		end	
	end
end	

function zgThresh:CastE(unit)
	local EPos = Vector(myHero.pos) + (Vector(myHero.pos) - Vector(unit.pos))
	Control.CastSpell(HK_E, EPos)
end

function zgThresh:CastW(target)
	local WPos = target and target.pos or target
	if not WPos then return end
	if target and target.pos then
		WPos = target:GetPrediction(math.huge, 1) or WPos
	end
	if myHero.pos:DistanceTo(WPos) > 950 then
		WPos = myHero.pos:Extended(WPos, 950)
	end
	Control.CastSpell(HK_W, WPos)
end

function zgThresh:FindQMarkedTarget()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(target) and HaveBuff(target, "ThreshQ") then
			return target
		end
	end
	return nil
end

function zgThresh:HandleQ2(mode)
	local enabled = mode == "Combo" and Menu.Combo.UseQ2:Value() or mode == "Harass" and Menu.Harass.UseQ2:Value()
	if not enabled or myHero:GetSpellData(_Q).name ~= "ThreshQLeap" then return end

	local target = self:FindQMarkedTarget()
	if not target then return end

	local hasBuff, buff = GetBuffData(target, "ThreshQ")
	if hasBuff and buff.expireTime and buff.expireTime > 0 and buff.expireTime - Game.Timer() <= 0.3 then
		self:CastQ2(target)
	end
end

function zgThresh:CastQ2(target)
	target = target or self:FindQMarkedTarget()
	if not IsValid(target) or not HaveBuff(target, "ThreshQ") then return end
	if Menu.extra.QTower:Value() and IsUnderTurret(target) then return end
	Control.CastSpell(HK_Q)
end

function zgThresh:IsAllyInRange(ally, range, excludeMe)
	if not ally or not IsValid(ally) then return false end
	if excludeMe and ally.isMe then return false end
	return myHero.pos:DistanceTo(ally.pos) <= range
end

function zgThresh:GetBuffCasterPosition(unit, buffName, enemies)
	if not HaveBuff(unit, buffName) then return nil end
	for _, enemy in ipairs(enemies or _G.SDK.ObjectManager:GetEnemyHeroes(1500)) do
		if IsValid(enemy) and enemy.charName == "Blitzcrank" then
			return enemy.pos
		end
	end
	return nil
end

function zgThresh:FindGapAlly(enemies, allies)
	local selectedAlly = nil
	local selectedDistance = math.huge
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pathing and enemy.pathing.isDashing and enemy.pathing.endPos and not HaveBuff(enemy, "ThreshQ") and not HaveBuff(enemy, "threshestun") then
			for _, ally in ipairs(allies) do
				if self:IsAllyInRange(ally, 1500, true) then
					local distance = ally.pos:DistanceTo(enemy.pathing.endPos)
					if distance <= 400 and distance < selectedDistance then
						selectedAlly = ally
						selectedDistance = distance
					end
				end
			end
		end
	end
	return selectedAlly
end
	
function zgThresh:FindLowestAlly()
	local LowestAlly = nil
	for i, Ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
		if Ally and GetDistance(Ally.pos, myHero.pos) <= 1200 and IsValid(Ally) then
			if LowestAlly == nil then
				LowestAlly = Ally
			elseif Ally.health < LowestAlly.health then
				LowestAlly = Ally
			end
		end
	end
	return LowestAlly
end

zgThresh()
