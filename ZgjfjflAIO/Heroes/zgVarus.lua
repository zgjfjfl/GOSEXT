local Version = 1.06

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6 }
local ItemKeys = { HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6 }

class "zgVarus"

function zgVarus:__init()		 
	print("Zgjfjfl AIO - Varus Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 70, Range = 925, Speed = 1900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 270, Range = 1060, Speed = 1750, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 120, Range = 1250, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.QTick = 0
	self.QCharging = false
	self.WActive = false
end

function zgVarus:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "HG", name = "Use Hextech Gunblade", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "Efirst", name = "Combo E First (Q First if Disabled)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qstacks", name = "Use Q|when W stacks more than", value = 3, min = 0, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "QstacksOut", name = "Use Q|Out of AA range|when W stacks more than", value = 2, min = 0, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "Qkill", name = "Use Q|to kill (when damage is lethal)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Whp", name = "Use W|when enemy %hp less than", value = 50, min = 0, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Estacks", name = "Use E|when W stacks more than", value = 3, min = 0, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "EstacksOut", name = "Use E|Out of AA range|when W stacks more than", value = 2, min = 0, max = 3, step = 1})
	Menu.Combo:MenuElement({id = "Ekill", name = "Use E|to kill (when damage is lethal)", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Eearly", name = "Use E early|when Q ready (ignore W stacks)", toggle = true, value = false})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "RCount", name = "Use R|when target nearly X enemies", value = 2, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "RSm", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Whp", name = "Use W|when enemy %hp less than", value = 50, min = 0, max = 100, step = 5})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgVarus:Tick()
	self.WActive = HaveBuff(myHero, "varuswempowered")
	if myHero.activeSpell.isCharging then
		if self.QCharging == false then
			self.QTick = GetTickCount()
			self.QCharging = true
		end
		_G.SDK.Orbwalker:SetAttack(false)
		self.QSpell.Range = math.min(925 + 675 / 1.5 * ((GetTickCount() - self.QTick) / 1000), 1650)
		self:HandleQCharging()
		return
	else
		self.QCharging = false
		_G.SDK.Orbwalker:SetAttack(true)
		self.QSpell.Range = 925
	end

	if Control.IsKeyDown(HK_Q) == true and Game.CanUseSpell(_Q) ~= 0 then
		Control.KeyUp(HK_Q)
	end

	if ShouldWait() or IsCasting() then return end

	if Menu.Combo.RSm:Value() then
		self:CastR()
	end

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgVarus:CastR()
	if IsReady(_R) then
		local target = GetTarget(self.RSpell.Range - 100)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_R, target)
		end
	end
end

