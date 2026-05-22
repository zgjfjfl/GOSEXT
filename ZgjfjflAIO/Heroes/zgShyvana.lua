local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgShyvana"

function zgShyvana:__init()		 
	print("Zgjfjfl AIO - Shyvana Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 150, Range = 800, Speed = 1500, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.e2Spell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 345, Range = 1000, Speed = 1600, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 225, Range = 1050, Speed = 1050, Collision = false}
end

function zgShyvana:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})		
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RAOE", name = "[R] AOE", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "RAOECount", name = "[R] AOE | X enemies", value = 3, min = 1, max = 5})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Lane Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgShyvana:Tick()
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
		self:LaneClear()
	elseif Mode == "Flee" then
		self:Flee()
	end
end

function zgShyvana:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local DragonForm = HaveBuff(myHero, "ShyvanaRTransform")
		if DragonForm then
			local target = GetTarget(self.e2Spell.Range)
			if IsValid(target) then
				self:CastE(target, self.e2Spell)
			end
		else
			local target = GetTarget(self.eSpell.Range)
			if IsValid(target) then
				self:CastE(target, self.eSpell)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and myHero:GetSpellData(_W).name == "ShyvanaW" then
		local target = GetTarget(600)
		if IsValid(target) then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local target = GetTarget(myHero.range + 200)
		if IsValid(target) then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
	if Menu.Combo.RAOE:Value() and IsReady(_R)  then
		local target = GetTarget(self.rSpell.Range)
		if IsValid(target) then
			local hitCount = Menu.Combo.RAOECount:Value()
			CastSpellAOE(HK_R, self.rSpell, hitCount, myHero, target)
		end
	end
end

function zgShyvana:LaneClear()
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if not target then
		target = _G.SDK.HealthPrediction:GetLaneClearTarget()
	end
	if IsValid(target) then
		if myHero.pos:DistanceTo(target.pos) < myHero.range + 200 and Menu.Clear.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
		if Menu.Clear.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, target)
		end
	end
end

function zgShyvana:Harass()
	if Menu.Harass.E:Value() and IsReady(_E) then
		local DragonForm = HaveBuff(myHero, "ShyvanaRTransform")
		if DragonForm then
			local target = GetTarget(self.e2Spell.Range)
			if IsValid(target) then
				self:CastE(target, self.e2Spell)
			end
		else
			local target = GetTarget(self.eSpell.Range)
			if IsValid(target) then
				self:CastE(target, self.eSpell)
			end
		end
	end
end

function zgShyvana:CastE(target, Spell)
	local Pred = GGPrediction:SpellPrediction(Spell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.CastPosition)
	end
end

function zgShyvana:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "ShyvanaW" then
		Control.CastSpell(HK_W)
	end
end

function zgShyvana:Draw()
	if Menu.Draw.E:Value() and IsReady(_E)then
		Draw.Circle(myHero.pos, self.eSpell.Range, Draw.Color(192, 255, 255, 255))
	end
	if Menu.Draw.R:Value() and IsReady(_R)then
		Draw.Circle(myHero.pos, self.rSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end

zgShyvana()