local Version = 1.02

require("GGPrediction")
-- require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgBriar"
		
function zgBriar:__init()
	print("Zgjfjfl AIO - Briar Loaded")
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)	
	self.Q = {Range = 450}
	self.W = {Range = 1000}
	self.E = {Range = 600}
	self.R = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 1, Radius = 160, Range = 10000, Speed = 2000, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
end

function zgBriar:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "W2", name = "[W2] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W2Kill", name = "Auto [W2] can kills", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "EWall", name = "[E] to wall when target isHardCC", toggle = true, value = false})
		Menu.Combo:MenuElement({id = "RM", name = "[R] Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = false})
		Menu.Clear:MenuElement({id = "W2", name = "[W2]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
		Menu.Clear:MenuElement({id = "EHP", name = "Use E when self <= HP%", value = 30, min = 0, max = 100, step = 5})
end

function zgBriar:Tick()
	if HaveBuff(myHero, "BriarWFrenzyBuff") or HaveBuff(myHero, "BriarRSelf") or myHero.activeSpell.name == "BriarE" then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
    local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "LaneClear" then
		self:JungleClear()
	end
	if Menu.Combo.RM:Value() then
		self:RSemiManual()
	end
	if Menu.Combo.W2Kill:Value() then
		self:AutoW2()
	end
end

function zgBriar:Combo()
	local target = GetTarget(1000)
	if IsValid(target) then
		local buff, buffData = GetBuffData(myHero, "BriarWAttackSpell")
		if Menu.Combo.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, target.pos) <= self.Q.Range and not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
			Control.CastSpell(HK_Q, target)
		end
		if Menu.Combo.EWall:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() then
			local Pos = myHero.pos:Extended(target.pos, self.E.Range)
			local Pos2 = FindFirstWallCollision(myHero.pos, Pos)
			if Pos2 ~= nil and IsHardCC(target) and GetDistance(myHero.pos, target.pos) < self.E.Range then
				self:CastE(target)
				lastE = GetTickCount()
			end
		end
		if Menu.Combo.W:Value() and not HaveBuff(myHero, "BriarRSelf") and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and GetDistance(myHero.pos, target.pos) < self.W.Range then
			Control.CastSpell(HK_W, target)
		end
		if Menu.Combo.W2:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and _G.SDK.Data:IsInAutoAttackRange(myHero, target) and buff and buffData.duration < 3 then
			Control.CastSpell(HK_W)
		end
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() and GetDistance(myHero.pos, target.pos) < self.E.Range and myHero.health/myHero.maxHealth <= Menu.Combo.EHP:Value()/100 then
			self:CastE(target)
			lastE = GetTickCount()
		end
	end
end

function zgBriar:RSemiManual()
	local target = GetTarget(self.R.Range)
	if IsValid(target) then
		if IsReady(_R) then
			local pred = GGPrediction:SpellPrediction(self.R)
			pred:GetPrediction(target, myHero)
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_R, pred.CastPosition)
			end
		end
	end
end

function zgBriar:CastE(target)
	local mPos = mousePos
	Control.SetCursorPos(target.pos)
	Control.KeyDown(HK_E)
	DelayAction(function() Control.SetCursorPos(mPos) end, 0.1)
	DelayAction(function() Control.KeyUp(HK_E) end, 1)
end

function zgBriar:JungleClear()
	local minions = _G.SDK.ObjectManager:GetMonsters()
    for _, minion in ipairs(minions) do
		if IsValid(minion) then
			local buff, buffData = GetBuffData(myHero, "BriarWAttackSpell")
			if Menu.Clear.Q:Value() and IsReady(_Q) and GetDistance(myHero.pos, minion.pos) <= self.Q.Range then
				Control.CastSpell(HK_Q, minion)
			end
			if Menu.Clear.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarW" and GetDistance(myHero.pos, minion.pos) < self.W.Range then
				Control.CastSpell(HK_W, minion)
			end
			if Menu.Clear.W2:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and _G.SDK.Data:IsInAutoAttackRange(myHero, minion) and buff and buffData.duration < 3 then
				Control.CastSpell(HK_W)
			end
			if Menu.Clear.E:Value() and IsReady(_E) and lastE + 1100 < GetTickCount() and GetDistance(myHero.pos, minion.pos) < self.E.Range and myHero.health/myHero.maxHealth <= Menu.Clear.EHP:Value()/100 then
				self:CastE(minion)
				lastE = GetTickCount()
			end
		end
	end
end

function zgBriar:AutoW2()
	local target = GetTarget(_G.SDK.Data:GetAutoAttackRange(myHero))
	if IsValid(target) then
		local W2Dmg = self:GetW2BonusDmg(target)
		if IsReady(_W) and myHero:GetSpellData(_W).name == "BriarWAttackSpell" and W2Dmg >= (target.health + target.shieldAD) then
			Control.CastSpell(HK_W)
		end
	end
end

function zgBriar:GetW2BonusDmg(target)
	local Wlvl = myHero:GetSpellData(_W).level
	local baseDmg = 15 * Wlvl - 10
	local adDmg = myHero.totalDamage * 0.05
	local bonusDmg = (0.09 + 0.025 * math.floor(myHero.bonusDamage/100))* (target.maxHealth - target.health)
	local Dmg = baseDmg + adDmg + bonusDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, Dmg)
end

zgBriar()