local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgJayce"

function zgJayce:__init()
	print("Zgjfjfl AIO - Jayce Loaded")
	self:LoadMenu()	
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("WndMsg", function(...) self:OnWndMsg(...) end)
	-- _G.SDK.Spell:OnSpellCast(function(...) self:OnSpellCast(...) end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.Q1Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1050, Speed = 1450, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.Q1extSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 1600, Speed = 2350, Collision = false}
	self.Q1extColSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 1600, Speed = 2350, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.Q2Spell = {Range = 600}
	self.W2Spell = {Radius = 350}
	self.E1Spell = {Range = 650}
	self.E2Spell = {Delay = 0.25, Range = 240}
end

function zgJayce:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Q", name = "Q Config"})
	Menu.Q:MenuElement({id = "Qr", name = "Use Q range", toggle = true, value = true})
	Menu.Q:MenuElement({id = "Qm", name = "Use Q melee", toggle = true, value = true})
	Menu.Q:MenuElement({id = "QEsplash", name = "Q + E splash minion damage", toggle = true, value = true})
	Menu.Q:MenuElement({id = "useQE", name = "Semi-manual Q + E Target near mouse", key = string.byte("T")})
	
	Menu:MenuElement({type = MENU, id = "W", name = "W Config"})
	Menu.W:MenuElement({id = "Wr", name = "Use W range", toggle = true, value = true})
	Menu.W:MenuElement({id = "Wm", name = "Use W melee", toggle = true, value = true})
	Menu.W:MenuElement({id = "Wmove", name = "Disable move if W range active", toggle = true, value = false})
	
	Menu:MenuElement({type = MENU, id = "E", name = "E Config"})
	Menu.E:MenuElement({id = "Er", name = "Use E range (Q + E)", toggle = true, value = true})
	Menu.E:MenuElement({id = "Esm", name = "Use E When Manual RangeQ", toggle = true, value = false})
	Menu.E:MenuElement({id = "Em", name = "Use E melee", toggle = true, value = true})
	Menu.E:MenuElement({id = "Eks", name = "E melee ks only", toggle = true, value = false})
	Menu.E:MenuElement({id = "gapE", name = "Gapcloser R + E", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "R", name = "R Config"})
	Menu.R:MenuElement({id = "Rr", name = "Use R range", toggle = true, value = true})
	Menu.R:MenuElement({id = "Rm", name = "Use R melee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	-- Menu.Harass:MenuElement({id = "Mana", name = "Harass Mana", value = 80, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "Enable", name = "Flee Mode(A)", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Farm", name = "Farm"})
	Menu.Farm:MenuElement({id = "spellFarm", name = "Spells Farm Key toggle", toggle = true, value = false, key = string.byte("N")})
	Menu.Farm:MenuElement({id = "farmQ", name = "Lane clear Q + E range", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "farmW", name = "Lane clear W range && melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "LCminions", name = "Lane clear minimum minions", value = 3, min = 0, max = 10, step = 1})
	-- Menu.Farm:MenuElement({id = "Mana", name = "LaneClear Mana", value = 50, min = 0, max = 100, step = 5})
	Menu.Farm:MenuElement({id = "jungleC", name = "Jungle Clear Key toggle", toggle = true, value = false, key = string.byte("M")})
	Menu.Farm:MenuElement({id = "jungleQ", name = "Jungle clear Q", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleW", name = "Jungle clear W", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleE", name = "Jungle clear E", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleR", name = "Jungle clear R", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleQm", name = "Jungle clear Q melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleWm", name = "Jungle clear W melee", toggle = true, value = true})
	Menu.Farm:MenuElement({id = "jungleEm", name = "Jungle clear E melee", toggle = true, value = true})


	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawJungle", name = "Draw Jungle Clear Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "showcd", name = "Show cooldown", toggle = true, value = false})
end

function SetPlus(valus)
	if valus < 0 then
		return 0
	else
		return valus
	end
end

local Q1mana, W1mana, E1mana, Q2mana, W2mana, E2mana= 0, 0, 0, 0, 0, 0
local Q1cdt, W1cdt, E1cdt, Q2cdt, W2cdt, E2cdt= 0, 0, 0, 0, 0, 0
local Q1cd, W1cd, E1cd, Q2cd, W2cd, E2cd= 0, 0, 0, 0, 0, 0
function zgJayce:SetValue()
	if self:IsRange() then
		Q1cdt = myHero:GetSpellData(_Q).castTime
		W1cdt = myHero:GetSpellData(_W).castTime
		E1cdt = myHero:GetSpellData(_E).castTime
		
		Q1mana = myHero:GetSpellData(_Q).mana
		W1mana = myHero:GetSpellData(_W).mana
		E1mana = myHero:GetSpellData(_E).mana
	else
		Q2cdt = myHero:GetSpellData(_Q).castTime
		W2cdt = myHero:GetSpellData(_W).castTime
		E2cdt = myHero:GetSpellData(_E).castTime

		Q2mana = myHero:GetSpellData(_Q).mana
		W2mana = myHero:GetSpellData(_W).mana
		E2mana = myHero:GetSpellData(_E).mana
	end
	Q1cd = SetPlus(Q1cdt - Game.Timer())
	W1cd = SetPlus(W1cdt - Game.Timer())
	E1cd = SetPlus(E1cdt - Game.Timer())
	Q2cd = SetPlus(Q2cdt - Game.Timer())
	W2cd = SetPlus(W2cdt - Game.Timer())
	E2cd = SetPlus(E2cdt - Game.Timer())
end

local isQmanualCast = false
local QmanualTimer = nil
function zgJayce:OnWndMsg(msg, wParam)
	if self:IsRange() and Game.CanUseSpell(_Q) == 0 then
		if msg == KEY_DOWN and wParam == HK_Q then
		-- print('q')
			isQmanualCast = true
			QmanualTimer = GetTickCount()
		end
	end
end

-- function zgJayce:OnSpellCast(spell)
	-- if not self:IsRange() then
		-- if spell == _Q then
			-- if IsReady(_W) and Menu.W.Wm:Value() and myHero.mana > 80 then
				-- Control.CastSpell(HK_W)
			-- end
		-- end
	-- end	
-- end

function zgJayce:OnPreAttack(args)
	if IsReady(_W) and Menu.W.Wr:Value() and self:IsRange() and args.Target.type == Obj_AI_Hero then
		if GetMode() == "Combo" then
			Control.CastSpell(HK_W)
		else
			if args.Target.pos:DistanceTo(myHero.pos) < 500 then
				Control.CastSpell(HK_W)
			end
		end
	end
end

local Etick = 0
function zgJayce:Tick()
	if ShouldWait() then
		return
	end
	if QmanualTimer and GetTickCount() > QmanualTimer + 1000 then
		isQmanualCast = false
		QmanualTimer = nil
	end

	if Menu.E.Esm:Value() and isQmanualCast == true or isQmanualCast == false then
		if myHero.activeSpell.name == "JayceShockBlast" then
			Etick = GetTickCount()
			if self:IsRange() and IsReady(_E) and Menu.E.Er:Value() and GetTickCount() < Etick + 250 + Game.Latency() then
				local EcastPos = Vector(myHero.pos):Extended(Vector(myHero.activeSpell.placementPos), 150 + Game.Latency()/2)
				Control.CastSpell(HK_E, EcastPos)
			end
		end	
	end

	self:SetValue()
	self:Gapcloser()
	if GetMode() == "Flee" and Menu.Flee.Enable:Value() then
		self:Flee()
	end

	if IsCasting() then return end

	if self:IsRange() then
		if Menu.W.Wmove:Value() and _G.SDK.Orbwalker:GetTarget() ~= nil and HaveBuff(myHero, "jaycehypercharge") then
			_G.SDK.Orbwalker:SetMovement(false)
		else
			_G.SDK.Orbwalker:SetMovement(true)
		end
		if IsReady(_Q) and Menu.Q.Qr:Value() then
			self:Q1Logic()
		end
		if IsReady(_W) and Menu.W.Wr:Value() then
			self:W1Logic()
		end
	else
		_G.SDK.Orbwalker:SetMovement(true)
		if IsReady(_E) and Menu.E.Em:Value() then
			self:E2Logic()
		end
		if IsReady(_Q) and Menu.Q.Qm:Value() then
			self:Q2Logic()
		end
		if IsReady(_W) and Menu.W.Wm:Value() then
			self:W2Logic()
		end
	end
	
	if IsReady(_R) then
		self:RLogic()
	end

	self:JungleClear()
	self:LaneClear()
