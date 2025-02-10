--// By @ThatOneTusk
-- This code is NOT intended for others' usage, hence the lack of dependencies provided (Remotes, utilities, etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = game:GetService("Players").LocalPlayer

local UiMain = player.PlayerGui:WaitForChild("LobbyGUI").UnitIndex
local MainFrame = UiMain.Page.MainFrame
local LevelFrame = MainFrame.LevelFrame
local UnitList = MainFrame.List
local Options = MainFrame.Options
local FilterButton = Options.FilterButton

local UnitTemplate = script.UnitTemplate
local RewardTemplate = script.RewardTemplate
local UiCommunication = ReplicatedStorage.Events.UiCommunication

local Notify = require(ReplicatedStorage.Libs.NotificationLib)
local UIMotion = require(ReplicatedStorage.Libs.UIMotion)
local UIUtility = require(ReplicatedStorage.Libs.UtilitiesUI)
local IndexRegistry = require(ReplicatedStorage.Registry.IndexData)
local GameFunctions = require(ReplicatedStorage.Libs.GameFunctions)
local GradientRegistry = _G.Registry.registry.GradientAnimations
local Maid = _G.Maid["shared"]

----DATA---------
local DataAccess = require(ReplicatedStorage.Libs.DataAccessAPIClient)
local DataAPI = DataAccess:GetAPI()
local PlrProfileClass = DataAPI:GetLocalProfileClass()

local FilteredBy = "All"
local TotalSorted = {}

local UnitIndex = {}

local UpdateGradients: {[any]: {Gradient: UIGradient, Speed: number, UseOffset: boolean?}} = {
	[1] = {
		Gradient = UiMain.Page.UIStroke.UIGradient;
		Speed = 1.25;
	};
	
	[2] = {
		Gradient = UiMain.MainGlow.UIGradient;
		Speed = 1.25;
	};
	
	[3] = {
		Gradient = LevelFrame.UIStroke.UIGradient;
		Speed = 1.25;
	};
	
	[4] = {
		Gradient = LevelFrame.NextLevel.UIStroke.UIGradient;
		Speed = 1.25;
	};
}

local LayoutOrders = {
	["Exclusive"] = 0,
	["Secret"] = 1,
	["Mythical"] = 2, 
	["Legendary"] = 3,
	["Epic"] = 4,
	["Rare"] = 5
}

Maid:StartTree("UnitIndex")


--//
function UnitIndex:FilterBy(Filter: string)
	FilterButton.FilteredBy.Text = `Filtered by: {Filter}`
	FilteredBy = Filter
	
	for _, unit in UnitList:GetChildren() do
		if not unit:GetAttribute("Rarity") then continue end
		
		unit.Visible = Filter == "All" or unit:GetAttribute("Rarity") == Filter
	end
	
	for _, tab in FilterButton.List:GetChildren() do
		if not tab:IsA("ImageButton") then continue end
		
		if tab.Name ~= Filter then
			tab.BackgroundColor3 = Color3.fromRGB(15,15,15)
		else
			tab.BackgroundColor3 = Color3.fromRGB(30,30,30)
		end
	end
	
	if TotalSorted[Filter] then
		UiMain.DiscoveredUnits.Text = `Discovered Units: <font color="rgb(26, 255, 0)">{TotalSorted[Filter].Discovered}/{TotalSorted[Filter].Total}</font>`
	else
		UiMain.DiscoveredUnits.Text = `Discovered Units: <font color="rgb(26, 255, 0)">{TotalSorted.TotalDiscovered}/{TotalSorted.TotalUnits}</font>`
	end
	
	if not GradientRegistry[FilteredBy] then
		FilterButton.FilteredBy.UIGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	end
end


