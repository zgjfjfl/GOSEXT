local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgMel"

function zgMel:__init()
	print("Zgjfjfl AIO - Mel Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.35, Radius = 200, Range = 950, Speed = 3800, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 115, Range = 1000, Speed = 1100, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgMel:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "Use E|Max Range", value = 900, min = 0, max = 1000, step = 50})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 4, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "AutoW", name = "Auto W"})
	Menu.AutoW:MenuElement({id = "W", name = "Auto W Reflect", toggle = true, value = true})
	Menu.AutoW:MenuElement({name = " ", drop = {"Reflect Abilities: "}})
	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		champName = args.charName
		enemy = args.unit
		Menu.AutoW:MenuElement({id = champName, name = champName, type = MENU})
		if champName == "Hwei" then
			Menu.AutoW[champName]:MenuElement({id = "HweiQQ", name = "QQ", value = false})
			Menu.AutoW[champName]:MenuElement({id = "HweiQW", name = "QW", value = false})
			Menu.AutoW[champName]:MenuElement({id = "HweiQE", name = "QE", value = false})
			Menu.AutoW[champName]:MenuElement({id = "HweiEQ", name = "EQ", value = false})
			Menu.AutoW[champName]:MenuElement({id = "HweiEW", name = "EW", value = false})
			Menu.AutoW[champName]:MenuElement({id = "HweiEE", name = "EE", value = false})
			local rName = enemy:GetSpellData(_R).name
			Menu.AutoW[champName]:MenuElement({id = rName, name = "R", value = false})
		else
			local qName = enemy:GetSpellData(_Q).name
			local wName = enemy:GetSpellData(_W).name
			local eName = enemy:GetSpellData(_E).name
			local rName = enemy:GetSpellData(_R).name	
			Menu.AutoW[champName]:MenuElement({id = qName, name = "Q", value = false})
			Menu.AutoW[champName]:MenuElement({id = wName, name = "W", value = false})
			Menu.AutoW[champName]:MenuElement({id = eName, name = "E", value = false})
			Menu.AutoW[champName]:MenuElement({id = rName, name = "R", value = false})
		end
	end)
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E AntiGapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Rkill", name = "Auto R Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function zgMel:Tick()
	if ShouldWait() then
		return
	end
	self:AutoQ()
	self:AutoW()
	self:AutoR()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	end
end

function zgMel:AutoQ()	
	if Menu.Misc.Qcc:Value() and IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsHardCC(target) then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
end

function zgMel:AutoE()	
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for _, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and target.posTo and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.posTo) < myHero.pos:DistanceTo(target.pos) then
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end
end

function zgMel:GetPDmg(target)
	local rlevel = myHero:GetSpellData(_R).level
	local buff, buffData = GetBuffData(target, "MelPassiveOverwhelm")
	local PDmg = 0
	if buff then
		if rlevel == 0 then
			PDmg = (50 + 0.1 * myHero.ap) + (2 + 0.0075 * myHero.ap) * buffData.stacks
		else
			PDmg = (({60, 70, 80})[rlevel] + 0.1 * myHero.ap) + (({3, 4, 5})[rlevel] + 0.0075 * myHero.ap) * buffData.stacks
		end
	end
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		PDmg = PDmg * 1.2
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, PDmg)
end

function zgMel:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local buff, buffData = GetBuffData(target, "MelPassiveOverwhelm")
	local RDmg = 0
	if buff then
		RDmg = (({125, 200, 275})[level] + 0.30 * myHero.ap) + (({4, 7, 10})[level] + 0.04 * myHero.ap) * buffData.stacks
	end
	if HasItem(myHero, 4645) and target.health / target.maxHealth < 0.4 then
		RDmg = RDmg * 1.2
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgMel:AutoR()
	if GetEnemyCount(800, myHero.pos) > 0 then
		return
	end
	if Menu.Misc.Rkill:Value() and IsReady(_R) then
		for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
			if IsValid(target) and HaveBuff(target, "MelPassiveOverwhelm") then
				local Dmg = self:GetRDmg(target) + self:GetPDmg(target)
				if Dmg > (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 2) and GetAllyCount(500, target.pos) == 0 then
					Control.CastSpell(HK_R)
				end
			end
		end
	end
