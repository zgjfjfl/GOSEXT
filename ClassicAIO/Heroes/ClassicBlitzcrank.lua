local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicBlitzcrank"

function ClassicBlitzcrank:__init()
	print("Classic AIO - Blitzcrank Loaded")
	self.QSpell = { Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1079, Speed = 1800, Collision = true, CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL } }
	self.ERange, self.RRange = 275, 600
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPreAttack(function(args) self:OnPreAttack(args) end)
end

function ClassicBlitzcrank:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	for _, s in ipairs({ "Q", "W", "E", "R" }) do
		Menu.Combo:MenuElement({ id = s, name = "Use " .. s, value = true })
	end
	Menu.Combo:MenuElement({ id = "RCount", name = "Use R | Enemy Count >=", value = 2, min = 1, max = 5, step = 1 })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "E", name = "Use E", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 45, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "W", name = "Use W In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "E", name = "Use E In Jungle", value = true })
	Menu.Clear:MenuElement({ id = "R", name = "Use R | Nearby Minions >=", value = 5, min = 0, max = 8, step = 1 })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "Q", name = "Auto Q", value = true })
	Menu.KillSteal:MenuElement({ id = "R", name = "Auto R", value = true })
	Menu:MenuElement({ type = MENU, id = "Misc", name = "Misc" })
	Menu.Misc:MenuElement({ id = "AutoQ", name = "Auto Q Immobilized Target", value = true })
	Menu.Misc:MenuElement({ id = "AntiDash", name = "Auto Q Anti-Dash", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	for _, s in ipairs({ "Q", "E", "R" }) do
		Menu.Draw:MenuElement({ id = s, name = "Draw " .. s .. " Range", value = false })
	end
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicBlitzcrank:ManaPercent() return myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100 end
function ClassicBlitzcrank:EActive() return HaveBuff(myHero, "Jade_BlitzcrankPowerFist") end

function ClassicBlitzcrank:Tick()
	if ShouldWait() or IsCasting() then return end
	self:AutoQ()
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

function ClassicBlitzcrank:OnPreAttack(args)
	local target = args and args.Target
	if not IsValid(target) or not IsReady(_E) or self:EActive() then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "Harass" and Menu.Harass.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "LaneClear" and Menu.Clear.Enabled:Value() and Menu.Clear.E:Value() and target.team == 300 then
		Control.CastSpell(HK_E)
	end
end

function ClassicBlitzcrank:Combo()
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and GetEnemyCount(self.RRange, myHero.pos) >= Menu.Combo.RCount:Value() then
		Control.CastSpell(HK_R)
		return
	end
	if Menu.Combo.E:Value() and IsReady(_E) and not self:EActive() and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and self:CastQ(target, 2) then return end
	if Menu.Combo.W:Value() and IsReady(_W) and target.distance > self.ERange then Control.CastSpell(HK_W) end
end

function ClassicBlitzcrank:Harass()
	if self:ManaPercent() < Menu.Harass.Mana:Value() then return end
	local target = GetTarget(self.QSpell.Range)
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Harass.E:Value() and IsReady(_E) and target.distance <= self.ERange then
		Control.CastSpell(HK_E)
		return
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then self:CastQ(target, 3) end
end

function ClassicBlitzcrank:Clear()
	if not Menu.Clear.Enabled:Value() or self:ManaPercent() < Menu.Clear.Mana:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ERange)
	if Menu.Clear.R:Value() > 0 and IsReady(_R) and GetMinionCount(self.RRange, myHero.pos) >= Menu.Clear.R:Value() then
		Control.CastSpell(HK_R)
		return
	end
	if IsValid(monsters[1]) then
		if Menu.Clear.E:Value() and IsReady(_E) and not self:EActive() then
			Control.CastSpell(HK_E)
			return
		end
		if Menu.Clear.W:Value() and IsReady(_W) then Control.CastSpell(HK_W) end
	end
end

function ClassicBlitzcrank:AutoQ()
	if not IsReady(_Q) then return end
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			if Menu.Misc.AntiDash:Value() and target.pathing and target.pathing.isDashing and target.pathing.endPos and target.pathing.endPos:DistanceTo(myHero.pos) <= self.QSpell.Range then
				Control.CastSpell(HK_Q, target.pathing.endPos)
				return
			end
			if Menu.Misc.AutoQ:Value() and IsHardCC(target) then
				if self:CastQ(target, 4) then return end
			end
		end
	end
end

function ClassicBlitzcrank:KillSteal()
	for _, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
		if IsValid(target) and target.pos2D.onScreen then
			local hp = target.health + (target.hpRegen or 0) + (target.shieldAP or 0)
			if Menu.KillSteal.R:Value() and IsReady(_R) and target.distance <= self.RRange and self:GetRDmg(target) >= hp then
				Control.CastSpell(HK_R)
				return
			end
			if Menu.KillSteal.Q:Value() and IsReady(_Q) and self:GetQDmg(target) >= hp then
				if self:CastQ(target, 3) then return end
			end
		end
	end
end

function ClassicBlitzcrank:CastQ(target, hc)
	local p = GGPrediction:SpellPrediction(self.QSpell)
	p:GetPrediction(target, myHero)
	if p:CanHit(hc or 2) then
		Control.CastSpell(HK_Q, p.CastPosition)
		return true
	end
	return false
end
function ClassicBlitzcrank:Magic(t, d) return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, d) end
function ClassicBlitzcrank:GetQDmg(t)
	local l = myHero:GetSpellData(_Q).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 80, 135, 190, 245, 300 })[l] + myHero.ap)
end
function ClassicBlitzcrank:GetRDmg(t)
	local l = myHero:GetSpellData(_R).level
	if l == 0 then return 0 end
	return self:Magic(t, ({ 250, 375, 500 })[l] + myHero.ap)
end

function ClassicBlitzcrank:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 244, 238, 66)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end

ClassicBlitzcrank()
