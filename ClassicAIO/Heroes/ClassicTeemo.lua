local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicTeemo"

function ClassicTeemo:__init()
	print("Classic AIO - Teemo Loaded")
	self.QRange, self.RRange = 680, 230
	self.RSpell = { Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 230, Speed = 1450, Collision = false }
	self.lastRPos = nil
	self.lastRTime = 0
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
end

function ClassicTeemo:LoadMenu()
	local icon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/" .. myHero.charName .. ".png"
	Menu = MenuElement({ type = MENU, id = "Classic_AIO_" .. myHero.charName, name = "Classic AIO - " .. myHero.charName .. " V: " .. Version, leftIcon = icon })
	Menu:MenuElement({ type = MENU, id = "Combo", name = "Combo" })
	Menu.Combo:MenuElement({ id = "Q", name = "Use Q After Attack", value = true })
	Menu.Combo:MenuElement({ id = "W", name = "Use W Chase", value = true })
	Menu.Combo:MenuElement({ id = "R", name = "Use R In Melee Range", value = true })
	Menu:MenuElement({ type = MENU, id = "Harass", name = "Harass" })
	Menu.Harass:MenuElement({ id = "Q", name = "Use Q", value = true })
	Menu.Harass:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 40, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "Clear", name = "Clear" })
	Menu.Clear:MenuElement({ id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end })
	Menu.Clear:MenuElement({ id = "Q", name = "Use Q Last Hit", value = true })
	Menu.Clear:MenuElement({ id = "R", name = "Use R In Jungle", value = false })
	Menu.Clear:MenuElement({ id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5 })
	Menu:MenuElement({ type = MENU, id = "KillSteal", name = "KillSteal" })
	Menu.KillSteal:MenuElement({ id = "Q", name = "Auto Q", value = true })
	Menu:MenuElement({ type = MENU, id = "Flee", name = "Flee" })
	Menu.Flee:MenuElement({ id = "W", name = "Use W", value = true })
	Menu:MenuElement({ type = MENU, id = "Draw", name = "Draw" })
	Menu.Draw:MenuElement({ id = "Q", name = "Draw Q Range", value = false })
	Menu.Draw:MenuElement({ id = "R", name = "Draw R Range", value = false })
	Menu.Draw:MenuElement({ id = "Farm", name = "Draw Farm Status", value = true })
end

function ClassicTeemo:Tick()
	if ShouldWait() or IsCasting() then return end
	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:Clear()
	elseif mode == "Flee" and Menu.Flee.W:Value() and IsReady(_W) then
		Control.CastSpell(HK_W)
	end
end

function ClassicTeemo:Combo()
	local t = GetTarget(self.QRange)
	if not IsValid(t) or not t.pos2D.onScreen then return end
	if Menu.Combo.R:Value() and IsReady(_R) and t.distance <= self.RRange and self:CastR(t) then return end
	local aaRange = myHero.range + myHero.boundingRadius + (t.boundingRadius or 0)
	if Menu.Combo.Q:Value() and IsReady(_Q) and t.distance > aaRange then
		Control.CastSpell(HK_Q, t)
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) and t.distance > aaRange then Control.CastSpell(HK_W) end
end

function ClassicTeemo:OnPostAttack(args)
	if GetMode() ~= "Combo" or not Menu.Combo.Q:Value() or not IsReady(_Q) then return end
	local t = args and (args.Target or args.target) or nil
	if not IsValid(t) and _G.SDK.Orbwalker.GetTarget then t = _G.SDK.Orbwalker:GetTarget() end
	if IsValid(t) and t.type == Obj_AI_Hero and t.distance <= self.QRange then Control.CastSpell(HK_Q, t) end
end

function ClassicTeemo:Harass()
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Harass.Mana:Value() then return end
	local t = GetTarget(self.QRange)
	if IsValid(t) and t.pos2D.onScreen and Menu.Harass.Q:Value() and IsReady(_Q) then Control.CastSpell(HK_Q, t) end
end

function ClassicTeemo:CastR(t)
	local p = GGPrediction:SpellPrediction(self.RSpell)
	p:GetPrediction(t, myHero)
	if not p:CanHit(2) then return false end
	if self.lastRPos and GetTickCount() - self.lastRTime < 5000 and self.lastRPos:DistanceTo(p.CastPosition) < 150 then return false end
	Control.CastSpell(HK_R, p.CastPosition)
	self.lastRPos = p.CastPosition
	self.lastRTime = GetTickCount()
	return true
end

function ClassicTeemo:Clear()
	if not Menu.Clear.Enabled:Value() or IsUnderTurret(myHero) then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QRange)
	if Menu.Clear.Q:Value() and IsReady(_Q) then
		for _, m in ipairs(minions) do
			local hp = IsValid(m) and _G.SDK.HealthPrediction:GetPrediction(m, 0.25) or 0
			if hp > 0 and self:GetQDmg(m) >= hp then
				Control.CastSpell(HK_Q, m)
				return
			end
		end
	end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QRange)
	local t = monsters[1]
	if IsValid(t) then
		if Menu.Clear.Q:Value() and IsReady(_Q) then
			Control.CastSpell(HK_Q, t)
			return
		end
		if Menu.Clear.R:Value() and IsReady(_R) and t.distance <= self.RRange then Control.CastSpell(HK_R, t.pos) end
	end
end

function ClassicTeemo:KillSteal()
	if not Menu.KillSteal.Q:Value() or not IsReady(_Q) then return end
	for _, t in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QRange)) do
		if IsValid(t) and t.pos2D.onScreen and self:GetQDmg(t) >= t.health + (t.hpRegen or 0) + (t.shieldAP or 0) then
			Control.CastSpell(HK_Q, t)
			return
		end
	end
end
function ClassicTeemo:GetQDmg(t)
	local l = myHero:GetSpellData(_Q).level
	if l == 0 then return 0 end
	return _G.SDK.Damage:CalculateDamage(myHero, t, _G.SDK.DAMAGE_TYPE_MAGICAL, ({ 80, 125, 170, 215, 260 })[l] + myHero.ap * 0.70)
end
function ClassicTeemo:Draw()
	if myHero.dead then return end
	if Menu.Draw.Farm:Value() then Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34)) end
	if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QRange, 1, Draw.Color(255, 66, 244, 113)) end
	if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end

ClassicTeemo()
