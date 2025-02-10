--[[

local Modules = game:GetService("ReplicatedStorage").Modules
local CacheModule = require(Modules.Classes.Utility.Cache)
local UiClient = require(Modules.Systems.Ui)

-- By @ThatOneTusk

local Component = {
	
	----------
	// A Component may have the following:
	* By may, it means you don't have to add one but you'll be unable to use some features
	
	A Settings dictionary
	
	A Cache. Under normal circumstances, use the Cache utility for it
	
	A Cleanup method
	
	A OnEnable/OnDisable/OnRespawn/OnRemove method (each documented below)
	
	// A Component MUST have the following:
	
	An Init function
	ALL Methods (hence the name method.. lol) must be declared using : and not . to avoid issues with arguments
	
	----------
	
	Settings = {
		
		InitOnLoad = true; -- // Can be left nil and it'll default to true. If false, will not automatically initalize the Component on main module running
		
		EnableOnSpawn = true; -- // Value to set the ScreenGui (if found) to while initalizing in the main module. If nil it'll automatically be false 
		
		AutoCleanup = true; -- // Can be left nil and it'll default to true. If false, will not attempt to automatically clear the Cache when CleanupComponent is called. Only set to false if you never want to clear the Cache and have no Cleanup method.
		
		InitOnEnable = true; -- // Can be left nil and it'll default to true. If false, will not call StartComponent once a Component is re-enabled
		
		InitOnRespawn = true -- // If true, will call Init on CharacterAdded, adds it in the RespawnGui queue
		
		CleanupOnDisable = true; -- // Can be left nil and it'll default to true. If false, will not call CleanupComponent once a Component is disabled
	}; 
	
	Cache = CacheModule.new() 
	
	----------
	Let's talk more about the cache. You may have and may not have one, if you don't have one and attempt to call Cleanup on it it'll give a warning but it's nothing to worry about if intentional.
	
	If you'll use a cache, make sure it's under the module, or well, Component
	
	Naturally you'd want to use the CacheModule utility, but incase you don't, you must have at least one of the following:
	
	a Clear method of the Cache table
	a Cleanup method of Component
	or AutoCleanup must be equal to false, if you don't want to clear the Cache automatically at all
	
	Important notes:
	
	Cache should be a constant value, and, if using the CacheModule utility, call the Clear method, not Destroy. Or consider adding another one right after destroying the previous.
	
	----------
	
}


-- // Main Initalize function
function Component:Init()
	print("Hello World!")
end


-- // OnRespawn. If this method exists, it'll be added to the RespawnGui table. If not then it will not. A Component is removed from the RespawnGui table if disabled, and will be re-added if it has the OnSpawn function/InitOnRespawn once enabled.
function Component:OnRespawn()
	print("Hello World! again..")
end

-- // OnRemove. Fires once RemoveComponent is called
function Component:OnRemove()
	print("Bye World! forever..")
end

-- // OnDisable. Fires once DisableComponent is called
function Component:OnDisable()
	print("Bye World! for now..")
end

-- // OnEnable. Fires once EnableComponent is called
function Component:OnEnable()
	print("Hello World! just came back")
end


-- // Cleanup method. Fires once CleanupComponent is called or whenever you want in this module lol
-- // If there is no Cleanup method, the UI Module will attempt to clean it on it's own
function Component:Cleanup()
	Cache:Clear()
end


return Component

]]
