local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgYorick"
	
function zgYorick:__init()
	print("Zgjfjfl AIO - Yorick Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnAttack(function() self:OnAttack() end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0, Radius = 225, Range = 600, Speed = math.huge, Collision = false}
	self.eSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 1000, Speed = 1800, Collision = false}
	self.rSpell = {Range = 600}
	self.qAttackReset = false
end

function zgYorick:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q2", name = "[Q2]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R1", name = "[R1] ", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "LaneClear", name = "Lane Clear"})
		Menu.LaneClear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.LaneClear:MenuElement({id = "Q2", name = "[Q2] activate Mist Walker", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "JungleClear", name = "Jungle Clear"})
		Menu.JungleClear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.JungleClear:MenuElement({id = "Q2", name = "[Q2] activate Mist Walker", toggle = true, value = true})
		Menu.JungleClear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
		Menu.LastHit:MenuElement({id = "Q", name = "Q", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoW"})
		Menu.Auto:MenuElement({id = "W", name = "AutoW on HardCC Target", value = true})
	Menu:MenuElement({type = MENU, id = "KS", name = "KillSteal"})
		Menu.KS:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
end

function zgYorick:OnAttack()
	if self.qAttackReset then
		_G.SDK.Attack.Reset = false
		self.qAttackReset = false
	end
end

function zgYorick:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:LastHit()
		self:Harass()
	elseif Mode == "LaneClear" then
		self:LaneClear()
		self:JungleClear()
	elseif Mode == "LastHit" then
		self:LastHit()
	end
	self:KillSteal()
	self:AutoW()
end

function zgYorick:CastW(target)
	local Pred = GGPrediction:SpellPrediction(self.wSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_W, Pred.CastPosition)
	end
end

function zgYorick:CastE(target)
	local Pred = GGPrediction:SpellPrediction(self.eSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.CastPosition)
	end
end

function zgYorick:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "YorickQ" and lastQ + 250 < GetTickCount() then
		local target = GetTarget(myHero.range + myHero.boundingRadius * 2 + 50)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() then
		local target = GetTarget(self.wSpell.Range)
		if IsValid(target) then
			self:CastW(target)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
	if Menu.Combo.R1:Value() and IsReady(_R) and myHero:GetSpellData(_R).name == "YorickR" then
		local target = GetTarget(self.rSpell.Range)
		if IsValid(target) then
			Control.CastSpell(HK_R, target)
		end
	end
	if Menu.Combo.Q2:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "YorickQ2" and not HaveBuff(myHero, "yorickqbuff") and lastQ + 300 < GetTickCount() then
		Control.CastSpell(HK_Q)
		lastQ = GetTickCount()
	end
end

function zgYorick:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			self:CastE(target)
		end
	end
end

function zgYorick:LaneClear()
	local minions = _G.SDK.ObjectManager:GetEnemyMinions(myHero.range + 50 + myHero.boundingRadius * 2)
	for _, minion in ipairs(minions) do
		if IsValid(minion) then
			if Menu.LaneClear.Q:Value() and IsReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" then
				if self:GetQDmg(minion) >= minion.health then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
					self.qAttackReset = true
					Control.Attack(minion)
				end
			end
			if Menu.LaneClear.Q2:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "YorickQ2" and not HaveBuff(myHero, "yorickqbuff") and lastQ + 300 < GetTickCount() then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
		end
	end
end

function zgYorick:JungleClear()
	local minions = _G.SDK.ObjectManager:GetMonsters(myHero.range + 50 + myHero.boundingRadius * 2)
	table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
	for _, minion in ipairs(minions) do
		if IsValid(minion) then
			if Menu.JungleClear.Q:Value() and IsReady(_Q) and lastQ + 300 < GetTickCount() and myHero:GetSpellData(_Q).name == "YorickQ" then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
			if Menu.JungleClear.Q2:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "YorickQ2" and not HaveBuff(myHero, "yorickqbuff") and lastQ + 300 < GetTickCount() then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
			if Menu.JungleClear.E:Value() and IsReady(_E) then
				Control.CastSpell(HK_E, minion)
			end
		end
	end
end

function zgYorick:LastHit()
	if Menu.LastHit.Q:Value() and IsReady(_Q) and myHero:GetSpellData(_Q).name == "YorickQ" and lastQ + 300 < GetTickCount() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(myHero.range + 50 + myHero.boundingRadius * 2)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and self:GetQDmg(minion) >= minion.health then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
				self.qAttackReset = true
				Control.Attack(minion)
			end
		end
	end
end

function zgYorick:KillSteal()
	if IsReady(_E) and Menu.KS.E:Value() then
		local target = GetTarget(self.eSpell.Range)
		if IsValid(target) then
			if self:GetEDmg(target) >= target.health then
				self:CastE(target)
			end
		end
	end
end

function zgYorick:GetQDmg(target)
	local qlvl = myHero:GetSpellData(_Q).level
	local qbaseDmg = 25 * qlvl + 5
	local qadDmg = myHero.totalDamage * 0.5
	local qDmg = qbaseDmg + qadDmg + myHero.totalDamage
	if target.type == Obj_AI_Minion then
		qDmg = (qbaseDmg + qadDmg)/2 + myHero.totalDamage
	end
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, qDmg) 
end

function zgYorick:GetEDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local eDmg = target.maxHealth * ((0.5 * elvl + 5.5)/100 + 0.0003 * myHero.ap)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function zgYorick:AutoW()
	for _, target in pairs(GetEnemyHeroes()) do
		if Menu.Auto.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and (IsInvulnerable(target) or IsHardCC(target)) then
			if myHero.pos:DistanceTo(target.pos) <= self.wSpell.Range then
				self:CastW(target)
				lastW = GetTickCount()
			end
		end
	end
end

function zgYorick:Draw()
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(225, 225, 125, 10))
	end
end

zgYorick()