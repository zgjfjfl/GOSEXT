local Version = 1.03

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local function DrawLine3D(x1, y1, z1, x2, y2, z2, width, color)
	local xyz_1 = Vector(x1, y1, z1):To2D()
	local xyz_2 = Vector(x2, y2, z2):To2D()
	Draw.Line(xyz_2.x, xyz_2.y, xyz_1.x, xyz_1.y, width or 1, color or Draw.Color(255, 255, 255, 255))
end

local function DrawRectangleOutline(startPos, endPos, width, color, ex)     
	local c1 = startPos+Vector(Vector(endPos)-startPos):Perpendicular():Normalized()*width     
	local c2 = startPos+Vector(Vector(endPos)-startPos):Perpendicular2():Normalized()*width     
	local c3 = endPos+Vector(Vector(startPos)-endPos):Perpendicular():Normalized()*width     
	local c4 = endPos+Vector(Vector(startPos)-endPos):Perpendicular2():Normalized()*width     
	DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,math.ceil(width/ex),color)     
	DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,math.ceil(width/ex),color)     
	DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color)     
	DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color) 
end 

---------------------------------------------

class "zgDrMundo"

function zgDrMundo:__init()
	print("Zgjfjfl AIO - DrMundo Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	WSpell = { Range =  325 }
	E2Spell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 800, Speed = 2000, Collision = false}
end

function zgDrMundo:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "QRange", name = "Use Q| Max Range", value = 990, min = 5, max = 1050, step = 10})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoR"})
	Menu.Auto:MenuElement({id = "R", name = "Auto R", value = true})
	Menu.Auto:MenuElement({id = "REnemy", name = "Auto R| Only enemies nearby ", value = true})
	Menu.Auto:MenuElement({id = "RHp", name = "Auto R| Self Hp% less than", value = 20, min = 5, max = 100, step = 5})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.LastHit:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = true})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E2] Range", value = false})
	Menu.Draw:MenuElement({id = "E2", name = "Draw E2 Rectangle", value = false})
end

function zgDrMundo:OnTick()
	E2Spell.Delay = myHero.attackData.WindUpTime
	if IsCasting() or ShouldWait() then return end
	self:AutoR()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LastHit()
		self:LaneClear()
		self:JungleClear()
	elseif mode == "LastHit" then
		self:LastHit()
	end
end

function zgDrMundo:OnPostAttack()
	local target = _G.SDK.Orbwalker:GetTarget()
	if target then
		if GetMode() == "Combo" then
			if Menu.Combo.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E)
			end
		end
		if GetMode() == "LaneClear" and target.team == 300 then
			if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E)
			end
		end
	end
end

function zgDrMundo:AutoR()
	if Menu.Auto.R:Value() and IsReady(_R) then
		if not Menu.Auto.REnemy:Value() or GetEnemyCount(QSpell.Range, myHero.pos) > 0 then
			if myHero.health / myHero.maxHealth <= Menu.Auto.RHp:Value() / 100 then
				Control.CastSpell(HK_R)
			end
		end
	end
end

function zgDrMundo:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.QRange:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "DrMundoW" then
		local target = GetTarget(WSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_W)
		end
	end
end

