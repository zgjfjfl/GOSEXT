local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgNautilus"

function zgNautilus:__init()
	print("Zgjfjfl AIO - Nautilus Loaded")
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 90, Range = 1150, Speed = 2000, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
end

function zgNautilus:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	--combo
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})
		Menu.Combo:MenuElement({id = "Quseon", name = "Use Q on: ", type = MENU})
		_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
			Menu.Combo.Quseon:MenuElement({id = args.charName, name = args.charName, value = true})
		end)
		Menu.Combo:MenuElement({id = "range", name = "Max Cast Q In range", value = 1000, min = 600, max = 1150, step = 50})
		Menu.Combo:MenuElement({id = "UseW", name = "[W] AA reset", value = true})
		Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})
	--Harass
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "UseQ", name = "Q", value = true})
		Menu.Harass:MenuElement({id = "Quseon", name = "Use Q on: ", type = MENU})
		_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
			Menu.Harass.Quseon:MenuElement({id = args.charName, name = args.charName, value = true})
		end)
		Menu.Harass:MenuElement({id = "range", name = "Max Cast Q In range", value = 1000, min = 600, max = 1150, step = 50})
	--Draw
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
		Menu.Drawing:MenuElement({id = "Q", name = "Draw [Q] Range", value = true})
end

function zgNautilus:Draw()
	if myHero.dead then return end
	if Menu.Drawing.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(80 ,0xFF,0xFF,0xFF))
	end
end


function zgNautilus:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	if GetMode() == "Combo" then
		self:Combo()
	elseif GetMode() == "Harass" then
		self:Harass()
	end
end

function zgNautilus:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.QSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		if self:CheckWall(myHero.pos, Vector(Pred.CastPosition)) then
			Control.CastSpell(HK_Q, Pred.CastPosition)
		end
	end
end

function zgNautilus:OnPostAttack()
	if GetMode() == "Combo" then
		local target = _G.SDK.Orbwalker:GetTarget()
		if IsValid(target) and target.type == Obj_AI_Hero then
			if Menu.Combo.UseW:Value() and IsReady(_W) and lastW + 350 < GetTickCount() then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
	end
end

function zgNautilus:Combo()
	if Menu.Combo.UseQ:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and Menu.Combo.Quseon[target.charName] and Menu.Combo.Quseon[target.charName]:Value() then
			if GetDistance(myHero.pos, target.pos) <= Menu.Combo.range:Value() and GetDistance(myHero.pos, target.pos) > myHero.range + myHero.boundingRadius + target.boundingRadius then 
				self:CastQ(target)
			end
		end
	end
	if Menu.Combo.UseE:Value() and IsReady(_E) then
		local target = GetTarget(350)
		if IsValid(target) then
			Control.CastSpell(HK_E)
		end
	end
end

function zgNautilus:Harass()
	if Menu.Harass.UseQ:Value() and IsReady(_Q) then
		local target = GetTarget(self.QSpell.Range)
		if IsValid(target) and Menu.Harass.Quseon[target.charName] and Menu.Harass.Quseon[target.charName]:Value() then
			if GetDistance(myHero.pos, target.pos) <= Menu.Harass.range:Value() and GetDistance(myHero.pos, target.pos) > myHero.range + myHero.boundingRadius + target.boundingRadius then 
				self:CastQ(target)
			end
		end
	end
end

function zgNautilus:CheckWall(from, to)
	local startPos = from
	local direction = (to - from):Normalized()
	local distance = GetDistance(from, to)
	for i = 0, distance, 25 do
		local checkPos = startPos + direction * i
		if Game.isWall(checkPos) then
			return false
		end
	end
	return true
end

zgNautilus()
