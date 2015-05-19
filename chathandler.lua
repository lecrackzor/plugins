PLUGIN.Title        = "Chat Handler"
PLUGIN.Description  = "Many features to help moderate the chat"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(2, 5, 5)
PLUGIN.ResourceId   = 707

local debugMode = false

-- --------------------------------
-- declare some plugin wide vars
-- --------------------------------
local muteData, spamData, langData = {}, {}, {}
local MuteList = "chathandler-mutelist"
local SpamList = "chathandler-spamlist"
local LangFile = "chathandler-localization"
local LogFile = "Log.ChatHandler.txt"
local AntiSpam, ChatHistory, AdminMode = {}, {}, {}
local GlobalMute = false
local langString
-- external plugin references
local exRanksAndTitles
-- --------------------------------
-- initialise all settings and data
-- --------------------------------
function PLUGIN:Init()
    self:LoadDefaultConfig()
    self:LoadChatCommands()
    self:LoadDataFiles()
    self:LoadLocalization()
    self:RegisterPermissions()
end
function PLUGIN:OnServerInitialized()
    exRanksAndTitles = plugins.Find("RanksAndTitles") or false
end
-- --------------------------------
-- error and debug reporting
-- --------------------------------
local pluginTitle = PLUGIN.Title
local pluginVersion = string.match(tostring(PLUGIN.Version), "(%d+.%d+.%d+)")
local function error(msg)
    local message = "[Error] "..pluginTitle.."(v"..pluginVersion.."): "..msg
    local array = util.TableToArray({message})
    UnityEngine.Debug.LogError.methodarray[0]:Invoke(nil, array)
    print(message)
end
local function debug(msg)
    if not debugMode then return end
    local message = "[Debug] "..pluginTitle.."(v"..pluginVersion.."): "..msg
    local array = util.TableToArray({message})
    UnityEngine.Debug.LogWarning.methodarray[0]:Invoke(nil, array)
end
-- --------------------------------
-- permission check
-- --------------------------------
local function HasPermission(player, perm)
    local steamID = rust.UserIDFromPlayer(player)
    if player:GetComponent("BaseNetworkable").net.connection.authLevel == 2 then
        return true
    end
    if permission.UserHasPermission(steamID, perm) then
        return true
    end
    return false
end
-- --------------------------------
-- builds output messages by replacing wildcards
-- --------------------------------
local function buildOutput(str, tags, replacements)
    for i = 1, #tags do
        str = string.gsub(str, tags[i], replacements[i])
    end
    return str
end
-- --------------------------------
-- prints to server console
-- --------------------------------
local function printToConsole(msg)
    global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, msg)
end
-- --------------------------------
-- prints to log file
-- --------------------------------
local function printToFile(msg)
    global.server.Log(LogFile, msg.."\n")
end
-- --------------------------------
-- splits chat messages longer than 80 characters into multilines
-- --------------------------------
local function splitLongMessages(msg, maxCharsPerLine)
    local length = string.len(msg)
    local msgTbl = {}
    if length > 128 then
        msg = string.sub(msg, 1, 128)
    end
    if length > maxCharsPerLine then
        while length > maxCharsPerLine do
            local subStr = string.sub(msg, 1, maxCharsPerLine)
            local first, last = string.find(string.reverse(subStr), " ")
            if first then
                subStr = string.sub(subStr, 1, -first)
            end
            table.insert(msgTbl, subStr)
            msg = string.sub(msg, string.len(subStr) + 1)
            length = string.len(msg)
        end
        table.insert(msgTbl, msg)
    else
        table.insert(msgTbl, msg)
    end
    return msgTbl
