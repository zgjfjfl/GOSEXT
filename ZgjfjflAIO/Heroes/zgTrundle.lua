local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgTrundle"

function zgTrundle:__init()		 
	print("Zgjfjfl AIO - Trundle Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 775, Range = 750, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1000, Speed = math.huge, Collision = false}
	self.rSpell = { Range = 650 }
end

function zgTrundle:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "[R] Use when self HP %", value = 60, min = 0, max = 100, step = 5})	
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgTrundle:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgTrundle:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) > 350 then
			local offset = IsFacingMe(target) and 100 or 200
			local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) + offset)
			if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
				Control.CastSpell(HK_E, castPos)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(self.rSpell.Range)
		if IsValid(target) and (myHero.health/myHero.maxHealth <= Menu.Combo.RHP:Value() / 100) then
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgTrundle:LaneClear()
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if not target then
		target = _G.SDK.HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < 300 and Menu.Clear.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount()then
			Control.CastSpell(HK_W, myHero)
			lastW = GetTickCount()
		end
		if myHero.pos:DistanceTo(target.pos) <= 300 and Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount()then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function zgTrundle:Harass()
	local target = GetTarget(350)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function zgTrundle:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		Control.CastSpell(HK_W, mousePos)
		lastW = GetTickCount()
	end
	local target = GetTarget(self.eSpell.Range)
	if IsValid(target) then
		if Menu.Flee.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			local castPos = Vector(myHero.pos) + Vector(Vector(target.pos) - Vector(myHero.pos)):Normalized() * (myHero.pos:DistanceTo(target.pos) - 100)
			Control.CastSpell(HK_E, castPos)
		end
	end
end

function zgTrundle:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end

zgTrundle()