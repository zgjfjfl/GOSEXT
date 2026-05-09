local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSeraphine"

function zgSeraphine:__init()
	print("Zgjfjfl AIO - Seraphine Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 350, Range = 900, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Range = 800}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1300, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 160, Range = 1200*2, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgSeraphine:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})
	Menu.Combo:MenuElement({name = " ", drop = {"(Can reset distance by hit allies or other enemies)"}})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Shield", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Whp", name = "Auto [W] allies or self Low hp%", value = 30, min = 0, max = 100, step = 5})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function zgSeraphine:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgSeraphine:Tick()
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
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		self:SemiManualR()
	end
	self:AutoQ()
	self:AutoW()
	self:AutoE()
end

function zgSeraphine:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgSeraphine:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgSeraphine:SemiManualR()
	local Rtarget = GetTarget(self.RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		if myHero.pos:DistanceTo(Rtarget.pos) < 1200 then
			self:CastGGPred(HK_R, Rtarget)
		else
			local isWall1, collisionObjects1, collisionCount1 = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, self.RSpell.Speed, self.RSpell.Delay, self.RSpell.Radius/2, {GGPrediction.COLLISION_ALLYHERO}, myHero.networkID)
			local isWall2, collisionObjects2, collisionCount2 = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, self.RSpell.Speed, self.RSpell.Delay, self.RSpell.Radius/2, {GGPrediction.COLLISION_ENEMYHERO}, Rtarget.networkID)
			table.sort(collisionObjects1, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			table.sort(collisionObjects2, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			if (collisionCount1 > 0 and myHero.pos:DistanceTo(collisionObjects1[1].pos) < 1200) or (collisionCount2 > 0 and myHero.pos:DistanceTo(collisionObjects2[1].pos) < 1200) then
				self:CastGGPred(HK_R, Rtarget)
			end
		end
	end
end

function zgSeraphine:AutoQ()
	if IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
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

function zgSeraphine:AutoW()
	if Menu.Auto.W:Value() and IsReady(_W) then
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
					Control.CastSpell(HK_W)
					break
				end
			end
		end
	end
end

function zgSeraphine:AutoE()
	if IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen then
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

function zgSeraphine:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
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

function zgSeraphine:GetQDmg(target)
	local missingHp = string.format("%.2f", (1 - target.health / target.maxHealth))
	local level = myHero:GetSpellData(_Q).level
	local QDmg = (({60, 85, 110, 135, 165})[level] + 0.5 * myHero.ap) * (1 + 0.06 * (math.min(missingHp, 0.75) / 0.075))
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgSeraphine:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({70, 100, 130, 160, 190})[level] + 0.5 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgSeraphine:Draw()
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

zgSeraphine()