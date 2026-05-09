local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAmbessa"

function zgAmbessa:__init()
	print("Zgjfjfl AIO - Ambessa Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.Q1Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 100, Range = 375, Speed = math.huge, Collision = false}
	self.Q2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.225, Radius = 15, Range = 650, Speed = math.huge, Collision = false}
	self.WSpell = { Range = 325 }
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 100, Range = 325, Speed = math.huge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.7, Radius = 15, Range = 1250, Speed = math.huge, Collision = false}
end

function zgAmbessa:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q2", name = "Use Q2", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q2", name = "Use Q2", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Q", name = "Use Q Dash to Mouse", toggle = true, value = true})
	Menu.Flee:MenuElement({id = "W", name = "Use W Dash to Mouse", toggle = true, value = true})
	Menu.Flee:MenuElement({id = "E", name = "Use E Dash to Mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgAmbessa:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgAmbessa:OneKeyCastR()
	local Rtarget = GetTarget(self.RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		self:CastGGPred(HK_R, Rtarget)
	end
end

function zgAmbessa:Combo()
	local canUsePassiveAA = HaveBuff(myHero, "AmbessaPassiveAttackEmpower")
	local target = GetTarget(myHero.range + myHero.boundingRadius * 2)
	if canUsePassiveAA and IsValid(target) then
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_W, target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.Q1Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Combo.Q2:Value() and IsReady(_Q) and HaveBuff(myHero, "AmbessaQEmpowerReady") then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgAmbessa:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.Q1Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Harass.Q2:Value() and IsReady(_Q) and HaveBuff(myHero, "AmbessaQEmpowerReady") then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

local lastCastTime = 0
local CAST_DELAY = 0.5
function zgAmbessa:Flee()
	local currentTime = Game.Timer()
	if currentTime - lastCastTime < CAST_DELAY then
		return
	end
	if Menu.Flee.Q:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
		lastCastTime = currentTime
		return 
	end
	if Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, mousePos)
		lastCastTime = currentTime
		return 
	end
	if Menu.Flee.E:Value() and IsReady(_E) then
		Control.CastSpell(HK_E, mousePos)
		lastCastTime = currentTime
		return 
	end
end

function zgAmbessa:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(HaveBuff(myHero, "AmbessaQEmpowerReady") and self.Q2Spell or self.Q1Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgAmbessa:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, HaveBuff(myHero, "AmbessaQEmpowerReady") and self.Q2Spell.Range or self.Q1Spell.Range, 1, Draw.Color(255, 66, 244, 113))
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
end

zgAmbessa()