end

function zgMel:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local Etarget = GetTarget(Menu.Combo.ERange:Value())
		if IsValid(Etarget) and Etarget.pos2D.onScreen then
			self:CastGGPred(HK_E, Etarget)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) then
		local Qtarget = GetTarget(self.QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			self:CastGGPred(HK_Q, Qtarget)
		end
	end
end

function zgMel:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local Qtarget = GetTarget(self.QSpell.Range)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
				self:CastGGPred(HK_Q, Qtarget)
			end
		end
	-- end
end

function zgMel:AutoW()
	if not (Menu.AutoW.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount()) then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) then
			local spell = enemy.activeSpell
			if spell and spell.valid and Menu.AutoW[enemy.charName] and Menu.AutoW[enemy.charName][spell.name] and Menu.AutoW[enemy.charName][spell.name]:Value() then
				if spell.target == myHero.handle then
					if not spell.isAutoAttack then
						Control.CastSpell(HK_W)
						lastW = GetTickCount()
						return
					end
				else
					local endPos = spell.startPos:Extended(spell.placementPos, spell.range + spell.width)
					local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(myHero.pos, endPos, spell.startPos)
					local width = myHero.boundingRadius + (spell.width > 0 and spell.width or 0)
					if isOnSegment and GGPrediction:IsInRange(myHero.pos, point, width) then
						local travelTime = 0
						if spell.speed and spell.speed > 0 then
							travelTime = spell.startPos:DistanceTo(point) / spell.speed
						end
						local timeUntilHit = spell.castEndTime + travelTime - Game.Timer()
						if timeUntilHit > 0 and timeUntilHit < 0.75 then
							Control.CastSpell(HK_W)
							lastW = GetTickCount()
							return
						end
					end
				end
			end
		end
	end
end

function zgMel:LaneClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		local bestQTarget = nil
		local maxQCount = 0
		local bestETarget = nil
		local maxECount = 0
		
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and not minion.pathing.hasMovePath then
					local qCount = GetMinionCount(self.QSpell.Radius, minion.pos)
					if qCount > maxQCount then
						maxQCount = qCount
						bestQTarget = minion
					end
				end
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					local _, _, eCollision = GGPrediction:GetCollision(myHero.pos, minion.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if eCollision > maxECount then
						maxECount = eCollision
						bestETarget = minion
					end
				end
			end
		end
		if bestQTarget and maxQCount >= Menu.Clear.LaneClear.QCount:Value() then
			Control.CastSpell(HK_Q, bestQTarget)
		end
		if bestETarget and maxECount >= Menu.Clear.LaneClear.ECount:Value() then
			Control.CastSpell(HK_E, bestETarget)
		end
	end
end

function zgMel:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		local bestQTarget = nil
		local maxQCount = 0
		local bestETarget = nil
		local maxECount = 0
		
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					local qCount = GetMinionCount(self.QSpell.Radius, minion.pos)
					if qCount > maxQCount then
						maxQCount = qCount
						bestQTarget = minion
					end
				end
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					local _, _, eCollision = GGPrediction:GetCollision(myHero.pos, minion.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if eCollision > maxECount then
						maxECount = eCollision
						bestETarget = minion
					end
				end
			end
		end
		if bestQTarget and maxQCount >= 1 then
			Control.CastSpell(HK_Q, bestQTarget)
		end
		if bestETarget and maxECount >= 1 then
			Control.CastSpell(HK_E, bestETarget)
		end
	end
end

function zgMel:CastGGPred(spell, target)
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
	end
end

function zgMel:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgMel()