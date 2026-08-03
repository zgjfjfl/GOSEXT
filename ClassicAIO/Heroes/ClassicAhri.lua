local Version = 1.01

require("GGPrediction")
require("ClassicAIO\\Utils")

class "ClassicAhri"

function ClassicAhri:__init()		 
	print("Classic AIO - Ahri Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 970, Speed = 1400, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1550, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.selectedTarget = nil
	self.targetTimer = 0
end

function ClassicAhri:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.15.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Classic_AIO_"..myHero.charName, name = "Classic AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "Qrange", name = "Use Q|Range", value = 900, min = 600, max = 970, step = 10})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", toggle = true, value = false})
	Menu.Harass:MenuElement({id = "Erange", name = "Use E|Range", value = 900, min = 600, max = 975, step = 10})

	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "Enabled", name = "Use Spell Farm (Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(v) CheckChatBlock(Menu.Clear.Enabled, v) end})
	Menu.Clear:MenuElement({id = "Q", name = "Use Q | Minions >=", value = 3, min = 1, max = 8, step = 1})
	Menu.Clear:MenuElement({id = "W", name = "Use W | Nearby Minions >=", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({id = "JungleQ", name = "Use Q In Jungle", value = true})
	Menu.Clear:MenuElement({id = "JungleW", name = "Use W In Jungle", value = true})
	Menu.Clear:MenuElement({id = "Mana", name = "Mana Percent >=", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "EAntiDash", name = "Auto E AntiDash", value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "Farm", name = "Draw Farm Status", value = true})
end

function ClassicAhri:OnTick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	self:AutoE()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:Clear()
	end
end

function ClassicAhri:OnPreAttack(args)
	if GetMode() == "Combo" and IsValid(args.Target) then
		local qReady = Menu.Combo.Q:Value() and IsReady(_Q) and args.Target.distance <= Menu.Combo.Qrange:Value()
		local eReady = Menu.Combo.E:Value() and IsReady(_E) and args.Target.distance <= Menu.Combo.Erange:Value()
		if qReady or eReady then
			args.Process = false
		end
	end
end

function ClassicAhri:AutoE()
	if Menu.Misc.EAntiDash:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i = 1, #enemies do
			local enemy = enemies[i]
			local path = enemy.pathing
			if path and path.isDashing and enemy.posTo then
				if myHero.pos:DistanceTo(enemy.posTo) < myHero.pos:DistanceTo(enemy.pos) then
					self:CastGGPred(HK_E, enemy)
					break
				end
			end
		end
	end
end
	
function ClassicAhri:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Combo.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			self.targetTimer = os.clock()
			self.selectedTarget = target
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance <= Menu.Combo.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function ClassicAhri:Harass()
	if Menu.Harass.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(700)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.Harass.Erange:Value())
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_E, target)
			self.targetTimer = os.clock()
			self.selectedTarget = target
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Harass.Qrange:Value())
		if os.clock() < self.targetTimer + 3 and IsValid(self.selectedTarget) and self.selectedTarget.distance < Menu.Harass.Qrange:Value() then
			target = self.selectedTarget
		end
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastGGPred(HK_Q, target)
		end
	end
end

function ClassicAhri:Clear()
	if not Menu.Clear.Enabled:Value() then return end
	if myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 < Menu.Clear.Mana:Value() then return end
	if not IsUnderTurret(myHero) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
		if Menu.Clear.Q:Value() > 0 and IsReady(_Q) then
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen and minion.distance <= self.QSpell.Range and GetMinionCount(180, minion.pos) >= Menu.Clear.Q:Value() then
					Control.CastSpell(HK_Q, minion.pos)
					return
				end
			end
		end
		if Menu.Clear.W:Value() > 0 and IsReady(_W) and lastW + 250 < GetTickCount() and GetMinionCount(700, myHero.pos) >= Menu.Clear.W:Value() then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
			return
		end
	end
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.QSpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	local target = monsters[1]
	if not IsValid(target) or not target.pos2D.onScreen then return end
	if Menu.Clear.JungleQ:Value() and IsReady(_Q) then
		Control.CastSpell(HK_Q, target.pos)
		return
	end
	if Menu.Clear.JungleW:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and target.distance <= 700 then
		Control.CastSpell(HK_W)
		lastW = GetTickCount()
	end
end

function ClassicAhri:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_E then
		local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
		EPrediction:GetPrediction(target, myHero)
		if EPrediction:CanHit(3) then
			Control.CastSpell(HK_E, EPrediction.CastPosition)
		end
	end
end

function ClassicAhri:Draw()
	if myHero.dead then return end

	if Menu.Draw.Farm:Value() then
		Draw.Text(Menu.Clear.Enabled:Value() and "Spell Farm: On" or "Spell Farm: Off", 16, myHero.pos2D.x - 55, myHero.pos2D.y + 60, Draw.Color(200, 242, 120, 34))
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

ClassicAhri()