--// 
function UnitIndex:ToggleDropDown()
	if FilterButton.List.Visible then
		FilterButton.List.Visible = false
		TweenService:Create(FilterButton.Arrow, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Rotation = 0}):Play()
	else
		FilterButton.List.Position = UDim2.fromScale(0.5, 0.8)
		FilterButton.List.Visible = true
		
		TweenService:Create(FilterButton.List, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = UDim2.fromScale(0.5, 1)}):Play()
		TweenService:Create(FilterButton.Arrow, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Rotation = 180}):Play()
	end
end


--//
function UnitIndex:LoadUnits()
	local UnlockedUnits = PlrProfileClass:GetField("IndexData").UnlockedUnits
	
	UnitIndex:ClearUnits()
	table.clear(TotalSorted)
	
	TotalSorted.TotalUnits = 0
	TotalSorted.TotalDiscovered = 0
	
	for _, UnitObject in ReplicatedStorage.Registry.Units:GetChildren() do
		if not UnitObject:IsA("ModuleScript") then continue end
		if not UnitObject:FindFirstChild("Released") or not UnitObject.Released.Value then continue end
		
		local UnitName, Unit = UnitObject.Name, require(UnitObject)
		local Rarity = Unit.configuration.Rarity
		
		if not TotalSorted[Rarity] then
			TotalSorted[Rarity] = {
				Discovered = 0;
				Total = 0;
			}
		end
		
		local NewUnit = UnitList:FindFirstChild(UnitName)
		local UnitMainFrame = NewUnit and NewUnit.MainFrame
		local JustCreated;
		
		if not NewUnit then
			NewUnit = UnitTemplate:Clone()
			UnitMainFrame = NewUnit.MainFrame
			JustCreated = true

			NewUnit:SetAttribute("Rarity", Rarity)
			NewUnit:SetAttribute("DisplayName", Unit.configuration.DisplayName)
			NewUnit.Name = UnitName

			NewUnit.LayoutOrder = LayoutOrders[Rarity]
			NewUnit.Parent = UnitList
		end
		
		NewUnit.Visible = FilteredBy == "All" or Rarity == FilteredBy		
		UnitMainFrame.ObtainedAt.Visible = UnlockedUnits[UnitName]
		
		UIMotion:RegisterUnitViewportFrame({UnitName = UnitName}, (JustCreated and UnitMainFrame.ViewportFrame), {
			GradientParent = UnitMainFrame.Icon;
			NameParent = UnitMainFrame.UnitName;
			ClassID = "UnitIndexFrames";
		})
		
		UIMotion:RegisterHover(UnitMainFrame.Hover, UnitMainFrame.Size, {
			Percent = 9;
			toIncrease = UnitMainFrame;
			UUID = UnitName;
			TreeUUID = "UnitIndex";
			
			callBackIn = function()
				TweenService:Create(UnitMainFrame.UnitName.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(0, 0, 0)}):Play()
				TweenService:Create(UnitMainFrame.ObtainedAt.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(0, 0, 0)}):Play()
			end,
			
			callBackOut = function()
				TweenService:Create(UnitMainFrame.UnitName.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(65, 65, 65)}):Play()
				TweenService:Create(UnitMainFrame.ObtainedAt.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(65, 65, 65)}):Play()
			end,
		})
		
		if UnlockedUnits[UnitName] then
			local ObtainedAt = os.date("*t", UnlockedUnits[UnitName].ObtainedAt)
			
			TotalSorted[Rarity].Discovered += 1
			TotalSorted.TotalDiscovered += 1
			UnitMainFrame.ObtainedAt.Text = ObtainedAt and `Obtained At: {ObtainedAt.year}-{ObtainedAt.month}-{ObtainedAt.day}` or "Couldn't find obtain time!"
			UnitMainFrame.ViewportFrame.ImageColor3 = Color3.fromRGB(255, 255, 255)
		else
			UnitMainFrame.ViewportFrame.ImageColor3 = Color3.fromRGB(0, 0, 0)
			UnitMainFrame.UnitName.Text = "???"
		end
		
		TotalSorted[Rarity].Total += 1
		TotalSorted.TotalUnits += 1
	end
	
	if TotalSorted[FilteredBy] then
		UiMain.DiscoveredUnits.Text = `Discovered Units: <font color="rgb(26, 255, 0)">{TotalSorted[FilteredBy].Discovered}/{TotalSorted[FilteredBy].Total}</font>`
	else
		UiMain.DiscoveredUnits.Text = `Discovered Units: <font color="rgb(26, 255, 0)">{TotalSorted.TotalDiscovered}/{TotalSorted.TotalUnits}</font>`
	end
