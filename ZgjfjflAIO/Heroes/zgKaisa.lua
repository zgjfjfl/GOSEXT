local Version = 1.02


require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgKaisa"

function zgKaisa:__init()
	print("Zgjfjfl AIO - Kaisa Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	self.QSpell = { Range = 665 }
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 100, Range = 3000, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
end

function zgKaisa:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "minionCount", name = "Only Q if Minions < X in range", value = 3, min = 1, max = 10, step = 1})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "minionCount", name = "Only Q if Minions < X in range", value = 3, min = 1, max = 10, step = 1})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
end

function zgKaisa:OnTick()
	if ShouldWait() then
		return
	end
	if HaveBuff(myHero, "KaisaE") then
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
end

function zgKaisa:Combo()
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and GetMinionCount(self.QSpell.Range, myHero.pos) < Menu.Combo.minionCount:Value() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			if not _G.SDK.Data:IsInAutoAttackRange(myHero, target) then
				self:CastW(target)
			end
		end
	end
end

function zgKaisa:Harass()
	if Menu.Harass.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and GetMinionCount(self.QSpell.Range, myHero.pos) < Menu.Harass.minionCount:Value() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) and target.pos:ToScreen().onScreen then
			self:CastW(target)
		end
	end
end

function zgKaisa:CastW(unit)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(unit, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgKaisa:Draw()
	if myHero.dead then return end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
end

zgKaisa()
