PLUGIN.Title        = "Enhanced Ban System"
PLUGIN.Description  = "Ban system with advanced features"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(2, 3, 2)
PLUGIN.ResourceId   = 693

local debugMode = false


function PLUGIN:Init()
    self:LoadDataFile()
    self:LoadDefaultConfig()
    self:LoadCommands()
    self:RegisterPermissions()
end
local plugin_RustDB
function PLUGIN:OnServerInitialized()
    plugin_RustDB = plugins.Find("RustDB") or false
end
-- --------------------------------
-- Handle data files
-- --------------------------------
local DataFile = "ebsbanlist"
local BanData = {}
function PLUGIN:LoadDataFile()
    BanData = datafile.GetDataTable(DataFile) or {}
end
function PLUGIN:SaveDataFile()
    datafile.SaveDataTable(DataFile)
end
-- --------------------------------
-- Load the default configs
-- --------------------------------
function PLUGIN:LoadDefaultConfig()
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.BroadcastBans = self.Config.Settings.BroadcastBans or "false"
    self.Config.Settings.LogToConsole = self.Config.Settings.LogToConsole or "true"
    self.Config.Settings.CheckUsableByEveryone = self.Config.Settings.CheckUsableByEveryone or "false"
    self.Config.Settings.ChatName = self.Config.Settings.ChatName or "SERVER"
    -- Permission settings
    self.Config.Settings.Permissions = self.Config.Settings.Permissions or {}
    self.Config.Settings.Permissions.Ban = self.Config.Settings.Permissions.Ban or "canban"
    self.Config.Settings.Permissions.Kick = self.Config.Settings.Permissions.Kick or "cankick"
    self.Config.Settings.Permissions.BanCheck = self.Config.Settings.Permissions.BanCheck or "canbancheck"
    -- Messages
    self.Config.Messages = self.Config.Messages or {}
    self.Config.Messages.KickMessage = self.Config.Messages.KickMessage or "An admin kicked you for {reason}"
    self.Config.Messages.BanMessage = self.Config.Messages.BanMessage or "An admin banned you for {reason}"
    self.Config.Messages.DenyConnection = self.Config.Messages.DenyConnection or "You are banned on this server"
    self.Config.Messages.HelpText = self.Config.Messages.HelpText or "Use /bancheck to check if and for how long someone is abnned"
    self:SaveConfig()
end
-- --------------------------------
-- Load chat and console commands
-- --------------------------------
function PLUGIN:LoadCommands()
    command.AddChatCommand("ban", self.Object, "cmdBan")
    command.AddChatCommand("unban", self.Object, "cmdUnban")
    command.AddChatCommand("kick", self.Object, "cmdKick")
    command.AddChatCommand("bancheck", self.Object, "cmdBanCheck")
    command.AddConsoleCommand("player.ban", self.Object, "ccmdBan")
    command.AddConsoleCommand("player.unban", self.Object, "ccmdUnban")
    command.AddConsoleCommand("player.kick", self.Object, "ccmdKick")
    command.AddConsoleCommand("player.bancheck", self.Object, "ccmdBanCheck")
    command.AddConsoleCommand("ebs.debug", self.Object, "ccmdDebug")
end
-- --------------------------------
-- Register permissions
-- --------------------------------
function PLUGIN:RegisterPermissions()
    for _, perm in pairs(self.Config.Settings.Permissions) do
        if not permission.PermissionExists(perm) then
            permission.RegisterPermission(perm, self.Object)
        end
    end
