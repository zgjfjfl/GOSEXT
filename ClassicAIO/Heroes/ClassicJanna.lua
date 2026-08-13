local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicJanna"

function ClassicJanna:__init()
	print("Classic AIO - Janna Loaded")
	self.QSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.15, Radius = 100, Range = 1100, Speed = 900, Collision = false }
	self.WRange, self.ERange, self.RRange = 550, 800, 600
	self.qStart = 0
	self.qTarget = nil
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function ClassicJanna:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	Menu.Combo:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Combo:MenuElement({ id = "W", name = "Use W", value = true })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "W", name = "Use W", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q | Minions >=", value = 3, min = 1, max = 6, step = 1 })
	Menu.Clear:MenuElement({ id = "W", name = "Use W In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Auto", name = "Auto Support" })
	Menu.Auto:MenuElement({ id = "E", name = "Auto E Shield", toggle = true, value = true })
	Menu.Auto:MenuElement({ type = MENU, id = "Etarget", name = "Use E On" })
	_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
		Menu.Auto.Etarget:MenuElement({ id = args.charName, name = args.charName, value = true })
	end)
	Menu.Auto:MenuElement({ id = "R", name = "Auto R Self HP <= x%", value = 25, min = 0, max = 100, step = 5 })
	Menu.Auto:MenuElement({ id = "AntiDash", name = "Auto Q Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "W", name = "Auto W", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicJanna:IsQCharging() return HaveBuff(myHero, "Jade_JannaHowlingGale") or myHero:GetSpellData(_Q).name == "Jade_JannaHowlingGaleSpell" end
function ClassicJanna:IsChannelingR()
	local a = myHero.activeSpell
	return HaveBuff(myHero, "Jade_JannaReapTheWhirlwind") or (a and a.valid and a.name == "Jade_JannaReapTheWhirlwind")
end

function ClassicJanna:Tick()
	local channel = self:IsChannelingR()
	_G.SDK.Orbwalker:SetAttack(not channel)
	_G.SDK.Orbwalker:SetMovement(not channel)
	if channel then return end
	if ShouldWait() then return end
	if self:HandleQ() then return end
	if IsCasting() then return end
	self:AutoR()
	self:AutoE()
	self:AntiDash()
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

function ClassicJanna:HandleQ()
	if not self:IsQCharging() then return false end
	local elapsed = GetTickCount() - self.qStart
	if elapsed >= 250 and ((IsValid(self.qTarget) and IsHardCC(self.qTarget)) or elapsed >= 650) then
		Control.CastSpell(HK_Q)
		self.qTarget = nil
		return true
	end
	return true
end

function ClassicJanna:StartQ(target, hc)
	if not IsReady(_Q) or self:IsQCharging() then return false end
	local p = GGPrediction:SpellPrediction(self.QSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		Control.CastSpell(HK_Q, p.CastPosition)
		self.qStart = GetTickCount()
		self.qTarget = target
		return true
	end
	return false
end

function ClassicJanna:Combo()
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.Q:Value() and self:StartQ(target, 2) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance <= self.WRange then Control.CastSpell(HK_W, target) end
end

function ClassicJanna:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.Q:Value() and self:StartQ(target, 3) then return end
	if Menu.Harass.W:Value() and IsReady(_W) and target.distance <= self.WRange then Control.CastSpell(HK_W, target) end
end

function ClassicJanna:AutoE()
	if not Menu.Auto.E:Value() or not IsReady(_E) or lastE + 250 >= GetTickCount() then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.ERange)
	local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1500)
	for _, ally in ipairs(allies) do
		local option = Menu.Auto.Etarget[ally.charName]
		if IsValid(ally) and option and option:Value() then
			local canuse = IsPoison(ally)
			if not canuse then
				for _, enemy in ipairs(enemies) do
					if IsValid(enemy) then
						local spell = enemy.activeSpell
						if spell and spell.valid then
							if spell.target == ally.handle then
								canuse = true
								break
							else
								local spellWidth = spell.width or 0
								local endPos = spell.startPos:Extended(spell.placementPos, (spell.range or 0) + spellWidth)
								local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
								local width = ally.boundingRadius + (spellWidth > 0 and spellWidth or 0)
								if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
									canuse = true
									break
								end
							end
						end
					end
				end
				if not canuse then
					for _, turret in ipairs(turrets) do
						if turret and turret.targetID == ally.networkID then
							canuse = true
							break
						end
					end
				end
			end
			if canuse then
				self:CastE(ally)
				lastE = GetTickCount()
				break
			end
		end
	end
end

function ClassicJanna:CastE(unit)
	if unit.isMe then
		Control.KeyDown(0x12)
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
		Control.KeyUp(0x12)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function ClassicJanna:AutoR()
	if not IsReady(_R) or Menu.Auto.R:Value() == 0 then return end
	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if hp <= Menu.Auto.R:Value() and GetEnemyCount(self.RRange, myHero.pos) > 0 then Control.CastSpell(HK_R) end
end

function ClassicJanna:AntiDash()
	if not Menu.Auto.AntiDash:Value() or not IsReady(_Q) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(t) and t.pathing and t.pathing.isDashing and t.posTo and myHero.pos:DistanceTo(t.posTo) < 500 then
			if self:StartQ(t, 2) then
				self.qStart = GetTickCount() - 500
				return
			end
		end
	end
end

function ClassicJanna:Clear()
	if not Menu.Clear.Enabled:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	if Menu.Clear.Q:Value() > 0 and IsReady(_Q) then
		for _, m in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)) do
			if IsValid(m) and GetMinionCount(200, m.pos) >= Menu.Clear.Q:Value() then
				Control.CastSpell(HK_Q, m.pos)
				self.qStart = GetTickCount() - 200
				self.qTarget = nil
				return
			end
		end
	end
	if Menu.Clear.W:Value() and IsReady(_W) then
		local monsters = _G.SDK.ObjectManager:GetMonsters(self.WRange)
		if IsValid(monsters[1]) then Control.CastSpell(HK_W, monsters[1]) end
	end
end

function ClassicJanna:Flee()
	if IsReady(_E) then
		Control.CastSpell(HK_E, myHero)
		return
	end
	local target = GetTarget(self.WRange)
	if IsValid(target) and IsReady(_W) then
		Control.CastSpell(HK_W, target)
		return
	end
	if IsReady(_Q) then
		Control.CastSpell(HK_Q, mousePos)
		self.qStart = GetTickCount() - 200
	end
end

function ClassicJanna:KillSteal()
	if not Menu.KillSteal.W:Value() or not IsReady(_W) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.WRange)) do
		if IsValid(t) and t.pos2D.onScreen and self:GetWDmg(t) >= t.health + (t.hpRegen or 0) + (t.shieldAP or 0) then
			Control.CastSpell(HK_W, t)
			return
		end
	end
end

function ClassicJanna:GetWDmg(t)
	local l = myHero:GetSpellData(_W).level
	if l == 0 then return 0 end
	return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, ({ 60, 115, 170, 225, 280 })[l] + myHero.ap * 0.60)
end
function ClassicJanna:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end

ClassicJanna()
