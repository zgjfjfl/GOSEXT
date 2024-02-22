
local Heroes = {"Zeri"}

if not table.contains(Heroes, myHero.charName) then return end

require "MapPositionGOS"
require "GGPrediction"

local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local Orbwalker, TargetSelector, ObjectManager, Data

Callback.Add("Load", function()

    Orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    ObjectManager = _G.SDK.ObjectManager
    Data = _G.SDK.Data

    if table.contains(Heroes, myHero.charName) then
        _G[myHero.charName]()
    end

end)

local function isSpellReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and Game.CanUseSpell(spell) == 0
end

local function getDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

local function getDistance(Pos1, Pos2)
    return math.sqrt(getDistanceSqr(Pos1, Pos2))
end

local function isValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.health > 0) then
        return true;
    end
    return false;
end

local function getEnemyHeroesWithinDistanceOfUnit(location, distance)
    local EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local Hero = GameHero(i)
        if Hero.isEnemy and not Hero.dead and getDistance(Hero.pos, location) < distance then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

local function getEnemyHeroesWithinDistance(distance)
    return getEnemyHeroesWithinDistanceOfUnit(myHero.pos, distance)
end

local function doesMyChampionHaveBuff(buffName)
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == buffName and buff.count > 0 then 
            return true
        end
    end
    return false
end

class "Zeri"
        
function Zeri:__init()
    print("Zgjfjfl-Zeri Loaded")
    self:LoadMenu()
   
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Tick", function() self:onTickEvent() end)
    qData = {Type = GGPrediction.SPELLTYPE_LINE, Range = 775, Speed = 2600, Delay = 0, Radius = 40, Collision = false}
    wData = {Type = GGPrediction.SPELLTYPE_LINE, Range= 1200, Speed = 2500, Delay = 0.55, Radius = 40, Collision = false}
    w2Data = {Type = GGPrediction.SPELLTYPE_LINE, Range= 2700, Speed = 2500, Delay = 0.55, Radius = 100, Collision = false}
    lastW = 0
end

function Zeri:LoadMenu() 
    self.Menu = MenuElement({type = MENU, id = "zgZeri", name = "Zgjfjfl Zeri"})
    
    self.Menu:MenuElement({type = MENU, id = "BlockAA", name = "No AA without Q passive"})
        self.Menu.BlockAA:MenuElement({id = "enabled", name = "Enabled", value = true, key = string.byte("T"), toggle = true})

    self.Menu:MenuElement({type = MENU, id = "QSpell", name = "Q"})
        self.Menu.QSpell:MenuElement({ id = "QEnabled", name = "Combo Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QHEnabled", name = "Harass Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QLCEnabled", name = "Lane Clear Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QLHEnabled", name = "LastHit Enabled", value = true})
        self.Menu.QSpell:MenuElement({ id = "QObj", name = "Buildings & Wards Enabled", value = true})

    self.Menu:MenuElement({type = MENU, id = "WSpell", name = "W"})
        self.Menu.WSpell:MenuElement({ id = "WEnabled", name = "Combo Enabled", value = true})
        self.Menu.WSpell:MenuElement({ id = "WTerrain", name = "Use only through Walls", value = true})

    self.Menu:MenuElement({type = MENU, id = "ESpell", name = "E"})
        self.Menu.ESpell:MenuElement({ id = "EEnabled", name = "Combo Enabled", value = false})
    
    self.Menu:MenuElement({type = MENU, id = "RSpell", name = "R"})
        self.Menu.RSpell:MenuElement({ id = "REnabled", name = "Combo Enabled", value = true})
        self.Menu.RSpell:MenuElement({ id = "RCount", name = "Use Ultimate when can hit >= X enemies", min = 1, max = 5, value = 2})

    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawing"})
        self.Menu.Drawing:MenuElement({id = "Qrange", name = "Draw Q Range", value = true})
        self.Menu.Drawing:MenuElement({id = "DrawBlockAA", name = "Draw Block AA", value = true})

