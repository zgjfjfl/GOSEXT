local Version = 1.01

local LargeMonsters = {
	sru_baron = true, sru_atakhan = true, sru_riftherald = true, sru_horde = true,
	sru_blue = true, sru_red = true, sru_gromp = true, sru_murkwolf = true,
	sru_razorbeak = true, sru_krug = true, sru_crab = true
}

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgKindred"

function zgKindred:__init()		 
	print("Zgjfjfl AIO - Kindred Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = { Range = 300 }
	self.WSpell = { Range = 800 }
	self.ESpell = { Range = 600 }
	self.RSpell = { Range = 500 }
end

function zgKindred:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "Qmode", name = "Use Q| Cast Mode", value = 1, drop = {"To Side", "To Mouse"}})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "EMode", name = "Use E| Cast Mode", value = 1, drop = {"Target Low HP", "Always"}})
	Menu.Combo:MenuElement({id = "EHP", name = "Use E| Target HP <= X%", value = 50, min = 1, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "ForceE", name = "Force Attack E Buff Target(AARange)", value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})

	Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
	Menu.AutoR:MenuElement({id = "R", name = "Use R", value = true})
	Menu.AutoR:MenuElement({id = "HP", name = "Use R When HP <= X%", value = 15, min = 1, max = 50, step = 1})
	Menu.AutoR:MenuElement({id = "Enemy", name = "Only R If Enemy Nearby", value = true})
	Menu.AutoR:MenuElement({id = "EnemyRange", name = "Enemy Nearby Range", value = 1000, min = 300, max = 2000, step = 100})
	Menu.AutoR:MenuElement({id = "MaxEnemies", name = "Don't R If Enemies > X", value = 3, min = 1, max = 5, step = 1})

	Menu:MenuElement({type = MENU, id = "AntiGapcloser", name = "AntiGapcloser"})
	Menu.AntiGapcloser:MenuElement({id = "Q", name = "Auto Q Backward", value = true})
	Menu.AntiGapcloser:MenuElement({id = "Range", name = "Use Q If Dash End Distance < X", value = 300, min = 100, max = 600, step = 50})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q| Min Minion Count", value = 3, min = 1, max = 10})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = false})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E| Large Monsters Only", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "EHP", name = "Use E| Monster HP <= X%", value = 50, min = 1, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})

end

function zgKindred:OnTick()
	self.ESpell.Range = myHero.range
	if ShouldWait() then
		return
	end
	if self:AutoR() then return end
	if self:AntiGapcloser() then return end
	self:ForceE()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		if not self:LaneClear() then self:JungleClear() end
	end
end

function zgKindred:AntiGapcloser()
	if not Menu.AntiGapcloser.Q:Value() or not IsReady(_Q) then return end
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1500)) do
		if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
			local endPos = Vector(target.pathing.endPos)
			local endDistance = myHero.pos:DistanceTo(endPos)
			local inRange = endDistance < Menu.AntiGapcloser.Range:Value()
			local isApproaching = endDistance < myHero.pos:DistanceTo(target.pos)
			if inRange and isApproaching then
				local awayFrom = endDistance > 1 and endPos or target.pos
				local castPos = myHero.pos + (myHero.pos - awayFrom):Normalized() * self.QSpell.Range
				if not Game.isWall(castPos) and not IsUnderTurret2(castPos) then
					Control.CastSpell(HK_Q, castPos)
					return true
				end
			end
		end
	end
end

function zgKindred:AutoR()
	local hasRBuff = HaveBuff(myHero, "kindredrnodeathbuff")
	if not Menu.AutoR.R:Value() or not IsReady(_R) or hasRBuff then return end
	if myHero.health / myHero.maxHealth > Menu.AutoR.HP:Value() / 100 then return end
	local enemyCount = GetEnemyCount(Menu.AutoR.EnemyRange:Value(), myHero.pos)
	if Menu.AutoR.Enemy:Value() and enemyCount == 0 then return end
	if enemyCount > Menu.AutoR.MaxEnemies:Value() then return end
	Control.CastSpell(HK_R)
	return true
end

function zgKindred:GetHeroTarget(range)
	local target = _G.SDK.Orbwalker:GetTarget()
	local isHero = IsValid(target) and target.type == Obj_AI_Hero
	local inRange = isHero and GetDistance(myHero.pos, target.pos) <= range
	if inRange and target.pos:ToScreen().onScreen then
		return target
	end
	return GetTarget(range)