end
-- --------------------------------
-- generates default config
-- --------------------------------
function PLUGIN:LoadDefaultConfig() 
    self.Config.Settings                                = self.Config.Settings or {}
    -- General Settings
    self.Config.Settings.General                        = self.Config.Settings.General or {}
    self.Config.Settings.General.Language               = self.Config.Settings.General.Language or "en"
    self.Config.Settings.General.MaxCharsPerLine        = self.Config.Settings.General.MaxCharsPerLine or 64
    self.Config.Settings.General.BroadcastMutes         = self.Config.Settings.General.BroadcastMutes or self.Config.Settings.BroadcastMutes or "true"
    self.Config.Settings.General.BlockServerAds         = self.Config.Settings.General.BlockServerAds or self.Config.Settings.BlockServerAds or "true"
    self.Config.Settings.General.AllowedIPsToPost       = self.Config.Settings.General.AllowedIPsToPost or self.Config.AllowedIPsToPost or {}
    self.Config.Settings.General.EnableChatHistory      = self.Config.Settings.General.EnableChatHistory or self.Config.Settings.EnableChatHistory or "true"
    self.Config.Settings.General.ChatHistoryMaxLines    = self.Config.Settings.General.ChatHistoryMaxLines or self.Config.Settings.ChatHistoryMaxLines or 10
    -- Wordfilter settings
    self.Config.Settings.Wordfilter                     = self.Config.Settings.Wordfilter or {}
    self.Config.Settings.Wordfilter.EnableWordfilter    = self.Config.Settings.Wordfilter.EnableWordfilter or "false"
    self.Config.Settings.Wordfilter.ReplaceFullWord     = self.Config.Settings.Wordfilter.ReplaceFullWord or "true"
    -- Chat commands
    self.Config.Settings.ChatCommands                   = self.Config.Settings.ChatCommands or {}
    self.Config.Settings.ChatCommands.AdminMode         = self.Config.Settings.ChatCommands.AdminMode or {"admin"}
    self.Config.Settings.ChatCommands.ChatHistory       = self.Config.Settings.ChatCommands.ChatHistory or {"history", "h"}
    self.Config.Settings.ChatCommands.Mute              = self.Config.Settings.ChatCommands.Mute or {"mute"}
    self.Config.Settings.ChatCommands.Unmute            = self.Config.Settings.ChatCommands.Unmute or {"unmute"}
    self.Config.Settings.ChatCommands.GlobalMute        = self.Config.Settings.ChatCommands.GlobalMute or {"globalmute"}
    self.Config.Settings.ChatCommands.Wordfilter        = self.Config.Settings.ChatCommands.Wordfilter or {"wordfilter" }
    -- command permissions
    self.Config.Settings.Permissions                    = self.Config.Settings.Permissions or {}
    self.Config.Settings.Permissions.AdminMode          = self.Config.Settings.Permissions.AdminMode or "canadminmode"
    self.Config.Settings.Permissions.Mute               = self.Config.Settings.Permissions.Mute or "canmute"
    self.Config.Settings.Permissions.GlobalMute         = self.Config.Settings.Permissions.GlobalMute or "canglobalmute"
    self.Config.Settings.Permissions.AntiGlobalMute     = self.Config.Settings.Permissions.AntiGlobalMute or "notglobalmuted"
    self.Config.Settings.Permissions.EditWordFilter     = self.Config.Settings.Permissions.EditWordFilter or "caneditwordfilter"
    -- Name colors
    self.Config.Settings.NameColor                      = self.Config.Settings.NameColor or {}
    self.Config.Settings.NameColor.NormalUser           = self.Config.Settings.NameColor.NormalUser or "#5af"
    self.Config.Settings.NameColor.AdminMode            = self.Config.Settings.NameColor.AdminMode or "#ff8000"
    -- Logging settings
    self.Config.Settings.Logging                        = self.Config.Settings.Logging or {}
    self.Config.Settings.Logging.LogToConsole           = self.Config.Settings.Logging.LogToConsole or "true"
    self.Config.Settings.Logging.LogBlockedMessages     = self.Config.Settings.Logging.LogBlockedMessages or "true"
    self.Config.Settings.Logging.LogToFile              = self.Config.Settings.Logging.LogToFile or "false"
    -- Admin mode settings
    self.Config.Settings.AdminMode                      = self.Config.Settings.AdminMode or {}
    self.Config.Settings.AdminMode.ReplaceChatName      = self.Config.Settings.AdminMode.ReplaceChatName or "true"
    self.Config.Settings.AdminMode.AdminChatName        = self.Config.Settings.AdminMode.AdminChatName or "[Server Admin]"
    -- Antispam settings
    self.Config.Settings.AntiSpam                       = self.Config.Settings.AntiSpam or {}
    self.Config.Settings.AntiSpam.EnableAntiSpam        = self.Config.Settings.AntiSpam.EnableAntiSpam or "true"
    self.Config.Settings.AntiSpam.MaxLines              = self.Config.Settings.AntiSpam.MaxLines or 4
    self.Config.Settings.AntiSpam.TimeFrame             = self.Config.Settings.AntiSpam.TimeFrame or 6
    -- Group settings
    self.Config.Settings.Groups                         = self.Config.Settings.Groups or {}
    self.Config.Settings.Groups.EnableGroups            = self.Config.Settings.Groups.EnableGroups or "false"
    self.Config.Settings.Groups.PrefixPosition          = self.Config.Settings.Groups.PrefixPosition or "left"
    self.Config.Settings.Groups.ColorNamesOnly          = self.Config.Settings.Groups.ColorNamesOnly or "true"
    -- Check if PrefixPosition setting is valid
    if self.Config.Settings.Groups.PrefixPosition ~= "left" and self.Config.Settings.Groups.PrefixPosition ~= "right" then
        self.Config.Settings.Groups.PrefixPosition = "left"
    end
    -- Chatgroups
    self.Config.ChatGroups = self.Config.ChatGroups or {
        ["Donator"] = {
            ["Permission"] = "donator",
            ["Prefix"] = "[$$$]",
            ["Color"] = "#06DCFB",
            ["ShowPrefix"] = true,
            ["ShowColor"] = true
        },
        ["VIP"] = {
            ["Permission"] = "vip",
            ["Prefix"] = "[VIP]",
            ["Color"] = "#59ff4a",
            ["ShowPrefix"] = true,
            ["ShowColor"] = true
        },
        ["Admin"] = {
            ["Permission"] = "admin",
            ["Prefix"] = "[Admin]",
            ["Color"] = "#FFA04A",
            ["ShowPrefix"] = true,
            ["ShowColor"] = true
        }
    }
    -- Wordfilter
    self.Config.WordFilter = self.Config.WordFilter or {
        ["bitch"] = "sweety",
        ["fucking hell"] = "lovely heaven",
        ["cunt"] = "****"
    }
    -- Check wordfilter for conflicts
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, _ = string.find(string.lower(value), string.lower(key))
            if first then
                self.Config.WordFilter[key] = nil
                error("Config error in wordfilter: [\""..key.."\":\""..value.."\"] both contain the same word")
                error("[\""..key.."\":\""..value.."\"] was removed from word filter")
            end
        end
    end
    -- removed config entries
        -- removed in v2.3.4
    self.Config.Settings.Logging.LogChatToOxide = nil
        -- removed in v2.4
    self.Config.AllowedIPsToPost = nil
    self.Config.Settings.BroadcastMutes = nil
    self.Config.Settings.BlockServerAds = nil
    self.Config.Settings.EnableWordFilter = nil
    self.Config.Settings.EnableChatHistory = nil
    self.Config.Settings.ChatHistoryMaxLines = nil
    self.Config.Settings.AdminMode.ChatCommand = nil
    self.Config.Settings.HelpText = nil
        -- removed in v2.5
    self.Config.Settings.NameColor.Admin = nil
    --
    self:SaveConfig()
