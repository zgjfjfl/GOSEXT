local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgMilio"
function zgMilio:__init()
	print("Zgjfjfl AIO - Milio Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 1500, Speed = 1200, Collision = false}
	self.WSpell = { Range = 650 }
	self.ESpell = { Range = 650 }
	self.RSpell = { Range = 700 }
	self.LastFleeE = 0
end

function zgMilio:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)", value = true})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "QBD", name = "[Q] ball collision minion bounces distance", value = 400, min = 100, max = 500, step = 50})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHP", name = "UseR when ally or self <= X hp%", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({type = MENU, id = "Rhealtarget", name = "UseR On"})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.Combo.Rhealtarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		-- Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 30, min = 0, max = 100})
	Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
		Menu.AutoW:MenuElement({id = "W", name = "[W]Auto heal", toggle = true, value = true})
		Menu.AutoW:MenuElement({id = "WHP", name = "When ally or self <= X hp%", value = 50, min = 0, max = 100, step = 5})
		Menu.AutoW:MenuElement({type = MENU, id = "Wtarget", name = "Use On"})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoW.Wtarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
		Menu.AutoE:MenuElement({id = "E", name = "[E]Auto shield", toggle = true, value = true})
		Menu.AutoE:MenuElement({type = MENU,id = "Etarget", name = "Use On"})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoE.Etarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
		Menu.AutoR:MenuElement({id = "R", name = "[R]Auto clears ally CC", toggle = true, value = true})
        Menu.AutoR:MenuElement({id = "RDelay", name = "Human Delay (seconds)", value = 0.1, min = 0, max = 0.5, step = 0.1})
			Menu.AutoR:MenuElement({type = MENU, id = "CC", name = "CC Types"})			
			Menu.AutoR.CC:MenuElement({ id = "Stun", name = "Use on Stun", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Taunt", name = "Use on Taunt", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Berserk", name = "Use on Berserk", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Snare", name = "Use on Snare", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Fear", name = "Use on Fear", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Charm", name = "Use on Charm", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Suppression", name = "Use on Suppression", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Disarm", name = "Use on Disarm", value = true})
			Menu.AutoR.CC:MenuElement({ id = "Asleep", name = "Use on Asleep", value = true})
		Menu.AutoR:MenuElement({type = MENU,id = "Rclearstarget", name = "Clears target"})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoR.Rclearstarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "AutoQ", name = "AutoQ"})
		Menu.AutoQ:MenuElement({id = "AntiDash", name = "AutoQ Anti-Dash",toggle = true, value = true})
		Menu.AutoQ:MenuElement({type = MENU,id = "AntiTarget", name = "Use On"})
			_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
				Menu.AutoQ.AntiTarget:MenuElement({id = args.charName, name = args.charName, value = true})				
			end)
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "E", name = "Use E to Flee",toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgMilio:OnPreAttack(args)
	local mode = GetMode()
	local target = args.Target
	if Menu.SupportMode:Value() and mode == "Harass" then
		if target.type ~= Obj_AI_Hero then
			args.Process = false
			return
		end
	end
end

function zgMilio:Tick()
	if ShouldWait() then
		return
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
	if Menu.AutoW.W:Value() then
		self:AutoW()
	end
	if Menu.AutoE.E:Value() then
		self:AutoE()
	end
	if Menu.AutoR.R:Value() then
		self:AutoR()
	end
	if Menu.AutoQ.AntiDash:Value() then
		self:AutoQAntiDash()
	end
end

function zgMilio:Combo()
	local target = GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
	local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.RSpell.Range)
		for i, hero in ipairs(heroes) do
			if Menu.Combo.Rhealtarget[hero.charName] and Menu.Combo.Rhealtarget[hero.charName]:Value() then 
				if hero.health/hero.maxHealth <= Menu.Combo.RHP:Value()/100 and GetEnemyCount(1200, hero.pos) > 0 then
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end
			end
		end
	end
end

function zgMilio:Harass()
	local target = GetTarget(1500)
	if IsValid(target) and target.pos2D.onScreen then
		if Menu.Harass.Q:Value() and IsReady(_Q)--[[and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 ]]then
			self:CastQ(target)
		end
	end
end

function zgMilio:Flee()
	if self.LastFleeE + 2500 < GetTickCount() then
		self:CastE(myHero)
		self.LastFleeE = GetTickCount()
	end
end

