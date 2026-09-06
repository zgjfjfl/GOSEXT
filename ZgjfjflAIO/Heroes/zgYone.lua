local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgYone"

local function EffectiveHealth(unit)
	return (unit.health or 0) + (unit.shieldAD or 0) + (unit.shieldAP or 0)
end

local function IsQ3Knockup(unit)
	return HaveBuff(unit, "yoneq3knockup")
end

local function IsNear(unit, pos, range)
	return IsValid(unit) and unit.pos:DistanceTo(pos) <= range
end

function zgYone:__init()
	print("Zgjfjfl AIO - Yone Loaded")
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 55, Range = 450, Speed = math.huge, Collision = false}
	self.q3Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1050, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = {Type = GGPrediction.SPELLTYPE_LINE, Angle = 40, Delay = 0.5, Radius = 100, Range = 600, Speed = math.huge, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.75, Radius = 112.5, Range = 1000, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.eRange = 300
	self.rRange = 1000
	self.lastQ = 0
	self.lastW = 0
	self.lastE = 0
	self.lastR = 0
	self.eStartTick = 0
	self:LoadMenu()
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function zgYone:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_" .. myHero.charName, name = "Zgjfjfl AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q3", name = "Use Q3", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E1", name = "Use E1", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "EHasQ3", name = "E1 only if Q3 can cast", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RMode", name = "Use R | Mode", value = 1, drop = {"After Q3 Knockup", "Always"}})
	Menu.Combo:MenuElement({id = "RCount", name = "Always R if hits >=", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q3", name = "Use Q3", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E1", name = "Use E1", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "Lane Clear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "Q3", name = "Use Q3", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Q3 minimum hits", value = 2, min = 1, max = 7, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "Jungle Clear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "Q3", name = "Use Q3", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "LastHit", name = "Last Hit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.LastHit:MenuElement({id = "W", name = "Use W", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Q3", name = "Use Q3 to mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Auto", name = "Automatic"})
	Menu.Auto:MenuElement({id = "QKill", name = "Use Q to kill", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "WKill", name = "Use W to kill", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "RKill", name = "Use R to kill", toggle = true, value = false})
	Menu.Auto:MenuElement({id = "AntiGapcloser", name = "Use Q3 against gapclosers", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "StackQ", name = "Auto stack Q on minions and monsters", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q range", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q3", name = "Draw Q3 range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R range", toggle = true, value = false})
end

function zgYone:IsQ3Ready()
	local name = myHero:GetSpellData(_Q).name:lower()
	return name == "yoneq3"
end

function zgYone:IsEActive()
	return HaveBuff(myHero, "YoneE")
end

function zgYone:UpdateSpellData()
	local bonusAS = math.max((myHero.attackSpeed or 1) - 1, 0)
	local castTimeScale = 1 - math.min(bonusAS * 0.4166667, 0.5)
	self.qSpell.Delay = 0.35 * castTimeScale
	self.q3Spell.Delay = self.qSpell.Delay
	self.wSpell.Delay = 0.5 * castTimeScale
end

function zgYone:CanCast(slot, lastCast, delay)
	return IsReady(slot) and lastCast + delay < GetTickCount()
end

function zgYone:GetTarget(range)
	local target = _G.SDK.Orbwalker and _G.SDK.Orbwalker.GetTarget and _G.SDK.Orbwalker:GetTarget()
	if IsValid(target) and target.type == Obj_AI_Hero and target.distance <= range then
		return target
	end
	return GetTarget(range)
end

function zgYone:CastQ(target, forceQ3)
	if not IsValid(target) or not self:CanCast(_Q, self.lastQ, 120) then return false end
	local q3 = forceQ3 == true or (forceQ3 ~= false and self:IsQ3Ready())
	local spell = q3 and self.q3Spell or self.qSpell
	local prediction = GGPrediction:SpellPrediction(spell)
	prediction:GetPrediction(target, myHero)
	local hitchance = q3 and GGPrediction.HITCHANCE_HIGH or GGPrediction.HITCHANCE_NORMAL
	if prediction:CanHit(hitchance) and prediction.CastPosition then
		if Control.CastSpell(HK_Q, prediction.CastPosition) then
			self.lastQ = GetTickCount()
			return true
		end
	end
	return false
end

function zgYone:CastQAt(position, forceQ3)
	if not position or not self:CanCast(_Q, self.lastQ, 120) then return false end
	local q3 = forceQ3 == true or (forceQ3 ~= false and self:IsQ3Ready())
	local spell = q3 and self.q3Spell or self.qSpell
	if Control.CastSpell(HK_Q, position) then
		self.lastQ = GetTickCount()
		return true
	end
	return false
end

function zgYone:CastW(target)
	if not IsValid(target) or not self:CanCast(_W, self.lastW, 350) then return false end
	if myHero.pos:DistanceTo(target.pos) > self.wSpell.Range then return false end
	if target.type ~= Obj_AI_Hero then
		if Control.CastSpell(HK_W, target.pos) then
			self.lastW = GetTickCount()
			return true
		end
		return false
	end
	local prediction = GGPrediction:SpellPrediction(self.wSpell)
	prediction:GetPrediction(target, myHero)
	if prediction:CanHit(GGPrediction.HITCHANCE_NORMAL) and prediction.CastPosition then
		if Control.CastSpell(HK_W, prediction.CastPosition) then
			self.lastW = GetTickCount()
			return true
		end
	end
	return false
end

function zgYone:GetBestRPosition(preferred, requirePreferred)
	local prediction = GGPrediction:SpellPrediction(self.rSpell)
	local results = nil
	local ok, value = pcall(function() return prediction:GetAOEPrediction(myHero) end)
	if ok and value then results = value end
	if results and #results > 0 then
		table.sort(results, function(a, b) return (a.Count or 0) > (b.Count or 0) end)
		if preferred then
			for _, result in ipairs(results) do
				if result.Unit and result.Unit.networkID == preferred.networkID and result.CastPosition then
					return result.CastPosition, result.Count or 1
				end
			end
		end
		if not requirePreferred and results[1].CastPosition then return results[1].CastPosition, results[1].Count or 1 end
	end
	if IsValid(preferred) then
		prediction:GetPrediction(preferred, myHero)
		if prediction:CanHit(GGPrediction.HITCHANCE_NORMAL) and prediction.CastPosition then return prediction.CastPosition, 1 end
	end
	return nil, 0
end

function zgYone:HasQ3Knockup()
	local target = self:GetTarget(self.rRange)
	return IsValid(target) and target.type == Obj_AI_Hero and IsQ3Knockup(target)
end

function zgYone:CastR(forceKill, singleTarget)
	if not self:CanCast(_R, self.lastR, 400) then return false end
	local preferred = nil
	if forceKill then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.rRange)) do
			if IsValid(enemy) and self:GetRDamage(enemy) >= EffectiveHealth(enemy) then
				preferred = enemy
				break
			end
		end
	else
		preferred = self:GetTarget(self.rRange)
	end
	if not IsValid(preferred) then return false end
	if myHero.pos:DistanceTo(preferred.pos) > self.rRange then return false end
	local castPosition, hitCount = self:GetBestRPosition(preferred, forceKill == true)
	if not castPosition then return false end
	local shouldCast = singleTarget or forceKill and self:GetRDamage(preferred) >= EffectiveHealth(preferred)
	if not shouldCast and Menu.Combo.RMode:Value() == 2 then
		shouldCast = hitCount >= Menu.Combo.RCount:Value()
	end
	if not shouldCast then return false end
	if Control.CastSpell(HK_R, castPosition) then
		self.lastR = GetTickCount()
		return true
	end
	return false
end

function zgYone:GetE1Range()
	local q3Ready = self:IsQ3Ready() and self:CanCast(_Q, self.lastQ, 120)
	return self.eRange + (q3Ready and self.q3Spell.Range or self.qSpell.Range)
end

function zgYone:CastEStart(target)
	local q3Ready = self:IsQ3Ready() and self:CanCast(_Q, self.lastQ, 120)
	if not IsValid(target) or self:IsEActive() or not self:CanCast(_E, self.lastE, 300) or (Menu.Combo.EHasQ3:Value() and not q3Ready) then return false end
	if Control.CastSpell(HK_E, target) then
		self.lastE = GetTickCount()
		self.eStartTick = GetTickCount()
		return true
	end
	return false
end

function zgYone:IsQ3RSetup(target)
	if GetMode() ~= "Combo" or not Menu.Combo.R:Value() or Menu.Combo.RMode:Value() ~= 1 then return false end
	if not IsValid(target) or target.type ~= Obj_AI_Hero or not self:CanCast(_R, self.lastR, 400) then return false end
	if IsQ3Knockup(target) then return target.distance <= self.rRange end
	if not Menu.Combo.Q3:Value() or not self:IsQ3Ready() or not self:CanCast(_Q, self.lastQ, 120) then return false end
	if target.distance > self.q3Spell.Range then return false end
	local prediction = GGPrediction:SpellPrediction(self.q3Spell)
	prediction:GetPrediction(target, myHero)
	return prediction:CanHit(GGPrediction.HITCHANCE_HIGH) and prediction.CastPosition ~= nil
end

function zgYone:OnPreAttack(args)
	local target = args and args.Target
	if self:IsQ3RSetup(target) then args.Process = false end
end

function zgYone:IsInAARange(target)
	if not IsValid(target) then return false end
	local range = (myHero.range or 175) + (myHero.boundingRadius or 35) + (target.boundingRadius or 35)
	return myHero.pos:DistanceTo(target.pos) <= range
end

function zgYone:Combo()
	local rMode = Menu.Combo.RMode:Value()
	local rAfterQ3 = rMode == 1 and self:HasQ3Knockup()
	local canR = rAfterQ3 or rMode == 2
	local q3RSequence = Menu.Combo.R:Value()
		and rMode == 1
		and self:CanCast(_R, self.lastR, 400)
		and (rAfterQ3 or self:IsQ3RSetup(self:GetTarget(self.q3Spell.Range)))
	if Menu.Combo.R:Value() and canR and self:CastR(false, rAfterQ3) then return end
	if Menu.Combo.E1:Value() and not self:IsEActive() then
		local target = self:GetTarget(self:GetE1Range())
		if not self:IsInAARange(target) and self:CastEStart(target) then return end
	end
	if Menu.Combo.Q3:Value() and self:IsQ3Ready() and self:CastQ(self:GetTarget(self.q3Spell.Range), true) then return end
	if Menu.Combo.Q:Value() and not self:IsQ3Ready() and self:CastQ(self:GetTarget(self.qSpell.Range), false) then return end
	if Menu.Combo.W:Value() and not q3RSequence and self:CastW(self:GetTarget(self.wSpell.Range)) then return end
end

function zgYone:Harass()
	if Menu.Harass.E1:Value() then
		local target = self:GetTarget(self:GetE1Range())
		if not self:IsInAARange(target) and self:CastEStart(target) then return end
	end
	if Menu.Harass.Q3:Value() and self:IsQ3Ready() and self:CastQ(self:GetTarget(self.q3Spell.Range), true) then return end
	if Menu.Harass.Q:Value() and not self:IsQ3Ready() and self:CastQ(self:GetTarget(self.qSpell.Range), false) then return end
	if Menu.Harass.W:Value() then self:CastW(self:GetTarget(self.wSpell.Range)) end
end

function zgYone:GetQDamage(target)
	local level = myHero:GetSpellData(_Q).level or 0
	if level <= 0 then return 0 end
	local base = ({25, 50, 75, 100, 125})[level] or 0
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, base + 1.10 * myHero.totalDamage)
end

function zgYone:GetWDamage(target)
	local level = myHero:GetSpellData(_W).level or 0
	if level <= 0 then return 0 end
	local base = ({10, 20, 30, 40, 50})[level] or 0
	local percent = ({0.08, 0.09, 0.10, 0.11, 0.12})[level] or 0
	local raw = base + percent * target.maxHealth
	if target.type == Obj_AI_Minion then
		local heroLevel = math.min(math.max(myHero.levelData and myHero.levelData.lvl or 1, 1), 20)
		if target.team == 300 then
			local monsterMaximum = ({150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320, 330, 340})[heroLevel] or 150
			raw = math.min(raw, monsterMaximum)
		else
			local minionMinimum = ({40, 50, 60, 70, 80, 90, 100, 110, 130, 150, 170, 190, 210, 250, 290, 330, 370, 410, 450, 490})[heroLevel] or 40
			raw = math.max(raw * 0.25, minionMinimum)
		end
	end
	local physical = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, raw * 0.5)
	local magical = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw * 0.5)
	return physical + magical
end

function zgYone:GetRDamage(target)
	local level = myHero:GetSpellData(_R).level or 0
	if level <= 0 then return 0 end
	local base = ({100, 200, 300})[level] or 0
	local raw = base + 0.4 * myHero.bonusDamage
	local physical = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, raw)
	local magical = _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw)
	return physical + magical
end

function zgYone:CastFarmQ(units, q3, minHits)
	if not self:CanCast(_Q, self.lastQ, 120) then return false end
	local spell = q3 and self.q3Spell or self.qSpell
	local best, bestCount = nil, 0
	for _, unit in ipairs(units or {}) do
		if IsValid(unit) and myHero.pos:DistanceTo(unit.pos) <= spell.Range then
			local count = 1
			if q3 then
				local isWall, _, collisions = GGPrediction:GetCollision(myHero.pos, unit.pos, spell.Speed, spell.Delay, spell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}, unit.networkID)
				count = isWall and 0 or (collisions or 0) + 1
			end
			if count > bestCount then best, bestCount = unit, count end
		end
	end
	if best and bestCount >= (minHits or 1) then return self:CastQAt(best.pos, q3) end
	return false
end

function zgYone:LaneClear()
	if Menu.Clear.LaneClear.Q3:Value() and self:IsQ3Ready() then
		if self:CastFarmQ(_G.SDK.ObjectManager:GetEnemyMinions(self.q3Spell.Range), true, Menu.Clear.LaneClear.QCount:Value()) then return end
	elseif Menu.Clear.LaneClear.Q:Value() and not self:IsQ3Ready() then
		if self:CastFarmQ(_G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range), false, 1) then return end
	end
	if Menu.Clear.LaneClear.W:Value() and self:CanCast(_W, self.lastW, 350) then
		for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.wSpell.Range)) do
			if IsValid(minion) and minion.team ~= 300 and not self:IsInAARange(minion) and self:GetWDamage(minion) >= EffectiveHealth(minion) then
				if self:CastW(minion) then return end
			end
		end
	end