end
-- --------------------------------
-- load all chat commands, depending on settings
-- --------------------------------
function PLUGIN:LoadChatCommands()
    for _, cmd in pairs(self.Config.Settings.ChatCommands.Mute) do
        command.AddChatCommand(cmd, self.Object, "cmdMute")
    end
    for _, cmd in pairs(self.Config.Settings.ChatCommands.Unmute) do
        command.AddChatCommand(cmd, self.Object, "cmdUnMute")
    end
    for _, cmd in pairs(self.Config.Settings.ChatCommands.AdminMode) do
        command.AddChatCommand(cmd, self.Object, "cmdAdminMode")
    end
    if self.Config.Settings.General.EnableChatHistory == "true" then
        for _, cmd in pairs(self.Config.Settings.ChatCommands.ChatHistory) do
            command.AddChatCommand(cmd, self.Object, "cmdHistory")
        end
    end
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        for _, cmd in pairs(self.Config.Settings.ChatCommands.Wordfilter) do
            command.AddChatCommand(cmd, self.Object, "cmdEditWordFilter")
        end
    end
    for _, cmd in pairs(self.Config.Settings.ChatCommands.GlobalMute) do
        command.AddChatCommand(cmd, self.Object, "cmdGlobalMute")
    end
    -- Console commands
    command.AddConsoleCommand("player.mute", self.Object, "ccmdMute")
    command.AddConsoleCommand("player.unmute", self.Object, "ccmdUnMute")
end
-- --------------------------------
-- handles all data files
-- --------------------------------
function PLUGIN:LoadDataFiles()
    muteData = datafile.GetDataTable(MuteList) or {}
    spamData = datafile.GetDataTable(SpamList) or {}
end
-- --------------------------------
-- handles localization file
-- --------------------------------
function PLUGIN:LoadLocalization()
    local configPath = self.Plugin.Manager.ConfigPath
    local fileName = configPath .. "/"..LangFile..".json"
    local langData = new(self.Plugin.Config:GetType(), nil)
    langData:Load(fileName)
    if not langData.Localization then
        error("Your ChatHandler localization file is corrupt. ChatHandler wont work properly")
        return
    end
    langString = langData.Localization[self.Config.Settings.General.Language]
end
-- --------------------------------
-- register all permissions for group system
-- --------------------------------
function PLUGIN:RegisterPermissions()
    -- command permissions
    for _, perm in pairs(self.Config.Settings.Permissions) do
        if not permission.PermissionExists(perm) then
            permission.RegisterPermission(perm, self.Object)
        end
    end
    -- group permissions
    if self.Config.Settings.Groups.EnableGroups == "true" then
        for key, _ in pairs(self.Config.ChatGroups) do
            permission.RegisterPermission(self.Config.ChatGroups[key].Permission, self.Object)
        end
    end
end
-- --------------------------------
-- removes expired mutes from the mutelist
-- --------------------------------
function PLUGIN:CleanUpMuteList()
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(muteData) do
        if muteData[key].expiration < now and muteData[key].expiration ~= 0 then
            table.remove(muteData, key)
            datafile.SaveDataTable(MuteList)
        end
    end
end
-- --------------------------------
-- broadcasts chat messages
-- --------------------------------
function PLUGIN:BroadcastChat(player, name, msg)
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        global.ConsoleSystem.Broadcast("chat.add", 0, name..": "..msg)
    else
        global.ConsoleSystem.Broadcast("chat.add", steamID, name..": "..msg)
    end
end
-- --------------------------------
-- returns args as a table
-- --------------------------------
function PLUGIN:ArgsToTable(args, src)
    local argsTbl = {}
    if src == "chat" then
        local length = args.Length
        for i = 0, length - 1, 1 do
            argsTbl[i + 1] = args[i]
        end
        return argsTbl
    end
    if src == "console" then
        local i = 1
        while args:HasArgs(i) do
            argsTbl[i] = args:GetString(i - 1)
            i = i + 1
        end
        return argsTbl
    end
    return argsTbl
end
-- --------------------------------
-- returns (bool)IsMuted, (string)timeMuted
-- --------------------------------
function PLUGIN:CheckMute(targetSteamID)
    local now = time.GetUnixTimestamp()
    if not muteData[targetSteamID] then return false, false end
    if muteData[targetSteamID].expiration < now and muteData[targetSteamID].expiration ~= 0 then
        muteData[targetSteamID] = nil
        datafile.SaveDataTable(MuteList)
        return false, false
    end
    if muteData[targetSteamID].expiration == 0 then
        return true, false
    else
        local expiration = muteData[targetSteamID].expiration
        local muteTime = expiration - now
        local hours = string.format("%02.f", math.floor(muteTime / 3600))
        local minutes = string.format("%02.f", math.floor(muteTime / 60 - (hours * 60)))
        local seconds = string.format("%02.f", math.floor(muteTime - (hours * 3600) - (minutes * 60)))
        local expirationString = tostring(hours.."h "..minutes.."m "..seconds.."s")
        return true, expirationString
    end
    return false, false
