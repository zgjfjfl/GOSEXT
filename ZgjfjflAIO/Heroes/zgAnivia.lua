local Version = 1.02

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

class "zgAnivia"

function zgAnivia:__init()		 
	print("Zgjfjfl AIO - Anivia Loaded")
	self:LoadMenu()

	Callback.Add("Draw", function() self:OnDraw() end)
	Callback.Add("Tick", function() self:OnTick() end)
	_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
	self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 110, Range = 1075, Speed = 950, Collision = true, CollisionTypes = {GGPrediction.COLLISION_YASUOWALL}}
	self.WSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.6, Radius = 1, Range = 1000, Speed = math.huge, Collision = false}
	self.ESpell = { Range = 730 }
	self.RSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.5, Radius = 400, Range = 750, Speed = math.huge, Collision = false}
	self.QPos = nil
	self.RPos = nil
	self.QMANA = 0
	self.WMANA = 0
	self.EMANA = 0
	self.RMANA = 0
end

function zgAnivia:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	-- Draw Menu
	Menu:MenuElement({ id = "Draw", name = "Draw", type = MENU })
	Menu.Draw:MenuElement({id = "DrawFarm", name = "Draw Spell Farm Status", value = true})
	Menu.Draw:MenuElement({ id = "qRange", name = "Q Range", value = false })
	Menu.Draw:MenuElement({ id = "wRange", name = "W Range", value = false })
	Menu.Draw:MenuElement({ id = "eRange", name = "E Range", value = false })
	Menu.Draw:MenuElement({ id = "rRange", name = "R Range", value = false })
	Menu.Draw:MenuElement({ id = "onlyRdy", name = "Draw Only Ready Spells", value = true })
	
	-- Q settings
	Menu:MenuElement({type = MENU, id = "QConfig", name = "Q Config"})
	Menu.QConfig:MenuElement({id = "autoQ", name = "Auto Q", value = true})
	Menu.QConfig:MenuElement({id = "AGCQ", name = "Q gapcloser", value = true})
	Menu.QConfig:MenuElement({id = "harassQ", name = "Harass Q", value = true})

	-- W settings
	Menu:MenuElement({type = MENU, id = "WConfig", name = "W Config"})
	Menu.WConfig:MenuElement({id = "autoW", name = "Auto W", value = true})
	Menu.WConfig:MenuElement({id = "AGCW", name = "AntiGapcloser W", value = true})

	-- E settings
	Menu:MenuElement({type = MENU, id = "EConfig", name = "E Config"})
	Menu.EConfig:MenuElement({id = "autoE", name = "Auto E", value = true})

	-- R settings
	Menu:MenuElement({type = MENU, id = "RConfig", name = "R Config"})
	Menu.RConfig:MenuElement({id = "autoR", name = "Auto R", value = true})

	-- Farm settings
	Menu:MenuElement({type = MENU, id = "Farm", name = "Farm"})
	Menu.Farm:MenuElement({id = "SpellFarm", name = "Use Spell Farm(Mouse Scroll)", toggle = true, value = false, key = 4})
	Menu.Farm:MenuElement({id = "LCminions", name = "LaneClear minimum minions", value = 3, min = 0, max = 10, step = 1 })
	Menu.Farm:MenuElement({id = "farmE", name = "Lane clear E", value = true})
	Menu.Farm:MenuElement({id = "farmR", name = "Lane clear R", value = true})
	Menu.Farm:MenuElement({id = "jungleE", name = "Jungle clear E", value = true})
	Menu.Farm:MenuElement({id = "jungleQ", name = "Jungle clear Q", value = true})
	Menu.Farm:MenuElement({id = "jungleR", name = "Jungle clear R", value = true})
end

function zgAnivia:OnPreAttack(args)
	local target = args.Target
	if GetMode() == "Combo" or GetMode() == "Harass" then
		if target and target.type == Obj_AI_Hero and HaveBuff(target, "aniviachilled") and Game.CanUseSpell(_E) == 0 then
			args.Process = false
		end
	end
end

