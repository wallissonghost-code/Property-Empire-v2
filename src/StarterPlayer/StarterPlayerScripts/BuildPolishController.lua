local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BuildPolishController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentPreview = nil
local lastSnapKey = ""
local lastPreviewBlocked = false
local watchedLotFolders = {}
local started = false

local soundsFolder = nil
local uiClickSound = nil
local snapSound = nil
local placeSound = nil
local removeSound = nil
local errorSound = nil

local BUTTON_HOVER_SCALE = 1.018
local BUTTON_PRESS_SCALE = 0.965

local function tween(instance, duration, properties, easingStyle, easingDirection)
	if not instance or not instance.Parent then
		return nil
	end

	local animation = TweenService:Create(
		instance,
		TweenInfo.new(
			duration,
			easingStyle or Enum.EasingStyle.Quint,
			easingDirection or Enum.EasingDirection.Out
		),
		properties
	)
	animation:Play()
	return animation
end

local function ensureSounds()
	if soundsFolder and soundsFolder.Parent then
		return
	end

	soundsFolder = Instance.new("Folder")
	soundsFolder.Name = "PropertyEmpireBuildSounds"
	soundsFolder.Parent = SoundService

	local function makeSound(name, soundId, volume, playbackSpeed)
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = soundId
		sound.Volume = volume
		sound.PlaybackSpeed = playbackSpeed
		sound.Parent = soundsFolder
		return sound
	end

	-- Packaged Roblox sounds: no dependency on a third-party audio creator.
	uiClickSound = makeSound("UiClick", "rbxasset://sounds/clickfast.wav", 0.16, 1.18)
	snapSound = makeSound("MagneticSnap", "rbxasset://sounds/electronicpingshort.wav", 0.10, 1.55)
	placeSound = makeSound("PiecePlaced", "rbxasset://sounds/electronicpingshort.wav", 0.18, 1.08)
	removeSound = makeSound("PieceRemoved", "rbxasset://sounds/clickfast.wav", 0.14, 0.82)
	errorSound = makeSound("Blocked", "rbxasset://sounds/clickfast.wav", 0.12, 0.62)
end

local function play(sound)
	if not sound then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

local function addPanelPolish(panel)
	if panel:FindFirstChild("PremiumPolishAccent") then
		return
	end

	local accent = Instance.new("Frame")
	accent.Name = "PremiumPolishAccent"
	accent.Size = UDim2.new(0, 3, 1, -24)
	accent.Position = UDim2.fromOffset(0, 12)
	accent.BorderSizePixel = 0
	accent.BackgroundColor3 = Color3.fromRGB(76, 190, 232)
	accent.BackgroundTransparency = 0.18
	accent.ZIndex = panel.ZIndex + 3
	accent.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = accent

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(74, 222, 163)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(76, 190, 232)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 111, 230)),
	})
	gradient.Parent = accent

	local innerGlow = Instance.new("Frame")
	innerGlow.Name = "PremiumPolishGlow"
	innerGlow.Size = UDim2.new(1, -12, 0, 1)
	innerGlow.Position = UDim2.fromOffset(6, 68)
	innerGlow.BorderSizePixel = 0
	innerGlow.BackgroundColor3 = Color3.fromRGB(114, 209, 255)
	innerGlow.BackgroundTransparency = 0.62
	innerGlow.ZIndex = panel.ZIndex + 2
	innerGlow.Parent = panel
end

local function decorateButton(button)
	if button:FindFirstChild("PremiumInteractionScale") then
		return
	end

	local scale = Instance.new("UIScale")
	scale.Name = "PremiumInteractionScale"
	scale.Scale = 1
	scale.Parent = button

	local hovering = false
	local pressing = false

	local function targetScale()
		if pressing then
			return BUTTON_PRESS_SCALE
		end
		if hovering and not UserInputService.TouchEnabled then
			return BUTTON_HOVER_SCALE
		end
		return 1
	end

	local function animateScale(duration)
		tween(scale, duration or 0.10, { Scale = targetScale() })
	end

	button.MouseEnter:Connect(function()
		hovering = true
		animateScale(0.10)
	end)

	button.MouseLeave:Connect(function()
		hovering = false
		pressing = false
		animateScale(0.12)
	end)

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressing = true
			animateScale(0.055)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressing = false
			animateScale(0.11)
		end
	end)

	button.Activated:Connect(function()
		play(uiClickSound)
	end)
end

local function decorateGui(gui)
	local buildPanel = gui:FindFirstChild("BuildPanel")
	if not buildPanel or not buildPanel:IsA("Frame") then
		return
	end

	addPanelPolish(buildPanel)

	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("TextButton") then
			decorateButton(descendant)
		end
	end

	gui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextButton") then
			decorateButton(descendant)
		end
	end)

	local lastVisible = buildPanel.Visible
	buildPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if buildPanel.Visible and not lastVisible then
			play(snapSound)
			local accent = buildPanel:FindFirstChild("PremiumPolishAccent")
			if accent and accent:IsA("Frame") then
				accent.BackgroundTransparency = 0.02
				tween(accent, 0.45, { BackgroundTransparency = 0.18 })
			end
		end
		lastVisible = buildPanel.Visible
	end)
