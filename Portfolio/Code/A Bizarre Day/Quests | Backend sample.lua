local Quests = {}

--// Quests module written by @ThatOneTusk
-- Typechecking for QuestData is within the live version and is an exported type from QuestData
-- This code is NOT intended for others' usage, hence the lack of dependencies provided (Remotes, utilities, etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local GeneralUtil = require(ReplicatedStorage.Modules.Utility.General)
local QuestRegistry = require(ReplicatedStorage.Modules.Defaults.QuestData)

--[[
	-- // [!] Valid Events and EventTriggers should be put in the QuestData -> 1_Documentation -> EventsDocumentation script. Please document them properly. [!] \\ --
	
	-- Ensure you've read the QuestData documentation!! --
	
--]]



-- // MODULE METHODS \\ --

export type EventDataType = {
	Event: string;
	EventTrigger: string?;
	ProgressAmount: number?;
	CheckArguments: {}?;
	-- Add more if you'd like
}

type QuestIdentifierCheckType = (Player) -> boolean?;

type QuestInstanceMethodType = (Player, NumberValue, any) -> ();

type ObjectiveInstanceMethodType = (Player, NumberValue, any, boolean?) -> ();

--

local QuestIdentifierChecks: {[string]: QuestIdentifierCheckType} = {  -- Must return true to validate
	AbilityQuest = function(player)
		local passed = not(next(Quests:FindQuestWithIdentifier(player, "AbilityQuest")))
		
		if not passed then
			GeneralUtil.Notify(player, {Text = "You can't have more than one ability quest!", Type = "Error"})
		end
		
		return passed
	end,
}

--
--[[

Template for Quest Types (If no methods exist, it'll follow the default behavior as listed above)

* Neither method needs to exist

QuestType = { 
		QuestInstanceMethod = function(player, QuestInstance: NumberValue, QuestData: any) -- Fires on the Quest Instance once it's created on GiveQuest
			
		end,
		
		ObjectiveInstanceMethod = function(player, ObjectiveInstance: NumberValue, ObjectiveData: any, DontCheckDoneProgression: boolean?)  -- Fires on the Objective once it's created on GiveQuest
			
		end,
	}
}

--]]


local function AttemptToGetDoneProgression(player, ObjectiveInstance, ObjectiveData, DontCheckDoneProgression)
	if not DontCheckDoneProgression then
		ObjectiveInstance.Value = Quests:GetDoneProgression(player, ObjectiveData)
	end
end

local QuestTypeFunctions = {

	CheckBased = {
		ObjectiveInstanceMethod = AttemptToGetDoneProgression
	};
	
}:: {[string]: {
	QuestInstanceMethod: QuestInstanceMethodType?;
	ObjectiveInstanceMethod: ObjectiveInstanceMethodType
}}


-- Utility method for the module to use to search through tables
local function Match(hay: any, needle: string)
	if typeof(hay) == "string"  then
		return needle:lower() == hay:lower()

	elseif typeof(hay) == "table" then
		
		for _, value: string in hay do
			if value:lower() == needle:lower() then
				return true
			end
		end
	end
end


local function GetQuestData(QuestName: string)
	QuestName = string.split(QuestName, "/")
	
	local name, act = QuestName[1], QuestName[2]
	
	return act and QuestRegistry[name][tonumber(act)] or QuestRegistry[name]
end



