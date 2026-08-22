local BuildSnap = {}

local DEFAULT_STEP = 8
local MAGNET_RADIUS = 11
local EPSILON = 0.01

local function normalizeRotation(rotation)
	if type(rotation) ~= "number" then
		return 0
	end
	return math.floor(rotation) % 4
end

local function snapAxis(value, step, offset)
	return math.round((value - offset) / step) * step + offset
end

local function rotatedFootprint(spec, rotation)
	if normalizeRotation(rotation) % 2 == 1 then
		return spec.Size.Z, spec.Size.X
	end
	return spec.Size.X, spec.Size.Z
end

local function localCenter(config, entry)
	local gridSize = tonumber(config.GridSize) or 2
	return entry.GridX * gridSize, entry.GridZ * gridSize
end

local function overlapAmount(centerA, sizeA, centerB, sizeB)
	local minA = centerA - sizeA / 2
	local maxA = centerA + sizeA / 2
	local minB = centerB - sizeB / 2
	local maxB = centerB + sizeB / 2
	return math.min(maxA, maxB) - math.max(minA, minB)
end

local function floorDescriptors(config, entries, level)
	local floors = {}
	if type(entries) ~= "table" then
		return floors
	end

	for _, entry in ipairs(entries) do
		if type(entry) == "table"
			and entry.Level == level
			and type(entry.GridX) == "number"
			and type(entry.GridZ) == "number"
		then
			local spec = config.Catalog[entry.Type]
			if spec and spec.Slot == "Floor" then
				local centerX, centerZ = localCenter(config, entry)
				local sizeX, sizeZ = rotatedFootprint(spec, entry.Rotation or 0)
				table.insert(floors, {
					CenterX = centerX,
					CenterZ = centerZ,
					SizeX = sizeX,
					SizeZ = sizeZ,
				})
			end
		end
	end

	return floors
end

local function wallDescriptors(config, entries, level)
	local walls = {}
	if type(entries) ~= "table" then
		return walls
	end

	for _, entry in ipairs(entries) do
		if type(entry) == "table"
			and entry.Level == level
			and type(entry.GridX) == "number"
			and type(entry.GridZ) == "number"
		then
			local spec = config.Catalog[entry.Type]
			if spec and spec.Slot == "Wall" then
				local centerX, centerZ = localCenter(config, entry)
				local rotation = normalizeRotation(entry.Rotation or 0)
				local sizeX, sizeZ = rotatedFootprint(spec, rotation)
				table.insert(walls, {
					CenterX = centerX,
					CenterZ = centerZ,
					SizeX = sizeX,
					SizeZ = sizeZ,
					Orientation = rotation % 2,
				})
			end
		end
	end

	return walls
end

local function floorCandidateOverlaps(candidateX, candidateZ, sizeX, sizeZ, floors)
	for _, floor in ipairs(floors) do
		local overlapX = overlapAmount(candidateX, sizeX, floor.CenterX, floor.SizeX)
		local overlapZ = overlapAmount(candidateZ, sizeZ, floor.CenterZ, floor.SizeZ)
		if overlapX > EPSILON and overlapZ > EPSILON then
			return true
		end
	end
	return false
end

local function addUniqueCandidate(candidates, seen, x, z, kind, priority)
	local key = string.format("%.3f:%.3f:%s", x, z, kind or "")
	if seen[key] then
		return
	end
	seen[key] = true
	table.insert(candidates, {
		X = x,
		Z = z,
		Kind = kind or "Grid",
		Priority = priority or 0,
	})
end

local function nearestCandidate(candidates, localX, localZ)
	local best = nil
	local bestScore = math.huge
	local bestDistanceSquared = math.huge

	for _, candidate in ipairs(candidates) do
		local dx = localX - candidate.X
		local dz = localZ - candidate.Z
		local distanceSquared = dx * dx + dz * dz
		local score = distanceSquared - (candidate.Priority or 0)
		if score < bestScore then
			bestScore = score
			bestDistanceSquared = distanceSquared
			best = candidate
		end
	end

	return best, bestDistanceSquared
end

