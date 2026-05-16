local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgKogMaw"

function zgKogMaw:__init()		 
	print("Zgjfjfl AIO - KogMaw Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1175, Speed = 1650, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1200, Speed = 1400, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1, Radius = 120, Range = 1300, Speed = math.huge, Collision = false}
end

function zgKogMaw:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 1100, min = 600, max = 1175, step = 50})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Range", value = 1100, min = 600, max = 1200, step = 50})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rstack", name = "Use R|Check R stacks", value = true})
	Menu.Combo:MenuElement({id = "Rstacks", name = "Check R stacks|Stop at x stacks", value = 3, min = 1, max = 9, step = 1})
	Menu.Combo:MenuElement({id = "Ronlylow", name = "Use R|Only 0-40 % HP enemies", value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 1100, min = 600, max = 1175, step = 50})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Range", value = 1100, min = 600, max = 1200, step = 50})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SMR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "Rks", name = "Auto R KillSteal", value = true})
	Menu.Misc:MenuElement({id = "stopq", name = "Stop using Q when has W", value = false})
	Menu.Misc:MenuElement({id = "stope", name = "Stop using E when has W", value = false})
	Menu.Misc:MenuElement({id = "stopr", name = "Stop using R when has W", value = false})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function zgKogMaw:OnTick()
	self.QSpell.Delay = myHero.attackData.windUpTime
	self.RSpell.Range = 1050 + 250 * myHero:GetSpellData(_R).level
	if ShouldWait() then
		return
	end

	if IsCasting() then return end

	self:RKS()
	if Menu.Misc.SMR:Value() then
		self:SMR()
	end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgKogMaw:SMR()
	if IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_R, target)
		end
	end
end
	
function zgKogMaw:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		if not Menu.Misc.stopq:Value() or not HaveBuff(myHero, "KogMawBioArcaneBarrage") then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Qrange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		if not Menu.Misc.stope:Value() or not HaveBuff(myHero, "KogMawBioArcaneBarrage") then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Erange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_E, target)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(610 + 20 * myHero:GetSpellData(_W).level + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			Control.CastSpell(HK_W)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local buff, buffData = GetBuffData(myHero, "kogmawlivingartillerycost")
		if Menu.Combo.Rstack:Value() and buff and buffData.count >= Menu.Combo.Rstacks:Value() then
			return
		end
		if Menu.Misc.stopr:Value() and HaveBuff(myHero, "KogMawBioArcaneBarrage") then
			return
		end
		local enemies = {}
		local target = _G.SDK.Orbwalker:GetTarget()
		if Menu.Combo.Ronlylow:Value() then
			if target and target.health * 100 / target.maxHealth >= 40 then
				target = nil
			end
			if target == nil then
				for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
					if IsValid(unit) and ((unit.health + (unit.hpRegen * 3)) * 100) / unit.maxHealth < 40 then
						table.insert(enemies, unit)
					end
				end
			end
		elseif target == nil then
			enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
		end
		if target == nil then target = GetTarget(enemies) end
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			self:CastGGPred(HK_R, target)
		end
	end
end

function zgKogMaw:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		if not Menu.Misc.stopq:Value() or not HaveBuff(myHero, "KogMawBioArcaneBarrage") then
			local target = GetTarget(Menu.Harass.Qrange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		if not Menu.Misc.stope:Value() or not HaveBuff(myHero, "KogMawBioArcaneBarrage") then
			local target = GetTarget(Menu.Harass.Erange:Value())
			if IsValid(target) and target.pos:ToScreen().onScreen then 
				self:CastGGPred(HK_E, target)
			end
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(610 + 20 * myHero:GetSpellData(_W).level + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then 
			Control.CastSpell(HK_W)
		end
	end
end

function zgKogMaw:RKS()
	if not (Menu.Misc.Rks:Value() and IsReady(_R)) then
		return
	end
	local baseRDmg = 60 + (40 * myHero:GetSpellData(_R).level) + (myHero.bonusDamage * 0.75) + (myHero.ap * 0.35)
	for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
		if IsValid(unit) and unit.pos2D.onScreen then
			local health = unit.health
			local hpRegen = unit.hpRegen
			local rMultipier = math.floor(100 - (((health + (hpRegen * 3)) * 100) / unit.maxHealth))
			local rDmg = rMultipier > 60 and baseRDmg * 2 or baseRDmg * (1 + (rMultipier * 0.00833))
			if _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg) > health + (hpRegen * 2) then
				if self:CastGGPred(HK_R, unit) then
					break
				end
			end
		end
	end
end

function zgKogMaw:CastGGPred(spell, target)
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
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgKogMaw:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgKogMaw()
