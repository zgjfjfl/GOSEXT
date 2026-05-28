local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgZyra"

function zgZyra:__init()
	print("Zgjfjfl AIO - Zyra Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 100, Range = 800, Speed = math.huge, Collision = false}
	self.WSpell = {Range = 850}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1100, Speed = 1150, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 500, Range = 950, Speed = math.huge, Collision = false}
end

function zgZyra:LoadMenu() 
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Combo [R]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RKill", name = "Combo [R] If TotalDmg Can Kill", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Combo [R] If Hit X Enemies", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})

	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q If Hit X Minions", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "Use E If Hit X Minions", value = 4, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] Passive when castingQ/E", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on 'CC'", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E", name = "Auto [E] on 'CC'", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Kill", name = "Kills"})
	Menu.Kill:MenuElement({id = "Q", name = "Auto [Q] Kills", toggle = true, value = true})
	Menu.Kill:MenuElement({id = "E", name = "Auto [E] Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", toggle = true, value = false})
end

function zgZyra:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgZyra:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
    local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
	self:AutoQ()
	self:AutoE()
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end 
end

function zgZyra:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local minHitCount = Menu.Combo.RCount:Value()
			CastSpellAOE(HK_R, self.RSpell, minHitCount, myHero, target)
			local canUseR = true
			if Game.CanUseSpell(_Q) == 0 and self:GetQDmg(target) >= target.health then
				canUseR = false
			end
			if Game.CanUseSpell(_E) == 0 and self:GetEDmg(target) >= target.health then
				canUseR = false
			end
			if Menu.Combo.RKill:Value() and canUseR then
				local Hp = (target.health + target.shieldAD + target.shieldAP)
				if Hp < self:ComboDmg(target) then
					self:CastGGPred(HK_R, target)
				end
			end
		end
	end
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

function zgZyra:Harass()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgZyra:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgZyra:LaneClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	if IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
			local castW = Menu.Clear.LaneClear.W:Value() and IsReady(_W)
			if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
				local bestTarget = nil
				local maxHits = 0
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if collisionCount > maxHits then
					maxHits = collisionCount
					bestTarget = minion
				end
				if bestTarget and maxHits >= Menu.Clear.LaneClear.ECount:Value() then
					Control.CastSpell({HK_E, castW and HK_W or nil}, bestTarget)
				end
			end
			if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
				local bestPos = nil
				local maxHits = 0
				local castDir = Vector(minion.pos - myHero.pos):Normalized()
				local perpDir = Vector(-castDir.z, 0, castDir.x)
				local portal1 = minion.pos + perpDir * 375
				local portal2 = minion.pos - perpDir * 375
				local hits = 1
				for _, checkMinion in ipairs(minions) do
					if IsValid(checkMinion) and checkMinion.networkID ~= minion.networkID and checkMinion.team ~= 300 and not checkMinion.pathing.hasMovePath then
						local point, onSegment = GGPrediction:ClosestPointOnLineSegment(checkMinion.pos, portal1, portal2)
						if onSegment and GGPrediction:IsInRange(checkMinion.pos, point, self.QSpell.Radius) then
							hits = hits + 1
						end
					end
				end				
				if hits > maxHits then
					maxHits = hits
					bestPos = minion.pos
				end
				if bestPos and maxHits >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell({HK_Q, castW and HK_W or nil}, bestPos)
				end
			end
		end
	end
end

function zgZyra:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetEnemyMinions(800)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.team == 300 then
			local castW = Menu.Clear.JungleClear.W:Value() and IsReady(_W)
			if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
				Control.CastSpell({HK_E, castW and HK_W or nil}, monster)
			end
			if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
				Control.CastSpell({HK_Q, castW and HK_W or nil}, monster)
			end
		end
	end
end

function zgZyra:AutoQ()
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

function zgZyra:AutoE()
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

function zgZyra:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			local castW = Menu.Auto.W:Value() and Game.CanUseSpell(_W) == 0
			Control.CastSpell({HK_Q, (castW and HK_W or nil)}, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			local castW = Menu.Auto.W:Value() and Game.CanUseSpell(_W) == 0
			local castPos = EPrediction.CastPosition
			if myHero.pos:DistanceTo(castPos) > self.WSpell.Range then
				castPos = Vector(myHero.pos):Extended(Vector(EPrediction.CastPosition), self.WSpell.Range)
			end
			Control.CastSpell({HK_E, (castW and HK_W or nil)}, castPos)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(unit, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgZyra:RSemiManual()
	local target = GetTarget(self.RSpell.Range)
	if IsValid(target) and target.pos2D.onScreen then
		if IsReady(_R) then
			CastSpellAOE(HK_R, self.RSpell, 1, myHero, target)
		end
	end
end

function zgZyra:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({60, 100, 140, 180, 220})[level] + 0.65 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgZyra:GetPDmg(target)
	local level = myHero.levelData.lvl
	local PDmg = (16 + 4 * level) + 0.18 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function zgZyra:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({60, 95, 130, 165, 200})[level] + 0.6 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgZyra:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = ({200, 300, 400})[level] + 0.7 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgZyra:ComboDmg(target)
	local Dmg = 0
	if IsReady(_Q) then
		if IsReady(_W) then
			Dmg = Dmg + self:GetQDmg(target) + self:GetPDmg(target)
		else
			Dmg = Dmg + self:GetQDmg(target)
		end
	end
	if IsReady(_E) then
		if IsReady(_W) then
			Dmg = Dmg + self:GetEDmg(target) + self:GetPDmg(target)
		else
			Dmg = Dmg + self:GetEDmg(target)
		end
	end
	if IsReady(_R) then
		Dmg = Dmg + self:GetRDmg(target)
	end
	return Dmg
end

function zgZyra:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
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

zgZyra()