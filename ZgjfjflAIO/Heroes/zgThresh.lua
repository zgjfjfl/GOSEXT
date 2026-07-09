local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgThresh"

function zgThresh:__init()		 
	print("Zgjfjfl AIO - Thresh Loaded")
	self:LoadMenu()
end

function zgThresh:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	--ComboMenu  
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q1]", value = true})		
	Menu.Combo:MenuElement({id = "UseQ2", name = "[Q2]", value = true})	
	Menu.Combo:MenuElement({id = "UseW", name = "[W] if [Q1] and Ally out of AArange", value = true})
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	Menu.Combo:MenuElement({id = "EMode", name = "[E] Mode Key Pull/Push", key = string.byte("T"), toggle = true, value = true})	
	Menu.Combo:MenuElement({id = "UseR", name = "[R]", value = true})
	Menu.Combo:MenuElement({id = "UseRE", name = "[R] min Enemies in range", value = 2, min = 1, max = 5})	

	--HarassMenu
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})	
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q1]", value = true})	
	Menu.Harass:MenuElement({id = "UseQ2", name = "[Q2]", value = false})	
	Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"}) 

	--Extra
	Menu:MenuElement({type = MENU, id = "extra", name = "Extra Settings"})	
	Menu.extra:MenuElement({id = "Qmin", name = "[Q1] min range", value = 200, min = 1, max = 500})
	Menu.extra:MenuElement({id = "Qmax", name = "[Q1] max range", value = 900, min = 500, max = 1000})
	Menu.extra:MenuElement({id = "QTower", name = "[Q2] under enemy Turret ?", value = false})	
	Menu.extra:MenuElement({id = "QTime", name = "[Q2] waiting for cast", value = 1.2, min = 0, max = 1.4, step = 0.1, identifier = "sec"})
	Menu.extra:MenuElement({id = "UseW", name = "Auto [W] Save Ally lower than 30% Hp", value = true})
	Menu.extra:MenuElement({id = "WCount", name = "Auto [W] Save Ally if enemies near", value = 4, min = 1, max = 5})
	Menu.extra:MenuElement({id = "UseW2", name = "Auto [W] CCed Ally", value = true})
	Menu.extra:MenuElement({id = "Egap", name = "Auto [E] Anti Gapcloser", value = true})
	Menu.extra:MenuElement({id = "UseR", name = "Auto [R]", value = true})
	Menu.extra:MenuElement({id = "UseRE", name = "Auto [R] min Enemies in range", value = 3, min = 1, max = 5})	

	--Prediction
	Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction Settings"})		
	Menu.Pred:MenuElement({id = "PredQ", name = "Hitchance[Q]", value = 2, drop = {"Normal", "High", "Immobile"}})	
 
	--Drawing 
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings Settings"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
	Menu.Drawing:MenuElement({type = MENU, id = "XY", name = "Text Pos Settings"})	
	Menu.Drawing.XY:MenuElement({id = "Text", name = "Draw EMode Text", value = true})		
	Menu.Drawing.XY:MenuElement({id = "x", name = "Pos: [X]", value = 700, min = 0, max = 1500, step = 10})
	Menu.Drawing.XY:MenuElement({id = "y", name = "Pos: [Y]", value = 0, min = 0, max = 860, step = 10})				
 
	Callback.Add("Tick", function() self:Tick() end)
	
	Callback.Add("Draw", function()
		if Menu.Drawing.XY.Text:Value() then 
			Draw.Text("EMode: ", 15, Menu.Drawing.XY.x:Value(), Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 225, 255, 0))		
			if Menu.Combo.EMode:Value() then
				Draw.Text("Pull", 15, Menu.Drawing.XY.x:Value()+45, Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 0, 255, 0))
			else
				Draw.Text("Push", 15, Menu.Drawing.XY.x:Value()+45, Menu.Drawing.XY.y:Value()+10, Draw.Color(255, 0, 255, 0))
			end
		end
		
		if myHero.dead then return end
		
		if Menu.Drawing.DrawR:Value() and IsReady(_R) then
		Draw.Circle(myHero, 470, 1, DrawColor(255, 225, 255, 10))
		end
		if Menu.Drawing.DrawQ:Value() and IsReady(_Q) then
		Draw.Circle(myHero, Menu.extra.Qmax:Value(), 1, DrawColor(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawE:Value() and IsReady(_E) then
		Draw.Circle(myHero, 500, 1, DrawColor(225, 225, 125, 10))
		end
		if Menu.Drawing.DrawW:Value() and IsReady(_W) then
		Draw.Circle(myHero, 950, 1, DrawColor(225, 225, 125, 10))
		end
	end)		
end

function zgThresh:Tick()
if ShouldWait() then
	return
end

if myHero:GetSpellData(_Q).name == "ThreshQLeap" then
	_G.SDK.Orbwalker:SetAttack(false)
else
	_G.SDK.Orbwalker:SetAttack(true)
end
if IsCasting() then return end
local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
		if Menu.Combo.UseQ2:Value() and myHero:GetSpellData(_Q).name == "ThreshQLeap" then 
			DelayAction(function()
				self:CastQ2()
			end, Menu.extra.QTime:Value())
		end		
	elseif Mode == "Harass" then
		self:Harass()
		if Menu.Harass.UseQ2:Value() and myHero:GetSpellData(_Q).name == "ThreshQLeap" then
			DelayAction(function()
				self:CastQ2()
			end, Menu.extra.QTime:Value())
		end		
	end	
	self:AutoE()
	self:AutoW()
	self:AutoR()	
end
	
function zgThresh:Combo()
local target = GetTarget(1000)
if target == nil then return end
	if IsValid(target) then
		if IsReady(_E) and Menu.Combo.UseE:Value() and myHero.pos:DistanceTo(target.pos) <= 500 and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" then
			if Menu.Combo.EMode:Value() then
				self:CastE(target)
			else
				Control.CastSpell(HK_E, target.pos)
			end
		end		
		
		if Menu.Combo.UseQ:Value() and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" and myHero.pos:DistanceTo(target.pos) < Menu.extra.Qmax:Value() and myHero.pos:DistanceTo(target.pos) >= Menu.extra.Qmin:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 70, Range = 1000, Speed = 1900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}})
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end
		end
	   
		if Menu.Combo.UseW:Value() and IsReady(_W) and HaveBuff(target, "ThreshQ") then
			local Ally = self:FindNearestAlly(target)			
			if Ally and IsValid(Ally) then
				self:CastW(Ally)
			end	
		end

		if Menu.Combo.UseR:Value() and IsReady(_R) then
		local count = GetEnemyCount(450, myHero.pos)
			if count >= Menu.Combo.UseRE:Value() then
				Control.CastSpell(HK_R)
			end	
		end
	end
end

function zgThresh:Harass()
local target = GetTarget(1000)
if target == nil then return end
	if IsValid(target) then				
		
		if Menu.Harass.UseQ:Value() and myHero:GetSpellData(_Q).name ~= "ThreshQLeap" and myHero.pos:DistanceTo(target.pos) < Menu.extra.Qmax:Value() and myHero.pos:DistanceTo(target.pos) >= Menu.extra.Qmin:Value() and IsReady(_Q) then
			local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.5, Radius = 70, Range = 1100, Speed = 1900, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}})
			QPrediction:GetPrediction(target, myHero)
			if QPrediction:CanHit(Menu.Pred.PredQ:Value() + 1) then
				Control.CastSpell(HK_Q, QPrediction.CastPosition)
			end	
		end 
	end
