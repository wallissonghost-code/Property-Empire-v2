local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BusinessConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessConfig"))

local BusinessController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openCityHall = remotes:WaitForChild("OpenCityHall")
local getBusinessState = remotes:WaitForChild("GetBusinessState")
local licenseBusiness = remotes:WaitForChild("LicenseBusiness")

local gui = nil
local panel = nil
local cashLabel = nil
local statusLabel = nil
local lotList = nil
local typeList = nil
local licenseButton = nil
local selectedLotId = nil
local selectedBusinessType = nil
local currentState = nil
local lotButtons = {}
local typeButtons = {}
local submitting = false

local COLORS = {
	Panel = Color3.fromRGB(24, 28, 34),
	PanelSoft = Color3.fromRGB(31, 36, 44),
	Button = Color3.fromRGB(43, 50, 60),
	Selected = Color3.fromRGB(54, 111, 164),
	Ready = Color3.fromRGB(48, 113, 75),
	Warning = Color3.fromRGB(119, 84, 42),
	Licensed = Color3.fromRGB(79, 64, 117),
	Text = Color3.fromRGB(243, 245, 247),
	Muted = Color3.fromRGB(164, 174, 187),
	Error = Color3.fromRGB(255, 151, 151),
	Success = Color3.fromRGB(145, 224, 170),
}

local function formatMoney(value)
	local formatted = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return "$" .. formatted
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeStroke(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(67, 76, 89)
	stroke.Thickness = 1
	stroke.Parent = parent
end

local function makeLabel(parent, text, size, position, textSize, bold)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = COLORS.Text
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size)
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = COLORS.Button
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.TextSize = 13
	button.TextWrapped = true
	button.Font = Enum.Font.GothamSemibold
	button.AutoButtonColor = true
	button.Parent = parent
	makeCorner(button, 8)
	makeStroke(button)
	return button
end

local function setStatus(text, isError)
	if not statusLabel then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = isError and COLORS.Error or COLORS.Muted
end

local function clearButtons(buttonMap)
	for _, button in pairs(buttonMap) do
		button:Destroy()
	end
	table.clear(buttonMap)
end

local function findLotState(lotId)
	if not currentState or type(currentState.Lots) ~= "table" then
		return nil
	end
	for _, lotState in ipairs(currentState.Lots) do
		if lotState.LotId == lotId then
			return lotState
		end
	end
	return nil
end

local function updateLicenseButton()
	if not licenseButton then
		return
	end

	local lotState = selectedLotId and findLotState(selectedLotId) or nil
	local canLicense = lotState
		and lotState.Build
		and lotState.Build.Ready
		and not lotState.Business
		and selectedBusinessType ~= nil
		and not submitting

	licenseButton.Active = canLicense == true
	licenseButton.AutoButtonColor = canLicense == true
	licenseButton.BackgroundColor3 = canLicense and Color3.fromRGB(53, 135, 89) or Color3.fromRGB(67, 72, 79)

	if submitting then
		licenseButton.Text = "PROCESSANDO..."
	elseif canLicense then
		licenseButton.Text = "EMITIR LICENÇA · " .. formatMoney(BusinessConfig.LicenseFee)
	else
		licenseButton.Text = "SELECIONE LOTE E ATIVIDADE"
	end
end

local function updateLotSelectionVisuals()
	for lotId, button in pairs(lotButtons) do
		local lotState = findLotState(lotId)
		if lotId == selectedLotId then
			button.BackgroundColor3 = COLORS.Selected
		elseif lotState and lotState.Business then
			button.BackgroundColor3 = COLORS.Licensed
		elseif lotState and lotState.Build and lotState.Build.Ready then
			button.BackgroundColor3 = COLORS.Ready
		else
			button.BackgroundColor3 = COLORS.Warning
		end
	end
end

local function updateTypeSelectionVisuals()
	for businessType, button in pairs(typeButtons) do
		button.BackgroundColor3 = businessType == selectedBusinessType and COLORS.Selected or COLORS.Button
	end
end

local function selectLot(lotId)
	selectedLotId = lotId
	updateLotSelectionVisuals()
	updateLicenseButton()

	local lotState = findLotState(lotId)
	if not lotState then
		return
	end

	if lotState.Business then
		local spec = BusinessConfig.Types[lotState.Business.BusinessType]
		setStatus(
			string.format(
				"%s já está licenciado como %s · reputação %d",
				lotId,
				spec and spec.DisplayName or lotState.Business.BusinessType,
				lotState.Business.Reputation or 0
			),
			false
		)
	elseif lotState.Build and lotState.Build.Ready then
		setStatus(lotId .. " está pronto para receber uma licença empresarial.", false)
	elseif lotState.Build then
		setStatus(
			string.format(
				"%s ainda precisa de construção: %d/%d peças · %d/%d pisos · %d/%d paredes",
				lotId,
				lotState.Build.Pieces or 0,
				lotState.Build.MinimumPieces or 0,
				lotState.Build.Floors or 0,
				lotState.Build.MinimumFloors or 0,
				lotState.Build.Walls or 0,
				lotState.Build.MinimumWalls or 0
			),
			true
		)
	end
