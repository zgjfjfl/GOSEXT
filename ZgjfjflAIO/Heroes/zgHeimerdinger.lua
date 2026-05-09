local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgHeimerdinger"
		
function zgHeimerdinger:__init()		 
	print("Zgjfjfl AIO - Heimerdinger Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)	
	self.Q = {Delay = 0.25, Range = 350}
	self.W = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 75, Range = 1200, Speed = 900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}} 
	self.E = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 135, Range = 970, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.E2 = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 1500, Speed = 1200, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgHeimerdinger:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "QRange1", name = "QTurret distance self", value = 300, min = 100, max = 350, step = 10})
		Menu.Combo:MenuElement({id = "QRange2", name = "Cast[Q] distance target ", value = 700, min = 500, max = 1000, step = 50})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RQ", name = "[RQ]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RQCount", name = "UseRQ when X enemies near", value = 2, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "RW", name = "[RW] UseRW if can kill target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RE", name = "[RE]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RECount", name = "UseRE when X enemies near", value = 3, min = 1, max = 5})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
		Menu.Misc:MenuElement({id = "QAmmo", name = "Save 1 QTurret in Combo", toggle = true, value = false})
		Menu.Misc:MenuElement({id = "QAHp", name = "When target <=HP% use last QTurret", value = 20, min = 0, max = 100, step = 5})
		Menu.Misc:MenuElement({id = "Flee", name = "Flee [RE] or [E]", toggle = true, value = false})
		Menu.Misc:MenuElement({id = "RW", name = "Semi-Manual [RW] Key", key = string.byte("Z")})
		Menu.Misc:MenuElement({id = "RE", name = "Semi-Manual [RE] Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E2", name = "[E2] Range", toggle = true, value = false})
end

function zgHeimerdinger:Tick()
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
	if Menu.Misc.RW:Value() then
		self:SemiManualRW()
	end
	if Menu.Misc.RE:Value() then
		self:SemiManualRE()
	end
end

function zgHeimerdinger:Combo()
	local target = GetTarget(1500)
	if IsValid(target) then
		if Menu.Combo.RQ:Value() and IsReady(_Q) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and GetEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= Menu.Combo.RQCount:Value() then
			self:CastR()
			self:CastQ(target)
		elseif Menu.Combo.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < Menu.Combo.QRange2:Value() and GetEnemyCount(Menu.Combo.QRange2:Value(), myHero.pos) >= 1 then
			if not Menu.Misc.QAmmo:Value() then
				self:CastQ(target)
			else
				if target.health/target.maxHealth >= Menu.Misc.QAHp:Value()/100 then
					if myHero:GetSpellData(_Q).ammo > 1 then
						self:CastQ(target)
					end
				else
					self:CastQ(target)
				end
			end
		end
		if Menu.Combo.RE:Value() and IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range and GetEnemyCount(275, target.pos) >= Menu.Combo.RECount:Value() then
			self:CastR()
			self:CastE2(target)
		elseif Menu.Combo.E:Value() and IsReady(_E) then
			if HaveBuff(myHero, "HeimerdingerR") then
				if myHero.pos:DistanceTo(target.pos) < self.E2.Range then
					self:CastE2(target)
				end
			else
				if myHero.pos:DistanceTo(target.pos) < self.E.Range then
					self:CastE(target)
				end
			end
		end
		if Menu.Combo.RW:Value() and IsReady(_W) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.W.Range and self:GetRWDmg(target) >= target.health then
			self:CastR()
			self:CastW(target)
		elseif Menu.Combo.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastW(target)
		end
	end
end

function zgHeimerdinger:Harass()
	local target = GetTarget(1500)
	if IsValid(target) then
		if Menu.Harass.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) < self.E.Range then
			self:CastE(target)
		end
		if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastW(target)
		end
	end
end

function zgHeimerdinger:SemiManualRW()
	local target = GetTarget(1500)
	if IsValid(target) then
		if IsReady(_W) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.W.Range then
			self:CastR()
			self:CastW(target)
		end
	end
end

function zgHeimerdinger:SemiManualRE()
	local target = GetTarget(1500)
	if IsValid(target) then
		if IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range then
			self:CastR()
			self:CastE2(target)
		end
	end
end

function zgHeimerdinger:Flee()
	local target = GetTarget(1500)
	if IsValid(target) and Menu.Misc.Flee:Value() then
		if IsReady(_E) and IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E2.Range then
			self:CastR()
			self:CastE2(target)
		else
			if IsReady(_E) and not IsReady(_R) and myHero.pos:DistanceTo(target.pos) < self.E.Range then
				self:CastE(target)
			end
		end
	end
end

function zgHeimerdinger:CastQ(target)
	local Castpos = myHero.pos:Extended(target.pos, Menu.Combo.QRange1:Value())
	Control.CastSpell(HK_Q, Castpos)
end

function zgHeimerdinger:CastW(target)
	local pred = GGPrediction:SpellPrediction(self.W)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_W, pred.CastPosition)	
	end
end

function zgHeimerdinger:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.E)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function zgHeimerdinger:CastE2(target)
	local pred = GGPrediction:SpellPrediction(self.E2)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		Control.CastSpell(HK_E, pred.CastPosition)	
	end
end

function zgHeimerdinger:CastR()
	if not HaveBuff(myHero, "HeimerdingerR") and lastR + 250 < GetTickCount() then
		Control.CastSpell(HK_R)
		lastR = GetTickCount()
	end
end

function zgHeimerdinger:GetRWDmg(target)
	local rlvl = myHero:GetSpellData(_R).level
	local baseDmg = 194.5 * rlvl + 308.5
	local apDmg = myHero.ap * 1.83
	local rwDmg = baseDmg + apDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, rwDmg)
end

function zgHeimerdinger:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.Q.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.W.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.E2:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.E2.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

zgHeimerdinger()