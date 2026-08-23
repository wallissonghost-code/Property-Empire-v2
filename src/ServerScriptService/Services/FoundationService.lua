local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuseumConfig = require(ReplicatedStorage.Shared.MuseumConfig)

local FoundationService = {}
local started = false

local function ratingFrom(profile, score)
	local visits = profile.Stats.Visits or 0
	local xp = profile.Museum.RatingXP or 0
	local base = 1 + math.min(2.6, score / 180)
	local visitBonus = math.min(0.8, visits / 500)
	local xpBonus = math.min(0.6, xp / 1000)
	return math.clamp(base + visitBonus + xpBonus, 1, 5)
end

local function syncPlayer(player, dataService, museumService)
	local profile = dataService:Get(player)
	if not profile then return end
	local score = museumService:GetScore(player)
	local stars = MuseumConfig.GetStars(score)
	local rating = ratingFrom(profile, score)
	player:SetAttribute("Prestige", score)
	player:SetAttribute("MuseumStars", stars)
	player:SetAttribute("MuseumRating", math.floor(rating * 10 + 0.5) / 10)
	player:SetAttribute("MuseumLevel", profile.Museum.Level)
	player:SetAttribute("MuseumVisits", profile.Stats.Visits or 0)
	player:SetAttribute("MuseumRevenue", profile.Stats.VisitorRevenue or 0)
end

function FoundationService:Start(dataService, museumService)
	if started then return end
	started = true

	local function setup(player)
		task.spawn(function()
			if dataService:Wait(player, 15) then
				while player.Parent do
					syncPlayer(player, dataService, museumService)
					task.wait(2)
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in ipairs(Players:GetPlayers()) do setup(player) end
	print("[Museum Empire] FoundationService started — level, prestige, stars and rating")
end

return FoundationService
