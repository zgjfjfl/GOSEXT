local Heroes ={"Milio"}

if not table.contains(Heroes, myHero.charName) then return end

require "GGPrediction"

local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion

local lastQ = 0
local lastW = 0
local lastE = 0
local lastR = 0

local function isSpellReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function isValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0 and not unit.dead) then
        return true
    end
    return false
end

local function recalling()
    for i, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

local function getDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function getEnemyHeroes()
    local EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isEnemy and not Hero.dead then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyCount(unit, range)
    local count = 0
    for i, hero in ipairs(getEnemyHeroes()) do
        if isValid(hero) and getDistanceSqr(unit, hero.pos) < range * range then
            count = count + 1
        end
    end
    return count
end

local function isInRange(v1, v2, range)
    v1 = v1.pos or v1
    v2 = v2.pos or v2
    local dx = v1.x - v2.x
    local dz = (v1.z or v1.y) - (v2.z or v2.y)
    if dx * dx + dz * dz <= range * range then
        return true
    end
    return false
end

class "Milio"
        
function Milio:__init()
    print("Zgjfjfl_Milio Loaded")
    self:LoadMenu()
	
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTick() end)    
    self.qSpell = {Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 30, Range = 1000, Speed = 1200, Collision = true, MaxCollision = 1, CollisionTypes = {GGPrediction.COLLISION_MINION}}
    self.wSpell = { Range = 650 }
    self.eSpell = { Range = 650 }
    self.rSpell = { Range = 700 }  
end

function Milio:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "zgMilio", name = "Zgjfjfl Milio"})
            
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        self.Menu.Combo:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Combo:MenuElement({id = "QBD", name = "[Q] ball collision minion bounces distance", value = 400, min = 100, max = 500, step = 50})
        self.Menu.Combo:MenuElement({id = "R", name = "[R]", toggle = true, value = false})
        self.Menu.Combo:MenuElement({id = "RHP", name = "UseR when ally or self  <= Xhp%", value = 20, min = 0, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        self.Menu.Harass:MenuElement({id = "Q", name = "[Q]", toggle = true, value = true})
        self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 20, min = 0, max = 100})

    self.Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
        self.Menu.AutoW:MenuElement({id = "W", name = "[W]Auto heal", toggle = true, value = true})
        self.Menu.AutoW:MenuElement({id = "WHP", name = "When ally or self X hp%", value = 50, min = 0, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "AutoE", name = "AutoE"})
        self.Menu.AutoE:MenuElement({id = "E", name = "[E]Auto shield", toggle = true, value = true})
        self.Menu.AutoE:MenuElement({id = "Eally", name = "Use on ally", toggle = true, value = true})
        self.Menu.AutoE:MenuElement({id = "Eself", name = "Use on self", toggle = true, value = true})

    self.Menu:MenuElement({type = MENU, id = "AutoR", name = "AutoR"})
        self.Menu.AutoR:MenuElement({id = "R", name = "[R]Auto clears ally CC", toggle = true, value = true})
            self.Menu.AutoR:MenuElement({type = MENU, id = "CC", name = "CC Types"})			
            self.Menu.AutoR.CC:MenuElement({ id = "Stun", name = "Use on Stun", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Taunt", name = "Use on Taunt", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Berserk", name = "Use on Berserk", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Snare", name = "Use on Snare", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Fear", name = "Use on Fear", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Charm", name = "Use on Charm", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Suppression", name = "Use on Suppression", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Disarm", name = "Use on Disarm", value = true})
            self.Menu.AutoR.CC:MenuElement({ id = "Asleep", name = "Use on Asleep", value = true})

    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
        self.Menu.Draw:MenuElement({id = "Q", name = "[Q] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "W", name = "[W] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "E", name = "[E] Range", toggle = true, value = false})
        self.Menu.Draw:MenuElement({id = "R", name = "[R] Range", toggle = true, value = false})

end

function Milio:onTick()

    if myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or recalling() then
        return
    end

    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end
    if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Harass()
    end
    if self.Menu.AutoW.W:Value() then
        self:AutoW()
    end
    if self.Menu.AutoE.E:Value() then
        self:AutoE()
    end
    if self.Menu.AutoR.R:Value() then
        self:AutoR()
    end
    
end

function Milio:Combo()

    local target = _G.SDK.TargetSelector:GetTarget(1500)
    if isValid(target) and  target.pos2D.onScreen then

        if self.Menu.Combo.Q:Value() then
            self:CastQ(target)
        end
    end

    if self.Menu.Combo.R:Value() and isSpellReady(_R) and lastR + 250 < GetTickCount() then
    local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.rSpell.Range)
        for i, hero in ipairs(heroes) do
            if hero.health/hero.maxHealth <= self.Menu.Combo.RHP:Value()/100 and getEnemyCount(hero.pos, 1200) > 0 then
                Control.CastSpell(HK_R)
                lastR = GetTickCount()
            end
        end
    end
end

function Milio:Harass()

    local target = _G.SDK.TargetSelector:GetTarget(1500)
    if isValid(target) and target.pos2D.onScreen then
            
        if self.Menu.Harass.Q:Value() and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
            self:CastQ(target)
        end
    end
end

function Milio:CastQ(target)
    if isSpellReady(_Q) and lastQ + 350 < GetTickCount() and _G.SDK.Orbwalker:CanMove() then
        local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, target.pos, self.qSpell.Speed, self.qSpell.Delay, self.qSpell.Radius, self.qSpell.CollisionTypes, target.networkID)
        if collisionCount >= self.qSpell.MaxCollision and myHero.pos:DistanceTo(target.pos) > 1000 and myHero.pos:DistanceTo(target.pos) < self.Menu.Combo.QBD:Value()+1000 then
            for i, minion in ipairs(collisionObjects) do
                if minion.pos:DistanceTo(target.pos) < self.Menu.Combo.QBD:Value() and minion.pos:DistanceTo(myHero.pos) < 1000 then
                    Control.CastSpell(HK_Q, minion)
                    lastQ = GetTickCount()
                end
            end
        elseif collisionCount <= self.qSpell.MaxCollision and myHero.pos:DistanceTo(target.pos) < 1000 then
            local Pred = GGPrediction:SpellPrediction(self.qSpell)
            Pred:GetPrediction(target, myHero)
            if Pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                Control.CastSpell(HK_Q, Pred.CastPosition)
                lastQ = GetTickCount()
            end
        end
    end
