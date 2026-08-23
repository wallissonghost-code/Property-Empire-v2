local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AssetLibrary = require(ReplicatedStorage.Shared.AssetLibrary)

local AssetImportService = {}
local started = false
local libraryFolder

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local function sanitize(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if SCRIPT_CLASSES[descendant.ClassName] then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
			descendant.CanQuery = true
		end
	end
end

local function normalizeAssetContainer(container, key, spec)
	local model = Instance.new("Model")
	model.Name = key
	model:SetAttribute("Source", "RobloxCreatorStore")
	model:SetAttribute("AssetId", spec.AssetId)
	model:SetAttribute("Category", spec.Category or "Other")
	model:SetAttribute("DisplayName", spec.Name or key)

	for _, child in ipairs(container:GetChildren()) do
		child.Parent = model
	end
	container:Destroy()
	sanitize(model)
	return model
end

local function loadCreatorAsset(key, spec)
	if not spec.Enabled then return false, "disabled" end
	local ok, loaded = pcall(function()
		return InsertService:LoadAsset(spec.AssetId)
	end)
	if not ok or not loaded then
		return false, tostring(loaded)
	end

	local model = normalizeAssetContainer(loaded, key, spec)
	model.Parent = libraryFolder
	return true, model
end

function AssetImportService:GetLibraryFolder()
	return libraryFolder
end

function AssetImportService:GetClone(key)
	if not libraryFolder then return nil end
	local asset = libraryFolder:FindFirstChild(key)
	return asset and asset:Clone() or nil
end

function AssetImportService:Start()
	if started then return end
	started = true

	local existing = ServerStorage:FindFirstChild("MuseumAssetLibrary")
	if existing then existing:Destroy() end
	libraryFolder = Instance.new("Folder")
	libraryFolder.Name = "MuseumAssetLibrary"
	libraryFolder.Parent = ServerStorage

	local loadedCount = 0
	for key, spec in pairs(AssetLibrary.CreatorStore) do
		local ok, result = loadCreatorAsset(key, spec)
		if ok then
			loadedCount += 1
		else
			warn(string.format("[Museum Empire] Asset %s (%s) could not be loaded: %s", key, tostring(spec.AssetId), tostring(result)))
		end
	end

	print(string.format("[Museum Empire] AssetImportService ready — %d sanitized Creator Store assets cached", loadedCount))
end

return AssetImportService