local function floorConnectionCandidate(config, spec, rotation, localX, localZ, entries, level)
	local floors = floorDescriptors(config, entries, level)
	if #floors == 0 then
		return nil, nil, floors
	end

	local sizeX, sizeZ = rotatedFootprint(spec, rotation)
	local candidates = {}
	local seen = {}

	for _, floor in ipairs(floors) do
		local deltaX = (floor.SizeX + sizeX) / 2
		local deltaZ = (floor.SizeZ + sizeZ) / 2
		local possible = {
			{ floor.CenterX + deltaX, floor.CenterZ },
			{ floor.CenterX - deltaX, floor.CenterZ },
			{ floor.CenterX, floor.CenterZ + deltaZ },
			{ floor.CenterX, floor.CenterZ - deltaZ },
		}

		for _, point in ipairs(possible) do
			if not floorCandidateOverlaps(point[1], point[2], sizeX, sizeZ, floors) then
				addUniqueCandidate(candidates, seen, point[1], point[2], "FloorEdge", 1.5)
			end
		end
	end

	local best, distanceSquared = nearestCandidate(candidates, localX, localZ)
	return best, distanceSquared, floors
end

local function addFloorWallCandidates(candidates, seen, floors, orientation)
	for _, floor in ipairs(floors) do
		if orientation == 0 then
			addUniqueCandidate(candidates, seen, floor.CenterX, floor.CenterZ + floor.SizeZ / 2, "FloorEdge", 1)
			addUniqueCandidate(candidates, seen, floor.CenterX, floor.CenterZ - floor.SizeZ / 2, "FloorEdge", 1)
		else
			addUniqueCandidate(candidates, seen, floor.CenterX + floor.SizeX / 2, floor.CenterZ, "FloorEdge", 1)
			addUniqueCandidate(candidates, seen, floor.CenterX - floor.SizeX / 2, floor.CenterZ, "FloorEdge", 1)
		end
	end
end

local function addWallContinuationCandidates(candidates, seen, walls, orientation, wallSizeX, wallSizeZ)
	for _, wall in ipairs(walls) do
		if wall.Orientation == orientation then
			if orientation == 0 then
				local deltaX = (wall.SizeX + wallSizeX) / 2
				addUniqueCandidate(candidates, seen, wall.CenterX + deltaX, wall.CenterZ, "WallEnd", 3)
				addUniqueCandidate(candidates, seen, wall.CenterX - deltaX, wall.CenterZ, "WallEnd", 3)
			else
				local deltaZ = (wall.SizeZ + wallSizeZ) / 2
				addUniqueCandidate(candidates, seen, wall.CenterX, wall.CenterZ + deltaZ, "WallEnd", 3)
				addUniqueCandidate(candidates, seen, wall.CenterX, wall.CenterZ - deltaZ, "WallEnd", 3)
			end
		else
			if orientation == 0 then
				local halfCandidate = wallSizeX / 2
				local endpointZ1 = wall.CenterZ + wall.SizeZ / 2
				local endpointZ2 = wall.CenterZ - wall.SizeZ / 2
				for _, endpointZ in ipairs({ endpointZ1, endpointZ2 }) do
					addUniqueCandidate(candidates, seen, wall.CenterX + halfCandidate, endpointZ, "WallCorner", 2.5)
					addUniqueCandidate(candidates, seen, wall.CenterX - halfCandidate, endpointZ, "WallCorner", 2.5)
				end
			else
				local halfCandidate = wallSizeZ / 2
				local endpointX1 = wall.CenterX + wall.SizeX / 2
				local endpointX2 = wall.CenterX - wall.SizeX / 2
				for _, endpointX in ipairs({ endpointX1, endpointX2 }) do
					addUniqueCandidate(candidates, seen, endpointX, wall.CenterZ + halfCandidate, "WallCorner", 2.5)
					addUniqueCandidate(candidates, seen, endpointX, wall.CenterZ - halfCandidate, "WallCorner", 2.5)
				end
			end
		end
	end
end

local function wallConnectionCandidate(config, spec, rotation, localX, localZ, entries, level)
	local floors = floorDescriptors(config, entries, level)
	local walls = wallDescriptors(config, entries, level)
	if #floors == 0 and #walls == 0 then
		return nil, nil
	end

	local orientation = normalizeRotation(rotation) % 2
	local wallSizeX, wallSizeZ = rotatedFootprint(spec, rotation)
	local candidates = {}
	local seen = {}

	addFloorWallCandidates(candidates, seen, floors, orientation)
	addWallContinuationCandidates(candidates, seen, walls, orientation, wallSizeX, wallSizeZ)

	return nearestCandidate(candidates, localX, localZ)
end

