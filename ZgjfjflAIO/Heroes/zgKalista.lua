local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgKalista"

function zgKalista:__init()
	print("Zgjfjfl AIO - Kalista Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 40, Range = 1150, Speed = 2400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Range = 1000}
	self.RSpell = {Range = 1150}
end

function zgKalista:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E| If Can Kill Minion And Slow Target", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E| If Can Kill Minion And Slow Target", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = true, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanKill Counts >= ", value = 2, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "QMana", name = "UseQ When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanKill Counts >= ", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E Kills", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "E", name = "Auto E Kill EpicMonster", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "R", name = "Auto R Ally LowHp", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	-- Menu.Draw:MenuElement({id = "DragonBuffNums", name = "Draw Duplicate dragon buffs Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgKalista:Tick()
	if ShouldWait() then
		return
	end
	self:KillSteal()
	self:AutoKillEpicMonster()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
	self:AutoR()
end

function zgKalista:KillSteal()
	if Menu.KillSteal.E:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and HaveBuff(target, "kalistaexpungemarker") then
				local EDmg = self:GetEDmg(target)
				-- print(EDmg)
				if EDmg >= target.health + target.hpRegen + target.shieldAD then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				local QDmg = self:GetQDmg(target)
				local EDmg = self:GetEDmg(target)
				local hp = target.health + target.shieldAD
				if QDmg >= hp and (EDmg < hp or not IsReady(_E)) then
					self:CastQ(target)
				elseif QDmg + EDmg > hp and EDmg < hp and _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
					self:CastQ(target)
				end
			end
		end
	end
end

function zgKalista:CastQ(target)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(target, myHero)
	if QPrediction:CanHit(3) and not IsCasting() and not myHero.pathing.isDashing then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, QPrediction.CastPosition, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount > 0 then
			local allColCanKill = true
			for _, col in ipairs(collisionObjects) do
				if IsValid(col) then
					local QDmg = self:GetQDmg(col)
					if col.health > QDmg then
						allColCanKill = false
						break
					end
				end
			end
			if allColCanKill then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		else
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	end
end

function zgKalista:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
		local Qtarget = GetTarget(self.QSpell.Range)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			self:CastQ(Qtarget)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local targets = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for _, Etarget in ipairs(targets) do 
			if IsValid(Etarget) and HaveBuff(Etarget, "kalistaexpungemarker") then
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
				for _, minion in ipairs(minions) do
					if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
						local EDmg = self:GetEDmg(minion)
						if minion.health <= EDmg then
							Control.CastSpell(HK_E)
						end
					end
				end
			end
		end
	end
end

function zgKalista:Harass()
	if IsUnderTurret(myHero) then return end
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
			local Qtarget = GetTarget(self.QSpell.Range)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen and not _G.SDK.Data:IsInAutoAttackRange(myHero, Qtarget) then
				self:CastQ(Qtarget)
			end
		end
		if Menu.Harass.E:Value() and IsReady(_E) then
			local targets = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
			for _, Etarget in ipairs(targets) do 
				if IsValid(Etarget) and HaveBuff(Etarget, "kalistaexpungemarker") then
					local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
					for i, minion in ipairs(minions) do
						if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
							local EDmg = self:GetEDmg(minion)
							if minion.health <= EDmg then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
	-- end
end

function zgKalista:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgKalista:LaneClear()
	if Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
			local killCount = 0
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and HaveBuff(minion, "kalistaexpungemarker") then
					local EDmg = self:GetEDmg(minion)
					if minion.health <= EDmg then
						killCount = killCount + 1
						if not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
							Control.CastSpell(HK_E)
						end
						if minion.charName:lower():find("siege") or minion.name:lower():find("super") then
							Control.CastSpell(HK_E)
						end
					end
					if killCount >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
		if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.QMana:Value()/100 and ]]Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and not IsCasting() and not myHero.pathing.isDashing then
					local QDmg = self:GetQDmg(minion)
					if minion.health <= QDmg then
						local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if Menu.Clear.LaneClear.QCount:Value() == 1 then
							if collisionCount == 0 then
								Control.CastSpell(HK_Q, minion)
							end
						else
							if collisionCount == Menu.Clear.LaneClear.QCount:Value() - 1 then
								local allColCanKill = true
								for _, col in ipairs(collisionObjects) do
									if IsValid(col) then
										local QDmg = self:GetQDmg(col)
										if col.health > QDmg then
											allColCanKill = false
											break
										end
									end
								end
								if allColCanKill then
									Control.CastSpell(HK_Q, minion)
								end
							end
						end
					end
				end
			end
		end
	end
end

local epicMonsters = {
	["sru_baron"] = true,
	["sru_atakhan"] = true,
	["sru_riftherald"] = true,
	["sru_horde"] = true,
	["sru_dragon_water"] = true,
	["sru_dragon_fire"] = true,
	["sru_dragon_earth"] = true,
	["sru_dragon_air"] = true,
	["sru_dragon_chemtech"] = true,
	["sru_dragon_hextech"] = true,
	["sru_dragon_elder"] = true
}

function zgKalista:JungleClear()
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
		local minions = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
				local minionName = minion.charName:lower()
				if not epicMonsters[minionName] then
					local EDmg = self:GetEDmg(minion)
					if EDmg >= minion.health then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
	end
end

function zgKalista:AutoKillEpicMonster()
	if Menu.Misc.E:Value() and IsReady(_E) then
		local minions = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and HaveBuff(minion, "kalistaexpungemarker") then
				local minionName = minion.charName:lower()
				if epicMonsters[minionName] then
					local EDmg = self:GetEDmg(minion, true)
					if EDmg >= (minion.health + minion.hpRegen + minion.shieldAD) then
						Control.CastSpell(HK_E)
					end
				end
			end
		end
	end
end

function zgKalista:AutoR()
	if Menu.Misc.R:Value() and IsReady(_R) then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.RSpell.Range)
		for i, ally in ipairs(allies) do
			if IsValid(ally) and not ally.isMe and HaveBuff(ally, "kalistacoopstrikeally") then
				if ally.health < GetEnemyCount(600, ally.pos) * ally.levelData.lvl * 30 then
					Control.CastSpell(HK_R)
				end
			end
		end
	end
