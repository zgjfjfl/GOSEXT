local Version = 1.01

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgPoppy"

function zgPoppy:__init()	 
	print("Simple Poppy Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 430, Speed = math.huge, Collision = false}
	self.eSpell = { Range = 475 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 450, Speed = 2500, Collision = false}
	self.r2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 100, Range = 1200, Speed = 2500, Collision = false}
	self.rCastTimer = 0
end


function zgPoppy:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "ED", name = "[E] X distance enemy from wall", min = 50, max = 400, value = 400, step = 50})
		Menu.Combo:MenuElement({id = "RF", name = "[R] Fast", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RFHP", name = "[R] Fastcast on target HP % < X", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Slowcast Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Antidash", name = "W Setting "})
		Menu.Antidash:MenuElement({id = "W", name = "[W] Anti-Dash", toggle = true, value = true})
		Menu.Antidash:MenuElement({type = MENU, id = "Wtarget", name = "Use On"})
			_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
				Menu.Antidash.Wtarget:MenuElement({id = args.charName, name = args.charName, value = false})				
			end)
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgPoppy:Tick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "PoppyR") then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if Menu.Antidash.W:Value() then
		self:AutoW()
	end
	if Control.IsKeyDown(HK_R) then
		DelayAction(function()
			if myHero.activeSpell.isCharging == false then
				Control.KeyUp(HK_R)
			end
		end, 0.45)
	end
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
	self:R2()
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

function zgPoppy:Combo()
	local target = GetTarget(500)
	if IsValid(target) then
		for dis = 20, Menu.Combo.ED:Value(), 20 do
			local endPos = target.pos:Extended(myHero.pos, -dis)
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= self.eSpell.Range then
				if MapPosition:inWall(endPos) then --Game.IsWall(endPos)
					Control.CastSpell(HK_E, target)
				end
			end
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			self:CastQ(target)
		end
		if Menu.Combo.RF:Value() and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range and target.health/target.maxHealth < Menu.Combo.RFHP:Value()/100 then
			Control.KeyDown(HK_R)
			DelayAction(function()
				self:CastR(target, self.rSpell)
				Control.KeyUp(HK_R)
			end, 0.1)
		end
	end
end

function zgPoppy:LaneClear()
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if not target then
		target = _G.SDK.HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) then
			Control.CastSpell(HK_Q, target)
		end
	end
end

function zgPoppy:Harass()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function zgPoppy:AutoW()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) then
			local blockobj = Menu.Antidash.Wtarget[enemy.charName] and Menu.Antidash.Wtarget[enemy.charName]:Value()
			if blockobj and enemy.pathing.isDashing and not HasInvalidDashBuff(enemy) then
				local vct = Vector(enemy.pathing.endPos.x, enemy.pathing.endPos.y, enemy.pathing.endPos.z)
				if vct:DistanceTo(myHero.pos) < 400 then
					if IsReady(_W) and lastW + 250 < GetTickCount() then
						Control.CastSpell(HK_W)
						lastW = GetTickCount()
					end
				end
			end
		end
	end
end

function zgPoppy:RSemiManual()
	if IsReady(_R) and GetEnemyCount(self.r2Spell.Range, myHero.pos) > 0 and lastR + 450 < GetTickCount() then
		if not (myHero.activeSpell.isCharging and Control.IsKeyDown(HK_R)) then
			Control.KeyDown(HK_R)
			self.rCastTimer = GetTickCount()
			lastR = GetTickCount()
		end
	end
end

function zgPoppy:R2()
	if GetTickCount() > self.rCastTimer + 450 and myHero.activeSpell.isCharging then
		local buff, buffData = GetBuffData(myHero, "PoppyR")
		if buff and buffData.duration < 2.9 then
			local target = GetTarget(self.r2Spell.Range)
			if IsValid(target) then
				self:CastR(target, self.r2Spell)
			end
		end
	end
end

function zgPoppy:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgPoppy:CastR(target, Spell)
	local Pred = GGPrediction:SpellPrediction(Spell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_R, Pred.CastPosition)
	end
end

function zgPoppy:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.r2Spell.Range, Draw.Color(192, 255, 255, 255))
	end
end

zgPoppy()