end

local function selectBusinessType(businessType)
	if not BusinessConfig.Types[businessType] then
		return
	end
	selectedBusinessType = businessType
	updateTypeSelectionVisuals()
	updateLicenseButton()
	local spec = BusinessConfig.Types[businessType]
	setStatus(spec.DisplayName .. " · " .. spec.Description, false)
end

local function rebuildLotList()
	clearButtons(lotButtons)

	if not currentState or type(currentState.Lots) ~= "table" or #currentState.Lots == 0 then
		local empty = makeLabel(lotList, "Você ainda não possui lotes.", UDim2.new(1, -12, 0, 46), UDim2.new(), 13, false)
		empty.Name = "EmptyState"
		empty.TextColor3 = COLORS.Muted
		return
	end

	for order, lotState in ipairs(currentState.Lots) do
		local text
		if lotState.Business then
			local spec = BusinessConfig.Types[lotState.Business.BusinessType]
			text = string.format("%s\nLICENCIADO · %s", lotState.LotId, spec and spec.DisplayName or lotState.Business.BusinessType)
		elseif lotState.Build and lotState.Build.Ready then
			text = string.format("%s\nPRONTO PARA LICENCIAR", lotState.LotId)
		else
			local pieces = lotState.Build and lotState.Build.Pieces or 0
			text = string.format("%s\nCONSTRUÇÃO %d/%d", lotState.LotId, pieces, BusinessConfig.MinimumBuildPieces)
		end

		local button = makeButton(lotList, text, UDim2.new(1, -10, 0, 58))
		button.LayoutOrder = order
		lotButtons[lotState.LotId] = button
		button.Activated:Connect(function()
			selectLot(lotState.LotId)
		end)
	end

	if selectedLotId and not findLotState(selectedLotId) then
		selectedLotId = nil
	end
	if not selectedLotId and currentState.Lots[1] then
		selectedLotId = currentState.Lots[1].LotId
	end
	updateLotSelectionVisuals()
end

local function rebuildTypeList()
	clearButtons(typeButtons)

	for order, businessType in ipairs(BusinessConfig.TypeOrder) do
		local spec = BusinessConfig.Types[businessType]
		if spec then
			local button = makeButton(
				typeList,
				string.format("%s\n%s", spec.DisplayName, string.upper(spec.Category)),
				UDim2.new(1, -10, 0, 58)
			)
			button.LayoutOrder = order
			typeButtons[businessType] = button
			button.Activated:Connect(function()
				selectBusinessType(businessType)
			end)
		end
	end

	if not selectedBusinessType then
		selectedBusinessType = BusinessConfig.TypeOrder[1]
	end
	updateTypeSelectionVisuals()
end

local function refreshState()
	setStatus("Consultando cadastro municipal...", false)
	local success, response = pcall(function()
		return getBusinessState:InvokeServer()
	end)

	if not success or type(response) ~= "table" or not response.Ok then
		currentState = nil
		setStatus(type(response) == "table" and response.Error or "Não foi possível consultar a Prefeitura.", true)
		updateLicenseButton()
		return false
	end

	currentState = response
	if cashLabel then
		cashLabel.Text = string.format("SALDO %s  ·  TAXA %s", formatMoney(response.Cash), formatMoney(response.LicenseFee))
	end
	rebuildLotList()
	rebuildTypeList()
	updateLicenseButton()

	if selectedLotId then
		selectLot(selectedLotId)
	end
	return true
end

