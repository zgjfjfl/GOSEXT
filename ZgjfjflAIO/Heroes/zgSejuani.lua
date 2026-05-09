local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSejuani"

function zgSejuani:__init()		 
	print("Zgjfjfl AIO - Sejuani Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 650, Speed = 1000, Collision = false}
	self.wSpell = { Range = 600 }
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1300, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.eSpell = { Range = 600 }
end

function zgSejuani:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgSejuani:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
end

function zgSejuani:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_E)
		end
	end
end

function zgSejuani:Harass()
	local target = GetTarget(self.wSpell.Range)
	if IsValid(target) then
		if Menu.Harass.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W, target)
		end
	end
end

function zgSejuani:RSemiManual()
	local target = GetTarget(self.rSpell.Range)
	if IsValid(target) then
		if IsReady(_R) then
			self:CastR(target)
		end
	end
end

function zgSejuani:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgSejuani:CastR(target)
	local Pred = GGPrediction:SpellPrediction(self.rSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_R, Pred.CastPosition)
	end
end

function zgSejuani:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(255, 225, 255, 10))
	end
end

zgSejuani()