end


--//
function UnitIndex:UpdateLevelFrame()
	local IndexData = PlrProfileClass:GetField("IndexData")
	local IndexLevel = IndexData.IndexLevel
	local IndexXP = IndexData.IndexXP
	local RequiredXP = GameFunctions:CalculateIndexEXPFromLevel(IndexLevel)
	local ClaimedRewards = IndexData.ClaimedLevelRewards
	
	UnitIndex:ClearRewardDisplay()
	
	LevelFrame.Level.Text = `Level {IndexLevel}`
	LevelFrame.XP.Text = `{UIUtility:format_int(IndexXP)}/{UIUtility:format_int(RequiredXP)} XP`
	LevelFrame.XPBar.XPBarProgress.Size = UDim2.fromScale(math.min(IndexXP/RequiredXP,1), 1)
	LevelFrame.NextLevel.Level.Text = `Level {IndexLevel + 1}`
	
	local Unclaimed;
	
	for i = 1, IndexLevel do
		if not table.find(ClaimedRewards, i) then
			Unclaimed = true
			break
		end
	end
	
	LevelFrame.ClaimPrizes.Visible = Unclaimed
	
	local DisplayReward = IndexRegistry:GetRewardsForLevel(IndexLevel + 1)
	
	for category, value in DisplayReward do
		if type(value) ~= "table" then continue end
		
		for item, amount in value do
			local NewFrame = RewardTemplate:Clone()
			
			NewFrame:SetAttribute("Added", true)
			NewFrame.Name = item
			NewFrame.Parent = LevelFrame.NextLevel.RewardBox
			
			UIMotion:RegisterRewardFrame({
				Name = item;
				Amount = amount;
				Type = category;
			}, {
				CountParent = NewFrame.Amount;
				NameParent = NewFrame.ItemName;
				IconParent = NewFrame.ItemIcon;
				GradientParent = NewFrame.Icon;
				ViewportFrame = NewFrame.ViewportFrame;
			})
		end
	end
end


--//
function UnitIndex:ClearUnits()
	UIMotion:ClearUnitFrameClass("UnitIndexFrames")
end


--//
function UnitIndex:ClearRewardDisplay()
	for _, v in LevelFrame.NextLevel.RewardBox:GetChildren() do
		if v:GetAttribute("Added") then
			v:Destroy()
		end
	end
end


--//
UnitIndex:FilterBy("All")

