local Version = 1.03

if myHero.charName ~= "Jade_Fiora" then return end

require("ClassicAIO\\Utils")

local WAttackList = {
	["Jade_Leona"] = {"Jade_LeonaShieldOfDaybreakAttack", "Jade_LeonaShieldOfDaybreak"},
	["Jade_Blitzcrank"] = {"Jade_BlitzcrankPowerFistAttack", "Jade_BlitzcrankPowerFist"},
	["Jade_Garen"] = {"Jade_GarenQAttack", "Jade_GarenQ"},
	["Jade_XinZhao"] = {"Jade_XinZhaoQ_Thrust3", "Jade_XinZhaoQ_Knockup"},
	["Jade_TwistedFate"] = {"Jade_TwistedFate_GoldCardAttack", "Jade_TwistedFate_RedCardAttack", "Jade_TwistedFate_GoldCardLock", "Jade_TwistedFate_RedCardLock"},
	["Jade_Jax"] = {"Jade_JaxWAttack", "Jade_JaxW", "Jade_JaxRPassiveAttack"},
	["Jade_Nasus"] = {"Jade_NasusSiphoningStrikeAttack", "Jade_NasusQ"},
	["Jade_Wukong"] = {"Jade_WukongQ"},
	["Jade_Vayne"] = {"Jade_VayneQ_Attack", "Jade_VayneQ_Bonus"},
	["Jade_Shyvana"] = {"Jade_ShyvanaQ"},
	["Jade_Sivir"] = {"Jade_SivirWAttack", "Jade_SivirW"},
	["Jade_Kassadin"] = {"Jade_KassadinW", "Jade_KassadinW_Buff"},
	["Jade_Nidalee"] = {"Jade_NidaleeTakedown"},
	["Jade_Sona"] = {"Jade_SonaQ_Attack", "Jade_SonaW_Attack", "Jade_SonaE_Attack"},
	["Jade_Shaco"] = {"Jade_ShacoDeceive", "Jade_ShacoDeceiveCritBonus", "Jade_ShacoFromBehind"},
	["Jade_Kennen"] = {"Jade_KennenWPassiveProc"},
	["Jade_Ashe"] = {"Jade_AsheFrostArrow", "Jade_AsheQ"},
	["Jade_KogMaw"] = {"Jade_KogMawWAttack", "Jade_KogMawW"},
	["Jade_Twitch"] = true,
	["Jade_MasterYi"] = {"Jade_MasterYiWujuStyle", "Jade_MasterYiWujuStyleSuperCharged", "Jade_MasterYiDoubleStrike"},
	["Jade_Olaf"] = {"Jade_OlafW"},
	["Jade_DrMundo"] = {"Jade_DrMundoE"},
	["Jade_Chogath"] = {"Jade_ChogathE"},
	["Jade_Poppy"] = {"Jade_PoppyW", "Jade_PoppyW_Stats"},
	["Jade_Fiora"] = {"Jade_FioraE"},
	["Jade_Tristana"] = {"Jade_TristanaQ"},
	["Jade_Teemo"] = {"Jade_TeemoE_Attack", "Jade_TeemoE"},
	["Jade_Taric"] = true,
}

class "ClassicFiora"

function ClassicFiora:__init()
	self.QRange = 600
	self.RRange = 400
	self.lastCast = -math.huge
	self.lastSpell = {}
	self.rPendingUntil = 0
	self.incomingAttacks = {}
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args)
		if self:RActive() then args.Process = false; return end
		self.attackTarget = args.Target
	end)
	_G.SDK.Orbwalker:OnPostAttack(function(args) self:OnPostAttack(args) end)
	_G.SDK.Orbwalker:OnPreMovement(function(args)
		if self:RActive() then args.Process = false end
	end)
	print("Classic AIO - Jade Fiora Loaded")
end

function ClassicFiora:LoadMenu()
	local championIcon = "https://raw.communitydragon.org/16.18/game/assets/characters/jade_fiora/hud/jade_fiora_square_301.png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "HoldQ2", name = "Save Second Q For Chase / Expiry", value = true})
	Menu.Combo:MenuElement({id = "SafeQ", name = "Do Not Q Into Enemy Turret", value = true})
	Menu.Combo:MenuElement({id = "QMinion", name = "Q Minion To Close Gap", value = true})
	Menu.Combo:MenuElement({id = "QMinionRange", name = "Gap Close Enemy Range", value = 1000, min = 600, max = 1200, step = 25})
	Menu.Combo:MenuElement({id = "E", name = "Use E After Attack (Reset)", value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R When Killable", value = true})
	Menu.Combo:MenuElement({id = "RHP", name = "Also R When My HP <= % (0: Off)", value = 25, min = 0, max = 60, step = 5})
	Menu.Combo:MenuElement({id = "SafeR", name = "Do Not R Into Enemy Turret", value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E After Attack", value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end})
	Menu.Clear:MenuElement({id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({id = "LaneQ", name = "Lane / LastHit: Q Last Hit", value = true})
	Menu.Clear:MenuElement({id = "LaneE", name = "Lane: E After Attack", value = true})
	Menu.Clear:MenuElement({id = "JungleQ", name = "Jungle: Use Q", value = true})
	Menu.Clear:MenuElement({id = "JungleW", name = "Jungle: W Incoming Attacks", value = true})
	Menu.Clear:MenuElement({id = "JungleE", name = "Jungle: E After Attack", value = true})
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q", value = true})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R", value = true})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoW", name = "Auto W Incoming Champion Attacks", value = true})
	Menu.Misc:MenuElement({id = "WNormalHP", name = "W: Normal Attacks Only Below My HP % (0 = Never)", value = 70, min = 0, max = 100, step = 5})
	Menu.Misc:MenuElement({id = "WLead", name = "W Before Attack Impact (ms)", value = 200, min = 50, max = 500, step = 25})
	Menu.Misc:MenuElement({id = "FleeQ", name = "Flee: Q Through Enemies Toward Mouse", value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", value = false})
	Menu.Draw:MenuElement({id = "Farm", name = "Draw Farm Status", value = true})
end

function ClassicFiora:ManaPercent()
	return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100
end

function ClassicFiora:QRecast()
	return HaveBuff(myHero, "Jade_FioraQ_CD")
end

function ClassicFiora:QExpiring()
	local active, buff = GetBuffData(myHero, "Jade_FioraQ_CD")
	return active and buff.expireTime > 0 and buff.expireTime - Game.Timer() <= 0.45
end

function ClassicFiora:RActive()
	if myHero.dead then return false end
	local spell = myHero.activeSpell
	local casting = spell and spell.valid and (spell.name == "Jade_FioraR" or spell.name == "Jade_FioraR_Strike")
		and (spell.isChanneling or Game.Timer() <= (spell.endTime or spell.castEndTime or 0))
	if casting then self.rObservedUntil = Game.Timer() + 3 end
	return Game.Timer() < self.rPendingUntil
		or HaveBuff(myHero, "Jade_FioraR") or HaveBuff(myHero, "Jade_FioraR_Strike")
		or casting or (myHero.isTargetable == false
			and Game.Timer() < math.max(self.rObservedUntil or 0, (self.lastSpell[_R] or -math.huge) + 3))
end

function ClassicFiora:Ready(slot)
	local spell = myHero:GetSpellData(slot)
	-- Q's free second cast can retain the first cast's mana value in spell data.
	return spell.level > 0 and spell.currentCd == 0 and Game.CanUseSpell(slot) == 0
		and ((slot == _Q and self:QRecast()) or spell.mana <= myHero.mana)
end

function ClassicFiora:Cast(slot, key, target)
	local now = Game.Timer()
	if not self:Ready(slot) or now - self.lastCast < 0.15 or now - (self.lastSpell[slot] or -math.huge) < 0.3 then return false end
	if not Control.CastSpell(key, target) then return false end
	self.lastCast, self.lastSpell[slot] = now, now
	if slot == _R then self.rPendingUntil = now + 0.4 end
	return true
end

function ClassicFiora:CanTarget(target, range, safe)
	if not IsValid(target) or not target.pos2D.onScreen or GetDistance(myHero.pos, target.pos) > range then return false end
	if target.type == Obj_AI_Hero and (IsInvulnerable(target) or _G.SDK.ObjectManager:IsHeroImmortal(target, false)) then return false end
	return not safe or IsUnderTurret(myHero) or not IsUnderTurret2(target.pos)
end

function ClassicFiora:CastQ(target, safe)
	if not self:CanTarget(target, self.QRange, safe) then return false end
	if not self:Cast(_Q, HK_Q, target) then return false end
	if target.type == Obj_AI_Hero then self.comboTarget, self.comboTargetUntil = target, Game.Timer() + 4 end
	return true
end

function ClassicFiora:CastQMinion(target)
	-- Dash to an enemy minion only when it leaves the hero inside Q range and closes the gap.
	if not Menu.Combo.QMinion:Value() or target.type ~= Obj_AI_Hero or not self:Ready(_Q) then return false end
	local targetDistance = GetDistance(myHero.pos, target.pos)
	if targetDistance <= self.QRange or targetDistance > Menu.Combo.QMinionRange:Value() then return false end
	local safe, best, bestDistance = Menu.Combo.SafeQ:Value(), nil, nil
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QRange)) do
		if self:CanTarget(minion, self.QRange, safe) then
			local distance = GetDistance(minion.pos, target.pos)
			if distance <= self.QRange and distance < targetDistance - 100 and (not bestDistance or distance < bestDistance) then
				best, bestDistance = minion, distance
			end
		end
	end
	if best then return self:CastQ(best, safe) end
	return false
end

function ClassicFiora:GetComboTarget()
	local range = math.max(self.QRange, self.RRange)
	if self.comboTargetUntil and Game.Timer() < self.comboTargetUntil and self:CanTarget(self.comboTarget, range, false) then return self.comboTarget end
	return GetTarget(range)
end

function ClassicFiora:CanFarm()
	return Menu.Clear.Enabled:Value() and self:ManaPercent() >= Menu.Clear.Mana:Value() and not IsUnderTurret(myHero)
end

function ClassicFiora:Tick()
	if ShouldWait() or self:RActive() then return end
	if self:AutoW() then return end
	if IsCasting() or (myHero.pathing and myHero.pathing.isDashing) or _G.SDK.Orbwalker:IsAutoAttacking() then return end
	if Menu.Misc.SemiR:Value() then
		local target = GetTarget(self.RRange)
		if self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value()) and self:Cast(_R, HK_R, target) then return end
	end
	local mode = GetMode()
	if mode == "Flee" then self:Flee(); return end
	if self:KillSteal() then return end
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" or mode == "LastHit" then
		self:Clear(mode == "LastHit")
	end
end

function ClassicFiora:OnPostAttack(args)
	local target = (args and args.Target) or self.attackTarget or _G.SDK.Orbwalker:GetTarget()
	self.attackTarget = nil
	if ShouldWait() or self:RActive() or IsCasting() or not IsValid(target) then return end
	local mode = GetMode()
	local useE, useQ, safe = false, false, true
	if mode == "Combo" and target.type == Obj_AI_Hero then
		useE, useQ, safe = Menu.Combo.E:Value(), Menu.Combo.Q:Value(), Menu.Combo.SafeQ:Value()
	elseif mode == "Harass" and target.type == Obj_AI_Hero and self:ManaPercent() >= Menu.Harass.Mana:Value() then
		useE, useQ = Menu.Harass.E:Value(), Menu.Harass.Q:Value()
	elseif mode == "LaneClear" and target.type == Obj_AI_Minion and self:CanFarm() then
		useE = target.team == 300 and Menu.Clear.JungleE:Value() or (target.team ~= 300 and Menu.Clear.LaneE:Value())
	end
	if useE and _G.SDK.Data:IsInAutoAttackRange(myHero, target) and not HaveBuff(myHero, "Jade_FioraE") then
		-- GGOrbwalker already registers Jade_Fiora E as an attack reset.
		if self:Cast(_E, HK_E) then return end
	end
	if useQ and (not self:QRecast() or not Menu.Combo.HoldQ2:Value() or self:QExpiring()) then self:CastQ(target, safe) end
end

function ClassicFiora:Combo()
	local target = self:GetComboTarget()
	if not IsValid(target) and Menu.Combo.QMinion:Value() then target = GetTarget(Menu.Combo.QMinionRange:Value()) end
	if not IsValid(target) then return end
	if Menu.Combo.R:Value() and self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value()) then
		local hp = target.health + (target.shieldAD or 0) + (target.hpRegen or 0) * 2
		local lowHP = Menu.Combo.RHP:Value() > 0 and myHero.health / myHero.maxHealth * 100 <= Menu.Combo.RHP:Value()
		if self:GetRDmg(target) >= hp or lowHP then
			if self:Cast(_R, HK_R, target) then return end
		end
	end
	if Menu.Combo.Q:Value() and (not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or self:QExpiring()) then
		if not self:CastQ(target, Menu.Combo.SafeQ:Value()) and GetDistance(myHero.pos, target.pos) > self.QRange then self:CastQMinion(target) end
	end
end

function ClassicFiora:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() or not Menu.Harass.Q:Value() then return end
	local target = self:GetComboTarget()
	if IsValid(target) and (not _G.SDK.Data:IsInAutoAttackRange(myHero, target) or self:QExpiring()) then self:CastQ(target, true) end
end

function ClassicFiora:ListedAttack(source)
	if source.charName == "Jade_Vayne" then
		local active, buff = GetBuffData(myHero, "Jade_VayneW_Debuff")
		if active and (buff.count or buff.stacks or 0) >= 2 then return true end
	end
	local names = WAttackList[source.charName]
	if names == true then return true end
	if not names then return false end
	local spell = source.activeSpell
	local spellName = spell and spell.valid and spell.name
	for _, name in ipairs(names) do
		if spellName == name or HaveBuff(source, name) then return true end
	end
	return false
end

function ClassicFiora:AutoW()
	if not self:Ready(_W) or HaveBuff(myHero, "Jade_FioraW") then return false end
	local now = Game.Timer()
	local jungle = GetMode() == "LaneClear" and self:CanFarm() and Menu.Clear.JungleW:Value()
	local sources = {}
	if Menu.Misc.AutoW:Value() then
		for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1600)) do sources[#sources + 1] = unit end
	end
	if jungle then
		for _, unit in ipairs(_G.SDK.ObjectManager:GetMonsters(800)) do sources[#sources + 1] = unit end
	end
	for _, source in ipairs(sources) do
		local spell = source.activeSpell
		if IsValid(source) and spell and spell.valid and not spell.isStopped and spell.target == myHero.handle
			and (spell.isAutoAttack or _G.SDK.Data:IsAttack(spell.name or "")) then
			local attack = source.attackData or {}
			local launch = spell.castEndTime
			if not launch or launch <= 0 then launch = (spell.startTime or now) + (spell.windup or attack.windUpTime or 0) end
			local speed = spell.speed and spell.speed > 0 and spell.speed or attack.projectileSpeed
			local travel = 0
			if (source.range or 125) >= 300 and speed and speed > 0 then
				travel = math.max(0, GetDistance(source.pos, myHero.pos) - (source.boundingRadius or 0) - myHero.boundingRadius) / speed
			end
			local key = tostring(source.handle) .. ":" .. tostring(launch)
			if not self.incomingAttacks[key] or now <= launch then
				self.incomingAttacks[key] = {source = source, launch = launch, hit = launch + travel, start = spell.startTime}
			end
		end
	end
	local lead = Menu.Misc.WLead:Value() / 1000 + _G.SDK.Data:GetLatency()
	local hpLimit = Menu.Misc.WNormalHP:Value()
	local lowHp = hpLimit > 0 and myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 <= hpLimit
	for key, attack in pairs(self.incomingAttacks) do
		local source, spell = attack.source, attack.source.activeSpell
		local empowered = source.type == Obj_AI_Hero and self:ListedAttack(source)
		local enabled = source.type == Obj_AI_Hero and Menu.Misc.AutoW:Value() and (empowered or lowHp)
			or (source.team == 300 and jungle)
		local cancelled = now < attack.launch and (not spell or not spell.valid or spell.isStopped or spell.target ~= myHero.handle or spell.startTime ~= attack.start)
		if not enabled or cancelled or now > attack.hit + 0.05 then
			self.incomingAttacks[key] = nil
		elseif attack.hit - now <= lead then
			if self:Cast(_W, HK_W) then self.incomingAttacks = {}; return true end
		end
	end
	return false
end

function ClassicFiora:Clear(lastHitOnly)
	if not self:CanFarm() then return end
	if not lastHitOnly and Menu.Clear.JungleQ:Value() then
		local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
		table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, monster in ipairs(monsters) do
			if self:CastQ(monster, true) then return end
		end
	end
	if not Menu.Clear.LaneQ:Value() or not self:Ready(_Q) then return end
	for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QRange)) do
		if minion.team ~= 300 and self:CanTarget(minion, self.QRange, true) then
			local hp = _G.SDK.HealthPrediction:GetPrediction(minion, 0.1 + GetDistance(myHero.pos, minion.pos) / 1200)
			if hp > 0 and self:GetQDmg(minion) >= hp + (minion.shieldAD or 0) and self:CastQ(minion, true) then return end
		end
	end
end

function ClassicFiora:Flee()
	if not Menu.Misc.FleeQ:Value() or not self:Ready(_Q) then return end
	local best, bestDistance = nil, 0
	local mouseDistance = GetDistance(myHero.pos, mousePos) - 100
	for _, units in ipairs({_G.SDK.ObjectManager:GetEnemyHeroes(self.QRange), _G.SDK.ObjectManager:GetEnemyMinions(self.QRange), _G.SDK.ObjectManager:GetMonsters(self.QRange)}) do
		for _, unit in ipairs(units) do
			local distance = GetDistance(myHero.pos, unit.pos)
			if distance > bestDistance and GetDistance(unit.pos, mousePos) < mouseDistance and self:CanTarget(unit, self.QRange, true) then best, bestDistance = unit, distance end
		end
	end
	if best then self:CastQ(best, true) end
end

function ClassicFiora:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(math.max(self.QRange, self.RRange))) do
		local hp = target.health + (target.shieldAD or 0) + (target.hpRegen or 0)
		if Menu.KillSteal.Q:Value() and self:GetQDmg(target) >= hp and self:CastQ(target, true) then return true end
		if Menu.KillSteal.R:Value() and self:CanTarget(target, self.RRange, Menu.Combo.SafeR:Value())
			and self:GetRDmg(target) >= hp + (target.hpRegen or 0) and self:Cast(_R, HK_R, target) then return true end
	end
	return false
end

function ClassicFiora:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	-- Jade 16.18 cache: 40/65/90/115/140 + 0.60 bonus AD, physical.
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, 15 + 25 * level + 0.6 * myHero.bonusDamage)
end

function ClassicFiora:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	local damage = ({160, 330, 500})[level] + 1.15 * myHero.bonusDamage
	-- Blade Waltz: five strikes; repeated hits deal 25%. Only assume all five
	-- hit one champion when no other enemy is inside the 600-unit bounce radius.
	local isolated = true
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if enemy.networkID ~= target.networkID and GetDistance(enemy.pos, target.pos) <= 600 then isolated = false; break end
	end
	if isolated then damage = damage * (1 + 4 * 0.25) end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, damage)
end

function ClassicFiora:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and self:Ready(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.R:Value() and self:Ready(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 120, 66)) end
end

ClassicFiora()
