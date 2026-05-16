local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local epicMonsters = {
	["sru_baron"] = true,
	["sru_atakhan"] = true,
	["sru_riftherald"] = true,
	["sru_horde"] = true,
	["sru_dragon_water"] = true,
	["sru_dragon_fire"] = true,
	["sru_dragon_earth"] = true,
	["sru_dragon_air"] = true,
	["sru_dragon_chemtech"] = true,
	["sru_dragon_hextech"] = true,
	["sru_dragon_elder"] = true
}

class "zgSyndra"

function zgSyndra:__init()		 
	print("Zgjfjfl AIO - Syndra Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.6, Radius = 210, Range = 900, Speed = math.huge, Collision = false}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.15, Radius = 225, Range = 1050, Speed = 1600, Collision = false}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 1300, Speed = 2500, Collision = false}
	self.RSpell = {Range = 675}
    self.Balls = {}
	self.WIsBall = false
	self.lastQ = 0
	self.lastQE = 0
	self.lastW1 = 0
	self.lastW2 = 0
    self.lastE = 0
    self.lastR = 0
    self.clearWPos = nil
end

function zgSyndra:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
    Menu.Combo:MenuElement({id = "Rkillable", name = "Use R| Killable", value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Harass:MenuElement({id = "E", name = "Use E| Only In Q Range", value = false})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoE"})
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
	Menu.Clear.LastHit:MenuElement({id = "Q", name = "LastHit Q| out aa range", value = true})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "Use Q| Min HitCount", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "Use W| Min HitCount", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu:MenuElement({type = MENU, id = "spellRange", name = "Spell Range Settings"})
	Menu.spellRange:MenuElement({id = "Q", name = "[Q] Cast Max Range", value = 800, min = 700, max = 900, step = 50})
	Menu.spellRange:MenuElement({id = "W", name = "[W] Cast Max Range", value = 950, min = 850, max = 1050, step = 50})
	Menu.spellRange:MenuElement({id = "E", name = "[E] Cast Max Range", value = 1200, min = 1000, max = 1300, step = 50})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = false})
	Menu.Draw:MenuElement({id = "E", name = "[E] Range", value = false})
	Menu.Draw:MenuElement({id = "W", name = "[W] Range", value = false})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
    Menu.Draw:MenuElement({id = "Balls", name = "Draw Balls", value = false})
end

function zgSyndra:Tick()
	self:UpdateBalls()
	if self.WIsBall and myHero:GetSpellData(_W).name ~= "SyndraWCast" then
		self.WIsBall = false
	end
	if ShouldWait() or IsCasting() then
		return
	end
	self:SemiR()
	self:AutoE()
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

function zgSyndra:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			self:CastR(target)
		end
	end
end

function zgSyndra:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(Menu.spellRange.E:Value())
		if IsValid(target) then
			if self:CastE(target) then
				self.lastE = GetTickCount()
			end
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.spellRange.Q:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(Menu.spellRange.W:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
	if Menu.Combo.Rkillable:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) then
			local buff, buffData = GetBuffData(myHero, "syndrapassivestacks")
			local passiveFull = HaveBuff(myHero, "syndrapassivecapstonebuff")
			local hasPassive = buff and buffData.stacks >= 100 or passiveFull
			local currentHp = target.health + target.shieldAD + target.shieldAP + target.hpRegen * 2
			local damage = self:GetRDamage(target)
			if currentHp - damage < (hasPassive and target.maxHealth * 0.15 or 0) then
				self:CastR(target)
			end
		end
	end
end

function zgSyndra:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(800)
		if IsValid(target) then
			if self:CastE(target) then
				self.lastE = GetTickCount()
			end
		end
	end
    if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.spellRange.Q:Value())
		if IsValid(target) then
			self:CastQ(target)
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(Menu.spellRange.W:Value())
		if IsValid(target) then
			self:CastW(target)
		end
	end
end

function zgSyndra:LastHitQ()
    if Menu.Clear.LastHit.Q:Value() and IsReady(_Q) then
        local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
        for _, minion in ipairs(minions) do
            if IsValid(minion) and not minion.pathing.hasMovePath and not _G.SDK.Data:IsInAutoAttackRange(myHero, minion) then
                local damage = self:GetQDamage(minion)
                if minion.health <= damage then
                    Control.CastSpell(HK_Q, minion)
                    break
                end
            end
        end
    end
end