function zgAnivia:OnTick()
	if ShouldWait() then
		return
	end
	self:CheckSpellParticle()
	if HaveBuff(myHero, "rebirth") then
		_G.SDK.Orbwalker:SetAttack(false)
		_G.SDK.Orbwalker:SetMovement(false)
		return
	end
	_G.SDK.Orbwalker:SetAttack(true)
	_G.SDK.Orbwalker:SetMovement(true)
	if IsCasting() then
		return
	end
	self:AntiGapcloser()
	if Game.CanUseSpell(_Q) == 0 and myHero:GetSpellData(_Q).toggleState == 2 and self.QPos ~= nil and GetEnemyCount(210, self.QPos) > 0 then
		Control.CastSpell(HK_Q)
	end
	self:SetMana()
	if IsReady(_R) and Menu.RConfig.autoR:Value() then
		self:LogicR()
	end
	if IsReady(_W) and Menu.WConfig.autoW:Value() then
		self:LogicW()
	end
	if IsReady(_Q) and self.QPos == nil and Menu.QConfig.autoQ:Value() then
		self:LogicQ()
	end
	if IsReady(_E) and Menu.EConfig.autoE:Value() then
		self:LogicE()
	end	
	self:Jungle()
end

function zgAnivia:SetMana()
	if myHero.health/myHero.maxHealth < 0.2 then
		self.QMANA = 0
		self.WMANA = 0
		self.EMANA = 0
		self.RMANA = 0
		return
	end

	self.QMANA = myHero:GetSpellData(_Q).mana
	self.WMANA = myHero:GetSpellData(_W).mana
	self.EMANA = myHero:GetSpellData(_E).mana
	self.RMANA = Game.CanUseSpell(_R) == 0 and myHero:GetSpellData(_R).mana or (self.QMANA - myHero.mpRegen * myHero:GetSpellData(_Q).cd)
end

function zgAnivia:CheckSpellParticle()
	local particleCount = Game.ParticleCount()
	local searchRadius = 1300
	local mePos = myHero.pos
	local needQPos = Game.CanUseSpell(_Q) == 0 and myHero:GetSpellData(_Q).toggleState == 2
	if not needQPos then
		self.QPos = nil
	end
	local needRPos = Game.CanUseSpell(_R) == 0 and myHero:GetSpellData(_R).toggleState == 2
	if not needRPos then
		self.RPos = nil
	end
	if not (needQPos or needRPos) then
		return
	end
	for i = particleCount, 1, -1 do
		local par = Game.Particle(i)
		if par and par.name and par.pos and GetDistance(mePos, par.pos) < searchRadius then
			if needQPos and string.find(par.name, "_Q_AOE_Mis") then
				self.QPos = par.pos + (par.pos - myHero.pos):Normalized() * 50
			elseif needRPos and string.find(par.name, "_R_indicator_ring") then
				self.RPos = par.pos
			end
		end
	end
end

function zgAnivia:AntiGapcloser()
	if not (IsReady(_Q) and Menu.QConfig.AGCQ:Value()) and 
		   not (IsReady(_W) and Menu.WConfig.AGCW:Value()) then
		return  -- Early exit if neither spell is ready/available
	end
	local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
	for _, target in ipairs(enemies) do
		if IsValid(target) and target.pathing.isDashing then
			local endPos = Vector(target.pathing.endPos)
			if myHero.pos:DistanceTo(endPos) < 300 and IsFacingMe(target) then
				if IsReady(_Q) and myHero:GetSpellData(_Q).toggleState == 1 and Menu.QConfig.AGCQ:Value() then
					self:CastGGPred(HK_Q, target)
					return
				elseif IsReady(_W) and Menu.WConfig.AGCW:Value() then
					Control.CastSpell(HK_W, myHero.pos:Extended(target.pos, 50))
					return
				end
			end
		end
	end
end

function zgAnivia:CastGGPred(spell, target)
	if spell == HK_Q then
		local QPrediction = GGPrediction:SpellPrediction(self.QSpell)
		QPrediction:GetPrediction(target, myHero)
		if QPrediction:CanHit(3) then
			Control.CastSpell(HK_Q, QPrediction.CastPosition)
		end
	elseif spell == HK_R then
		local RPrediction = GGPrediction:SpellPrediction(self.RSpell)
		RPrediction:GetPrediction(target, myHero)
		if RPrediction:CanHit(3) then
			Control.CastSpell(HK_R, RPrediction.CastPosition)
		end
	end
end

function zgAnivia:LogicQ()
	local target = GetTarget(self.QSpell.Range)
	if IsValid(target) and myHero:GetSpellData(_Q).toggleState == 1 then
		if GetMode() == "Combo" and myHero.mana > self.EMANA + self.QMANA - 10 then
			self:CastGGPred(HK_Q, target)
		elseif GetMode() == "Harass" and Menu.QConfig.harassQ:Value() and myHero.mana > self.RMANA + self.EMANA + self.QMANA + self.WMANA then
			self:CastGGPred(HK_Q, target)
		else
			local qDmg = self:GetQDmg(target)
			local eDmg = Game.CanUseSpell(_E) == 0 and self:GetEDmg(target) or 0
			if qDmg > target.health then
				self:CastGGPred(HK_Q, target)
			elseif qDmg + eDmg > target.health and myHero.mana > self.QMANA + self.EMANA then
				self:CastGGPred(HK_Q, target)
			end
		end
	end 
	if myHero.mana > self.RMANA + self.EMANA then
		for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do 
			if IsValid(enemy) and IsHardCC(enemy) then
				self:CastGGPred(HK_Q, enemy)
			end
		end
	end
end

function zgAnivia:LogicW()
	if GetMode() == "Combo" and myHero.mana > self.RMANA + self.EMANA + self.WMANA then
		local target = GetTarget(self.WSpell.Range)
		if IsValid(target) then
			local pred = target:GetPrediction(self.WSpell.Speed, self.WSpell.Delay)
			if pred:DistanceTo(target.pos) > 100 and pred:DistanceTo(myHero.pos) <= self.WSpell.Range then
				Control.CastSpell(HK_W, pred)
			end
		end
	end
end

function zgAnivia:LogicE()
	local target = GetTarget(self.ESpell.Range)
	if IsValid(target) then
		local qCd = myHero:GetSpellData(_Q).currentCd
		local rCd = myHero:GetSpellData(_R).currentCd
		if myHero.levelData.lvl < 7 then
			rCd = 10
		end
		local eDmg = self:GetEDmg(target)
		if eDmg > target.health then
			Control.CastSpell(HK_E, target)
		end
		if HaveBuff(target, "aniviachilled") or (qCd > myHero:GetSpellData(_E).cd - 1 and rCd > myHero:GetSpellData(_E).cd - 1) then
			if eDmg * 3 > target.health then
				Control.CastSpell(HK_E, target)
			elseif GetMode() == "Combo" and (HaveBuff(target, "aniviachilled") or myHero.mana > self.RMANA + self.EMANA) then
				Control.CastSpell(HK_E, target)
			elseif GetMode() == "Harass" and myHero.mana > self.RMANA + self.EMANA + self.QMANA + self.WMANA and not IsUnderTurret(myHero) and self.QPos == nil then
				Control.CastSpell(HK_E, target)
			end
		elseif GetMode() == "Combo" and IsReady(_R) and myHero.mana > self.RMANA + self.EMANA and self.QPos == nil then
			self:CastGGPred(HK_R, target)
		end
	end
	self:FarmE()
end

function zgAnivia:FarmE()
	if GetMode() == "LaneClear" and Menu.Farm.SpellFarm:Value() and Menu.Farm.farmE:Value() then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ESpell.Range)
		for _, minion in ipairs(minions) do
			if IsValid(minion) and minion.team ~= 300 and minion.health > _G.SDK.Damage:GetAutoAttackDamage(myHero, minion) then
				local eDmg = self:GetEDmg(minion) * 2
				if minion.health < eDmg and HaveBuff(minion, "aniviachilled") then
					Control.CastSpell(HK_E, minion)
				end
			end
		end
	end
end

