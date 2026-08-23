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

local removed = 0
local function hasLegacyText(text)
	text = string.lower(tostring(text or ""))
	return string.find(text, "bereza", 1, true) ~= nil
		or string.find(text, "twitch.tv", 1, true) ~= nil
		or string.find(text, "@bere", 1, true) ~= nil
end

local doomed = {}
for _, inst in ipairs(starterGui:GetDescendants()) do
	if (inst.ClassName == "TextLabel" or inst.ClassName == "TextButton") and hasLegacyText(inst.Text) then
		local candidate = inst
		local parent = candidate.Parent
		while parent and parent ~= starterGui and parent.ClassName ~= "ScreenGui" do
			if parent:IsA("GuiObject") then
				local size = parent.Size
				if size.X.Scale >= 0.7 or size.X.Offset >= 700 then
					candidate = parent
				end
			end
			parent = parent.Parent
		end
		doomed[candidate] = true
	end
end

for inst in pairs(doomed) do
	if inst and inst.Parent then
		inst:Destroy()
		removed = removed + 1
	end
end

local old = starterPlayerScripts:FindFirstChild("MiningEmpireSafeHUD")
if old then old:Destroy() end
local oldV2 = starterPlayerScripts:FindFirstChild("MiningEmpireSafeHUDV2")
if oldV2 then oldV2:Destroy() end

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireSafeHUDV2"
client.Source = [=[
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function legacyText(text)
	text = string.lower(tostring(text or ""))
	return string.find(text, "bereza", 1, true)
		or string.find(text, "twitch.tv", 1, true)
		or string.find(text, "@bere", 1, true)
end

local function hideLegacy()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and string.find(gui.Name, "MiningEmpire", 1, true) == nil then
			for _, desc in ipairs(gui:GetDescendants()) do
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and legacyText(desc.Text) then
					local candidate = desc
					local parent = candidate.Parent
					while parent and parent ~= gui do
						if parent:IsA("GuiObject") then
							local size = parent.Size
							if size.X.Scale >= 0.7 or size.X.Offset >= 700 then
								candidate = parent
							end
						end
						parent = parent.Parent
					end
					if candidate:IsA("GuiObject") then candidate.Visible = false end
				end
			end
		end
	end
end

local function getTopInset()
	local topLeft = GuiService:GetGuiInset()
	return math.max(10, topLeft.Y + 10)
end

local function apply()
	hideLegacy()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 900
	local top = getTopInset()

	local travelGui = playerGui:FindFirstChild("MiningEmpireTravelUI")
	if travelGui and travelGui:IsA("ScreenGui") then
		travelGui.IgnoreGuiInset = true
		travelGui.DisplayOrder = 60
		local frame = travelGui:FindFirstChildWhichIsA("Frame")
		if frame then
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.Position = UDim2.new(0.5, 0, 0, top)
			if width < 700 then
				frame.Size = UDim2.new(0, math.max(260, math.min(360, width - 24)), 0, 42)
			else
				frame.Size = UDim2.fromOffset(370, 46)
			end
		end
	end

	local economyGui = playerGui:FindFirstChild("MiningEmpireMuseumEconomyUI")
	if economyGui and economyGui:IsA("ScreenGui") then
		economyGui.IgnoreGuiInset = true
		economyGui.DisplayOrder = 59
		local panel = economyGui:FindFirstChildWhichIsA("Frame")
		if panel then
			panel.AnchorPoint = Vector2.new(1, 0)
			panel.Position = UDim2.new(1, -12, 0, top + (width < 700 and 50 or 58))
			if width < 700 then
				panel.Size = UDim2.fromOffset(162, 62)
			else
				panel.Size = UDim2.fromOffset(190, 72)
			end
		end
	end
end

playerGui.ChildAdded:Connect(function()
	task.delay(0.1, apply)
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.delay(0.1, apply)
end)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
end

task.defer(apply)
task.spawn(function()
	for _ = 1, 20 do
		task.wait(0.35)
		apply()
	end
end)
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print(string.format("[Mining Empire] safe HUD v2 applied; removed=%d", removed))