end
-- --------------------------------
-- try to find a BasePlayer
-- returns (int) numFound, (table) playerTbl
-- --------------------------------
local function FindPlayer(NameOrIpOrSteamID, checkSleeper)
    local playerTbl = {}
    local enumPlayerList = global.BasePlayer.activePlayerList:GetEnumerator()
    while enumPlayerList:MoveNext() do
        local currPlayer = enumPlayerList.Current
        local currSteamID = rust.UserIDFromPlayer(currPlayer)
        local currIP = currPlayer.net.connection.ipaddress
        if currPlayer.displayName == NameOrIpOrSteamID or currSteamID == NameOrIpOrSteamID or currIP == NameOrIpOrSteamID then
            table.insert(playerTbl, currPlayer)
            return #playerTbl, playerTbl
        end
        local matched, _ = string.find(currPlayer.displayName:lower(), NameOrIpOrSteamID:lower(), 1, true)
        if matched then
            table.insert(playerTbl, currPlayer)
        end
    end
    if checkSleeper then
        local enumSleeperList = global.BasePlayer.sleepingPlayerList:GetEnumerator()
        while enumSleeperList:MoveNext() do
            local currPlayer = enumSleeperList.Current
            local currSteamID = rust.UserIDFromPlayer(currPlayer)
            if currPlayer.displayName == NameOrIpOrSteamID or currSteamID == NameOrIpOrSteamID then
                table.insert(playerTbl, currPlayer)
                return #playerTbl, playerTbl
            end
            local matched, _ = string.find(currPlayer.displayName:lower(), NameOrIpOrSteamID:lower(), 1, true)
            if matched then
                table.insert(playerTbl, currPlayer)
            end
        end
    end
    return #playerTbl, playerTbl
end
-- --------------------------------
-- prints to server console
-- --------------------------------
local function printToConsole(msg)
    global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, msg)
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
-- debug print
-- --------------------------------
local function debug(msg)
    if not debugMode then return end
    global.ServerConsole.PrintColoured(System.ConsoleColor.Yellow, msg)
end
-- --------------------------------
-- removes expired bans
-- --------------------------------
function PLUGIN:CleanUpBanList()
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(BanData) do
        if BanData[key].expiration < now and BanData[key].expiration ~= 0 then
            BanData[key] = nil
            self:SaveDataFile()
        end
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
-- handles chat command /ban
-- --------------------------------
function PLUGIN:cmdBan(player, _, args)
    local args = self:ArgsToTable(args, "chat")
    local target, reason, duration = args[1], args[2], args[3]
    local perm = self.Config.Settings.Permissions.Ban
    if not HasPermission(player, perm) then
        rust.SendChatMessage(player, "You dont have permission to use this command")
        return
    end
    if not reason then
        rust.SendChatMessage(player, "Syntax: /ban <name|steamID|ip> <reason> <time[m|h|d] (optional)>")
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, true)
    if numFound == 0 then
        rust.SendChatMessage(player, "Player not found")
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        rust.SendChatMessage(player, "Found more than one player, be more specific:")
        rust.SendChatMessage(player, targetNameString)
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Ban(player, targetPlayer, reason, duration, nil)
end
-- --------------------------------
-- handles console command player.ban
-- --------------------------------
function PLUGIN:ccmdBan(arg)
    local player, F1Console
    local perm = self.Config.Settings.Permissions.Ban
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if F1Console and not HasPermission(player, perm) then
        arg:ReplyWith("You dont have permission to use this command")
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target, reason, duration = args[1], args[2], args[3]
    if not reason then
        if F1Console then
            arg:ReplyWith("Syntax: player.ban <name|steamID|ip> <reason> <time[m|h|d] (optional)>")
        else
            printToConsole("Syntax: player.ban <name|steamID|ip> <reason> <time[m|h|d] (optional)>")
        end
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, true)
    if numFound == 0 then
        if F1Console then
            arg:ReplyWith("Player not found")
        else
            printToConsole("Player not found")
        end
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        if F1Console then
            arg:ReplyWith("Found more than one player, be more specific:")
            for i = 1, numFound do
                arg:ReplyWith(targetPlayerTbl[i].displayName)
            end
        else
            printToConsole("Found more than one player, be more specific:")
            for i = 1, numFound do
                printToConsole(targetPlayerTbl[i].displayName)
            end
        end
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Ban(player, targetPlayer, reason, duration, arg)
end
-- --------------------------------
-- handles chat command /unban
-- --------------------------------
function PLUGIN:cmdUnban(player, _, args)
    local args = self:ArgsToTable(args, "chat")
    local target = args[1]
    local perm = self.Config.Settings.Permissions.Ban
    if not HasPermission(player, perm) then
        rust.SendChatMessage(player, "You dont have permission to use this command")
        return
    end
    if not target then
        rust.SendChatMessage(player, "Syntax: /unban <name|steamID|ip>")
        return
    end
    self:UnBan(player, target, nil)