function zgMilio:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.QSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, Pred.CastPosition, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}, target.networkID)
	    local minion = collisionCount > 0  and collisionObjects[1] or nil
        if myHero.pos:DistanceTo(Pred.CastPosition) > 1100 then
            if isWall == false and collisionCount >= 1 then
                if myHero.pos:DistanceTo(minion.pos) <= 1100 and minion.pos:DistanceTo(Pred.CastPosition) <= Menu.Combo.QBD:Value() then
                    Control.CastSpell(HK_Q, Pred.CastPosition)
                end
            end
        else
            if isWall == false and (collisionCount == 0 or minion.pos:DistanceTo(myHero.pos) <= Menu.Combo.QBD:Value()) then
                Control.CastSpell(HK_Q, Pred.CastPosition)
            end
        end
	end
end

function zgMilio:AutoW()
	if IsReady(_W) and myHero:GetSpellData(_W).name == "MilioW" then
	    local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.WSpell.Range)
		for i, hero in ipairs(heroes) do
			if Menu.AutoW.Wtarget[hero.charName] and Menu.AutoW.Wtarget[hero.charName]:Value() then
				if hero.health/hero.maxHealth <= Menu.AutoW.WHP:Value()/100 and GetEnemyCount(1200, hero.pos) > 0 then
					Control.CastSpell(HK_W, hero)
				end
			end
		end
	end
end

function zgMilio:AutoE()
	if IsReady(_E) and lastE + 250 < GetTickCount() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.ESpell.Range)
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1500)
		for _, ally in ipairs(allies) do
			if IsValid(ally) and Menu.AutoE.Etarget[ally.charName] and Menu.AutoE.Etarget[ally.charName]:Value() then
				local canuse = false
				if IsPoison(ally) and not HaveBuff(ally, "milioqpopup") then
					canuse = true
				else
					for _, enemy in ipairs(enemies) do
						if IsValid(enemy) then
							local spell = enemy.activeSpell
							if spell.valid then 
								if spell.target == ally.handle then
									canuse = true
									break
								else
									local endPos = spell.startPos:Extended(spell.placementPos, spell.range + spell.width)
									local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, endPos, enemy.pos)
									local width = ally.boundingRadius + (spell.width > 0 and spell.width or 0)
									if isOnSegment and GGPrediction:IsInRange(point, ally.pos, width) then
										canuse = true
										break
									end
								end
							end
						end
					end
					if not canuse then
						for _, turret in ipairs(turrets) do
							if turret and turret.targetID == ally.networkID then
								canuse = true
								break
							end
						end
					end
				end
				if canuse then
					self:CastE(ally)
					lastE = GetTickCount()
					break
				end
			end
		end
	end
end

function zgMilio:CastE(unit)
	if unit.isMe then
		Control.KeyDown(0x12)  -- Alt key
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
		Control.KeyUp(0x12)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function zgMilio:AutoR()
	if IsReady(_R) and lastR + 250 < GetTickCount() then
		local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.RSpell.Range)
		for i, hero in ipairs(heroes) do
			if Menu.AutoR.Rclearstarget[hero.charName] and Menu.AutoR.Rclearstarget[hero.charName]:Value() and self:RCleans(hero) then
				DelayAction(function()
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end, Menu.AutoR.RDelay:Value())
				break
			end
		end
	end
end

function zgMilio:RCleans(unit)
	local CleanBuffs = {
		[5] = Menu.AutoR.CC.Stun:Value(),
		[8] = Menu.AutoR.CC.Taunt:Value(),
		[9] = Menu.AutoR.CC.Berserk:Value(),
		[12] = Menu.AutoR.CC.Snare:Value(),
		[22] = Menu.AutoR.CC.Fear:Value(),
		[23] = Menu.AutoR.CC.Charm:Value(),
		[25] = Menu.AutoR.CC.Suppression:Value(),
		[32] = Menu.AutoR.CC.Disarm:Value(),
		[35] = Menu.AutoR.CC.Asleep:Value()
	}	
	
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.count > 0 and buff.duration > 0.5 then
			if CleanBuffs[buff.type] then
				return true
			end
		end
	end
	return false
end

function zgMilio:AutoQAntiDash()
	if IsReady(_Q)and lastQ + 350 < GetTickCount() then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1000)
		for i, enemy in ipairs(enemies) do
			if IsValid(enemy) then
				if enemy.pathing.isDashing and not HasInvalidDashBuff(enemy) then
					if myHero.pos:DistanceTo(enemy.pathing.startPos) > myHero.pos:DistanceTo(enemy.pathing.endPos) then
						local Pred = GGPrediction:SpellPrediction(self.QSpell)
						Pred:GetPrediction(enemy, myHero)
						if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
							if Control.CastSpell(HK_Q, Pred.CastPosition) then
								lastQ = GetTickCount()
							end
						end
					end
				end
			end
		end
	end
end

function zgMilio:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, 1200, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 0, 0, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

zgMilio()