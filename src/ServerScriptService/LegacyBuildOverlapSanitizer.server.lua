local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared:WaitForChild("BuildConfig"))
local BuildCollision = require(Shared:WaitForChild("BuildCollision"))

local buildStore = DataStoreService:GetDataStore(BuildConfig.DataStoreName)
local oldSanitizerStore = DataStoreService:GetDataStore("PropertyEmpireV2_BuildSanitizer_v1")

local CLEANUP_VERSION = 1
local processedLots = {}
local rejectedByLot = {}

local function buildKey(lotId)
	return "build_" .. lotId
end

local function oldSanitizerKey(lotId)
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

	-- Keep the most recent piece when legacy data contains two pieces sharing
	-- physical volume. The older conflicting entry is permanently removed.
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

local function asSet(ids)
	local set = {}
	for _, pieceId in ipairs(ids) do
		if type(pieceId) == "string" and pieceId ~= "" then
			set[pieceId] = true
		end
	end
	return set
end

local function migrateLot(lotId)
	if processedLots[lotId] then
		return rejectedByLot[lotId] or {}
	end

	local finalRejectedIds = {}
	local success, errorMessage = pcall(function()
		buildStore:UpdateAsync(buildKey(lotId), function(stored)
			if type(stored) ~= "table" or type(stored.Pieces) ~= "table" then
				finalRejectedIds = {}
				return stored
			end

			if (tonumber(stored.LegacyCleanupVersion) or 0) >= CLEANUP_VERSION then
				finalRejectedIds = {}
				return stored
			end

			local rejectedIds = calculateRejectedIds(stored)
			local rejectedSet = asSet(rejectedIds)
			local filtered = {}

			for _, raw in ipairs(stored.Pieces) do
				if type(raw) == "table" and type(raw.Id) == "string" and not rejectedSet[raw.Id] then
					table.insert(filtered, raw)
				end
			end

			stored.Pieces = filtered
			stored.LegacyCleanupVersion = CLEANUP_VERSION
			stored.LegacyCleanupAt = os.time()
			stored.LegacyRemovedPieceCount = #rejectedIds
			finalRejectedIds = rejectedIds
			return stored
		end)
	end)

	if not success then
		warn(string.format(
			"[LegacyBuildOverlapSanitizer] Failed to permanently migrate %s: %s",
			lotId,
			tostring(errorMessage)
		))
		return nil
	end

	-- The old helper DataStore is obsolete after the build record itself has
	-- been migrated. Remove its per-lot key so stale cleanup metadata disappears.
	pcall(function()
		oldSanitizerStore:RemoveAsync(oldSanitizerKey(lotId))
	end)

	local rejectedSet = asSet(finalRejectedIds)
	processedLots[lotId] = true
	rejectedByLot[lotId] = rejectedSet
	return rejectedSet
end

local function sanitizeFolder(lotFolder)
	if not lotFolder:IsA("Folder") then
		return
	end

	local rejectedSet = migrateLot(lotFolder.Name)
	if not rejectedSet then
		return
	end

	local removedFromWorld = 0
	for _, root in ipairs(lotFolder:GetChildren()) do
		local pieceId = root:GetAttribute("BuildPieceId")
		if type(pieceId) ~= "string" or pieceId == "" then
			pieceId = root.Name
		end
		if rejectedSet[pieceId] then
			root:Destroy()
			removedFromWorld += 1
		end
	end

	lotFolder:SetAttribute("LegacyCleanupVersion", CLEANUP_VERSION)
	lotFolder:SetAttribute("LegacyRemovedFromWorld", removedFromWorld)
	if removedFromWorld > 0 then
		print(string.format(
			"[Property Empire v2] Permanently removed %d legacy conflicting piece(s) from %s",
			removedFromWorld,
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

	-- BuildService and this one-time migration can overlap during startup.
	-- Repeating the runtime removal briefly guarantees that a stale object loaded
	-- from a pre-migration read cannot remain visible in the current server.
	for _ = 1, 30 do
		runSweep(buildsFolder)
		task.wait(2)
	end

	print("[Property Empire v2] Legacy construction cleanup migration complete")
end

task.spawn(start)
