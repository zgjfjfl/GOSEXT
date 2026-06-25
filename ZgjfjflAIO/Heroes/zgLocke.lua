local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgLocke"

function zgLocke:__init()
	print("Zgjfjfl AIO - Locke Loaded")
	self.comboMode = 2
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 950, Speed = 1650, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.175, Radius = 150, Range = 425, Speed = math.huge, Collision = false}
	RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 400, Range = 1000, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgLocke:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.13.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "ComboModeKey", name = "Combo Mode Toggle Key", toggle = true, value = true, key = string.byte("M"), tooltip = "Toggle between Priority Q and Priority E", callback = function(newValue)
		if CheckChatBlock(Menu.Combo.ComboModeKey, newValue) then return end
	end})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q| Max Range", value = 850, min = 200, max = 950, step = 10})
	Menu.Combo:MenuElement({id = "W1", name = "Use W1| In AA Range", value = true})
	Menu.Combo:MenuElement({id = "W2", name = "Use W2| Healing", value = false})
	Menu.Combo:MenuElement({id = "W2Percent", name = "W2 Healing| Heath < X%", value = 50, min = 0, max = 100, step = 5})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "E1Range", name = "Use E1| Dash Range", value = 800, min = 400, max = 900, step = 10})
	Menu.Combo:MenuElement({id = "Rkill", name = "Use R| Can Kill", value = true})
	Menu.Combo:MenuElement({id = "RAoe", name = "Use R| AOE", value = true})
	Menu.Combo:MenuElement({id = "RAoeCount", name = "Use R AOE| Min Enemies", value = 3, min = 1, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q| Max Range", value = 850, min = 200, max = 950, step = 10})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = false})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q| LastHit not in AARange", value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E1| Dash to mouse", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "DrawComboMode", name = "Draw Combo Mode Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
end

function zgLocke:Tick()
	QSpell.Delay = myHero.attackData.windUpTime
	if IsCasting() or ShouldWait() then return end
	self:SemiManualR()
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LastHit()
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgLocke:SemiManualR()
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		local target = GetTarget(RSpell.Range + RSpell.Radius)
		if IsValid(target) then
			self:CastR(target)
		end
	end
end

function zgLocke:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
		local pos = myHero.pos:DistanceTo(Vector(mousePos)) > ESpell.Range and myHero.pos + (mousePos - myHero.pos)
					or myHero.pos + (mousePos - myHero.pos):Normalized() * (ESpell.Range + 100)
		Control.CastSpell(HK_E, pos)
		lastE = GetTickCount()
	end
end

function zgLocke:Combo()
	local PriorityQ = Menu.Combo.ComboModeKey:Value()
	local eBuff = HaveBuff(myHero, "lockeeattackready")
	local notQ = not IsReady(_Q) and myHero:GetSpellData(_Q).name ~= "LockeQMissile"
	local notE = not IsReady(_E) and (lastE + 400 < GetTickCount()) and not eBuff
	if PriorityQ then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Qrange:Value())
			if IsValid(target) and not eBuff then
				self:CastQ(target)
			end
		end
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() and notQ then
			local target = GetTarget(Menu.Combo.E1Range:Value())
			if IsValid(target) then
				if target.pos:DistanceTo(myHero.pos) > ESpell.Range then
					Control.CastSpell(HK_E, target)
					lastE = GetTickCount()
				else
					self:CastE(target)
					lastE = GetTickCount()
				end
			end
		end
	else
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
			local target = GetTarget(Menu.Combo.E1Range:Value())
			if IsValid(target) then
				if target.pos:DistanceTo(myHero.pos) > ESpell.Range then
					Control.CastSpell(HK_E, target)
					lastE = GetTickCount()
				else
					self:CastE(target)
					lastE = GetTickCount()
				end
			end
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and notE then
			local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.Qrange:Value())
			if IsValid(target) then
				self:CastQ(target)
			end
		end
	end
	if Menu.Combo.W1:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "LockeW" and lastW + 300 < GetTickCount() then
		local target = GetTarget(myHero.range + myHero.boundingRadius)
		if IsValid(target) and not eBuff then
			if Control.CastSpell(HK_W) then
				lastW = GetTickCount()
			end
		end
	end
	if Menu.Combo.W2:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "LockeWRecast" and lastW + 300 < GetTickCount() then
		if myHero.health / myHero.maxHealth * 100 < Menu.Combo.W2Percent:Value() then
			if Control.CastSpell(HK_W) then
				lastW = GetTickCount()
			end
		end
	end
	if Menu.Combo.Rkill:Value() and IsReady(_R) then
		local target = GetTarget(RSpell.Range)
		if IsValid(target) then
			local hp = (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 6 - self:GetRDmg(target))
			if hp < 0.1 * target.maxHealth and notE and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
				self:CastR(target)
			end
		end
	end
	if Menu.Combo.RAoe:Value() and IsReady(_R) then
		local target = GetTarget(RSpell.Range)
		if IsValid(target) then
			CastSpellAOE(HK_R, RSpell, Menu.Combo.RAoeCount:Value(), myHero, target)
		end
	end
end

function zgLocke:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgLocke:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgLocke:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(QSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgLocke:CastE(target)
	local Pred = GGPrediction:SpellPrediction(ESpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.CastPosition)
	end
end

function zgLocke:CastR(target)
	local Pred = GGPrediction:SpellPrediction(RSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_R, Pred.CastPosition)
	end
end

function zgLocke:GetQDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local baseDmg = 10 * qlvl + 40
	local apDmg = myHero.ap * 0.2
	local qDmg = baseDmg + apDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg)
end

function zgLocke:GetRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 75 * rlvl + 75
	local apDmg = myHero.ap * 0.6
	local rDmg = baseDmg + apDmg + (target.maxHealth * (0.09 + rlvl / 100))
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg)
end

function zgLocke:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) and lastQ + 1000 < GetTickCount() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(QSpell.Range)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
					if minion.health < self:GetQDmg(minion) then
						Control.CastSpell(HK_Q, minion)
						lastQ = GetTickCount()
					end
				end
			end
		end
	end
end

function zgLocke:LaneClear()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(QSpell.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) and lastQ + 1000 < GetTickCount() then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.QCount:Value() then
						Control.CastSpell(HK_Q, minion)
						lastQ = GetTickCount()
					end
				end
			end
		end
	end
end

function zgLocke:JungleClear()
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(QSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					Control.CastSpell(HK_Q, minion)
				end
				if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "lockew" then
					if _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
						Control.CastSpell(HK_W)
					end
				end
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
					if minion.distance < ESpell.Range then
						Control.CastSpell(HK_E, minion)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
end

function zgLocke:Draw()
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
	if Menu.Draw.DrawComboMode:Value() then
		local modeText = Menu.Combo.ComboModeKey:Value() and "Priority Q" or "Priority E"
		Draw.Text("Combo Mode: "..modeText, 16, myHero.pos2D.x-57, myHero.pos2D.y+98, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, QSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgLocke()
