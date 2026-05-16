local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgMaokai"

function zgMaokai:__init()
	print("Zgjfjfl AIO - Maokai Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.3, Radius = 70, Range = 600, Speed = 1600, Collision = false}
	self.wSpell = { Range = 525 }
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 50, Range = 1100, Speed = math.huge, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 600, Range = 3000, Speed = myHero:GetSpellData(_R).speed, Collision = false}
end

function zgMaokai:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "InsecQ", name = "InsecQ to ally", value = false, key = string.byte("T"), toggle = true})
		Menu.Combo:MenuElement({id = "InsecRange", name = "allies in x range use insecQ", value = 1500, min = 500, max = 3000, step = 100 })
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "R hit x enemies", value = 3, min = 1, max = 5 })
		Menu.Combo:MenuElement({id = "Rrange", name = "R max range", value = 2000, min = 500, max = 3000, step = 100 })
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
		Menu.Misc:MenuElement({id = "autoQ", name = "[Q] Auto anti gapcloser", toggle = true, value = true})
		Menu.Misc:MenuElement({id = "autoE", name = "[E] Auto on CC", toggle = true, value = true})		
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "InsecQ", name = "InsecQ", toggle = true, value = true})
end

function zgMaokai:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
	self:AutoQ()
	self:AutoE()
end

function zgMaokai:GetNearestAlly()
	if not Menu.Combo.InsecQ:Value() or not IsReady(_Q) then
		return nil
	end
	
	local allies = _G.SDK.ObjectManager:GetAllyHeroes(Menu.Combo.InsecRange:Value())
	local nearestAlly = nil
	local nearestDistance = math.huge
	
	for i, ally in ipairs(allies) do
		if not ally.isMe and IsValid(ally) then
			local distance = myHero.pos:DistanceTo(ally.pos)
			if distance < nearestDistance then
				nearestDistance = distance
				nearestAlly = ally
			end
		end
	end
	
	return nearestAlly
end

function zgMaokai:OnPreAttack(args)
	local Mode = GetMode()
	if Mode == "Combo" then
		if IsReady(_Q) or IsReady(_W) then
			args.Process = false
		end
	end
end

function zgMaokai:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(self.qSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgMaokai:CastE(target)
	local Pred = GGPrediction:SpellPrediction(self.eSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_E, Pred.UnitPosition)
	end
end

function zgMaokai:Combo()
	if Menu.Combo.E:Value() and IsReady(_E) then
		local Etarget = GetTarget(self.eSpell.Range)
		if IsValid(Etarget) then
			if not IsReady(_W) or Etarget.distance < self.wSpell.Range then
				self:CastE(Etarget)
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local Wtarget = GetTarget(self.wSpell.Range)
		if Wtarget and IsValid(Wtarget) then
			Control.CastSpell(HK_W, Wtarget)
		end
	end
	if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_W) then
		local Qtarget = GetTarget(self.qSpell.Range)
		if IsValid(Qtarget) then
			local nearestAlly = self:GetNearestAlly()
			if nearestAlly == nil then
				self:CastQ(Qtarget)
			else
				if myHero.pos:DistanceTo(Qtarget.pos) <= 325 then
					local KnockbackPos = Qtarget.pos + (Qtarget.pos - myHero.pos):Normalized() * 300
					if KnockbackPos:DistanceTo(nearestAlly.pos) < Qtarget.pos:DistanceTo(nearestAlly.pos) or Qtarget.pos:DistanceTo(nearestAlly.pos) < 300 then
						Control.CastSpell(HK_Q, Qtarget)
					end
				end
			end
		end
	end
	if IsReady(_R) and Menu.Combo.R:Value() then
		local Rtarget = GetTarget(Menu.Combo.Rrange:Value())
		if IsValid(Rtarget) then
			if GetEnemyCount(self.rSpell.Radius, Rtarget.pos) >= Menu.Combo.Rcount:Value() then
				Control.CastSpell(HK_R, Rtarget)
			end
		end
	end
end

function zgMaokai:Harass()
	local Qtarget = GetTarget(self.qSpell.Range)
	if Qtarget and IsValid(Qtarget) then
		if Menu.Harass.Q:Value() and IsReady(_Q) then
			self:CastQ(Qtarget)
		end
	end
	local Etarget = GetTarget(self.eSpell.Range)
	if Etarget and IsValid(Etarget) then
		if Menu.Harass.E:Value() and IsReady(_E) then
			self:CastE(Etarget)
		end
	end
end

function zgMaokai:AutoQ()
	if not Menu.Misc.autoQ:Value() or not IsReady(_Q) then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(1500)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy.pathing.isDashing then
			if myHero.pos:DistanceTo(enemy.pathing.endPos) <= 325 then
				Control.CastSpell(HK_Q, enemy.pathing.endPos)
			end
		end
	end
end

function zgMaokai:AutoE()
	if not Menu.Misc.autoE:Value() or not IsReady(_E) then return end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.eSpell.Range)
	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and IsHardCC(enemy) then
			self:CastE(enemy)
		end
	end
end
	
function zgMaokai:Draw()
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, Menu.Combo.Rrange:Value(), 1, Draw.Color(255, 225, 255, 10))
	end
	if Menu.Draw.InsecQ:Value() then
		if Menu.Combo.InsecQ:Value() then
			Draw.Text("InsecQ:ON", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 000, 255, 000))
		else
			Draw.Text("InsecQ:OFF", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(255, 255, 000, 000))
		end
	end
end

zgMaokai()