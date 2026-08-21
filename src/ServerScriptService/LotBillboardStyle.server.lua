local Workspace = game:GetService("Workspace")

local world = Workspace:WaitForChild("PropertyEmpireV2World")
local lotsFolder = world:WaitForChild("Lots")

local function compactLabelText(label)
	local text = label.Text
	local compact = text
		:gsub("\nPROPRIEDADE DE #", " · #")
		:gsub("\nDISPONÍVEL · ", " · ")
		:gsub("\nCOMPRA EM PROCESSAMENTO", " · PROCESSANDO")

	if compact ~= text then
		label.Text = compact
	end
end

local function styleLotBillboard(lot)
	if not lot:IsA("BasePart") then
		return
	end

	task.spawn(function()
		local billboard = lot:WaitForChild("StatusBillboard", 10)
		if not billboard or not billboard:IsA("BillboardGui") then
			return
		end

		billboard.Size = UDim2.fromOffset(170, 34)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 30
		billboard.StudsOffset = Vector3.new(
			-lot.Size.X / 2 + 9,
			2.2,
			lot.Size.Z / 2 - 7
		)

		local label = billboard:FindFirstChild("StatusLabel")
		if not label or not label:IsA("TextLabel") then
			return
		end

		label.TextScaled = false
		label.TextSize = 13
		label.TextWrapped = false
		label.BackgroundTransparency = 0.4
		compactLabelText(label)

		label:GetPropertyChangedSignal("Text"):Connect(function()
			compactLabelText(label)
		end)
	end)
end

for _, lot in ipairs(lotsFolder:GetChildren()) do
	styleLotBillboard(lot)
end

lotsFolder.ChildAdded:Connect(styleLotBillboard)

print("[Property Empire v2] Compact lot billboard styling enabled")