end

function Milio:AutoW()
    if isSpellReady(_W) and myHero:GetSpellData(_W).name == "MilioW" and lastW + 350 < GetTickCount() then
    local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.wSpell.Range)
        for i, hero in ipairs(heroes) do
            if hero.health/hero.maxHealth <= self.Menu.AutoW.WHP:Value()/100 and getEnemyCount(hero.pos, 1200) > 0 then
                Control.CastSpell(HK_W, hero)
                lastW = GetTickCount()
            end
        end
    end
end

function Milio:AutoE()
    if isSpellReady(_E) and lastE + 250 < GetTickCount() then
        local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2500)
        for i, enemy in ipairs(enemies) do
            if isValid(enemy) then
                local allies = _G.SDK.ObjectManager:GetAllyHeroes(self.eSpell.Range)
                for i, ally in ipairs(allies) do
                    if (ally.isMe and self.Menu.AutoE.Eself:Value()) or (not ally.isMe and self.Menu.AutoE.Eally:Value())then
                        local canuse = false
                        if enemy.isChanneling then 
                            if enemy.activeSpell.target == ally.handle then
                                canuse = true
                            else
                                local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(ally.pos, enemy.activeSpell.placementPos, enemy.pos)
                                local width = ally.boundingRadius
                                if enemy.activeSpell.width > 0 then
                                    width = width + enemy.activeSpell.width
                                end
                                if isOnSegment and isInRange(point, ally.pos, width) then
                                    canuse = true
                                end
                            end
                        elseif enemy.activeSpell.target == ally.handle then --autoattack
                            canuse = true
                        end
                        if canuse then
                            Control.CastSpell(HK_E, ally)
                            lastE = GetTickCount()
                        end
                    end
                end
            end
        end
    end
end

function Milio:AutoR()
    if isSpellReady(_R) and lastR + 250 < GetTickCount() then
    local heroes = _G.SDK.ObjectManager:GetAllyHeroes(self.rSpell.Range)
        for i, hero in ipairs(heroes) do
            if not hero.isMe and self:RCleans(hero) then
                Control.CastSpell(HK_R)
                lastR = GetTickCount()
            end
        end
    end
end

function Milio:RCleans(unit)
    local CleanBuffs = {
        [5]  = self.Menu.AutoR.CC.Stun:Value(),
        [8]  = self.Menu.AutoR.CC.Taunt:Value(),
        [9]  = self.Menu.AutoR.CC.Berserk:Value(),
        [12] = self.Menu.AutoR.CC.Snare:Value(),
        [22] = self.Menu.AutoR.CC.Fear:Value(),
        [23] = self.Menu.AutoR.CC.Charm:Value(),
        [25] = self.Menu.AutoR.CC.Suppression:Value(),
        [32] = self.Menu.AutoR.CC.Disarm:Value(),
        [35] = self.Menu.AutoR.CC.Asleep:Value()
    }    
	
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            if CleanBuffs[buff.type] then
                return true
            end
        end
    end
    return false
end

function Milio:Draw()
    if self.Menu.Draw.Q:Value() and isSpellReady(_Q)then
        Draw.Circle(myHero.pos, 1000, 1, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.Draw.W:Value() and isSpellReady(_W)then
        Draw.Circle(myHero.pos, self.wSpell.Range, 1, Draw.Color(255, 0, 0, 255))
    end
    if self.Menu.Draw.E:Value() and isSpellReady(_E)then
        Draw.Circle(myHero.pos, self.eSpell.Range, 1, Draw.Color(255, 0, 0, 0))
    end
    if self.Menu.Draw.R:Value() and isSpellReady(_R)then
        Draw.Circle(myHero.pos, self.rSpell.Range, 1, Draw.Color(255, 255, 0, 0))
    end
end

Callback.Add("Load", function()
    if table.contains(Heroes, myHero.charName) then
        _G[myHero.charName]()
    end
end)