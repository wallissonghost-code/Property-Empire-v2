local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.AssetLibrary)

local MuseumAssetPlacementService = {}
local started = false
local assetService

local function sanitizeClone(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
end

local function fitAndPivot(model, targetCFrame, maxSize)
	sanitizeClone(model)
	local _, size = model:GetBoundingBox()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > 0 and largest > maxSize then
		local scale = math.clamp(maxSize / largest, 0.08, 1)
		pcall(function() model:ScaleTo(scale) end)
	end
	model:PivotTo(targetCFrame)
end

local function fallbackDisplayCase(parent, cf)
	local m = Instance.new("Model")
	m.Name = "FallbackDisplayCase"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, .6, 5)
	base.Color = Color3.fromRGB(44, 48, 54)
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.CanCollide = false
	base.CFrame = cf
	base.Parent = m
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = Vector3.new(4.2, 4.2, 4.2)
	glass.Color = Color3.fromRGB(177, 219, 232)
	glass.Material = Enum.Material.Glass
	glass.Transparency = .55
	glass.Anchored = true
	glass.CanCollide = false
	glass.CFrame = cf * CFrame.new(0, 2.35, 0)
	glass.Parent = m
	m.Parent = parent
	return m
end

local function fallbackStatue(parent, cf)
	local m = Instance.new("Model")
	m.Name = "FallbackStatue"
	local pedestal = Instance.new("Part")
	pedestal.Size = Vector3.new(4, 1.3, 4)
	pedestal.Color = Color3.fromRGB(191, 188, 178)
	pedestal.Material = Enum.Material.Marble
	pedestal.Anchored = true
	pedestal.CanCollide = false
	pedestal.CFrame = cf
	pedestal.Parent = m
	local sculpture = Instance.new("Part")
	sculpture.Shape = Enum.PartType.Ball
	sculpture.Size = Vector3.new(3.2, 5.2, 3.2)
	sculpture.Color = Color3.fromRGB(153, 157, 160)
	sculpture.Material = Enum.Material.Marble
	sculpture.Anchored = true
	sculpture.CanCollide = false
	sculpture.CFrame = cf * CFrame.new(0, 3, 0)
	sculpture.Parent = m
	m.Parent = parent
	return m
end

local function placeAsset(folder, key, cf, maxSize, fallback)
	local clone = assetService and assetService:GetClone(key) or nil
	if clone then
		clone.Name = "Library_" .. key
		clone:SetAttribute("MuseumLibraryAsset", true)
		clone.Parent = folder
		local ok = pcall(fitAndPivot, clone, cf, maxSize)
		if ok then return clone end
		clone:Destroy()
	end
	return fallback and fallback(folder, cf) or nil
end

local function decorateMuseum(model)
	if not model:IsA("Model") or not model.Name:match("^Museum_%d+$") then return end
	local floor = model:WaitForChild("Floor", 8)
	if not floor then return end
	local old = model:FindFirstChild("LibraryDecor")
	if old then old:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "LibraryDecor"
	folder.Parent = model

	local level = math.clamp(math.floor(((floor.Size.X - 40) / 8) + 1.5), 1, 5)
	local w, d = floor.Size.X, floor.Size.Z
	local base = floor.CFrame * CFrame.new(0, .6, 0)

	-- Real Creator Store display cases are used where available; procedural cases keep gameplay intact if loading is restricted.
	local caseCount = math.clamp(2 + level, 3, 6)
	for i = 1, caseCount do
		local side = i % 2 == 0 and 1 or -1
		local row = math.ceil(i / 2)
		local x = side * math.min(w * .31, 13)
		local z = -d * .24 + (row - 1) * math.min(8, d * .18)
		placeAsset(folder, "DisplayCase", base * CFrame.new(x, 0, z), 7, fallbackDisplayCase)
	end

	-- Feature sculpture anchors the back gallery without blocking circulation.
	if level >= 2 then
		placeAsset(folder, "Statue", base * CFrame.new(0, 0, -d * .34), 8, fallbackStatue)
	end

	-- Natural-history feature for level 3+.
	if level >= 3 then
		placeAsset(folder, "DinoSkull", base * CFrame.new(-w * .24, 0, -d * .32) * CFrame.Angles(0, math.rad(18), 0), 10, fallbackStatue)
	end

	-- Ancient gallery becomes a premium side feature only on large museums.
	if level >= 4 then
		local gallery = placeAsset(folder, "HistoryGallery", base * CFrame.new(w * .23, 0, -d * .30), math.min(14, w * .24), nil)
		if gallery then gallery:SetAttribute("PremiumGalleryFeature", true) end
	end

	model:SetAttribute("LibraryDecorVersion", 1)
end

function MuseumAssetPlacementService:Start(importService, worldService)
	if started then return end
	started = true
	assetService = importService
	local world = worldService:GetWorld()
	for _, child in ipairs(world:GetChildren()) do task.defer(decorateMuseum, child) end
	world.ChildAdded:Connect(function(child)
		task.defer(decorateMuseum, child)
	end)
	print("[Museum Empire] MuseumAssetPlacementService started — sanitized Creator Store decor + fallbacks")
end

return MuseumAssetPlacementService