end

function zgJayce:Gapcloser()
	if not Menu.E.gapE:Value() or E2cd > 0.1 then
		return
	end
	if self:IsRange() and not IsReady(_R) then
		return
	end
	
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
	for i, target in ipairs(enemies) do
		if IsValid(target) and target.pathing.isDashing and not HasInvalidDashBuff(target) then
			if myHero.pos:DistanceTo(target.pathing.endPos) <= 400 then
				if self:IsRange() then
					Control.CastSpell(HK_R)
				else
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgJayce:Flee()
	if self:IsRange() then
		if IsReady(_E) then
			Control.CastSpell(HK_E, myHero.pos:Extended(mousePos, 150))
		else
			if IsReady(_R) then
				Control.CastSpell(HK_R)
			end
		end
	else
		if IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q2Spell.Range)
			table.sort(minions, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
			if #minions > 0 then
				local best = minions[1]
				if best.pos:DistanceTo(mousePos) + 200 < myHero.pos:DistanceTo(mousePos) then
					Control.CastSpell(HK_Q, best)
				end
			else
				if IsReady(_R) then
					Control.CastSpell(HK_R)
				end
			end
		else
			if IsReady(_R) then
				Control.CastSpell(HK_R)
			end
		end
	end	
end

function zgJayce:Q1Logic()
	local Qtype = self.Q1Spell
	if self:CanUseQE() then Qtype = self.Q1extSpell end
	
	if Menu.Q.useQE:Value() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Qtype.Range)
		table.sort(enemies, function(a, b) return mousePos:DistanceTo(a.pos) < mousePos:DistanceTo(b.pos) end)
		if IsValid(enemies[1]) then
			self:CastQ1(enemies[1])
			return
		end
	end
	
	local target = GetTarget(Qtype.Range)
	if IsValid(target) then
		local qDmg = self:GetQ1Dmg(target)
		if self:CanUseQE() then qDmg = qDmg * 1.4 end
		if qDmg > target.health then
			self:CastQ1(target)
		elseif GetMode() == "Combo" and myHero.mana > Q1mana + E1mana then
			self:CastQ1(target)
		elseif GetMode() == "Harass" --[[and myHero.mana/myHero.maxMana > Menu.Harass.Mana:Value()/100 ]]then
			self:CastQ1(target)
		end
	end
	
	-- if (GetMode() ~= "Combo" or GetMode() ~= "Harass") and myHero.mana > Q1mana + E1mana then
		-- local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Qtype.Range)
		-- for i, enemy in ipairs(enemies) do
			-- if IsValid(enemy) and IsHardCC(enemy) then
				-- self:CastQ1(enemy)
			-- end
		-- end
	-- end
end

function zgJayce:W1Logic()
	local target = _G.SDK.Orbwalker:GetTarget()
	if GetMode() == "Combo" and IsReady(_W) and target ~= nil and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_W)
	end
end

function zgJayce:Q2Logic()
	local target = GetTarget(self.Q2Spell.Range)
	if IsValid(target) then
		if self:GetQ2Dmg(target) > target.health then
			Control.CastSpell(HK_Q, target)
		else
			if GetMode() == "Combo" then
				Control.CastSpell(HK_Q, target)
			end
		end
	end
