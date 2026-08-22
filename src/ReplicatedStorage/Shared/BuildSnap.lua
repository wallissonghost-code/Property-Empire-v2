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

local function getRule(config, pieceType, rotation)
	local spec = config.Catalog[pieceType]
	if not spec then
		return nil
	end

	local orientation = normalizeRotation(rotation) % 2
	local slot = spec.Slot

	if slot == "Floor" then
		return SNAP_STEP, 4, SNAP_STEP, 4
	end

	if slot == "Wall" then
		if orientation == 0 then
			return SNAP_STEP, 4, SNAP_STEP, 0
		end
		return SNAP_STEP, 0, SNAP_STEP, 4
	end

	if slot == "Stair" then
		if orientation == 0 then
			return SNAP_STEP, 4, SNAP_STEP, 0
		end
		return SNAP_STEP, 0, SNAP_STEP, 4
	end

	local step = math.max(tonumber(config.GridSize) or 2, 1)
	return step, 0, step, 0
end

function BuildSnap.SnapLocalPosition(config, pieceType, rotation, localX, localZ)
	if type(localX) ~= "number" or type(localZ) ~= "number" then
		return nil
	end

	local stepX, offsetX, stepZ, offsetZ = getRule(config, pieceType, rotation)
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

function BuildSnap.SnapGrid(config, pieceType, rotation, gridX, gridZ)
	if type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return nil
	end
	local gridSize = tonumber(config.GridSize) or 2
	return BuildSnap.SnapLocalPosition(
		config,
		pieceType,
		rotation,
		gridX * gridSize,
		gridZ * gridSize
	)
end

function BuildSnap.IsAligned(config, pieceType, rotation, gridX, gridZ)
	local snapped = BuildSnap.SnapGrid(config, pieceType, rotation, gridX, gridZ)
	if not snapped then
		return false
	end
	return math.abs(snapped.GridX - gridX) <= EPSILON
		and math.abs(snapped.GridZ - gridZ) <= EPSILON
end

return table.freeze(BuildSnap)
