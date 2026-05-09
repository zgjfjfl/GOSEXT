local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgUdyr"

function zgUdyr:__init()		 
	print("Zgjfjfl AIO - Udyr Loaded") 
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
end

function zgUdyr:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Style", name = "Playstyle Set"})
		Menu.Style:MenuElement({id = "MainR", name = "Main R Playstyle", value = true,
		callback = function(val)
			if val and Menu.Style.MainQ then Menu.Style.MainQ:Value(false) end
		end})
		Menu.Style:MenuElement({id = "MainQ", name = "Main Q Playstyle", value = false,
		callback = function(val)
			if val and Menu.Style.MainR then Menu.Style.MainR:Value(false) end
		end})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
		Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "Whp", name = "[W] use when self hp% < X ", value = 50, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "W2hp", name = "use AwakenedW when self hp% < X ", value = 30, min = 0, max = 100, step = 5})
		Menu.Combo:MenuElement({id = "E", name = "[E]", toggle = true, value = true})
		Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Jungle Clear"})
		Menu.Clear:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "W", name = "[W]", toggle = true, value = true})
		Menu.Clear:MenuElement({id = "Whp", name = "[W] use when self X% hp", value = 30, min = 0, max = 100, step = 5})
		Menu.Clear:MenuElement({id = "R", name = "[R]", toggle = true, value = true})
end

function zgUdyr:Tick()
	if ShouldWait() then
		return
	end
	if IsCasting() then return end
	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
	elseif Mode == "LaneClear" then
		self:JungleClear()
	end
end

function zgUdyr:Combo()
	local target = GetTarget(800)
	if IsValid(target) then
		local hasAwakenedQ = HaveBuff(myHero, "udyrqrecastready")
		local hasAwakenedW = HaveBuff(myHero, "udyrwrecastready")
		local hasAwakenedE = HaveBuff(myHero, "udyrerecastready")
		local hasAwakenedR = HaveBuff(myHero, "udyrrrecastready")
		local R1Buff, R1BuffData = GetBuffData(myHero, "UdyrRActivation")
		local haspassiveAA = HaveBuff(myHero, "UdyrPAttackReady")
		if Menu.Combo.E:Value() and IsReady(_E) and lastE + 250 < GetTickCount() and not hasAwakenedE then
			if (Menu.Style.MainR:Value() and not hasAwakenedR) or (Menu.Style.MainQ:Value() and not hasAwakenedQ) then
				Control.CastSpell(HK_E)
				lastE = GetTickCount()
			end
		end
		if myHero.health/myHero.maxHealth <= Menu.Combo.Whp:Value()/100 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and GetEnemyCount(600, myHero.pos) >= 1 and not hasAwakenedW then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if myHero.health/myHero.maxHealth <= Menu.Combo.W2hp:Value()/100 and Menu.Combo.W:Value() and IsReady(_W) and lastW + 250 < GetTickCount() and hasAwakenedW and GetEnemyCount(600, myHero.pos) >= 1 then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		end
		if Menu.Style.MainR:Value() then
			if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
				if ((not IsReady(_E) and not hasAwakenedR) or hasAwakenedE or (hasAwakenedR and R1Buff and R1BuffData.duration < 1.5)) and myHero.pos:DistanceTo(target.pos) < 450 then
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end
			end
			if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE) and (not IsReady(_R) or not hasAwakenedR) and not hasAwakenedQ and myHero.pos:DistanceTo(target.pos) < 300 then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			end
		end
		if Menu.Style.MainQ:Value() then
			if Menu.Combo.Q:Value() and IsReady(_Q) and lastQ + 250 < GetTickCount() then
				if ((not IsReady(_E) and not hasAwakenedQ) or hasAwakenedE or (hasAwakenedQ and not haspassiveAA)) and myHero.pos:DistanceTo(target.pos) < 300 then
					Control.CastSpell(HK_Q)
					lastQ = GetTickCount()
				end
			end
			if Menu.Combo.R:Value() and IsReady(_R) and lastR + 250 < GetTickCount() then
				if (not IsReady(_E) or hasAwakenedE) and (not IsReady(_Q) or not hasAwakenedQ) and not hasAwakenedR and myHero.pos:DistanceTo(target.pos) < 450 then
					Control.CastSpell(HK_R)
					lastR = GetTickCount()
				end
			end
		end
	end
end

function zgUdyr:JungleClear()
	local count = GetMinionCount(450, myHero.pos)
	local hasAwakenedQ = HaveBuff(myHero, "udyrqrecastready")
	local hasAwakenedR = HaveBuff(myHero, "udyrrrecastready")
	local haspassiveAA = HaveBuff(myHero, "UdyrPAttackReady")
	local R1Buff, R1BuffData = GetBuffData(myHero, "UdyrRActivation")
	local target = _G.SDK.HealthPrediction:GetJungleTarget()
	if target and not haspassiveAA then
		if Menu.Clear.Q:Value() and IsReady(_Q) and count == 1 then
			Control.CastSpell(HK_Q)
				if hasAwakenedQ then
					Control.CastSpell(HK_Q)
				end
		elseif not hasAwakenedR and IsReady(_R) and not IsReady(_Q) then
			Control.CastSpell(HK_R)
		end
		if Menu.Clear.R:Value() and IsReady(_R) and count > 1 then
			Control.CastSpell(HK_R)
				if hasAwakenedR and R1Buff and R1BuffData.duration < 0.5 then
					Control.CastSpell(HK_R)
				end
		elseif not hasAwakenedQ and IsReady(_Q) and not IsReady(_R) then
			Control.CastSpell(HK_Q)
		end
		if myHero.health/myHero.maxHealth <= Menu.Clear.Whp:Value()/100 and Menu.Clear.W:Value() and IsReady(_W) then
			Control.CastSpell(HK_W)
		end
	end
end

zgUdyr()