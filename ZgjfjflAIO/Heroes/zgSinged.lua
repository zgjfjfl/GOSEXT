local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgSinged"

function zgSinged:__init()		 
	print("Zgjfjf AIO - Singed Loaded") 
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.wSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 265, Range = 1000, Speed = 700, Collision = false}
	self.poisonTime = 0
end

function zgSinged:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "WE", name = "Try [WE] Roots", toggle = true, value = false, key = string.byte("T")})
		Menu.Combo:MenuElement({id = "R", name = "[R] ", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR when X enemies inWrange ", value = 2, min = 1, max = 5, step = 1})
	Menu:MenuElement({type = MENU, id = "Auto", name = "AutoQ"})
		Menu.Auto:MenuElement({id = "Q", name = "Auto Q when enemies nearby", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "Qrange", name = "turn on Q enemy distance", value = 300, min = 200, max = 1000, step = 50})
		Menu.Auto:MenuElement({id = "QClear", name = "Auto Q Clear(LaneClear Mode)", toggle = true, value = true})
		Menu.Auto:MenuElement({id = "QCrange", name = "turn on Q minion distance", value = 400, min = 200, max = 1000, step = 50})
		Menu.Auto:MenuElement({id = "ClearAA", name = "Disable [AA] in Clear", toggle = true, value = false})
		Menu.Auto:MenuElement({id = "DontOffQ", name = "Do not turn off Q", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "WE", name = "Draw WE Roots Status", toggle = true, value = true})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
end

function zgSinged:Tick()
	if ShouldWait() then
		return
	end
	self:AutoQ()
	if IsCasting() then return end
	if GetMode() == "Combo" then
		self:Combo()
	end
end

function zgSinged:OnPreAttack(args)
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() then
			args.Process = false
		end
	end
	if GetMode() == "LaneClear" then
		if Menu.Auto.ClearAA:Value() then
			args.Process = false
		end
	end
end

function zgSinged:AutoQ()
	if IsReady(_Q) and lastQ + 250 < GetTickCount() then
		local shouldQBeOn = false
		if Menu.Auto.Q:Value() then
			shouldQBeOn = GetEnemyCount(Menu.Auto.Qrange:Value(), myHero.pos) >= 1
		end
		if GetMode() == "LaneClear" then
			if Menu.Auto.QClear:Value() and not shouldQBeOn then
				shouldQBeOn = GetMinionCount(Menu.Auto.QCrange:Value(), myHero.pos) > 0
			end
		end
		if shouldQBeOn then
			if myHero:GetSpellData(_Q).toggleState == 1 then
				Control.CastSpell(HK_Q)
				lastQ = GetTickCount()
			end
			if myHero:GetSpellData(_Q).toggleState == 2 then
				self.poisonTime = GetTickCount() + 1200
			end
		end
		if Menu.Auto.DontOffQ:Value() then return end
		if myHero:GetSpellData(_Q).toggleState == 2 and GetTickCount() - self.poisonTime > 1200 then
			Control.CastSpell(HK_Q)
			lastQ = GetTickCount()
		end
	end
end

function zgSinged:Combo()
	if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
		if GetEnemyCount(1000, myHero.pos) >= Menu.Combo.Rcount:Value() then
			Control.CastSpell(HK_R)
			lastR = GetTickCount()
		end
	end
	local target = GetTarget(1000)
	if IsValid(target) then
		if Menu.Combo.WE:Value() then
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= _G.SDK.Data:GetAutoAttackRange(myHero, target) then
				if Menu.Combo.W:Value() and IsReady(_W) and myHero.mana > myHero:GetSpellData(_E).mana + myHero:GetSpellData(_W).mana and target.health > self:GetEDmg(target) then
					local wCastPos = myHero.pos:Extended(target.pos, -300)
					Control.CastSpell(HK_W, wCastPos)
				end
				Control.CastSpell(HK_E, target)
			end
		else
			if Menu.Combo.W:Value() and IsReady(_W) then
				self:CastW(target)
			end
			if Menu.Combo.E:Value() and IsReady(_E) and myHero.pos:DistanceTo(target.pos) <= _G.SDK.Data:GetAutoAttackRange(myHero, target) then
				Control.CastSpell(HK_E, target)
			end
		end
	end
end

function zgSinged:GetEDmg(target)
	local elvl = myHero:GetSpellData(_E).level
	local baseDmg = 10 * elvl + 40
	local extDmg = (0.5 * elvl + 5.5)/100 * target.maxHealth + 0.55 * myHero.ap
	local eDmg = baseDmg + extDmg
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, eDmg) 
end

function zgSinged:CastW(target)
	if IsReady(_W) then
		local pred = GGPrediction:SpellPrediction(self.wSpell)
		pred:GetPrediction(target, myHero)
		if self.wSpell.Range - 80 > myHero.pos:DistanceTo(pred.CastPosition) then
			if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
				Control.CastSpell(HK_W, pred.CastPosition)
			end
		end
	end
end

function zgSinged:Draw()
	if Menu.Draw.WE:Value() then
		if Menu.Combo.WE:Value() then
			Draw.Text("Tyr WE Roots: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Tyr WE Roots: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, Draw.Color(192, 255, 255, 255))
	end
end

zgSinged()