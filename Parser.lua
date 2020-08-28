local CLASS = {}

--// SERVICES //--



--// CONSTANTS //--

CLASS.CONFIGURATIONS = require(script.Configurations)

CLASS.COMMANDS = require(script.Commands)
CLASS.MODIFIERS = require(script.Modifiers)

-- Calculated when singleton is intialized
-- Included in constants because they are never changed once set
CLASS.SORTED_COMMANDS = nil
CLASS.SORTED_MODIFIERS = nil

-- Using string.format to make the patterns easier to understand
CLASS.PATTERNS = {
	
	COMMANDS_FROM_BATCH = string.format(
		"%s([^%s]+)",
		CLASS.CONFIGURATIONS.PREFIX,
		CLASS.CONFIGURATIONS.PREFIX
	),
	
	
	DEFINITIONS_FROM_COMMAND = string.format(
		"%s?([^%s]+)",
		CLASS.CONFIGURATIONS.DEFINITION_SEPARATOR,
		CLASS.CONFIGURATIONS.DEFINITION_SEPARATOR
	),
	
	
	KEYWORD_WITH_CAPSULE = string.format(
		"%s(.-)%s",
		CLASS.CONFIGURATIONS.CAPSULE_OPEN,
		CLASS.CONFIGURATIONS.CAPSULE_CLOSE
	),
	
	
	ARGUMENTS_SEPERATOR = string.format(
		"([^%s]+)%s?",
		CLASS.CONFIGURATIONS.ARGUMENT_SEPARATOR,
		CLASS.CONFIGURATIONS.ARGUMENT_SEPARATOR
	),
	
}

--// VARIABLES //--



--// CONSTRUCTOR //--

function CLASS.new()
	local dataTable = setmetatable(
		{
			
		},
		CLASS
	)
	local proxyTable = setmetatable(
		{
			
		},
		{
			__index = function(self, index)
				return dataTable[index]
			end,
			__newindex = function(self, index, newValue)
				dataTable[index] = newValue
			end
		}
	)
	
	proxyTable:initialize()
	
	return proxyTable
end

--// FUNCTIONS //--



--// METHODS //--