function UnitIndex:Open(WindowManager)
	UnitIndex:UpdateLevelFrame()
	UnitIndex:LoadUnits()
	
	UiMain.Visible = true
	
	--// Exiting
	UIMotion:FullRegister(UiMain.Cross.Close.Clickable, UiMain.Cross.Close.Size, {
		toIncrease = UiMain.Cross.Close;
		Percent = 10;
		UUID = "Close";
		TreeUUID = "UnitIndex";

		callBack = function()
			WindowManager:CloseWindow("UnitIndex")
		end,
	}, {
		WhiteStrokeSupress = true;
	})
	
	--// Updating gradients
	Maid:GiveTreeTask("UnitIndex", "UpdateGradients", RunService.RenderStepped, function(dt)
		for _, info in UpdateGradients do
			if not info.UseOffset then
				info.Gradient.Rotation += info.Speed * (dt*45)
			else
				if info.Gradient.Offset.X >= 1 then
					info.Gradient.Offset = Vector2.new(-1,0)
				end

				info.Gradient.Offset += Vector2.new(info.Speed * dt, 0)
			end
		end
		
		if FilterButton.List.Visible then
			for _, tab in FilterButton.List:GetChildren() do
				if not tab:IsA("ImageButton") or not GradientRegistry[tab.Name] then continue end
				
				GradientRegistry[tab.Name]:Animate(tab:FindFirstChild("Text").UIGradient, dt)
			end	
		end
		
		if GradientRegistry[FilteredBy] then
			GradientRegistry[FilteredBy]:Animate(FilterButton.FilteredBy.UIGradient, dt)
		end
	end)
	
	--// Claiming prizes
	UIMotion:FullRegister(LevelFrame.ClaimPrizes, LevelFrame.ClaimPrizes.Size, {
		UUID = "Claim";
		TreeUUID = "UnitIndex";
		
		callBack = function()
			if player:GetAttribute("ClaimingIndexPrizes") then
				Notify("Error", "Please wait a few seconds!")
			else
				local IndexData = PlrProfileClass:GetField("IndexData")
				local IndexLevel = IndexData.IndexLevel
				local ClaimedRewards = IndexData.ClaimedLevelRewards
				
				UiCommunication:FireServer("UnitIndex/ClaimAllPrizes")

				local AllRewards = {}
				
				for i = 1, IndexLevel do
					if table.find(ClaimedRewards, i) then continue end
					
					for RewardType, RewardTable in IndexRegistry:GetRewardsForLevel(i) do
						for RewardName,RewardAmount in RewardTable do
							AllRewards[RewardType] = AllRewards[RewardType] or {}
							AllRewards[RewardType][RewardName] = AllRewards[RewardType][RewardName] or 0
							AllRewards[RewardType][RewardName] += RewardAmount
						end
					end
				end
				
				WindowManager:RunComponentMethod("RewardNotification/PlayNotification", {
					Header = `Index Level {IndexLevel}`,
					Description = `You have claimed rewards for reaching index level {IndexLevel}!`
				}, AllRewards)
				
				UiCommunication:FireServer("NPCNotifications/Toggle",'UnitIndexZone', false)
			end
		end,
	})
	
	--// Sorting
	Maid:GiveTreeTask("UnitIndex", "Sorting", FilterButton.MouseButton1Click, function()
		UnitIndex:ToggleDropDown()
	end)
	
	for _, tab in FilterButton.List:GetChildren() do
		if not tab:IsA("ImageButton") then continue end
		
		UIMotion:FullRegister(tab, tab.Size, {
			UUID = `Filter {tab.Name}`;
			TreeUUID = "UnitIndex";
			
			callBack = function()
				UnitIndex:FilterBy(tab.Name)
				UnitIndex:ToggleDropDown()
			end,
		})
	end
	
	--// Searching
	Maid:GiveTreeTask("UnitIndex", "Search", Options.SearchBox.TextBox:GetPropertyChangedSignal("Text"), function()
		local Text = string.gsub(Options.SearchBox.TextBox.Text, " ", ""):lower()

		for _, unit in UnitList:GetChildren() do
			if not unit:GetAttribute("Rarity") then continue end

			unit.Visible = string.find(string.gsub(unit:GetAttribute("DisplayName"), " ", ""):lower(), Text) and (Text ~= "" or unit:GetAttribute("Rarity") == FilteredBy or FilteredBy == "All")
		end
	end)
	
	--// Data changing
	Maid:GiveTreeTask("UnitIndex", "Index Data Updated", PlrProfileClass:GetFieldChangedSignal("IndexData"), function()
		UnitIndex:LoadUnits()
		UnitIndex:UpdateLevelFrame()
	end)
end


--//
function UnitIndex:Close()
	UiMain.Visible = false
	table.clear(TotalSorted)
	
	Maid:EndTree("UnitIndex")
	UnitIndex:ClearUnits()
	UnitIndex:ClearRewardDisplay()
	UnitIndex:FilterBy("All")
	
	if FilterButton.List.Visible then
		UnitIndex:ToggleDropDown()
	end
end


return UnitIndex
