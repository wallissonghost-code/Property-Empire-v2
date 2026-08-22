local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared:WaitForChild("BuildConfig"))
local BuildCollision = require(Shared:WaitForChild("BuildCollision"))
local BuildSnap = require(Shared:WaitForChild("BuildSnap"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function findLotForPreview(preview)
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local lots = world and world:FindFirstChild("Lots")
	if not lots then
		return nil
	end

	local bestLot = nil
	local bestDistance = math.huge
	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == player.UserId then
			local localPosition = lot.CFrame:PointToObjectSpace(preview.Position)
			local insideExtendedBounds = math.abs(localPosition.X) <= lot.Size.X / 2 + 16
				and math.abs(localPosition.Z) <= lot.Size.Z / 2 + 16
			if insideExtendedBounds then
				local distance = Vector2.new(localPosition.X, localPosition.Z).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestLot = lot
				end
			end
		end
	end
	return bestLot
end

local function inferPieceType(preview)
	if preview.Size.Y <= 1.1 then
		return "Floor"
	end
	if math.max(preview.Size.X, preview.Size.Z) >= 15.5 then
		return "Stair"
	end
	return "Wall"
end

local function inferRotation(relativeCFrame)
	if math.abs(relativeCFrame.XVector.X) >= math.abs(relativeCFrame.XVector.Z) then
		return 0
	end
	return 1
end

local function readPlacedEntries(lotId)
	local entries = {}
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	local folder = builds and builds:FindFirstChild(lotId)
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

local function updateSnapPreview()
	local visuals = workspace:FindFirstChild("PropertyEmpireLocalBuildVisuals")
	local preview = visuals and visuals:FindFirstChild("BuildPreview")
	if not preview or not preview:IsA("BasePart") or preview.Transparency >= 1 then
		return
	end

	local lot = findLotForPreview(preview)
	if not lot then
		return
	end

	local pieceType = inferPieceType(preview)
	local spec = BuildConfig.Catalog[pieceType]
	if not spec then
		return
	end

	local relative = lot.CFrame:ToObjectSpace(preview.CFrame)
	local rotation = inferRotation(relative)
	local localHit = lot.CFrame:PointToObjectSpace(mouse.Hit.Position)
	local snapped = BuildSnap.SnapLocalPosition(BuildConfig, pieceType, rotation, localHit.X, localHit.Z)
	if not snapped then
		return
	end

	local rotationOnly = CFrame.fromMatrix(Vector3.zero, relative.XVector, relative.YVector, relative.ZVector)
	preview.CFrame = lot.CFrame
		* CFrame.new(snapped.LocalX, relative.Position.Y, snapped.LocalZ)
		* rotationOnly

	local level = math.round(
		(relative.Position.Y - lot.Size.Y / 2 - spec.Size.Y / 2) / BuildConfig.LevelHeight
	)
	local candidate = BuildCollision.MakeDescriptor(
		BuildConfig,
		pieceType,
		snapped.GridX,
		snapped.GridZ,
		level,
		rotation
	)

	local blocked = not candidate or not BuildCollision.IsInsideLot(BuildConfig, lot, candidate)
	if not blocked then
		blocked = BuildCollision.HasConflict(BuildConfig, candidate, readPlacedEntries(lot.Name))
	end

	preview:SetAttribute("SnapGridX", snapped.GridX)
	preview:SetAttribute("SnapGridZ", snapped.GridZ)
	preview:SetAttribute("SnapBlocked", blocked)
	preview.Color = blocked and Color3.fromRGB(235, 84, 84) or Color3.fromRGB(80, 220, 120)
end

RunService:BindToRenderStep(
	"PropertyEmpireBuildSnapPreview",
	Enum.RenderPriority.Last.Value,
	updateSnapPreview
)

print("[Property Empire v2] Build snap preview started")