function CLASS:initialize()
	--// Copies commands and modifiers tables and sorts them in descending order by length
	local sortedCommands = {}
	for _, command in pairs(CLASS.COMMANDS) do table.insert(sortedCommands, command) end
	table.sort(sortedCommands, function(a, b) return #a > #b end)
	CLASS.SORTED_COMMANDS = sortedCommands
	
	local sortedModifiers = {}
	for _, modifier in pairs(CLASS.MODIFIERS) do table.insert(sortedModifiers, modifier) end
	table.sort(sortedModifiers, function(a, b) return #a > #b end)
	CLASS.SORTED_MODIFIERS = sortedModifiers
end

function CLASS:getMatches(source, pattern)
	--// Helper method to return all matches
	local matches = {}
	for match in string.gmatch(source, pattern) do
		if (string.match(match, "^%s*$") == nil) then
			table.insert(matches, match)
		end
	end
	return matches
end

function CLASS:getCaptures(source, sortedKeywordsTable)
	--// A Capture is found in a source by a table of possible captures and it
	--// includes the arguments in a following capsule if there is any
	--// A Capture is structured like this [capture] = {[arg1], [arg2], ... }
	--// Captures are structured like this Captures = {[capture1], [capture2], ... }
	
	--// Find all the captures
	local captures = {}
	--// We need sorted table so that larger keywords get captured before smaller
	--// keywords so we solve the issue of large keywords made of smaller ones
	for counter = 1, #sortedKeywordsTable do
		local keyword = sortedKeywordsTable[counter]:lower()
		--// Captures with argument capsules are stripped away from the source
		source = string.gsub(
			source,
			string.format("(%s)%s", keyword, CLASS.PATTERNS.KEYWORD_WITH_CAPSULE),
			function(keyword, arguments)
				--// Arguments need to be separated as they are the literal string
				--// in the capsule at this point
				local separatedArguments = self:getMatches(arguments, CLASS.PATTERNS.ARGUMENTS_SEPERATOR)
				table.insert(captures, {[keyword] = separatedArguments})
				return ""
			end
		)
		--// Captures without argument capsules are left in the source and are
		--// collected at this point
		source = string.gsub(
			source,
			string.format("(%s)", keyword),
			function(keyword)
				table.insert(captures, {[keyword] = {}})
				return ""
			end
		)
	end
	
	for _, capture in pairs(captures) do
		for keyword, args in pairs(capture) do
			print(keyword, " : ", table.concat(args, ", "))
		end
	end
	
	return captures
end

function CLASS:getCleanText(text)
	--// Returns a cleaned up version of the text
	local cleanText = string.gsub(text:lower(), "%s+", " ")
	return cleanText
end

function CLASS:getCommandsFromBatch(commandsBatch)
	--// Returns a table containing all of the commands in a command batch
	return self:getMatches(commandsBatch, CLASS.PATTERNS.COMMANDS_FROM_BATCH)
end

function CLASS:getDefinitionsFromCommand(command)
	--// Returns a table containing all of the definitions in a command
	return self:getMatches(command, CLASS.PATTERNS.DEFINITIONS_FROM_COMMAND)
end

function CLASS:getIdentifiedDefinitions(command)
	--// Returns a table with keys identifying the different definitions in a command
	local definitions = self:getDefinitionsFromCommand(command)
	local ARGUMENT_SEPARATOR = CLASS.CONFIGURATIONS.ARGUMENT_SEPARATOR
	local doesTargetExist = (definitions[2] ~= nil) and (string.find(definitions[2], ARGUMENT_SEPARATOR) ~= nil) or (false)
	local identifiedDefinitions = {
		COMMAND = definitions[1],
		TARGET = doesTargetExist and definitions[2] or nil,
		EXTRA = table.concat(definitions, " ", (doesTargetExist) and (3) or (2), #definitions)
	}
	return identifiedDefinitions
end

function CLASS:parseCommandDefinition(commandDefinition)
	--// Returns a table of commands and modifiers along with their arguments
	--// A Capture is found in a source by a table of possible captures and it
	--// includes the following arguments in an argument capsule if there is any
	--// A Capture is structured like this [capture] = {[arg1], [arg2], ... }
	--// Captures are structured like this Captures = {[capture1], [capture2], ... }
	local commandCaptures = self:getCaptures(commandDefinition, CLASS.SORTED_COMMANDS)
	local modifierCaptures = self:getCaptures(commandDefinition, CLASS.SORTED_MODIFIERS)
	return {
		COMMANDS = commandCaptures,
		MODIFIERS = modifierCaptures
	}
end

function CLASS:parseTargetDefinition(targetDefinition)
	--// Returns a table of all the targets
	return self:getMatches(targetDefinition, CLASS.PATTERNS.ARGUMENTS_SEPERATOR)
end

function CLASS:parseExtraArgumentDefinition(extraArgumentDefinition)
	--// Returns the extra argument
	return extraArgumentDefinition
end

function CLASS:organizeParsedData(parsedData)
	--// Returns a table of organized parsed data
end

function CLASS:parse(text)
	--// We need to clean the text to remove unnecessary whitespace
	local cleanedText = self:getCleanText(text)
	--// Commands can be sent in a batch, we need to process them individually
	local commands = self:getCommandsFromBatch(text)
	--// Temporary parsed data needs to be collected, it will be organized before the function returns
	local parsedData = {}
	--// We need to collect the temporary parsed data from each command in the batch
	for _, command in pairs(commands) do
		--// Only the command definition is guaranteed to exist and be the first one, others are
		--// optional and can take different places in the overall command structure, thus we
		--// must identify all the definitions before parsing them
		local identifiedDefinitions = self:getIdentifiedDefinitions(command)
		--// Temporary parsed data is collected for this command
		table.insert(
			parsedData,
			{
				--// Allows us to determine the commands and modifiers
				commandData = self:parseCommandDefinition(identifiedDefinitions.COMMAND),
				--// Allows us to determine the targets
				targetData = self:parseTargetDefinition(identifiedDefinitions.TARGET),
				--// Provides backward compatibility, only one argument which will be sent to
				--// every command
				extraArgumentData = self:parseExtraArgumentDefinition(identifiedDefinitions.EXTRA)
			}
		)
	end
	--// Create the final form of the parsed data before returning it
	return self:organizeParsedData(parsedData)
end

--// INSTRUCTIONS //--

CLASS.__index = CLASS

return CLASS.new()
