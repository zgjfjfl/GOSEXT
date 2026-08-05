local Version = 1.02

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicKatarina"

function ClassicKatarina:__init()
	print("Classic AIO - Katarina Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Range = 675}
	self.WSpell = {Range = 400}
	self.ESpell = {Range = 700}
	self.RSpell = {Range = 500}
	self.comboTarget = nil
	self.comboTargetExpire = 0
	self.rCastLockUntil = 0
	self.rNextCastAttempt = 0
end

function ClassicKatarina:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R | Enemy Count >=", value = 1, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RMinHP", name = "Use R | Target HP >= x%", value = 15, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 2, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "Auto E KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "SafeE", name = "Do Not E Under Enemy Turret", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "FleeE", name = "Use E To Flee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function ClassicKatarina:IsChannelingR()
	local activeSpell = myHero.activeSpell
	return GetTickCount() < self.rCastLockUntil
		or HaveBuff(myHero, "Jade_KatarinaRSound")
		or (activeSpell and activeSpell.valid and activeSpell.name == "Jade_KatarinaR")
end

function ClassicKatarina:Tick()
	local channelingR = self:IsChannelingR()
	_G.SDK.Orbwalker:SetAttack(not channelingR)
	_G.SDK.Orbwalker:SetMovement(not channelingR)
	if channelingR then return end
	if ShouldWait() then return end
	if IsCasting() then return end

	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicKatarina:GetComboTarget(range)
	if GetTickCount() < self.comboTargetExpire and IsValid(self.comboTarget) then
		if myHero.pos:DistanceTo(self.comboTarget.pos) <= range then
			return self.comboTarget
		end
	end
	return GetTarget(range)
end

function ClassicKatarina:SetComboTarget(target)
	self.comboTarget = target
	self.comboTargetExpire = GetTickCount() + 2500
end

function ClassicKatarina:CanUseE(target)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.ESpell.Range then
		return false
	end
	if Menu.Misc.SafeE:Value() and not IsUnderTurret(myHero) and IsUnderTurret2(target.pos) then
		return false
	end
	return true
end

function ClassicKatarina:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = self:GetComboTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_Q, target)
			return
		end
	end

	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = self:GetComboTarget(self.ESpell.Range)
		if self:CanUseE(target) and target.pos2D.onScreen then
			self:SetComboTarget(target)
			Control.CastSpell(HK_E, target)
			return
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = self:GetComboTarget(self.WSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) and GetTickCount() >= self.rNextCastAttempt then
		local target = self:GetComboTarget(self.RSpell.Range)
		if IsValid(target) and target.maxHealth > 0 then
			local hpPercent = target.health / target.maxHealth * 100
			if hpPercent >= Menu.Combo.RMinHP:Value() and GetEnemyCount(self.RSpell.Range, myHero.pos) >= Menu.Combo.RCount:Value() then
				local now = GetTickCount()
				self.rCastLockUntil = now + 500
				self.rNextCastAttempt = self.rCastLockUntil + 750
				_G.SDK.Orbwalker:SetAttack(false)
				_G.SDK.Orbwalker:SetMovement(false)
				if not Control.CastSpell(HK_R) then
					self.rCastLockUntil = 0
					_G.SDK.Orbwalker:SetAttack(true)
					_G.SDK.Orbwalker:SetMovement(true)
				end
			end
		end
	end
end

function ClassicKatarina:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_Q, target)
			return
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if self:CanUseE(target) and target.pos2D.onScreen then
			Control.CastSpell(HK_E, target)
			return
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
			Control.CastSpell(HK_W)
		end
	end
end

function ClassicKatarina:FarmHarass()
	if Menu.Clear.SpellHarass:Value() and not IsUnderTurret(myHero) then
		self:Harass()
	end
end

function ClassicKatarina:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)

	if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
		local count = 0
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and myHero.pos:DistanceTo(minion.pos) <= self.WSpell.Range then
				count = count + 1
			end
		end
		if count >= Menu.Clear.LaneClear.WCount:Value() then
			Control.CastSpell(HK_W)
			return
		end
	end

	if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if GetMinionCount(450, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell(HK_Q, minion)
					return
				end
			end
		end
	end
end

function ClassicKatarina:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if not IsValid(monster) or not monster.pos2D.onScreen then return end

	if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(monster.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, monster)
		return
	end
	if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(monster.pos) <= self.ESpell.Range then
		Control.CastSpell(HK_E, monster)
		return
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(monster.pos) <= self.WSpell.Range then
		Control.CastSpell(HK_W)
	end
end

function ClassicKatarina:Flee()
	if not Menu.Misc.FleeE:Value() or not IsReady(_E) then return end
	local candidates = {}
	local allyHeroes = _G.SDK.ObjectManager:GetAllyHeroes(self.ESpell.Range)
	local allyMinions = _G.SDK.ObjectManager:GetAllyMinions()
	local enemyMinions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	local wards = _G.SDK.ObjectManager:GetOtherMinions(self.ESpell.Range)

	for _, unit in ipairs(allyHeroes) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(allyMinions) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(enemyMinions) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(monsters) do candidates[#candidates + 1] = unit end
	for _, unit in ipairs(wards) do candidates[#candidates + 1] = unit end

	local bestTarget = nil
	local bestDistance = myHero.pos:DistanceTo(mousePos)
	for _, unit in ipairs(candidates) do
		if IsValid(unit) and unit.networkID ~= myHero.networkID and myHero.pos:DistanceTo(unit.pos) <= self.ESpell.Range then
			local mouseDistance = unit.pos:DistanceTo(mousePos)
			local safePosition = not Menu.Misc.SafeE:Value() or IsUnderTurret(myHero) or not IsUnderTurret2(unit.pos)
			if safePosition and mouseDistance < bestDistance then
				bestDistance = mouseDistance
				bestTarget = unit
			end
		end
	end
	if bestTarget then
		Control.CastSpell(HK_E, bestTarget)
	end
end

function ClassicKatarina:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen then
			local magicHealth = target.health + target.hpRegen + target.shieldAP
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
				if self:GetQDmg(target) >= magicHealth then
					Control.CastSpell(HK_Q, target)
					return
				end
			end
			local markDamage = HaveBuff(target, "Jade_KatarinaQBuff") and self:GetQMarkDmg(target) or 0
			if Menu.KillSteal.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
				if self:GetWDmg(target) + markDamage >= magicHealth then
					Control.CastSpell(HK_W)
					return
				end
			end
			if Menu.KillSteal.E:Value() and IsReady(_E) and self:CanUseE(target) then
				if self:GetEDmg(target) + markDamage >= magicHealth then
					Control.CastSpell(HK_E, target)
					return
				end
			end
		end
	end
end

function ClassicKatarina:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.45
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetQMarkDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({15, 30, 45, 60, 75})[level] + myHero.ap * 0.15
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local damage = ({40, 75, 110, 145, 180})[level] + myHero.ap * 0.25 + myHero.bonusDamage * 0.60
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local damage = ({60, 85, 110, 135, 160})[level] + myHero.ap * 0.40
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicKatarina:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.DrawHarass:Value() then
		Draw.Text(Menu.Clear.SpellHarass:Value() and "Spell Harass: On" or "Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104)) end
end

ClassicKatarina()