end
-- --------------------------------
-- handles chat command /admin
-- --------------------------------
function PLUGIN:cmdAdminMode(player)
    if not HasPermission(player, self.Config.Settings.Permissions.AdminMode) then
        rust.SendChatMessage(player, langString.AdminNotifications["NoPermission"])
        return
    end
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        AdminMode[steamID] = nil
        rust.SendChatMessage(player, langString.AdminNotifications["AdminModeDisabled"])
    else
        AdminMode[steamID] = true
        rust.SendChatMessage(player, langString.AdminNotifications["AdminModeEnabled"])
    end
end
-- --------------------------------
-- handles chat command /globalmute
-- --------------------------------
function PLUGIN:cmdGlobalMute(player)
    if not HasPermission(player, self.Config.Settings.Permissions.GlobalMute) then
        rust.SendChatMessage(player, langString.AdminNotifications["NoPermission"])
        return
    end
    if not GlobalMute then
        GlobalMute = true
        rust.BroadcastChat(langString.PlayerNotifications["GlobalMuteEnabled"])
    else
        GlobalMute = false
        rust.BroadcastChat(langString.PlayerNotifications["GlobalMuteDisabled"])
    end
end
-- --------------------------------
-- handles chat command /mute
-- --------------------------------
function PLUGIN:cmdMute(player, cmd, args)
    if not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        rust.SendChatMessage(player, langString.AdminNotifications["NoPermission"])
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target, duration = args[1], args[2]
    if not target then
        rust.SendChatMessage(player, "Syntax: /mute <name/steamID> <time[m/h] (optional)>")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        rust.SendChatMessage(player, langString.AdminNotifications["PlayerNotFound"])
        return
    end
    self:Mute(player, targetPlayer, duration, nil)
end
-- --------------------------------
-- handles console command player.mute
-- --------------------------------
function PLUGIN:ccmdMute(arg)
    local player, F1Console
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if player and not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        arg:ReplyWith(langString.AdminNotifications["NoPermission"])
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target, duration = args[1], args[2]
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: player.mute <name/steamID> <time[m/h] (optional)>")
        else
            printToConsole("Syntax: player.mute <name/steamID> <time[m/h] (optional)>")
        end
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        if F1Console then
            arg:ReplyWith(langString.AdminNotifications["PlayerNotFound"])
        else
            printToConsole(langString.AdminNotifications["PlayerNotFound"])
        end
        return
    end
    self:Mute(player, targetPlayer, duration, arg)
end
-- --------------------------------
-- mute target
-- --------------------------------
function PLUGIN:Mute(player, targetPlayer, duration, arg)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    -- Check if target is already muted
    local isMuted, _ = self:CheckMute(targetSteamID)
    if isMuted then
        if F1Console then
            arg:ReplyWith(buildOutput(langString.AdminNotifications["AlreadyMuted"], {"{name}"}, {targetName}))
        end
        if srvConsole then
            printToConsole(buildOutput(langString.AdminNotifications["AlreadyMuted"], {"{name}"}, {targetName}))
        end
        if chatCmd then
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["AlreadyMuted"], {"{name}"}, {targetName}))
        end
        return
    end
    if not duration then
    -- No time is given, mute permanently
        muteData[targetSteamID] = {}
        muteData[targetSteamID].steamID = targetSteamID
        muteData[targetSteamID].expiration = 0
        table.insert(muteData, muteData[targetSteamID])
        datafile.SaveDataTable(MuteList)
        -- Send mute notice
        if self.Config.Settings.General.BroadcastMutes == "true" then
            rust.BroadcastChat(buildOutput(langString.PlayerNotifications["BroadcastMutes"], {"{name}"}, {targetName}))
            if F1Console then
                arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerMuted"], {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(langString.AdminNotifications["PlayerMuted"], {"{name}"}, {targetName}))
            end
        else
            if F1Console then
                arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerMuted"], {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(langString.AdminNotifications["PlayerMuted"], {"{name}"}, {targetName}))
            end
            if chatCmd then
                rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["PlayerMuted"], {"{name}"}, {targetName}))
            end
            rust.SendChatMessage(targetPlayer, langString.PlayerNotifications["Muted"])
        end
        -- Send console log
        if self.Config.Settings.Logging.LogToConsole == "true" then
            if not player then
                printToConsole("[ChatHandler] An admin muted "..targetName)
            else
                printToConsole("[ChatHandler] "..player.displayName.." muted "..targetName)
            end
        end
        -- log to file
        if self.Config.Settings.Logging.LogToFile == "true" then
            if not player then
                printToFile("An admin muted "..targetName)
            else
                printToFile(player.displayName.." muted "..targetName)
            end
        end
        return
    end
    -- Time is given, mute only for this timeframe
    -- Check for valid time format
    local c = string.match(duration, "^%d*[mh]$")
    if string.len(duration) < 2 or not c then
        if F1Console then
            arg:ReplyWith(langString.AdminNotifications["InvalidTimeFormat"])
        end
        if srvConsole then
            printToConsole(langString.AdminNotifications["InvalidTimeFormat"])
        end
        if chatCmd then
            rust.SendChatMessage(player, langString.AdminNotifications["InvalidTimeFormat"])
        end
        return
    end
    -- Build expiration time
    local now = time.GetUnixTimestamp()
    local muteTime = tonumber(string.sub(duration, 1, -2))
    local timeUnit = string.sub(duration, -1)
    local timeMult, timeUnitLong
    if timeUnit == "m" then
        timeMult = 60
        timeUnitLong = "minutes"
    end
    if timeUnit == "h" then
        timeMult = 3600
        timeUnitLong = "hours"
    end
    local expiration = (now + (muteTime * timeMult))
    local time = muteTime.." "..timeUnitLong
    -- Mute player for given duration
    muteData[targetSteamID] = {}
    muteData[targetSteamID].steamID = targetSteamID
    muteData[targetSteamID].expiration = expiration
    table.insert(muteData, muteData[targetSteamID])
    datafile.SaveDataTable(MuteList)
    -- Send mute notice
    if self.Config.Settings.General.BroadcastMutes == "true" then
        rust.BroadcastChat(buildOutput(langString.PlayerNotifications["BroadcastMutesTimed"], {"{name}", "{time}"}, {targetName, time}))
        if F1Console then
            arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerMutedTimed"], {"{name}", "{time}"}, {targetName, time}))
        end
        if srvConsole then
            printToConsole(buildOutput(langString.AdminNotifications["PlayerMutedTimed"], {"{name}", "{time}"}, {targetName, time}))
        end
    else
        rust.SendChatMessage(targetPlayer, buildOutput(langString.PlayerNotifications["MutedTimed"], {"{time}"}, {time}))
        if F1Console then
            arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerMutedTimed"], {"{name}", "{time}"}, {targetName, time}))
        end
        if srvConsole then
            printToConsole(buildOutput(langString.AdminNotifications["PlayerMutedTimed"], {"{name}", "{time}"}, {targetName, time}))
        end
        if chatCmd then
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["PlayerMutedTimed"], {"{name}", "{time}"}, {targetName, time}))
        end
    end
    -- Send console log
    if self.Config.Settings.Logging.LogToConsole == "true" then
        if not player then
            printToConsole("[ChatHandler] An admin muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        else
            printToConsole("[ChatHandler] "..player.displayName.." muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        end
    end
    -- log to file
    if self.Config.Settings.Logging.LogToFile == "true" then
        if not player then
            printToFile("An admin muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        else
            printToFile(player.displayName.." muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        end
    end
end
-- --------------------------------
-- handles chat command /unmute
-- --------------------------------
function PLUGIN:cmdUnMute(player, cmd, args)
    if not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        rust.SendChatMessage(player, langString.AdminNotifications["NoPermission"])
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target = args[1]
    -- Check for valid syntax
    if not target then
        rust.SendChatMessage(player, "Syntax: /unmute <name|steamID> or /unmute all to clear mutelist")
        return
    end
    -- Check if "all" is used to clear the whole mutelist
    if target == "all" then
        local mutecount = #muteData
        muteData = {}
        datafile.SaveDataTable(MuteList)
        rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["MutelistCleared"], {"{count}"}, {tostring(mutecount)}))
        return
    end
    -- Try to get target netuser
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        rust.SendChatMessage(player, langString.AdminNotifications["PlayerNotFound"])
        return
    end
    self:Unmute(player, targetPlayer, nil)
end
-- --------------------------------
-- handles console command player.unmute
-- --------------------------------
function PLUGIN:ccmdUnMute(arg)
    local player, F1Console
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if player and not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        arg:ReplyWith(langString.AdminNotifications["NoPermission"])
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target = args[1]
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: player.unmute <name/steamID> or player.unmute all to clear mutelist")
        else
            printToConsole("Syntax: player.unmute <name/steamID> or player.unmute all to clear mutelist")
        end
        return
    end
    -- Check if "all" is used to clear the whole mutelist
    if target == "all" then
        local mutecount = #muteData
        muteData = {}
        datafile.SaveDataTable(MuteList)
        if F1Console then
            arg:ReplyWith(buildOutput(langString.AdminNotifications["MutelistCleared"], {"{count}"}, {tostring(mutecount)}))
        else
            printToConsole(buildOutput(langString.AdminNotifications["MutelistCleared"], {"{count}"}, {tostring(mutecount)}))
        end
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        if F1Console then
            arg:ReplyWith(langString.AdminNotifications["PlayerNotFound"])
        else
            printToConsole(langString.AdminNotifications["PlayerNotFound"])
        end
        return
    end
    self:Unmute(player, targetPlayer, arg)
end
-- --------------------------------
-- unmute target
-- --------------------------------
function PLUGIN:Unmute(player, targetPlayer, arg)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    -- Unmute player
    if muteData[targetSteamID] then
        muteData[targetSteamID] = nil
        datafile.SaveDataTable(MuteList)
        -- Send unmute notice
        if self.Config.Settings.General.BroadcastMutes == "true" then
            rust.BroadcastChat(buildOutput(langString.PlayerNotifications["BroadcastUnmutes"], {"{name}"}, {targetName}))
            if F1Console then
                arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerUnmuted"], {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(langString.AdminNotifications["PlayerUnmuted"], {"{name}"}, {targetName}))
            end
        else
            rust.SendChatMessage(targetPlayer, langString.PlayerNotifications["Unmuted"])
            if F1Console then
                arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerUnmuted"], {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(langString.AdminNotifications["PlayerUnmuted"], {"{name}"}, {targetName}))
            end
            if chatCmd then
                rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["PlayerUnmuted"], {"{name}"}, {targetName}))
            end
        end
        -- Send console log
        if self.Config.Settings.Logging.LogToConsole == "true" then
            if player then
                printToConsole("[ChatHandler] "..player.displayName.." unmuted "..targetName)
            else
                printToConsole("[ChatHandler] An admin unmuted "..targetName)
            end
        end
        -- log to file
        if self.Config.Settings.Logging.LogToFile == "true" then
            if player then
                printToFile(player.displayName.." unmuted "..targetName)
            else
                printToFile("An admin unmuted "..targetName)
            end
        end
        return
    end
    -- player is not muted
    if F1Console then
        arg:ReplyWith(buildOutput(langString.AdminNotifications["PlayerNotMuted"], {"{name}"}, {targetName}))
    end
    if srvConsole then
        printToConsole(buildOutput(langString.AdminNotifications["PlayerNotMuted"], {"{name}"}, {targetName}))
    end
    if chatCmd then
        rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["PlayerNotMuted"], {"{name}"}, {targetName}))
    end
end
-- --------------------------------
-- handles chat messages
-- --------------------------------
function PLUGIN:OnPlayerChat(arg)
    local msg = arg:GetString(0, "text")
    local player = arg.connection.player
    if string.sub(msg, 1, 1) == "/" or msg == "" then return end
    local steamID = rust.UserIDFromPlayer(player)
    -- Spam prevention
    if self.Config.Settings.AntiSpam.EnableAntiSpam == "true" then
        local isSpam, punishTime = self:AntiSpamCheck(player)
        if isSpam then
            rust.SendChatMessage(player, buildOutput(langString.PlayerNotifications["AutoMuted"], {"{punishTime}"}, {punishTime}))
            timer.Once(4, function() rust.SendChatMessage(player, langString.PlayerNotifications["SpamWarning"]) end)
            if self.Config.Settings.General.BroadcastMutes == "true" then
                rust.BroadcastChat(buildOutput(langString.PlayerNotifications["BroadcastAutoMutes"], {"{name}", "{punishTime}"}, {player.displayName, punishTime}))
            end
            if self.Config.Settings.Logging.LogToConsole == "true" then
                printToConsole("[ChatHandler] "..player.displayName.." got a "..punishTime.." auto mute for spam")
            end
            if self.Config.Settings.Logging.LogToFile == "true" then
                printToFile(player.displayName.." got a "..punishTime.." auto mute for spam")
            end
            return false
        end
    end
    -- Parse message to filter stuff and check if message should be blocked
    local canChat, msg, errorMsg, errorPrefix = self:ParseChat(player, msg)
    -- Chat is blocked
    if not canChat then
        if self.Config.Settings.Logging.LogBlockedMessages == "true" then
            if self.Config.Settings.Logging.LogToConsole == "true" then
                global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, errorPrefix, System.ConsoleColor.DarkYellow, " "..player.displayName..": ", System.ConsoleColor.DarkGreen, msg)
            end
            if self.Config.Settings.Logging.LogToFile == "true" then
                global.server.Log("Log.Chat.txt", errorPrefix.." "..steamID.."/"..player.displayName..": "..msg.."\n")
            end
        end
        rust.SendChatMessage(player, errorMsg)
        return false
    end
    -- Chat is ok and not blocked
    local maxCharsPerLine = tonumber(self.Config.Settings.General.MaxCharsPerLine)
    msg = splitLongMessages(msg, maxCharsPerLine) -- msg is a table now
    local i = 1
    while msg[i] do
        local username, message, logUsername, logMessage = self:BuildNameMessage(player, msg[i])
        self:SendChat(player, username, message, logUsername, logMessage)
        i = i + 1
    end
    return false
end
-- --------------------------------
-- checks for chat spam
-- returns (bool)IsSpam, (string)punishTime
-- --------------------------------
function PLUGIN:AntiSpamCheck(player)
    local steamID = rust.UserIDFromPlayer(player)
    local now = time.GetUnixTimestamp()
    if muteData[steamID] then return false, false end
    if AdminMode[steamID] then return false, false end
    if AntiSpam[steamID] then
        local firstMsg = AntiSpam[steamID].timestamp
        local msgCount = AntiSpam[steamID].msgcount
        if msgCount < self.Config.Settings.AntiSpam.MaxLines then
            AntiSpam[steamID].msgcount = AntiSpam[steamID].msgcount + 1
            return false, false
        else
            if now - firstMsg <= self.Config.Settings.AntiSpam.TimeFrame then
                -- punish
                local punishCount = 1
                local expiration, punishTime, newEntry
                if spamData[steamID] then
                    newEntry = false
                    punishCount = spamData[steamID].punishcount + 1
                    spamData[steamID].punishcount = punishCount
                    datafile.SaveDataTable(SpamList)
                end
                if punishCount == 1 then
                    expiration =  now + 300
                    punishTime = "5 minutes"
                elseif punishCount == 2 then
                    expiration = now + 3600
                    punishTime = "1 hour"
                else
                    expiration = 0
                    punishTime = "permanent"
                end
                if newEntry ~= false then
                    spamData[steamID] = {}
                    spamData[steamID].steamID = steamID
                    spamData[steamID].punishcount = punishCount
                    table.insert(spamData, spamData[steamID])
                    datafile.SaveDataTable(SpamList)
                end
                muteData[steamID] = {}
                muteData[steamID].steamID = steamID
                muteData[steamID].expiration = expiration
                table.insert(muteData, muteData[steamID])
                datafile.SaveDataTable(MuteList)
                AntiSpam[steamID] = nil
                return true, punishTime
            else
                AntiSpam[steamID].timestamp = now
                AntiSpam[steamID].msgcount = 1
                return false, false
            end
        end
    else
        AntiSpam[steamID] = {}
        AntiSpam[steamID].timestamp = now
        AntiSpam[steamID].msgcount = 1
        return false, false
    end
end
-- --------------------------------
-- parses the chat
-- returns (bool)canChat, (string)msg, (string)errorMsg, (string)errorPrefix
-- --------------------------------
function PLUGIN:ParseChat(player, msg)
    local msg = tostring(msg)
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then return true, msg, false, false end
    -- Check player specific mute
    local isMuted, timeMuted = self:CheckMute(steamID)
    if isMuted then
        if not timeMuted then
            return false, msg, langString.PlayerNotifications["IsMuted"], "[MUTED]"
        else
            return false, msg, buildOutput(langString.PlayerNotifications["IsTimeMuted"], {"{timeMuted}"}, {timeMuted}), "[MUTED]"
        end
    end
    -- Check global mute
    if GlobalMute and not HasPermission(player, self.Config.Settings.Permissions.AntiGlobalMute) then
        return false, msg, langString.PlayerNotifications["GlobalMuted"], "[MUTED]"
    end
    -- Check for server advertisements
    if self.Config.Settings.General.BlockServerAds == "true" then
        local ipCheck
        local ipString = ""
        local chunks = {string.match(msg, "(%d+)%.(%d+)%.(%d+)%.(%d+)") }
        if #chunks == 4 then
            for _,v in pairs(chunks) do
                if tonumber(v) < 0 or tonumber(v) > 255 then
                    ipCheck = false
                    break
                end
                ipString = ipString..v.."."
                ipCheck = true
            end
            -- remove the last dot
            if string.sub(ipString, -1) == "." then
                ipString = string.sub(ipString, 1, -2)
            end
        else
            ipCheck = false
        end
        if ipCheck then
            local allowedIP = false
            for key, value in pairs(self.Config.Settings.General.AllowedIPsToPost) do
                if string.match(self.Config.Settings.General.AllowedIPsToPost[key], ipString) then
                    allowedIP = true
                end
            end
            if not allowedIP then
                return false, msg, langString.PlayerNotifications["AdWarning"], "[BLOCKED]"
            end
        end
    end
    -- Check for blacklisted words
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, last = string.find(string.lower(msg), string.lower(key), nil, true)
            if first then
                while first do
                    local before = string.sub(msg, 1, first - 1)
                    local after = string.sub(msg, last + 1)
                    -- replace whole word if parts are blacklisted
                    if self.Config.Settings.Wordfilter.ReplaceFullWord == "true" then
                        if string.sub(before, -1) ~= " " and string.len(before) > 0 then
                            local spaceStart, spaceEnd = string.find(string.reverse(before), " ")
                            if spaceStart then
                                before = string.reverse(string.sub(before, spaceStart + 1))
                            else
                                before = ""
                            end
                        end
                        if string.sub(after, 1, 1) ~= " " and string.len(after) > 0 then
                            local spaceStart, spaceEnd = string.find(after, " ")
                            if spaceStart then
                                after = string.sub(after, spaceStart)
                            else
                                after = ""
                            end
                        end
                    end
                    msg = before..value..after
                    first, last = string.find(string.lower(msg), string.lower(key), nil, true)
                end
            end
        end
    end
    -- show dem sneaky color tags
    msg = string.gsub(msg, "<[cC][oO][lL][oO][rR]", "<\\color\\")
    msg = string.gsub(msg, "[cC][oO][lL][oO][rR]>", "\\color\\>")
    return true, msg, false, false
end
-- --------------------------------
-- builds username and chatmessage
-- returns (string)username, (string)message
-- --------------------------------
function PLUGIN:BuildNameMessage(player, msg)
    local username, logUsername = player.displayName, player.displayName
    local message, logMessage = msg, msg
    local steamID = rust.UserIDFromPlayer(player)
    local foundPerm = false
    if AdminMode[steamID] then
        if self.Config.Settings.AdminMode.ReplaceChatName == "true" then
            username = "<color="..self.Config.Settings.NameColor.AdminMode..">"..self.Config.Settings.AdminMode.AdminChatName.."</color>"
            message = "<color="..self.Config.Settings.NameColor.AdminMode..">"..message.."</color>"
            logUsername = self.Config.Settings.AdminMode.AdminChatName
            logMessage = msg
            return username, message, logUsername, logMessage
        else
            username = "<color="..self.Config.Settings.NameColor.AdminMode..">"..username.."</color>"
            message = "<color="..self.Config.Settings.NameColor.AdminMode..">"..message.."</color>"
            logUsername = self.Config.Settings.AdminMode.AdminChatName
            logMessage = msg
            return username, message, logUsername, logMessage
        end
    end
    if self.Config.Settings.Groups.EnableGroups == "true" then
        for key, value in pairs(self.Config.ChatGroups) do
            if permission.UserHasPermission(steamID, self.Config.ChatGroups[key].Permission) then
                if self.Config.ChatGroups[key].ShowPrefix == true then
                    if self.Config.Settings.Groups.PrefixPosition == "left" then
                        username = self.Config.ChatGroups[key].Prefix.." "..username
                        logUsername = self.Config.ChatGroups[key].Prefix.." "..logUsername
                    else
                        username = username.." "..self.Config.ChatGroups[key].Prefix
                        logUsername = logUsername.." "..self.Config.ChatGroups[key].Prefix
                    end
                end
                if self.Config.ChatGroups[key].ShowColor then
                    if self.Config.Settings.Groups.ColorNamesOnly == "true" then
                        username = "<color="..self.Config.ChatGroups[key].Color..">"..username.."</color>"
                    else
                        username = "<color="..self.Config.ChatGroups[key].Color..">"..username.."</color>"
                        message = "<color="..self.Config.ChatGroups[key].Color..">"..message.."</color>"
                    end
                else
                    username = "<color="..self.Config.Settings.NameColor.NormalUser..">"..username.."</color>"
                end
                foundPerm = true
            end
        end
    end
    if not foundPerm then
        username = "<color="..self.Config.Settings.NameColor.NormalUser..">"..username.."</color>"
    end
    -- Add title if plugin RanksAndTitles is installed
    if exRanksAndTitles then
        local title = exRanksAndTitles:Call("grabPlayerData", steamID, "Title")
        local hideTitle = exRanksAndTitles:Call("grabPlayerData", steamID, "hidden")
        local colorOn = exRanksAndTitles.Config.Settings.colorSupport
        local color = exRanksAndTitles:Call("getColor", steamID)
        if not hideTitle and title ~= "" and colorOn then
            username = username.."<color="..color.."> ["..title.."]</color>"
            logUsername = logUsername.." ["..title.."]"
        end
        if not hideTitle and title ~= "" and not colorOn then
            if string.sub(username, -8) == "</color>" then
                username = string.sub(username, 1, -9).." ["..title.."]</color>"
                logUsername = logUsername.." ["..title.."]"
            else
                username = username.." ["..title.."]"
                logUsername = logUsername.." ["..title.."]"
            end
        end
    end
    return username, message, logUsername, logMessage
