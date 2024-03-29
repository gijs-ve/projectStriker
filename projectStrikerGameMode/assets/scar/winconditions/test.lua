-----------------------------------------------------------------------
-- Imported Scripts
-----------------------------------------------------------------------

-- Import Utility Scripts
import("cardinal.scar")							-- Contains sfx references, UI templates, and Civ/Age helper functions
import("ScarUtil.scar")							-- Contains game helper functions

-- Import Gameplay Systems
import("gameplay/score.scar")					-- Tracks player score
import("gameplay/diplomacy.scar")				-- Manages Tribute

-- Import Win Conditions
import("winconditions/elimination.scar")		-- Support for player quitting or dropping (through pause menu or disconnection)
import("winconditions/surrender.scar")			-- Support for player surrender (through pause menu)

-- Import UI Support
import("gameplay/chi/current_dynasty_ui.scar")	-- Displays Chinese Dynasty UI
import("gameplay/event_cues.scar")
import("gameplay/currentageui.scar")

--Striker functions
import("gameFunctions/getAttackType.scar") --Checks if someone is team 1 or 2
import("gameFunctions/getEntityType.scar")
import("gameFunctions/getKickAngle.scar") --Calculaters input angle of a deer kick
import("gameFunctions/getKickDirection.scar") --Checks kick direction N/E/S/W
import("gameFunctions/getTeamFromPlayer.scar") --Checks if someone is team 1 or 2
import("gameFunctions/handleAgeAndResources.scar") --sets resources to 0 and age to 4
import("gameFunctions/handleCivs.scar") --Kicks people not HRE
--import("gameFunctions/handleTackle.scar") --Handles damage receival
import("gameFunctions/handleTeams.scar") --Kicks people not in team 1 or 2
import("gameFunctions/handleUnitHeight.scar") --Fixes y position for moved units
import("gameFunctions/mapClear.scar") --Clears map
import("gameFunctions/spawnBall.scar") --Spawns the ball
import("gameFunctions/spawnLines.scar") --Spawns all game lines
import("gameFunctions/spawnUnit.scar") --Spawns a unit



-----------------------------------------------------------------------
-- Data
-----------------------------------------------------------------------

-- Global data table that can be referenced in script functions (e.g. _mod.module = "Mod")
_mod = {
	module = "Mod",
}

-- Register the win condition (Some functions can be prepended with "Mod_" to be called automatically as part of the scripting framework)
Core_RegisterModule(_mod.module)




-----------------------------------------------------------------------
-- Constants  
-----------------------------------------------------------------------
gameState = {}
gameState.phase = "WarmUp"

lines = {}
lines.middle = 0
lines.zLineTop = lines.middle+55
lines.zLineBottom = lines.middle-55
lines.xLineTop = lines.middle+100
lines.xLineBottom = lines.middle-100
lines.zGoalTop = lines.zLineTop-35
lines.zGoalBottom = lines.zLineBottom+35
lines.xGoalTop = lines.xLineTop + 35
lines.xGoalBottom = lines.xLineBottom - 35
lines.xSpawnOffset = 15
lines.zSpawnOffset = 5

positions = {}
positions.arenaHeight = World_GetHeightAt(0,0)
positions.center = World_Pos(0, positions.arenaHeight+1, 0)


-----------------------------------------------------------------------
-- Scripting framework 
-----------------------------------------------------------------------

-- Called during load as part of the game setup sequence
function Mod_OnGameSetup()
	print("Mod_OnGameSetup")
	
end

-- Called before initialization, preceding other module OnInit functions
function Mod_PreInit()
	print("Mod_PreInit")
	-- Enable Tribute UI
	Core_CallDelegateFunctions("TributeEnabled", true)
	
end

-- Called on match initialization before handing control to the player
function Mod_OnInit()
	print("Mod_OnInit")
	localPlayer = Core_GetPlayersTableEntry(Game_GetLocalPlayer())	
	mapClear()
	FOW_RevealAll()
	handleCivs()
	teams = handleTeams()
	positions.teamSpawns = getTeamSpawns()
	Rule_AddGlobalEvent(handleDamage, GE_DamageReceived)	
