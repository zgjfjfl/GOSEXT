local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6 }
local ItemKeys = { HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6 }

--------------------------------------

class "zgKarma"

function zgKarma:__init()		 
	print("Zgjfjfl AIO - Karma Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 890, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RQSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1090, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}	
	self.WSpell = { Range = 675 }
	self.ESpell = { Range = 800, Radius = 575 }
end

function zgKarma:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({id = "SupportMode", name = "Support Mode (Disable Harass Lasthit)",value = true})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "R", name = "Use R", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "R", name = "Use R", toggle = true, value = true})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Mikael", name = "Auto Mikael's Blessing", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "AutoE", name = "Auto RE or E shields", value = true})
	Menu.Misc:MenuElement({id = "FleeE", name = "Flee mode RE or E self", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function zgKarma:OnTick()
	if ShouldWait() then
		return
	end
	self:AutoE()
	self:AutoMikael()
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "Flee" then
		self:FleeE()
	end
end

function zgKarma:OnPreAttack(args)
	local mode = GetMode()
	if Menu.SupportMode:Value() and mode == "Harass" then
		if args.Target.type ~= Obj_AI_Hero then
			args.Process = false
		end
	end
	if (mode == "Combo" or mode == "Harass") and (IsReady(_Q) or IsReady(_W)) then
		args.Process = false
	end
end

function zgKarma:FleeE()
	if Menu.Misc.FleeE:Value() and IsReady(_E) then
		if IsReady(_R) and (GetAllyCount(self.ESpell.Radius, myHero.pos) > 1 or myHero.health < myHero.maxHealth * 0.5) then 
			Control.CastSpell(HK_R)
		end
		self:CastE(myHero)
	end
end

function zgKarma:AutoMikael()
	if Menu.Misc.Mikael:Value() then
		for i = 1, #ItemSlots do
			local slot = ItemSlots[i]
			local item = myHero:GetItemData(slot)
			if item and item.itemID == 3222 and myHero:GetSpellData(slot).currentCd == 0 then
				local allies = _G.SDK.ObjectManager:GetAllyHeroes(650)
				for _, ally in ipairs(allies) do
					if IsValid(ally) and not ally.isMe and GetHardCCDuration(ally) > 0.5 then
						Control.CastSpell(ItemKeys[i], ally)
						break
					end
				end
			end
		end
	end
end

function zgKarma:AutoE()
	if Menu.Misc.AutoE:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.ESpell.Range)
		local turrets = _G.SDK.ObjectManager:GetEnemyTurrets(1500)
		for _, ally in ipairs(allies) do
			if IsValid(ally) then
				local canuse = false
				if IsPoison(ally) then
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
					if IsReady(_R) and (GetAllyCount(self.ESpell.Radius, ally.pos) > 2 or ally.health < ally.maxHealth * 0.5) then
						Control.CastSpell(HK_R)
					end
					self:CastE(ally)
					break
				end
			end
		end
	end
end
	
function zgKarma:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) then
		local allyCount = GetAllyCount(1000, myHero.pos)
		local useR = Menu.Combo.R:Value() and Game.CanUseSpell(_R) == 0 and (allyCount < 3 or myHero:GetSpellData(_E).level == 0)
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if useR then
				Control.CastSpell({HK_R, HK_W}, target)
			else
				Control.CastSpell(HK_W, target)
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local allyCount = GetAllyCount(1000, myHero.pos)
		local useR = Menu.Combo.R:Value() and Game.CanUseSpell(_R) == 0 and (allyCount < 3 or myHero:GetSpellData(_E).level == 0)
		local spell = useR and self.RQSpell or self.QSpell
		local target = GetTarget(spell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if not IsReady(_W) or target.distance > self.WSpell.Range then
				self:CastQ(useR, spell, target)
			end
		end
	end
end

function zgKarma:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) then
		local useR = Menu.Harass.R:Value() and Game.CanUseSpell(_R) == 0
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if useR then Control.CastSpell(HK_R) end
			Control.CastSpell(HK_W, target)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local useR = Menu.Harass.R:Value() and Game.CanUseSpell(_R) == 0
		local spell = useR and self.RQSpell or self.QSpell
		local target = GetTarget(spell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if not IsReady(_W) or target.distance > self.WSpell.Range then
				self:CastQ(useR, spell, target)
			end
		end
	end
end

function zgKarma:CastQ(useR, spell, target)
	local pred = GGPrediction:SpellPrediction(spell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(3) then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(
			myHero.pos, pred.CastPosition, spell.Speed, spell.Delay, spell.Radius, 
			{GGPrediction.COLLISION_MINION}, target.networkID
		)
		if collisionCount == 0 or collisionObjects[1].pos:DistanceTo(pred.CastPosition) < 200 then
			if useR then
				Control.CastSpell({HK_R, HK_Q}, pred.CastPosition)
			else
				Control.CastSpell(HK_Q, pred.CastPosition)
			end
		end
	end
end

function zgKarma:CastE(unit)
	if unit.isMe then
		Control.KeyDown(0x12)  -- Alt key
		Control.KeyDown(HK_E)
		Control.KeyUp(HK_E)
		Control.KeyUp(0x12)
	else
		Control.CastSpell(HK_E, unit)
	end
end

function zgKarma:Draw()
	if myHero.dead then return end

	if Menu.Draw.Q:Value() and IsReady(_Q) then
		if HaveBuff(myHero, "karmamantra") then
			Draw.Circle(myHero.pos, self.RQSpell.Range, 1, Draw.Color(255, 66, 244, 113))
		else
			Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
		end
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgKarma()