--// Give the player a quest if they're eligible for it, return the quest instance if given
-- QuestName: Can be a path in the form of Name/Act if the quest has them
-- DontCheckDoneProgression: If true, will not check previously done progression when giving the quest if the ObjectiveInstanceMethod of QuestType does that (Used by Datastores mainly)
function Quests:GiveQuest(player: Player, QuestName: string, DontCheckDoneProgression: boolean?): NumberValue?
	local QuestData = GetQuestData(QuestName)
	
	assert(QuestData, `Quest {QuestName} not found`)
	assert(QuestData.Objectives, `No objectives for quest {QuestName}`)
	
	-- // Check if the quest has a Quest identifier and an EligibilityCheck
	if QuestData.QuestIdentifier then
		local FoundCheck = QuestIdentifierChecks[QuestData.QuestIdentifier]
		
		if FoundCheck then
			if not FoundCheck(player) then return end
		end
	end
	
	if QuestData.EligibilityCheck then
		if not QuestData.EligibilityCheck(player) then return end
	end
	
	-- // All checks passed, give the player the quest
	local TypeMethods = QuestTypeFunctions[QuestData.QuestType]
	
	local NewQuest = Instance.new("NumberValue")
	NewQuest.Name = QuestName
	
	if TypeMethods and TypeMethods.QuestInstanceMethod then
		TypeMethods.QuestInstanceMethod(player, NewQuest, QuestData)
	end
	
	for ObjectiveName, ObjectiveData in QuestData.Objectives do
		local NewObjective = Instance.new("NumberValue")
		NewObjective.Name = ObjectiveName
			
		NewObjective:SetAttribute("Goal", ObjectiveData.Goal) -- Used for client checks. Not used for checking in this module.
			
		if TypeMethods and TypeMethods.ObjectiveInstanceMethod then
			TypeMethods.ObjectiveInstanceMethod(player, NewObjective, ObjectiveData, DontCheckDoneProgression)
		end
			
		NewObjective.Parent = NewQuest
	end
	
	
	NewQuest.Parent = player.Data.Storage.Quests
	
	if QuestData.OnApply then
		QuestData.OnApply(player)
	end
	
	-- // Check if the quest is completed just incase previous progress (if present) finished it
	if QuestData.AutoFinish then
		if Quests:IsQuestCompleted(player, QuestName) then
			Quests:FinishQuest(player, QuestName)
			return
		end
	end

	return NewQuest
end


--// Remove a quest from the player
function Quests:RemoveQuest(player: Player, QuestName: string)
	local QuestData = GetQuestData(QuestName)
	local FoundQuest = player.Data.Storage.Quests:FindFirstChild(QuestName)
	
	if FoundQuest then
		FoundQuest:Destroy()
		
		if QuestData.OnRemove then
			QuestData.OnRemove(player)
		end
	end
end


--// Checks if the player has any quests and tries to progress them. If you want to progress an individual quest, use ProgressIndividual instead
function Quests:ProgressQuests(player: Player | Model, EventData: EventDataType)
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)
	
	assert(player, "No Player")
	assert(EventData, "Event data is nil")
	
	for _, quest in player.Data.Storage.Quests:GetChildren() do
		task.spawn(function()
			Quests:ProgressIndividual(player, quest.Name, EventData)
		end)
	end
end


--// Default progression method. Only progresses the quest given to it
function Quests:ProgressIndividual(player: Player | Model, QuestName: string, EventData: EventDataType)
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)
	
	assert(player, "No Player")
	
	local QuestData = GetQuestData(QuestName)
	local QuestInstance = player.Data.Storage.Quests:FindFirstChild(QuestName)
	
	assert(EventData, `Event data is nil for quest {QuestName}`)
	assert(QuestData, `Quest data is nil for quest {QuestName}`)
	assert(QuestInstance, `Attempt to progress a quest the player doesn't have, quest name: {QuestName}`)
	
	local Event = EventData.Event
	local EventTrigger = EventData.EventTrigger
	local ProgressAmount = EventData.ProgressAmount or 1
	local CheckArguments = EventData.CheckArguments or {}
	
	if QuestData.Objectives then
		for ObjectiveName, ObjectiveData in QuestData.Objectives do
			
			local ObjectiveEvent = ObjectiveData.Event
			local ObjectiveTrigger = ObjectiveData.EventTrigger
			local ObjectiveGoal = ObjectiveData.Goal
			
			-- // Check if the Events match
			if not Match(ObjectiveEvent, Event) then continue end
			
			-- // Check if the triggers match if a trigger exists
			if ObjectiveTrigger then
				if not EventTrigger then continue end
				
				if not Match(ObjectiveTrigger, EventTrigger) then continue end
			end
			
			-- // Check if there is a CheckFunction
			if ObjectiveData.CheckFunction then
				assert(not CheckArguments.EventData, `EventData is reserved. CheckArguments: {CheckArguments}`)
				CheckArguments.EventData = EventData
				
				if not ObjectiveData.CheckFunction(player, CheckArguments) then continue end
			end
		
			-- // All things match, progress the quest if possible
			local ObjectiveInstance: NumberValue = QuestInstance:FindFirstChild(ObjectiveName)
			
			assert(ObjectiveInstance, `Objective exists in data, but not under the quest instance for quest {QuestName}, objective {ObjectiveName}`)
			
			if ObjectiveGoal > ObjectiveInstance.Value then
				
				if ObjectiveGoal <= (ObjectiveInstance.Value + ProgressAmount) then
					ObjectiveInstance.Value = ObjectiveGoal
				else
					ObjectiveInstance.Value += ProgressAmount
				end
			end
		end
	end
	
	-- // Check if the quest should automatically finish
	if QuestData.AutoFinish then
		if Quests:IsQuestCompleted(player, QuestName) then
			Quests:FinishQuest(player, QuestName)
		end
	end
