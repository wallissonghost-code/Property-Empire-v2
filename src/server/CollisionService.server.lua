local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local PLAYER_GROUP = "Players"
local MOB_GROUP = "Mobs"

pcall(function() PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(MOB_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, MOB_GROUP, false)

local function assignCharacter(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(assignCharacter)
	if player.Character then assignCharacter(player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do onPlayer(player) end

_G.AssignMobCollisionGroup = function(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = MOB_GROUP
		end
	end
end
