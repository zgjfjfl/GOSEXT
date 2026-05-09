local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAurelionSol"

function zgAurelionSol:__init()		 
	print("Zgjfjfl AIO - AurelionSol Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0, Radius = 75, Range = 750, Speed = math.huge, Collision = false}
	self.wSpell = { Range = 1500 } 
	self.eSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 275, Range = 750, Speed = math.huge, Collision = false}
	self.rSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 1.25, Radius = 275, Range = 1250, Speed = math.huge, Collision = false}
end

function zgAurelionSol:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "DisableAA", name = "Disable [AA] in Combo", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Rcount", name = "UseR when hit X enemies", value = 3, min = 1, max = 5})
		Menu.Combo:MenuElement({id = "Rsm", name = "R Semi-Manual Key", key = string.byte("T")})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
		Menu.Harass:MenuElement({id = "Q", name = "[Q] Quick Harass", toggle = true, value = true})
		Menu.Harass:MenuElement({id = "E", name = "[E]", toggle = true, value = false})
	Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
		Menu.Flee:MenuElement({id = "W", name = "[W] to mouse direction ", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
		Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "W2", name = "[W] Range in minimap", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
		Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})
end

function zgAurelionSol:Tick()
	local passive, passiveData = GetBuffData(myHero, "AurelionSolPassive")
	self.qSpell.Range = 740 + 10 * myHero.levelData.lvl
	self.eSpell.Range = 740 + 10 * myHero.levelData.lvl
	if passive then
		self.wSpell.Range = 1500 + 7.5 * passiveData.stacks
		self.eSpell.Radius = math.sqrt(275^2+16.93^2 * passiveData.stacks)
		self.rSpell.Radius = math.sqrt(275^2+16.93^2 * passiveData.stacks)
		if myHero:GetSpellData(_R).name == "AurelionSolR2" then
			self.rSpell.Radius = math.sqrt(388.91^2+21.85^2 * passiveData.stacks)
            self.rSpell.Delay = 2.0
		end
	end
	if myHero.activeSpell.valid and (Game.Timer() >= myHero.activeSpell.startTime and Game.Timer() <= myHero.activeSpell.castEndTime) then
		return
	end
    local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "Flee" then
		self:Flee()
	end
	if Menu.Combo.Rsm:Value() then
		self:SemiManualR()
	end
	if HaveBuff(myHero, "AurelionSolQ") or myHero:GetSpellData(_W).name == "AurelionSolWToggle" then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	if Control.IsKeyDown(HK_Q) then
		DelayAction(function()
			if myHero.activeSpell.isCharging == false then
				Control.KeyUp(HK_Q)
			end
		end, 0.35)
	end
end

function zgAurelionSol:OnPreAttack(args)
	if GetMode() == "Combo" then
		if Menu.Combo.DisableAA:Value() then
			args.Process = false
		end
	end
end

function zgAurelionSol:Flee()
	if Menu.Flee.W:Value() and IsReady(_W) and myHero:GetSpellData(_W).name == "AurelionSolW" then 
		Control.CastSpell(HK_W)
	end
end

function zgAurelionSol:Combo()
    local Rtarget = GetTarget(self.rSpell.Range)
	if IsValid(Rtarget) then
		if Menu.Combo.R:Value() and IsReady(_R) and myHero.activeSpell.isCharging == false then
            local hitCount = Menu.Combo.Rcount:Value()
			CastSpellAOE(HK_R, self.rSpell, hitCount, myHero, Rtarget)
		end
	end
    local Etarget = GetTarget(self.eSpell.Range)
	if IsValid(Etarget) then
		if Menu.Combo.E:Value() and IsReady(_E) and myHero.activeSpell.isCharging == false then
			CastSpellAOE(HK_E, self.eSpell, 1, myHero, Etarget)
		end
		if Menu.Combo.Q:Value() and not IsReady(_E) then
			self:CastQ(Etarget)
		end
	end
end

function zgAurelionSol:Harass()
	if myHero:GetSpellData(_W).name == "AurelionSolWToggle" then return end
	local Etarget = GetTarget(self.eSpell.Range)
	if IsValid(Etarget) then
		if IsReady(_Q) and lastQ + 1000 < GetTickCount() then
			local mPos = mousePos
			Control.SetCursorPos(Etarget.pos)
			Control.KeyDown(HK_Q)
			DelayAction(function() 
				Control.KeyUp(HK_Q)
				Control.SetCursorPos(mPos) 
			end, 0.2)
			lastQ = GetTickCount()
		end
	end
    local Etarget = GetTarget(self.eSpell.Range)
	if IsValid(Etarget) then
		if Menu.Harass.E:Value() and IsReady(_E) then
			CastSpellAOE(HK_E, self.eSpell, 1, myHero, Etarget)
		end
	end
end

function zgAurelionSol:SemiManualR()
    local Rtarget = GetTarget(self.rSpell.Range)
	if IsValid(Rtarget) then
		if IsReady(_R) then
			CastSpellAOE(HK_R, self.rSpell, 1, myHero, Rtarget)
		end
	end
end

function zgAurelionSol:CastQ(target)
	if IsReady(_Q) then
		Control.SetCursorPos(target.pos)
		Control.KeyDown(HK_Q)
	end
end

function zgAurelionSol:CastE(target)
	local pred = GGPrediction:SpellPrediction(self.eSpell)
	pred:GetPrediction(target, myHero)
	if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
		if myHero.pos:DistanceTo(pred.CastPosition) > 750 then
			Control.CastSpell(HK_E, myHero.pos:Extended(pred.CastPosition, 750))
		else
			Control.CastSpell(HK_E, pred.CastPosition)
		end
	end
end

function zgAurelionSol:Draw()
    if myHero.dead then return end
	if Menu.Draw.Q:Value() and IsReady(_Q) then
		Draw.Circle(myHero.pos, self.qSpell.Range, 1, Draw.Color(255, 255, 255, 255))
	end
	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 255, 255))
	end
	if Menu.Draw.W2:Value() and IsReady(_W) then
		Draw.CircleMinimap(myHero.pos, self.wSpell.Range, 1, Draw.Color(200, 0, 255, 255))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
	end
	if Menu.Draw.R:Value() and IsReady(_R) then
		Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
	end
end

zgAurelionSol()