end

local function findAdorneePart(root)
	if root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") then
		return root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function flashPlacedPiece(root)
	if not root or not root.Parent then
		return
	end

	local adornee = findAdorneePart(root)
	if not adornee then
		return
	end

	play(placeSound)

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlacementConfirmation"
	highlight.Adornee = root
	highlight.FillColor = Color3.fromRGB(74, 222, 163)
	highlight.FillTransparency = 0.68
	highlight.OutlineColor = Color3.fromRGB(202, 255, 226)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlacementConfirmationLabel"
	billboard.Size = UDim2.fromOffset(126, 32)
	billboard.StudsOffset = Vector3.new(0, math.max(2.5, adornee.Size.Y / 2 + 1.5), 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(24, 70, 50)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Text = "COLOCADO  ✓"
	label.TextColor3 = Color3.fromRGB(209, 255, 229)
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 232, 163)
	stroke.Transparency = 0.18
	stroke.Thickness = 1
	stroke.Parent = label

	task.delay(0.18, function()
		if highlight.Parent then
			tween(highlight, 0.42, { FillTransparency = 1, OutlineTransparency = 1 })
		end
		if label.Parent then
			tween(label, 0.42, {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			})
		end
		if stroke.Parent then
			tween(stroke, 0.42, { Transparency = 1 })
		end
	end)

	task.delay(0.68, function()
		if highlight then
			highlight:Destroy()
		end
		if billboard then
			billboard:Destroy()
		end
	end)
end

local function watchLotFolder(folder)
	if watchedLotFolders[folder] then
		return
	end
	watchedLotFolders[folder] = true

	folder.ChildAdded:Connect(function(root)
		task.defer(function()
			if not root.Parent then
				return
			end
			local createdBy = root:GetAttribute("CreatedBy")
			if createdBy == player.UserId then
				flashPlacedPiece(root)
			end
		end)
	end)

	folder.ChildRemoved:Connect(function(root)
		local createdBy = root:GetAttribute("CreatedBy")
		if createdBy == player.UserId then
			play(removeSound)
		end
	end)
end

local function watchBuilds()
	task.spawn(function()
		local world = workspace:WaitForChild("PropertyEmpireV2World", 60)
		if not world then
			return
		end
		local builds = world:WaitForChild("Builds", 60)
		if not builds then
			return
		end

		for _, lotFolder in ipairs(builds:GetChildren()) do
			if lotFolder:IsA("Folder") then
				watchLotFolder(lotFolder)
			end
		end

		builds.ChildAdded:Connect(function(lotFolder)
			if lotFolder:IsA("Folder") then
				watchLotFolder(lotFolder)
			end
		end)
	end)
end

local function pulsePreviewLabel(preview)
	local billboard = preview:FindFirstChild("SnapStatus")
	local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel")
	if not label then
		return
	end

	local originalSize = label.Size
	label.Size = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset + 8,
		originalSize.Y.Scale,
		originalSize.Y.Offset + 4
	)
	tween(label, 0.16, { Size = originalSize }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function updatePreviewFeedback()
	local visuals = workspace:FindFirstChild("PropertyEmpireLocalBuildVisuals")
	local preview = visuals and visuals:FindFirstChild("BuildPreview")
	if not preview or not preview:IsA("BasePart") or preview.Transparency >= 0.98 then
		currentPreview = nil
		lastSnapKey = ""
		lastPreviewBlocked = false
		return
	end

	if currentPreview ~= preview then
		currentPreview = preview
		lastSnapKey = ""
		lastPreviewBlocked = preview:GetAttribute("SnapBlocked") == true
	end

	local blocked = preview:GetAttribute("SnapBlocked") == true
	local connectionKind = tostring(preview:GetAttribute("SnapConnectionKind") or "Grid")
	local gridX = tonumber(preview:GetAttribute("SnapGridX")) or 0
	local gridZ = tonumber(preview:GetAttribute("SnapGridZ")) or 0
	local magnetic = connectionKind ~= "Grid"
	local snapKey = string.format("%s:%d:%d", connectionKind, gridX, gridZ)

	if magnetic and not blocked and snapKey ~= lastSnapKey then
		play(snapSound)
		pulsePreviewLabel(preview)
	end

	if blocked and not lastPreviewBlocked then
		play(errorSound)
	end

	lastPreviewBlocked = blocked
	lastSnapKey = snapKey
end

function BuildPolishController:Start()
	if started then
		return
	end
	started = true

	ensureSounds()
	watchBuilds()

	task.spawn(function()
		local existing = playerGui:FindFirstChild("PropertyEmpireBuildGui")
		if existing and existing:IsA("ScreenGui") then
			decorateGui(existing)
			return
		end

		local gui = playerGui:WaitForChild("PropertyEmpireBuildGui", 30)
		if gui and gui:IsA("ScreenGui") then
			decorateGui(gui)
		end
	end)

	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "PropertyEmpireBuildGui" and child:IsA("ScreenGui") then
			task.defer(function()
				decorateGui(child)
			end)
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < 0.05 then
			return
		end
		accumulator = 0
		updatePreviewFeedback()
	end)

	print("[Property Empire v2] BuildPolishController started")
end

return BuildPolishController
