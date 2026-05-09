local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgJinx"

function zgJinx:__init()
	print("Zgjfjfl AIO - Jinx Loaded")
	self:LoadMenu()
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("Tick", function() self:Tick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = { Range = 525 }
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 60, Range = 1450, Speed = 3300, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}}
	self.ESpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 115, Range = 925, Speed = math.huge, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.RSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 140, Range = 25000, Speed = 1700, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.BonusAttackRange = 0
end

function zgJinx:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})

	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	Menu.Combo:MenuElement({id = "E", name = "Use E", toggle = true, value = false})

	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	Menu.Harass:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Harass:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Harass:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
	Menu.Clear:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4, callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellFarm, newValue) then return end
	end})
	Menu.Clear:MenuElement({id = "SpellHarass", name = "Use Spell Harass(In LaneClear Mode)", toggle = true, value = false, key = string.byte("H"), callback = function(newValue)
		if CheckChatBlock(Menu.Clear.SpellHarass, newValue) then return end
	end})
	Menu.Clear:MenuElement({type = MENU, id = "LaneClear", name = "LaneClear"})
	Menu.Clear.LaneClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.LaneClear:MenuElement({id = "QCount", name = "If Q CanHit Counts >= ", value = 3, min = 1, max = 6, step = 1})
	-- Menu.Clear.LaneClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 60, min = 0, max = 100, step = 5})
	Menu.Clear:MenuElement({type = MENU, id = "JungleClear", name = "JungleClear"})
	Menu.Clear.JungleClear:MenuElement({id = "Q", name = "Use Q", toggle = true, value = true})
	Menu.Clear.JungleClear:MenuElement({id = "W", name = "Use W", toggle = true, value = true})
	-- Menu.Clear.JungleClear:MenuElement({id = "Mana", name = "When ManaPercent >= x%", value = 30, min = 0, max = 100, step = 5})
	
	Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
	Menu.KillSteal:MenuElement({id = "W", name = "Auto W KillSteal", toggle = true, value = true})
	Menu.KillSteal:MenuElement({id = "R", name = "Auto R KillSteal", toggle = true, value = true})

	Menu:MenuElement({type = MENU, id = "Misc", name = "Misc"})
	Menu.Misc:MenuElement({id = "Ecc", name = "Auto E On 'CC'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Etp", name = "Auto E On 'TP'", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "Egap", name = "Auto E Anti Gapcloser", toggle = true, value = true})
	Menu.Misc:MenuElement({id = "SemiR", name = "Semi-manual R Key", key = string.byte("T")})
	Menu.Misc:MenuElement({id = "Rmin", name = "Use R| MinRange >= X", value = 1000, min = 500, max = 2500, step = 100})
	Menu.Misc:MenuElement({id = "Rmax", name = "Use R| MaxRange <= X", value = 3000, min = 1500, max = 3500, step = 100})

	Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "DrawHarass", name = "Draw Spell Harass Status", toggle = true, value = true})
	Menu.Draw:MenuElement({id = "W", name = "Draw W Range", toggle = true, value = false})
	Menu.Draw:MenuElement({id = "E", name = "Draw E Range", toggle = true, value = false})
end

function zgJinx:OnPreAttack(args)
	local target = args.Target
	if IsValid(target) then
		if GetMode() == "LaneClear" and IsReady(_Q) and not IsCasting() then
			if target.type == Obj_AI_Minion then
				if Menu.Clear.SpellFarm:Value() then
					if target.team ~= 300 and Menu.Clear.LaneClear.Q:Value() then
						-- if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 then
							if GetMinionCount(300, target.pos) >= Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(300, target.pos) < Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						-- else
							-- if HaveBuff(myHero, "JinxQ") then
								-- Control.CastSpell(HK_Q)
							-- end
						-- end
					end
					if target.team == 300 and Menu.Clear.JungleClear.Q:Value() then
						-- if myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 then
							if GetMinionCount(300, target.pos) >= 2 and HaveBuff(myHero, "jinxqicon") then
								Control.CastSpell(HK_Q)
							end
							if GetMinionCount(300, target.pos) < 2 and HaveBuff(myHero, "JinxQ") then
								Control.CastSpell(HK_Q)
							end
						-- else
							-- if HaveBuff(myHero, "JinxQ") then
								-- Control.CastSpell(HK_Q)
							-- end
						-- end
					end
				end
			elseif target.type == Obj_AI_Nexus or target.type == Obj_AI_Barracks or target.type == Obj_AI_Turret then
				if myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
					Control.CastSpell(HK_Q)
				end
			end
		end
	end