function zgSyndra:LaneClear()
    local currentTime = GetTickCount()

    -- 统一获取敌方小兵并按距离排序
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(800)
    table.sort(minions, function(a, b) return a.distance < b.distance end)

    -- ===================== Q 清线 =====================
    if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
        local bestHitCount = 0
        local bestCastPos = nil
        local qCount = Menu.Clear.LaneClear.QCount:Value()  -- 从菜单读取命中数

        for i, minion in ipairs(minions) do
            if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
                local hitCount = GetMinionCount(self.QSpell.Radius, minion.pos)
                -- 严格匹配菜单设定命中数
                if hitCount >= qCount and hitCount > bestHitCount then
                    bestHitCount = hitCount
                    bestCastPos = minion.pos
                end
            end
        end

        if bestCastPos and bestHitCount >= qCount and self.lastQ + 300 < currentTime then
            if Control.CastSpell(HK_Q, bestCastPos) then
                self.lastQ = currentTime
            end
        end
    end

    -- ===================== W 清线 =====================
    if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
        local bestHitCount = 0
        local bestCastPos = nil
        local wCount = Menu.Clear.LaneClear.WCount:Value()  -- 从菜单读取命中数

        for i, minion in ipairs(minions) do
            if IsValid(minion) and minion.team ~= 300 and not minion.pathing.hasMovePath then
                local hitCount = GetMinionCount(self.WSpell.Radius, minion.pos)
                if hitCount >= wCount and hitCount > bestHitCount then
                    bestHitCount = hitCount
                    bestCastPos = minion.pos
                end
            end
        end

        -- 施法前再次确认命中数满足菜单设定
		local spellName = myHero:GetSpellData(_W).name
        if bestCastPos and bestHitCount >= wCount then
            if spellName == "SyndraW" and self.lastW1 + 300 < currentTime then
                if Control.CastSpell(HK_W, bestCastPos) then
                    self.clearWPos = bestCastPos
                    self.lastW1 = currentTime
                end
			end
		end
        if spellName == "SyndraWCast" and self.lastW2 + 300 < currentTime then
			local castPos = self.clearWPos or bestCastPos
			if castPos then
				if Control.CastSpell(HK_W, castPos) then
					self.lastW2 = currentTime
					self.clearWPos = nil
				end
			end
		end
    end
end

function zgSyndra:JungleClear()
    -- 统一获取范围内怪物并按血量排序
    local monsters = _G.SDK.ObjectManager:GetMonsters(800)
    table.sort(monsters, function(a, b) return a.maxHealth > b.maxHealth end)

    local currentTime = GetTickCount()

    -- ===================== Q 清野 =====================
    if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
        local bestHitCount = 0
        local bestCastPos = nil

        for i, monster in ipairs(monsters) do
            if IsValid(monster) then
                local hitCount = GetMinionCount(self.QSpell.Radius, monster.pos)
                -- 允许命中数 >= 1
                if hitCount > bestHitCount then
                    bestHitCount = hitCount
                    bestCastPos = monster.pos
                end
            end
        end

        if bestCastPos and self.lastQ + 300 < currentTime then
            if Control.CastSpell(HK_Q, bestCastPos) then
                self.lastQ = currentTime
            end
        end
    end

    -- ===================== W 清野 =====================
    if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
        local bestHitCount = 0
        local bestCastPos = nil

        for i, monster in ipairs(monsters) do
            if IsValid(monster) then
                local name = monster.charName:lower()
                -- 史诗怪物优先直接施法
                if epicMonsters[name] then
                    self:CastW(monster)
                else
                    local hitCount = GetMinionCount(self.QSpell.Radius, monster.pos)
                    if hitCount > bestHitCount then
                        bestHitCount = hitCount
                        bestCastPos = monster.pos
                    end
                end
            end
        end
        -- 对普通怪物施放 W
		local spellName = myHero:GetSpellData(_W).name
        if bestCastPos then
            if spellName == "SyndraW" and self.lastW1 + 300 < currentTime then
                if Control.CastSpell(HK_W, bestCastPos) then
					self.clearWPos = bestCastPos
                    self.lastW1 = currentTime
                end
			end
		end
        if spellName == "SyndraWCast" and self.lastW2 + 300 < currentTime then
			local castPos = self.clearWPos or bestCastPos
			if castPos then
				if Control.CastSpell(HK_W, castPos) then
					self.lastW2 = currentTime
					self.clearWPos = nil
				end
			end
		end
    end
end

function zgSyndra:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgSyndra:AutoE()
	if Menu.Auto.Egap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) then
				if target.pathing.isDashing then
					local endPos = Vector(target.pathing.endPos)
					if myHero.pos:DistanceTo(endPos) < Menu.Auto.EgapRange:Value() and IsFacingMe(target) then
						if self:CastE(target) then
							self.lastE = GetTickCount()
							return
						end
					end
				end
				if myHero.pos:DistanceTo(target.pos) < Menu.Auto.EMeleeRange:Value() then
					if self:CastE(target) then
						self.lastE = GetTickCount()
						return
					end
				end
			end	
		end
	end
end

function zgSyndra:UpdateBalls()
    self.Balls = {}
	local particleCount = Game.ParticleCount()
	for i = particleCount, 1, -1 do
		local particle = Game.Particle(i)
		local name = particle.name:lower()
		if particle and name:find("syndra") then
			if (name:find("_q_lv5_idle") or name:find("_q_2021_idle") or name:find("_q_idle")) then
				self.Balls[#self.Balls + 1] = particle
			end
		end
	end
end

function zgSyndra:CastE(unit)
    local pred = GGPrediction:SpellPrediction(self.ESpell)
    pred:GetPrediction(unit, myHero)
    if pred:CanHit(3) and myHero.pos:DistanceTo(pred.CastPosition) < Menu.spellRange.E:Value() then
        if #self.Balls > 0 then
			if self.WIsBall == false and self.lastQE + 1000 < GetTickCount() then
            	for i, ball in ipairs(self.Balls) do
					if ball and myHero.pos:DistanceTo(ball.pos) < 800 then
                    	local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ball.pos, myHero.pos, pred.CastPosition)
						local point2, isOnSegment2 = GGPrediction:ClosestPointOnLineSegment(pred.CastPosition, myHero.pos, ball.pos)
                    	local width = unit.boundingRadius + self.ESpell.Radius / 2
                    	if (isOnSegment and GGPrediction:IsInRange(point, ball.pos, width)) or 
							(isOnSegment2 and GGPrediction:IsInRange(point2, pred.CastPosition, width)) then
							if Control.CastSpell(HK_E, pred.CastPosition) then
								return true
							end
						end
                    end
				end
            end
		end
        if IsReady(_Q) and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
			if myHero.pos:DistanceTo(pred.CastPosition) < 800 then
				if Control.CastSpell(HK_Q, pred.CastPosition) then
					self.lastQE = GetTickCount()
					DelayAction(function()
						if Control.CastSpell(HK_E, pred.CastPosition) then
							return true
						end
					end, 0.35)
				end
			else
				return Control.CastSpell({HK_Q, HK_E}, pred.CastPosition)
			end
		end
        if myHero.pos:DistanceTo(pred.CastPosition) < 700 and self.lastQE + 1000 < GetTickCount() then
            if Control.CastSpell(HK_E, pred.CastPosition) then
                return true
            end
        end
    end
    return false
end

function zgSyndra:CastQ(unit)
	local pred = GGPrediction:SpellPrediction(self.QSpell)
	pred:GetPrediction(unit, myHero)
	if pred:CanHit(3) and self.lastQ + 300 < GetTickCount() then
		if myHero.pos:DistanceTo(pred.CastPosition) < Menu.spellRange.Q:Value() then
			if Control.CastSpell(HK_Q, pred.CastPosition) then
				self.lastQ = GetTickCount()
			end
		end
	end
end

function zgSyndra:CastR(unit)
    if self.lastR + 300 < GetTickCount() then
        if Control.CastSpell(HK_R, unit) then
            self.lastR = GetTickCount()
        end
    end
end

function zgSyndra:CastW(unit)
    if myHero:GetSpellData(_W).name == "SyndraWCast" then
		if unit.type == Obj_AI_Minion and self.lastW2 + 300 < GetTickCount() then
			if Control.CastSpell(HK_W, unit) then
				self.lastW2 = GetTickCount()
				return
			end
		end
	    local pred = GGPrediction:SpellPrediction(self.WSpell)
	    pred:GetPrediction(unit, myHero)
	    if pred:CanHit(3) then
	        local predPos = pred.CastPosition
			if myHero.pos:DistanceTo(predPos) > Menu.spellRange.W:Value() then
				return
			end
	        if myHero.pos:DistanceTo(predPos) > 950 then
	            predPos = myHero.pos + (predPos - myHero.pos):Normalized() * 950
	        end
	        if Control.CastSpell(HK_W, predPos) then
                self.lastW2 = GetTickCount()
	            return
	        end
	    end
    else
        if self.lastQE + 1000 < GetTickCount() and self.lastE + 1000 < GetTickCount() and self.lastW1 + 300 < GetTickCount() then
            if #self.Balls > 0 then
                for _, ball in ipairs(self.Balls) do
                    if ball.pos:DistanceTo(myHero.pos) < 925 then
                        if Control.CastSpell(HK_W, ball.pos) then
							self.WIsBall = true
                            self.lastW1 = GetTickCount()
                            return
                        end
                    end
                end
            end
            local minion = _G.SDK.ObjectManager:GetEnemyMinions(925)[1]
            if IsValid(minion) and not epicMonsters[minion.charName:lower()] then
                if Control.CastSpell(HK_W, minion) then
                    self.lastW1 = GetTickCount()
                    return
                end
            end
        end
	end
end

function zgSyndra:GetRDamage(unit)
    local ballCount = myHero:GetSpellData(_R).ammo
	local level = myHero:GetSpellData(_R).level
	local baseDamage = {80, 120, 160}
	if level > 0 then
		local damage = (baseDamage[level] + myHero.ap * 0.20) * ballCount
		if HasItem(myHero, 4645) and unit.health / unit.maxHealth < 0.4 then
			damage = damage * 1.2
		end
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgSyndra:GetQDamage(unit)
	local level = myHero:GetSpellData(_Q).level
	local baseDamage = {80, 115, 150, 185, 220}
	if level > 0 then
		local damage = (baseDamage[level] + myHero.ap * 0.65)
		return _G.SDK.Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, damage)
	end
	return 0
end

function zgSyndra:Draw()
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
	if Menu.Draw.Balls:Value() then
		for i, ball in ipairs(self.Balls) do
			Draw.Circle(ball.pos, 50, 1, Draw.Color(255, 255, 0, 0))
		end
	end
end

zgSyndra()
