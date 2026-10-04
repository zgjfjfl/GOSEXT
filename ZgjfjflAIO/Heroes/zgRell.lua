local Version = 1.01

require("GGPrediction")
require("ZgjfjflAIO\\Utils")

local Menu
class "zgRell"

function zgRell:__init()
    self.QSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 40, Range = 600, Speed = math.huge, Collision = false}
    self.WSpell = {Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.625, Radius = 100, Range = 850, Speed = 1000, Collision = false}
    self.ERange, self.RRange = 1200, 400
   self:LoadMenu()
    _G.SDK.Orbwalker:OnPreAttack(function(args)
        if GetMode() ~= "Combo" or HaveBuff(myHero, "RellWEmpoweredAttack") then return end
        if (Menu.Combo.Q:Value() and IsReady(_Q)) or (Menu.Combo.W:Value() and IsReady(_W)) then
            args.Process = false
        end
    end)
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    print("Zgjfjfl AIO - Rell Loaded")
end

function zgRell:LoadMenu()
	local championIcon = "http://ddragon.leagueoflegends.com/cdn/16.1.1/img/champion/"..myHero.charName..".png"
	Menu = MenuElement({type = MENU, id = "Zgjfjfl_AIO_"..myHero.charName, name = "Zgjfjfl AIO - "..myHero.charName.." V: "..Version, leftIcon = championIcon})
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    for _, spell in ipairs({"Q", "W", "E", "R"}) do
        Menu.Combo:MenuElement({id = spell, name = "Use "..spell, value = true})
    end
    Menu.Combo:MenuElement({id = "RCount", name = "R | Enemy count >=", value = 2, min = 1, max = 5, step = 1})
    Menu.Combo:MenuElement({id = "ERange", name = "E | Engage distance", value = 850, min = 450, max = 1200, step = 50})
    Menu.Combo:MenuElement({id = "MountRange", name = "W Mount Up | Target distance <=", value = 600, min = 200, max = 1000, step = 50})
    Menu.Combo:MenuElement({id = "Turret", name = "Allow W Crash Down under enemy turret", value = false})
    Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
    Menu.Harass:MenuElement({id = "Mana", name = "Mana percent >=", value = 50, min = 0, max = 100, step = 5})
    Menu:MenuElement({type = MENU, id = "Auto", name = "Auto"})
    Menu.Auto:MenuElement({id = "AntiDash", name = "Q against approaching dashes", value = true})
    Menu:MenuElement({type = MENU, id = "SemiR", name = "Semi-Manual R"})
    Menu.SemiR:MenuElement({id = "Key", name = "R key (hold)", key = string.byte("T")})
    Menu.SemiR:MenuElement({id = "Count", name = "Enemy count >=", value = 1, min = 1, max = 5, step = 1})
    Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    Menu.Flee:MenuElement({id = "E", name = "Use E", value = true})
    Menu.Flee:MenuElement({id = "W", name = "Use W Mount Up", value = true})
    Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
    for _, spell in ipairs({"Q", "W", "E", "R"}) do
        Menu.Draw:MenuElement({id = spell, name = "Draw "..spell.." range", value = false})
    end
end

function zgRell:WForm()
    local name = (myHero:GetSpellData(_W).name or ""):lower()
    if name == "rellw_mountup" then return "Dismounted" end
    if name == "rellw_dismount" then return "Mounted" end
    -- Unknown spell states must not become a positional W cast.
    return nil
end

function zgRell:Cast(key, position)
    local result
    if position then result = Control.CastSpell(key, position)
    else result = Control.CastSpell(key) end
    if result == false then return false end
    return true
end

function zgRell:CastQ(target)
    if HaveBuff(myHero, "RellWEmpoweredAttack") then return false end
    if not IsReady(_Q) or not IsValid(target) or not target.pos2D.onScreen then return false end
    if GetDistance(myHero.pos, target.pos) > self.QSpell.Range - 50 then return false end
    -- W2's remaining knockback ends before Q hits; aim at its landing position.
    local hasW2, w2 = GetBuffData(target, "rellw_knockup")
    if hasW2 and w2.type == 31 and w2.duration > 0 and w2.duration <= self.QSpell.Delay then
        local path, castPos = target.pathing, target.pos
        if path and path.isDashing then castPos = path.endPos end
        if castPos and GetDistance(myHero.pos, castPos) <= self.QSpell.Range then
            return self:Cast(HK_Q, castPos)
        end
        return false
    end
    local prediction = GGPrediction:SpellPrediction(self.QSpell)
    prediction:GetPrediction(target, myHero)
    if prediction:CanHit(GGPrediction.HITCHANCE_HIGH) and prediction.CastPosition
        and GetDistance(myHero.pos, prediction.CastPosition) <= self.QSpell.Range then
        return self:Cast(HK_Q, prediction.CastPosition)
    end
    return false
