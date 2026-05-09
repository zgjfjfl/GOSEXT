local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgNasus"

function zgNasus:__init()		 
	print("Zgjfjfl AIO - Nasus Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.wSpell = { Range = 700 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 650, Speed = math.huge, Collision = false}
end

function zgNasus:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Auto Use when self HP %", value = 30, min = 10, max = 100})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
		Menu.Clear:MenuElement({id = "EH", name = "E hits x minions", value = 3, min = 1, max = 6})
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function zgNasus:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if GetEnemyCount(700, myHero.pos) >= 1 and myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value()/100 and Menu.Combo.R:Value() and IsReady(_R) then
		Control.CastSpell(HK_R)
	end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
		self:LastHit()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:LastHit()
	elseif Mode == "LastHit" then
		self:LastHit()
	end
	self:KillSteal()
end

function zgNasus:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(myHero.range + myHero.boundingRadius * 2 + 50)
		if IsValid(target) then
			if Control.CastSpell(HK_Q) then
				lastQ = GetTickCount()
			end
		end
	end
end

function zgNasus:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.eSpell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_E, pred.UnitPosition)
	end
end

function zgNasus:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(myHero.range + myHero.boundingRadius * 2 + 50)
		if IsValid(target) then
			if Control.CastSpell(HK_Q) then
				lastQ = GetTickCount()
			end
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
end

function zgNasus:LaneClear()
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.eSpell.Range)
	for _, minion in ipairs(minions) do
		if IsValid(minion) then
			if Menu.Clear.E:Value() and IsReady(_E) then
				if GetMinionCount(self.eSpell.Radius, minion.pos) >= Menu.Clear.EH:Value() then
					Control.CastSpell(HK_E, minion)
				end
			end
			if Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
				if myHero.pos:DistanceTo(minion.pos) < (myHero.range + myHero.boundingRadius * 2 + 50) and self:GetQDmg(minion) >= minion.health then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
					Control.Attack(minion)
				end
			end
		end
	end
end

function zgNasus:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(myHero.range + myHero.boundingRadius * 2 + 50)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and  self:GetQDmg(minion) >= minion.health then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				Control.Attack(minion)
			end
		end
	end
end

function zgNasus:KillSteal()
	if IsReady(_E) and Menu.KS.E:Value() then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) and self:GetEDmg(target) >= target.health then
			Control.CastSpell(HK_E, target)
		end
	end
	if IsReady(_Q) and lastQ + 250 < GetTickCount() and Menu.KS.Q:Value() then
		local target = GetTarget(myHero.range + myHero.boundingRadius * 2 + 50)
		if IsValid(target) and self:GetQDmg(target) >= target.health then			
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
			Control.Attack(target)
		end
	end
end

function zgNasus:GetQDmg(target)
	local buff, buffData = GetBuffData(myHero, "NasusQStacks")
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 20 * qlvl + 15
	local qDmg = qbaseDmg + (buff and buffData.stacks or 0) + myHero.totalDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function zgNasus:GetEDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 40 * elvl + 15
	local eapDmg = 0.6 * myHero.ap
	local eDmg = ebaseDmg + eapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function zgNasus:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end

zgNasus()