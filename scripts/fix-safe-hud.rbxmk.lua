local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local starterGui = place:GetService("StarterGui")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

-- Remove the old Miner's Haven promotional/social banner itself, not only its text.
local removed = 0
local doomed = {}
local function legacyText(text)
	text = string.lower(tostring(text or ""))
	return text:find("bereza", 1, true)
		or text:find("twitch.tv", 1, true)
		or text:find("twitter", 1, true)
		or text:find("@bere", 1, true)
end

for _, instance in ipairs(starterGui:GetDescendants()) do
	if (instance:IsA("TextLabel") or instance:IsA("TextButton")) and legacyText(instance.Text) then
		local candidate = instance
		for _ = 1, 5 do
			local parent = candidate.Parent
			if not parent or parent == starterGui or parent:IsA("ScreenGui") then break end
			if parent:IsA("GuiObject") then
				local size = parent.Size
				if size.X.Scale >= 0.70 or size.X.Offset >= 700 then
					candidate = parent
				end
			end
		end
		doomed[candidate] = true
	end
end
for instance in pairs(doomed) do
	if instance and instance.Parent then
		instance:Destroy()
		removed += 1
	end
end

-- Also remove known thin, full-width legacy promo bars near the top.
for _, gui in ipairs(starterGui:GetChildren()) do
	if gui:IsA("ScreenGui") then
		for _, obj in ipairs(gui:GetChildren()) do
			if obj:IsA("GuiObject") then
				local size = obj.Size
				local pos = obj.Position
				local thin = (size.Y.Offset > 0 and size.Y.Offset <= 90) or (size.Y.Scale > 0 and size.Y.Scale <= 0.12)
				local wide = size.X.Scale >= 0.90 or size.X.Offset >= 900
				local top = pos.Y.Scale <= 0.08 and pos.Y.Offset <= 100
				local n = string.lower(obj.Name or "")
				if thin and wide and top and (n:find("banner",1,true) or n:find("social",1,true) or n:find("promo",1,true) or n:find("topbar",1,true)) then
					obj:Destroy()
					removed += 1
				end
			end
		end
	end
end

local old = starterPlayerScripts:FindFirstChild("MiningEmpireSafeHUD")
if old then old:Destroy() end

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireSafeHUD"
client.Source = [=[
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function legacyText(text)
	text = string.lower(tostring(text or ""))
	return text:find("bereza",1,true) or text:find("twitch.tv",1,true) or text:find("twitter",1,true) or text:find("@bere",1,true)
end

local function hideLegacyBanner()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and not string.find(gui.Name, "MiningEmpire", 1, true) then
			for _, desc in ipairs(gui:GetDescendants()) do
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and legacyText(desc.Text) then
					local candidate = desc
					for _ = 1, 5 do
						local parent = candidate.Parent
						if not parent or parent == gui then break end
						if parent:IsA("GuiObject") then
							local size = parent.Size
							if size.X.Scale >= 0.7 or size.X.Offset >= 700 then candidate = parent end
						end
					end
					if candidate:IsA("GuiObject") then candidate.Visible = false end
				end
			end
		end
	end
end

local function safeTop()
	local topLeft = GuiService:GetGuiInset()
	return math.max(8, topLeft.Y + 8)
end

local function layout()
	hideLegacyBanner()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 900
	local top = safeTop()

	local travelGui = playerGui:FindFirstChild("MiningEmpireTravelUI")
	if travelGui and travelGui:IsA("ScreenGui") then
		travelGui.IgnoreGuiInset = true
		travelGui.DisplayOrder = 50
		local frame = travelGui:FindFirstChildWhichIsA("Frame")
		if frame then
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.Position = UDim2.new(0.5, 0, 0, top)
			if width < 700 then
				frame.Size = UDim2.new(0, math.min(360, width - 24), 0, 42)
			else
				frame.Size = UDim2.fromOffset(370, 46)
			end
		end
	end

	local economyGui = playerGui:FindFirstChild("MiningEmpireMuseumEconomyUI")
	if economyGui and economyGui:IsA("ScreenGui") then
		economyGui.IgnoreGuiInset = true
		economyGui.DisplayOrder = 49
		local panel = economyGui:FindFirstChildWhichIsA("Frame")
		if panel then
			panel.AnchorPoint = Vector2.new(1,0)
			panel.Position = UDim2.new(1,-12,0,top + (width < 700 and 50 or 58))
			if width < 700 then panel.Size = UDim2.fromOffset(162,62) else panel.Size = UDim2.fromOffset(190,72) end
		end
	end
end

playerGui.ChildAdded:Connect(function()
	task.delay(0.15, layout)
end)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.delay(0.1, layout)
end)

task.defer(layout)
task.spawn(function()
	for _ = 1, 12 do
		task.wait(0.5)
		layout()
	end
end)
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print(string.format("[Mining Empire] safe HUD stage applied; legacy banners removed=%d", removed))
