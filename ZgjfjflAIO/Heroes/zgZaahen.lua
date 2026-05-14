local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgZaahen"

function zgZaahen:__init()
	print("Zgjfjfl AIO - Zaahen Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
	WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 35, Range = 850, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 375, Range = 350, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.1, Radius = 550, Range = 600, Speed = math.huge, Collision = false}
end

function zgZaahen:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "Wrange", name = "Use W| Max Range", value = 750, min = 200, max = 850, step = 10})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E| Outer edge range", value = 300, min = 200, max = 375, step = 5})
	Menu.Combo:MenuElement({id = "R", name = "Use R", value = true})
	Menu.Combo:MenuElement({id = "Rmode", name = "Use R| Mode: ", value = 1, drop = {"After Q2 Knockup", "After W Pull", "Killable"}})
	Menu.Combo:MenuElement({id = "Rsm", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Combo:MenuElement({id = "RCount", name = "Semi-manual R| CanHit Targets", value = 2, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Harass:MenuElement({id = "Wrange", name = "Use W| Max Range", value = 750, min = 200, max = 850, step = 10})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
	Menu.Flee:MenuElement({id = "E", name = "Use E| Dash to mouse", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
end

function zgZaahen:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
    local Mode = GetMode()
	if IsValid(target) and IsReady(_Q) and lastQ + 300 < GetTickCount() then
		if Mode == "LaneClear" and Menu.Clear.SpellFarm:Value() and target.type == Obj_AI_Minion then
			if target.team == 300 then
				if Menu.Clear.JungleClear.Q:Value() then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			else
				if Menu.Clear.LaneClear.Q:Value() and not IsUnderTurret(myHero) then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			end
		end
	end
end

function zgZaahen:Tick()
	if HaveBuff(myHero,"zaahenrlockout") then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
		_G.SDK.Orbwalker:SetMovement(true)
	end
	if IsCasting() or ShouldWait() then return end
	self:SemiManualR()
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

function zgZaahen:SemiManualR()
	if Menu.Combo.Rsm:Value() and IsReady(_R) then
		local mainTarget = GetTarget(RSpell.Range + RSpell.Radius)
		if IsValid(mainTarget) then
			self:CastRWithMainTarget(mainTarget)
		end
	end
end

function zgZaahen:CastRWithMainTarget(mainTarget)
	local pred = GGPrediction:SpellPrediction(RSpell)
	local aoeResults = pred:GetAOEPrediction(myHero.pos)
	local bestResult = nil
	for i, result in ipairs(aoeResults) do
		if result.Unit.networkID == mainTarget.networkID then
			if not bestResult or result.Count > bestResult.Count then
				bestResult = result
			end
		end
	end
	if bestResult and bestResult.Count >= Menu.Combo.RCount:Value() then
		Control.CastSpell(HK_R, bestResult.CastPosition)
	end
end

function zgZaahen:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
		local pos = myHero.pos:DistanceTo(Vector(mousePos)) > ESpell.Range and myHero.pos + (mousePos - myHero.pos)
					or myHero.pos + (mousePos - myHero.pos):Normalized() * (ESpell.Range + 100)
		Control.CastSpell(HK_E, pos)
		lastE = GetTickCount()
	end
end

function zgZaahen:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 300 < GetTickCount() then
		local target = GetTarget(myHero.range + myHero.boundingRadius * 2 + 50)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
		local target = GetTarget(ESpell.Range + ESpell.Radius)
		if IsValid(target) and not HaveBuff(target, "zaahenwpull") then
			local outerRange = Menu.Combo.Erange:Value()
			local dashTime = math.min(math.abs(target.distance - outerRange), ESpell.Range) / ESpell.Speed
			local predPos = target:GetPrediction(MathHuge, dashTime)
			local castPos = predPos:Extended(myHero.pos, outerRange)
			if castPos:DistanceTo(myHero.pos) <= ESpell.Range then
				Control.CastSpell(HK_E, castPos)
				lastE = GetTickCount()
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(Menu.Combo.Wrange:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) then
		local target = GetTarget(RSpell.Range)
		if IsValid(target) then
			local Rmode = Menu.Combo.Rmode:Value()
			local conditionMet = 
				(Rmode == 1 and HaveBuff(target, "zaahenqknockup")) or
				(Rmode == 2 and HaveBuff(target, "zaahenwpull")) or
				(Rmode == 3 and (target.health + target.shieldAD < self:GetRDmg(target)))
			if conditionMet then
				self:CastR(target)
			end
        end
	end
end

function zgZaahen:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(Menu.Harass.Wrange:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
end

function zgZaahen:CastW(target)
	local Pred = GGPrediction:SpellPrediction(WSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_W, Pred.CastPosition)
	end
end

function zgZaahen:CastR(target)
	local Pred = GGPrediction:SpellPrediction(RSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_R, Pred.CastPosition)
	end
end

function zgZaahen:GetRDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 150 * rlvl + 100
	local adDmg = myHero.bonusDamage * 2.0
	local rDmg = baseDmg + adDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg)
end

function zgZaahen:LaneClear()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(ESpell.Range + ESpell.Radius)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		local eCount = 0
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if minion.distance < ESpell.Radius and minion.distance > 200 then
					eCount = eCount + 1
				end
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
					if eCount >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E, myHero)
						lastE = GetTickCount()
					end
				end
				if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, WSpell.Speed, WSpell.Delay, WSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.WCount:Value() then
						Control.CastSpell(HK_W, minion)
					end
				end
			end
		end
	end
end

function zgZaahen:JungleClear()
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(ESpell.Range + ESpell.Radius)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
					Control.CastSpell(HK_W, minion)
				end
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and lastE + 300 < GetTickCount() then
					local dashTime = math.min(math.abs(minion.distance - 300), ESpell.Range) / ESpell.Speed
					local predPos = minion:GetPrediction(MathHuge, dashTime)
					local castPos = predPos:Extended(myHero.pos, 300)
					if castPos:DistanceTo(myHero.pos) <= ESpell.Range then
						Control.CastSpell(HK_E, castPos)
						lastE = GetTickCount()
					end
				end
			end
		end
	end
end

function zgZaahen:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.W:Value() then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() then
		Draw.Circle(myHero.pos, ESpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgZaahen()