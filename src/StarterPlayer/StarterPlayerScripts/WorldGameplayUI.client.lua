local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("MuseumWorldRemotes")
local getState=remotes:WaitForChild("GetWorldState")
local action=remotes:WaitForChild("WorldAction")

local gui=Instance.new("ScreenGui") gui.Name="MuseumWorldGameplayUI" gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")

local daily=Instance.new("Frame") daily.AnchorPoint=Vector2.new(1,0) daily.Position=UDim2.new(1,-16,0,90) daily.Size=UDim2.fromOffset(260,104) daily.BackgroundColor3=Color3.fromRGB(24,29,37) daily.Parent=gui
Instance.new("UICorner",daily).CornerRadius=UDim.new(0,14)
local ds=Instance.new("UIStroke") ds.Color=Color3.fromRGB(74,101,126) ds.Transparency=.35 ds.Parent=daily
local dt=Instance.new("TextLabel") dt.BackgroundTransparency=1 dt.Position=UDim2.fromOffset(12,8) dt.Size=UDim2.new(1,-24,0,25) dt.Font=Enum.Font.GothamBold dt.TextColor3=Color3.new(1,1,1) dt.TextSize=14 dt.TextXAlignment=Enum.TextXAlignment.Left dt.Text="🎯 OBJETIVO DIÁRIO" dt.Parent=daily
local dp=Instance.new("TextLabel") dp.BackgroundTransparency=1 dp.Position=UDim2.fromOffset(12,34) dp.Size=UDim2.new(1,-24,0,28) dp.Font=Enum.Font.GothamMedium dp.TextColor3=Color3.fromRGB(185,196,210) dp.TextSize=12 dp.TextXAlignment=Enum.TextXAlignment.Left dp.Parent=daily
local claim=Instance.new("TextButton") claim.Position=UDim2.fromOffset(12,66) claim.Size=UDim2.new(1,-24,0,30) claim.BackgroundColor3=Color3.fromRGB(55,111,79) claim.TextColor3=Color3.new(1,1,1) claim.Font=Enum.Font.GothamBold claim.TextSize=12 claim.Parent=daily
Instance.new("UICorner",claim).CornerRadius=UDim.new(0,9)

local tutorial=Instance.new("Frame") tutorial.AnchorPoint=Vector2.new(.5,1) tutorial.Position=UDim2.new(.5,0,1,-18) tutorial.Size=UDim2.new(.78,0,0,92) tutorial.BackgroundColor3=Color3.fromRGB(21,26,34) tutorial.Parent=gui
Instance.new("UICorner",tutorial).CornerRadius=UDim.new(0,15)
local limit=Instance.new("UISizeConstraint") limit.MinSize=Vector2.new(300,92) limit.MaxSize=Vector2.new(620,92) limit.Parent=tutorial
local tt=Instance.new("TextLabel") tt.BackgroundTransparency=1 tt.Position=UDim2.fromOffset(14,8) tt.Size=UDim2.new(1,-140,0,28) tt.Font=Enum.Font.GothamBold tt.TextSize=14 tt.TextColor3=Color3.fromRGB(245,247,250) tt.TextXAlignment=Enum.TextXAlignment.Left tt.Parent=tutorial
local ts=Instance.new("TextLabel") ts.BackgroundTransparency=1 ts.Position=UDim2.fromOffset(14,36) ts.Size=UDim2.new(1,-140,0,44) ts.Font=Enum.Font.Gotham ts.TextSize=12 ts.TextColor3=Color3.fromRGB(172,185,202) ts.TextWrapped=true ts.TextXAlignment=Enum.TextXAlignment.Left ts.TextYAlignment=Enum.TextYAlignment.Top ts.Parent=tutorial
local nextBtn=Instance.new("TextButton") nextBtn.AnchorPoint=Vector2.new(1,.5) nextBtn.Position=UDim2.new(1,-12,.5,0) nextBtn.Size=UDim2.fromOffset(110,48) nextBtn.BackgroundColor3=Color3.fromRGB(63,139,210) nextBtn.Text="CONCLUIR" nextBtn.TextColor3=Color3.new(1,1,1) nextBtn.Font=Enum.Font.GothamBold nextBtn.TextSize=12 nextBtn.Parent=tutorial
Instance.new("UICorner",nextBtn).CornerRadius=UDim.new(0,10)

local STEPS={
	[1]={"Bem-vindo ao Museum Empire","Conheça seu museu e use o botão VOLTAR AO MEU MUSEU quando quiser retornar."},
	[2]={"Construa seu espaço","Abra CONSTRUIR, escolha uma peça e personalize seu museu."},
	[3]={"Encontre artefatos","Use a mineração para encontrar itens e aumentar o prestígio."},
	[4]={"Monte sua exposição","Coloque artefatos nas vitrines para atrair visitantes e ganhar dinheiro."},
	[5]={"Gerencie a operação","Contrate funcionários, cuide da limpeza, segurança e loja."},
	[6]={"Seu império começou","Continue evoluindo estrelas, prestígio e ranking mundial."},
}
local busy=false
local function refresh()
	local ok,s=pcall(function() return getState:InvokeServer() end)
	if not ok or type(s)~="table" or not s.Ok then return end
	dp.Text=string.format("Receba 25 visitantes: %d/%d · prêmio $%s",s.DailyProgress,s.DailyTarget,tostring(s.DailyReward))
	claim.Text=s.DailyClaimed and "✓ RESGATADO" or (s.DailyProgress>=s.DailyTarget and "RESGATAR $5.000" or "EM PROGRESSO")
	claim.Active=not s.DailyClaimed and s.DailyProgress>=s.DailyTarget
	claim.BackgroundTransparency=claim.Active and 0 or .45
	tutorial.Visible=not s.TutorialDone
	if tutorial.Visible then local step=STEPS[s.TutorialStep] or STEPS[6] tt.Text=string.format("GUIA %d/6 · %s",s.TutorialStep,step[1]) ts.Text=step[2] end
end
local function doAction(name)
	if busy then return end busy=true
	pcall(function() action:InvokeServer({Action=name}) end)
	busy=false refresh()
end
claim.Activated:Connect(function() if claim.Active then doAction("ClaimDaily") end end)
nextBtn.Activated:Connect(function() doAction("AdvanceTutorial") end)
task.spawn(function() while task.wait(4) do refresh() end end)
refresh()
