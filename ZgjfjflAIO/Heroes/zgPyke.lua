local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgPyke"

function zgPyke:__init()		 
	print("Zgjfjfl AIO - Pyke Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 70, Range = 1100, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 100, Range = 750, Speed = math.huge, Collision = false}
	self.QTick = 0
	self.QCharging = false
end

function zgPyke:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
	Menu.AutoR:MenuElement({id = "kills", name = "Auto R KillSteal", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgPyke:OnTick()
	if myHero.activeSpell.isCharging then
		if self.QCharging == false then
			self.QTick = GetTickCount() + 400
			self.QCharging = true
		end
	else
		self.QCharging = false
	end

	if self.QCharging == true then
		self.QSpell.Range = math.min(400 + (1166 * (GetTickCount() - self.QTick) / 1000), 1100)
	else
		self.QSpell.Range = 400
	end
	
	if Control.IsKeyDown(HK_Q) == true and Game.CanUseSpell(_Q) ~= 0 then
		Control.KeyUp(HK_Q)
	end

	if HaveBuff(myHero, "PykeQ") then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end

	if ShouldWait() then
		return
	end
	self:AutoR()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgPyke:AutoR()
	if Menu.AutoR.kills:Value() and IsReady(_R) and lastR + 1000 < GetTickCount() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.health + target.shieldAD + target.hpRegen < self:GetRDmg() then
				self:CastGGPred(HK_R, target)
				lastR = GetTickCount()
			end
		end
	end
end

function zgPyke:GetRDmg()
	local level = myHero.levelData.lvl
	local baseDmg = ({ 250, 250, 250, 250, 250, 250, 290, 330, 370, 400, 430, 450, 470, 490, 510, 530, 540, 550 })[level]
	return baseDmg + 0.8 * myHero.bonusDamage + 1.5 * myHero.armorPen
end
	
function zgPyke:Combo()
	if Menu.Combo.Q:Value() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1100)
		if self.QCharging == true then
			local target = GetTarget(enemies)
			if IsValid(target) then
				self:CastGGPred(HK_Q, target)
			end
		else
			if IsReady(_Q) and not IsCasting() and #enemies > 0 then
				Control.KeyDown(HK_Q)
			end
		end
	end
end

function zgPyke:Harass()
	if Menu.Harass.Q:Value() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1100)
		if self.QCharging == true then
			local target = GetTarget(enemies)
			if IsValid(target) then
				self:CastGGPred(HK_Q, target)
			end
		else
			if IsReady(_Q) and not IsCasting() and #enemies > 0 then
				Control.KeyDown(HK_Q)
			end
		end
	end
end

function zgPyke:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgPyke:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgPyke()
