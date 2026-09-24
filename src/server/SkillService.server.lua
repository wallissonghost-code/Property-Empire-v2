local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local purchaseRemote = Instance.new("RemoteEvent")
purchaseRemote.Name = "SkillPurchaseRequest"
purchaseRemote.Parent = ReplicatedStorage

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "SkillState"
stateRemote.Parent = ReplicatedStorage

local SKILL_ID = "LaserEyes"

local function sendState(player)
	stateRemote:FireClient(player, {
		laserEyes = player:GetAttribute("Skill_" .. SKILL_ID) == true,
	})
end

purchaseRemote.OnServerEvent:Connect(function(player, skillId)
	if skillId ~= SKILL_ID then return end
	-- Temporary R$0 test purchase. Persistence/payment will be added later.
	player:SetAttribute("Skill_" .. SKILL_ID, true)
	sendState(player)
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Skill_" .. SKILL_ID, false)
end)