end
-- --------------------------------
-- handles console command player.unban
-- --------------------------------
function PLUGIN:ccmdUnban(arg)
    local player, F1Console
    local perm = self.Config.Settings.Permissions.Ban
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if player and not HasPermission(player, perm) then
        arg:ReplyWith("You dont have permission to use this command")
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target = args[1]
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: player.unban <name|steamID|ip>")
        else
            printToConsole("Syntax: player.unban <name|steamID|ip>")
        end
        return
    end
    self:UnBan(player, target, arg)
end
-- --------------------------------
-- handles chat command /kick
-- --------------------------------
function PLUGIN:cmdKick(player, _, args)
    local args = self:ArgsToTable(args, "chat")
    local target, reason = args[1], args[2]
    local perm = self.Config.Settings.Permissions.Kick
    if not HasPermission(player, perm) then
        rust.SendChatMessage(player, "You dont have permission to use this command")
        return
    end
    if not reason then
        rust.SendChatMessage(player, "Syntax: /kick <name|steamID|ip> <reason>")
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        rust.SendChatMessage(player, "Player not found")
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        rust.SendChatMessage(player, "Found more than one player, be more specific:")
        rust.SendChatMessage(player, targetNameString)
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Kick(player, targetPlayer, reason, nil)
end
-- --------------------------------
-- handles console command player.kick
-- --------------------------------
function PLUGIN:ccmdKick(arg)
    local player, F1Console
    local perm = self.Config.Settings.Permissions.Kick
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if F1Console and not HasPermission(player, perm) then
        arg:ReplyWith("You dont have permission to use this command")
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target, reason = args[1], args[2]
    if not reason then
        if F1Console then
            arg:ReplyWith("Syntax: player.kick <name|steamID|ip> <reason>")
        else
            printToConsole("Syntax: player.kick <name|steamID|ip> <reason>")
        end
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        if F1Console then
            arg:ReplyWith("Player not found")
        else
            printToConsole("Player not found")
        end
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        if F1Console then
            arg:ReplyWith("Found more than one player, be more specific:")
            for i = 1, numFound do
                arg:ReplyWith(targetPlayerTbl[i].displayName)
            end
        else
            printToConsole("Found more than one player, be more specific:")
            for i = 1, numFound do
                printToConsole(targetPlayerTbl[i].displayName)
            end
        end
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Kick(player, targetPlayer, reason, arg)
end
-- --------------------------------
-- handles chat command /bancheck
-- --------------------------------
function PLUGIN:cmdBanCheck(player, _, args)
    debug("## [EBS debug] cmdBanCheck() ##")
    local args = self:ArgsToTable(args, "chat")
    local perm = self.Config.Settings.Permissions.BanCheck
    local target = args[1]
    debug("perm: "..perm)
    debug("target: "..target)
    if not HasPermission(player, perm) and self.Config.Settings.CheckUsableByEveryone == "false" then
        rust.SendChatMessage(player, "You dont have permission to use this command")
        return
    end
    if not target then
        rust.SendChatMessage(player, "Syntax: /bancheck <name|steamID|ip>")
        return
    end
    self:BanCheck(player, target, nil)
end
-- --------------------------------
-- handles console command player.bancheck
-- --------------------------------
function PLUGIN:ccmdBanCheck(arg)
    debug("## [EBS debug] ccmdBanCheck() ##")
    local player, F1Console
    local perm = self.Config.Settings.Permissions.Kick
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    local args = self:ArgsToTable(arg, "console")
    local target = args[1]
    debug("perm: "..perm)
    debug("target: "..target)
    if F1Console and not HasPermission(player, perm) and self.Config.Settings.CheckUsableByEveryone == "false" then
        arg:ReplyWith("You dont have permission to use this command")
        return
    end
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: /bancheck <name|steamID|ip>")
        else
            printToConsole("Syntax: /bancheck <name|steamID|ip>")
        end
        return
    end
    self:BanCheck(player, target, arg)
end
-- --------------------------------
-- checks if target is banned
-- --------------------------------
function PLUGIN:BanCheck(player, target, arg)
    debug("## [EBS debug] BanCheck() ##")
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    debug("F1Console: "..tostring(F1Console))
    debug("srvConsole: "..tostring(srvConsole))
    debug("chatCmd: "..tostring(chatCmd))
    --
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(BanData) do
        if BanData[key].name == target or BanData[key].steamID == target or BanData[key].IP == target then
            if BanData[key].expiration > now or BanData[key].expiration == 0 then
                if BanData[key].expiration == 0 then
                    if F1Console then
                        arg:ReplyWith(target.." is permanently banned")
                    end
                    if srvConsole then
                        printToConsole(target.." is permanently banned")
                    end
                    if chatCmd then
                        rust.SendChatMessage(player, target.." is permanently banned")
                    end
                    return
                else
                    local expiration = BanData[key].expiration
                    local bantime = expiration - now
                    local days = tostring(math.floor(bantime / 86400)):format("%02.f")
                    local hours = tostring(math.floor(bantime / 3600 - (days * 24))):format("%02.f")
                    local minutes = tostring(math.floor(bantime / 60 - (days * 1440) - (hours * 60))):format("%02.f")
                    local seconds = tostring(math.floor(bantime - (days * 86400) - (hours * 3600) - (minutes * 60))):format("%02.f")
                    if F1Console then
                        arg:ReplyWith(target.." is banned for "..tostring(days).." days "..tostring(hours).." hours "..tostring(minutes).." minutes "..tostring(seconds).." seconds")
                    end
                    if srvConsole then
                        printToConsole(target.." is banned for "..tostring(days).." days "..tostring(hours).." hours "..tostring(minutes).." minutes "..tostring(seconds).." seconds")
                    end
                    if chatCmd then
                        rust.SendChatMessage(player, target.." is banned for "..tostring(days).." days "..tostring(hours).." hours "..tostring(minutes).." minutes "..tostring(seconds).." seconds")
                    end
                    return
                end
            end
        end
    end
    if F1Console then
        arg:ReplyWith(target.." is not banned")
    end
    if srvConsole then
        printToConsole(target.." is not banned")
    end
    if chatCmd then
        rust.SendChatMessage(player, target.." is not banned")
    end
end
-- --------------------------------
-- kick player
-- --------------------------------
function PLUGIN:Kick(player, targetPlayer, reason, arg)
    debug("## [EBS debug] Kick() ##")
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    local targetInfo = targetName.." ("..targetSteamID..")"
    debug("targetName: "..targetName)
    debug("targetSteamID: "..targetSteamID)
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    debug("F1Console: "..tostring(F1Console))
    debug("srvConsole: "..tostring(srvConsole))
    debug("chatCmd: "..tostring(chatCmd))
    -- Kick player
    local kickMsg = string.gsub(self.Config.Messages.KickMessage, "{reason}", reason)
    Network.Net.sv:Kick(targetPlayer.net.connection, kickMsg)
    -- Output the bans
    if self.Config.Settings.BroadcastBans == "true" then
        rust.BroadcastChat(self.Config.Settings.ChatName, targetName.." has been kicked for "..reason)
    end
    if chatCmd and self.Config.Settings.BroadcastBans == "false" then
        rust.SendChatMessage(player, targetName.." has been kicked for "..reason)
    end
    if F1Console then
        arg:ReplyWith(targetName.." has been kicked for "..reason)
    end
    if srvConsole then
        printToConsole(targetName.." has been kicked for "..reason)
    end
    if self.Config.Settings.LogToConsole == "true" then
        if player then
            printToConsole("[EBS]: "..player.displayName.." kicked "..targetInfo)
        else
            printToConsole("[EBS]: Admin kicked "..targetInfo)
        end
    end
end
-- --------------------------------
-- unban player
-- --------------------------------
function PLUGIN:UnBan(player, target, arg)
    debug("## [EBS debug] UnBan() ##")
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    debug("F1Console: "..tostring(F1Console))
    debug("srvConsole: "..tostring(srvConsole))
    debug("chatCmd: "..tostring(chatCmd))
    --
    debug("target: "..tostring(target))
    for key, _ in pairs(BanData) do
        if BanData[key].name == target or BanData[key].steamID == target or BanData[key].IP == target then
            debug("ban found")
            -- Send unban request to RustDB
            if plugin_RustDB then
                debug("RustDB found")
                plugin_RustDB:Call("RustDBUnban", BanData[key].steamID)
            end
            -- remove from banlist
            BanData[key].name = nil
            BanData[key].steamID = nil
            BanData[key].IP = nil
            BanData[key].expiration = nil
            BanData[key].reason = nil
            BanData[key] = nil
            debug("ban entry deleted: "..tostring(BanData[key] == nil))
            self:SaveDataFile()
            -- Output the bans
            if self.Config.Settings.BroadcastBans == "true" then
                rust.BroadcastChat(self.Config.Settings.ChatName, target.." has been unbanned")
            end
            if chatCmd then
                rust.SendChatMessage(player, target.." has been unbanned")
            end
            if F1Console then
                arg:ReplyWith(target.." has been unbanned")
            end
            if srvConsole then
                printToConsole(target.." has been unbanned")
            end
            if self.Config.Settings.LogToConsole == "true" then
                if player then
                    printToConsole("[EBS]: "..player.displayName.." unbanned "..target)
                else
                    printToConsole("[EBS]: Admin unbanned "..target)
                end
            end
            return
        end
    end
    if chatCmd then
        rust.SendChatMessage(player, target.." not found in banlist")
    end
    if F1Console then
        arg:ReplyWith(target.." not found in banlist")
    end
    if srvConsole then
        printToConsole(target.." not found in banlist")
    end