end

function getTeamSpawns()
	local spawns = {}
	spawns.team1 = generateTeamSpawns("team1")	
	spawns.team2 = generateTeamSpawns("team2")

	
	function generateTeamSpawns(team)
		local spawns = {}
		local teamTable
		local xLineStart
		local xLineStart		
		local playerCount = #team
		local xUnitOffset = math.abs(xLineTop - xLineBottom - lines.xSpawnOffset*2) / playerCount
		local zUnitOffset = math.abs(zLineTop - zLineBottom - lines.zSpawnOffset*2) / playerCount
		local unitCount = playerCount * 3
		local cavTable = {}
		local spearTable = {} 
		local maaTable = {}
		if team == "team1" then
			teamTable = teams.team1
			xLineStart = lines.middle - lines.xSpawnOffset
			zLineStart = zLineTop - lines.zSpawnOffset	
			for i = 0, unitCount do
			    if i < unitCount / 3 then
				    local position = {}
				    position.x =  xLineStart - (i * xUnitOffset) 
				    position.z = zLineStart - (i * zUnitOffset) 
				    table.insert(spearTable, i, position)
			    end
			    if i >= unitCount / 3 and i < (unitCount / 3) * 2 then
			    	local position = {}
			    	position.x =  xLineStart - (i * xUnitOffset) 
		    		position.z = zLineStart - (i * zUnitOffset) 
		    		table.insert(maaTable, i, position)
		    	end
		    	if i >= (unitCount / 3) * 2 then
		    		local position = {}
		    		position.x =  xLineStart - (i * xUnitOffset) 
		    		position.z = zLineStart - (i * zUnitOffset) 
		    		table.insert(cavTable, i, position)
			    end
	    	end        
		end
		if team == "team2" then
			teamTable = teams.team2
			xLineStart = lines.middle + lines.xSpawnOffset
			zLineStart = zLineTop + lines.zSpawnOffset
			for i = 0, unitCount do
			if i < unitCount / 3 then
				local position = {}
				position.x =  xLineStart + (i * xUnitOffset) 
				position.z = zLineStart + (i * zUnitOffset) 
				table.insert(spearTable, i, position)
			end
			if i >= unitCount / 3 and i < (unitCount / 3) * 2 then
				local position = {}
				position.x =  xLineStart + (i * xUnitOffset) 
				position.z = zLineStart + (i * zUnitOffset) 
				table.insert(maaTable, i, position)
			end
			if i >= (unitCount / 3) * 2 then
				local position = {}
				position.x =  xLineStart + (i * xUnitOffset) 
				position.z = zLineStart + (i * zUnitOffset) 
				table.insert(cavTable, i, position)
			end
		end
		end		
		
		
	end
end

function handleOnTick()	
	handleBall()
	for i, player in pairs(PLAYERS) do
		local allEntities = Player_GetAllEntities(player.id)
		--local cav = EGroup_Filter(allEntities, "cavalry", FILTER_KEEP)
		EGroup_ForEach(allEntities, handleUnitOutside)
	end
	
end


function handleBall()
	if ball == nil or gameState.phase ~= "inGame" then
		return
	end
	local ballPosition = Entity_GetPosition(ball)
	ballPosition.y = World_GetHeightAt(ballPosition.x, ballPosition.z)
	Entity_SetPosition(ball, ballPosition)	
	if ballPosition.x > lines.xGoalBottom and 
		ballPosition.x < lines.xLineBottom and
		ballPosition.z < lines.zGoalTop and
		ballPosition.z > lines.zGoalBottom then
		handleGoal("team1")
		return
	end
	if ballPosition.x < lines.xGoalTop and 
		ballPosition.x > lines.xLineTop and
		ballPosition.z < lines.zGoalTop and
		ballPosition.z > lines.zGoalBottom then
		handleGoal("team2")
		return
	end
	handleUnitOutside(nil, nil, ball)
	print("test")
end

