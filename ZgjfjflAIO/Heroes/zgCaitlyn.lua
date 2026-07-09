local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgCaitlyn"

function zgCaitlyn:__init()
	print("Zgjfjfl AIO - Caitlyn Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.625, Radius = 60, Range = 1240, Speed = 2200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.25, Radius = 15, Range = 800, Speed = math.huge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.15, Radius = 70, Range = 750, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.375, Radius = 40, Range = 3500, Speed = 3200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgCaitlyn:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QSlow", name = "Use Q| Slow", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QAoe", name = "Use Q| Aoe", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QRange", name = "Use Q| Min Range >= x", value = 750, min = 500, max = 1000, step = 50})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WCount", name = "Use W| Keep Ammo Count == x", value = 1, min = 1, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "Use E| Max Range <= x", value = 750, min = 250, max = 750, step = 50})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RSafe", name = "Use R| Safe Check?", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RRange", name = "Use R| Min Range >= x", value = 900, min = 500, max = 1500, step = 100})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 4, min = 1, max = 5, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E Dash to Mouse", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "E", name = "E + AA KillSteal", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qcc", name = "Auto Q on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Wcc", name = "Auto W on CC", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Wtp", name = "Auto W on TP", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "Wgap", name = "Auto W Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "EgapRange", name = "AntiGap E Range(dash endPos form self < X)", value = 300, min = 0, max = 600, step = 50})
	Menu.Misc:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "EQKey", name = "One Key EQ target(In E Range)", key = string.byte("G")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Rmin", name = "Draw R Range on minimap", toggle = true, value = false})
end

function zgCaitlyn:Tick()
	if ShouldWait() then
		return
	end

	if myHero.activeSpell.valid and (myHero.activeSpell.name == "CaitlynQ" or myHero.activeSpell.name == "CaitlynR") then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() or myHero.activeSpell.name == "CaitlynR" then return end
	if Menu.Misc.EQKey:Value() then
		self:OneKeyEQ()
	end
	if Menu.Misc.Rsm:Value() and IsReady(_R) then
		self:OneKeyCastR()
	end
	self:AntiGapcloser()
	self:Auto()
	self:KillSteal()

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

_G.CTRLCait = true
_G.lastEProc = 0
_G.lastWProc = {}
local currentBuffTarget = nil

function zgCaitlyn:OnPreAttack(args)
	local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(1300)
	local Buff = _G.SDK.BuffManager
	local bestTarget = nil
	local shortestBuffTime = math.huge
	for i, enemy in pairs(heroes) do
		if enemy then
			if Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker") and _G.lastEProc + 3 < Game.Timer() then
				local buffTime = Buff:GetBuffDuration(enemy, "eternals_caitlyneheadshottracker")
				if buffTime < shortestBuffTime then
					bestTarget = enemy
					shortestBuffTime = buffTime
					currentBuffTarget = {target = enemy, buffType = "E"}
				end
			end
			
			if Buff:HasBuff(enemy, "caitlynwsight") and (_G.lastWProc[enemy.networkID] == nil or _G.lastWProc[enemy.networkID] + 3 < Game.Timer()) then
				local buffTime = Buff:GetBuffDuration(enemy, "caitlynwsight")
				if buffTime < shortestBuffTime then
					bestTarget = enemy
					shortestBuffTime = buffTime
					currentBuffTarget = {target = enemy, buffType = "W"}
				end
			end
		end
	end
	if bestTarget then
		args.Target = bestTarget
	end
end

function zgCaitlyn:OnPostAttack()
	if currentBuffTarget and currentBuffTarget.target then
		local target = currentBuffTarget.target
		if currentBuffTarget.buffType == "E" then
			_G.lastEProc = Game.Timer()
		elseif currentBuffTarget.buffType == "W" then
			_G.lastWProc[target.networkID] = Game.Timer()
		end
		currentBuffTarget = nil
	end
end

function zgCaitlyn:OneKeyCastR()
	local Rtarget = GetTarget(self.RSpell.Range)
	if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
		Control.CastSpell(HK_R, Rtarget)
	end
end

local lastWcc = 0
local lastWgap = 0
local lastWtp = 0
local lastWtfr = 0
-- Separate timestamps for different WCC scenarios
local lastWInvulnerable = 0
local lastWLissandraR = 0
local lastWMeditate = 0
local lastWChronoRevive = 0
local lastWGA = 0
local lastParticleCheckTime = 0
local particleCheckInterval = 1.0
local slots = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}

function zgCaitlyn:AntiGapcloser()
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				local endPos = Vector(target.pathing.endPos)
				if myHero.pos:DistanceTo(endPos) < Menu.Misc.EgapRange:Value() and IsFacingMe(target) then
					self:CastGGPred(HK_E, target)
				end
			end	
		end
	elseif Menu.Misc.Wgap:Value() and IsReady(_W) and lastWgap + 3000 < GetTickCount() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_W, target.pathing.endPos)
					lastWgap = GetTickCount()
				end
			end	
		end
	end
