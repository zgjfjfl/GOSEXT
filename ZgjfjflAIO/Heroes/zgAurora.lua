local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAurora"

function zgAurora:__init()
	print("Zgjfjfl AIO - Aurora Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 900, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 80, Range = 825, Speed = math.huge, Collision = false}
	self.RSpell = { Range = 700, Radius = 700}
end

function zgAurora:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo(when Q or E ready)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q | Max Range", value = 850, min = 550, max = 900, step = 25})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E | Max Range", value = 775, min = 550, max = 825, step = 25})
	Menu.Combo:MenuElement({id = "RAOE", name = "Use R AOE", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R | Min Enemies", value = 3, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q | Max Range", value = 850, min = 550, max = 900, step = 25})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoQ2", name = "Auto Q2", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "EGap", name = "Use E AntiGapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "WFlee", name = "Use W | Flee to Mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgAurora:OnPreAttack(args)
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() and ((IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ") or IsReady(_E)) then
			args.Process = false
		end
	end
end

function zgAurora:Tick()
	if ShouldWait() then
		return
	end
	self:AntiGapcloser()
	self:AutoQ2()
	if IsCasting() then return end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgAurora:GetQ2Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local missingHpPer = (target.maxHealth - target.health) / target.maxHealth
	local Dmg = (({45, 70, 95, 120, 145})[level] + 0.4 * myHero.ap) * (1 + missingHpPer * 0.5)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
end

function zgAurora:GetPDmg(target)
	local buff, buffData = GetBuffData(target, "AuroraPDebuff")
	if buff and buffData.count == 2 then
		local Dmg = (0.025 + myHero.ap / 100 * 0.02) * target.maxHealth
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, Dmg)
	else
		return 0
	end
end

function zgAurora:AutoQ2()
	local buff, buffData = GetBuffData(myHero, "AuroraQRecast")
	if myHero:GetSpellData(_Q).name == "AuroraQRecast" then
		if Menu.Misc.AutoQ2:Value() and Game.CanUseSpell(_Q) == 0 then
			for i, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
				if IsValid(enemy) and HaveBuff(enemy, "auroraqdebufftracker") then
					local Q2Dmg = self:GetQ2Dmg(enemy) + self:GetPDmg(enemy)
					if (enemy.health + enemy.shieldAD + enemy.shieldAP) <= Q2Dmg or (buff and buffData.duration < 1) then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end

function zgAurora:AntiGapcloser()
	if Menu.Misc.EGap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Combo.Erange:Value())
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					self:CastE(target)
				end
			end
		end
	end
end

function zgAurora:Flee()
	if Menu.Misc.WFlee:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
	end
end

function zgAurora:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) then 
			self:CastE(target)
		end
	end
	if Menu.Combo.RAOE:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and GetEnemyCount(self.RSpell.Radius, target.pos) >= Menu.Combo.RCount:Value() then 
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgAurora:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ" then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgAurora:LaneClear()
	if IsUnderTurret(myHero) then return end
	if not Menu.Clear.SpellFarm:Value() then return end

	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
	local qReady = Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ"
	local eReady = Menu.Clear.LaneClear.E:Value() and IsReady(_E)
	local qBestTarget, qMaxHits = nil, 0
	local eBestTarget, eMaxHits = nil, 0

	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
			if qReady then
				local _, _, qCollision = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if qCollision > qMaxHits then
					qMaxHits = qCollision
					qBestTarget = minion
				end
			end
			if eReady then
				local _, _, eCollision = GGPrediction:GetCollision(myHero.pos, minion.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if eCollision > eMaxHits then
					eMaxHits = eCollision
					eBestTarget = minion
				end
			end
		end
	end

	if qBestTarget and qMaxHits >= Menu.Clear.LaneClear.QCount:Value() then
		Control.CastSpell(HK_Q, qBestTarget)
	end
	if eBestTarget and eMaxHits >= Menu.Clear.LaneClear.ECount:Value() then
		Control.CastSpell(HK_E, eBestTarget)
	end
end

function zgAurora:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end

	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local qReady = Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "AuroraQ"
	local eReady = Menu.Clear.JungleClear.E:Value() and IsReady(_E)
	local qBestTarget, qMaxHits = nil, 0
	local eBestTarget, eMaxHits = nil, 0

	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.pos2D.onScreen then
			if qReady then
				local _, _, qCollision = GGPrediction:GetCollision(myHero.pos, monster.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if qCollision > qMaxHits then
					qMaxHits = qCollision
					qBestTarget = monster
				end
			end
			if eReady then
				local _, _, eCollision = GGPrediction:GetCollision(myHero.pos, monster.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
				if eCollision > eMaxHits then
					eMaxHits = eCollision
					eBestTarget = monster
				end
			end
		end
	end

	if qBestTarget and qMaxHits >= 1 then
		Control.CastSpell(HK_Q, qBestTarget)
	end
	if eBestTarget and eMaxHits >= 1 then
		Control.CastSpell(HK_E, eBestTarget)
	end
end

function zgAurora:CastQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
	end
end

function zgAurora:CastE(unit)
	local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
	EPrediction:GetPrediction(unit, myHero)
	if EPrediction:CanHit(3) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function zgAurora:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgAurora()