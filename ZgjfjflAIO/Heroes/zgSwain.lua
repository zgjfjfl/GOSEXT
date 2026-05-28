local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSwain"

function zgSwain:__init()
	print("Zgjfjfl AIO - Swain Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.25, Angle = 32, Range = 725, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 325, Range = 5500, Speed = math.huge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 85, Range = 950, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgSwain:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = false})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Combo [Q]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Waoe", name = "Combo [W] AoE", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "WCount", name = "[W] hit x targets", value = 3, min = 2, max = 5, step = 1})
	Menu.Combo:MenuElement({id = "Wsm", name = "W Semi-Manual Key(Only Cursor near)", key = string.byte("T")})
	Menu.Combo:MenuElement({id = "E", name = "Combo [E]", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "ERange", name = "E Range Set", value = 900, min = 500, max = 950, step = 10})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Harass [Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q If Hit X Minions", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W If Hit X Minions", value = 4, min = 1, max = 10, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "Q", name = "Auto [Q] on CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "W", name = "Auto [W] on CC", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Wslow", name = "Auto [W] on Slow", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "Wgap", name = "Auto [W] AnitGap", toggle = true, value = true})
	Menu.Auto:MenuElement({id = "E2", name = "Auto [E2] pulls", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "Draw [W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", toggle = true, value = false})
end

function zgSwain:Tick()
	self.WSpell.Range = 5000 + 500*myHero:GetSpellData(_W).level
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
    local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
	if Menu.Combo.Wsm:Value() and IsReady(_W) then
		self:SemiManualW()
	end
	self:Auto()
end

function zgSwain:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgSwain:SemiManualW()
	for i, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			if enemy.pos:DistanceTo(mousePos) < 500 and myHero.pos:DistanceTo(enemy.pos) <= self.WSpell.Range then
				self:CastGGPred(HK_W, enemy)
				break
			end
		end
	end
end

function zgSwain:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "SwainE" then
		local target = GetTarget(Menu.Combo.ERange:Value())
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range - 50)
		if IsValid(target) and target.pos2D.onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
	local Wtarget = GetTarget(self.WSpell.Range)
	if IsValid(Wtarget) and Wtarget.pos2D.onScreen then
		if Menu.Combo.Waoe:Value() and IsReady(_W) then
			local minHitCount = Menu.Combo.WCount:Value()
			CastSpellAOE(HK_W, self.WSpell, minHitCount, myHero, Wtarget)
		end
	end
end	

function zgSwain:Harass()
	local target = GetTarget(self.QSpell.Range - 50)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function zgSwain:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgSwain:LaneClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	if IsUnderTurret(myHero) then return end
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
			if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
				local bestTarget = nil
				local maxHits = 0
				local hitCount = GetMinionCount(self.WSpell.Radius, minion.pos)
				if hitCount > maxHits then
					maxHits = hitCount
					bestTarget = minion
				end
				if bestTarget and maxHits >= Menu.Clear.LaneClear.WCount:Value() then
					Control.CastSpell(HK_W, bestTarget)
				end
			end
			if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
				local bestPos = nil
				local maxHits = 0
				local castDir = Vector(minion.pos - myHero.pos):Normalized()
				local halfAngle = math.rad(self.QSpell.Angle / 2)
				local hits = 1
				for _, checkMinion in ipairs(minions) do
					if IsValid(checkMinion) and checkMinion.team ~= 300 and not checkMinion.pathing.hasMovePath then
						local toMinion = Vector(checkMinion.pos - myHero.pos)
						local dist = toMinion:Len()
						if dist <= self.QSpell.Range and dist > 0 then
							local toMinionDir = toMinion:Normalized()
							local angle = math.acos(math.max(-1, math.min(1, castDir:DotP(toMinionDir))))
							if angle <= halfAngle then
								hits = hits + 1
							end
						end
					end
				end				
				if hits > maxHits then
					maxHits = hits
					bestPos = minion.pos
				end
				if bestPos and maxHits >= Menu.Clear.LaneClear.QCount:Value() then
					Control.CastSpell(HK_Q, bestPos)
				end
			end
		end
	end
end

function zgSwain:JungleClear()
	if not Menu.Clear.SpellFarm:Value() then return end
	local monsters = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and monster.team == 300 then
			if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
				Control.CastSpell(HK_W, monster)
			end
			if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
				Control.CastSpell(HK_Q, monster)
			end
		end
	end
end

function zgSwain:Auto()
	for i, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if IsValid(enemy) and enemy.pos2D.onScreen then
			local buff, buffData = GetBuffData(enemy, "swaineroot")
			if Menu.Auto.E2:Value() and IsReady(_E) and myHero:GetSpellData(_E).name == "SwainE2" and buff and buffData.duration < 1 then
				Control.CastSpell(HK_E)
			end
			if Menu.Auto.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(enemy.pos) < self.QSpell.Range and IsHardCC(enemy) then
				self:CastGGPred(HK_Q, enemy)
			end
			if Menu.Auto.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(enemy.pos) <= self.WSpell.Range and IsHardCC(enemy) then
				if HaveBuff(enemy, "swaineroot") and myHero:GetSpellData(_E).name == "SwainE2" then
					if myHero.pos:DistanceTo(enemy.pos) < 290 then
						self:CastGGPred(HK_W, enemy)
					else
						local castPos = enemy.pos:Extended(myHero.pos, 250)
						Control.CastSpell(HK_W, castPos)
					end
				else
					self:CastGGPred(HK_W, enemy)
				end
			end
			if Menu.Auto.Wslow:Value() and IsReady(_W) and myHero.pos:DistanceTo(enemy.pos) <= self.WSpell.Range and IsSlow(enemy) then
				self:CastGGPred(HK_W, enemy)
			end
			if Menu.Auto.Wgap:Value() and myHero.pos:DistanceTo(enemy.pos) < 1500 and enemy.pathing.isDashing then
				if myHero.pos:DistanceTo(enemy.pathing.endPos) < myHero.range and IsReady(_W) then
					Control.CastSpell(HK_W, enemy.pathing.endPos)
				end
			end
		end
	end
end

function zgSwain:CastGGPred(spell, unit)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(unit, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_W then
		local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
		WPrediction:GetPrediction(unit, myHero)
		if WPrediction:CanHit(3) then
			Control.CastSpell(HK_W, WPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(unit, myHero)
		if EPrediction:CanHit(3) then
			local endPos = myHero.pos + (EPrediction.CastPosition - myHero.pos):Normalized() * self.ESpell.Range
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(endPos, EPrediction.CastPosition, 1400, 0.1, self.ESpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
			if collisionCount == 0 then
				Control.CastSpell(HK_E, EPrediction.CastPosition)
			end
		end	
	end
end

function zgSwain:Draw()
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgSwain()