local Version = 1.03

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgVeigar"

function zgVeigar:__init()		 
	print("Zgjfjfl AIO - Veigar Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 2200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.2, Radius = 240, Range = 950, Speed = math.huge, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 340, Range = 1040, Speed = math.huge, Collision = false}
	self.RSpell = {Range = 650}
    self.EPos = nil
    self.ECastTime = 0
    self.ETargetPos = nil
end

function zgVeigar:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
	Menu.Combo:MenuElement({id = "Wkillable", name = "Use W| Killable", value = true})
    Menu.Combo:MenuElement({id = "Rkillable", name = "Use R| Killable", value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
	Menu.Auto:MenuElement({id = "WCC", name = "Auto W| On CC", value = true})
	Menu.Auto:MenuElement({id = "ECC", name = "Auto E| On CC", value = true})
	Menu.Auto:MenuElement({id = "Egap", name = "Auto E| Anti Gapcloser or Melee", value = true})
	Menu.Auto:MenuElement({id = "EgapRange", name = "AntiGap E Range(dash endPos form self < X)", value = 400, min = 0, max = 600, step = 50})
	Menu.Auto:MenuElement({id = "EMeleeRange", name = "AntiMelee E Range(melee form self < X)", value = 350, min = 0, max = 600, step = 50})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
	Menu.Clear.LastHit:MenuElement({id = "Q", name = "LastHit Q", value = true})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W| Min HitCount", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
end

function zgVeigar:Tick()
	self:UpdateEPos()
	if ShouldWait() or IsCasting() then
		return
	end
	self:SemiR()
	self:AutoE()
	self:AutoW()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHitQ()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LastHitQ()
		self:FarmHarass()
		if Menu.Clear.SpellFarm:Value() then
			self:LaneClear()
			self:JungleClear()
		end
	elseif Mode == "LastHit" then
		self:LastHitQ()
	end
end

function zgVeigar:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_R, target)
		end
	end
end

function zgVeigar:AutoW()
	if not IsReady(_W) then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.WSpell.Range)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) then
			if Menu.Auto.WCC:Value() and GetHardCCDuration(enemy) > 1.0 then
				Control.CastSpell(HK_W, enemy)
			end
		end
	end
end

function zgVeigar:AutoE()
	if not IsReady(_E) then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) then
			if Menu.Auto.ECC:Value() and GetHardCCDuration(enemy) > 0.75 then
				local castPos = enemy.pos:Extended(myHero.pos, self.ESpell.Radius)
				if castPos:DistanceTo(myHero.pos) <= 700 then
					Control.CastSpell(HK_E, castPos)
				end
			end
			if Menu.Auto.Egap:Value() and enemy.pathing.isDashing then
				local endPos = Vector(enemy.pathing.endPos)
				local castPos = endPos:Extended(myHero.pos, self.ESpell.Radius)
				if castPos:DistanceTo(myHero.pos) <= 700 then
					Control.CastSpell(HK_E, castPos)
				end
			end	
		end
	end
end

function zgVeigar:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.ESpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			if self.EPos ~= nil and GetDistance(target.pos, self.EPos) < 290 and not IsHardCC(target) then
				local castPos = self.EPos:Extended(target.pos, self.ESpell.Radius / 2)
				Control.CastSpell(HK_W, castPos)
			end
			if IsSlow(target) then
				self:CastW(target)
			end
			if Menu.Combo.Wkillable:Value() then
				local currentHp = (target.health + target.shieldAD + target.shieldAP + target.hpRegen * 2)
				local damage = self:GetWDamage(target)
				if currentHp - damage <= 0 then
					self:CastW(target)
				end
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.Rkillable:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			local currentHp = (target.health + target.shieldAD + target.shieldAP + target.hpRegen)
			local damage = self:GetRDamage(target)
			if currentHp - damage <= 0 then
				Control.CastSpell(HK_R, target)
			end
		end
	end
end

function zgVeigar:Harass()
    if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgVeigar:LastHitQ()
    if Menu.Clear.LastHit.Q:Value() and IsReady(_Q) then
        local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range)
        for _, minion in ipairs(minions) do
            if IsValid(minion) and not minion.pathing.hasMovePath then
                local damage = self:GetQDamage(minion)
                local t = minion.distance / self.QSpell.Speed + self.QSpell.Delay
                local hp = _G.SDK.HealthPrediction:GetPrediction(minion, t)
                local isWall, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius, {GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}, minion.networkID)
                if hp > 0 and hp <= damage and not isWall and collisionCount <= 1 then
                    Control.CastSpell(HK_Q, minion)
                    break
                end
            end
        end
    end
end

function zgVeigar:LaneClear()
    local currentTime = GetTickCount()

    -- 统一获取敌方小兵并按距离排序
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.WSpell.Range)
    table.sort(minions, function(a, b) return a.distance < b.distance end)

    if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
        local bestHitCount = 0
        local bestCastPos = nil
        local wCount = Menu.Clear.LaneClear.WCount:Value()  -- 从菜单读取命中数

        for i, minion in ipairs(minions) do
            if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
                local hitCount = GetMinionCount(self.WSpell.Radius, minion.pos)
                -- 严格匹配菜单设定命中数
                if hitCount >= wCount and hitCount > bestHitCount then
                    bestHitCount = hitCount
                    bestCastPos = minion.pos
                end
            end
        end

        if bestCastPos and bestHitCount >= wCount then
            Control.CastSpell(HK_W, bestCastPos)
        end
    end
end

function zgVeigar:JungleClear()
    local monsters = _G.SDK.ObjectManager:GetMonsters(800)
    table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)
    for i, monster in ipairs(monsters) do
        if IsValid(monster) then
            if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
                Control.CastSpell(HK_Q, monster)
            end
            if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
                local bestHitCount = 0
                local bestCastPos = nil
                local hitCount = GetMinionCount(self.WSpell.Radius, monster.pos)
                if hitCount > bestHitCount then
                    bestHitCount = hitCount
                    bestCastPos = monster.pos
                end
                if bestCastPos then
                    Control.CastSpell(HK_W, bestCastPos)
                end
            end
        end
    end
end

function zgVeigar:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgVeigar:UpdateEPos()
	local now = Game.Timer()
	
	-- Clear after 3s duration
	if self.ECastTime > 0 and now - self.ECastTime > 3 + self.ESpell.Delay then
		self.EPos = nil
		self.ECastTime = 0
		self.ETargetPos = nil
		return
	end
	
	-- Record cast
	if myHero.activeSpell.name == "VeigarEventHorizon" and self.ECastTime == 0 then
		self.ECastTime = now
		self.ETargetPos = myHero.activeSpell.placementPos
	end
	
	-- Activate after delay
	if self.ECastTime > 0 and now - self.ECastTime > self.ESpell.Delay + 0.1 then
		self.EPos = self.ETargetPos
	end
end

function zgVeigar:CastE(unit)
    local pred = GGPrediction:SpellPrediction(self.ESpell)
    pred:GetPrediction(unit, myHero)
    if pred:CanHit(3) then
		local predPos = Vector(pred.UnitPosition)
		if predPos:DistanceTo(myHero.pos) > 700 then
			local castPos = predPos:Extended(myHero.pos, self.ESpell.Radius / 2)
			if castPos:DistanceTo(myHero.pos) <= 700 then
				return Control.CastSpell(HK_E, castPos)
			end
			return false
		else
			return Control.CastSpell(HK_E, predPos)
		end
    end
    return false
end

function zgVeigar:CastQ(unit)
	local pred = GGPrediction:SpellPrediction(self.QSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		local isWall, _, collisionCount = GGPrediction:GetCollision(myHero.pos, pred.CastPosition, self.QSpell.Speed, self.QSpell.Delay, self.QSpell.Radius/2, {GGPrediction.COLLISION_YASUOWALL, GGPrediction.COLLISION_MINION}, unit.networkID)
		if not isWall and collisionCount <= 1 then
			return Control.CastSpell(HK_Q, pred.CastPosition)
		end
	end
	return false
end

function zgVeigar:CastW(unit)
	local pred = GGPrediction:SpellPrediction(self.WSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) then
		return Control.CastSpell(HK_W, pred.CastPosition)
	end
	return false
end

function zgVeigar:GetRDamage(unit)
	local level = myHero:GetSpellData(_R).level
	local baseDamage = {175, 250, 325}
	if level > 0 then
		local baseDmg = baseDamage[level] + myHero.ap * ({0.65, 0.70, 0.75})[level]
		local missingHealthPercent = (unit.maxHealth - unit.health) / unit.maxHealth
		if missingHealthPercent > 0.6666 then missingHealthPercent = 0.6666 end
		local bonusMultiplier = missingHealthPercent * 1.5
		local damage = baseDmg * (1 + bonusMultiplier)
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgVeigar:GetWDamage(unit)
	local level = myHero:GetSpellData(_W).level
	local baseDamage = {85, 140, 195, 250, 305}
	if level > 0 then
		local damage = baseDamage[level] + myHero.ap * ({0.7, 0.8, 0.9, 1.0, 1.1})[level]
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgVeigar:GetQDamage(unit)
	local level = myHero:GetSpellData(_Q).level
	local baseDamage = {80, 120, 160, 200, 240}
	if level > 0 then
		local damage = baseDamage[level] + myHero.ap * ({0.5, 0.55, 0.6, 0.65, 0.7})[level]
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgVeigar:Draw()
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
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 66, 244, 113))
	end
end

zgVeigar()