end

function zgYone:JungleClear()
	if Menu.Clear.JungleClear.Q3:Value() and self:IsQ3Ready() then
		if self:CastFarmQ(_G.SDK.ObjectManager:GetMonsters(self.q3Spell.Range), true, 1) then return end
	elseif Menu.Clear.JungleClear.Q:Value() and not self:IsQ3Ready() then
		if self:CastFarmQ(_G.SDK.ObjectManager:GetMonsters(self.qSpell.Range), false, 1) then return end
	end
	if Menu.Clear.JungleClear.W:Value() then
		for _, monster in ipairs(_G.SDK.ObjectManager:GetMonsters(self.wSpell.Range)) do
			if IsValid(monster) and self:CastW(monster) then return end
		end
	end
end

function zgYone:LastHit()
	local q3 = self:IsQ3Ready()
	if Menu.LastHit.Q:Value() then
		for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(q3 and self.q3Spell.Range or self.qSpell.Range)) do
			if IsValid(minion) and self:GetQDamage(minion) >= EffectiveHealth(minion) then
				if self:CastQAt(minion.pos, q3) then return end
			end
		end
	end
	if Menu.LastHit.W:Value() then
		for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.wSpell.Range)) do
			if IsValid(minion) and minion.team ~= 300 and self:GetWDamage(minion) >= EffectiveHealth(minion) then
				if self:CastW(minion) then return end
			end
		end
	end
end

function zgYone:AntiGapcloser()
	if not Menu.Auto.AntiGapcloser:Value() or not self:IsQ3Ready() or not self:CanCast(_Q, self.lastQ, 120) then return end
	for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.q3Spell.Range)) do
		if IsValid(enemy) and enemy.pathing and enemy.pathing.isDashing and enemy.pathing.endPos then
			local nearEnd = enemy.pathing.endPos.DistanceTo and enemy.pathing.endPos:DistanceTo(myHero.pos) <= 350
			if nearEnd or IsNear(enemy, myHero.pos, 350) then
				if self:CastQAt(enemy.pathing.endPos, true) then return end
			end
		end
	end
end

function zgYone:StackQ()
	if not Menu.Auto.StackQ:Value() or self:IsQ3Ready() or not self:CanCast(_Q, self.lastQ, 120) then return end
	if self:GetTarget(self.qSpell.Range) then return end
	for _, unit in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.qSpell.Range) or {}) do
		if IsValid(unit) and self:CastQAt(unit.pos, false) then return end
	end
end

function zgYone:KillSteal()
	if Menu.Auto.RKill:Value() and self:CastR(true) then return end
	local q3 = self:IsQ3Ready()
	if Menu.Auto.QKill:Value() then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(q3 and self.q3Spell.Range or self.qSpell.Range)) do
			if IsValid(enemy) and self:GetQDamage(enemy) >= EffectiveHealth(enemy) then
				if self:CastQ(enemy, q3) then return end
			end
		end
	end
	if Menu.Auto.WKill:Value() then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.wSpell.Range)) do
			if IsValid(enemy) and self:GetWDamage(enemy) >= EffectiveHealth(enemy) then
				if self:CastW(enemy) then return end
			end
		end
	end
end

function zgYone:Flee()
	if Menu.Flee.Q3:Value() and self:IsQ3Ready() then self:CastQAt(mousePos, true) end
end

function zgYone:Tick()
	if ShouldWait() then return end
	self:UpdateSpellData()
	self:AntiGapcloser()
	if IsCasting() then return end
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif mode == "LaneClear" then
		self:LastHit()
		self:LaneClear()
		self:JungleClear()
	elseif mode == "LastHit" then
		self:LastHit()
	elseif mode == "Flee" then
		self:Flee()
	end
	if not mode then self:StackQ() end
	if Menu.Combo.SemiR:Value() then self:CastR(false, true) end
	self:KillSteal()
end

function zgYone:Draw()
	if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) and not self:IsQ3Ready() then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(180, 70, 170, 255))
	end
	if Menu.Draw.Q3:Value() and IsReady(_Q) and self:IsQ3Ready() then
		Draw.Circle(myHero.pos, self.q3Spell.Range, Draw.Color(180, 255, 210, 70))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(180, 70, 220, 120))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(180, 255, 80, 80))
	end
end

zgYone()
