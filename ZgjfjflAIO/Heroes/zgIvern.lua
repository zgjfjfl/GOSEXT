local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgIvern"

function zgIvern:__init()		 
	print("Zgjfjfl AIO - Ivern Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1150, Speed = 1300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.eSpell = { Range = 750, Radius = 500 }
	self.rSpell = { Range = 800 }
end

function zgIvern:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R1]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q1]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
		Menu.AutoE:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
		Menu.AutoE.Etarget:MenuElement({id = "Daisy", name = "Daisy", value = true})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoE.Etarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "Daisy", name = "Daisy Setting"})
		Menu.Daisy:MenuElement({id = "R1", name = "Control 'Daisy' attack target", key = string.byte("T")})
		Menu.Daisy:MenuElement({id = "R2", name = "Control 'Daisy' follow self", key = string.byte("Z")})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
		Menu.Misc:MenuElement({id = "disableAA", name = "Disable AA", toggle = true, value = true})
		Menu.Misc:MenuElement({id = "count", name = "DisableAA when >= X enemies inQrange", value = 3, min = 1 , max = 5 , step = 1})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function zgIvern:Tick()
	if ShouldWait() then
		return
	end
	if Menu.Misc.disableAA:Value() and GetEnemyCount(self.qSpell.Range, myHero.pos) >= Menu.Misc.count:Value() then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
	if Menu.AutoE.E:Value() then
		self:AutoE()
	end
	if myHero:GetSpellData(_R).name == "IvernRRecast" then
		self:DaisyControl()
	end
end

function zgIvern:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgIvern:Combo()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "IvernQ" then
			self:CastQ(target)
		end
		if Menu.Combo.R:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "IvernR" then
			if myHero.pos:DistanceTo(target.pos) < self.rSpell.Range then
				Control.CastSpell(HK_R, target)
			end
		end
	end
end

function zgIvern:CastE(unit)
	if unit.isMe then
		Control.KeyDown(0x12)  -- Alt key
		Control.KeyDown(HK_E)
		DelayAction(function()
			Control.KeyUp(HK_E)
			Control.KeyUp(0x12)
		end, 0.01)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function zgIvern:AutoE()
	if IsReady(_E) and lastE + 250 < GetTickCount() then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.eSpell.Range)
		local validAllies = {}
		
		local daisy = self:GetDaisy()
        if daisy and Menu.AutoE.Etarget.Daisy and Menu.AutoE.Etarget.Daisy:Value() then
            table.insert(validAllies, daisy)
        end
		for _, ally in ipairs(allies) do
			if Menu.AutoE.Etarget[ally.charName] and Menu.AutoE.Etarget[ally.charName]:Value() then
				table.insert(validAllies, ally)
			end
		end
		local urgentAlly = nil
		for _, ally in ipairs(validAllies) do
			if IsPoison(ally) then
				urgentAlly = ally
				break
			end
			local enemyTowers = _G.SDK.ObjectManager:GetEnemyTurrets(2000)
			for _, turret in ipairs(enemyTowers) do
				if turret and turret.targetID == ally.networkID then
					urgentAlly = ally
					break
				end
			end
			if urgentAlly then break end
		end
		if urgentAlly and IsValid(urgentAlly) then
			self:CastE(urgentAlly)
			lastE = GetTickCount()
			return
		end
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
		local bestAlly, minDist = nil, math.huge
		for _, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				for _, ally in ipairs(validAllies) do
					local dist = ally.pos:DistanceTo(enemy.pos)
					if dist < self.eSpell.Radius and dist < minDist then
						bestAlly = ally
						minDist = dist
					end
				end
			end
		end
		if bestAlly and IsValid(bestAlly) and bestAlly.distance <= self.eSpell.Range then
			self:CastE(bestAlly)
			lastE = GetTickCount()
		end
	end
end

function zgIvern:GetDaisy()
	if myHero:GetSpellData(_R).name ~= "IvernRRecast" then
		return nil
	end
	local minions = _G.SDK.ObjectManager:GetAllyMinions()
	for i = 1, #minions do
		local minion = minions[i]
		if minion and minion.charName == "IvernMinion" then
			return minion
		end
	end
	return nil
end

function zgIvern:DaisyControl()
	if Menu.Daisy.R1:Value() and lastR + 250 < GetTickCount() then
		local target = GetTarget(2000)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_R, target)
			lastR = GetTickCount()
		end
	end
	if Menu.Daisy.R2:Value() and lastR + 250 < GetTickCount() then
		Control.CastSpell(HK_R, myHero)
		lastR = GetTickCount()
	end
end

function zgIvern:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "IvernQ" then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgIvern:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end

zgIvern()