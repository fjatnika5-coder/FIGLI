-- Property Of @TheDranxX
local Revoke = require(game.ReplicatedStorage:WaitForChild("Repok")) -- definisiin reference nya
local part = Revoke.get("Workspace.PartContoh") -- pake API nya
if part then
	part.Transparency = 0.5
	print("Success")
else
	print("Gagal")
end

-- Property Of @TheDranxX