function zgVarus:HandleQCharging()
	if GetMode() ~= "Combo" and GetMode() ~= "Harass" then return end
	if not self.QCharging then return end
	local target = nil
	local killable, wStacked = {}, {}
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1650)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			local qDmg = self:GetQDmg(enemy, self.WActive)
			local wDmg = self:GetWDmg(enemy)
			if enemy.distance > 925 then wDmg = wDmg * 1.5 end
			if (qDmg + wDmg) > (enemy.health + enemy.hpRegen * 2) then
				table.insert(killable, enemy)
			elseif HaveBuff(enemy, "varuswdebuff") then
				table.insert(wStacked, enemy)
			end
		end
	end
	target = (#killable > 0 and GetTarget(killable)) or
			(#wStacked > 0 and GetTarget(wStacked)) or
			GetTarget(enemies)
	if IsValid(target) and target.pos2D.onScreen then	
		if target.distance <= 925 or (GetTickCount() - self.QTick) / 1000 > 1.25 then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgVarus:Combo()
	-- Use Hextech Gunblade if available and in combo
	if Menu.Combo.HG:Value() then
		for i = 1, #ItemSlots do
			local slot = ItemSlots[i]
			local item = myHero:GetItemData(slot)
			if item and item.itemID == 3146 and myHero:GetSpellData(slot).currentCd == 0 then
				local target = GetTarget(700)
				if IsValid(target) and target.pos:ToScreen().onScreen then
					Control.CastSpell(ItemKeys[i], target.pos)
					break -- Exit loop after using the item
				end
			end
		end
	end

	-- R as an opener
	if Menu.Combo.R:Value() and IsReady(_R) and (IsReady(_E) or IsReady(_Q)) then
		local target = GetTarget(self.RSpell.Range - 100)
		if IsValid(target) and target.pos:ToScreen().onScreen and GetEnemyCount(400, target.pos) >= Menu.Combo.RCount:Value() then
			self:CastGGPred(HK_R, target)
		end
	end

	-- Get the main target to decide spell priority
	local priorityTarget = GetTarget(1650)
	if not IsValid(priorityTarget) then return end -- Exit if no valid target

	-- Define the logic for casting Q as a local function to avoid code duplication
	local castQLogic = function()
		if Menu.Combo.Q:Value() and self.QCharging == false and IsReady(_Q) and lastE + 1000 < GetTickCount() then
			local canusew = Game.CanUseSpell(_W) == 0
			for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(1650)) do
				if IsValid(target) and target.pos2D.onScreen then
					local qDmg = self:GetQDmg(target)
					local wDmg = self:GetWDmg(target)
					if target.distance > 925 then wDmg = wDmg * 1.5 end
					local buff, buffData = GetBuffData(target, "varuswdebuff")
					local canAAKill = _G.SDK.Data:IsInAutoAttackRange(myHero, target) and target.health <= _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
					local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)
					local qStacks = inAARange and Menu.Combo.Qstacks:Value() or Menu.Combo.QstacksOut:Value()
					if not canAAKill and (
						qStacks == 0
						or myHero:GetSpellData(_W).level == 0
						or (Menu.Combo.Qkill:Value() and (qDmg + wDmg) > (target.health + target.shieldAD + target.hpRegen * 2))
						or (buff and buffData.count >= qStacks)
					) then
						if canusew and Menu.Combo.W:Value() and (target.health / target.maxHealth * 100) < Menu.Combo.Whp:Value() then
							Control.KeyDown(HK_W)
							Control.KeyUp(HK_W)
						end
						Control.KeyDown(HK_Q)
						return true -- Indicate that we started casting Q
					end
				end
			end
		end
		return false
	end

	-- Define the logic for casting E as a local function to avoid code duplication
	local castELogic = function(qAlsoReady)
		if Menu.Combo.E:Value() and IsReady(_E) and lastQ + 1000 < GetTickCount() then
			local orbTarget = _G.SDK.Orbwalker:GetTarget()
			local targets = orbTarget and {orbTarget} or _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
			for _, target in ipairs(targets) do
				if IsValid(target) and target.pos2D.onScreen then
					local eDmg = self:GetEDmg(target)
					local wDmg = self:GetWDmg(target)
					local buff, buffData = GetBuffData(target, "varuswdebuff")
					local canAAKill = _G.SDK.Data:IsInAutoAttackRange(myHero, target) and target.health <= _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
					local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)
					local eStacks = inAARange and Menu.Combo.Estacks:Value() or Menu.Combo.EstacksOut:Value()
					local canUseEarly = qAlsoReady and IsReady(_Q) and Menu.Combo.Eearly:Value()
					if not canAAKill and (
						canUseEarly
						or eStacks == 0
						or myHero:GetSpellData(_W).level == 0
						or (Menu.Combo.Ekill:Value() and (eDmg + wDmg) > (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 2))
						or (buff and buffData.count >= eStacks)
					) then
						self:CastGGPred(HK_E, target)
						return true -- Indicate that we cast E
					end
				end
			end
		end
		return false
	end

	-- NEW LOGIC: Prioritize based on AA range first
	--local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, priorityTarget)

	--if inAARange then
		-- In AA range, always prioritize Q, then E
	if lastR + 750 < GetTickCount() then
		if Menu.Combo.Efirst:Value() then
			-- E priority mode
			if castELogic(IsReady(_Q) and Menu.Combo.Q:Value()) then return end
			if castQLogic() then return end
		else
			-- Q priority mode (default)
			if castQLogic() then return end
			if not IsReady(_Q) or not Menu.Combo.Q:Value() then
				if castELogic(false) then return end
			else
				-- Q is ready, try E early if enabled
				if castELogic(true) then return end
			end
		end
	end
	--else
		-- Outside AA range, use stack-based priority
		-- local wStacks = 0
		-- local hasBuff, buffData = GetBuffData(priorityTarget, "varuswdebuff")
		-- if hasBuff then
			-- wStacks = buffData.count
		-- end

		-- if wStacks >= 2 then
			-- -- 3+ stacks, prioritize Q, then E
			-- if castQLogic() then return end
			-- if castELogic() then return end
		-- else
			-- < 3 stacks, prioritize E, then Q
	-- 		if castELogic() then return end
	-- 		if castQLogic() then return end
	-- 	--end
	-- end