end

function zgJayce:W2Logic()
	if GetEnemyCount(300, myHero.pos) > 0 and myHero.mana > 80 then
		Control.CastSpell(HK_W)
	end
end

function zgJayce:E2Logic()
	local target = GetTarget(self.E2Spell.Range+150)
	if IsValid(target) then
		if self:GetE2Dmg(target) > target.health then
			Control.CastSpell(HK_E, target)
		else
			if GetMode() == "Combo" and not Menu.E.Eks:Value() and not HaveBuff(myHero, "jaycehypercharge") then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function zgJayce:RLogic()
	if self:IsRange() and Menu.R.Rm:Value() then
		local target = GetTarget(self.Q2Spell.Range+200)
		if GetMode() == "Combo" and Q1cd > 0.5 and IsValid(target) and
			((not IsReady(_W) and target.range > 300) or (not IsReady(_W) and not HaveBuff(myHero, "jaycehypercharge") and target.range < 300))
		then
			if Q2cd < 0.5 and GetEnemyCount(800, target.pos) < 3 then
				Control.CastSpell(HK_R)
			else
				if GetEnemyCount(300, myHero.pos) > 0 and E2cd < 0.5 then
					Control.CastSpell(HK_R)
				end
			end
		end
	else
		if GetMode() == "Combo" and Menu.R.Rr:Value() then
			local target = GetTarget(1400)
			if IsValid(target) and target.pos:DistanceTo(myHero.pos) > self.Q2Spell.Range + 200 then
				if Q1cd < 0.5 and E1cd < 0.5 then -- and self:GetQ1Dmg(target) * 1.4 > target.health
					Control.CastSpell(HK_R)
				end
			end
			if not IsReady(_Q) and (not IsReady(_E) or Menu.E.Eks:Value()) then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function zgJayce:CastQ1(target)
	if not self:CanUseQE() then
		local Pred = GGPrediction:SpellPrediction(self.Q1Spell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
			return
		end
	end

	if Menu.Q.QEsplash:Value() then
		local Pred = GGPrediction:SpellPrediction(self.Q1extSpell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, Pred.CastPosition, self.Q1extSpell.Speed, self.Q1extSpell.Delay, self.Q1extSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
			if collisionCount > 0 then
				local minion = collisionObjects[1]
				if minion.pos:DistanceTo(Pred.CastPosition) < 150 then
					Control.CastSpell(HK_Q, Pred.CastPosition)
				end
			else
				Control.CastSpell(HK_Q, Pred.CastPosition)
			end
		end
	else
		local Pred = GGPrediction:SpellPrediction(self.Q1extColSpell)
		Pred:GetPrediction(target, myHero)
		if Pred:CanHit(3) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function zgJayce:CanUseQE()
	if IsReady(_E) and myHero.mana > Q1mana + E1mana and Menu.E.Er:Value() then
		return true
	else
		return false
	end
end

function zgJayce:IsRange()
	return myHero:GetSpellData(_Q).name:lower() == "jayceshockblast"
end

function zgJayce:LaneClear()
	if GetMode() ~= "LaneClear" then return end
	if IsUnderTurret(myHero) then return end
	if Menu.Farm.spellFarm:Value() --[[and myHero.mana/myHero.maxMana > Menu.Farm.Mana:Value()/100 ]]then
		if self:IsRange() and IsReady(_Q) and IsReady(_E) and Menu.Farm.farmQ:Value() then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q1Spell.Range)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					if GetMinionCount(250, minion.pos) >= Menu.Farm.LCminions:Value() then
						local endPos = minion.pos:Extended(myHero.pos, 150)
						local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, endPos, self.Q1extSpell.Speed, self.Q1extSpell.Delay, self.Q1extSpell.Radius, {GGPrediction.COLLISION_MINION}, minion.networkID)
						if collisionCount == 0 then
							Control.CastSpell(HK_Q, minion)
						end
					end
				end
			end
		end
		if IsReady(_W) and Menu.Farm.farmW:Value() then
			if self:IsRange() then
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(550)
				for i = 1, #minions do
					local minion = minions[i]
					if minion.team ~= 300 and #minions >= Menu.Farm.LCminions:Value() then
						Control.CastSpell(HK_W)
					end
				end
			else
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(300)
				for i = 1, #minions do
					local minion = minions[i]
					if minion.team ~= 300 and #minions >= Menu.Farm.LCminions:Value() then
						Control.CastSpell(HK_W)
					end
				end
			end
		end
	end