end

function zgKindred:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget()
		local aaRange = myHero.range + myHero.boundingRadius * 2
		if IsValid(target) then
			if Menu.Combo.Qmode:Value() == 1 then
				local intPos1, intPos2 = CircleCircleIntersection(
					myHero.pos,
					target.pos,
					self.QSpell.Range,
					myHero.range
				)
				if intPos1 and intPos2 then
					local firstIsCloser = GetDistance(intPos1, mousePos) < GetDistance(intPos2, mousePos)
					local closest = firstIsCloser and intPos1 or intPos2
					if IsFacingMe(target) then
						Control.CastSpell(HK_Q, closest)
						return
					else
						if target.distance > 400 then
							Control.CastSpell(HK_Q, target)
							return
						end
					end
				end
			else
				Control.CastSpell(HK_Q)
				return
			end
		end
		if target == nil then target = GetTarget(aaRange + self.QSpell.Range) end
		if IsValid(target) and target.distance > aaRange then
			local extended = myHero.pos:Extended(target.pos, self.QSpell.Range)
			Control.CastSpell(HK_Q, extended)
			return
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = self:GetHeroTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			Control.CastSpell(HK_W, target)
			return
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = self:GetHeroTarget(self.ESpell.Range + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			local hasEBuff = HaveBuff(target, "KindredERefresher")
			local targetLowHP = target.health / target.maxHealth <= Menu.Combo.EHP:Value() / 100
			local useE = Menu.Combo.EMode:Value() == 2 or targetLowHP
			if not hasEBuff and useE then
				Control.CastSpell(HK_E, target)
				return
			end
		end
	end
end

function zgKindred:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = self:GetHeroTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			Control.CastSpell(HK_W, target)
			return
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = self:GetHeroTarget(self.ESpell.Range + myHero.boundingRadius * 2)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			local hasEBuff = HaveBuff(target, "KindredERefresher")
			if not hasEBuff then
				Control.CastSpell(HK_E, target)
				return
			end
		end
	end
end

function zgKindred:LaneClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local qPos = myHero.pos:Extended(mousePos, self.QSpell.Range)
	local aaRange = myHero.range + myHero.boundingRadius * 2
	local minionCount = GetMinionCount(aaRange, qPos)
	if
		Menu.Clear.LaneClear.Q:Value()
		and IsReady(_Q)
		and minionCount >= Menu.Clear.LaneClear.QCount:Value()
	then
		Control.CastSpell(HK_Q, qPos)
		return true
	end
	if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
		for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.WSpell.Range)) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				Control.CastSpell(HK_W, minion)
				return true
			end
		end
	end
end

function zgKindred:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.WSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.pos2D.onScreen then
			if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q)
				return
			end
			if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
				Control.CastSpell(HK_W, monster)
				return
			end
			local monsterName = monster.charName:lower()
			local isLarge = LargeMonsters[monsterName]
				or monsterName:find("sru_dragon_", 1, true) == 1
			local targetLowHP = monster.health / monster.maxHealth
				<= Menu.Clear.JungleClear.EHP:Value() / 100
			local eRange = self.ESpell.Range + myHero.boundingRadius + monster.boundingRadius
			local inERange = GetDistance(myHero.pos, monster.pos) <= eRange
			local hasEBuff = HaveBuff(monster, "KindredERefresher")
			if
				Menu.Clear.JungleClear.E:Value()
				and IsReady(_E)
				and isLarge
				and targetLowHP
				and inERange
				and not hasEBuff
			then
				Control.CastSpell(HK_E, monster)
				return
			end
		end
	end
end

function zgKindred:ForceE()
	if not Menu.Combo.ForceE:Value() then
		_G.SDK.Orbwalker.ForceTarget = nil
		return
	end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes()
	for i, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if HaveBuff(enemy, "KindredERefresher") and _G.SDK.Data:IsInAutoAttackRange(myHero, enemy) then
				_G.SDK.Orbwalker.ForceTarget = enemy
				return
			end
		end
	end
	_G.SDK.Orbwalker.ForceTarget = nil
end

function zgKindred:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgKindred()