end
-- --------------------------------
-- ban player
-- --------------------------------
function PLUGIN:Ban(player, targetPlayer, reason, duration, arg)
    debug("## [EBS debug] Ban() ##")
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    debug("F1Console: "..tostring(F1Console))
    debug("srvConsole: "..tostring(srvConsole))
    debug("chatCmd: "..tostring(chatCmd))
    --
    local targetName = targetPlayer.displayName
    local targetOffline = targetPlayer.net.connection == nil
    debug("targetOffline: "..tostring(targetOffline))
    local targetIP
    if targetOffline then
        targetIP = "0.0.0.0"
    else
        targetIP = targetPlayer.net.connection.ipaddress:match("([^:]*):")
    end
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    debug("targetName: "..targetName)
    debug("targetIP: "..tostring(targetIP))
    debug("targetSteamID: "..targetSteamID)
    -- Check if player is already banned
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(BanData) do
        if BanData[key].steamID == targetSteamID then
            if BanData[key].expiration > now or BanData[key].expiration == 0 then
                debug("player already banned")
                if chatCmd then
                    rust.SendChatMessage(player, targetName.." is already banned!")
                end
                if F1Console then
                    arg:ReplyWith(targetName.." is already banned!")
                end
                if srvConsole then
                    printToConsole(targetName.." is already banned!")
                end
                return
            else
                self:CleanUpBanList()
            end
        end
    end
    if not duration then -- If no time is given ban permanently
        debug("no duration")
        local expiration = 0
        -- Insert data into the banlist
        BanData[targetSteamID] = {}
        BanData[targetSteamID].steamID = targetSteamID
        BanData[targetSteamID].name = targetName
        BanData[targetSteamID].expiration = expiration
        BanData[targetSteamID].IP = targetIP
        BanData[targetSteamID].reason = reason
        table.insert(BanData, BanData[targetSteamID])
        self:SaveDataFile()
        debug("ban entry saved to file")
        -- Send ban to RustDB
        if plugin_RustDB then
            debug("RustDB found")
            plugin_RustDB:Call("RustDBBan", player, targetName, targetSteamID, reason)
        end
        -- Kick target from server
        local BanMsg = self.Config.Messages.BanMessage:gsub("{reason}", reason)
        if not targetOffline then
            Network.Net.sv:Kick(targetPlayer.net.connection, BanMsg)
            debug("targetPlayer kicked")
        end
        -- Output bans
        if self.Config.Settings.BroadcastBans == "true" then
            rust.BroadcastChat(self.Config.Settings.ChatName, targetName.." has been permanently banned")
        end
        if chatCmd then
            rust.SendChatMessage(player, targetName.." has been permanently banned")
        end
        if F1Console then
            arg:ReplyWith(targetName.." has been permanently banned")
        end
        if srvConsole then
            printToConsole(targetName.." has been permanently banned")
        end
        if self.Config.Settings.LogToConsole == "true" then
            if player then
                printToConsole("[EBS]: "..player.displayName.." permanently banned "..targetName.." for "..reason)
            else
                printToConsole("[EBS]: Admin permanently banned "..targetName.." for "..reason)
            end
        end
    else -- if time is given, ban for time
        debug("duration: "..duration)
        -- Check if time input is a valid format
        if duration:len() < 2 or not duration:match("^%d*[mhd]$") then
            debug("invalid time format")
            if chatCmd then
                rust.SendChatMessage(player, "Invalid time format")
            end
            if F1Console then
                arg:ReplyWith("Invalid time format")
            end
            if srvConsole then
                printToConsole("Invalid time format")
            end
            return
        end
        -- Build time format
        local now = time.GetUnixTimestamp()
        local banTime = tonumber(duration:sub(1, -2))
        local timeUnit = duration:sub(-1)
        local timeMult, timeUnitLong
        if timeUnit == "m" then
            timeMult = 60
            timeUnitLong = "minutes"
        elseif timeUnit == "h" then
            timeMult = 3600
            timeUnitLong = "hours"
        elseif timeUnit == "d" then
            timeMult = 86400
            timeUnitLong = "days"
        end
        local expiration = now + (banTime * timeMult)
        -- Insert data into the banlist
        BanData[targetSteamID] = {}
        BanData[targetSteamID].steamID = targetSteamID
        BanData[targetSteamID].name = targetName
        BanData[targetSteamID].expiration = expiration
        BanData[targetSteamID].IP = targetIP
        BanData[targetSteamID].reason = reason
        table.insert(BanData, BanData[targetSteamID])
        debug("ban entry saved to fiile")
        self:SaveDataFile()
        -- Kick target from server
        local BanMsg = self.Config.Messages.BanMessage:gsub("{reason}", reason)
        if not targetOffline then
            Network.Net.sv:Kick(targetPlayer.net.connection, BanMsg)
            debug("targetPlayer kicked")
        end
        -- Output bans
        if self.Config.Settings.BroadcastBans == "true" then
            rust.BroadcastChat(self.Config.Settings.ChatName, targetName.." has been banned for "..banTime.." "..timeUnitLong)
        end
        if chatCmd then
            rust.SendChatMessage(player, targetName.." has been banned for "..banTime.." "..timeUnitLong)
        end
        if F1Console then
            arg:ReplyWith(targetName.." has been banned for "..banTime.." "..timeUnitLong)
        end
        if srvConsole then
            printToConsole(targetName.." has been banned for "..banTime.." "..timeUnitLong)
        end
        if self.Config.Settings.LogToConsole == "true" then
            if player then
                printToConsole("[EBS]: "..player.displayName.." banned "..targetName.." for "..banTime.." "..timeUnitLong.." for "..reason)
            else
                printToConsole("[EBS]: Admin banned "..targetName.." for "..banTime.." "..timeUnitLong.." for "..reason)
            end
        end
    end
end
-- --------------------------------
-- checks for ban on player connects
-- --------------------------------
function PLUGIN:CanClientLogin(connection)
    local steamID = rust.UserIDFromConnection(connection)
    local ip = connection.ipaddress:match("([^:]*):")
    local name = connection.username
    local userInfo = name.." ("..steamID..")"
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(BanData) do
        if BanData[key].steamID == steamID or BanData[key].IP == ip then
            if BanData[key].expiration < now and BanData[key].expiration ~= 0 then
                self:CleanUpBanList()
                return
            else
                debug(userInfo.." connection denied")
                if self.Config.Settings.LogToConsole == "true" then
                    printToConsole("[EBS]: "..userInfo.." connection denied")
                end
                return self.Config.Messages.DenyConnection
            end
        else
            if BanData[key].name == name then
                printToConsole("[EBS]: Warning! the name from "..userInfo.." has been banned but is using another steam account now!")
                printToConsole("[EBS]: It might be the same person with another account or just someone else with the same name. Judge it by yourself")
            end
        end
    end
end
-- --------------------------------
-- activate/deactivate debug mode
-- --------------------------------
function PLUGIN:ccmdDebug(arg)
    if arg.connection then return end -- terminate if not server console
    local args = self:ArgsToTable(arg, "console")
    if args[1] == "true" then
        debugMode = true
        printToConsole("[EBS]: debug mode activated")
    elseif args[1] == "false" then
        debugMode = false
        printToConsole("[EBS]: debug mode deactivated")
    else
        printToConsole("Syntax: ebs.debug true/false")
    end
end
-- --------------------------------
-- sends helptext when /help is used
-- --------------------------------
function PLUGIN:SendHelpText(player)
    if self.Config.Settings.CheckUsableByEveryone == "true" then
        rust.SendChatMessage(player, self.Config.Messages.HelpText)
    end
end