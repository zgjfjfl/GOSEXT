local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgLux"

function zgLux:__init()
	print("Zgjfjfl AIO - Lux Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1300, Speed = 1200, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = { Range = 1200 }
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 310, Range = 1250, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 100, Range = 3400, Speed = math.huge, Collision = false}
end

function zgLux:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)",value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QRange", name = "Use Q| Max Range", min = 600, max = 1250, value = 1150, step = 50})	
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RRange", name = "Use R| Max Range", min = 1000, max = 3400, value = 3000, step = 100})	
	Menu.Combo:MenuElement({id = "RCount", name = "Use R| when hit X enemies", min = 1, max = 5, value = 3, step = 1})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "QRange", name = "Use Q| Max Range", min = 600, max = 1250, value = 1150, step = 50})	
	Menu.Harass:MenuElement({id = "E", name = "Harass [E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Shield", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Whp", name = "Auto [W] allies or self Low hp%", value = 30, min = 0, max = 100, step = 5})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "R", name = "Auto [R] on 'CC'", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "R", name = "Auto [R] Kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function zgLux:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgLux:Tick()
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
	self:AutoQ()
	self:AutoW()
	self:AutoE()
	self:AutoR()
end

function zgLux:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.QRange:Value())
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and not IsReady(_Q) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then						
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		local minhitchance = 2
		local aoeresult = RPrediction:GetAOEPrediction(myHero)
		local bestaoe = nil
		local bestcount = 0
		local bestdistance = 1000
		for i = 1, #aoeresult do
			local aoe = aoeresult[i]
			if aoe.HitChance >= minhitchance and aoe.TimeToHit <= 3 and aoe.Count >= Menu.Combo.RCount:Value() and GetDistance(myHero.pos, aoe.CastPosition) <= Menu.Combo.RRange:Value() then
				if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
					bestdistance = aoe.Distance
					bestcount = aoe.Count
					bestaoe = aoe
				end
			end
		end
		if bestaoe then
			Control.CastSpell(HK_R, bestaoe.CastPosition)
		end
	end
end

function zgLux:Harass()
	local target = GetTarget(Menu.Harass.QRange:Value())
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
	end
	local target = GetTarget(self.ESpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.E:Value() and IsReady(_E) then
			self:CastGGPred(HK_E, target)
		end
	end
end

function zgLux:AutoQ()
	if IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.QRange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.Q:Value() and IsHardCC(target) then
					self:CastGGPred(HK_Q, target)
				end
				if Menu.Kill.Q:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetQDmg(target) then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
end

function zgLux:AutoW()
	if Menu.Auto.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.WSpell.Range)
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(2000)
		for _, ally in ipairs(allies) do
			if IsValid(ally) then
				local useForPoison = IsPoison(ally)
				local useForLowHP = (ally.health / ally.maxHealth <= Menu.Auto.Whp:Value() / 100 and GetEnemyCount(1000, ally.pos) > 0)
				local useForTurret = false
				for _, turret in ipairs(turrets) do
					if turret and turret.targetID == ally.networkID then
						useForTurret = true
						break
					end
				end
				if useForPoison or useForLowHP or useForTurret then
					self:CastW(ally)
					lastW = GetTickCount()
					break
				end
			end
		end
	end
end

function zgLux:CastW(unit)
	if unit.isMe then
		Control.CastSpell(HK_W)
	else
		Control.CastSpell(HK_W, unit)
	end
end
	

function zgLux:AutoE()
	if IsReady(_E) then
		for i, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
			if IsValid(target) and target.pos2D.onScreen then
				local LuxBuff = HaveBuff(myHero, "LuxLightStrikeKugel")
				local targetBuff = HaveBuff(target, "luxeslow")
				if LuxBuff and targetBuff and lastE + 250 < GetTickCount() then
					Control.CastSpell(HK_E)
					lastE = GetTickCount()
				end
				if myHero.pos:DistanceTo(target.pos) < self.ESpell.Range then
					if Menu.Auto.E:Value() and IsHardCC(target) then
						self:CastGGPred(HK_E, target)
					end
					if Menu.Kill.E:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetEDmg(target) then
						self:CastGGPred(HK_E, target)
					end
				end
			end
		end
	end	
end

function zgLux:AutoR()
	if IsReady(_R) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.RRange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
				if Menu.Auto.R:Value() and IsHardCC(target) then
					self:CastGGPred(HK_R, target)
				end
				if Menu.Kill.R:Value() and (target.health + target.shieldAD + target.shieldAP) < self:GetRDmg(target) then
					self:CastGGPred(HK_R, target)
				end
			end
		end
	end
end

function zgLux:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) and myHero:GetSpellData(_E).name == "LuxLightStrikeKugel" then
			local castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), 1100)
			if myHero.pos:DistanceTo(unit.pos) <= 1100 then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
			elseif myHero.pos:DistanceTo(unit.pos) > 1100 and myHero.pos:DistanceTo(unit.pos) <= 1250 then
				Control.CastSpell(HK_E, castPos)
			end
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgLux:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({80, 120, 160, 200, 240})[level] + 0.75 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgLux:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 120, 170, 220, 270})[level] + 0.8 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgLux:GetRDmg(target)
	local R2Dmg = 0
	local buff, buffData = GetBuffData(target, "LuxIlluminatingFraulein")
	local level = myHero:GetSpellData(_R).level
	local R1Dmg = ({300, 400, 500})[level] + 1.2 * myHero.ap
	if buff and buffData.duration > 1.25 then
 		R2Dmg = 10 + 10 * myHero.levelData.lvl + myHero.ap * 0.2
	end
	local RDmg = R1Dmg + R2Dmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgLux:Draw()
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
end

zgLux()