function zgDrMundo:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.QRange:Value())
		if IsValid(target) and target.pos2D.onScreen then
			self:CastQ(target)
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(E2Spell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			if target.distance <= 320 then
				Control.CastSpell(HK_E)
			else
				self:CastE2(target)
			end
		end
	end
end

function zgDrMundo:CastE2(target)
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(350)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.health <= self:GetEDmg(minion) then
			local Pred = GGPrediction:SpellPrediction(E2Spell)
			Pred:GetPrediction(target, minion)
			if Pred:CanHit(3) then
				local predPos = Pred.CastPosition
				local endPos = myHero.pos:Extended(minion.pos, E2Spell.Range)
				local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(predPos, minion.pos, endPos)
				local width = E2Spell.Radius/2 + target.boundingRadius
				if isOnSegment and GGPrediction:IsInRange(point, predPos, width) then
					_G.SDK.Orbwalker:SetMovement(false)
					_G.SDK.Orbwalker:SetAttack(false)
					Control.CastSpell(HK_E)
					Control.Attack(minion)
					DelayAction(function()
						_G.SDK.Orbwalker:SetMovement(true)
						_G.SDK.Orbwalker:SetAttack(true)
					end, E2Spell.Delay)
					return
				end
			end
		end
	end
end

function zgDrMundo:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgDrMundo:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Menu.Combo.QRange:Value())
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.pos2D.onScreen and not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
				local Hp = _G.SDK.HealthPrediction:GetPrediction(minion, minion.distance / QSpell.Speed + QSpell.Delay)
				local QDmg = self:GetQDmg(minion)
				local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius/2, {GGPrediction.COLLISION_MINION}, minion.networkID)
				if QDmg > Hp and collisionCount == 0 then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgDrMundo:LaneClear()
	if Menu.Clear.SpellFarm:Value() and Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(E2Spell.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if myHero.pos:DistanceTo(minion.pos) <= 350 then
					local hitCount = 1
					for _, otherMinion in ipairs(minions) do
						if IsValid(otherMinion) and otherMinion.networkID ~= minion.networkID then
							local endPos = myHero.pos:Extended(minion.pos, E2Spell.Range)
							local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(otherMinion.pos, minion.pos, endPos)
							local width = E2Spell.Radius/2 + otherMinion.boundingRadius
							if isOnSegment and GGPrediction:IsInRange(point, otherMinion.pos, width) then
								hitCount = hitCount + 1
							end
						end
					end
					if hitCount >= Menu.Clear.LaneClear.ECount:Value() and minion.health < self:GetEDmg(minion) then
						Control.CastSpell(HK_E)
						Control.Attack(minion)
					end
				end
			end
		end
	end
end

function zgDrMundo:JungleClear()
	if Menu.Clear.SpellFarm:Value() and Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetMonsters(Menu.Combo.QRange:Value())
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
	if Menu.Clear.JungleClear.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "DrMundoW" then
		local minions = _G.SDK.ObjectManager:GetMonsters(WSpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) then
				Control.CastSpell(HK_W)
			end
		end
	end
end

function zgDrMundo:GetBonusHealth()
	local level = myHero.levelData.lvl
	local baseHP = myHero.baseHP + myHero.hpPerLevel * (level - 1) * (0.7025 + 0.0175 * (level - 1))
	return myHero.maxHealth - baseHP
end

function zgDrMundo:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({20, 22.5, 25, 27.5, 30})[level] / 100 * target.health
	QDmg = math.max(QDmg, ({80, 130, 180, 230, 280})[level])
	if target.type == Obj_AI_Minion and target.team == 300 then
		QDmg = math.min(QDmg, ({300, 375, 450, 535, 600})[level])
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgDrMundo:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local missingHealthPercent = (myHero.maxHealth - myHero.health) / myHero.maxHealth
	local EDmg = (myHero.totalDamage + ({5, 15, 25, 35, 45})[level] + 0.05 * self:GetBonusHealth()) * (1 + math.min(missingHealthPercent * 0.57, 0.4))
	if target.type == Obj_AI_Minion then
		if target.team == 300 then
			EDmg = EDmg * 2
		else
			EDmg = EDmg * 1.4
		end
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, EDmg)
end

function zgDrMundo:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(QSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgDrMundo:Draw()
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
	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, Menu.Combo.QRange:Value(), 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.W:Value() then
		Draw.Circle(myHero.pos, WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() then
		Draw.Circle(myHero.pos, E2Spell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	local target = GetTarget(800)
	if target == nil or not IsReady(_E) then return end
	if Menu.Draw.E2:Value() then
		for _, minion in ipairs(_G.SDK.ObjectManager:GetEnemyMinions(350)) do
			if IsValid(minion) then
				if minion.health <= self:GetEDmg(minion) then
					local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(minion.pos, myHero.pos, target.pos)
					if isOnSegment and GGPrediction:IsInRange(point, minion.pos, 50) then
						Draw.Circle(minion.pos, 45, 3, Draw.Color(255, 255, 0, 0))
					end
				end
			end
		end
		DrawRectangleOutline(myHero.pos, myHero.pos:Extended(target.pos, E2Spell.Range), 25, Draw.Color(255,255,255,255), 50)
	end
end

zgDrMundo()
