local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgYunara"

function zgYunara:__init()
	print("Zgjfjfl AIO - Yunara Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.45, Radius = 60, Range = 1150, Speed = 2150, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.W2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 90, Range = 1150, Speed = math.huge, Collision = false}
end

function zgYunara:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
 
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WLogic", name = "W Usage Logic", value = 1, drop = {"Smart", "Always"}})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "WLogic", name = "W Usage Logic", value = 1, drop = {"Smart", "Always"}})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "W", name = "Use W| LastHit Not In AA Range", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "AntiGapcloser", name = "AntiGapcloser"})
	Menu.AntiGapcloser:MenuElement({id = "E2", name = "Auto E2 AntiGapcloser", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal(not in aa range)", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function zgYunara:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
	if IsValid(target) and (IsReady(_Q) and myHero.hudAmmo == 8) then
		if target.type == Obj_AI_Hero then
			if GetMode() == "Combo" and Menu.Combo.Q:Value() or (GetMode() == "Harass" and Menu.Harass.Q:Value()--[[ and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100]]) then
				Control.CastSpell(HK_Q)
			end
		elseif target.type == Obj_AI_Minion then
			if GetMode() == "LaneClear" and Menu.Clear.SpellFarm:Value() then
				if target.team ~= 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.LaneClear.Q:Value() then
					if GetMinionCount(300, target.pos) >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q)
					end
				elseif target.team == 300 and --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.JungleClear.Q:Value() then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgYunara:Tick()
	if ShouldWait() then
		return
	end
	self.WSpell.Delay = math.max(0.225, 0.45 - 0.225 * (myHero.attackSpeed - 1))
	self.W2Spell.Delay = math.max(0.45, 0.6 - 0.45 * (myHero.attackSpeed - 1))
	self:AntiGapcloser()
	if IsCasting() then return end
	self:KillSteal()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LastHitW()
		self:FarmHarass()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHitW()
	end
end

function zgYunara:KillSteal()
	if Menu.KillSteal.W:Value() and IsReady(_W) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1100)
		for i, target in ipairs(enemies) do
			if IsValid(target) and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
				local WDmg = self:GetWDmg(target)
				if WDmg >= target.health + target.hpRegen + target.shieldAD then
					self:CastW(target)
				end
			end
		end
	end
end

function zgYunara:CastW(target)
	local wName = myHero:GetSpellData(_W).name
	local spell =  wName == "YunaraW2" and self.W2Spell or self.WSpell
	local WPrediction = GGPrediction:SpellPrediction(spell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgYunara:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(1100)
		if IsValid(target) and target.pos2D.onScreen then
			local wLogic = Menu.Combo.WLogic:Value()
			if wLogic == 1 and self:CanUseW() then
				if not HaveBuff(myHero, "YunaraQ") or not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
					self:CastW(target)
				end
			elseif wLogic == 2 then
				self:CastW(target)
			end
		end
	end
end

function zgYunara:Harass()
	if IsUnderTurret(myHero) then return end
	if Menu.Harass.W:Value() and IsReady(_W) --[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 ]]then
		local target = GetTarget(1100)
		if IsValid(target) and target.pos2D.onScreen then
			local wLogic = Menu.Harass.WLogic:Value()
			if wLogic == 1 and self:CanUseW() then
				if not HaveBuff(myHero, "YunaraQ") or not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
					self:CastW(target)
				end
			elseif wLogic == 2 then
				self:CastW(target)
			end
		end
	end
end

function zgYunara:AntiGapcloser()
	if Menu.AntiGapcloser.E2:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "YunaraE2" then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 300 and IsFacingMe(target) then
					local castPos = myHero.pos + (myHero.pos - target.pos):Normalized() * 450
					if castPos:To2D().onScreen then
						Control.CastSpell(HK_E, castPos)
					end
				end
			end	
		end
	end
end

function zgYunara:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgYunara:CanUseW()
	local QData = myHero:GetSpellData(_Q)
	local WData = myHero:GetSpellData(_W)
	local EData = myHero:GetSpellData(_E)
	local RData = myHero:GetSpellData(_R)
	if WData.name == "YunaraW" and 
		myHero.mana < (QData.mana + WData.mana + (EData.currentCd == 0 and EData.mana or 0) + (RData.currentCd == 0 and RData.mana or 0))
	then
		return false
	end
	return true
end

function zgYunara:LastHitW()
	if Menu.LastHit.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "YunaraW" then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1150)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 then
				local Wdmg = self:GetWDmg(minion)
				if minion.health <= Wdmg and not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.WSpell.Speed, self.WSpell.Delay, self.WSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
					if collisionCount == 0 then
						Control.CastSpell(HK_W, minion)
						return
					end
				end
			end
		end
	end
end

function zgYunara:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(600)
			table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team == 300 then
					if not HaveBuff(myHero, "YunaraQ") or not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgYunara:GetWDmg(target)
	local wlevel = myHero:GetSpellData(_W).level
	local rlevel = myHero:GetSpellData(_R).level
	local wName = myHero:GetSpellData(_W).name
	if wlevel > 0 then
		if wName == "YunaraW2" then
			local WDmg = ({160, 320, 480})[rlevel] + 1.20 * myHero.bonusDamage + 0.75 * myHero.ap
			return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
		else
			local WDmg = ({55, 95, 135, 170, 215})[wlevel] + 0.85 * myHero.bonusDamage + 0.5 * myHero.ap
			return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
		end
	else
		return 0
	end
end

function zgYunara:Draw()
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

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, 1150, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgYunara()