local Version = 1.01

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgGragas"

function zgGragas:__init()
	print("Zgjfjfl AIO - Gragas Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 850, Speed = 1000, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 50, Range = 800, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 400, Range = 1000, Speed = math.huge, Collision = false}
end

function zgGragas:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Insec", name = "InsecR Setting"})
		Menu.Insec:MenuElement({id = "R1", name = "Semi-Manual InsecR Target to Self", key = string.byte("T")})
		Menu.Insec:MenuElement({id = "R2", name = "Auto InsecR on HardCC Target", value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.KS:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgGragas:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:JungleClear()
	end
	if IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQToggle" then
		self:CastQ2()
	end
	if Menu.Insec.R1:Value() then
		self:InsecR()
	end
	if Menu.Insec.R2:Value() then
		self:AutoR()
	end
	self:KillSteal()
end

function zgGragas:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgGragas:CastE(target)
	local Pred = GGPrediction:SpellPrediction(self.eSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.CastPosition)
	end
end

function zgGragas:CastR(target)
	local Pred = GGPrediction:SpellPrediction(self.rSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_R, Pred.CastPosition)
	end
end

function zgGragas:Combo()
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(1000)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and not IsReady(_E) then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgGragas:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Harass.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" then
		local target = GetTarget(self.qSpell.Range)
		if IsValid(target) then
			self:CastQ(target)
		end
	end
end

function zgGragas:InsecR()
	local target = GetTarget(1000)
	if IsValid(target) and IsReady(_R) then
		local wallPos = FindFirstWallCollision(myHero.pos, target.pos)
		if wallPos == nil and myHero.pos:DistanceTo(target.pos) < self.rSpell.Range - 150 then
			local pred = GGPrediction:SpellPrediction(self.rSpell)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				local castPos = Vector(pred.CastPosition):Extended(Vector(myHero.pos), -150)
				Control.CastSpell(HK_R, castPos)
			end
		end
	end
end

function zgGragas:AutoR()
	local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(self.rSpell.Range - 150)
	for i, hero in ipairs(heroes) do
		if IsHardCC(hero) and FindFirstWallCollision(myHero.pos, hero.pos) == nil and IsReady(_R) then
			Control.CastSpell(HK_R, Vector(hero.pos):Extended(Vector(myHero.pos), -150))
		end
	end
end

function zgGragas:JungleClear()
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if IsValid(target) then
		local buff, buffData = GetBuffData(myHero, "GragasQ")
		if Menu.Clear.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_Q, target)
		end
		if IsReady(_Q) and lastQ + 250 < GetTickCount() and myHero:GetSpellData(_Q).name == "GragasQToggle" and buff and buffData.duration < 2 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if Menu.Clear.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
			Control.CastSpell(HK_E, target)
		end
	end
end

function zgGragas:CastQ2()
	for i = Game.ParticleCount(), 1, -1 do
	local particle = Game.Particle(i)
		if particle and particle.name:find("Gragas") and particle.name:find("_Q_Ally") and GetEnemyCount(300, particle.pos) >= 1 and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function zgGragas:KillSteal()
	local target = GetTarget(self.rSpell.Range)
	if IsValid(target) then
		if IsReady(_Q) and myHero:GetSpellData(_Q).name == "GragasQ" and Menu.KS.Q:Value() then
			if self:GetQDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.qSpell.Range then
				self:CastQ(target)
			end
		end
		if IsReady(_E) and Menu.KS.E:Value() then
			if self:GetEDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) < self.eSpell.Range then
				self:CastE(target)
			end
		end
		if IsReady(_R) and Menu.KS.R:Value() then
			if self:GetRDmg(target) >= target.health and myHero.pos:DistanceTo(target.pos) <= self.rSpell.Range then
				self:CastR(target)
			end
		end
	end
end

function zgGragas:GetQDmg(target)	
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 40 * qlvl + 40
	local qapDmg = myHero.ap * 0.8
	local qDmg = qbaseDmg + qapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, qDmg)
end

function zgGragas:GetEDmg(target)	
	local elvl = myHero:GetSpellData(_E).level
	local ebaseDmg = 35 * elvl + 45
	local eapDmg = myHero.ap * 0.6
	local eDmg = ebaseDmg + eapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg)
end

function zgGragas:GetRDmg(target)	
	local rlvl = myHero:GetSpellData(_R).level
	local rbaseDmg = 100 * rlvl + 100
	local rapDmg = myHero.ap * 0.8
	local rDmg = rbaseDmg + rapDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rDmg)
end

function zgGragas:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

zgGragas()