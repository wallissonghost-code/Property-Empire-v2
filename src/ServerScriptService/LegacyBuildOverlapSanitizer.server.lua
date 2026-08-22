local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared:WaitForChild("BuildConfig"))
local BuildCollision = require(Shared:WaitForChild("BuildCollision"))

local buildStore = DataStoreService:GetDataStore(BuildConfig.DataStoreName)
local sanitizerStore = DataStoreService:GetDataStore("PropertyEmpireV2_BuildSanitizer_v1")

local processedLots = {}
local rejectedByLot = {}

local function buildKey(lotId)
	return "build_" .. lotId
end

local function sanitizerKey(lotId)
	return "legacy_overlap_" .. lotId
end

local function isValidStoredPiece(raw)
	return type(raw) == "table"
		and type(raw.Id) == "string"
		and type(raw.Type) == "string"
		and type(raw.GridX) == "number"
		and type(raw.GridZ) == "number"
		and type(raw.Level) == "number"
		and type(raw.Rotation) == "number"
		and BuildConfig.Catalog[raw.Type] ~= nil
end

local function collisionEntry(raw)
	return {
		Type = raw.Type,
		GridX = raw.GridX,
		GridZ = raw.GridZ,
		Level = math.floor(raw.Level),
		Rotation = math.floor(raw.Rotation) % 4,
	}
end

local function calculateRejectedIds(stored)
	if type(stored) ~= "table" or type(stored.Pieces) ~= "table" then
		return {}
	end

	local ordered = {}
	for index, raw in ipairs(stored.Pieces) do
		if isValidStoredPiece(raw) then
			table.insert(ordered, {
				Raw = raw,
				Index = index,
				CreatedAt = tonumber(raw.CreatedAt) or 0,
			})
		end
	end

	-- Keep the newest valid piece whenever two legacy pieces occupy the same
	-- physical volume. This best matches the player's most recent edit while
	-- preserving every non-conflicting piece of the construction.
	table.sort(ordered, function(a, b)
		if a.CreatedAt == b.CreatedAt then
			return a.Index > b.Index
		end
		return a.CreatedAt > b.CreatedAt
	end)

	local accepted = {}
	local rejectedIds = {}
	for _, item in ipairs(ordered) do
		local raw = item.Raw
		local candidate = BuildCollision.MakeDescriptor(
			BuildConfig,
			raw.Type,
			raw.GridX,
			raw.GridZ,
			raw.Level,
			raw.Rotation
		)

		if candidate and BuildCollision.HasConflict(BuildConfig, candidate, accepted) then
			table.insert(rejectedIds, raw.Id)
		else
			table.insert(accepted, collisionEntry(raw))
		end
	end

	return rejectedIds
end

local function readPersistentSanitizer(lotId)
	local success, stored = pcall(function()
		return sanitizerStore:GetAsync(sanitizerKey(lotId))
	end)
	if not success then
		warn(string.format("[LegacyBuildOverlapSanitizer] Failed to read sanitizer for %s", lotId))
		return nil
	end

	if type(stored) == "table" and type(stored.RejectedIds) == "table" then
		return stored.RejectedIds
	end
	return nil
end

local function calculateAndPersistSanitizer(lotId)
	local success, stored = pcall(function()
		return buildStore:GetAsync(buildKey(lotId))
	end)
	if not success then
		warn(string.format("[LegacyBuildOverlapSanitizer] Failed to inspect legacy build for %s", lotId))
		return nil
	end

	local rejectedIds = calculateRejectedIds(stored)
	local saveSuccess = pcall(function()
		sanitizerStore:SetAsync(sanitizerKey(lotId), {
			Version = 1,
			RejectedIds = rejectedIds,
			CreatedAt = os.time(),
		})
	end)
	if not saveSuccess then
		warn(string.format("[LegacyBuildOverlapSanitizer] Failed to persist sanitizer for %s", lotId))
	end

	return rejectedIds
end

local function getRejectedIds(lotId)
	if processedLots[lotId] then
		return rejectedByLot[lotId] or {}
	end

	local rejectedIds = readPersistentSanitizer(lotId)
	if rejectedIds == nil then
		rejectedIds = calculateAndPersistSanitizer(lotId)
	end
	if rejectedIds == nil then
		return nil
	end

	local set = {}
	for _, pieceId in ipairs(rejectedIds) do
		if type(pieceId) == "string" then
			set[pieceId] = true
		end
	end

	processedLots[lotId] = true
	rejectedByLot[lotId] = set
	return set
end

local function sanitizeFolder(lotFolder)
	if not lotFolder:IsA("Folder") or #lotFolder:GetChildren() == 0 then
		return
	end

	local rejectedSet = getRejectedIds(lotFolder.Name)
	if not rejectedSet then
		return
	end

	local removed = 0
	for _, root in ipairs(lotFolder:GetChildren()) do
		local pieceId = root:GetAttribute("BuildPieceId")
		if type(pieceId) ~= "string" or pieceId == "" then
			pieceId = root.Name
		end
		if rejectedSet[pieceId] then
			root:Destroy()
			removed += 1
		end
	end

	lotFolder:SetAttribute("LegacyOverlapSanitized", true)
	lotFolder:SetAttribute("LegacyOverlapHiddenPieces", removed)
	if removed > 0 then
		print(string.format(
			"[Property Empire v2] Hidden %d legacy overlapping piece(s) from %s",
			removed,
			lotFolder.Name
		))
	end
end

local function runSweep(buildsFolder)
	for _, lotFolder in ipairs(buildsFolder:GetChildren()) do
		sanitizeFolder(lotFolder)
		task.wait(0.05)
	end
end

local function start()
	local world = Workspace:WaitForChild("PropertyEmpireV2World", 60)
	if not world then
		warn("[LegacyBuildOverlapSanitizer] World did not appear")
		return
	end

	local buildsFolder = world:WaitForChild("Builds", 60)
	if not buildsFolder then
		warn("[LegacyBuildOverlapSanitizer] Builds folder did not appear")
		return
	end

	-- BuildService loads DataStore-backed construction asynchronously. Re-run
	-- the visual sanitation for the first minute so late-loaded legacy roots are
	-- removed as soon as they appear. New valid pieces are never in RejectedIds.
	for _ = 1, 30 do
		runSweep(buildsFolder)
		task.wait(2)
	end

	print("[Property Empire v2] Legacy build overlap sanitizer ready")
end

task.spawn(start)
