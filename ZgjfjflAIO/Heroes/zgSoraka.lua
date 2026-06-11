local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSoraka"

function zgSoraka:__init()
	print("Zgjfjfl AIO - Soraka Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 230, Range = 915, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Range = 550}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 260, Range = 925, Speed = math.huge, Collision = false}
end

function zgSoraka:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = true})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when spell ready)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Heal", name = "Heal Settings"})
	Menu.Heal:MenuElement({id = "Enemy", name = "Healing Only When Enemies Nearby", toggle = true, value = true})
	Menu.Heal:MenuElement({id = "W", name = "Auto [W] Heal", toggle = true, value = true})
	Menu.Heal:MenuElement({id = "Wmin", name = "Auto [W] Ally < HP%", value = 50, min = 0, max = 100, step = 5})
	Menu.Heal:MenuElement({id = "WMmin", name = "Auto [W] Self > HP%", value = 20, min = 0, max = 100, step = 5})
	Menu.Heal:MenuElement({id = "Priority", name = "Healing Priority", value = 4, drop = {"Most AD", "Most AP", "Least Health", "Least Health (Prioritize Squishies)"}})
	Menu.Heal:MenuElement({type = MENU,id = "WHealTarget", name = "UseW On"})
		_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
			if args.charName ~= myHero.charName then
				Menu.Heal.WHealTarget:MenuElement({id = args.charName, name = args.charName, value = true})
			end
		end)
	Menu.Heal:MenuElement({id = "R", name = "Auto [R] Heal", toggle = true, value = true})
	Menu.Heal:MenuElement({id = "Rmin", name = "Auto [R] Ally < HP%", value = 20, min = 0, max = 100, step = 5})
	Menu.Heal:MenuElement({type = MENU,id = "RHealTarget", name = "UseR On"})
		_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
			Menu.Heal.RHealTarget:MenuElement({id = args.charName, name = args.charName, value = true})			
		end)
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] On CC or Slow", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] On CC or Slow", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
end

function zgSoraka:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgSoraka:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	end
	self:AutoQE()
	self:AutoW()
	self:AutoR()
end

function zgSoraka:OnPreAttack(args)
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() and (IsReady(_Q) or IsReady(_E)) then
			args.Process = false
		end
	end
end

function zgSoraka:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
end

function zgSoraka:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.QSpell.Range then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgSoraka:AutoW()
	if not (Menu.Heal.W:Value() and IsReady(_W)) then return end
	if myHero.health/myHero.maxHealth < Menu.Heal.WMmin:Value()/100 then return end
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.WSpell.Range)
	local validAllies = {}
	for _, ally in ipairs(allies) do
		if Menu.Heal.WHealTarget[ally.charName] and Menu.Heal.WHealTarget[ally.charName]:Value() then
			if IsValid(ally) and ally.health/ally.maxHealth <= Menu.Heal.Wmin:Value()/100 then
				if not Menu.Heal.Enemy:Value() or GetEnemyCount(1500, ally.pos) > 0 then
					table.insert(validAllies, ally)
				end
			end
		end
	end
	if #validAllies == 0 then return end
	local priorityMode = Menu.Heal.Priority:Value()
	if priorityMode == 1 then
		table.sort(validAllies, function(a, b) 
			return a.totalDamage > b.totalDamage 
		end)
	elseif priorityMode == 2 then
		table.sort(validAllies, function(a, b) 
			return a.ap > b.ap 
		end)
	elseif priorityMode == 3 then
		table.sort(validAllies, function(a, b) 
			return a.health < b.health 
		end)
	elseif priorityMode == 4 then
		table.sort(validAllies, function(a, b)
			if a.health == b.health then
				return a.maxHealth < b.maxHealth
			else
				return a.health < b.health
			end
		end)
	end
	for _, target in ipairs(validAllies) do
		Control.CastSpell(HK_W, target)
		return
	end
end

function zgSoraka:AutoR()
	if Menu.Heal.R:Value() and IsReady(_R) then
		for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
			if Menu.Heal.RHealTarget[ally.charName] and Menu.Heal.RHealTarget[ally.charName]:Value() then		
				if IsValid(ally) and ally.health/ally.maxHealth <= Menu.Heal.Rmin:Value()/100 then
					if not Menu.Heal.Enemy:Value() or GetEnemyCount(1500, ally.pos) > 0 then
						Control.CastSpell(HK_R)
					end
				end
			end
		end
	end	
end

function zgSoraka:AutoQE()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and (IsHardCC(target) or IsSlow(target)) then
			if Menu.Auto.Q:Value() and IsReady(_Q) then
				self:CastGGPred(HK_Q, target)
			end
			if Menu.Auto.E:Value() and IsReady(_E) then
				self:CastGGPred(HK_E, target)
			end
		end
	end
end

function zgSoraka:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			local castPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 800)
			if myHero.pos:DistanceTo(QPrediction.CastPosition) <= 800 then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			else
				Control.CastSpell(HK_Q, castPos)
			end
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function zgSoraka:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgSoraka()