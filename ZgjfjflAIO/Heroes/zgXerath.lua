local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgXerath"

function zgXerath:__init()		 
	print("Zgjfjfl AIO - Xerath Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.528, Radius = 100, Range = 750, Speed = math.huge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.778, Radius = 250, Range = 1000, Speed = math.huge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1125, Speed = 1400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.627, Radius = 200, Range = 5000, Speed = math.huge, Collision = false}
	self.QTick = 0
	self.QCharging = false
	self.RCharging = false
	self.WCastTime = 0
	self.EHitTime = 0
end

function zgXerath:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Max Range", value = 1000, min = 600, max = 1125, step = 25})
	Menu.Combo:MenuElement({id = "R", name = "Use R On Target Near Mouse", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Max Range", value = 1000, min = 600, max = 1125, step = 25})

	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
	Menu.AutoE:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser or Melee", toggle = true, value = true})
	Menu.AutoE:MenuElement({id = "EgapRange", name = "AntiGap E Range(dash endPos form self < X)", value = 400, min = 0, max = 600, step = 50})
	Menu.AutoE:MenuElement({id = "EgapRange2", name = "AntiMelee E Range(melee form self < X)", value = 350, min = 0, max = 600, step = 50})
	
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rminimap", name = "[R] Range on minimap", toggle = true, value = true})

end

function zgXerath:OnTick()
	if myHero.activeSpell.isCharging then
		if self.QCharging == false then
			self.QTick = GetTickCount()
			self.QCharging = true
		end
	else
		self.QCharging = false
	end

	if self.QCharging == true then
		self.QSpell.Range = math.min(600 + 500 * (GetTickCount() - self.QTick) / 1000, 1500)
	else
		self.QSpell.Range = 600
	end
	
	if Control.IsKeyDown(HK_Q) == true and Game.CanUseSpell(_Q) ~= 0 then
		Control.KeyUp(HK_Q)
	end

	if myHero:GetSpellData(_R).name == "XerathRMissileWrapper" then
		self.RCharging = true
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	elseif myHero.activeSpell.isCharging or myHero.activeSpell.name == "XerathArcanopulse2" then
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		self.RCharging = false
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end

	if ShouldWait() then
		return
	end
	if Menu.Combo.R:Value() and not IsCasting() then
		self:CastR()
	end
	self:AntiGapcloser()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgXerath:OnPreAttack(args)
	local mode = GetMode()
	if (mode == "Combo" or mode == "Harass") and args.Target.type == Obj_AI_Hero then
		local useQ = Menu[mode].Q:Value()
		local useW = Menu[mode].W:Value()
		local useE = Menu[mode].E:Value()
		if (IsReady(_Q) and useQ or IsReady(_W) and useW or IsReady(_E) and useE) then
			args.Process = false
		end
	end
end

function zgXerath:AntiGapcloser()
	if Menu.AutoE.Egap:Value() and IsReady(_E) and not IsCasting() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				if target.pathing.isDashing then
					local endPos = Vector(target.pathing.endPos)
					if myHero.pos:DistanceTo(endPos) < Menu.AutoE.EgapRange:Value() and IsFacingMe(target) then
						self:CastGGPred(HK_E, target)
						return
					end
				end
				if myHero.pos:DistanceTo(target.pos) < Menu.AutoE.EgapRange2:Value() then
					self:CastGGPred(HK_E, target)
					return
				end
			end	
		end
	end
end

function zgXerath:CastR()
	if self.RCharging == true and Game.CanUseSpell(_R) == 0 then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		table.sort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) then
			self:CastGGPred(HK_R, enemies[1])
		end
	end
end
	
function zgXerath:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) and not IsCasting() and Game.Timer() > self.EHitTime then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			self:CastGGPred(HK_W, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and not IsCasting() and (not Menu.Combo.W:Value() or (not IsReady(_W) and Game.Timer() > self.WCastTime + self.WSpell.Delay)) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() then
		if self.QCharging then
			local target = GetTarget(1500)
			if IsValid(target) then
				self:CastGGPred(HK_Q, target)
			end
		else
			if not IsCasting() and IsReady(_Q) then
				local target = GetTarget(1500)
				if IsValid(target) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, self.ESpell.CollisionTypes, target.networkID)
					if target.distance > self.WSpell.Range or 
						((not Menu.Combo.E:Value() or (not IsReady(_E) and Game.Timer() > self.EHitTime or collisionCount > 0)) and
						(not Menu.Combo.W:Value() or (not IsReady(_W) and Game.Timer() > self.WCastTime + self.WSpell.Delay))) then
						Control.KeyDown(HK_Q)
					end
				end
			end
		end
	end
end

function zgXerath:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) and not IsCasting() and Game.Timer() > self.EHitTime then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			self:CastGGPred(HK_W, target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) and not IsCasting() and (not Menu.Harass.W:Value() or (not IsReady(_W) and Game.Timer() > self.WCastTime + self.WSpell.Delay)) then
		local target = GetTarget(Menu.Harass.Erange:Value())
		if IsValid(target) then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Harass.Q:Value() then
		if self.QCharging then
			local target = GetTarget(1500)
			if IsValid(target) then
				self:CastGGPred(HK_Q, target)
			end
		else
			if not IsCasting() and IsReady(_Q) then
				local target = GetTarget(1500)
				if IsValid(target) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, self.ESpell.CollisionTypes, target.networkID)
					if target.distance > self.WSpell.Range or 
						((not Menu.Harass.E:Value() or (not IsReady(_E) and Game.Timer() > self.EHitTime or collisionCount > 0)) and
						(not Menu.Harass.W:Value() or (not IsReady(_W) and Game.Timer() > self.WCastTime + self.WSpell.Delay))) then
						Control.KeyDown(HK_Q)
					end
				end
			end
		end
	end
end

function zgXerath:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
			if Control.CastSpell(HK_W, WPrediction.CastPosition) then
				self.WCastTime = Game.Timer()
			end
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			if Control.CastSpell(HK_E, EPrediction.CastPosition) then
				self.EHitTime = Game.Timer() + EPrediction.TimeToHit
			end
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgXerath:Draw()
	if myHero.dead then return end
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
	if Menu.Draw.Rminimap:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, self.RSpell.Range, 1, Draw.Color(200, 50, 180, 230))
	end
end

zgXerath()