end

function zgJayce:JungleClear()
	if GetMode() == "LaneClear" and Menu.Farm.jungleC:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(700)
		for i = 1, #minions do
			local minion = minions[i]
			if minion.team == 300 and #minions > 0 then
				if self:IsRange() then
					if IsReady(_Q) and Menu.Farm.jungleQ:Value() then
						Control.CastSpell(HK_Q, minion)
						return
					end
					if IsReady(_W) and Menu.Farm.jungleW:Value() then
						if _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
							Control.CastSpell(HK_W)
							return
						end
					end
					if IsReady(_R) and Menu.Farm.jungleR:Value() then
						Control.CastSpell(HK_R)
					end
				else
					if IsReady(_Q) and Menu.Farm.jungleQm:Value() then
						Control.CastSpell(HK_Q, minion)
						return
					end
					if IsReady(_W) and Menu.Farm.jungleWm:Value() then
						if myHero.pos:DistanceTo(minion.pos) <= 300 then
							Control.CastSpell(HK_W)
							return
						end
					end
					if IsReady(_E) and Menu.Farm.jungleEm:Value() then
						if myHero.pos:DistanceTo(minion.pos) <= 300 then
							Control.CastSpell(HK_E, minion)
							return
						end
					end
					if IsReady(_R) and Menu.Farm.jungleR:Value() then
						Control.CastSpell(HK_R)
					end
				end
			end
		end
	end
end

function zgJayce:GetQ1Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({80, 121, 162, 203, 244, 285})[level] + 1.40 * myHero.bonusDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgJayce:GetQ2Dmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({60, 110, 160, 210, 260, 310})[level] + 1.35 * myHero.bonusDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgJayce:GetE2Dmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({8, 10.8, 13.6, 16.4, 19.2, 22})[level]/100 * target.maxHealth + myHero.bonusDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgJayce:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Farm.spellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.DrawJungle:Value() then
		if Menu.Farm.jungleC:Value() then
			Draw.Text("Jungle Clear: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Jungle Clear: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end

	if Menu.Draw.showcd:Value() then
		local msg = " "
		if self:IsRange() then
			msg = "Q2 " .. math.floor(Q2cd) .. " W2 " .. math.floor(W2cd) .. " E2 " .. math.floor(E2cd)
			Draw.Text(msg, 22, myHero.pos2D.x-50, myHero.pos2D.y-120, Draw.Color(255, 255, 165, 0))
		else
			msg = "Q1 " .. math.floor(Q1cd) .. " W1 " .. math.floor(W1cd) .. " E1 " .. math.floor(E1cd)
			Draw.Text(msg, 22, myHero.pos2D.x-50, myHero.pos2D.y-120, Draw.Color(255, 0, 255, 255))
		end
	end
	
	if Menu.Draw.Q:Value() then
		if self:IsRange() then
			if self:CanUseQE() then
				Draw.Circle(myHero.pos, self.Q1extSpell.Range, 1, Draw.Color(255, 66, 244, 113))
			else
				Draw.Circle(myHero.pos, self.Q1Spell.Range, 1, Draw.Color(255, 66, 244, 113))
			end
		else
			Draw.Circle(myHero.pos, self.Q2Spell.Range, 1, Draw.Color(255, 66, 244, 113))
		end
	end
end

zgJayce()