end

function zgThresh:AutoE()
	if IsReady(_E) and Menu.extra.Egap:Value() then
		local EnemyHeroes = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
		for i = 1, #EnemyHeroes do
			local target = EnemyHeroes[i]
			if IsValid(target) and target.pathing.isDashing and not HaveBuff(target, "ThreshQ") then
				if myHero.pos:DistanceTo(target.pathing.endPos) < 400 then
					Control.CastSpell(HK_E, target)
				end
			end
		end
	end
end

function zgThresh:AutoW()	
	if IsReady(_W) then	
		
		if Menu.extra.UseW:Value() then
			local LowAlly = self:FindLowestAlly()
			if LowAlly and IsValid(LowAlly) and LowAlly.health/LowAlly.maxHealth <= 0.3 and GetEnemyCount(950, LowAlly.pos) >= Menu.extra.WCount:Value() then
				self:CastW(LowAlly)
			end
		end
		
		if Menu.extra.UseW2:Value() then
			for i, Ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
				if Ally and myHero.pos:DistanceTo(Ally.pos) <= 1200 and IsValid(Ally) and IsHardCC(Ally) then
					self:CastW(Ally)
				end
			end
		end
	end	
end	

function zgThresh:AutoR()
	if Menu.extra.UseR:Value() and IsReady(_R) then
		local count = GetEnemyCount(450, myHero.pos)
		if count >= Menu.extra.UseRE:Value() then
			Control.CastSpell(HK_R)
		end	
	end
end	

function zgThresh:CastE(unit)
	local EPos = Vector(myHero.pos) + (Vector(myHero.pos) - Vector(unit.pos))
	Control.CastSpell(HK_E, EPos)
end

function zgThresh:CastW(ally)
	local WPos = ally.pos:Extended(myHero.pos, 250)
	Control.CastSpell(HK_W, WPos)
end

function zgThresh:CastQ2()
	for i, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes()) do
		if HaveBuff(target, "ThreshQ") then
			if Menu.extra.QTower:Value() then
				if not IsUnderTurret(target) then
					Control.CastSpell(HK_Q)
				end
			else
				Control.CastSpell(HK_Q)
			end
		end
	end
end
	
function zgThresh:FindLowestAlly()
	LowestAlly = nil
	for i, Ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
		if Ally and GetDistance(Ally.pos, myHero.pos) <= 1200 and IsValid(Ally) then
			if LowestAlly == nil then
				LowestAlly = Ally
			elseif Ally.health < LowestAlly.health then
				LowestAlly = Ally
			end
		end
	end
	return LowestAlly
end

function zgThresh:FindNearestAlly(unit)
	local NearestAlly = nil
	for i, Ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes()) do
		if NearestAlly == nil then 
			if GetDistance(Ally.pos, myHero.pos) <= 1200 and IsValid(Ally) and GetDistance(Ally.pos, unit.pos) > Ally.range then
				NearestAlly = Ally
			end	
			
		elseif GetDistance(Ally.pos, myHero.pos) <= 1200 and IsValid(Ally) and GetDistance(Ally.pos, myHero.pos) > GetDistance(NearestAlly.pos, myHero.pos) and GetDistance(Ally.pos, unit.pos) > Ally.range then
			NearestAlly = Ally
		end
	end
	return NearestAlly
end

zgThresh()
