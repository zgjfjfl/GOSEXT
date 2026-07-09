local Version = 1.03

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgVex"

function zgVex:__init()		 
	print("Zgjfjfl AIO - Vex Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 180, Range = 1200, Speed = 600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 200, Range = 950, Speed = 1300, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 130, Range = 2000, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}}
	self.selectedTarget = nil
	self.targetTimer = 0
end

function zgVex:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 1100, min = 550, max = 1200, step = 10})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R1", name = "Semi-manual R1", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 1100, min = 500, max = 1200, step = 10})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
	Menu.Auto:MenuElement({id = "AutoW", name = "Auto W enemy in Range", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgVex:OnTick()
	self.RSpell.Range = 1500 + (500 * myHero:GetSpellData(_R).level)
	if ShouldWait() then
		return
	end

	if IsCasting() then return end
	self:AutoW()
	if Menu.Combo.R1:Value() then
		self:SMR1()
	end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgVex:OnPreAttack(args)
	if GetMode() == "Combo" then
		if IsReady(_Q) or IsReady(_E) then
			args.Process = false
		end
	end
end

function zgVex:SMR1()
	if IsReady(_R) and myHero:GetSpellData(_R).name == "VexR" then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_R, target)
		end
	end
end

function zgVex:AutoW()
	if Menu.Auto.AutoW:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local Count = 0
		for _, enemy in ipairs(GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(math.huge, 0.25)
				if myHero.pos:DistanceTo(enemyPred) < 450 then
					Count = Count + 1
				end
			end
		end

		if Count >= 1 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
end
	
function zgVex:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			self.targetTimer = os.clock()
			self.selectedTarget = target
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and (not Menu.Combo.E:Value() or not IsReady(_E)) then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance <= Menu.Combo.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgVex:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
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

function zgVex:GetQParams(source, target)
	local distance = GetDistance(source.pos, target.pos)
	local accelerationDistance = 550
	if distance <= accelerationDistance then
		return 600, 180
	else
		local initialTime = accelerationDistance / 600
		local remainingDistance = distance - accelerationDistance
		local acceleratedTime = remainingDistance / 3200
		local totalTime = initialTime + acceleratedTime
		local speed = distance / totalTime
		return speed, 80
	end
end

function zgVex:CastGGPred(spell, target)
	if spell == HK_Q then
		local speed, radius = self:GetQParams(myHero, target)
		self.QSpell.Speed = speed
		self.QSpell.Radius = radius
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			local castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), 800)
			if myHero.pos:DistanceTo(EPrediction.CastPosition) <= 800 then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
			else
				Control.CastSpell(HK_E, castPos)
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

function zgVex:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 475, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgVex()