end

function zgCaitlyn:Auto()
	if Menu.Misc.Qcc:Value() and IsReady(_Q) and GetMode() ~= "Combo" and GetMode() ~= "Harass" then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pos2D.onScreen and IsHardCC(target) then
				if not IsReady(_W) or myHero.pos:DistanceTo(target.pos) > self.WSpell.Range then
					self:CastGGPred(HK_Q, target)
				end
			end
		end
	end
	
	-- WCC for various scenarios with independent timing
	if Menu.Misc.Wcc:Value() and IsReady(_W) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= self.WSpell.Range then
				local isKillableByAA = _G.SDK.Data:IsInAutoAttackRange(myHero, target) and (target.health + target.shieldAD) <= _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
				
				-- HardCC targets (CC)
				if (not HaveBuff(target, "caitlynwsight") and GetHardCCDuration(target) > 0.5) then
					if not isKillableByAA and lastWcc + 3000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWcc = GetTickCount()
					end
				end
				
				-- General invulnerable targets
				if IsInvulnerable(target) then
					if lastWInvulnerable + 2500 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWInvulnerable = GetTickCount()
					end
				end
				
				-- Lissandra R targets
				if HaveBuff(target, "LissandraRSelf") then
					if lastWLissandraR + 2500 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWLissandraR = GetTickCount()
					end
				end
				
				-- Meditate targets (Master Yi)
				if HaveBuff(target, "Meditate") then
					if not isKillableByAA and lastWMeditate + 4000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWMeditate = GetTickCount()
					end
				end
				
				-- Chrono Revive targets (Zilean R)
				if HaveBuff(target, "ChronoRevive") then
					if lastWChronoRevive + 3000 < GetTickCount() then
						Control.CastSpell(HK_W, target)
						lastWChronoRevive = GetTickCount()
					end
				end
				
				-- Guardian Angel targets
				for j, slot in ipairs(slots) do
					local Data = target:GetSpellData(slot)
					if Data.name == "GuardianAngel" and Data.currentCd == 0 and not target.alive then
						if lastWGA + 4000 < GetTickCount() then
							Control.CastSpell(HK_W, target)
							lastWGA = GetTickCount()
						end
					end
				end
			end
		end
	end

	if Menu.Misc.Wtp:Value() and IsReady(_W) then
		local now = GetTickCount() / 1000
		if now - lastParticleCheckTime > particleCheckInterval then
			lastParticleCheckTime = now
			for i = Game.ParticleCount(), 1, -1 do
				local par = Game.Particle(i)
				if par and par.pos:DistanceTo(myHero.pos) <= self.WSpell.Range then
					local name = par.name:lower()
					if name:find("teledash_end") and name:find("wardenemy") and lastWtp + 8000 < GetTickCount() then -- TP
						Control.CastSpell(HK_W, par)
						lastWtp = GetTickCount()
					end
					if name:find("gatemarker_red") and lastWtfr + 3000 < GetTickCount() then -- TF-R
						Control.CastSpell(HK_W, par)
						lastWtfr = GetTickCount()
					end
						-- (name:find("viego") and name:find("p_spiritshader_inworld_enemy")) -- viego passive
						-- (name:find("yone") and name:find("e_invulnerable_buf")) -- yone E
				end
			end
		end
	end
end

function zgCaitlyn:KillSteal()
	if Menu.KillSteal.Q:Value() and IsReady(_Q) and GetEnemyCount(400, myHero.pos) == 0 then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < self:GetQDmg(target) then
				if _G.SDK.Data:IsInAutoAttackRange(myHero, target) and target.health <= _G.SDK.Damage:GetAutoAttackDamage(myHero, target) then
					return
				end
				self:CastGGPred(HK_Q, target)
			end
		end
	end
	if Menu.KillSteal.E:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < (self:GetEDmg(target) + _G.SDK.Damage:GetAutoAttackDamage(myHero, target)) then
				self:CastGGPred(HK_E, target)
			end
		end
	end
end

