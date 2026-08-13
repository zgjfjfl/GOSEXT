local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicAkali"

function ClassicAkali:__init()
	print("Classic AIO - Akali Loaded")
	self.QRange, self.WRange, self.ERange, self.RRange = 550, 700, 325, 675
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function ClassicAkali:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.16.1/img/champion/Akali.png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, spell in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = spell, name = "Use " .. spell, value = true })
	end
	Menu.Combo:MenuElement({ id = "WHP", name = "Use W When HP <= x%", value = 55, min = 0, max = 100, step = 5 })
	Menu.Combo:MenuElement({ id = "RReserve", name = "Keep R Charges", value = 1, min = 0, max = 2, step = 1 })
	Menu.Combo:MenuElement({ id = "SafeR", name = "Do Not R Under Enemy Turret", value = true })

	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "E", name = "Use E", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Energy Percent >=", value = 40, min = 0, max = 100, step = 5 })

	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q Last Hit / Jungle", value = true })
	Menu.Clear:MenuElement({ id = "E", name = "Use E | Nearby Units >=", value = 3, min = 1, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "Mana", name = "Energy Percent >=", value = 30, min = 0, max = 100, step = 5 })

	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	for _, spell in ipairs({ "Q", "E", "R" }) do
		Menu.KillSteal:MenuElement({ id = spell, name = "Auto " .. spell, value = true })
	end

	Menu:MenuElement({ type = MENU, id = "Flee", name = "Flee" })
	Menu.Flee:MenuElement({ id = "W", name = "Use W", value = true })
	Menu.Flee:MenuElement({ id = "R", name = "Use R Through Enemy Unit", value = false })
	Menu.Flee:MenuElement({ id = "SafeR", name = "Do Not R Under Enemy Turret", value = true })

	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, spell in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = spell, name = "Draw " .. spell .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicAkali:ResourcePercent()
	return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100
end

function ClassicAkali:RAmmo()
	return myHero:GetSpellData(_R).ammo or 0
end

function ClassicAkali:Marked(target)
	return HaveBuff(target, "Jade_AkaliQ")
end

function ClassicAkali:InAutoAttackRange(target)
	if _G.SDK.Data and _G.SDK.Data.IsInAutoAttackRange then
		return _G.SDK.Data:IsInAutoAttackRange(myHero, target)
	end
	local range = (myHero.range or 125) + (myHero.boundingRadius or 65) + (target.boundingRadius or 65)
	return myHero.pos:DistanceTo(target.pos) <= range
end

function ClassicAkali:CanR(target, safe)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.RRange then return false end
	return not safe or IsUnderTurret(myHero) or not IsUnderTurret2(target.pos)
end

function ClassicAkali:Tick()
	if ShouldWait() or IsCasting() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicAkali:Combo()
	local target = GetTarget(self.RRange)
	if not IsValid(target) or not target.pos2D.onScreen then return end

	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if Menu.Combo.W:Value() and IsReady(_W) and hp <= Menu.Combo.WHP:Value() and target.distance <= 500 then
		Control.CastSpell(HK_W, myHero.pos)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and target.distance <= self.QRange and not self:Marked(target) then
		Control.CastSpell(HK_Q, target)
		return
	end
	if self:Marked(target) then
		if self:InAutoAttackRange(target) then return end
		if Menu.Combo.R:Value() and IsReady(_R) and self:RAmmo() > Menu.Combo.RReserve:Value() and self:CanR(target, Menu.Combo.SafeR:Value()) then
			Control.CastSpell(HK_R, target)
			return
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Combo.R:Value() and IsReady(_R) and self:RAmmo() > Menu.Combo.RReserve:Value() and self:CanR(target, Menu.Combo.SafeR:Value()) then
		Control.CastSpell(HK_R, target)
	end
end

function ClassicAkali:Harass()
	if self:ResourcePercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QRange)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.Q:Value() and IsReady(_Q) and not self:Marked(target) then
		Control.CastSpell(HK_Q, target)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) and target.distance <= self.ERange then Control.CastSpell(HK_E) end
end

function ClassicAkali:Clear()
	if not Menu.Clear.Enabled:Value() or self:ResourcePercent() < Menu.Clear.Mana:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QRange)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
	local nearby = GetMinionCount(self.ERange, myHero.pos)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.distance <= self.ERange then nearby = nearby + 1 end
	end
	if IsReady(_E) and nearby >= Menu.Clear.E:Value() then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Clear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			local health = IsValid(minion) and _G.SDK.HealthPrediction:GetPrediction(minion, 0.25) or 0
			if health > 0 and self:GetQDmg(minion) >= health then
				Control.CastSpell(HK_Q, minion)
				return
			end
		end
		if IsValid(monsters[1]) then Control.CastSpell(HK_Q, monsters[1]) end
	end
end

function ClassicAkali:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W, myHero.pos)
		return
	end
	if not Menu.Flee.R:Value() or not IsReady(_R) or self:RAmmo() == 0 then return end
	local best, bestDistance = nil, myHero.pos:DistanceTo(mousePos)
	for _, list in ipairs({ _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange), _G.SDK.ObjectManager:GetEnemyMinions(self.RRange), _G.SDK.ObjectManager:GetMonsters(self.RRange) }) do
		for _, unit in ipairs(list) do
			if IsValid(unit) and self:CanR(unit, Menu.Flee.SafeR:Value()) then
				local distance = unit.pos:DistanceTo(mousePos)
				if distance < bestDistance then
					best, bestDistance = unit, distance
				end
			end
		end
	end
	if best then Control.CastSpell(HK_R, best) end
end

function ClassicAkali:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)) do
		if IsValid(target) and target.pos2D.onScreen then
			local health = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and target.distance <= self.QRange and self:GetQDmg(target) >= health then
				Control.CastSpell(HK_Q, target)
				return
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and target.distance <= self.ERange and self:GetEDmg(target) >= health then
				Control.CastSpell(HK_E)
				return
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and self:RAmmo() > 0 and self:CanR(target, Menu.Combo.SafeR:Value()) and self:GetRDmg(target) >= health then
				Control.CastSpell(HK_R, target)
				return
			end
		end
	end
end

function ClassicAkali:Magic(target, damage)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicAkali:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 45, 70, 95, 120, 145 })[level] + myHero.ap * 0.40)
end

function ClassicAkali:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 30, 55, 80, 105, 130 })[level] + myHero.totalDamage * 0.60 + myHero.ap * 0.30)
end

function ClassicAkali:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	return self:Magic(target, ({ 100, 175, 250 })[level] + myHero.ap * 0.50)
end

function ClassicAkali:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end

ClassicAkali()
