--[[ 

UI System made by @ThatOneTusk and feedback from @Good1005
Server-side is private. This code is NOT intended for others' usage, hence the lack of dependencies provided (Remotes, server side, etc.)

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local UiCommunication = ReplicatedStorage.Events.UiCommunication

local player = Players.LocalPlayer

local UiClient = {
	LoadedComponents = {};
	RespawnGui = {};
	DisabledComponents = {};
}

local LoadedComponents = UiClient.LoadedComponents
local DisabledComponents = UiClient.DisabledComponents
local RespawnGui = UiClient.RespawnGui

----------------------------------------------------------------

export type ComponentDataType = ModuleScript | {
	Name: string;
}


--// Loads the modules and starts them if possible
local function LoadAndStartModules(object: Instance)
	for _, module in object:GetChildren() do
		if module:IsA("ModuleScript") then
			
			task.spawn(function()
				local name = module.Name

				LoadedComponents[name] = require(module)

				module = LoadedComponents[name]

				local Settings = module.Settings
				local PlayerGui = player.PlayerGui

				if not Settings then return end;

				local UiMain: ScreenGui = StarterGui:FindFirstChild(name) and PlayerGui:WaitForChild(name) or PlayerGui:FindFirstChild(name)

				local EnableOnSpawn = Settings.EnableOnSpawn -- If nil, it'll automatically be false 

				if UiMain then
					UiMain.Enabled = EnableOnSpawn
				end

				local CanInit = Settings.InitOnLoad

				if CanInit ~= false then
					UiClient:StartComponent(name)
				end
			end)
			
		elseif module:IsA("Folder") then
			LoadAndStartModules(module)
		end
	end
end


--// Initalize all components with InitOnLoad, connect the UiCommunication remote, connect for RespawnGui
function UiClient:Init()
	
	-- // Load up the components/modules and start them if possible
	LoadAndStartModules(script)
	
	-- // Ui Server -> Client Communication. Keep in mind the method you're calling must be declared using : otherwise you may experience issues with arguments
	UiCommunication.OnClientEvent:Connect(function(info: string, ...)
		UiClient:RunComponentMethod(info, ...)
	end)
	
	
	-- // Connect to a new character added
	
	local character = player.Character or player.CharacterAdded:Wait() -- [ THIS MAY YIELD THE SCRIPT, IT IS ASSUMED THE INIT METHOD IS CALLED IN A THREAD ALREADY ] Ensure a character is added first to avoid duped initializing

	player.CharacterAdded:Connect(function()
		
		-- // Clean the cache of all loaded modules
		for name, module in LoadedComponents do
			if module.Cache and next(module.Cache) then
				task.spawn(function()
					UiClient:CleanupComponent(name)
				end)
			end
		end
		
		-- // Init the Respawn components
		for name, module in RespawnGui do
			if DisabledComponents[name] then continue end
			
			task.spawn(function()
				local UiMain: ScreenGui = StarterGui:FindFirstChild(name) and player.PlayerGui:WaitForChild(name)
				local Settings = module.Settings 
				
				if Settings and UiMain then
					UiMain.Enabled = Settings.EnableOnSpawn
					
					if Settings.InitOnRespawn then
						UiClient:StartComponent(name)
					end
				end
				
				if module.OnRespawn and typeof(module.OnRespawn == "function") then
					module:OnRespawn()
				end
			end)
		end
	end)
end


-- // Fire the UiCommunication remote to the server
function UiClient:FireUiServer(path: string, ...: any?)
	local SplitInfo = string.split(path,"/")

	local ComponentName = SplitInfo[1]
	
	-- TODO: Other checks if wanted

	if not UiClient.DisabledComponents[ComponentName] then
		UiCommunication:FireServer(path, ...)
	end
end


--[[ :RunComponentMethod
// Run a Component method only if it's not disabled and loaded. ComponentName:lower() == "ui" means you're requesting a method from THIS module itself.

- ONLY USE WHEN: calling a method outside of this module or outside of a component, calling a method that may not exist or when calling a method using a string
- Keep in mind the method you're calling must be declared using : otherwise you may experience issues with arguments
- Takes in path in the form: "ComponentName/MethodName"
]]
function UiClient:RunComponentMethod(path: string, ...: any?)
	path = string.split(path,"/")
	
	local ComponentName, MethodName = path[1], path[2]
	local FoundModule, IsEnabled;
	
	if not ComponentName or not MethodName then return end
	
	if ComponentName:lower() == "ui" then -- Is asking for a method from THIS module itself
		FoundModule = UiClient
		IsEnabled = true
	else
		FoundModule = LoadedComponents[ComponentName]
		IsEnabled = not DisabledComponents[ComponentName] 
	end

	if FoundModule and FoundModule[MethodName] and IsEnabled then
		assert(typeof(FoundModule[MethodName]) == "function", `MethodName {MethodName} of Component {ComponentName} exists but is not a function. Did you give a wrong name?`)
		
		FoundModule[MethodName](FoundModule, ...)
	elseif IsEnabled then
		warn(debug.traceback(`Either component or method not found. Component: {ComponentName}, method: {MethodName}`))
	end
end



-- // Call the Init method of Component and insert it to the RespawnGui table. Entirely different behavior than EnableComponent
function UiClient:StartComponent(ComponentName: string, ...: any?)
	local module = LoadedComponents[ComponentName]
	
	if not module then
		warn(`Component "{ComponentName}" is not loaded or added. Can not start component. Call AddComponent instead.`)
		return
	end
	
	if DisabledComponents[ComponentName] then
		warn(`Component "{ComponentName}" is disabled. Enable first before starting.`)
		return
	end

	local CanRespawn = (type(module.OnRespawn) == "function") or module.Settings and module.Settings.InitOnRespawn
	
	if not RespawnGui[ComponentName] and CanRespawn then
		RespawnGui[ComponentName] = module
	end
	
	module:Init(...)
end



-- // Attempt to clean up the Component/it's cache
function UiClient:CleanupComponent(ComponentName: string)
	local module = LoadedComponents[ComponentName]
	
	if not module then
		warn(`Component "{ComponentName}" is not loaded.`)
		return
	end
	
	local HasCleanup = type(module.Cleanup) == "function"
	local Cache = module.Cache
	local Settings = module.Settings
	
	if not Cache then
		warn(`Component "{ComponentName}" does not have a cache. If intentional, don't worry. If not, add one to silence.`)
		return
	end
	
	if HasCleanup then
		module:Cleanup()
		
	elseif Settings and Settings.AutoCleanup ~= false then
		assert(type(Cache.Clear ~= "function"), `Cache exists, AutoCleanup is true, no Cleanup function supplied and Cache has no Clear function. Cache is never cleared for Component: {ComponentName}`)
		
		Cache:Clear()
	end
end



-- // Add a new component to be registered, instantly calls start on it unless DontStartComponent is true - Accepts a table or module for the first argument, if it's a table then you must add a ComponentName - Unused in the main Initalize method
function UiClient:AddComponent(ComponentData: ComponentDataType, ComponentName: string?, DontStartComponent: boolean?) 
	local IsAModule = ComponentData:IsA("ModuleScript")
	
	ComponentName = ComponentName or (IsAModule and ComponentData.Name)
	
	if not ComponentName then
		warn("Component name is nil for component data: ", ComponentData)
		return
	end
	
	if LoadedComponents[ComponentName] then
		warn(`Component "{ComponentName}" is already loaded`)
		return
	end
	
	LoadedComponents[ComponentName] = (IsAModule and require(ComponentData)) or ComponentData
	
	if not DontStartComponent then
		UiClient:StartComponent(ComponentName)
	end
end


-- // Remove a component from the module and call OnRemove if applied, does not enable the component if disabled
function UiClient:RemoveComponent(ComponentName: string)
	local module = LoadedComponents[ComponentName]
	
	if not module then return end
	
	-- // Call the methods first then remove them from the references so said methods don't error
	UiClient:CleanupComponent(ComponentName)
	
	if module.OnRemove then
		module:OnRemove()
	end
	
	LoadedComponents[ComponentName] = nil
	RespawnGui[ComponentName] = nil
end


-- // Utility function to toggle UI
-- Note: Disabling/Enabling UI affects their RespawnGui reference too

local function ToggleUI(ComponentName: string, Disabled: boolean)
	local module = LoadedComponents[ComponentName]
	
	local SetTo = Disabled or nil
	local OnSpawn;
	
	if not Disabled and (type(module.OnRespawn) == "function" or module.Settings and module.Settings.InitOnRespawn) then
		OnSpawn = module
	end
	
	DisabledComponents[ComponentName] = SetTo
	RespawnGui[ComponentName] = OnSpawn
end


-- // Disable a component for the CLIENT ONLY! Does not replicate to server for security reasons. ENTIRELY different behavior than RemoveComponent
-- [!] If called functions throw an error, the main thread will not be halted [!]
function UiClient:DisableComponent(ComponentName: string)
	local module = LoadedComponents[ComponentName]
	local Settings = module.Settings
	
	local UiMain = player.PlayerGui:FindFirstChild(ComponentName)

	if not module then
		warn(`Component "{ComponentName}" is not loaded. Will put in DisabledComponents`)
		
		DisabledComponents[ComponentName] = true

		return
	end
	
	if DisabledComponents[ComponentName] then
		return
	end
	
	if module.OnDisable then
		task.spawn(function()
			UiClient:RunComponentMethod(`{ComponentName}/OnDisable`)
		end)
	end
	
	ToggleUI(ComponentName, true) --// Disable after running the methods

	if UiMain then
		UiMain.Enabled = false
	end
	
	if Settings and Settings.CleanupOnDisable ~= false then
		task.spawn(function()
			UiClient:CleanupComponent(ComponentName)
		end)
	end
end



-- // Enable a component for the CLIENT ONLY! Does not replicate to server for security reasons. ENTIRELY different behavior than StartComponent
-- [!] If called functions throw an error, the main thread will not be halted [!]
function UiClient:EnableComponent(ComponentName: string)
	local module = LoadedComponents[ComponentName]
	local Settings = module.Settings
	local UiMain = player.PlayerGui:FindFirstChild(ComponentName)

	if not module then
		warn(`Component "{ComponentName}" is not loaded. Will remove from DisabledComponents`)
		
		DisabledComponents[ComponentName] = nil
		
		return
	end
	
	if not DisabledComponents[ComponentName] then
		warn(`Component "{ComponentName}" is not disabled`)
		return
	end
	
	ToggleUI(ComponentName, false) -- // Enable before running the methods
	
	if module.OnEnable then
		task.spawn(function()
			UiClient:RunComponentMethod(`{ComponentName}/OnEnable`)
		end)
	end
	
	if Settings then
		if Settings.InitOnEnable ~= false then
			task.spawn(function()
				UiClient:StartComponent(ComponentName)
			end)
		end
		
		if UiMain then
			UiMain.Enabled = Settings.EnableOnSpawn
		end
	end
end


return UiClient
