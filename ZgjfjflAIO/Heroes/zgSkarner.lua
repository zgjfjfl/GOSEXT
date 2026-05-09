local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSkarner"

function zgSkarner:__init()		 
	print("Zgjfjfl AIO - Skarner Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1050, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.wSpell = {Range = 650}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.65, Radius = 150, Range = 625, Speed = math.huge, Collision = false}
end

function zgSkarner:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WCount", name = "Use W when can hit >= X enemies", value = 1, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RCount", name = "R hit x enemies", value = 2, min = 1, max = 5 })
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgSkarner:Tick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "SkarnerR") then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "LaneClear" then
		self:LaneClear()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgSkarner:Combo()
	local Qtarget = GetTarget(self.qSpell.Range)
	if Qtarget and IsValid(Qtarget) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(Qtarget.pos) > _G.SDK.Data:GetAutoAttackRange(myHero, Qtarget) then
					self:CastQ2(Qtarget)
				end
			end
		end
	end
	local Rtarget = GetTarget(self.rSpell.Range)
	if IsValid(Rtarget) then
		if Menu.Combo.R:Value() and IsReady(_R) then
			local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, Rtarget.pos, self.rSpell.Speed, self.rSpell.Delay, self.rSpell.Radius, {GGPrediction.COLLISION_ENEMYHERO}, nil)
			if collisionCount >= Menu.Combo.RCount:Value() then
				Control.CastSpell(HK_R, Rtarget)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and GetEnemyCount(self.wSpell.Range, myHero.pos) >= Menu.Combo.WCount:Value() then
		Control.CastSpell(HK_W)
	end
end

function zgSkarner:CastQ2(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		local _, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, Pred.CastPosition, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, {GGPrediction.COLLISION_MINION}, target.networkID)
		if collisionCount > 0 then
			local minion = collisionObjects[1]
			if minion.pos:DistanceTo(Pred.CastPosition) < 250 then
				Control.CastSpell(HK_Q, Pred.CastPosition)
			end
		else
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function zgSkarner:Harass()
	local Qtarget = GetTarget(self.qSpell.Range)
	if Qtarget and IsValid(Qtarget) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(Qtarget.pos) > _G.SDK.Data:GetAutoAttackRange(myHero, Qtarget) then
					self:CastQ2(Qtarget)
				end
			end
		end
	end
end

function zgSkarner:LaneClear()
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if IsValid(target) then
		if Menu.Clear.Q:Value() and IsReady(_Q) and myHero.pos:DistanceTo(target.pos) < self.qSpell.Range then
			if myHero:GetSpellData(_Q).name == "SkarnerQ" then
				Control.CastSpell(HK_Q)
			end
			if myHero:GetSpellData(_Q).name == "SkarnerQRockThrow" then
				if myHero.pos:DistanceTo(target.pos) > _G.SDK.Data:GetAutoAttackRange(myHero, target) then
					Control.CastSpell(HK_Q, target)
				end
			end
		end
		if Menu.Clear.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) < self.wSpell.Range then
			Control.CastSpell(HK_W)
		end
	end
end

function zgSkarner:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
end

zgSkarner()