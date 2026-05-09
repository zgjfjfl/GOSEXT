local Version = 1.01

require("GGPrediction")
require("MapPositionGOS")
require("ZgjfjflAIO\\Utils")

class "zgMaokai"

function zgMaokai:__init()
	print("Zgjfjfl AIO - Maokai Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.38, Radius = 70, Range = 600, Speed = 1600, Collision = false}
	self.wSpell = { Range = 525 }
	self.eSpell = { Range = 1100 }
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
		Menu.Combo:MenuElement({id = "Rcount", name = "R hit x enemies", value = 2, min = 1, max = 5 })
		Menu.Combo:MenuElement({id = "Rrange", name = "R max range", value = 2000, min = 500, max = 3000, step = 100 })
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E] only on target", toggle = true, value = false})
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
	if Menu.Combo.InsecQ:Value() then
		local allies = _G.SDK.ObjectManager:GetAllyHeroes(Menu.Combo.InsecRange:Value())
		for i, ally in ipairs(allies) do
			if not ally.isMe then
				Qtoward = ally.pos
			end
		end
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "Harass" then
		self:Harass()
	end
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


function zgMaokai:Combo()
	local Etarget = GetTarget(self.eSpell.Range)
	if IsValid(Etarget) then
		if Menu.Combo.E:Value() and IsReady(_E) then
			Control.CastSpell(HK_E, Etarget)
		end
	end
	local Wtarget = GetTarget(self.wSpell.Range)
	if Wtarget and IsValid(Wtarget) then
		if Menu.Combo.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W, Wtarget)
		end
	end
	local Qtarget = GetTarget(self.qSpell.Range)
	if IsValid(Qtarget) then
		if Menu.Combo.Q:Value() and IsReady(_Q) and not IsReady(_W) then
			if not Menu.Combo.InsecQ:Value() or Qtoward == nil then
				self:CastQ(Qtarget)
			elseif Qtoward ~= nil then
				local Pos = Qtarget.pos + (Qtarget.pos - Qtoward):Normalized() * 250
				if MapPosition:inWall(Pos) then
					self:CastQ(Qtarget)
				elseif myHero.pos:DistanceTo(Pos) < 100 then
					self:CastQ(Qtarget)
				end
			end
		end
	end
	local Rtarget = GetTarget(Menu.Combo.Rrange:Value())
	if IsValid(Rtarget) then
		if IsReady(_R) and Menu.Combo.R:Value() then
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
			Control.CastSpell(HK_E, Etarget)
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