function zgAnivia:LogicR()
	if self.RPos == nil then
		local target = GetTarget(self.RSpell.Range + 400)
		if IsValid(target) then
			if self:GetRDmg(target) > target.health then
				self:CastGGPred(HK_R, target)
			elseif myHero.mana > self.RMANA + self.EMANA and self:GetEDmg(target) * 2 + self:GetRDmg(target) > target.health then
				self:CastGGPred(HK_R, target)
			end
			if myHero.mana > self.RMANA + self.EMANA + self.QMANA + self.WMANA and GetMode() == "Combo" then
				self:CastGGPred(HK_R, target)
			end
		end
		if GetMode() == "LaneClear" and Menu.Farm.SpellFarm:Value() and Menu.Farm.farmR:Value() then
			local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.RSpell.Range)
			local bestPos = nil
			local bestCount = 0
			for _, minion in ipairs(minions) do
				if IsValid(minion) and minion.team ~= 300 then
					local count = GetMinionCount(self.RSpell.Radius, minion.pos)
					if count > bestCount then
						bestCount = count
						bestPos = minion.pos
					end
				end
			end
			if bestPos and bestCount >= Menu.Farm.LCminions:Value() then
				Control.CastSpell(HK_R, bestPos)
			end
		end
	else
		if GetMode() == "LaneClear" then
			local minions = GetMinionCount(self.RSpell.Radius, self.RPos)
			if minions == 0 then
				Control.CastSpell(HK_R)
			end
		elseif self:GetEnemyCount(470, self.RPos) == 0 or myHero.mana < self.EMANA + self.QMANA then
			Control.CastSpell(HK_R)
		end
	end
end

function zgAnivia:GetEnemyCount(range, unit)
	local count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
		local Range = range * range
		if hero and GetDistanceSqr(unit, hero.pos) < Range then
			count = count + 1
		end
	end
	return count
end

function zgAnivia:Jungle()
	if GetMode() == "LaneClear" and Menu.Farm.SpellFarm:Value() then
		local mobs = _G.SDK.ObjectManager:GetMonsters(self.ESpell.Range)
		if #mobs > 0 then
			table.sort(mobs, function(a, b) return a.maxHealth > b.maxHealth end)
			local mob = mobs[1]
			if IsReady(_Q) and Menu.Farm.jungleQ:Value() then
				if self.QPos ~= nil then
					if myHero:GetSpellData(_Q).toggleState == 2 and self.QPos:DistanceTo(mob.pos) < 210 then
						Control.CastSpell(HK_Q)
					end
				elseif myHero:GetSpellData(_Q).toggleState == 1 then
					Control.CastSpell(HK_Q, mob)
				end
				return
			end
			if IsReady(_R) and Menu.Farm.jungleR:Value() and self.RPos == nil then
				Control.CastSpell(HK_R, mob)
				return
			end
			if IsReady(_E) and Menu.Farm.jungleE:Value() and HaveBuff(mob, "aniviachilled") then
				Control.CastSpell(HK_E, mob)
				return
			end
		end
	end
end

function zgAnivia:GetQDmg(target)
	local level = myHero:GetSpellData(_Q).level
	local QDmg = ({50, 70, 90, 110, 130})[level] + 0.25 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, QDmg)
end

function zgAnivia:GetEDmg(target)
	local level = myHero:GetSpellData(_E).level
	local EDmg = ({50, 75, 100, 125, 150})[level] + 0.55 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, EDmg)
end

function zgAnivia:GetRDmg(target)
	local level = myHero:GetSpellData(_R).level
	local RDmg = ({30, 45, 60})[level] + 0.125 * myHero.ap
	return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_MAGICAL, RDmg)
end

function zgAnivia:OnDraw()
	if myHero.dead then return end
	if Menu.Draw.DrawFarm:Value() then
		if Menu.Farm.SpellFarm:Value() then
			Draw.Text("Spell Farm: On", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		else
			Draw.Text("Spell Farm: Off", 16, myHero.pos2D.x-57, myHero.pos2D.y+58, Draw.Color(200, 242, 120, 34))
		end
	end
	if Menu.Draw.wRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_W) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 255, 165, 0)) -- Orange
		end
	end
	if Menu.Draw.rRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_R) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.RSpell.Range, 1, Draw.Color(255, 128, 128, 128)) -- Gray
		end
	end
	if Menu.Draw.qRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_Q) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 0, 255, 255)) -- Cyan
		end
	end
	if Menu.Draw.eRange:Value() then
		if Menu.Draw.onlyRdy:Value() and IsReady(_E) or not Menu.Draw.onlyRdy:Value() then
			Draw.Circle(myHero.pos, self.ESpell.Range, 1, Draw.Color(255, 255, 255, 0)) -- Yellow
		end
	end
end

zgAnivia()
