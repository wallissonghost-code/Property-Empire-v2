local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared.BuildConfig)
local BuildCollision = require(Shared.BuildCollision)

local BuildPlacementGuard = {}
local started = false
local lotLocks = {}

local function getLot(lotId)
	local world = Workspace:FindFirstChild("PropertyEmpireV2World")
	local lots = world and world:FindFirstChild("Lots")
	local lot = lots and lots:FindFirstChild(lotId)
	if lot and lot:IsA("BasePart") then
		return lot
	end
	return nil
end

local function getLotBuildFolder(lotId)
	local world = Workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	return builds and builds:FindFirstChild(lotId) or nil
end

local function readPlacedEntries(lotId)
	local entries = {}
	local folder = getLotBuildFolder(lotId)
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

local function validatePlacement(payload)
	if type(payload) ~= "table" then
		return false, "Solicitação inválida"
	end

	local lotId = payload.LotId
	local pieceType = payload.PieceType
	if type(lotId) ~= "string" or #lotId > 32 or type(pieceType) ~= "string" then
		return false, "Dados inválidos"
	end

	local lot = getLot(lotId)
	local candidate = BuildCollision.MakeDescriptor(
		BuildConfig,
		pieceType,
		payload.GridX,
		payload.GridZ,
		payload.Level,
		payload.Rotation
	)
	if not lot or not candidate then
		return false, "Lote ou peça inválida"
	end

	if not BuildCollision.IsInsideLot(BuildConfig, lot, candidate) then
		return false, "A peça precisa ficar dentro do lote"
	end

	local conflict = BuildCollision.HasConflict(BuildConfig, candidate, readPlacedEntries(lotId))
	if conflict then
		return false, "Outra peça já ocupa esse espaço"
	end

	return true, nil
end

local function acquireLotLock(lotId)
	while lotLocks[lotId] do
		task.wait()
	end
	lotLocks[lotId] = true
end

local function releaseLotLock(lotId)
	lotLocks[lotId] = nil
end

function BuildPlacementGuard:Start()
	if started then
		return
	end
	started = true

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local placeRemote = remotes:WaitForChild("PlaceBuildPiece")
	local originalHandler = placeRemote.OnServerInvoke
	if type(originalHandler) ~= "function" then
		error("[BuildPlacementGuard] PlaceBuildPiece has no server handler")
	end

	placeRemote.OnServerInvoke = function(player, payload)
		local lotId = type(payload) == "table" and payload.LotId or nil
		if type(lotId) ~= "string" or #lotId > 32 then
			return { Ok = false, Error = "Dados inválidos" }
		end

		acquireLotLock(lotId)
		local ok, result = xpcall(function()
			local valid, errorMessage = validatePlacement(payload)
			if not valid then
				return { Ok = false, Error = errorMessage }
			end
			return originalHandler(player, payload)
		end, debug.traceback)
		releaseLotLock(lotId)

		if not ok then
			warn(string.format("[BuildPlacementGuard] Placement failed: %s", tostring(result)))
			return { Ok = false, Error = "Não foi possível validar a construção" }
		end

		return result
	end

	print("[Property Empire v2] BuildPlacementGuard started")
end

return BuildPlacementGuard
