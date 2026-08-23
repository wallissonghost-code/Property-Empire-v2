local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuseumConfig = require(ReplicatedStorage.Shared.MuseumConfig)

local VisitorService = {}
local started = false
local rng = Random.new()
local activeByOwner = {}

local BODY_COLORS = {
	Color3.fromRGB(255, 204, 153),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(90, 55, 32),
}

local SHIRT_COLORS = {
	Color3.fromRGB(48, 87, 143),
	Color3.fromRGB(52, 120, 86),
	Color3.fromRGB(138, 64, 70),
	Color3.fromRGB(72, 72, 84),
	Color3.fromRGB(157, 118, 45),
	Color3.fromRGB(107, 71, 140),
}

local function chooseVisitorType(score)
	local eligible = {}
	local total = 0
	for _, spec in ipairs(MuseumConfig.VisitorTypes) do
		if score >= (spec.MinScore or 0) then
			total += spec.Weight
			table.insert(eligible, spec)
		end
	end
	local roll = rng:NextNumber(0, total)
	local cursor = 0
	for _, spec in ipairs(eligible) do
		cursor += spec.Weight
		if roll <= cursor then return spec end
	end
	return eligible[1]
end

local function tintRig(model)
	local skin = BODY_COLORS[rng:NextInteger(1, #BODY_COLORS)]
	local shirt = SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Head" or part.Name:find("Hand") or part.Name:find("Arm") then
				part.Color = skin
			elseif part.Name:find("Torso") then
				part.Color = shirt
			elseif part.Name:find("Leg") or part.Name:find("Foot") then
				part.Color = Color3.fromRGB(45, 48, 58)
			end
		end
	end
end

local function addNameplate(model, visitorType)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VisitorNameplate"
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 45
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(24, 28, 35)
	label.TextColor3 = visitorType.Id == "VIP" and Color3.fromRGB(255, 220, 112) or Color3.fromRGB(245, 247, 250)
	label.Text = visitorType.Name
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
end

local function createRobloxVisitor(parent, cf, visitorType)
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = "Visitor_" .. visitorType.Id
	model:SetAttribute("MuseumNPC", true)
	model:SetAttribute("VisitorType", visitorType.Id)
	model.Parent = parent
	tintRig(model)
	addNameplate(model, visitorType)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = MuseumConfig.VisitorWalkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.AutoRotate = true
	end
	model:PivotTo(cf)
	return model, humanoid
end

local function walkTo(model, humanoid, destination)
	if not model or not humanoid or humanoid.Health <= 0 then return false end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 5,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, destination.Position) end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(waypoint.Position)
			local reached = humanoid.MoveToFinished:Wait()
			if not reached then return false end
		end
		return true
	end
	humanoid:MoveTo(destination.Position)
	return humanoid.MoveToFinished:Wait()
end

local function randomInsidePoint(info)
	local floor = info.Model and info.Model:FindFirstChild("Floor")
	if not floor then return info.Inside end
	local x = rng:NextNumber(-math.max(2, floor.Size.X * 0.32), math.max(2, floor.Size.X * 0.32))
	local z = rng:NextNumber(-math.max(2, floor.Size.Z * 0.28), math.max(2, floor.Size.Z * 0.18))
	return floor.CFrame * CFrame.new(x, 2.8, z)
end

local function changeActive(owner, delta)
	activeByOwner[owner] = math.max(0, (activeByOwner[owner] or 0) + delta)
end

function VisitorService:Start(dataService, worldService, museumService)
	if started then return end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		activeByOwner[player] = nil
	end)

	task.spawn(function()
		while task.wait(MuseumConfig.VisitorTickSeconds) do
			for _, owner in ipairs(museumService:GetOwners()) do
				local info = museumService:GetMuseumInfo(owner)
				if info and info.Score > 0 and (activeByOwner[owner] or 0) < MuseumConfig.MaxVisitorsPerMuseum then
					local chance = math.min(
						MuseumConfig.MaxVisitorChance,
						MuseumConfig.VisitorChanceBase + info.Score * MuseumConfig.VisitorChancePerScore
					)
					if rng:NextNumber() < chance then
						changeActive(owner, 1)
						task.spawn(function()
							local visitorType = chooseVisitorType(info.Score)
							local model, humanoid = createRobloxVisitor(worldService:GetWorld(), info.Entrance, visitorType)
							if not model or not humanoid then
								changeActive(owner, -1)
								return
							end

							walkTo(model, humanoid, info.Inside)
							local stops = rng:NextInteger(1, 3)
							for _ = 1, stops do
								walkTo(model, humanoid, randomInsidePoint(info))
								task.wait(rng:NextNumber(1.2, 2.6))
							end

							local baseRevenue = math.min(
								MuseumConfig.MaxRevenuePerVisitor,
								math.floor(MuseumConfig.BaseVisitorRevenue + info.Score * MuseumConfig.RevenuePerScore)
							)
							local revenue = math.max(1, math.floor(baseRevenue * visitorType.RevenueMultiplier))
							museumService:AwardVisit(owner, revenue, visitorType.Id)
							task.wait(rng:NextNumber(MuseumConfig.VisitorStayMin, MuseumConfig.VisitorStayMax))
							walkTo(model, humanoid, info.Exit)
							model:Destroy()
							changeActive(owner, -1)
						end)
					end
				end
			end
		end
	end)
	print("[Museum Empire] VisitorService started — Roblox R15 NPC foundation")
end

return VisitorService
