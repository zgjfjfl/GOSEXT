local Version = 1.04

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgBlitzcrank"

function zgBlitzcrank:__init()		 
	print("Zgjfjfl AIO - Blitzcrank Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1080, Speed = 1800, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = { Range = 600, Delay = 0.25 }
end

function zgBlitzcrank:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Quseon", name = "Use Q on: ", type = MENU})
		_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
			Menu.Combo.Quseon:MenuElement({id = args.charName, name = args.charName, value = true})
		end)
	Menu.Combo:MenuElement({id = "Qminrange", name = "Use Q|Min Range", value = 250, min = 250, max = 1080, step = 10})
	Menu.Combo:MenuElement({id = "Qmaxrange", name = "Use Q|Max Range", value = 1000, min = 250, max = 1080, step = 10})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Renemies", name = "Use R|X Enemies", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Quseon", name = "Use Q on: ", type = MENU})
		_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
			Menu.Harass.Quseon:MenuElement({id = args.charName, name = args.charName, value = true})
		end)
	Menu.Harass:MenuElement({id = "Qminrange", name = "Use Q|Min Range", value = 250, min = 250, max = 500, step = 10})
	Menu.Harass:MenuElement({id = "Qmaxrange", name = "Use Q|Max Range", value = 1000, min = 250, max = 1080, step = 10})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgBlitzcrank:OnPreAttack(args)
	local target = args.Target and args.Target.type == Obj_AI_Hero
	if target and IsReady(_E) and lastE + 300 < GetTickCount() then
		if GetMode() == "Combo" and Menu.Combo.E:Value() then
			if Control.CastSpell(HK_E) then
				lastE = GetTickCount()
			end
		elseif GetMode() == "Harass" and Menu.Harass.E:Value() then
			if Control.CastSpell(HK_E) then
				lastE = GetTickCount()
			end
		end
	end
end

function zgBlitzcrank:OnTick()
	if ShouldWait() then
		return
	end
	if myHero.activeSpell.name == "PowerFistAttack" then
		_G.SDK.Attack.Reset = false
	end
	if IsCasting() then return end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgBlitzcrank:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) then
		local Count = 0
		for _, enemy in ipairs(GetEnemyHeroes()) do
			if IsValid(enemy) then
				local enemyPred = enemy:GetPrediction(math.huge, self.RSpell.Delay)
				if myHero.pos:DistanceTo(enemyPred) < self.RSpell.Range - 50 then
					Count = Count + 1
				end
			end
		end
		
		if Count >= Menu.Combo.Renemies:Value() then
			Control.CastSpell(HK_R)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.Qmaxrange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			local canuse = Menu.Combo.Quseon[target.charName]
			if canuse and canuse:Value() then
				if target.distance > Menu.Combo.Qminrange:Value() then
					self:CastQ(target)
				end
			end
		end
	end
end

function zgBlitzcrank:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qmaxrange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			local canuse = Menu.Harass.Quseon[target.charName]
			if canuse and canuse:Value() then
				if target.distance > Menu.Harass.Qminrange:Value() then
					self:CastQ(target)
				end
			end
		end
	end
end

function zgBlitzcrank:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end

function zgBlitzcrank:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgBlitzcrank()