end

function zgJinx:Tick()
	self.WSpell.Delay = math.max(math.floor((0.6 - 0.02 * ((myHero.attackSpeed - 1)/0.25)) * 100) / 100, 0.4)
	if HaveBuff(myHero, "JinxQ") then
		local level = myHero:GetSpellData(_Q).level
		self.BonusAttackRange = myHero.range - 525 - ({100, 125, 150, 175, 200})[level]
	else
		self.BonusAttackRange = myHero.range - 525
	end
	if ShouldWait() then
		return
	end
	if IsCasting() then return end

	self:AutoE()
	self:SemiR()
	self:KillSteal()

	local Mode = GetMode()
	if Mode == "Combo" then
		self:Combo()
		self:ComboQ()
	elseif Mode == "Harass" then
		self:Harass()
	elseif Mode == "LaneClear" then
		self:FarmHarass()
		--self:LaneClear()
		self:JungleClear()
	end
end

function zgJinx:Combo()
	local target = _G.SDK.Orbwalker:GetTarget() or GetTarget(self.WSpell.Range)
	if IsValid(target) then
		if Menu.Combo.W:Value() and IsReady(_W) then
			if myHero.pos:DistanceTo(target.pos) > _G.SDK.Data:GetAutoAttackRange(myHero, target) then
				self:CastW(target)
			end
		end
		if Menu.Combo.E:Value() and IsReady(_E) then
			if myHero.pos:DistanceTo(target.pos) < self.ESpell.Range then
				self:CastE(target)
			end
		end
	end
end

function zgJinx:ComboQ()	
	local target = GetTarget(1200)
	if IsValid(target) then
		if Menu.Combo.Q:Value() and IsReady(_Q) then
			if myHero.pos:DistanceTo(target.pos) > self:QbaseRange(target) and HaveBuff(myHero, "jinxqicon") then
				if myHero.pos:DistanceTo(target.pos) <= self:QmaxRange(target) then
					Control.CastSpell(HK_Q)
				end
			elseif myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
				Control.CastSpell(HK_Q)
			end
		end
	elseif HaveBuff(myHero, "JinxQ") and GetEnemyCount(1500, myHero.pos) == 0 and IsReady(_Q) then
		Control.CastSpell(HK_Q)
	end
end

function zgJinx:QbaseRange(unit)
	return self.QSpell.Range + self.BonusAttackRange + myHero.boundingRadius + unit.boundingRadius
end

function zgJinx:QmaxRange(unit)
	local level = myHero:GetSpellData(_Q).level
	return self.QSpell.Range + self.BonusAttackRange + myHero.boundingRadius + unit.boundingRadius + ({100, 125, 150, 175, 200})[level]
end

function zgJinx:CastW(target)
	local WPrediction = GGPrediction:SpellPrediction(self.WSpell)
	WPrediction:GetPrediction(target, myHero)
	if WPrediction:CanHit(3) then
		Control.CastSpell(HK_W, WPrediction.CastPosition)
	end
end

function zgJinx:CastE(target)
	local EPrediction = GGPrediction:SpellPrediction(self.ESpell)
	EPrediction:GetPrediction(target, myHero)
	if EPrediction:CanHit(3) then
		Control.CastSpell(HK_E, EPrediction.CastPosition)
	end
end

function zgJinx:CastR(target)
	local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
	RPrediction:GetPrediction(target, myHero)
	if RPrediction:CanHit(3) then
		Control.CastSpell(HK_R, RPrediction.CastPosition)
	end
end

function zgJinx:Harass()
	-- if myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value()/100 then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			if Menu.Harass.W:Value() and IsReady(_W) and myHero.pos:DistanceTo(target.pos) > self:QmaxRange(target) then
				self:CastW(target)
			end
			if Menu.Harass.Q:Value() and IsReady(_Q) then
				if myHero.pos:DistanceTo(target.pos) <= self:QmaxRange(target) then
					if myHero.pos:DistanceTo(target.pos) > self:QbaseRange(target) and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if myHero.pos:DistanceTo(target.pos) < self:QbaseRange(target) and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	-- end
end

function zgJinx:FarmHarass()
	if IsUnderTurret(myHero) then return end
	if Menu.Clear.SpellHarass:Value() then
		self:Harass()
	end
end

--[[ function zgJinx:LaneClear()
	if IsUnderTurret(myHero) then return end
	if myHero.mana/myHero.maxMana >= Menu.Clear.LaneClear.Mana:Value()/100 and Menu.Clear.SpellFarm:Value() then
		if Menu.Clear.LaneClear.Q:Value() and IsReady(_Q) then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range + 130)
			table.sort(minions, function(a, b) return myHero.pos:DistanceTo(a.pos) < myHero.pos:DistanceTo(b.pos) end)
			for i, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 and minion.pos2D.onScreen then
					if GetMinionCount(250, minion.pos) >= Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if GetMinionCount(250, minion.pos) < Menu.Clear.LaneClear.QCount:Value() and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
					if minion.health < _G.SDK.Damage:GetAutoAttackDamage(myHero, minion) then
						if myHero.pos:DistanceTo(minion.pos) > self:QbaseRange() and HaveBuff(myHero, "jinxqicon") then
							Control.CastSpell(HK_Q)
						end
					end
				else
					if HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			end
		end
	end
end ]]

function zgJinx:JungleClear()
	if --[[myHero.mana/myHero.maxMana >= Menu.Clear.JungleClear.Mana:Value()/100 and ]]Menu.Clear.SpellFarm:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QSpell.Range + 130)
		table.sort(minions, function(a, b) return a.maxHealth > b.maxHealth end)
		for i, minion in ipairs(minions) do
			if IsValid(minion) and minion.team == 300 and minion.pos2D.onScreen then
				if Menu.Clear.JungleClear.W:Value() and IsReady(_W) then
					if not minion.name:lower():find("mini") then
						Control.CastSpell(HK_W, minion)
					end
				end
				--[[ if Menu.Clear.JungleClear.Q:Value() and IsReady(_Q) then
					if GetMinionCount(250, minion.pos) >= 2 and HaveBuff(myHero, "jinxqicon") then
						Control.CastSpell(HK_Q)
					end
					if GetMinionCount(250, minion.pos) < 2 and HaveBuff(myHero, "JinxQ") then
						Control.CastSpell(HK_Q)
					end
				end
			else
				if HaveBuff(myHero, "JinxQ") then
					Control.CastSpell(HK_Q)
				end ]]
			end
		end
	end
end

