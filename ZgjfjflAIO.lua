if not _G.SDK then
    print("GGOrbwalker is not enabled. Zgjfjfl AIO will exit.")
    return
end

local BaseUrl   = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/master/ZgjfjflAIO/"
local BasePath  = COMMON_PATH .. "ZgjfjflAIO\\"
local HeroPath  = BasePath .. "Heroes\\"
local charName  = myHero.charName

local function FileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function GetLocalVersion(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local line = f:read("*l"); f:close()
    return tonumber(line and line:match("Version%s*=%s*([%d.]+)")) or 0
end

local function ParseVersionContent(content)
    local t = {}
    for line in (content or ""):gmatch("[^\r\n]+") do
        local k, v = line:match("^([^=]+)=(.+)$")
        if k then t[k] = tonumber(v) or 0 end
    end
    return t
end

do
    local GGPredictionFile = COMMON_PATH .. "GGPrediction.lua"
    local UtilsFile = BasePath .. "Utils.lua"
    local HeroFile = HeroPath .. "zg" .. charName .. ".lua"
    local VersionUrl = BaseUrl .. "ZgjfjflAIO.version"
    local GGPredictionUrl = "https://raw.githubusercontent.com/4risto/GoS/master/GGPrediction.lua"
    local UtilsUrl = BaseUrl .. "Utils.lua"
    local HeroUrl = BaseUrl .. "Heroes/zg" .. charName .. ".lua"
    GetWebResultAsync(VersionUrl, function(content)
        if not content or content == "" then
            print("Zgjfjfl AIO: Failed to check version. Network error or URL unreachable.")
            return
        end
        local remoteVersion = ParseVersionContent(content)
        if not remoteVersion["zg" .. charName] then
            print("Zgjfjfl AIO: " .. charName .. " is not supported yet")
            return
        end
        if not FileExists(GGPredictionFile) then
            DownloadFileAsync(GGPredictionUrl, GGPredictionFile, function()
                print("Zgjfjfl AIO: Downloaded GGPrediction File, F6 to Reload")
            end)
        end
        if not FileExists(UtilsFile) then
            print("Zgjfjfl AIO: First time setup, Downloading Utils File")
            DownloadFileAsync(UtilsUrl, UtilsFile, function()
                print("Zgjfjfl AIO: Downloaded Utils File, F6 to Reload")
            end)
        end
        if not FileExists(HeroFile) then
            print("Zgjfjfl AIO: " .. charName .. " File Missing, Downloading File")
            DownloadFileAsync(HeroUrl, HeroFile, function()
                print("Zgjfjfl AIO: Downloaded " .. charName .. " File, F6 to Reload")
            end)
        end
        if not FileExists(UtilsFile) or not FileExists(HeroFile) then
            return
        end
        local localUtilsVersion = GetLocalVersion(UtilsFile)
        local localHeroVersion = GetLocalVersion(HeroFile)
        if remoteVersion["Utils"] > localUtilsVersion then
            print("Zgjfjfl AIO: Found Utils File Update")
            DownloadFileAsync(UtilsUrl, UtilsFile, function()
                print("Zgjfjfl AIO: Updated Utils File, F6 to Reload")
            end)
        end
        if remoteVersion["zg" .. charName] > localHeroVersion then
            print("Zgjfjfl AIO: Found " .. charName .. " File Update")
            DownloadFileAsync(HeroUrl, HeroFile, function()
                print("Zgjfjfl AIO: Updated " .. charName .. " File, F6 to Reload")
            end)
        end
    end)
end

Callback.Add("Load", function()
    local UtilsFile = BasePath .. "Utils.lua"
    local HeroFile = HeroPath .. "zg" .. charName .. ".lua"
    if FileExists(UtilsFile) and FileExists(HeroFile) then
        require("ZgjfjflAIO\\Heroes\\zg" .. charName)
    end
end)