end

function Zeri:onTickEvent()

    if doesMyChampionHaveBuff("ZeriR") then
        qData.Speed = 3400
    else
        qData.Speed = 2600
    end

    hasQPassive = doesMyChampionHaveBuff("ZeriQPassiveReady")
    if hasQPassive and self.Menu.BlockAA.enabled:Value() then
        Orbwalker:SetAttack(true)
    elseif not hasQPassive and self.Menu.BlockAA.enabled:Value() then
        Orbwalker:SetAttack(false)
    else
        Orbwalker:SetAttack(true)
    end

    if myHero.range == 550 then
        qData.Range = 800
    else
        qData.Range = 750
    end

    wData.Delay = math.max(math.floor((0.55 - 0.09 * (myHero.attackSpeed - 1)) * 100) / 100, 0.3)
    w2Data.Delay = wData.Delay

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        self:Combo()
    end

    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        self:QObject()
        self:QFarm()
    end
	
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        self:Lasthit()
        self:Harass()
    end
    if Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        self:Lasthit()
    end
end

function Zeri:CastQ(target)
    local pred = GGPrediction:SpellPrediction(qData)
    pred:GetPrediction(target, myHero)
    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
        Control.CastSpell(HK_Q, pred.CastPosition)
    end
end

function Zeri:CastW(target)
    local time = Game.Timer() - lastW
    if time < wData.Delay + 0.1 then
        return false
    end

    local direction = (target.pos - myHero.pos):Normalized()
    for distance = 50, 1100, 50 do
        local testPosition = myHero.pos + direction * distance
        if testPosition:ToScreen().onScreen and target.pos:ToScreen().onScreen then
            
            for i = 1, GameMinionCount() do -- blocked by minion
                local minion = GameMinion(i)
                if minion and minion.isEnemy and isValid(minion) and getDistance(minion.pos, testPosition) < 50 then
                    return false
                end 
            end
            if getDistance(target.pos, testPosition) < 50 then
                if not self.Menu.WSpell.WTerrain:Value() then
                    local pred = GGPrediction:SpellPrediction(wData)
                    pred:GetPrediction(target, myHero)
                    if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                        Control.CastSpell(HK_W, pred.CastPosition)
                    end
                    lastW = Game.Timer()
                    return true
                else
                    return false
                end
            end
            if MapPosition:inWall(testPosition) then
                if getDistance(target.pos, testPosition) > 1500 then
                    return false
                end
                local pred = GGPrediction:SpellPrediction(w2Data)
                pred:GetPrediction(target, myHero)
                if pred:CanHit(GGPrediction.HITCHANCE_HIGH) then
                    Control.CastSpell(HK_W, pred.CastPosition)
                end
                lastW = Game.Timer()
                return true
            end
        end
    end
    return false
end

function Zeri:Combo()

    -- local executeDmg = self:AAexecuteDmg()
    -- if self.Menu.BlockAA.enabled:Value() and not hasQPassive and not myHero.isChanneling then
        -- local targets = ObjectManager:GetEnemyHeroes(Data:GetAutoAttackRange(myHero))
        -- for i, target in ipairs(targets) do
            -- if target and target.health <= executeDmg then
                -- Control.Attack(target)
                -- return
            -- end
        -- end
    -- end

    local Qtarget = TargetSelector:GetTarget(qData.Range)
    if Qtarget and isSpellReady(_Q) and self.Menu.QSpell.QEnabled:Value() then
        self:CastQ(Qtarget)
    end

    local Wtarget = TargetSelector:GetTarget(2700)
    if Wtarget and isSpellReady(_W) and self.Menu.WSpell.WEnabled:Value() and getDistance(Wtarget.pos, myHero.pos) > qData.Range then
        self:CastW(Wtarget)
    end

    if isSpellReady(_E) and self.Menu.ESpell.EEnabled:Value() then
        local pos = myHero.pos + (mousePos - myHero.pos):Normalized() * 300
        Control.CastSpell(HK_E, pos)
    end

    if isSpellReady(_R) and self.Menu.RSpell.REnabled:Value() then 
        if self.Menu.RSpell.RCount:Value() <= #getEnemyHeroesWithinDistance(825) then
            Control.CastSpell(HK_R)
        end
    end
