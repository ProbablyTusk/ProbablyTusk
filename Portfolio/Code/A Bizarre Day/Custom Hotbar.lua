--// Backpack by @ThatOneTusk
-- Backpack CoreGui being disabled is in StarterPlayerScripts > Client
-- This code is NOT intended for others' usage, hence the lack of dependencies provided (Remotes, server side, etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CacheModule = require(ReplicatedStorage.Modules.Classes.Utility.Cache)
local UiClient = require(ReplicatedStorage.Modules.Systems.Ui)
local EntityUtil = require(ReplicatedStorage.Modules.Utility.Entity)

local player = game:GetService("Players").LocalPlayer
local EquippedItems: Folder = player:WaitForChild("TemporaryData").EquippedItems
local PlayerItems: Folder = player:WaitForChild("Data").Storage.Items

local BackpackUI = player.PlayerGui:WaitForChild("Backpack")
local Hotbar = BackpackUI.Hotbar

local Backpack = {
	Settings = {
		EnableOnSpawn = true;
		InitOnRespawn = true;
		
		Keybinds = {
			[Enum.KeyCode.One] = 1;
			[Enum.KeyCode.Two] = 2;
			[Enum.KeyCode.Three] = 3;
			[Enum.KeyCode.Four] = 4;
			[Enum.KeyCode.Five] = 5;
			[Enum.KeyCode.Six] = 6;
			[Enum.KeyCode.Seven] = 7;
			[Enum.KeyCode.Eight] = 8;
			[Enum.KeyCode.Nine] = 9;
			[Enum.KeyCode.Zero] = 0;
		}:: {[Enum.KeyCode]: number}
	};
	
	Cache = CacheModule.new();
}


local Cache = Backpack.Cache 
local ItemTemplate = script.ItemTemplate
local Keybinds = Backpack.Settings.Keybinds

--// Also fires when a keybind is clicked
local function OnClick(Origin: StringValue)
	if EntityUtil.IsBackpackDisabled(player) then return end
	
	local FoundTool = player.Character:FindFirstChildWhichIsA("Tool")
	
	for _, item in EquippedItems:GetChildren() do
		if item == Origin then continue end
		
		Backpack:UpdateItem(item, false)
	end
	
	Backpack:UpdateItem(Origin, (not FoundTool or FoundTool.Name ~= Origin.Name))
	
	UiClient:FireUiServer("Backpack/ToggleToolEquip", Origin.Name)
end


--// 
function Backpack:Init()
	Backpack:ClearHotbar()
	
	--// Load items and listen for data changing
	local function SetupItem(item: StringValue)
		local StoredItem = PlayerItems:FindFirstChild(item.Name)

		Backpack:_CreateItem(item)

		Cache:Add(StoredItem.Changed:Connect(function()
			Backpack:UpdateItem(item)
		end), {Identity = `{item.Name} Listener`})
	end
	
	for _, item in EquippedItems:GetChildren() do
		SetupItem(item)
	end
	
	Cache:Add(EquippedItems.ChildAdded:Connect(SetupItem))
	
	Cache:Add(EquippedItems.ChildRemoved:Connect(function(item: StringValue)
		local FoundFrame = Hotbar:FindFirstChild(item.Name)
		
		if FoundFrame then
			FoundFrame:Destroy()
		end
		
		if Cache:FindByIdentity(`{item.Name} Listener`) then
			Cache:Remove(Cache:FindByIdentity(`{item.Name} Listener`))
		end
	end))
	
	
	--// Listen to keybinds
	Cache:Add(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		
		local Position = Keybinds[input.KeyCode]
		
		if Position then
			local FoundItem;
			
			for _, item in Hotbar:GetChildren() do
				if item:GetAttribute("Position") == Position then
					FoundItem = item
					break
				end
			end
			
			if not FoundItem then return end
			
			FoundItem = EquippedItems:FindFirstChild(FoundItem.Name)
			if not FoundItem then return end
			
			OnClick(FoundItem)
		end
	end))
end


--//
function Backpack:ClearHotbar()
	for _, item in Hotbar:GetChildren() do
		if item:GetAttribute("Position") then
			item:Destroy()
		end
	end
end


--// 
function Backpack:_CreateItem(Origin: StringValue)
	local Position = Origin:GetAttribute("Position")
	local StoredItem = PlayerItems:FindFirstChild(Origin.Name)
	local FoundTool = player.Character:FindFirstChildWhichIsA("Tool")
	
	local NewItem = ItemTemplate:Clone()
	NewItem.Name = Origin.Name
	NewItem.DisplayName.Text = `{StoredItem.Value}x {Origin.Name}`
	NewItem.DisplayPosition.Text = Position
	NewItem.Border.ImageTransparency = FoundTool and FoundTool.Name == Origin.Name and 0 or 0.5
	NewItem.LayoutOrder = Position
	NewItem:SetAttribute("Position", Position)
	
	Cache:Add(NewItem.MouseButton1Click:Connect(function()
		OnClick(Origin)
	end))
	
	NewItem.Parent = Hotbar
end


--//
function Backpack:UpdateItem(Origin: StringValue, equipped: boolean?)
	local Position = Origin:GetAttribute("Position")
	local StoredItem = PlayerItems:FindFirstChild(Origin.Name)
	local FoundFrame = Hotbar:FindFirstChild(Origin.Name)
	local FoundTool = player.Character:FindFirstChildWhichIsA("Tool")
	
	if not FoundFrame or not StoredItem then return end
	
	FoundFrame.DisplayName.Text = `{StoredItem.Value}x {Origin.Name}`
	FoundFrame.DisplayPosition.Text = Position
	FoundFrame.Border.ImageTransparency = if equipped == nil and FoundTool and FoundTool.Name == Origin.Name or equipped then 0 else 0.5
	FoundFrame.LayoutOrder = Position
	FoundFrame:SetAttribute("Position", Position)
end


--//
function Backpack:Cleanup()
	Backpack:ClearHotbar()
	Cache:Clear()
end

return Backpack
