--// By @ThatOneTusk
-- This code is NOT intended for others' usage, hence the lack of dependencies provided (Remotes, utilities, etc.)

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local HumanoidValues = ReplicatedStorage.HumanoidValues
local OverrideAnimations = ReplicatedStorage.Animations.Override
local ToggleMountRemote = ReplicatedStorage.Events.ToggleMount

local Notify = ReplicatedStorage.Libs:FindFirstChild("NotificationLib") and require(ReplicatedStorage.Libs.NotificationLib)
local DataAccess = require(ReplicatedStorage.Libs.DataAccessAPIClient)
local Maid = require(ReplicatedStorage.Maid).new()
local MountsRegistry = _G.Registry.registry.Mounts

local DataAPI = DataAccess:GetAPI()
local PlayerProfile = DataAPI:GetLocalProfileClass()

local MountsHandler = {}

local AnimationPaths = {
	idle = OverrideAnimations.IdleAnim;
	jump = OverrideAnimations.FallingAnim;
	walk = OverrideAnimations.RunningAnim;
	doubleJump = OverrideAnimations.DoubleJump;
}

--//
local function OnMountChanged()
	local NewMount = PlayerProfile:GetField("EquippedMount")
	NewMount = player:GetAttribute("MountToggled") and NewMount or ""
	
	if NewMount ~= "" then
		local FoundMount = MountsRegistry[NewMount]
		local MountInfo = FoundMount.configuration 
		local MaxSpeed = MountInfo.MaxSpeed
		local Acceleration = MountInfo.Acceleration
		
		humanoid:SetAttribute("RunDisabled", true)
		character:SetAttribute("WalkingSoundsDisabled", true)
		
		for Name, Object in AnimationPaths do
			local Id = FoundMount.animations[Name]
			local IsAStringValue = Object:IsA("StringValue")
			
			if Id then
				if IsAStringValue then
					Object.Value = `rbxassetid://{Id}`
				else
					Object.Value = Id
				end
			else
				if IsAStringValue then
					Object.Value = ""
				else
					Object.Value = 0
				end
			end
		end
		
		humanoid.JumpHeight = MountInfo.JumpHeight

		Maid:GiveTask("Speed Calculator", RunService.PreSimulation, function(dt)
			if player:GetAttribute("WindowsDisabled") then return end
			
			if humanoid.MoveDirection ~= Vector3.zero then
				if humanoid.WalkSpeed >= MaxSpeed then
					humanoid.WalkSpeed = MaxSpeed
				else
					humanoid.WalkSpeed += (Acceleration * dt)
				end
			else
				humanoid.WalkSpeed = 0 -- Reset to accelerate again
			end
		end, true)
	else
		Maid:KillTask("Speed Calculator")
		
		for _, Path in AnimationPaths do
			if not Path:IsA("StringValue") then
				Path.Value = 0
			else
				Path.Value = ""
			end
		end
		
		humanoid.JumpHeight = 7.2
		humanoid.WalkSpeed = HumanoidValues.WalkSpeed.Value
		
		humanoid:SetAttribute("RunDisabled", nil)
		character:SetAttribute("WalkingSoundsDisabled", nil)
	end
end


--//
local function ToggleMount(_, InputState)
	if PlayerProfile:GetField("EquippedMount") == "" or _G.WindowManager and _G.WindowManager.openedWindow or InputState ~= Enum.UserInputState.Begin then return end

	if player:GetAttribute("ToggleMountCooldown") then
		if Notify then
			Notify("Error", "Please wait a few moments!")
		end

		return
	end

	player:SetAttribute("ToggleMountCooldown", true)

	if Notify then
		Notify("Success", "Mount toggled!")				
	end

	ToggleMountRemote:FireServer()
	
	task.wait(1)
	player:SetAttribute("ToggleMountCooldown", nil)
end


--//
function MountsHandler:start()
	OnMountChanged()
	
	Maid:GiveTask("Mount Changed", PlayerProfile:GetFieldChangedSignal("EquippedMount"), OnMountChanged)
	Maid:GiveTask("Mount Hidden", player:GetAttributeChangedSignal("MountToggled"), OnMountChanged)
	
	ContextActionService:BindAction("ToggleMount", ToggleMount, true, Enum.KeyCode.C)
	ContextActionService:SetTitle("ToggleMount", "C")
end


return MountsHandler