end


--// Returns whether the quest is completed or not
-- Client UI uses a built in method
function Quests:IsQuestCompleted(player: Player | Model, QuestName: string): boolean?
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)

	assert(player, "No Player")
	
	local QuestData = GetQuestData(QuestName)
	local QuestInstance = player.Data.Storage.Quests:FindFirstChild(QuestName)

	assert(QuestData, `Quest data is nil for quest {QuestName}`)
	assert(QuestData.Objectives, `No objectives for quest {QuestName}`)
	
	if not QuestInstance then return end
	
	if QuestData.Objectives then
		for ObjectiveName, ObjectiveData in QuestData.Objectives do
			local ObjectiveInstance: NumberValue = QuestInstance:FindFirstChild(ObjectiveName)
			
			assert(ObjectiveInstance, `Objective exists in data, but not under the quest instance for quest {QuestName}, objective {ObjectiveName}`)
			
			if ObjectiveInstance.Value < ObjectiveData.Goal then
				return 
			end
		end
	end
	
	return true
end


--// Finish the quest if quest is completed and reward the player
-- Returns true if the quest is successfully finished
function Quests:FinishQuest(player: Player | Model, QuestName: string): boolean?
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)

	assert(player, "No Player")
	
	local QuestData = GetQuestData(QuestName)
	local QuestInstance = player.Data.Storage.Quests:FindFirstChild(QuestName)
	
	if not Quests:IsQuestCompleted(player, QuestName) then return end
	
	local Rewards = QuestData.Rewards
	
	Quests:RemoveQuest(player, QuestName)
	
	local RewardMethods = {
		RunFunction = function()
			Rewards.RunFunction(player)
		end,
		
		GiveQuest = function(name)
			Quests:GiveQuest(player, name)
		end,
	}
	
	for RewardName, Value in Rewards do
		if RewardMethods[RewardName] then
			task.spawn(RewardMethods[RewardName], Value)
		end
	end
	
	return true
end


-- [[ General Utility Methods ]] -- 

--// Check if a player has a quest with a certain QuestIdentifier, returning all the quests found or an empty table
function Quests:FindQuestWithIdentifier(player: Player | Model, Identifier: string): {NumberValue?}
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)

	assert(player, "No Player")
	
	local PlayerQuests = player.Data.Storage.Quests
	local FoundQuests = {}

	for _, Quest in PlayerQuests:GetChildren() do
		local QuestData = GetQuestData(Quest.Name)

		if QuestData and QuestData.QuestIdentifier == Identifier then
			table.insert(FoundQuests, Quest)
		end
	end
	
	return FoundQuests
end


--// Check if a player has a quest
-- QuestName: Can be a path in the form of Name/Act, if no Act is given, it'll try to match the Name only
function Quests:PlayerHasQuest(player: Player | Model, QuestName: string): NumberValue?
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)
	QuestName = string.split(QuestName, "/")

	assert(player, "No Player")
	
	local PlayerQuests = player.Data.Storage.Quests
	local name, act = QuestName[1], QuestName[2]
	
	for _, quest in PlayerQuests:GetChildren() do
		if string.split(quest.Name, "/")[1] == name and (not act or string.split(quest.Name, "/")[2] == act) then
			return quest
		end
	end
end


--// Utility method to attempt to get previously done progression for an objective. Mainly used for the type CheckBased 
local checks = { -- A table to fetch the progression for GetDoneProgression. Must return a number, if it returns nil, value will be 0
	
	ObtainItem = function(player, ObjectiveData)
		local PlayerInventory = player.Data.Storage.Items
		local EventTrigger = ObjectiveData.EventTrigger
		local FoundAmounts = {}
		
		for _, Item in PlayerInventory:GetChildren() do
			if Match(EventTrigger, Item.Name) then
				table.insert(FoundAmounts, Item.Value)
			end
		end

		if next(FoundAmounts) then
			return math.max(table.unpack(FoundAmounts))
		end
		
		return 0
	end,
	
}:: {[string]: (Player, any) -> number?};


function Quests:GetDoneProgression(player: Player | Model, ObjectiveData: any): number
	player = player:IsA("Player") and player or PlayerService:GetPlayerFromCharacter(player)

	assert(player, "No Player")
	
	if checks[ObjectiveData.Event] then
		return checks[ObjectiveData.Event](player, ObjectiveData) or 0
	end
	
	return 0
end


return Quests
