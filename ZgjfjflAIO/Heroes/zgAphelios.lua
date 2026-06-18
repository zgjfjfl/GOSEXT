local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAphelios"

function zgAphelios:__init()		 
	print("Zgjfjfl AIO - Aphelios Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	self.GreenQSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.35, Radius = 60, Range = 1450, Speed = 1850, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}}
	self.BlueQSpell = {Type = GGPrediction.SPELLTYPE_CONE, Delay = 0.4, Angle = 40, Range = 800, Speed = 1850, Collision = false}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 300, Range = 1300, Speed = 1000, Collision = false}
	self.GunCDs = {Green = 0, Purple = 0, Red = 0, White = 0, Blue = 0}
	self.IgnoreCalibrumTarget = nil
	self.IgnoreCalibrumUntil = 0
	self.LastAttackWasWhite = false
end

function zgAphelios:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgAphelios:OnPreAttack(args)
	if not args or not args.Process or not IsValid(args.Target) then
		return
	end
	local force = _G.SDK.Orbwalker.ForceTarget
	if force and force.networkID == args.Target.networkID and HaveBuff(args.Target, "aphelioscalibrumbonusrangedebuff") then
		self.IgnoreCalibrumTarget = args.Target.networkID
		self.IgnoreCalibrumUntil = Game.Timer() + 1.25
		_G.SDK.Orbwalker.ForceTarget = nil
	end
	self.LastAttackWasWhite = self:MainGun() == "White"
end

function zgAphelios:OnPostAttack()
	local target = _G.SDK.Orbwalker.LastTarget or _G.SDK.Orbwalker:GetTarget()
	if self.LastAttackWasWhite and IsValid(target) then
		local delay = self:GetWhiteResetDelay(target)
		DelayAction(function()
			if self:MainGun() == "White" then
				_G.SDK.Orbwalker:__OnAutoAttackReset()
			end
		end, delay)
	end
	self.LastAttackWasWhite = false
end

function zgAphelios:GetWhiteResetDelay(target)
	local distance = target.distance
	local initialSpeed = 5000
	local minSpeed = 1700
	local deceleration = 6000
	local decelTime = (initialSpeed - minSpeed) / deceleration
	local decelDistance = initialSpeed * decelTime - 0.5 * deceleration * decelTime * decelTime
	local outTime = distance <= decelDistance
		and (initialSpeed - math.sqrt(initialSpeed * initialSpeed - 2 * deceleration * distance)) / deceleration
		or decelTime + ((distance - decelDistance) / minSpeed)
	local returnSpeed = 600 + math.max(0, myHero.attackSpeed - 1) * 750
	return math.max(0.05, outTime + (distance / returnSpeed) + 0.03)
end

function zgAphelios:PriorityAttack()
	_G.SDK.Orbwalker.ForceTarget = nil
	local debuffTargets = {}
	local currentTime = Game.Timer()
	if self.IgnoreCalibrumUntil < currentTime then
		self.IgnoreCalibrumTarget = nil
	end
	for _, enemy in ipairs(GetEnemyHeroes()) do
		if IsValid(enemy) and HaveBuff(enemy, "aphelioscalibrumbonusrangedebuff") and enemy.distance < 1800 then
			if enemy.networkID ~= self.IgnoreCalibrumTarget then
				table.insert(debuffTargets, enemy)
			end
		end
	end
	if #debuffTargets > 0 then
		local target = GetTarget(debuffTargets)
		if IsValid(target) then
			_G.SDK.Orbwalker.ForceTarget = target
		end
	end
end

function zgAphelios:OnTick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "ApheliosSeverumQ") then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	self:SemiR()
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgAphelios:IsOffGunReady()
	local currentTime = Game.Timer()
	local qData = myHero:GetSpellData(_Q)
	local mainGun = self:MainGun()
	local offGun = self:OffGun()
	if not offGun then
		return false
	end
	if Game.CanUseSpell(_Q) ~= 0 then
		if mainGun then
			self.GunCDs[mainGun] = currentTime + qData.currentCd
		end
	end
	local offGunCd = self.GunCDs[offGun]
	if not offGunCd then
		self.GunCDs[offGun] = 0
		offGunCd = 0
	end
	return offGunCd < currentTime and myHero.mana > 60
end

