local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAhri"

function zgAhri:__init()		 
	print("Zgjfjfl AIO - Ahri Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 970, Speed = 1100, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.selectedTarget = nil
	self.targetTimer = 0
end

function zgAhri:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "EAntiDash", name = "Auto E AntiDash", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function zgAhri:OnTick()
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
	end
end

function zgAhri:OnPreAttack(args)
	if GetMode() == "Combo" then
		if IsReady(_Q) or IsReady(_E) then
			args.Process = false
		end
	end
end

function zgAhri:AutoE()
	if Menu.Misc.EAntiDash:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i = 1, #enemies do
			local enemy = enemies[i]
			local path = enemy.pathing
			if path and path.isDashing and enemy.posTo then
				if myHero.pos:DistanceTo(enemy.posTo) < myHero.pos:DistanceTo(enemy.pos) then
					self:CastGGPred(HK_E, enemy)
					break
				end
			end
		end
	end
end
	
function zgAhri:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			self.targetTimer = os.clock()
			self.selectedTarget = target
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance <= Menu.Combo.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgAhri:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Harass.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			self.targetTimer = os.clock()
			self.selectedTarget = target
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance < Menu.Harass.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgAhri:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function zgAhri:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end
zgAhri()
