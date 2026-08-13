local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicLeona"

function ClassicLeona:__init()
	print("Classic AIO - Leona Loaded")
	self.WRange = 450
	self.QRange = 225
	self.ESpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 875, Speed = 1200, Collision = false }
	self.RSpell = { Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.625, Radius = 250, Range = 1200, Speed = math.huge, Collision = false }
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args) self:OnPreAttack(args) end)
end

function ClassicLeona:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = s, name = "Use " .. s, value = true })
	end
	Menu.Combo:MenuElement({ id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	for _, s in ipairs({ "Q", "W", "E" }) do
		Menu.Harass:MenuElement({ id = s, name = "Use " .. s, value = s ~= "W" })
	end
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "W", name = "Use W | Nearby Units >=", value = 3, min = 1, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "E", name = "Use E In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "E", name = "Auto E", value = true })
	Menu.KillSteal:MenuElement({ id = "R", name = "Auto R", value = true })
	Menu:MenuElement({ type = MENU, id = "SemiR", name = "Semi-Manual R" })
	Menu.SemiR:MenuElement({ id = "Key", name = "Semi-Manual R Key (Hold)", key = string.byte("T") })
	Menu.SemiR:MenuElement({ id = "Count", name = "Enemy Count >=", value = 1, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Misc", name = "Misc" })
	Menu.Misc:MenuElement({ id = "AutoW", name = "Auto W When HP <= x%", value = 35, min = 0, max = 100, step = 5 })
	Menu.Misc:MenuElement({ id = "AntiDash", name = "Auto E Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicLeona:QActive() return HaveBuff(myHero, "Jade_LeonaShieldOfDaybreak") end
function ClassicLeona:ManaPercent() return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100 end

function ClassicLeona:Tick()
	if ShouldWait() or IsCasting() then return end
	self:AutoW()
	self:AntiDash()
	if self:SemiR() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	end
end

function ClassicLeona:OnPreAttack(args)
	local target = args and args.Target
	if not IsValid(target) or target.type ~= Obj_AI_Hero or self:QActive() or not IsReady(_Q) then return end
	local mode = GetMode()
	if (mode == "Combo" and Menu.Combo.Q:Value()) or (mode == "Harass" and Menu.Harass.Q:Value()) then Control.CastSpell(HK_Q) end
end

function ClassicLeona:AutoW()
	if not IsReady(_W) or Menu.Misc.AutoW:Value() == 0 or GetEnemyCount(700, myHero.pos) == 0 then return end
	local hp = myHero.maxHealth > 0 and myHero.health / myHero.maxHealth * 100 or 100
	if hp <= Menu.Misc.AutoW:Value() then Control.CastSpell(HK_W) end
end

function ClassicLeona:Combo()
	local target = GetTarget(self.RSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and target.distance <= self.RSpell.Range and CastSpellAOE(HK_R, self.RSpell, Menu.Combo.RCount:Value(), myHero, target) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance <= self.ESpell.Range then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) and target.distance <= self.ESpell.Range and self:CastE(target, 2) then return end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not self:QActive() and target.distance <= self.QRange then Control.CastSpell(HK_Q) end
end

function ClassicLeona:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.ESpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Harass.E:Value() and IsReady(_E) and self:CastE(target, 3) then return end
	if Menu.Harass.Q:Value() and IsReady(_Q) and target.distance <= self.QRange then Control.CastSpell(HK_Q) end
end

function ClassicLeona:Clear()
	if not Menu.Clear.Enabled:Value() or self:ManaPercent() < Menu.Clear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WRange)
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	local count = 0
	for _, u in ipairs(minions) do
		if IsValid(u) and u.distance <= self.WRange then count = count + 1 end
	end
	for _, u in ipairs(monsters) do
		if IsValid(u) and u.distance <= self.WRange then count = count + 1 end
	end
	if IsReady(_W) and count >= Menu.Clear.W:Value() then
		Control.CastSpell(HK_W)
		return
	end
	if Menu.Clear.E:Value() and IsReady(_E) and IsValid(monsters[1]) then Control.CastSpell(HK_E, monsters[1].pos) end
end

function ClassicLeona:AntiDash()
	if not Menu.Misc.AntiDash:Value() or not IsReady(_E) then return end
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)) do
		if IsValid(target) and target.pathing and target.pathing.isDashing and target.pathing.endPos and target.pathing.endPos:DistanceTo(myHero.pos) <= self.ESpell.Range then
			Control.CastSpell(HK_E, target.pathing.endPos)
			return
		end
	end
end

function ClassicLeona:SemiR()
	if not Menu.SemiR.Key:Value() or not IsReady(_R) then return false end
	local target = GetTarget(self.RSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return false end
	local count = Menu.SemiR.Count:Value()
	if count > 1 then return CastSpellAOE(HK_R, self.RSpell, count, myHero, target) and true or false end
	local p = GGPrediction:SpellPrediction(self.RSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(3) then
		Control.CastSpell(HK_R, p.CastPosition)
		return true
	end
	return false
end

function ClassicLeona:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.RSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			local hp = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.E:Value() and IsReady(_E) and target.distance <= self.ESpell.Range and self:GetEDmg(target) >= hp then
				if self:CastE(target, 3) then return end
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and self:GetRDmg(target) >= hp then
				local p = GGPrediction:SpellPrediction(self.RSpell)
				p:GetPrediction(target, myHero)
				if p:CanHit(3) then
					Control.CastSpell(HK_R, p.CastPosition)
					return
				end
			end
		end
	end
end

function ClassicLeona:CastE(target, hc)
	local p = GGPrediction:SpellPrediction(self.ESpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		Control.CastSpell(HK_E, p.CastPosition)
		return true
	end
	return false
end
function ClassicLeona:Magic(target, raw) return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, raw) end
function ClassicLeona:GetEDmg(t)
	local l = myHero:GetSpellData(_E).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 60, 100, 140, 180, 220 })[l] + myHero.ap * 0.40)
end
function ClassicLeona:GetRDmg(t)
	local l = myHero:GetSpellData(_R).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 150, 250, 350 })[l] + myHero.ap * 0.80)
end

function ClassicLeona:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.W:Value() and IsReady(_W) then Draw.Circle(myHero.pos, self.WRange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 66, 229, 244)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 96)) end
end

ClassicLeona()