function zgAphelios:MainGun()
	if myHero:GetSpellData(_Q).name == "ApheliosCalibrumQ" then
		return "Green" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosGravitumQ" then
		return "Purple" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosSeverumQ" then
		return "Red" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosCrescendumQ" then
		return "White" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosInfernumQ" then
		return "Blue" 
	end
end

function zgAphelios:OffGun()
	if HaveBuff(myHero, "ApheliosOffHandBuffCalibrum") then
		return "Green" 
	elseif HaveBuff(myHero, "ApheliosOffHandBuffGravitum") then
		return "Purple" 
	elseif HaveBuff(myHero,  "ApheliosOffHandBuffSeverum") then
		return "Red" 
	elseif HaveBuff(myHero, "ApheliosOffHandBuffCrescendum") then
		return "White" 
	elseif HaveBuff(myHero,  "ApheliosOffHandBuffInfernum") then
		return "Blue" 
	end
end

function zgAphelios:SemiR()
	if Menu.Combo.SemiR:Value() and IsReady(_R) then
		local target = GetTarget(self.RSpell.Range)
		if IsValid(target) and target.pos2D.onScreen then
			local offGun = self:OffGun()
			if lastW + 1000 < GetTickCount() and (myHero.health < myHero.maxHealth * 0.5 and offGun == "Red" or offGun == "Blue") then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
			CastSpellAOE(HK_R, self.RSpell, 1, myHero)
		end
	end
end

function zgAphelios:Combo()
	self:PriorityAttack()
	local mainGun = self:MainGun()
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		if self:CastComboQ(mainGun) then
			return
		end
	end
	local orbwalker = _G.SDK.Orbwalker:GetTarget()
	if not orbwalker then
		return
	end
	if myHero.levelData.lvl > 1 and Menu.Combo.W:Value() and self:IsOffGunReady() and lastW + 1000 < GetTickCount() then
		if self:ShouldSwapCombo(mainGun) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
end

function zgAphelios:CastComboQ(mainGun)
	if mainGun == "Red" then
		local target = GetTarget(550 + myHero.boundingRadius * 2)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			return true
		end
	elseif mainGun == "Green" then
		local target = GetTarget(self.GreenQSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			return self:CastGreenQ(target)
		end
	elseif mainGun == "Blue" then
		local target = GetTarget(self.BlueQSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			return self:CastBlueQ(target)
		end
	elseif mainGun == "Purple" then
		for _, target in ipairs(GetEnemyHeroes()) do
			if IsValid(target) and target.pos:ToScreen().onScreen and HaveBuff(target, "ApheliosGravitumDebuff") then
				Control.CastSpell(HK_Q)
				return true
			end
		end
	end
	return false
end

function zgAphelios:ShouldSwapCombo(mainGun)
	local qState = Game.CanUseSpell(_Q)
	if mainGun == "Purple" and qState == 8 then
		return false
	end
	if mainGun == "White" and IsValid(GetTarget(650)) then
		return false
	end
	return qState ~= 0 or mainGun == "White"
end

function zgAphelios:Harass()
	self:PriorityAttack()
	local mainGun = self:MainGun()
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		if mainGun == "Red" then
			local target = GetTarget(550 + myHero.boundingRadius * 2)
			if IsValid(target) then
				Control.CastSpell(HK_Q)
			end
		elseif mainGun == "Green" then
			local target = GetTarget(self.GreenQSpell.Range)
			if IsValid(target) and target.pos:ToScreen().onScreen then
				self:CastGreenQ(target)
			end
		elseif mainGun == "Blue" then
			local target = GetTarget(self.BlueQSpell.Range)
			if IsValid(target) and target.pos:ToScreen().onScreen then
				self:CastBlueQ(target)
			end
		elseif mainGun == "Purple" then
			for _, target in ipairs(GetEnemyHeroes()) do
				if IsValid(target) and target.pos:ToScreen().onScreen and HaveBuff(target, "ApheliosGravitumDebuff") then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgAphelios:CastGreenQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.GreenQSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
		return true
	end
	return false
end

function zgAphelios:CastBlueQ(unit)
	local QPrediction = GGPrediction:SpellPrediction(self.BlueQSpell)
	QPrediction:GetPrediction(unit, myHero)
	if QPrediction:CanHit(3) then
		Control.CastSpell(HK_Q, QPrediction.CastPosition)
		return true
	end
	return false
end

function zgAphelios:CastR(unit)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(unit, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgAphelios:Draw()
	if myHero.dead then return end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 244, 66, 104))
	end
end

zgAphelios()