local lastParticleCheckTime = 0
local particleCheckInterval = 1.0
local slots = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}
function zgJinx:AutoE()
	if Menu.Misc.Ecc:Value() and IsReady(_E) then
		for i, target in ipairs(GetEnemyHeroes()) do
			if target and myHero.pos:DistanceTo(target.pos) <= self.ESpell.Range then
				if
					GetHardCCDuration(target) > 0.5 --cc
					or IsInvulnerable(target) --zhonya
					or HaveBuff(target, "LissandraRSelf")
					or HaveBuff(target, "Meditate") --yi w
					or HaveBuff(target, "ChronoRevive") --zilean r
				then
					Control.CastSpell(HK_E, target)
				end

				for j, slot in ipairs(slots) do
					local Data = target:GetSpellData(slot)
					if Data.name == "GuardianAngel" and Data.currentCd == 0 and not target.alive then --G A
						Control.CastSpell(HK_E, target)
					end
				end
			end
		end
	end
	
	if Menu.Misc.Egap:Value() and IsReady(_E) then
		local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.ESpell.Range)
		for i, target in ipairs(enemies) do
			if IsValid(target) and target.pathing.isDashing then
				if myHero.pos:DistanceTo(target.pathing.endPos) < myHero.pos:DistanceTo(target.pos) then
					Control.CastSpell(HK_E, target.pathing.endPos)
				end
			end	
		end
	end

	if Menu.Misc.Etp:Value() and IsReady(_E) then
		local now = GetTickCount() / 1000
		if now - lastParticleCheckTime > particleCheckInterval then
			lastParticleCheckTime = now
			for i = Game.ParticleCount(), 1, -1 do
				local par = Game.Particle(i)
				if
					par and par.pos:DistanceTo(myHero.pos) <= self.ESpell.Range
					and ((par.name:lower():find("teledash_end") and par.name:lower():find("wardenemy")) or par.name:lower():find("gatemarker_red")) -- TP or TF-R
				then
					Control.CastSpell(HK_E, par)
					break
				end
			end
		end
	end
end

function zgJinx:SemiR()
	if Menu.Misc.SemiR:Value() and IsReady(_R) then
		local Rtarget = GetTarget(Menu.Misc.Rmax:Value())
		if IsValid(Rtarget) and Rtarget.pos2D.onScreen then
			self:CastR(Rtarget)
		end
	end
end

function zgJinx:KillSteal()
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(Menu.Misc.Rmax:Value())
	for i, enemy in ipairs(enemies) do
		if enemy and not enemy.dead and enemy.pos2D.onScreen then
			if Menu.KillSteal.W:Value() and IsReady(_W) and lastR + 1500 < GetTickCount() then
				local Wdmg = self:GetWDmg(enemy)
				if Wdmg >= enemy.health + enemy.hpRegen * 1 then
					if myHero.pos:DistanceTo(enemy.pos) < self.WSpell.Range then
						if myHero.pos:DistanceTo(enemy.pos) > _G.SDK.Data:GetAutoAttackRange(myHero, enemy) then 
							self:CastW(enemy)
							lastW = GetTickCount()
						end	
					end
				end
			end
			if Menu.KillSteal.R:Value() and IsReady(_R) and lastW + 1500 < GetTickCount() then
				local Rdmg = self:GetRDmg(enemy)
				local IsSionPassive = HaveBuff(enemy, "sionpassivezombie")
				if not IsSionPassive and Rdmg >= enemy.health + enemy.hpRegen * 2 and myHero.pos:DistanceTo(enemy.pos) >= Menu.Misc.Rmin:Value() then
					self:CastR(enemy)
					lastR = GetTickCount()
				end
			end
		end
	end
end

function zgJinx:GetWDmg(target)
	local level = myHero:GetSpellData(_W).level
	local WDmg = ({10, 60, 110, 160, 210})[level] + 1.4 * myHero.totalDamage
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, WDmg)
end

function zgJinx:GetRDmg(target)
	local d = target.pos:DistanceTo(myHero.pos)
	local level = myHero:GetSpellData(_R).level
	local RDmg = (({200, 350, 500})[level] + 1.2 * myHero.bonusDamage) * (0.06 * math.min(math.floor(d/100), 15) + 0.1) + ({0.25, 0.3, 0.35})[level] * (target.maxHealth - target.health)
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, RDmg)
end

function zgJinx:Draw()
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

	if Menu.Draw.W:Value() and IsReady(_W) then
		Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 66, 229, 244))
	end
	if Menu.Draw.E:Value() and IsReady(_E) then
		Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 244, 238, 66))
	end
end

zgJinx()