function handleGoal(team)
	if team == "team1" then
		teams.score.team1 = teams.score.team1 + 1
	end
	if team == "team2" then
		teams.score.team2 = teams.score.team2 + 1
	end
	gameState.phase = "preparing"
end	

function handleUnitOutside(groupid, itemindex, unit)
	local entityPosition = Entity_GetPosition(unit)
	local entityType = getEntityType(unit)
	if entityType == "gaia" and groupid ~= nil then 
		return
	end
	local flatPush = World_GetRand(2, 5)	
	local differenceMultiplier = 0.45
	local yEntityAddition = 3
	if entityType == "cavalry" then
		yEntityAddition = 10
	end
	if entityPosition.x >= lines.xLineTop then	
		local difference = (math.abs(entityPosition.x - lines.xLineTop))
		entityPosition.x = lines.xLineTop - (difference * differenceMultiplier) - flatPush
		entityPosition.y = World_GetHeightAt(entityPosition.x, entityPosition.z) + yEntityAddition
		Entity_SetPosition(unit, entityPosition)
	end
	if entityPosition.x <= lines.xLineBottom then
		local difference = (math.abs(entityPosition.x - lines.xLineBottom))
		entityPosition.x = lines.xLineBottom + (difference * differenceMultiplier) + flatPush		
		entityPosition.y = World_GetHeightAt(entityPosition.x, entityPosition.z) + yEntityAddition
		Entity_SetPosition(unit, entityPosition)
	end
	if entityPosition.z >= lines.zLineTop then
		local difference = (math.abs(entityPosition.z - lines.zLineTop))
		entityPosition.z = lines.zLineTop - (difference * differenceMultiplier) - flatPush
		entityPosition.y = World_GetHeightAt(entityPosition.x, entityPosition.z) + yEntityAddition
		Entity_SetPosition(unit, entityPosition)		
	end
	if entityPosition.z <= lines.zLineBottom then
		local difference = (math.abs(entityPosition.z - lines.zLineBottom))
		entityPosition.z = lines.zLineBottom + (difference * differenceMultiplier) + flatPush
		entityPosition.y = World_GetHeightAt(entityPosition.x, entityPosition.z) + yEntityAddition
		Entity_SetPosition(unit, entityPosition)			
	end

	return false
end

function handleDamage(ctx)
	local attackingPlayer = ctx.attackerOwner
	local attackerUnit = ctx.attacker
	local tackledUnit = ctx.victim
	local tackledPlayer = ctx.victimOwner
	local tackledSquad = ctx.victimSquad
	if attackingPlayer == nil or attackerUnit == nil or tackledUnit == nil then
		return
	end
	local attackerLocation = Entity_GetPosition(attackerUnit)
	local tackledLocation = Entity_GetPosition(tackledUnit)
	local attackerTeam = getTeamFromPlayer(attackingPlayer)
	if attackerTeam == nil then 
		return 
	end
	
	--Tackle
	local attackerOffset = 3 + World_GetRand(1, 2)
	local tackledOffset = 35 + World_GetRand(1, 5)
	local mirrorOffset = 25
	local attackType = getAttackType(attackerUnit, tackledUnit)
	if attackType == nil then return end
	if attackType == "cavToMan" or attackType == "spearToCav" or attackType == "manToSpear" then
		if attackerTeam == "team1" then
			attackerLocation.x = attackerLocation.x - attackerOffset
			tackledLocation.x = tackledLocation.x + tackledOffset			
		end
		if attackerTeam == "team2" then
			attackerLocation.x = attackerLocation.x + attackerOffset
			tackledLocation.x = tackledLocation.x - tackledOffset
		end
		Entity_SetPosition(attackerUnit, attackerLocation)
		Entity_SetPosition(tackledUnit, tackledLocation)
		return
	end	
	if attackType == "mirrorREMOVED" then
		if attackerTeam == "team1" then
			attackerLocation.x = attackerLocation.x - mirrorOffset
			tackledLocation.x = tackledLocation.x + mirrorOffset			
		end
		if attackerTeam == "team2" then
			attackerLocation.x = attackerLocation.x + mirrorOffset
			tackledLocation.x = tackledLocation.x - mirrorOffset
		end
		Entity_SetPosition(attackerUnit, attackerLocation)
		Entity_SetPosition(tackledUnit, tackledLocation)
		return
	end
	
	--Kick
	if attackType == "cavToBall" or attackType == "spearToBall" or attackType == "manToBall" then
		local kickDirection = getKickDirection(attackerLocation, tackledLocation)
		local kickAngle = getKickAngle(attackerLocation, tackledLocation, kickDirection)
		setNewDeerPosition(attackerLocation, tackledLocation, tackledUnit, kickDirection, kickAngle, attackType)
		--SGroup_DeSpawn(tackledUnit)
	end
