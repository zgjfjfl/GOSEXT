local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgTwistedFate"

function zgTwistedFate:__init()
	print("Zgjfjfl AIO - TwistedFate Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 40, Range = 1400, Speed = 1450, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	RSpell = { Range = 5500 }
end

function zgTwistedFate:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Combo:MenuElement({id = "QRange", name = "Use Q| MaxRange", value = 1400, min = 600, max = 1400, step = 50})
	Menu.Combo:MenuElement({id = "W", name = "Use W", value = true})
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", value = true})
    Menu:MenuElement({type = MENU, id = "Key", name = "Card Picker"})
    Menu.Key:MenuElement({id = "Gold", name = "Pick Gold Card", key = string.byte("E")})
    Menu.Key:MenuElement({id = "Blue", name = "Pick Blue Card", key = string.byte("T")})
    Menu.Key:MenuElement({id = "Red", name = "Pick Red Card", key = string.byte("Z")})
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = true, key = string.byte("H")})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear.LaneClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu.Clear.LaneClear:MenuElement({id = "WCount", name = "If W CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", value = true})
	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", value = true})
	Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", value = true})
	Menu.Draw:MenuElement({id = "R", name = "[R] Range", value = false})
	Menu.Draw:MenuElement({id = "Rmin", name = "[R] Range on minimap", value = false})
end

function zgTwistedFate:OnTick()
	if IsCasting() or ShouldWait() then return end
	self:AutoPick()
	local mode = GetMode()
	if mode == "Combo" then
		self:Combo()
	elseif mode == "Harass" then
		self:Harass()
	elseif mode == "LaneClear" then
		self:FarmHarass()
		self:LaneClear()
		self:JungleClear()
	end
end

local wantCard = nil
function zgTwistedFate:AutoPick()
	if GetTickCount() < LevelUpKeyTimer + 1000 then
		return
	end
	local wData = myHero:GetSpellData(_W)
	if not IsReady(_W) then return end
	if Menu.Key.Gold:Value() or myHero:GetSpellData(_R).name == "Gate" then
		wantCard = "Gold"
	elseif Menu.Key.Blue:Value() then
		wantCard = "Blue"
	elseif Menu.Key.Red:Value() then
		wantCard = "Red"
	end
	if wantCard == nil then return end
	if lastW + 200 < GetTickCount() then
		if wData.name == "PickACard" then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		elseif HaveBuff(myHero, "pickacard_tracker") then
			local wantSpellName = wantCard .. "CardLock"
			if wData.name == wantSpellName then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
				wantCard = nil
			end
		end
	end
end

function zgTwistedFate:PickCard(card)
	local wData = myHero:GetSpellData(_W)
	if lastW + 200 < GetTickCount() then
		if wData.name == "PickACard" then
			Control.CastSpell(HK_W)
			lastW = GetTickCount()
		elseif HaveBuff(myHero, "pickacard_tracker") then
			local wantSpellName = card .. "CardLock"
			if wData.name == wantSpellName then
				Control.CastSpell(HK_W)
				lastW = GetTickCount()
			end
		end
	end
end

function zgTwistedFate:Combo()
	local qData = myHero:GetSpellData(_Q)
	local wData = myHero:GetSpellData(_W)
	local rData = myHero:GetSpellData(_R)
	if Menu.Combo.Q:Value() and IsReady(_Q) then
		local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(Menu.Combo.QRange:Value())
		if IsValid(target) then
			if wData.level == 0 or (not HaveBuff(myHero, "pickacard_tracker") and (wData.currentCd > 3 or GetEnemyCount(950, myHero.pos) == 0)) then
				if myHero.mana > rData.mana + qData.mana then
					self:CastQ(target)
				end
			end
		end
	end
	if Menu.Combo.W:Value() and IsReady(_W) then
		local target = GetTarget(1100)
		if IsValid(target) then
			if myHero.mana < rData.mana + qData.mana + wData.mana then
				self:PickCard("Blue")
				return
			end
			self:PickCard("Gold")
		end
	end
