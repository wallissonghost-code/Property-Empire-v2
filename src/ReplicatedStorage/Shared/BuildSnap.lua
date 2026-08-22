local BuildSnap = {}

local SNAP_STEP = 8
local EPSILON = 0.001

local function normalizeRotation(rotation)
	if type(rotation) ~= "number" then
		return 0
	end
	return math.floor(rotation) % 4
end

local function snapAxis(value, step, offset)
	return math.round((value - offset) / step) * step + offset
end

local function localCenter(config, entry)
	local gridSize = tonumber(config.GridSize) or 2
	return entry.GridX * gridSize, entry.GridZ * gridSize
end

local function nearestFloorAnchor(config, localX, localZ, entries, level)
	if type(entries) ~= "table" then
		return nil
	end

	local best = nil
	local bestDistance = math.huge
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and entry.Level == level then
			local spec = config.Catalog[entry.Type]
			if spec and spec.Slot == "Floor" and type(entry.GridX) == "number" and type(entry.GridZ) == "number" then
				local centerX, centerZ = localCenter(config, entry)
				local dx = localX - centerX
				local dz = localZ - centerZ
				local distance = dx * dx + dz * dz
				if distance < bestDistance then
					bestDistance = distance
					best = { X = centerX, Z = centerZ }
				end
			end
		end
	end
	return best
end

local function getRule(config, pieceType, rotation, localX, localZ, entries, level)
	local spec = config.Catalog[pieceType]
	if not spec then
		return nil
	end

	local orientation = normalizeRotation(rotation) % 2
	local slot = spec.Slot
	local anchor = nearestFloorAnchor(config, localX, localZ, entries, level)

	if slot == "Floor" then
		if anchor then
			return SNAP_STEP, anchor.X, SNAP_STEP, anchor.Z
		end
		return SNAP_STEP, 4, SNAP_STEP, 4
	end

	if slot == "Wall" then
		if anchor then
			if orientation == 0 then
				return SNAP_STEP, anchor.X, SNAP_STEP, anchor.Z + 4
			end
			return SNAP_STEP, anchor.X + 4, SNAP_STEP, anchor.Z
		end

		if orientation == 0 then
			return SNAP_STEP, 4, SNAP_STEP, 0
		end
		return SNAP_STEP, 0, SNAP_STEP, 4
	end

	if slot == "Stair" then
		if anchor then
			if orientation == 0 then
				return SNAP_STEP, anchor.X, SNAP_STEP, anchor.Z + 4
			end
			return SNAP_STEP, anchor.X + 4, SNAP_STEP, anchor.Z
		end

		if orientation == 0 then
			return SNAP_STEP, 4, SNAP_STEP, 0
		end
		return SNAP_STEP, 0, SNAP_STEP, 4
	end

	local step = math.max(tonumber(config.GridSize) or 2, 1)
	return step, 0, step, 0
end

function BuildSnap.SnapLocalPosition(config, pieceType, rotation, localX, localZ, entries, level)
	if type(localX) ~= "number" or type(localZ) ~= "number" then
		return nil
	end

	local stepX, offsetX, stepZ, offsetZ = getRule(
		config,
		pieceType,
		rotation,
		localX,
		localZ,
		entries,
		level
	)
	if not stepX then
		return nil
	end

	local snappedX = snapAxis(localX, stepX, offsetX)
	local snappedZ = snapAxis(localZ, stepZ, offsetZ)
	local gridSize = tonumber(config.GridSize) or 2

	return {
		LocalX = snappedX,
		LocalZ = snappedZ,
		GridX = math.round(snappedX / gridSize),
		GridZ = math.round(snappedZ / gridSize),
	}
end

function BuildSnap.SnapGrid(config, pieceType, rotation, gridX, gridZ, entries, level)
	if type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return nil
	end
	local gridSize = tonumber(config.GridSize) or 2
	return BuildSnap.SnapLocalPosition(
		config,
		pieceType,
		rotation,
		gridX * gridSize,
		gridZ * gridSize,
		entries,
		level
	)
end

function BuildSnap.IsAligned(config, pieceType, rotation, gridX, gridZ, entries, level)
	local snapped = BuildSnap.SnapGrid(config, pieceType, rotation, gridX, gridZ, entries, level)
	if not snapped then
		return false
	end
	return math.abs(snapped.GridX - gridX) <= EPSILON
		and math.abs(snapped.GridZ - gridZ) <= EPSILON
end

return table.freeze(BuildSnap)
