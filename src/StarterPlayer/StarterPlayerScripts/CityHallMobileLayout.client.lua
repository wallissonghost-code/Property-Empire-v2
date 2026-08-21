local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("PropertyEmpireCityHallGui", 60)

if not gui then
	warn("[Property Empire v2] Mobile City Hall layout could not find the GUI")
	return
end

local function startsWith(value, prefix)
	return type(value) == "string" and string.sub(value, 1, #prefix) == prefix
end

local function findUiParts()
	local shade = nil
	local panel = nil

	for _ = 1, 120 do
		shade = gui:FindFirstChildWhichIsA("Frame")
		panel = shade and shade:FindFirstChildWhichIsA("Frame") or nil

		if panel then
			local scrollingCount = 0
			for _, child in ipairs(panel:GetChildren()) do
				if child:IsA("ScrollingFrame") then
					scrollingCount += 1
				end
			end

			if scrollingCount >= 2 then
				break
			end
		end

		task.wait(0.05)
	end

	if not panel then
		return nil
	end

	local scrollingFrames = {}
	local titleLabel = nil
	local subtitleLabel = nil
	local cashLabel = nil
	local lotHeader = nil
	local activityHeader = nil
	local statusLabel = nil
	local closeButton = nil
	local licenseButton = nil

	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("ScrollingFrame") then
			table.insert(scrollingFrames, child)
		elseif child:IsA("TextLabel") then
			if startsWith(child.Text, "PREFEITURA") then
				titleLabel = child
			elseif startsWith(child.Text, "Transforme") then
				subtitleLabel = child
			elseif startsWith(child.Text, "SALDO") then
				cashLabel = child
			elseif child.Text == "SEU LOTE" then
				lotHeader = child
			elseif child.Text == "ATIVIDADE" then
				activityHeader = child
			else
				statusLabel = child
			end
		elseif child:IsA("TextButton") then
			if child.Text == "✕" then
				closeButton = child
			else
				licenseButton = child
			end
		end
	end

	table.sort(scrollingFrames, function(a, b)
		return a.Position.X.Offset < b.Position.X.Offset
	end)

	if #scrollingFrames < 2 or not licenseButton then
		return nil
	end

	return {
		Panel = panel,
		Title = titleLabel,
		Subtitle = subtitleLabel,
		Cash = cashLabel,
		LotHeader = lotHeader,
		ActivityHeader = activityHeader,
		Status = statusLabel,
		Close = closeButton,
		License = licenseButton,
		LotList = scrollingFrames[1],
		TypeList = scrollingFrames[2],
	}
end

local parts = findUiParts()
if not parts then
	warn("[Property Empire v2] Mobile City Hall layout could not resolve UI parts")
	return
end

parts.Panel.Name = "CityHallPanel"
parts.LotList.Name = "LotList"
parts.TypeList.Name = "BusinessTypeList"
parts.License.Name = "LicenseButton"

local sizeConstraint = parts.Panel:FindFirstChild("MobileSizeConstraint")
if not sizeConstraint then
	sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.Name = "MobileSizeConstraint"
	sizeConstraint.MaxSize = Vector2.new(560, 720)
	sizeConstraint.Parent = parts.Panel
end

parts.Panel.AnchorPoint = Vector2.new(0.5, 0.5)
parts.Panel.Position = UDim2.fromScale(0.5, 0.5)
parts.Panel.Size = UDim2.new(0.92, 0, 0.88, 0)

if parts.Subtitle then
	parts.Subtitle.Visible = false
end

if parts.Title then
	parts.Title.Text = "PREFEITURA · LICENÇAS"
	parts.Title.TextSize = 16
end

if parts.Cash then
	parts.Cash.TextSize = 12
end

if parts.Close then
	parts.Close.Size = UDim2.fromOffset(36, 32)
	parts.Close.TextSize = 16
end

parts.LotList.ScrollBarThickness = 4
parts.TypeList.ScrollBarThickness = 4

local applying = false

local function applyLayout()
	if applying or not parts.Panel.Parent then
		return
	end
	applying = true

	local panelHeight = math.max(280, parts.Panel.AbsoluteSize.Y)
	local compact = panelHeight < 430

	local horizontalPadding = 12
	local titleY = compact and 6 or 10
	local cashY = compact and 36 or 48
	local lotHeaderY = compact and 58 or 76
	local lotListY = lotHeaderY + 20
	local lotHeight = compact and 58 or math.clamp(math.floor(panelHeight * 0.16), 74, 100)
	local activityHeaderY = lotListY + lotHeight + (compact and 5 or 10)
	local typeListY = activityHeaderY + 20
	local footerHeight = compact and 94 or 110
	local footerTop = panelHeight - footerHeight
	local typeHeight = math.max(54, footerTop - typeListY - 8)

	if parts.Title then
		parts.Title.Position = UDim2.fromOffset(horizontalPadding, titleY)
		parts.Title.Size = UDim2.new(1, -64, 0, 28)
	end

	if parts.Close then
		parts.Close.Position = UDim2.new(1, -46, 0, titleY)
	end

	if parts.Cash then
		parts.Cash.Position = UDim2.fromOffset(horizontalPadding, cashY)
		parts.Cash.Size = UDim2.new(1, -24, 0, 22)
	end

	if parts.LotHeader then
		parts.LotHeader.Position = UDim2.fromOffset(horizontalPadding, lotHeaderY)
		parts.LotHeader.Size = UDim2.new(1, -24, 0, 18)
	end

	parts.LotList.Position = UDim2.fromOffset(horizontalPadding, lotListY)
	parts.LotList.Size = UDim2.new(1, -24, 0, lotHeight)

	if parts.ActivityHeader then
		parts.ActivityHeader.Position = UDim2.fromOffset(horizontalPadding, activityHeaderY)
		parts.ActivityHeader.Size = UDim2.new(1, -24, 0, 18)
	end

	parts.TypeList.Position = UDim2.fromOffset(horizontalPadding, typeListY)
	parts.TypeList.Size = UDim2.new(1, -24, 0, typeHeight)

	if parts.Status then
		parts.Status.Position = UDim2.new(0, horizontalPadding, 1, compact and -88 or -100)
		parts.Status.Size = UDim2.new(1, -24, 0, compact and 36 or 42)
		parts.Status.TextSize = compact and 10 or 11
	end

	parts.License.Position = UDim2.new(0, horizontalPadding, 1, compact and -46 or -52)
	parts.License.Size = UDim2.new(1, -24, 0, compact and 38 or 42)
	parts.License.TextSize = compact and 11 or 12

	applying = false
end

RunService.Heartbeat:Wait()
applyLayout()

parts.Panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(applyLayout)
end)

print("[Property Empire v2] Mobile City Hall layout enabled")