end



function setNewDeerPosition(kickLocation, deerLocation, ball, kickDirection, kickAngle, attackType)
	--Distance ball and kicker are travelling
	local ballOffset = nil
	local ballOffset = 3
	local ballOffset =  World_GetRand(1, 5)
	if attackType == "cavToBall" then
		ballOffset = 10 + ballOffset
	end
	if attackType == "manToBall" then
		ballOffset = 30 + ballOffset
	end
	if attackType == "spearToBall" then
		ballOffset = 35 + ballOffset +  World_GetRand(1, 4)
	end	
	
	local xLength = math.sin(kickAngle) * ballOffset
	local zLength = math.cos(kickAngle) * ballOffset
	local newDeerLocation = deerLocation
	if kickDirection == "north" then		
		newDeerLocation.x = newDeerLocation.x + xLength
		newDeerLocation.z = newDeerLocation.z + zLength
	end	
	if kickDirection == "east" then		
		newDeerLocation.x = newDeerLocation.x + xLength
		newDeerLocation.z = newDeerLocation.z - zLength
	end	
	if kickDirection == "south" then		
		newDeerLocation.x = newDeerLocation.x - xLength
		newDeerLocation.z = newDeerLocation.z - zLength
	end	
	if kickDirection == "west" then		
		newDeerLocation.x = newDeerLocation.x - xLength
		newDeerLocation.z = newDeerLocation.z + zLength
	end	
	if newDeerLocation == nil then
		return
	end
	Entity_SetPosition(ball, newDeerLocation)	
end

-- Called after initialization is done when game is fading up from black
function Mod_Start()
	print("Mod_Start")
	for i, player in pairs(PLAYERS) do
		handleAgeAndResources(player.id)
		setMarchingDrills(player.id)
	end
	
	
	
	spawnLines()
	setInGame()
	Rule_AddInterval(handleOnTick, 1)
end

function setInGame()
	gameState.phase = "inGame"
	mapClear()
	for i, player in pairs(teams.team1) do
		spawnUnit("knight", World_Pos(33, 12, 45), player.id)
		spawnUnit("spear", World_Pos(33, 12, 45), player.id)
		spawnUnit("maa", World_Pos(33, 12, 45), player.id)
	end
	for i, player in pairs(teams.team2) do
		spawnUnit("knight", World_Pos(0, 12, 45), player.id)
		spawnUnit("spear", World_Pos(0, 12, 1), player.id)
		spawnUnit("maa", World_Pos(0, 12, 45), player.id)
	end
	spawnBall(positions.center)
end

function setMarchingDrills(playerId)
	marchingDrills = BP_GetUpgradeBlueprint("upgrade_infantry_marching_drills_hre")
	Player_CompleteUpgrade(playerId, marchingDrills)
end

-- Called when Core_SetPlayerDefeated() is invoked. Signals that a player has been eliminated from play due to defeat.
function Mod_OnPlayerDefeated(player, reason)
	print("Mod_OnPlayerDefeated", reason)
	
	
end

-- When a victory condition is met, a module must call Core_OnGameOver() in order to invoke this delegate and notify all modules that the match is about to end. Generally used for clean up (removal of rules, objectives, and UI elements specific to the module).
function Mod_OnGameOver()
	
	
	
end

