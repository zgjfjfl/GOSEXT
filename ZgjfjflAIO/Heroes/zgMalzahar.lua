local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgMalzahar"


function zgMalzahar:__init()		 
	print("Zgjfjfl AIO - Malzahar Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.65, Radius = 100, Range = 900, Speed = math.huge, Collision = false}
	self.ESpell = {Range = 650}
	self.RSpell = {Range = 700}
end

function zgMalzahar:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 10, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "E", name = "Use E", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
end

function zgMalzahar:Tick()
	if ShouldWait() or IsCasting() then
		return
	end
    if HaveBuff(myHero, "malzaharrsound") then
        _G.SDK.Orbwalker:SetMovement(false)
        _G.SDK.Orbwalker:SetAttack(false)
        return
    else
        _G.SDK.Orbwalker:SetMovement(true)
        _G.SDK.Orbwalker:SetAttack(true)
    end
    self:SemiR()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		if Menu.Clear.SpellFarm:Value() then
			self:LaneClear()
			self:JungleClear()
		end
	end
end

function zgMalzahar:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgMalzahar:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_E, target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(1000)
        local buff, buffData = GetBuffData(myHero, "malzaharw")
		if IsValid(target) and HaveBuff(target, "malzahare") and buff and buffData.count == 2 then
			Control.CastSpell(HK_W, target)
		end
	end
end

function zgMalzahar:Harass()
    if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
    if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range + 400)
		if IsValid(target) then
			if target.distance <= self.ESpell.Range then
				Control.CastSpell(HK_E, target)
			else
				local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
				for _, minion in ipairs(minions) do
					if IsValid(minion) and minion.health < self:GetEDmg(minion) / 4 then
						Control.CastSpell(HK_E, minion)
						break
					end
				end
			end
		end
	end
end

function zgMalzahar:CastQ(unit)
	local pred = GGPrediction:SpellPrediction(self.QSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		Control.CastSpell(HK_Q, pred.CastPosition)
	end
end

function zgMalzahar:LaneClear()
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
	table.sort(minions, function(a, b) return a.distance < b.distance end)
	for _, minion in ipairs(minions) do
		if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
			if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
				local bestPos = nil
				local maxHits = 0
				local castDir = Vector(minion.pos - myHero.pos):Normalized()
				local perpDir = Vector(-castDir.z, 0, castDir.x)
				local portal1 = minion.pos + perpDir * 375
				local portal2 = minion.pos - perpDir * 375
				local hits = 1
				for _, checkMinion in ipairs(minions) do
					if IsValid(checkMinion) and checkMinion.networkID ~= minion.networkID and checkMinion.team ~= 300 and not checkMinion.pathing.hasMovePath then
						local point, onSegment = GGPrediction:ClosestPointOnLineSegment(checkMinion.pos, portal1, portal2)
						if onSegment and GGPrediction:IsInRange(checkMinion.pos, point, self.QSpell.Radius) then
							hits = hits + 1
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
			if Menu.Clear.LaneClear.E:Value() and IsReady(_E) then
				if minion.health < self:GetEDmg(minion) and not HaveBuff(minion, "malzahare") and minion.distance <= self.ESpell.Range then
					Control.CastSpell(HK_E, minion)
				end
			end
			if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
        		local buff, buffData = GetBuffData(myHero, "malzaharw")
				if buff and buffData.count == 2 and minion.distance <= 750 then
					Control.CastSpell(HK_W, minion)
				end
			end
		end
	end
end

function zgMalzahar:JungleClear()
	local monsters = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
	table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, monster in ipairs(monsters) do
		if IsValid(monster) and not monster.pathing.hasMovePath then
			if Menu.Clear.JungleClear.E:Value() and IsReady(_E) and not HaveBuff(monster, "malzahare") then
				Control.CastSpell(HK_E, monster)
			end
			if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
				local bestPos = nil
				local maxHits = 0
				local castDir = Vector(monster.pos - myHero.pos):Normalized()
				local perpDir = Vector(-castDir.z, 0, castDir.x)
				local portal1 = monster.pos + perpDir * 375
				local portal2 = monster.pos - perpDir * 375
				local hits = 1
				for _, checkMonster in ipairs(monsters) do
					if IsValid(checkMonster) and checkMonster.networkID ~= monster.networkID and not checkMonster.pathing.hasMovePath then
						local point, onSegment = GGPrediction:ClosestPointOnLineSegment(checkMonster.pos, portal1, portal2)
						if onSegment and GGPrediction:IsInRange(checkMonster.pos, point, self.QSpell.Radius) then
							hits = hits + 1
						end
					end
				end
				if hits > maxHits then
					maxHits = hits
					bestPos = monster.pos
				end
				if bestPos and maxHits >= 1 then
					Control.CastSpell(HK_Q, bestPos)
				end
			end
			if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
        		local buff, buffData = GetBuffData(myHero, "malzaharw")
				if buff and buffData.count == 2 then
					Control.CastSpell(HK_W, monster)
				end
			end
		end
	end
end

function zgMalzahar:GetQDmg(unit)
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	local QDmg = ({70, 105, 140, 175, 210})[level] + 0.55 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgMalzahar:GetWDmg(unit)
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	local WDmg = ({20, 35, 50, 65, 80})[level] + 0.2 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, WDmg)
end

function zgMalzahar:GetEDmg(unit)
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	local EDmg = ({80, 115, 160, 205, 250})[level] + 0.8 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, unit, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgMalzahar:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
end

zgMalzahar()