function zgCaitlyn:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) <= Menu.Combo.ERange:Value() then
			local eToPos = myHero.pos:Extended(target.pos, -400)
			if GetEnemyCount(700, eToPos) < 2 then
				if Menu.Combo.Q:Value() and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
					self:CastEQ(target)
				else
					self:CastGGPred(HK_E, target)
				end
			end
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) and GetEnemyCount(400, myHero.pos) == 0 then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and target.pos2D.onScreen and myHero.pos:DistanceTo(target.pos) > Menu.Combo.QRange:Value() then
			if Menu.Combo.QSlow:Value() and IsSlow(target) then
				self:CastGGPred(HK_Q, target)
			end
			if Menu.Combo.QAoe:Value() and GetEnemyCount(720 + myHero.boundingRadius, myHero.pos) == 0 then
				CastSpellAOE(HK_Q, self.QSpell, 2, myHero, target)
			end
		end
	end

	if Menu.Combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).ammo > Menu.Combo.WCount:Value() then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_W, target)
		end
	end

	if Menu.Combo.R:Value() and IsReady(_R) and lastQ + 1500 < GetTickCount() and lastE + 1500 < GetTickCount() then
		local Rtarget = GetTarget(self.RSpell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			if Menu.Combo.RSafe:Value() and (IsUnderTurret(myHero) or GetEnemyCount(Menu.Combo.RRange:Value(), myHero.pos) > 0) then
				return
			end
			if myHero.pos:DistanceTo(Rtarget.pos) < Menu.Combo.RRange:Value() then
				return
			end
			if (Rtarget.health + Rtarget.shieldAD + Rtarget.hpRegen * 3) > self:GetRDmg(Rtarget) then
				return
			end
			if GetEnemyCount(400, Rtarget.pos) > 1 then
				return
			end
			Control.CastSpell(HK_R, Rtarget)
		end
	end
end

function zgCaitlyn:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			local target = GetTarget(self.QSpell.Range)
			if IsValid(target) and target.pos2D.onScreen then
				self:CastGGPred(HK_Q, target)
			end
		end
	-- end
end

function zgCaitlyn:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			local bestTarget = nil
			local maxCollisions = 0
			
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount > maxCollisions then
						maxCollisions = collisionCount
						bestTarget = minion
					end
				end
			end
			
			if bestTarget and maxCollisions >= Menu.Clear.LaneClear.QCount:Value() then
				Control.CastSpell(HK_Q, bestTarget)
				lastQ = GetTickCount()
			end
		end
	end
end

function zgCaitlyn:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
					Control.CastSpell(HK_Q, minion)
					lastQ = GetTickCount()
				end
			end
		end
	end
end

function zgCaitlyn:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		local castPos = myHero.pos - (mousePos - myHero.pos):Normalized() * 200
		if castPos:To2D().onScreen then
			Control.CastSpell(HK_E, castPos)
			lastE = GetTickCount()
		end
	end
end

function zgCaitlyn:OneKeyEQ()
	if IsReady(_E) and IsReady(_Q) and myHero.mana > myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.ESpell.Speed, self.ESpell.Delay, self.ESpell.Radius, self.ESpell.CollisionTypes, target.networkID)
			if collisionCount == 0 then
				self:CastEQ(target)
			end
		end
	end
end

function zgCaitlyn:CastEQ(target)
	local Prediction = GGPrediction:SpellPrediction(self.ESpell)
	Prediction:GetPrediction(target, myHero)
	if Prediction:CanHit(3) then
		Control.CastSpell({HK_E, HK_Q}, Prediction.CastPosition)
	end
end

function zgCaitlyn:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) and lastW + 3000 < GetTickCount() then
			local isKillableByAA = _G.SDK.Data:IsInAutoAttackRange(myHero, unit) and (unit.health + unit.shieldAD) <= _G.SDK.Damage:GetAutoAttackDamage(myHero, unit)
			local finalCastPos = nil
			if IsFacingMe(unit) then
				if unit.range < 300 and myHero.pos:DistanceTo(unit.pos) < _G.SDK.Data:GetAutoAttackRange(unit, myHero) + 100 then
					finalCastPos = myHero.pos
				else
					finalCastPos = WPrediction.CastPosition
				end
			else
				local castPos = WPrediction.CastPosition + (unit.pos - myHero.pos):Normalized() * 100
				if myHero.pos:DistanceTo(castPos) <= self.WSpell.Range then
					finalCastPos = castPos
				end
			end
			if finalCastPos and not isKillableByAA and not self:IsTrapParticleNearby(finalCastPos, 200) then
				Control.CastSpell(HK_W, finalCastPos)
				lastW = GetTickCount()
			end
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end	
	end
end

function zgCaitlyn:IsTrapParticleNearby(castPos, radius)
	for i = Game.ParticleCount(), 1, -1 do
		local par = Game.Particle(i)
		if par and par.pos:DistanceTo(castPos) < radius then
			local pName = par.name:lower()
			if pName:find("caitlyn") and (pName:find("trap_idle_ally") or pName:find("trap_idle_green")) then
				return true
			end
		end
	end
	return false 
end

function zgCaitlyn:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({50, 90, 130, 170, 210})[level] + ({1.25, 1.45, 1.65, 1.85, 2.05})[level] * myHero.totalDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgCaitlyn:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local mod = HasItem(myHero, 3031) and 0.39 or 0.3
	local RDmg = (({300, 475, 650})[level] + 1.0 * myHero.bonusDamage) * (1 + mod * myHero.critChance)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, RDmg)
end

function zgCaitlyn:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({80, 130, 180, 230, 280})[level] + 0.8 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgCaitlyn:Draw()
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
	if Menu.Draw.Rmin:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, self.RSpell.Range, 1, Draw.Color(200, 14, 194, 255))
	end
end

zgCaitlyn()