end

function zgRell:CastW(target)
    if not IsReady(_W) or not IsValid(target) or not target.pos2D.onScreen then return false end
    local form = self:WForm()
    if form == "Dismounted" then
        if GetDistance(myHero.pos, target.pos) <= Menu.Combo.MountRange:Value() then return self:Cast(HK_W) end
        return false
    end
    if form ~= "Mounted" or GetDistance(myHero.pos, target.pos) > self.WSpell.Range then return false end
    local prediction = GGPrediction:SpellPrediction(self.WSpell)
    prediction:GetPrediction(target, myHero)
    if not prediction:CanHit(GGPrediction.HITCHANCE_HIGH) or not prediction.CastPosition then return false end
    local pos = prediction.CastPosition
    if GetDistance(myHero.pos, pos) > self.WSpell.Range or Game.isWall(pos) then return false end
    if not Menu.Combo.Turret:Value() and IsUnderTurret2(pos) then return false end
    if self:Cast(HK_W, pos) then
        return true
    end
    return false
end

function zgRell:CastE(target)
    if not IsReady(_E) then return false end
    local allyTarget, bestDistance = myHero, math.huge
    local destination = target and target.pos or mousePos
    for _, ally in ipairs(_G.SDK.ObjectManager:GetAllyHeroes(self.ERange)) do
        if IsValid(ally) and ally.networkID ~= myHero.networkID and ally.pos2D.onScreen
            and GetDistance(myHero.pos, ally.pos) <= self.ERange then
            local distance = GetDistance(ally.pos, destination)
            if distance < bestDistance then allyTarget, bestDistance = ally, distance end
        end
    end
    return self:Cast(HK_E, allyTarget)
end

function zgRell:CastR(count)
    if not IsReady(_R) or HaveBuff(myHero, "RellR") then return false end
    if GetEnemyCount(self.RRange, myHero.pos) >= count then return self:Cast(HK_R) end
    return false
end

function zgRell:AntiDash()
    if not Menu.Auto.AntiDash:Value() or not IsReady(_Q) then return false end
    for _, enemy in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(self.QSpell.Range)) do
        local path = enemy.pathing
        if IsValid(enemy) and path and path.isDashing and path.endPos
            and GetDistance(myHero.pos, path.endPos) <= 350
            and GetDistance(myHero.pos, path.endPos) < GetDistance(myHero.pos, enemy.pos)
            and self:CastQ(enemy) then return true end
    end
    return false
end

function zgRell:Combo()
    local target = GetTarget(self.WSpell.Range - 100)
    if not IsValid(target) then return end
    if Menu.Combo.E:Value() and self:CastE(target) then return end
    if Menu.Combo.W:Value() and self:WForm() == "Dismounted" and self:CastW(target) then return end
    if Menu.Combo.Q:Value() and self:CastQ(target) then return end
    if Menu.Combo.W:Value() then self:CastW(target) end
end

function zgRell:Tick()
    if ShouldWait() then return end
    local mode = GetMode()
    local dashing = myHero.pathing and myHero.pathing.isDashing
    if dashing or IsCasting() then return end
    if Menu.SemiR.Key:Value() and self:CastR(Menu.SemiR.Count:Value()) then return end
    if mode == "Combo" and Menu.Combo.R:Value() and self:CastR(Menu.Combo.RCount:Value()) then return end
    if mode == "Flee" then
        if Menu.Flee.W:Value() and self:WForm() == "Dismounted" and IsReady(_W) and self:Cast(HK_W) then return end
        if Menu.Flee.E:Value() then self:CastE() end
        return
    end
    if self:AntiDash() then return end
    if mode == "Combo" then
        self:Combo()
    elseif mode == "Harass" and Menu.Harass.Q:Value() then
        local mana = myHero.maxMana > 0 and myHero.mana / myHero.maxMana * 100 or 100
        if mana >= Menu.Harass.Mana:Value() then self:CastQ(GetTarget(self.QSpell.Range)) end
    end
end

function zgRell:Draw()
    if myHero.dead then return end
    if Menu.Draw.Q:Value() and IsReady(_Q) then Draw.Circle(myHero.pos, self.QSpell.Range, 1, Draw.Color(255, 66, 244, 113)) end
    if Menu.Draw.W:Value() and IsReady(_W) and self:WForm() == "Mounted" then Draw.Circle(myHero.pos, self.WSpell.Range, 1, Draw.Color(255, 244, 238, 66)) end
    if Menu.Draw.E:Value() and IsReady(_E) then Draw.Circle(myHero.pos, self.ERange, 1, Draw.Color(255, 66, 229, 244)) end
    if Menu.Draw.R:Value() and IsReady(_R) then Draw.Circle(myHero.pos, self.RRange, 1, Draw.Color(255, 244, 66, 96)) end
end

zgRell()
