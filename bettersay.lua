PLUGIN.Title       = "Better Say"
PLUGIN.Description = "Customize the output of the say console command."
PLUGIN.Author      = "LaserHydra"
PLUGIN.Version     = V(1, 0, 3)
PLUGIN.ResourceId  = 998

function PLUGIN:Init()
    self:LoadDefaultConfig()
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Prefix = self.Config.Prefix or "SERVER CONSOLE"
    self.Config.PrefixColor = self.Config.PrefixColor or "orange"
    self.Config.PrefixSize = self.Config.PrefixSize or "20"
    self.Config.TextColor = self.Config.TextColor or "white"
    self.Config.TextSize = self.Config.TextSize or "20"
end

function PLUGIN:OnRunCommand(arg)
	if not arg then return end
    if not arg.cmd then return end
    if not arg.cmd.namefull then return end
    if arg.cmd.namefull == "global.say" then
		if not arg.connection or arg.connection.authLevel > 0 then
			local prefix = "<size=" .. self.Config.PrefixSize .. ">" .. "<color=" .. self.Config.PrefixColor .. ">" .. self.Config.Prefix .. "</color>" .. "</size>"
			local oldMessage = arg:GetString(0, "text")
			if oldMessage == "" then return false end
			local newMessage = "<size=" .. self.Config.TextSize .. ">" .."<color=" .. self.Config.TextColor .. ">" .. oldMessage .. "</color>" .. "</size>"
			rust.BroadcastChat(prefix, newMessage)
			print(self.Config.Prefix .. ": " .. oldMessage)
			return false
		end
	end
end