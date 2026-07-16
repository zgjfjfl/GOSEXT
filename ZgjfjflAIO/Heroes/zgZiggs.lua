local Version = 1.04

require("GGPrediction")
-- require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgZiggs"

function zgZiggs:__init()
	print("Zgjfjfl AIO - Ziggs Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.Q1Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 180, Range = 850, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.Q2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 180, Range = 1400, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 1200, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 325, Range = 1000, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.375, Radius = 230, Range = 5000, Speed = 2250, Collision = false}
	self.w2Timestamp = nil
end

function zgZiggs:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Combo [W] on long-range Enemy", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] hit x targets", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Harass [W]", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W2", name = "Auto [W2]", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W2time", name = "Auto [W2] Delay X time(ms)", value = 250, min = 0, max = 1000, step = 50})
	Menu.Auto:MenuElement({id = "WTurret", name = "Auto [W] low turret", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "WPeel", name = "Auto [W] Peel", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RCC", name = "Auto [R] On 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RKill", name = "Auto [R] Kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "W", name = "[W] to mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rmini", name = "Draw [R] Range in minimap", toggle = true, value = false})
end

function zgZiggs:Tick()
	if ShouldWait() then
		return
	end
	self:AutoW2()
	if IsCasting() then return end
    local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "Flee" then
		self:Flee()
	end
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:SemiManualR()
	end
	self:Auto()
end

function zgZiggs:AutoW2()
	if Menu.Auto.W2:Value() and myHero:GetSpellData(_W).name == "ZiggsWToggle" and Game.CanUseSpell(_W) == 0 then
		if not self.w2Timestamp then
			self.w2Timestamp = GetTickCount()
		end
		if GetTickCount() > self.w2Timestamp + Menu.Auto.W2time:Value() then
			Control.CastSpell(HK_W)
			self.w2Timestamp = nil
		end
	else
		self.w2Timestamp = nil
	end
end

function zgZiggs:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastE(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local IsRange = target.range > 300
			if IsRange then
 				self:CastW(target)
			end
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local Rtarget = GetTarget(5000)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			local minHitCount = Menu.Combo.RCount:Value()
			CastSpellAOE(HK_R, self.RSpell, minHitCount, myHero, Rtarget)
		end
	end
end	

function zgZiggs:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.Q2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastW(target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastE(target)
		end
	end
end

function zgZiggs:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" then
		local castPos = myHero.pos:Extended(mousePos, -100)
		if castPos:To2D().onScreen then
			Control.CastSpell(HK_W, castPos)
		end
	end
end

function zgZiggs:SemiManualR()
	local Rtarget = GetTarget(5000)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		CastSpellAOE(HK_R, self.RSpell, 1, myHero, Rtarget)
	end
end

function zgZiggs:Auto()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if Menu.Auto.WPeel:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" then
				local IsMelee = enemy.range < 300
				if IsMelee and myHero.pos:DistanceTo(enemy.pos) <= enemy.boundingRadius + enemy.range + myHero.boundingRadius then
					local castPos = Vector(myHero.pos):Extended(Vector(enemy.pos), math.min(200, myHero.pos:DistanceTo(enemy.pos)/2))
					Control.CastSpell(HK_W, castPos)
				end
			end
			if Menu.Auto.RCC:Value() and IsReady(_R) and GetHardCCDuration(enemy) > 0.5 then
				self:CastR(enemy)
			end
			if Menu.Auto.RKill:Value() and IsReady(_R) then
				local Rdmg = self:GetRDmg(enemy)
				if Rdmg > enemy.health + enemy.shieldAP + enemy.shieldAD then
					self:CastR(enemy)
				end
			end
		end
	end
	if Menu.Auto.WTurret:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ZiggsW" then
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1000)
		for i, turret in ipairs(turrets) do
			if turret then
				if Game.mapID == SUMMONERS_RIFT then
					if turret.health/turret.maxHealth < (myHero:GetSpellData(_W).level*2.5 + 22.5)/100 then
						Control.CastSpell(HK_W, turret)
					end
				elseif Game.mapID == HOWLING_ABYSS then
					if turret.health/turret.maxHealth < (myHero:GetSpellData(_W).level*2.5 + 10)/100 then
						Control.CastSpell(HK_W, turret)
					end
				end
			end
		end
	end
end

function zgZiggs:CastQ(unit)
	if myHero.pos:DistanceTo(unit.pos) > 850 then
		local QPrediction = GGPrediction:SpellPrediction(self.Q2Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local startPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 600)
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(startPos, QPrediction.CastPosition, self.Q2Spell.Speed, self.Q2Spell.Delay, self.Q2Spell.Radius/2, {GGPrediction.COLLISION_MINION}, unit.networkID)
			if collisionCount == 0 then
				local endPos = Vector(myHero.pos):Extended(Vector(QPrediction.CastPosition), 850)
				if Vector(QPrediction.CastPosition):To2D().onScreen and not Game.isWall(endPos) then
					Control.CastSpell(HK_Q, QPrediction.CastPosition)
				end
			end
		end
	else
		local QPrediction = GGPrediction:SpellPrediction(self.Q1Spell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function zgZiggs:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
		local castPos1 = Vector(Vector(WPrediction.CastPosition)):Extended(Vector(myHero.pos), 100)
		local castPos2 = Vector(myHero.pos):Extended(Vector(WPrediction.CastPosition), 1000)
		if myHero.pos:DistanceTo(unit.pos) <= 1000 then
			Control.CastSpell(HK_W, castPos1)
		elseif myHero.pos:DistanceTo(unit.pos) > 1000 and myHero.pos:DistanceTo(unit.pos) <= 1200 then
			Control.CastSpell(HK_W, castPos2)
		end
	end
end

function zgZiggs:CastE(unit)
	local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
	EPrediction:GetPrediction(unit, myHero)
	if EPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
		local castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), 900)
		if myHero.pos:DistanceTo(unit.pos) <= 900 then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		elseif myHero.pos:DistanceTo(unit.pos) > 900 and myHero.pos:DistanceTo(unit.pos) <= 1000 then
			Control.CastSpell(HK_E, castPos)
		end
	end
end

function zgZiggs:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgZiggs:GetRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 150 * rlvl + 150
	local apDmg = myHero.ap * 1.1
	local Dmg = baseDmg + apDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
end

function zgZiggs:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.Q2Spell.Range, 1, Draw.Color(255, 66, 244, 113))
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
	if Menu.Draw.Rmini:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, self.RSpell.Range, 0.5, Draw.Color(200,50,180,230))
	end
end

zgZiggs()
