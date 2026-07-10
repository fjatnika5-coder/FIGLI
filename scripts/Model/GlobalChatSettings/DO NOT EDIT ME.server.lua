local module = require(script.Parent)

module.Chat_Event.Name = "OT_SERVER_CHAT_MSG_EVENT"
module.Chat_Event.Parent = game:GetService("ReplicatedStorage")

function colorText(text :string, color3 :Color3)
	return ('<font color="#%s">%s</font>'):format(color3:ToHex(), text)
end

while task.wait(module.MessageDelay) do
	local randomMsg = module.Messages[math.random(1, #module.Messages)]
	module.Chat_Event:FireAllClients(("%s %s"):format(colorText(module.Prefix, module.PrefixColor), colorText(randomMsg, module.MessageColor)))
end