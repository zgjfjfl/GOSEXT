if not _G.SDK then
    print("GGOrbwalker is not enabled. Classic AIO will exit.")
    return
end

local BaseUrl  = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/master/ClassicAIO/"
local BasePath = COMMON_PATH .. "ClassicAIO\\"
local HeroPath = BasePath .. "Heroes\\"
local rawCharName = myHero.charName
local charName = rawCharName:match("^Jade_(.+)$")

if not charName or charName == "" then
    print("Classic AIO: " .. tostring(rawCharName) .. " is not a Jade classic champion")
    return
end

local heroKey = "Classic" .. charName

local function FileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function GetLocalVersion(path)
    local file = io.open(path, "r")
    if not file then return 0 end
    local line = file:read("*l")
    file:close()
    return tonumber(line and line:match("Version%s*=%s*([%d.]+)")) or 0
end

local function ParseVersionContent(content)
    local versions = {}
    for line in (content or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.+)$")
        if key then
            versions[key] = tonumber(value) or 0
        end
    end
    return versions
end

do
    local UtilsFile = BasePath .. "Utils.lua"
    local HeroFile = HeroPath .. heroKey .. ".lua"
    local VersionUrl = BaseUrl .. "ClassicAIO.version"
    local UtilsUrl = "https://raw.githubusercontent.com/zgjfjfl/GOSEXT/master/ZgjfjflAIO/Utils.lua"
    local HeroUrl = BaseUrl .. "Heroes/" .. heroKey .. ".lua"
    GetWebResultAsync(VersionUrl, function(content)
        if not content or content == "" then
            print("Classic AIO: Failed to check version. Network error or URL unreachable.")
            return
        end
        local remoteVersion = ParseVersionContent(content)
        if not remoteVersion[heroKey] then
            print("Classic AIO: " .. rawCharName .. " is not supported yet")
            return
        end
        if not FileExists(UtilsFile) then
            print("Classic AIO: First time setup, Downloading Utils File")
            DownloadFileAsync(UtilsUrl, UtilsFile, function()
                print("Classic AIO: Downloaded Utils File, F6 to Reload")
            end)
        end
        if not FileExists(HeroFile) then
            print("Classic AIO: " .. rawCharName .. " File Missing, Downloading File")
            DownloadFileAsync(HeroUrl, HeroFile, function()
                print("Classic AIO: Downloaded " .. rawCharName .. " File, F6 to Reload")
            end)
        end
        if not FileExists(UtilsFile) or not FileExists(HeroFile) then
            return
        end
        local localUtilsVersion = GetLocalVersion(UtilsFile)
        local localHeroVersion = GetLocalVersion(HeroFile)
        if (remoteVersion.Utils or 0) > localUtilsVersion then
            print("Classic AIO: Found Utils File Update")
            DownloadFileAsync(UtilsUrl, UtilsFile, function()
                print("Classic AIO: Updated Utils File, F6 to Reload")
            end)
        end
        if remoteVersion[heroKey] > localHeroVersion then
            print("Classic AIO: Found " .. rawCharName .. " File Update")
            DownloadFileAsync(HeroUrl, HeroFile, function()
                print("Classic AIO: Updated " .. rawCharName .. " File, F6 to Reload")
            end)
        end
    end)
end

Callback.Add("Load", function()
    local UtilsFile = BasePath .. "Utils.lua"
    local HeroFile = HeroPath .. heroKey .. ".lua"
    if FileExists(UtilsFile) and FileExists(HeroFile) then
        require("ClassicAIO\\Heroes\\" .. heroKey)
    end
end)