end

function zgKalista:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level > 0 then
		local QDmg = ({10, 75, 140, 205, 270})[level] + 1.05 * myHero.totalDamage
		if Game.mapID == HOWLING_ABYSS then
			if target.type == Obj_AI_Hero then
				QDmg = QDmg * 1.1
			end
		end
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
	else
		return 0
	end
end

function zgKalista:GetEDmg(target, isEpicMonster)
	local buff, buffData = GetBuffData(target, "kalistaexpungemarker")
	local level = myHero:GetSpellData(_E).level
	local targetName = target.charName:lower()
	if buff and level > 0 then
		local baseDmg = ({5, 15, 25, 35, 45})[level] + 0.7 * myHero.totalDamage + 0.65 * myHero.ap
		local bonusDmg = (buffData.count - 1) * (({7, 14, 21, 28, 35})[level] + ({0.2, 0.275, 0.35, 0.425, 0.5})[level] * myHero.totalDamage + 0.5 * myHero.ap)
		local totalDmg = baseDmg + bonusDmg
		if HasBuffContainsName(myHero, "PressTheAttackLockout") then
			totalDmg = totalDmg * 1.08
		end
		if HaveBuff(myHero, "SummonerExhaust") then
			totalDmg = totalDmg * 0.65
		end
		if HaveBuff(myHero, "SRX_DragonSoulBuffChemtech") and myHero.health/myHero.maxHealth < 0.5 then
			totalDmg = totalDmg * 1.11
		elseif HaveBuff(target, "SRX_DragonSoulBuffChemtech") and target.health/target.maxHealth < 0.5 then
			totalDmg = totalDmg * 0.89
		end
		if Game.mapID == HOWLING_ABYSS then
			if target.type == Obj_AI_Hero then
				totalDmg = totalDmg * 1.1
			else
				totalDmg = totalDmg * 0.75
			end
		end
		if isEpicMonster then
			totalDmg = totalDmg * 0.5
			if targetName == "sru_baron" and HaveBuff(myHero, "BaronTarget") then
				totalDmg = totalDmg * 0.5
			end
			if targetName:find("sru_dragon") and targetName ~= "sru_dragon_elder" then
				local buffNums = HaveBuffContainsNameNums(myHero, "SRX_DragonBuff")
				totalDmg = totalDmg * (1 - 0.15 * buffNums)
			end
		end
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, totalDmg)
	else
		return 0
	end
end

function zgKalista:Draw()
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
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgKalista()