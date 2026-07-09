local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgJhin"

function zgJhin:__init()		 
	print("Zgjfjfl AIO - Jhin Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = { Range = 550 }
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Radius = 40, Range = 2500, Speed = 5000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = { Range = 750 }
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 3500, Speed = 5000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgJhin:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Wnoaa", name = "Use W|Only not within aaRange", value = true})
	Menu.Combo:MenuElement({id = "Wpassive", name = "Use W|Only has passive", value = true})
	Menu.Combo:MenuElement({id = "Wrange", name = "Use W|Range", value = 2400, min = 1000, max = 2500, step = 50})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Wpassive", name = "Use W|Only has passive", value = true})
	
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "AutoW", name = "Auto W kills", value = true})
	Menu.Auto:MenuElement({id = "AutoE", name = "Auto E on cc", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgJhin:OnTick()
	if ShouldWait() then
		return
	end
	if self:HasRBuff() then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
		self:ComboR()
		return
	else
		_G.SDK.Orbwalker:SetAttack(true)
		_G.SDK.Orbwalker:SetMovement(true)
	end
	if IsCasting() then return end
	self:AutoW()
	self:AutoE()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgJhin:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({70, 105, 140, 175, 210})[level] + 0.5 * myHero.totalDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
end

function zgJhin:AutoW()
	if Menu.Auto.AutoW:Value() and IsReady(_W) then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)) do
			if IsValid(enemy) and enemy.pos2D.onScreen and not _G.SDK.Data:IsInAutoAttackRange(myHero, enemy) then
				if enemy.health < self:GetWDmg(enemy) then
					self:CastGGPred(HK_W, enemy)
				end
			end
		end
	end
end

function zgJhin:AutoE()
	if Menu.Auto.AutoE:Value() and IsReady(_E) and not self:FourthShot() then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)) do
			if IsValid(enemy) and enemy.pos2D.onScreen and IsHardCC(enemy) then
				Control.CastSpell(HK_E, enemy)
			end
		end
	end
end

function zgJhin:InsidePolygon(polygon, point)
	local result = false
	local j = #polygon
	point = point.pos or point
	local pointx = point.x
	local pointz = point.z or point.y
	for i = 1, #polygon do
		if polygon[i].z < pointz and polygon[j].z >= pointz or polygon[j].z < pointz and polygon[i].z >= pointz then
			if
				polygon[i].x
					+ (pointz - polygon[i].z) / (polygon[j].z - polygon[i].z) * (polygon[j].x - polygon[i].x)
				< pointx
			then
				result = not result
			end
		end
		j = i
	end
	return result
end

function zgJhin:FourthShot()
	if myHero.hudAmmo == 1 then
		return true
	end
	return false
end

function zgJhin:ComboR()
	if GetMode() ~= "Combo" then return end
	local spell = myHero.activeSpell
	local middlePos = Vector(spell.placementPos)
	local startPos = Vector(spell.startPos)
	local pos1 = startPos + (middlePos - startPos):Rotated(0, 30.6 * math.pi / 180, 0):Normalized() * self.RSpell.Range
	local pos2 = startPos + (middlePos - startPos):Rotated(0, -30.6 * math.pi / 180, 0):Normalized() * self.RSpell.Range
	local polygon = {
			pos1 + (pos1 - startPos):Normalized() * self.RSpell.Range,
			pos2 + (pos2 - startPos):Normalized() * self.RSpell.Range,
			startPos,
		}
	if Menu.Combo.R:Value() then
		local enemies = {}
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
			if self:InsidePolygon(polygon, enemy) then
				table.insert(enemies, enemy)
			end
		end
		local target = GetTarget(enemies)
		if IsValid(target) and target.pos:ToScreen().onScreen and IsReady(_R) then
			self:CastGGPred(HK_R, target)
		end
	end
end
	
function zgJhin:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Wrange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if not Menu.Combo.Wnoaa:Value() and not self:FourthShot() or not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
				if not Menu.Combo.Wpassive:Value() or HaveBuff(target, "jhinespotteddebuff") then
					self:CastGGPred(HK_W, target)
				end
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not self:FourthShot() then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.QSpell.Range + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if target.distance <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and not self:FourthShot() then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			Control.CastSpell(HK_Q, target)
		end
	end
end

function zgJhin:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and not self:FourthShot() then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.QSpell.Range + myHero.boundingRadius * 2)
		if IsValid(target) and target.type == Obj_AI_Hero and target.pos:ToScreen().onScreen then
			if target.distance <= (self.QSpell.Range + myHero.boundingRadius + target.boundingRadius) then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.WSpell.Range)
		if IsValid(target) and target.type == Obj_AI_Hero and target.pos:ToScreen().onScreen then
			if not Menu.Harass.Wpassive:Value() or HaveBuff(target, "jhinespotteddebuff") then
				if not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or not self:FourthShot() then
					self:CastGGPred(HK_W, target)
				end
			end
		end
    end
end

function zgJhin:CastGGPred(spell, target)
	if spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(target, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgJhin:HasRBuff(spell)
	local s = spell or myHero.activeSpell
	if s and s.valid and s.name:lower() == "jhinr" then
		return true
	end
	return false
end

function zgJhin:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
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
	local spell = myHero.activeSpell
	if self:HasRBuff(spell) then
		local middlePos = Vector(spell.placementPos)
		local startPos = Vector(spell.startPos)
		local pos1 = startPos + (middlePos - startPos):Rotated(0, 30.6 * math.pi / 180, 0):Normalized() * self.RSpell.Range
		local pos2 = startPos + (middlePos - startPos):Rotated(0, -30.6 * math.pi / 180, 0):Normalized() * self.RSpell.Range
		local p1 = startPos:To2D()
		local p2 = pos1:To2D()
		local p3 = pos2:To2D()
		Draw.Line(p1.x, p1.y, p2.x, p2.y, 1, Draw.Color(255, 255, 255, 255))
		Draw.Line(p1.x, p1.y, p3.x, p3.y, 1, Draw.Color(255, 255, 255, 255))
	end
end

zgJhin()
