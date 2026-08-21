local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared.BuildConfig)
local BuildCollision = require(Shared.BuildCollision)

local player = Players.LocalPlayer
local overlapHighlight = Instance.new("Highlight")
overlapHighlight.Name = "BuildOverlapHighlight"
overlapHighlight.FillColor = Color3.fromRGB(235, 65, 65)
overlapHighlight.FillTransparency = 0.35
overlapHighlight.OutlineColor = Color3.fromRGB(255, 220, 220)
overlapHighlight.OutlineTransparency = 0
overlapHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
overlapHighlight.Enabled = false
overlapHighlight.Parent = player:WaitForChild("PlayerGui")

local function nearlyEqual(a, b)
	return math.abs(a - b) <= 0.01
end

local function sameSize(a, b)
	return nearlyEqual(a.X, b.X) and nearlyEqual(a.Y, b.Y) and nearlyEqual(a.Z, b.Z)
end

local function findRepresentativePieceType(preview)
	for _, pieceType in ipairs(BuildConfig.CatalogOrder) do
		local spec = BuildConfig.Catalog[pieceType]
		if spec and sameSize(spec.Size, preview.Size) then
			return pieceType, spec
		end
	end
	return nil, nil
end

local function findLotForPreview(preview)
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local lots = world and world:FindFirstChild("Lots")
	if not lots then
		return nil
	end

	local best = nil
	local bestDistance = math.huge
	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == player.UserId then
			local localPosition = lot.CFrame:PointToObjectSpace(preview.Position)
			local withinX = math.abs(localPosition.X) <= lot.Size.X / 2 + 2
			local withinZ = math.abs(localPosition.Z) <= lot.Size.Z / 2 + 2
			if withinX and withinZ then
				local distance = Vector2.new(localPosition.X, localPosition.Z).Magnitude
				if distance < bestDistance then
					best = lot
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function makePreviewDescriptor(preview, lot)
	local pieceType, spec = findRepresentativePieceType(preview)
	if not pieceType or not spec then
		return nil
	end

	local localCFrame = lot.CFrame:ToObjectSpace(preview.CFrame)
	local gridX = math.round(localCFrame.Position.X / BuildConfig.GridSize)
	local gridZ = math.round(localCFrame.Position.Z / BuildConfig.GridSize)
	local level = math.round(
		(localCFrame.Position.Y - lot.Size.Y / 2 - spec.Size.Y / 2) / BuildConfig.LevelHeight
	)
	local rotation = math.abs(localCFrame.RightVector.X) >= math.abs(localCFrame.RightVector.Z) and 0 or 1

	return BuildCollision.MakeDescriptor(BuildConfig, pieceType, gridX, gridZ, level, rotation)
end

local function getExistingEntries(lot)
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	local folder = builds and builds:FindFirstChild(lot.Name)
	local entries = {}
	if not folder then
		return entries
	end

	for _, root in ipairs(folder:GetChildren()) do
		local pieceType = root:GetAttribute("PieceType")
		local gridX = root:GetAttribute("GridX")
		local gridZ = root:GetAttribute("GridZ")
		local level = root:GetAttribute("Level")
		local rotation = root:GetAttribute("Rotation")
		if type(pieceType) == "string"
			and type(gridX) == "number"
			and type(gridZ) == "number"
			and type(level) == "number"
			and type(rotation) == "number"
		then
			table.insert(entries, {
				Type = pieceType,
				GridX = gridX,
				GridZ = gridZ,
				Level = level,
				Rotation = rotation,
			})
		end
	end
	return entries
end

local function updateOverlapVisual()
	local visuals = workspace:FindFirstChild("PropertyEmpireLocalBuildVisuals")
	local preview = visuals and visuals:FindFirstChild("BuildPreview")
	if not preview or not preview:IsA("BasePart") or preview.Transparency >= 0.95 then
		overlapHighlight.Enabled = false
		overlapHighlight.Adornee = nil
		return
	end

	local lot = findLotForPreview(preview)
	local candidate = lot and makePreviewDescriptor(preview, lot) or nil
	if not lot or not candidate then
		overlapHighlight.Enabled = false
		overlapHighlight.Adornee = nil
		return
	end

	local conflict = BuildCollision.HasConflict(BuildConfig, candidate, getExistingEntries(lot))
	overlapHighlight.Adornee = preview
	overlapHighlight.Enabled = conflict
	preview:SetAttribute("OverlapBlocked", conflict)
end

RunService:BindToRenderStep("PropertyEmpireBuildCollisionPreview", Enum.RenderPriority.Last.Value, updateOverlapVisual)
