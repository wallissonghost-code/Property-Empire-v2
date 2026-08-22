local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local MuseumConfig=require(ReplicatedStorage.Shared.MuseumConfig)

local VisitorService={}
local started=false
local rng=Random.new()

local function visitorModel(parent,cf)
	local m=Instance.new("Model") m.Name="MuseumVisitor" m.Parent=parent
	local root=Instance.new("Part") root.Name="Root" root.Size=Vector3.new(1,1,1) root.Transparency=1 root.Anchored=true root.CanCollide=false root.CFrame=cf root.Parent=m m.PrimaryPart=root
	local function body(name,size,offset,color)
		local p=Instance.new("Part") p.Name=name p.Size=size p.Color=color p.Material=Enum.Material.SmoothPlastic p.CanCollide=false p.CFrame=root.CFrame*CFrame.new(offset) p.Parent=m
		local w=Instance.new("WeldConstraint") w.Part0=root w.Part1=p w.Parent=p
	end
	local tone=Color3.fromHSV(rng:NextNumber(),0.45,0.85)
	body("Torso",Vector3.new(2,2.5,1),Vector3.new(0,1.8,0),tone)
	body("Head",Vector3.new(1.6,1.6,1.6),Vector3.new(0,3.8,0),Color3.fromRGB(220,181,145))
	body("LegL",Vector3.new(.8,2, .8),Vector3.new(-.55,-.2,0),Color3.fromRGB(40,45,55))
	body("LegR",Vector3.new(.8,2,.8),Vector3.new(.55,-.2,0),Color3.fromRGB(40,45,55))
	return m,root
end

local function tween(root,cf,time)
	local t=TweenService:Create(root,TweenInfo.new(time,Enum.EasingStyle.Linear),{CFrame=cf}) t:Play() t.Completed:Wait()
end

function VisitorService:Start(dataService,worldService,museumService)
	if started then return end started=true
	task.spawn(function()
		while task.wait(MuseumConfig.VisitorTickSeconds) do
			for _,owner in ipairs(museumService:GetOwners()) do
				local info=museumService:GetMuseumInfo(owner)
				if info and info.Score>0 then
					local chance=math.min(MuseumConfig.MaxVisitorChance,MuseumConfig.VisitorChanceBase+info.Score*MuseumConfig.VisitorChancePerScore)
					if rng:NextNumber()<chance then
						task.spawn(function()
							local m,root=visitorModel(worldService:GetWorld(),info.Entrance)
							tween(root,info.Inside,2.2)
							local revenue=math.min(MuseumConfig.MaxRevenuePerVisitor,math.floor(MuseumConfig.BaseVisitorRevenue+info.Score*MuseumConfig.RevenuePerScore))
							museumService:AwardVisit(owner,revenue)
							task.wait(rng:NextNumber(1.2,2.8))
							tween(root,info.Exit,1.8)
							m:Destroy()
						end)
					end
				end
			end
		end
	end)
	print("[Museum Empire] VisitorService started")
end

return VisitorService
