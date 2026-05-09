local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgMissFortune"

function zgMissFortune:__init()
	print("Zgjfjfl AIO - MissFortune Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	-- _G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.QSpell = {Delay = 0.25, Range = 550, Speed = 1400}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 200, Range = 1150, Speed = math.huge, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.375, Radius = 40, Range = 1350, Speed = 2000, Collision = false}
	-- LastAttackId = 0
end

function zgMissFortune:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Q2", name = "Use Bounce Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "ECount", name = "If E CanHit Counts >= ", value = 3, min = 1, max = 5, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})

	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "Q", name = "Auto Q KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Qangle", name = "Bounce Q's Angle", value = 60, min = 60, max = 80, step = 5})
	-- Menu.Misc:MenuElement({id = "newTarget", name = "Try change focus after attack(Combo)", toggle = true, value = false})
	Menu.Misc:MenuElement({id = "R", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw Q Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "R", name = "Draw R Range", toggle = true, value = false})
end

function zgMissFortune:Tick()
	if ShouldWait() then
		return
	end

	self.QSpell.Range = myHero.range + myHero.boundingRadius*2
	self.QSpell.Delay = myHero.attackData.windUpTime

	if HaveBuff(myHero, "missfortunebulletsound") then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
		return
	else
		_G.SDK.Orbwalker:SetAttack(true)
		_G.SDK.Orbwalker:SetMovement(true)
	end
	
	-- self:newTarget()

	if IsCasting() then return end

	self:SemiRLogic()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

function zgMissFortune:OnPreAttack(args)
	local target = args.Target
	-- local manaPercentage = myHero.mana / myHero.maxMana
	if GetMode() == "Combo" and IsValid(target) and target.type == Obj_AI_Hero then
		if Menu.Combo.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W)
		end
	end
	if GetMode() == "LaneClear" and IsValid(target) and target.type == Obj_AI_Minion then
		local isJungleMinion = target.team == 300
		local isLaneMinion = target.team ~= 300
		-- local minMana = isJungleMinion and Menu.Clear.JungleClear.Mana:Value() or Menu.Clear.LaneClear.Mana:Value()
		if --[[manaPercentage >= minMana / 100 and ]]Menu.Clear.SpellFarm:Value() then
			if (isJungleMinion and Menu.Clear.JungleClear.W:Value() or isLaneMinion and Menu.Clear.LaneClear.W:Value()) and IsReady(_W) then
				Control.CastSpell(HK_W)
			end
		end
	end
end

-- function zgMissFortune:OnPostAttack()
	-- local target = _G.SDK.Orbwalker:GetTarget()
	-- if target then
		-- LastAttackId = target.networkID
	-- end
-- end

function zgMissFortune:SemiRLogic()
	if Menu.Misc.R:Value() and IsReady(_R) and lastR + 3000 < GetTickCount() then
		local Rtarget = GetTarget(self.RSpell.Range)
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			Control.CastSpell(HK_R, Rtarget)
			lastR = GetTickCount()
		end
	end
end

function zgMissFortune:KillSteal()
	if Menu.KillSteal.Q:Value() and IsReady(_Q) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range+500)
		for i, target in ipairs(enemies) do
			if IsValid(target) and (target.health + target.shieldAD) < self:GetQDmg(target) then
				self:QLogic(target, true)
			end
		end
	end
end

-- function zgMissFortune:newTarget()
	-- if Menu.Misc.newTarget:Value() and GetMode() == "Combo" then
		-- local orbT = _G.SDK.Orbwalker:GetTarget()
		-- if IsValid(orbT) and orbT.type == Obj_AI_Hero and orbT.networkID == LastAttackId then
			-- if orbT.health > _G.SDK.Damage:GetAutoAttackDamage(myHero, orbT) * 2 then
				-- local ta = nil
				-- local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)				--aarange == qrange
				-- for _, enemy in ipairs(enemies) do
					-- if IsValid(enemy) and enemy.networkID ~= LastAttackId then
						-- ta = enemy
						-- break
					-- end
				-- end
				-- if ta then
					-- _G.SDK.Orbwalker.ForceTarget = ta
				-- else
					-- _G.SDK.Orbwalker.ForceTarget = nil
				-- end
			-- else
				-- _G.SDK.Orbwalker.ForceTarget = nil
			-- end
		-- end
	-- else
		-- _G.SDK.Orbwalker.ForceTarget = nil
	-- end
	-- if _G.SDK.Orbwalker.ForceTarget and not _G.SDK.Data:IsInAutoAttackRange(myHero, _G.SDK.Orbwalker.ForceTarget) then
		-- _G.SDK.Orbwalker.ForceTarget = nil
	-- end
-- end

function zgMissFortune:Combo()
	if IsReady(_Q) then
		local Qtarget = GetTarget(self.QSpell.Range+500)
		if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
			if Menu.Combo.Q:Value() then
				self:QLogic(Qtarget, Menu.Combo.Q2:Value())
			end
		end
	end

	local Etarget = GetTarget(self.ESpell.Range)
	if IsValid(Etarget) and Etarget.pos2D.onScreen then
		if Menu.Combo.E:Value() and IsReady(_E) and not _G.SDK.Data:IsInAutoAttackRange(myHero, Etarget) then
			if myHero.mana > myHero:GetSpellData(_R).mana + myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_W).mana + myHero:GetSpellData(_E).mana then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	end
end

function zgMissFortune:Harass()
	--if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		if IsReady(_Q) then
			local Qtarget = GetTarget(self.QSpell.Range+500)
			if IsValid(Qtarget) and Qtarget.pos2D.onScreen then
				if Menu.Harass.Q:Value() then
					self:QLogic(Qtarget, Menu.Harass.Q2:Value())
				end
			end
		end

		local Etarget = GetTarget(self.ESpell.Range)
		if IsValid(Etarget) and Etarget.pos2D.onScreen then
			if Menu.Harass.E:Value() and IsReady(_E) then
				self:CastGGPred(HK_E, Etarget)
			end
		end
	--end
end

function zgMissFortune:FarmHarass()
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgMissFortune:LaneClear()
	if IsUnderTurret(myHero) then return end
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
					if GetMinionCount(self.ESpell.Radius, minion.pos) >= Menu.Clear.LaneClear.ECount:Value() then
						Control.CastSpell(HK_E, minion)
					end
				end
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					if #minions > 2 and minions[1].pos:DistanceTo(myHero.pos) < self.QSpell.Range then
						Control.CastSpell(HK_Q, minions[1])
					end
				end
			end
		end
	end
end

function zgMissFortune:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.E:Value() and IsReady(_E) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_E, minion)
					else
						if GetMinionCount(self.ESpell.Radius, minion.pos) > 2 then
							Control.CastSpell(HK_E, minion)
						end
					end
				end
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(minion.pos) < self.QSpell.Range then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function zgMissFortune:QLogic(target, UseQBounce)
	if target == nil then return end
	if myHero.pos:DistanceTo(target.pos) <= self.QSpell.Range then
		Control.CastSpell(HK_Q, target)
	else
		if UseQBounce then
			local tarPred = target:GetPrediction(self.QSpell.Speed, self.QSpell.Delay)
			local bounceFirstTar = {}
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
			local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)
			
			local objTable = {}
			for i = 1, #minions do
				local minion = minions[i]
				table.insert(objTable, minion)
			end
			for i = 1, #enemies do
				local enemy = enemies[i]
				table.insert(objTable, enemy)
			end
			
			for i = 1, #objTable do
				local obj = objTable[i]
				if IsValid(obj) and obj.networkID ~= target.networkID then
					local angle = Menu.Misc.Qangle:Value()/2
					local objPred = obj:GetPrediction(self.QSpell.Speed, self.QSpell.Delay)
					local middlePos = myHero.pos:Extended(objPred, myHero.pos:DistanceTo(objPred) + 500)
					local leftVector = (middlePos - objPred):Rotated(0, angle * math.pi / 180, 0)
					local rightVector = (middlePos - objPred):Rotated(0, -angle * math.pi / 180, 0)
					local targetVector = tarPred - objPred
					-- Method 1 -- EXT API: Vector:Angle(Vector) broken, so use Method 2
					-- local Angle1 = leftVector:Angle(rightVector)
					-- local Angle2 = leftVector:Angle(targetVector)
					-- local Angle3 = rightVector:Angle(targetVector)
					-- if objPred:DistanceTo(tarPred) < 420 and Angle2 < Angle1 and Angle3 < Angle1 then
					-- Method 2
					local dotLeft = targetVector:DotProduct(leftVector)
					local dotRight = targetVector:DotProduct(rightVector)
					local crossLeft = targetVector:CrossProduct(leftVector)
					local crossRight = rightVector:CrossProduct(targetVector)
					if objPred:DistanceTo(tarPred) < 420 and dotLeft > 0 and dotRight > 0 and crossLeft * crossRight > 0 then
						bounceFirstTar[#bounceFirstTar + 1] = {tar = obj, dis = objPred:DistanceTo(tarPred)}
					end
				end
			end

			if #bounceFirstTar > 0 then
				table.sort(bounceFirstTar, function(a, b) return a.dis < b.dis end)
				local starTar = bounceFirstTar[1].tar
				local starPos = starTar.pos:Extended(tarPred, starTar.boundingRadius*2)
				local _, _, collisionCount = GGPrediction:GetCollision(starPos, tarPred, self.QSpell.Speed, self.QSpell.Delay, 60, {GGPrediction.COLLISION_MINION}, target.networkID)
				if collisionCount == 0 then
					Control.CastSpell(HK_Q, starTar)
				end
			end
		end
	end
end

function zgMissFortune:CastGGPred(spell, unit)
	if spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function zgMissFortune:GetQDmg(target)
		local level = myHero:GetSpellData(_Q).level
		local QDmg = ({20, 45, 70, 95, 120})[level] + myHero.totalDamage + 0.35 * myHero.ap
		return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, QDmg)
end

function zgMissFortune:Draw()
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

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgMissFortune()