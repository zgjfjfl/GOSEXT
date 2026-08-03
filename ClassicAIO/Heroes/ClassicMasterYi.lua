local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicMasterYi"

function ClassicMasterYi:__init()
	print("Classic AIO - MasterYi Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Range = 600}
	self.RSearchRange = 1000
	self.meditateStart = 0
	self.wasMeditating = false
end

function ClassicMasterYi:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "QSafe", name = "Do Not Q Under Enemy Turret", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q | Nearby Minions >=", value = 3, min = 1, max = 4, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E Before Attack", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "AutoW", name = "Auto W At Low HP", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "WHP", name = "Auto W | HP <= x%", value = 30, min = 5, max = 80, step = 5})
	Menu.Misc:MenuElement({id = "WRange", name = "Auto W | Enemy Range", value = 900, min = 300, max = 1500, step = 50})
	Menu.Misc:MenuElement({id = "WChannel", name = "Minimum W Channel Seconds", value = 1, min = 0, max = 3, step = 1})
	Menu.Misc:MenuElement({id = "FleeR", name = "Use R To Flee", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
end

function ClassicMasterYi:IsMeditating()
	return HaveBuff(myHero, "Jade_MasterYiMeditate")
end

function ClassicMasterYi:HandleMeditate()
	local meditating = self:IsMeditating()
	if meditating and not self.wasMeditating then
		self.meditateStart = Game.Timer()
	end
	self.wasMeditating = meditating

	local locked = meditating and Game.Timer() < self.meditateStart + Menu.Misc.WChannel:Value()
	_G.SDK.Orbwalker:SetAttack(not locked)
	_G.SDK.Orbwalker:SetMovement(not locked)
	if not meditating then
		self.meditateStart = 0
	end
	return locked
end

function ClassicMasterYi:Tick()
	if self:HandleMeditate() then return end
	if ShouldWait() then return end
	if IsCasting() then return end
	if self:AutoW() then return end

	self:KillSteal()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	elseif mode == "Flee" then
		self:Flee()
	end
end

function ClassicMasterYi:OnPreAttack(args)
	local target = args.Target
	if not IsValid(target) or not IsReady(_E) then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.E:Value() and target.type == Obj_AI_Hero then
		Control.CastSpell(HK_E)
	elseif mode == "LaneClear" and Menu.Clear.SpellFarm:Value() and target.type == Obj_AI_Minion then
		if target.team == 300 and Menu.Clear.JungleClear.E:Value() then
			Control.CastSpell(HK_E)
		elseif target.team ~= 300 and Menu.Clear.LaneClear.E:Value() then
			Control.CastSpell(HK_E)
		end
	end
end

function ClassicMasterYi:OnPostAttack(args)
	if not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local target = (args and args.Target) or _G.SDK.Orbwalker:GetTarget()
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.QSpell.Range then return end
	local mode = GetMode()
	if mode == "Combo" and Menu.Combo.Q:Value() and target.type == Obj_AI_Hero then
		if self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			Control.CastSpell(HK_Q, target)
			lastQ = GetTickCount()
		end
	elseif mode == "Harass" and Menu.Harass.Q:Value() and target.type == Obj_AI_Hero then
		if self:CanUseQ(target, true) then
			Control.CastSpell(HK_Q, target)
			lastQ = GetTickCount()
		end
	end
end

function ClassicMasterYi:CanUseQ(target, safeMode)
	if not IsValid(target) or myHero.pos:DistanceTo(target.pos) > self.QSpell.Range then return false end
	if safeMode and not IsUnderTurret(myHero) and IsUnderTurret2(target.pos) then return false end
	return true
end

function ClassicMasterYi:Combo()
	local target = GetTarget(self.RSearchRange)
	if not IsValid(target) then return end
	local inAARange = _G.SDK.Data:IsInAutoAttackRange(myHero, target)

	if Menu.Combo.R:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_MasterYiHighlander") then
		local aaDamage = _G.SDK.Damage:GetAutoAttackDamage(myHero, target)
		if not inAARange or target.health + target.shieldAD > aaDamage * 2 then
			Control.CastSpell(HK_R)
			return
		end
	end

	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		if self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			local qKills = self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAP
			if not inAARange or qKills then
				Control.CastSpell(HK_Q, target)
				lastQ = GetTickCount()
			end
		end
	end
end

function ClassicMasterYi:Harass()
	if not Menu.Harass.Q:Value() or not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) and self:CanUseQ(target, true) then
		Control.CastSpell(HK_Q, target)
		lastQ = GetTickCount()
	end
end

function ClassicMasterYi:LaneClear()
	if not Menu.Clear.SpellFarm:Value() or not Menu.Clear.LaneClear.Q:Value() or not IsReady(_Q) then return end
	if IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
			if GetMinionCount(300, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() then
				Control.CastSpell(HK_Q, minion)
				lastQ = GetTickCount()
				return
			end
		end
	end
end

function ClassicMasterYi:JungleClear()
	if not Menu.Clear.SpellFarm:Value() or not Menu.Clear.JungleClear.Q:Value() or not IsReady(_Q) then return end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local monster = monsters[1]
	if IsValid(monster) and monster.pos2D.onScreen then
		Control.CastSpell(HK_Q, monster)
		lastQ = GetTickCount()
	end
end

function ClassicMasterYi:AutoW()
	if not Menu.Misc.AutoW:Value() or not IsReady(_W) or myHero.maxHealth <= 0 then return false end
	local hpPercent = myHero.health / myHero.maxHealth * 100
	if hpPercent <= Menu.Misc.WHP:Value() and GetEnemyCount(Menu.Misc.WRange:Value(), myHero.pos) > 0 then
		Control.CastSpell(HK_W)
		self.meditateStart = Game.Timer()
		self.wasMeditating = true
		return true
	end
	return false
end

function ClassicMasterYi:Flee()
	if Menu.Misc.FleeR:Value() and IsReady(_R) and not HaveBuff(myHero, "Jade_MasterYiHighlander") then
		Control.CastSpell(HK_R)
	end
end

function ClassicMasterYi:KillSteal()
	if not Menu.KillSteal.Q:Value() or not IsReady(_Q) or lastQ + 250 >= GetTickCount() then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pos2D.onScreen and self:CanUseQ(target, Menu.Combo.QSafe:Value()) then
			if self:GetQDmg(target) >= target.health + target.hpRegen + target.shieldAP then
				Control.CastSpell(HK_Q, target)
				lastQ = GetTickCount()
				return
			end
		end
	end
end

function ClassicMasterYi:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local damage = ({100, 150, 200, 250, 300})[level] + myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, damage)
end

function ClassicMasterYi:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		Draw.Text(Menu.Clear.SpellFarm:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
end

ClassicMasterYi()
