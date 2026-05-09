local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgJarvanIV"

function zgJarvanIV:__init()		 
	print("Zgjfjfl AIO - JarvanIV Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreMovement(function(...) self:OnPreMovement(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 70, Range = 770, Speed = math.huge, Collision = false}
	self.wSpell = { Range = 600 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 200, Range = 860, Speed = math.huge, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 350, Range = 650, Speed = math.huge, Collision = false}
    self.eqTime = 0
end

function zgJarvanIV:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "EQ", name = "[EQ]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WHp", name = "use W when self HP %", value = 40, min=5, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "WCount", name = "or use W when can hit >= X enemies", value=2, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RHp", name = "use R when target HP %", value = 40, min=5, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "RCount", name = "or use R when can hit >= X enemies", value=2, min = 1, max = 5})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "JungleClear", name = "Jungle Clear"})
		Menu.JungleClear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "EQ", name = "[EQ] to mouse", toggle = true, value = true})
		Menu.Flee:MenuElement({id = "W", name = "[W] slow enemy", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgJarvanIV:OnPreMovement(args)
	if GetMode() == "Flee" then
		if IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
			args.Process = false
		end
	end
end

function zgJarvanIV:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if myHero:GetSpellData(_R).toggleState == 2 and GetEnemyCount(self.rSpell.Radius, myHero.pos) == 0 then
		Control.CastSpell(HK_R)
	end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:JungleClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
	self:KillSteal()
end

function zgJarvanIV:Combo()
	local target = GetTarget(1000)
	if IsValid(target) then
		local pred = GGPrediction:SpellPrediction(self.eSpell)
		pred:GetPrediction(target, myHero)
		if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
			local offset = IsFacingMe(target) and -100 or -200
			local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), offset)
			if Menu.Combo.EQ:Value() and IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
				if myHero.pos:DistanceTo(castPos) <= self.eSpell.Range then
					if Control.CastSpell({HK_E, HK_Q}, castPos) then
						self.eqTime = GetTickCount()
					end
				end
			end
		end
		if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_E) and myHero:GetSpellData(_E).currentCd > 2 and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			self:CastQ(target)
		end
		if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
			if ((myHero.pos:DistanceTo(target.pos) < self.wSpell.Range and myHero.health/myHero.maxHealth <= Menu.Combo.WHp:Value()/100) or GetEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value()) then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
		if Menu.Combo.R:Value() and IsReady(_R) and myHero:GetSpellData(_R).toggleState == 1 and GetTickCount() > self.eqTime + 600 and not myHero.pathing.isDashing then
			if myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range and (target.health/target.maxHealth <= Menu.Combo.RHp:Value()/100 or GetEnemyCount(self.rSpell.Radius, target.pos) >= Menu.Combo.RCount:Value()) then
				Control.CastSpell(HK_R, target)
			end
		end
	end
end

function zgJarvanIV:CastQ(target)
    local pred = GGPrediction:SpellPrediction(self.qSpell)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(HK_Q, pred.CastPosition)
    end
end

function zgJarvanIV:CastE(target)
    local pred = GGPrediction:SpellPrediction(self.eSpell)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(HK_E, pred.CastPosition)
    end
end

function zgJarvanIV:JungleClear()
	if Menu.JungleClear.Q:Value() and IsReady(_Q) then
		local minions = _G.SDK.ObjectManager:GetMonsters(self.qSpell.Range)
        table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) then
				Control.CastSpell(HK_Q, minion)
			end
		end
	end
end

function zgJarvanIV:Harass()
	local target = GetTarget(self.qSpell.Range)
	if IsValid(target) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(target)
		end
	end
end

function zgJarvanIV:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.eSpell.Range)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) then
		    if IsReady(_Q) and Menu.KS.Q:Value() then
			    if self:getqDmg(enemy) >= enemy.health then
				    self:CastQ(enemy)
			    end
		    end
		    if IsReady(_E) and Menu.KS.E:Value() then
			    if self:geteDmg(enemy) >= enemy.health then
				    self:CastE(enemy)
			    end
		    end
		    if IsReady(_R) and Menu.KS.R:Value() and myHero:GetSpellData(_R).toggleState == 1 and GetTickCount() > self.eqTime + 600 and not myHero.pathing.isDashing then
			    if self:getrDmg(enemy) >= enemy.health then
				    Control.CastSpell(HK_R, enemy)
			    end
		    end
		end
	end
end

function zgJarvanIV:getqDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 40 * qlvl + 50
	local qadDmg = myHero.bonusDamage * 1.45
	local qDmg = qbaseDmg + qadDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function zgJarvanIV:geteDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 40 * elvl + 40
	local eapDmg = myHero.ap * 0.8
	local eDmg = ebaseDmg + eapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function zgJarvanIV:getrDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local rbaseDmg = 125 * rlvl + 75
	local radDmg = myHero.bonusDamage * 1.8
	local rDmg = rbaseDmg + radDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, rDmg) 
end

function zgJarvanIV:Flee()
	if Menu.Flee.EQ:Value() and IsReady(_Q) and IsReady(_E) and myHero.mana >= myHero:GetSpellData(_E).mana + myHero:GetSpellData(_Q).mana then
		local pos = myHero.pos:DistanceTo(Vector(mousePos)) > self.eSpell.Range and myHero.pos + (mousePos - myHero.pos)
					or myHero.pos + (mousePos - myHero.pos):Normalized() * (self.eSpell.Range + 100)
		if Control.CastSpell({HK_E,HK_Q}, pos) then
			self.eqTime = GetTickCount()
		end
	end
	if Menu.Flee.W:Value() and IsReady(_W) and not IsReady(_Q) and lastW + 250 < GetTickCount() then
		if GetEnemyCount(self.wSpell.Range, myHero.pos) > 0 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
end

function zgJarvanIV:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(192, 255, 255, 255))
	end
end

zgJarvanIV()