local Version = 1.04

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgGalio"

function zgGalio:__init()
	print("Zgjfjfl AIO - Galio Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 825, Speed = 1400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 160, Range = 650, Speed = 2300, Collision = false}
	self.wSpell = {Range = 450}
end

function zgGalio:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto W"})
		Menu.Auto:MenuElement({id = "Wdash", name = "[W] Auto if enemy dash to me", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Waoe", name = "[W] Auto if many enemies in W range", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "WaoeCount", name = "Auto W enemies count", value = 3, min = 1, max = 5, step = 1})
		Menu.Auto:MenuElement({id = "Wtime", name = "W Channel Time(s)", value = 2, min = 0 , max = 2 , step = 0.25})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q] auto kills", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "[E] to mouse", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range in minimap", toggle = true, value = true})
end

function zgGalio:Tick()
	if ShouldWait() then
		return
	end
	if myHero:GetSpellData(_W).toggleState == 2 then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:Flee()
	end
	self:AutoW()
	self:KillSteal()
end

function zgGalio:Combo()
	local hasPassive = HaveBuff(myHero, "galiopassivebuff")
	local target = GetTarget(self.wSpell.Range)
	if hasPassive and IsValid(target) then
		return
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			self:CastW(Menu.Combo.Wtime:Value())
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			local pred = GGPrediction:SpellPrediction(self.eSpell)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				local wallPos = FindFirstWallCollision(myHero.pos, pred.CastPosition)
				if wallPos == nil then  --	if not MapPosition:intersectsWall(myHero.pos, pred.CastPosition) then
					Control.CastSpell(HK_E, pred.CastPosition)
				end
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			local pred = GGPrediction:SpellPrediction(self.qSpell)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_Q, pred.CastPosition)
			end
		end
	end
end

function zgGalio:Harass()
	if not Menu.Harass.Q:Value() or not IsReady(_Q) then return end
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.qSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(3) then
			Control.CastSpell(HK_Q, pred.CastPosition)
		end
	end
end

function zgGalio:AutoW()
	if not IsReady(_W) then return end
	if Menu.Auto.Wdash:Value() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				if enemy.pathing.isDashing and not HasInvalidDashBuff(enemy) then
					if enemy.pathing.endPos:DistanceTo(myHero.pos) < self.wSpell.Range then
						self:CastW(Menu.Auto.Wtime:Value())
					end
				end
			end
		end
	end
	if Menu.Auto.Waoe:Value() then
		if GetEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Auto.WaoeCount:Value() then
			self:CastW(Menu.Auto.Wtime:Value())
		end
	end
end

function zgGalio:CastW(time)
	if myHero:GetSpellData(_W).toggleState == 1 then
		Control.KeyDown(HK_W)
	end
	DelayAction(function() Control.KeyUp(HK_W) end, time)
end

function zgGalio:Flee()
	if Menu.Flee.E:Value() and IsReady(_E) then
		local pos = myHero.pos + (mousePos - myHero.pos)
		Control.CastSpell(HK_E, pos)
	end
end

function zgGalio:KillSteal()
	if not IsReady(_Q) or not Menu.KS.Q:Value() then return end
	local targets = _G.SDK.ObjectManager:GetEnemyHeroes(self.qSpell.Range)
	for _, target in ipairs(targets) do
		if IsValid(target) then
			if self:GetQDmg(target) >= target.health then
				local pred = GGPrediction:SpellPrediction(self.qSpell)
				pred:GetPrediction(target, myHero)
				if pred:CanHit(3) then
					Control.CastSpell(HK_Q, pred.CastPosition)
				end
			end
		end
	end
end

function zgGalio:GetQDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 35 * qlvl + 35
	local qapDmg = myHero.ap * 0.7
	local qDmg = qbaseDmg + qapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg) 
end

function zgGalio:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, Draw.Color(225, 225, 0, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, 3250 + 750*myHero:GetSpellData(_R).level, 1, Draw.Color(200,50,180,230))
	end
end

zgGalio()
