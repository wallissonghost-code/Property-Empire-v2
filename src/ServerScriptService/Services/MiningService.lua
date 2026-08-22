local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.Shared.ArtifactCatalog)
local GameConfig=require(ReplicatedStorage.Shared.GameConfig)

local MiningService={}
local started=false
local lastMine={}
local rng=Random.new()

function MiningService:Start(dataService,worldService,museumService)
	if started then return end started=true
	local remotes=ReplicatedStorage:WaitForChild("MuseumRemotes")
	local nodes=worldService:GetMineNodes()
	for _,node in ipairs(nodes:GetChildren()) do
		if node:IsA("BasePart") and node.Name:match("MineNode") then
			local prompt=Instance.new("ProximityPrompt") prompt.ActionText="Minerar" prompt.ObjectText="Veio mineral" prompt.HoldDuration=0.7 prompt.MaxActivationDistance=12 prompt.Parent=node
			prompt.Triggered:Connect(function(player)
				local now=os.clock() local previous=lastMine[player] or 0
				if now-previous<GameConfig.MiningCooldown then remotes.MuseumToast:FireClient(player,"Aguarde a frente de mineração esfriar") return end
				lastMine[player]=now
				local id,spec=Catalog.Roll(rng)
				local ok,err=museumService:AddArtifact(player,id)
				if not ok then remotes.MuseumToast:FireClient(player,err) return end
				local p=dataService:Get(player) if p then p.Stats.Mined+=1 end
				dataService:Save(player)
				remotes.MuseumToast:FireClient(player,string.format("ACHADO: %s · %s · valor estimado $%d",spec.Name,spec.Rarity,spec.Value))
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(p) lastMine[p]=nil end)
	print("[Museum Empire] MiningService started")
end

return MiningService