end
-- --------------------------------
-- sends and logs chat messages
-- --------------------------------
function PLUGIN:SendChat(player, name, msg, logName, logMsg)
    local steamID = rust.UserIDFromPlayer(player)
    -- Broadcast chat ingame
    self:BroadcastChat(player, name, msg)
    -- Log chat to console
    global.ServerConsole.PrintColoured(System.ConsoleColor.DarkYellow, logName..": ", System.ConsoleColor.DarkGreen, logMsg)
    -- Log chat to Rusty chat stream
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({"[CHAT] "..logName..": "..logMsg}))
    -- Log chat to log file
    global.server.Log("Log.Chat.txt", steamID.."/"..logName..": "..logMsg.."\n")
    -- Log chat history
    if self.Config.Settings.General.EnableChatHistory == "true" then
        self:InsertHistory(name, steamID, msg)
    end
end
-- --------------------------------
-- remove data on disconnect
-- --------------------------------
function PLUGIN:OnPlayerDisconnected(player)
    local steamID = rust.UserIDFromPlayer(player)
    AntiSpam[steamID] = nil
    AdminMode[steamID] = nil
end
-- --------------------------------
-- handles chat command for chat history
-- --------------------------------
function PLUGIN:cmdHistory(player)
    if #ChatHistory > 0 then
        rust.SendChatMessage(player, "ChatHistory", "----------")
        local i = 1
        while ChatHistory[i] do
            rust.SendChatMessage(player, ChatHistory[i].name, ChatHistory[i].msg, ChatHistory[i].steamID)
            i = i + 1
        end
        rust.SendChatMessage(player, "ChatHistory", "----------")
    else
        rust.SendChatMessage(player, "ChatHistory", langString.PlayerNotifications["NoChatHistory"])
    end
end
-- --------------------------------
-- inserts chat messages into history
-- --------------------------------
function PLUGIN:InsertHistory(name, steamID, msg)
    if #ChatHistory == self.Config.Settings.General.ChatHistoryMaxLines then
        table.remove(ChatHistory, 1)
    end
    table.insert(ChatHistory, {["name"] = name, ["steamID"] = steamID, ["msg"] = msg})
end
-- --------------------------------
-- handles chat command /wordfilter
-- --------------------------------
function PLUGIN:cmdEditWordFilter(player, cmd, args)
    local args = self:ArgsToTable(args, "chat")
    local func, word, replacement = args[1], args[2], args[3]
    if not func or func ~= "add" and func ~= "remove" and func ~= "list" then
        if not HasPermission(player, self.Config.Settings.Permissions.EditWordFilter) then
            rust.SendChatMessage(player, "Syntax /wordfilter list")
        else
            rust.SendChatMessage(player, "Syntax: /wordfilter add <word> <replacement> or /wordfilter remove <word>")
        end
        return
    end
    if func ~= "list" and not HasPermission(player, self.Config.Settings.Permissions.EditWordFilter) then
        rust.SendChatMessage(player, langString.AdminNotifications["NoPermission"])
        return
    end
    if func == "add" then
        if not replacement then
            rust.SendChatMessage(player, "Syntax: /wordfilter add <word> <replacement>")
            return
        end
        local first, last = string.find(string.lower(replacement), string.lower(word))
        if first then
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["WordfilterError"], {"{replacement}", "{word}"}, {replacement, word}))
            return
        else
            self.Config.WordFilter[word] = replacement
            self:SaveConfig()
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["WordfilterAdded"], {"{word}", "{replacement}"}, {word, replacement}))
        end
        return
    end
    if func == "remove" then
        if not word then
            rust.SendChatMessage(player, "Syntax: /wordfilter remove <word>")
            return
        end
        if self.Config.WordFilter[word] then
            self.Config.WordFilter[word] = nil
            self:SaveConfig()
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["WordfilterRemoved"], {"{word}"}, {word}))
        else
            rust.SendChatMessage(player, buildOutput(langString.AdminNotifications["WordfilterNotFound"], {"{word}"}, {word}))
        end
        return
    end
    if func == "list" then
        local wordFilterList = ""
        for key, _ in pairs(self.Config.WordFilter) do
            wordFilterList = wordFilterList..key..", "
        end
        rust.SendChatMessage(player, buildOutput(langString.PlayerNotifications["WordfilterList"], {"{wordFilterList}"}, {wordFilterList}))
    end
end
-- --------------------------------
-- handles chat command /help
-- --------------------------------
function PLUGIN:SendHelpText(player)
    if self.Config.Settings.General.EnableChatHistory == "true" then
        rust.SendChatMessage(player, langString.HelpText["ChatHistory"])
    end
    if self.Config.Settings.Wordfilter.EnableWordfilter== "true" then
        rust.SendChatMessage(player, langString.HelpText["Wordfilter"])
    end
end