local function submitLicense()
	if submitting or not selectedLotId or not selectedBusinessType then
		return
	end

	local lotState = findLotState(selectedLotId)
	if not lotState or lotState.Business or not lotState.Build or not lotState.Build.Ready then
		setStatus("Esse lote ainda não pode receber uma licença.", true)
		return
	end

	submitting = true
	updateLicenseButton()
	setStatus("Emitindo licença e registrando a empresa...", false)

	local success, response = pcall(function()
		return licenseBusiness:InvokeServer({
			LotId = selectedLotId,
			BusinessType = selectedBusinessType,
		})
	end)

	submitting = false
	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação com a Prefeitura.", true)
		updateLicenseButton()
		return
	end

	if not response.Ok then
		setStatus(response.Error or "A licença foi recusada.", true)
		refreshState()
		return
	end

	player:SetAttribute("Cash", response.Cash or player:GetAttribute("Cash"))
	setStatus(string.format("Licença emitida: %s em %s.", response.DisplayName or selectedBusinessType, response.LotId), false)
	refreshState()
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PropertyEmpireCityHallGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(8, 10, 13)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Parent = gui

	panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(720, 540)
	panel.Position = UDim2.new(0.5, -360, 0.5, -270)
	panel.BackgroundColor3 = COLORS.Panel
	panel.Parent = shade
	makeCorner(panel, 12)
	makeStroke(panel)

	makeLabel(panel, "PREFEITURA · LICENÇAS EMPRESARIAIS", UDim2.fromOffset(580, 34), UDim2.fromOffset(22, 14), 20, true)
	local subtitle = makeLabel(
		panel,
		"Transforme uma construção do seu lote em uma empresa oficial da cidade.",
		UDim2.fromOffset(610, 28),
		UDim2.fromOffset(22, 46),
		12,
		false
	)
	subtitle.TextColor3 = COLORS.Muted

	local closeButton = makeButton(panel, "✕", UDim2.fromOffset(42, 36))
	closeButton.Position = UDim2.new(1, -58, 0, 14)
	closeButton.TextSize = 18
	closeButton.Activated:Connect(function()
		gui.Enabled = false
	end)

	cashLabel = makeLabel(panel, "SALDO --", UDim2.fromOffset(420, 28), UDim2.fromOffset(22, 78), 13, true)
	cashLabel.TextColor3 = COLORS.Success

	makeLabel(panel, "SEU LOTE", UDim2.fromOffset(290, 22), UDim2.fromOffset(22, 116), 11, true).TextColor3 = COLORS.Muted
	makeLabel(panel, "ATIVIDADE", UDim2.fromOffset(350, 22), UDim2.fromOffset(348, 116), 11, true).TextColor3 = COLORS.Muted

	lotList = Instance.new("ScrollingFrame")
	lotList.Size = UDim2.fromOffset(300, 294)
	lotList.Position = UDim2.fromOffset(22, 140)
	lotList.BackgroundColor3 = COLORS.PanelSoft
	lotList.BorderSizePixel = 0
	lotList.ScrollBarThickness = 5
	lotList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lotList.CanvasSize = UDim2.new()
	lotList.Parent = panel
	makeCorner(lotList, 8)

	local lotPadding = Instance.new("UIPadding")
	lotPadding.PaddingLeft = UDim.new(0, 8)
	lotPadding.PaddingRight = UDim.new(0, 8)
	lotPadding.PaddingTop = UDim.new(0, 8)
	lotPadding.PaddingBottom = UDim.new(0, 8)
	lotPadding.Parent = lotList
	local lotLayout = Instance.new("UIListLayout")
	lotLayout.Padding = UDim.new(0, 8)
	lotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lotLayout.Parent = lotList

	typeList = Instance.new("ScrollingFrame")
	typeList.Size = UDim2.fromOffset(350, 294)
	typeList.Position = UDim2.fromOffset(348, 140)
	typeList.BackgroundColor3 = COLORS.PanelSoft
	typeList.BorderSizePixel = 0
	typeList.ScrollBarThickness = 5
	typeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	typeList.CanvasSize = UDim2.new()
	typeList.Parent = panel
	makeCorner(typeList, 8)

	local typePadding = Instance.new("UIPadding")
	typePadding.PaddingLeft = UDim.new(0, 8)
	typePadding.PaddingRight = UDim.new(0, 8)
	typePadding.PaddingTop = UDim.new(0, 8)
	typePadding.PaddingBottom = UDim.new(0, 8)
	typePadding.Parent = typeList
	local typeLayout = Instance.new("UIListLayout")
	typeLayout.Padding = UDim.new(0, 8)
	typeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	typeLayout.Parent = typeList

	statusLabel = makeLabel(panel, "Use o balcão da Prefeitura para consultar seu cadastro.", UDim2.fromOffset(676, 46), UDim2.fromOffset(22, 442), 12, false)
	statusLabel.TextColor3 = COLORS.Muted

	licenseButton = makeButton(panel, "SELECIONE LOTE E ATIVIDADE", UDim2.fromOffset(676, 42))
	licenseButton.Position = UDim2.fromOffset(22, 486)
	licenseButton.BackgroundColor3 = Color3.fromRGB(67, 72, 79)
	licenseButton.Activated:Connect(submitLicense)
end

function BusinessController:Open()
	gui.Enabled = true
	refreshState()
end

function BusinessController:Start()
	createGui()
	openCityHall.OnClientEvent:Connect(function()
		self:Open()
	end)
	print("[Property Empire v2] BusinessController started")
end

return BusinessController