local function stairConnectionCandidate(config, spec, rotation, localX, localZ, entries, level)
	local floors = floorDescriptors(config, entries, level)
	if #floors == 0 then
		return nil, nil
	end

	local sizeX, sizeZ = rotatedFootprint(spec, rotation)
	local candidates = {}
	local seen = {}

	for _, floor in ipairs(floors) do
		local deltaX = (floor.SizeX + sizeX) / 2
		local deltaZ = (floor.SizeZ + sizeZ) / 2
		addUniqueCandidate(candidates, seen, floor.CenterX + deltaX, floor.CenterZ, "StairEdge", 2)
		addUniqueCandidate(candidates, seen, floor.CenterX - deltaX, floor.CenterZ, "StairEdge", 2)
		addUniqueCandidate(candidates, seen, floor.CenterX, floor.CenterZ + deltaZ, "StairEdge", 2)
		addUniqueCandidate(candidates, seen, floor.CenterX, floor.CenterZ - deltaZ, "StairEdge", 2)
	end

	return nearestCandidate(candidates, localX, localZ)
end

local function fallbackSnap(config, spec, rotation, localX, localZ)
	local slot = spec.Slot
	local orientation = normalizeRotation(rotation) % 2
	local sizeX, sizeZ = rotatedFootprint(spec, rotation)

	if slot == "Floor" then
		local stepX = math.max(sizeX, DEFAULT_STEP)
		local stepZ = math.max(sizeZ, DEFAULT_STEP)
		return snapAxis(localX, stepX, 0), snapAxis(localZ, stepZ, 0)
	end

	if slot == "Wall" then
		if orientation == 0 then
			return snapAxis(localX, DEFAULT_STEP, 0), snapAxis(localZ, DEFAULT_STEP, 4)
		end
		return snapAxis(localX, DEFAULT_STEP, 4), snapAxis(localZ, DEFAULT_STEP, 0)
	end

	if slot == "Stair" then
		if orientation == 0 then
			return snapAxis(localX, math.max(sizeX, DEFAULT_STEP), 0), snapAxis(localZ, DEFAULT_STEP, 0)
		end
		return snapAxis(localX, DEFAULT_STEP, 0), snapAxis(localZ, math.max(sizeZ, DEFAULT_STEP), 0)
	end

	local step = math.max(tonumber(config.GridSize) or 2, 1)
	return snapAxis(localX, step, 0), snapAxis(localZ, step, 0)
end

function BuildSnap.SnapLocalPosition(config, pieceType, rotation, localX, localZ, entries, level)
	if type(config) ~= "table" or type(config.Catalog) ~= "table" then
		return nil
	end
	if type(localX) ~= "number" or type(localZ) ~= "number" then
		return nil
	end

	local spec = config.Catalog[pieceType]
	if not spec then
		return nil
	end

	local normalizedRotation = normalizeRotation(rotation)
	local normalizedLevel = math.floor(tonumber(level) or 0)
	local snappedX, snappedZ = fallbackSnap(config, spec, normalizedRotation, localX, localZ)
	local connectionKind = "Grid"

	if spec.Slot == "Floor" then
		local candidate, distanceSquared, floors = floorConnectionCandidate(
			config,
			spec,
			normalizedRotation,
			localX,
			localZ,
			entries,
			normalizedLevel
		)
		local sizeX, sizeZ = rotatedFootprint(spec, normalizedRotation)
		local fallbackBlocked = floorCandidateOverlaps(snappedX, snappedZ, sizeX, sizeZ, floors)
		if candidate and (distanceSquared <= MAGNET_RADIUS * MAGNET_RADIUS or fallbackBlocked) then
			snappedX = candidate.X
			snappedZ = candidate.Z
			connectionKind = candidate.Kind
		end
	elseif spec.Slot == "Wall" then
		local candidate, distanceSquared = wallConnectionCandidate(
			config,
			spec,
			normalizedRotation,
			localX,
			localZ,
			entries,
			normalizedLevel
		)
		if candidate and distanceSquared <= MAGNET_RADIUS * MAGNET_RADIUS then
			snappedX = candidate.X
			snappedZ = candidate.Z
			connectionKind = candidate.Kind
		end
	elseif spec.Slot == "Stair" then
		local candidate, distanceSquared = stairConnectionCandidate(
			config,
			spec,
			normalizedRotation,
			localX,
			localZ,
			entries,
			normalizedLevel
		)
		if candidate and distanceSquared <= MAGNET_RADIUS * MAGNET_RADIUS then
			snappedX = candidate.X
			snappedZ = candidate.Z
			connectionKind = candidate.Kind
		end
	end

	local gridSize = tonumber(config.GridSize) or 2
	return {
		LocalX = snappedX,
		LocalZ = snappedZ,
		GridX = math.round(snappedX / gridSize),
		GridZ = math.round(snappedZ / gridSize),
		ConnectionKind = connectionKind,
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
