local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local purchaseRemote = Instance.new("RemoteEvent")
purchaseRemote.Name = "SkillPurchaseRequest"
purchaseRemote.Parent = ReplicatedStorage

local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "SkillState"
stateRemote.Parent = ReplicatedStorage

local SKILL_ID = "LaserEyes"
local ATTRIBUTE = "Skill_" .. SKILL_ID
local STORE = DataStoreService:GetDataStore("PlayerSkills_v1")
local saveLocks = {}

local function keyFor(player)
	return "player_" .. player.UserId
end

local function sendState(player)
	stateRemote:FireClient(player, {
		laserEyes = player:GetAttribute(ATTRIBUTE) == true,
	})
end

local function loadSkills(player)
	player:SetAttribute(ATTRIBUTE, false)

	local success, data = pcall(function()
		return STORE:GetAsync(keyFor(player))
	end)
	if not player.Parent then return end

	if success and type(data) == "table" and data[SKILL_ID] == true then
		player:SetAttribute(ATTRIBUTE, true)
	end
	sendState(player)
end

local function saveLaserEyes(player)
	if saveLocks[player] then return end
	saveLocks[player] = true

	local success, err = pcall(function()
		STORE:UpdateAsync(keyFor(player), function(current)
			current = type(current) == "table" and current or {}
			current[SKILL_ID] = true
			return current
		end)
	end)

	saveLocks[player] = nil
	if not success then
		warn("Failed to persist LaserEyes for", player.UserId, err)
	end
end

purchaseRemote.OnServerEvent:Connect(function(player, skillId)
	if skillId ~= SKILL_ID then return end
	if player:GetAttribute(ATTRIBUTE) == true then
		sendState(player)
		return
	end

	-- Temporary R$0 acquisition. Ownership is permanent and server-persisted.
	player:SetAttribute(ATTRIBUTE, true)
	sendState(player)
	task.spawn(saveLaserEyes, player)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadSkills, player)
end)

Players.PlayerRemoving:Connect(function(player)
	if player:GetAttribute(ATTRIBUTE) == true then
		saveLaserEyes(player)
	end
	saveLocks[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(ATTRIBUTE) == true then
			saveLaserEyes(player)
		end
	end
end)
