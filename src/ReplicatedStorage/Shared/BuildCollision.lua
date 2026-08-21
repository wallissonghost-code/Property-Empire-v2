local BuildCollision = {}

local EPSILON = 0.01
local WALL_JOIN_END_TOLERANCE = 0.55
local WALL_JOIN_THICKNESS_TOLERANCE = 1.05

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function normalizeRotation(rotation)
	if not isFiniteNumber(rotation) then
		return nil
	end
	return math.floor(rotation) % 4
end

local function getRotatedFootprint(spec, rotation)
	if rotation % 2 == 1 then
		return spec.Size.Z, spec.Size.X
	end
	return spec.Size.X, spec.Size.Z
end

local function overlapAmount(centerA, sizeA, centerB, sizeB)
	local minA = centerA - sizeA / 2
	local maxA = centerA + sizeA / 2
	local minB = centerB - sizeB / 2
	local maxB = centerB + sizeB / 2
	return math.min(maxA, maxB) - math.max(minA, minB)
end

local function isFloorAndWall(slotA, slotB)
	return (slotA == "Floor" and slotB == "Wall") or (slotA == "Wall" and slotB == "Floor")
end

local function isFloorAndStair(slotA, slotB)
	return (slotA == "Floor" and slotB == "Stair") or (slotA == "Stair" and slotB == "Floor")
end

function BuildCollision.MakeDescriptor(config, pieceType, gridX, gridZ, level, rotation)
	if type(config) ~= "table" or type(config.Catalog) ~= "table" then
		return nil
	end
	if type(pieceType) ~= "string" then
		return nil
	end
	if not isFiniteNumber(gridX) or not isFiniteNumber(gridZ) or not isFiniteNumber(level) then
		return nil
	end

	local spec = config.Catalog[pieceType]
	local normalized = normalizeRotation(rotation)
	if not spec or normalized == nil then
		return nil
	end

	local sizeX, sizeZ = getRotatedFootprint(spec, normalized)
	return {
		Type = pieceType,
		Slot = spec.Slot,
		CenterX = gridX * config.GridSize,
		CenterZ = gridZ * config.GridSize,
		SizeX = sizeX,
		SizeZ = sizeZ,
		Level = math.floor(level),
		Rotation = normalized,
		Orientation = normalized % 2,
	}
end

function BuildCollision.IsInsideLot(config, lot, descriptor)
	if not lot or not descriptor then
		return false
	end

	local margin = tonumber(config.BoundaryMargin) or 0
	local maxX = lot.Size.X / 2 - margin
	local maxZ = lot.Size.Z / 2 - margin
	return math.abs(descriptor.CenterX) + descriptor.SizeX / 2 <= maxX
		and math.abs(descriptor.CenterZ) + descriptor.SizeZ / 2 <= maxZ
end

function BuildCollision.Conflicts(candidate, existing)
	if not candidate or not existing then
		return true
	end

	if candidate.Level ~= existing.Level then
		return false
	end

	local overlapX = overlapAmount(candidate.CenterX, candidate.SizeX, existing.CenterX, existing.SizeX)
	local overlapZ = overlapAmount(candidate.CenterZ, candidate.SizeZ, existing.CenterZ, existing.SizeZ)

	-- Encostar na borda é permitido. Só volume interno compartilhado conta como colisão.
	if overlapX <= EPSILON or overlapZ <= EPSILON then
		return false
	end

	local slotA = candidate.Slot
	local slotB = existing.Slot

	-- Piso e parede formam a estrutura do mesmo andar e podem coexistir.
	if isFloorAndWall(slotA, slotB) then
		return false
	end

	-- A escada pode nascer sobre o piso do andar de origem e terminar no piso seguinte.
	if isFloorAndStair(slotA, slotB) then
		return false
	end

	if slotA == "Wall" and slotB == "Wall" then
		-- Paredes perpendiculares podem se encontrar somente na ponta/canto.
		-- Isso permite L e T sem permitir uma parede atravessar outra pelo meio.
		if candidate.Orientation ~= existing.Orientation then
			local shallowOverlap = math.min(overlapX, overlapZ)
			local thickOverlap = math.max(overlapX, overlapZ)
			if shallowOverlap <= WALL_JOIN_END_TOLERANCE and thickOverlap <= WALL_JOIN_THICKNESS_TOLERANCE then
				return false
			end
		end
		return true
	end

	-- Piso com piso, escada com escada e escada atravessando parede são bloqueados.
	return true
end

function BuildCollision.HasConflict(config, candidate, entries)
	if not candidate or type(entries) ~= "table" then
		return true
	end

	for _, entry in ipairs(entries) do
		local descriptor = BuildCollision.MakeDescriptor(
			config,
			entry.Type,
			entry.GridX,
			entry.GridZ,
			entry.Level,
			entry.Rotation
		)
		if descriptor and BuildCollision.Conflicts(candidate, descriptor) then
			return true, entry
		end
	end

	return false, nil
end

return table.freeze(BuildCollision)
