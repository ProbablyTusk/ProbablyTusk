--[[

-- By @ThatOneTusk

- Most documentation can be found in the main module

------------------

[!] Quest Types and Identifiers [!]

-- * Please document a quest type/identifier if you add a new one, under EventsDocumentation (directly under this) --
-- * Both ARE case sensitive, unlike Event and EventTrigger -- 

Quest types documentation:

Progression Does not check for previous actions to attempt to consider them in the progression
CheckBased: Checks for previous actions to attempt to consider them in the progression

[!] If QuestType is nil, it will not check for previous actions to attempt to consider them in the progression [!]

Quest Identifiers documentation:

AbilityQuest: Having a quest with the identifier AbilityQuest will not allow you to take any other 

[!} if left nil, no behavior will be considered [!]

------------------

- Template (actual template used for testing)

local test = {
	-- Event and EventTrigger can be tables and it'll check inside of them. Are NOT case sensitive
	
	DisplayName = "" -- will use the quest name instead if nil
    Description = "Description here"; optional
    Image = "rbxassetid://id"; optional
	
	QuestType = "Progression"; -- The type of the quest, Can be left nil for normal behavior
	QuestIdentifier = "AbilityQuest"; -- An identifier for the quest. Can be left nil
	AutoFinish = boolean; -- Whether to automatically finish the quest or not once it's objectives are done. False by default
	
	OnApply = function(player) -- Fires once the quest is given
			
	end,
		
	OnRemove = function(player) -- Fires once the quest is removed
			
	end,
	
	EligibilityCheck = function(player) -- A check that happens before giving the player a quest. Returning anything with a true value will let the script proceed, anything else that is of false value will not let it proceed.
		return math.random(2) == 2
	end,
	
	Objectives = {
		["me"] = { -- Index is the objective name. Code has support for multiple objectives but UI doesn't.
			Event = "KillEnemy"; -- The event/action that the quest should listen to
			EventTrigger = "Dummy"; -- What exactly happened in that event, example: the dummy that was killed. Can be nil and it'll trigger on every `Event (in this case, KillEnemy)` event.
			Goal = 10; -- The goal of the objective
			
			CheckFunction = function(player, CheckArguments) -- A check that happens before progressing an objective. Returning anything with a true value will progress, anything else that is of false value will not progress it.
															 -- CheckArguments is given from Quests:ProgressIndividual
				return math.random(2) == 1
			end,
			
		}
	};
	
	Rewards = { -- The rewards to give to the player after a quest is completed
		
		RunFunction = function(player) -- A function to run once the player completes a quest
			print(`Woah you are so cool {player.Name}`)
		end,
	}
	
}


Example of acts (just an array basically):


local test = { 
	[1] = Same template above
	
}


return test


--]]