end

function zgVarus:Harass()
	-- Skip if R was used recently
	if lastR + 750 > GetTickCount() then return end
	
	if Menu.Harass.E:Value() and IsReady(_E) and lastQ + 1000 < GetTickCount() then
		local target = nil
		local killable, wStacked = {}, {}
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for _, enemy in ipairs(enemies) do
			if IsValid(enemy) and enemy.pos2D.onScreen then
				local eDmg = self:GetEDmg(enemy)
				local wDmg = self:GetWDmg(enemy)
				if (eDmg + wDmg) > enemy.health then
					table.insert(killable, enemy)
				elseif HaveBuff(enemy, "varuswdebuff") then
					table.insert(wStacked, enemy)
				end
			end
		end
		target = (#killable > 0 and GetTarget(killable)) or
				(#wStacked > 0 and GetTarget(wStacked)) or
				GetTarget(enemies)
		if IsValid(target) then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Harass.Q:Value() then
		if self.QCharging == false then
			if IsReady(_Q) and lastE + 1000 < GetTickCount() then
				local canusew = Game.CanUseSpell(_W) == 0
				local enemy = GetTarget(1650)
				if IsValid(enemy) and enemy.pos2D.onScreen then
					local buff, buffData = GetBuffData(enemy, "varuswdebuff")
					if canusew and Menu.Harass.W:Value() and (enemy.health / enemy.maxHealth * 100) < Menu.Harass.Whp:Value() then
						Control.KeyDown(HK_W)
						Control.KeyUp(HK_W)
					end
					Control.KeyDown(HK_Q)
				end
			end
		end
	end
end

function zgVarus:GetQDmg(target, wActive)
	local qlvl = myHero:GetSpellData(_Q).level
	if qlvl == 0 then return 0 end
	local wlvl = myHero:GetSpellData(_W).level
	local missingHp = target.maxHealth - target.health
	local Dmg = ({80, 150, 220, 290, 360})[qlvl] + 1.2 * myHero.bonusDamage
	local t = wlvl > 0 and ({9, 12, 15, 18, 21})[wlvl] or 0
	local canUseW = Game.CanUseSpell(_W) == 0 and (100 * target.health / target.maxHealth) < Menu.Combo.Whp:Value()
	local useW = wActive ~= nil and wActive or canUseW
	if useW then
		local qDmg = (target.distance <= 925 and Dmg / 1.5 + t / 1.5 / 100 * missingHp) or (Dmg + t / 100 * missingHp)
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
	else
		local qDmg = (target.distance <= 925 and Dmg / 1.5) or Dmg
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg)
	end
end

function zgVarus:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local buff, buffData = GetBuffData(target, "varuswdebuff")
	if level > 0 and buff then
		local WDmg = (({3, 3.5, 4, 4.5, 5})[level]/100 + 0.015 * (myHero.ap/100)) * target.maxHealth
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg * buffData.count)
	else
		return 0
	end
end

function zgVarus:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local EDmg = ({60, 90, 120, 150, 180})[level] + 0.9 * myHero.bonusDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, EDmg)
end

function zgVarus:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
			lastQ = GetTickCount()
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
			lastE = GetTickCount()
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
			lastR = GetTickCount()
		end
	end
end

function zgVarus:Draw()
	if myHero.dead then return end

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

zgVarus()
