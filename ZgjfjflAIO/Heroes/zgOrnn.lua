local Version = 1.01

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgOrnn"

function zgOrnn:__init()
	print("Zgjfjfl AIO - Ornn Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(...) self:OnWndMsg(...) end)
	-- _G.SDK.Spell:OnSpellCast(function(...) self:OnSpellCast(...) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 65, Range = 800, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 175, Range = 500, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 180, Range = 750, Speed = 1600, Collision = false}
	self.r1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 170, Range = 2500, Speed = 1200, Collision = false}
	self.qPos = {}
	self.qTimer = nil
end

function zgOrnn:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})	
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EQ", name = "[E] to Q", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EWall", name = "[E] to Wall", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ED", name = "E KnockUp Range", min = 0, max = 360, value = 300, step = 10})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR1 when hit X enemies inrange", min = 1, max = 5, value = 2, step = 1})
		Menu.Combo:MenuElement({id = "R2", name = "[R2]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgOrnn:Tick()
	if self.qTimer and Game.Timer() > self.qTimer then
		self:GetQPos()
		self.qTimer = nil
	end
	self:UpdateQPos()
	if myHero.pathing.isDashing then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
		_G.SDK.Orbwalker:SetMovement(true)
	end
	if ShouldWait() then return end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
	end
end

function zgOrnn:OnPreAttack(args)
	local target = args.Target
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() and not HaveBuff(target, "ornnvulnerabledebuff") and (IsReady(_Q) or IsReady(_W)) then
			args.Process = false
		end
	end
end

-- function zgOrnn:OnSpellCast(spell)
	-- if spell == _Q then
		-- self.qTimer = Game.Timer() + 1.25
	-- end	
-- end

function zgOrnn:OnWndMsg(msg, wParam)
	if Game.CanUseSpell(_Q) == 0 then
		if msg == KEY_UP and wParam == HK_Q then
		-- print('q')
			self.qTimer = Game.Timer() + 1.25
		end
	end
end

function zgOrnn:GetQPos()
	for i = Game.ParticleCount(), 1, -1 do
		local particle = Game.Particle(i)
		local Name = particle.name
		if particle and Name:find("Ornn") and Name:find("Q_Indicator") then
			table.insert(self.qPos, {pos = particle.pos, Timer = Game.Timer()})
			break
		end
	end
end

function zgOrnn:UpdateQPos()
	for i = #self.qPos, 1, -1 do
		local qPos = self.qPos[i]
		if Game.Timer() - qPos.Timer > 4.5 then
			table.remove(self.qPos, i)
		end
		-- if qPos then
			-- Draw.Circle(qPos.pos)
		-- end
	end
end

function zgOrnn:CastQ(unit)
	local pred = GGPrediction:SpellPrediction(self.qSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_Q, pred.CastPosition)
	end
end

function zgOrnn:Combo()
	if Menu.Combo.R2:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "OrnnRCharge" then
		local Rtarget = GetTarget(2500)
		if Rtarget and IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			for i = Game.ParticleCount(), 1, -1 do
				local particle = Game.Particle(i)
				if particle and particle.name:find("Ornn") and particle.name:find("R_Wave_Mis") then
					local closePoint, isOnSegment = GGPrediction:ClosestPointOnLineSegment(particle.pos, Rtarget.pos, myHero.pos)
					if isOnSegment and myHero.pos:DistanceTo(particle.pos) < 700 then
						Control.CastSpell(HK_R, Rtarget)
					end
				end
			end
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "OrnnR" then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.r1Spell.Range)
		for i, enemy in ipairs(enemies) do
			if GetEnemyCount(170, enemy.pos) >= Menu.Combo.Rcount:Value() then
				Control.CastSpell(HK_R, enemy)
			end
		end
	end
	if myHero:GetSpellData(_R).name == "OrnnRCharge" then return end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local extPos = target.pos:Extended(myHero.pos, -Menu.Combo.ED:Value())
			if FindFirstWallCollision(target.pos, extPos) == nil or not IsReady(_E) then
				self:CastQ(target)
			end
		end
	end
	if Menu.Combo.EQ:Value() and IsReady(_E) then
		local castPos = nil
		for i, qPos in ipairs(self.qPos) do
			if qPos then
				local checkWall = FindFirstWallCollision(myHero.pos, qPos.pos)
				if checkWall == nil and GetEnemyCount(Menu.Combo.ED:Value(), qPos.pos) >= 1 and myHero.pos:DistanceTo(qPos.pos) <= self.eSpell.Range then
					castPos = qPos.pos
					break
				end
			end
		end
		if castPos then
			Control.CastSpell(HK_E, castPos)
			self.qPos = {}
		end
	end
	if Menu.Combo.EWall:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local extPos = target.pos:Extended(myHero.pos, -Menu.Combo.ED:Value())
			local wallPos1 = FindFirstWallCollision(myHero.pos, target.pos)
			local wallPos2 = FindFirstWallCollision(target.pos, extPos)
			if wallPos1 == nil then
				if wallPos2 ~= nil and myHero.pos:DistanceTo(wallPos2) < self.eSpell.Range then
					Control.CastSpell(HK_E, wallPos2)
				end
			else
				if target.pos:DistanceTo(wallPos1) < Menu.Combo.ED:Value() and myHero.pos:DistanceTo(wallPos1) < self.eSpell.Range then
					Control.CastSpell(HK_E, wallPos1)
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_W, target)
		end
	end
end

function zgOrnn:LaneClear()
	if Menu.Clear.W:Value() and IsReady(_W) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.wSpell.Range)
		for _, minion in ipairs(minions) do
			if IsValid(minion) then
				Control.CastSpell(HK_W, minion)
			end
		end
	end
end

function zgOrnn:Harass()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then	
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
			self:CastQ(target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
			Control.CastSpell(HK_W, target)
		end
	end
end

function zgOrnn:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.r1Spell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
end

zgOrnn()