end

function Zeri:Harass()
    local target = TargetSelector:GetTarget(qData.Range)
    if target and isSpellReady(_Q) and self.Menu.QSpell.QHEnabled:Value() then
        self:CastQ(target)
    end
end

function Zeri:QObject()
    if not isSpellReady(_Q) or not self.Menu.QSpell.QObj:Value() then return end

    local qRange = qData.Range
    local targets = {}
    local turrets = ObjectManager:GetEnemyTurrets(qRange)
    local buildings = ObjectManager:GetEnemyBuildings(qRange + 380)
    local wards = ObjectManager:GetOtherEnemyMinions(qRange)

    for _, turret in pairs(turrets) do
        if turret.isTargetable then
            table.insert(targets, turret)
        end
    end

    for _, building in pairs(buildings) do
        if building.type == Obj_AI_Nexus or (building.type == Obj_AI_Barracks and building.distance < qRange + 270) then
            table.insert(targets, building)
        end
    end

    for _, ward in pairs(wards) do
        table.insert(targets, ward)
    end

    if #targets > 0 then
        Control.CastSpell(HK_Q, targets[1])
    end
end

function Zeri:AAexecuteDmg()
    local level = myHero.levelData.lvl
    return 60 + 90 / 17 * (level - 1)
end

function Zeri:QFarm()
    if not isSpellReady(_Q) or not self.Menu.QSpell.QLCEnabled:Value() then return end

    local level = myHero:GetSpellData(_Q).level
    local qBaseDamage = {15, 17, 19, 21, 23}
    local qBonusDamage = {1.04, 1.08, 1.12, 1.16, 1.2}
    local qDamage = qBaseDamage[level] + qBonusDamage[level] * myHero.totalDamage
    local Minions = ObjectManager:GetEnemyMinions(qData.Range)
    local target = nil
    if #Minions > 0 then
        target = Minions[1]
    end
    for i = 1, #Minions do
        local unit = Minions[i]
        if unit.health <= qDamage then
            target = unit
            break
        end
    end
    if target then
        Control.CastSpell(HK_Q, target)
    end
end

function Zeri:Lasthit()
    if not isSpellReady(_Q) or not self.Menu.QSpell.QLHEnabled:Value() then return end

    local minionInRange = ObjectManager:GetEnemyMinions(qData.Range)
    for i, minion in ipairs(minionInRange) do
        if getDistance(minion.pos) <= qData.Range then
            local level = myHero:GetSpellData(_Q).level
            local qBaseDamage = {15, 17, 19, 21, 23}
            local qBonusDamage = {1.04, 1.08, 1.12, 1.16, 1.2}
            local qDamage = qBaseDamage[level] + qBonusDamage[level] * myHero.totalDamage
            if qDamage >= minion.health and not minion.dead then
                Control.CastSpell(HK_Q, minion)
                break
            end
        end
    end
end

function Zeri:Draw()
    if self.Menu.Drawing.Qrange:Value() then
        Draw.Circle(myHero.pos, qData.Range, 0.5, Draw.Color(150, 255, 255, 255))
    end
    if self.Menu.Drawing.DrawBlockAA:Value() then
        if self.Menu.BlockAA.enabled:Value() then
            Draw.Text("AA Disabled", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(150, 255, 0, 0))
        else
            Draw.Text("AA Enabled", 15, myHero.pos2D.x -30, myHero.pos2D.y, Draw.Color(150, 0, 255, 0))
        end
    end
end