end

function zgTwistedFate:Harass()
	local qData = myHero:GetSpellData(_Q)
	local wData = myHero:GetSpellData(_W)
	local rData = myHero:GetSpellData(_R)
	if Menu.Harass.Q:Value() and IsReady(_Q) then
		local target = GetTarget(Menu.Combo.QRange:Value())
		if IsValid(target) then
			if not HaveBuff(myHero, "pickacard_tracker") and (wData.currentCd > 3 or GetEnemyCount(950, myHero.pos) == 0) then
				if myHero.mana > rData.mana + qData.mana + wData.mana then
					self:CastQ(target)
				end
			end
		end
	end
	if Menu.Harass.W:Value() and IsReady(_W) then
		local target = GetTarget(1100)
		if IsValid(target) then
			if myHero.mana < rData.mana + qData.mana + wData.mana then
				self:PickCard("Blue")
				return
			end
			self:PickCard("Gold")
		end
	end
end

function zgTwistedFate:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

function zgTwistedFate:LaneClear()
	local target = _G.SDK.Orbwalker:GetTarget()
	if target and IsReady(_W) then
		if (target.type == Obj_AI_Turret or target.type == Obj_AI_Barracks or target.type == Obj_AI_Nexus) then
			self:PickCard("Blue")
		end
	end
	if IsUnderTurret(myHero) then return end
	local qData = myHero:GetSpellData(_Q)
	local wData = myHero:GetSpellData(_W)
	local rData = myHero:GetSpellData(_R)
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(Menu.Combo.QRange:Value())
		table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
				if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
					local _, _, collisionCount = GGPrediction:GetCollision(myHero.pos, minion.pos, QSpell.Speed, QSpell.Delay, QSpell.Radius, {GGPrediction.COLLISION_MINION}, nil)
					if collisionCount >= Menu.Clear.LaneClear.QCount:Value() and myHero.mana > rData.mana + qData.mana then
						Control.CastSpell(HK_Q, minion)
					end
				end
				if Menu.Clear.LaneClear.W:Value() and IsReady(_W) then
					if myHero.mana > rData.mana + qData.mana + wData.mana then
						if #minions >= Menu.Clear.LaneClear.WCount:Value() then
							self:PickCard("Red")
						else
							self:PickCard("Blue")
						end
					else
						self:PickCard("Blue")
					end
				end
			end
		end
	end
end

function zgTwistedFate:JungleClear()
	local qData = myHero:GetSpellData(_Q)
	local wData = myHero:GetSpellData(_W)
	local rData = myHero:GetSpellData(_R)
	if Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetMonsters(myHero.range + 100)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for _, minion in ipairs(minions) do
			if IsValid(minion) then
				if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) and myHero.mana > rData.mana + qData.mana then
					Control.CastSpell(HK_Q, minion)
				end
				if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
					if myHero.mana > rData.mana + qData.mana + wData.mana then
						if #minions >= 2 then
							self:PickCard("Red")
						else
							self:PickCard("Gold")
						end
					else
						self:PickCard("Blue")
					end
				end
			end
		end
	end
end

function zgTwistedFate:CastQ(target)
	local Pred = GGPrediction:SpellPrediction(QSpell)
	Pred:GetPrediction(target, myHero)
	if Pred:CanHit(3) then
		Control.CastSpell(HK_Q, Pred.CastPosition)
	end
end

function zgTwistedFate:Draw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Clear.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.DrawHarass:Value() then
		if Menu.Clear.SpellHarass:Value() then
			Draw.Text("Spell Harass: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Harass: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+78, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.Q:Value() then
		Draw.Circle(myHero.pos, Menu.Combo.QRange:Value(), 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.R:Value() then
		Draw.Circle(myHero.pos, RSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.Rmin:Value() and IsReady(_R) then
		Draw.CircleMinimap(myHero.pos, RSpell.Range, 1, Draw.Color(200, 14, 194, 255))
	end
end

zgTwistedFate()
