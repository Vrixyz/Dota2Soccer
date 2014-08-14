USE_LOBBY=false
THINK_TIME = 0.25
ADDON_NAME="CANDYSOCCER"

TIME_TO_PICK = 5
PRE_GAME_TIME = 30
MATCH_LENGTH = 200 -- TODO: Rematch

GRAVITY_AMOUNT = -80
FRICTION_MULTIPLIER = 0.04

require( "candysoccer_game_spawner" )
require( "candysoccer_game_round" )

local function loadModule(name)
    local status, err = pcall(function()
        -- Load the module
        require(name)
    end)

    if not status then
        -- Tell the user about it
        print('WARNING: '..name..' failed to load!')
        print(err)
    end
end

loadModule ( 'util' )
-- loadModule ( 'physics' )



function Log(msg)
  print ( '['..ADDON_NAME..'] '..msg )
end

-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

function Precache( context )

    -- Precache things we know we'll use.  Possible file types include (but not limited to):
    -- PrecacheResource( "model", "*.vmdl", context )
    -- PrecacheResource( "soundfile", "*.vsndevts", context )
    -- PrecacheResource( "particle", "*.vpcf", context )
    -- PrecacheResource( "particle_folder", "particles/folder", context )
    PrecacheResource( "particle", "particles/units/heroes/hero_legion_commander/legion_commander_duel_victory.vpcf", context )	
	
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	-- ListenToGameEvent('player_connect_full', Dynamic_Wrap(CAddonTemplateGameMode, 'AutoAssignPlayer'), self)
  -- ListenToGameEvent('player_connect', Dynamic_Wrap(CAddonTemplateGameMode, 'PlayerConnect'), self)

	-- Timers
	self.timers = {}

	-- userID map
	self.vUserNames = {}
	self.vUserIds = {}
	self.vSteamIds = {}
	self.vBots = {}
	self.vBroadcasters = {}
  Log("self.vPlayers touched")
	self.vPlayers = {}
	self.vRadiant = {}
	self.vDire = {}

	-- Active Hero Map
	self.vPlayerHeroData = {}
	Log('values set')

	Log('Precaching stuff...')
	-- PrecacheUnitByName('npc_precache_everything') -- TODO: use new precaching
	Log('Done precaching!') 
	
	print( "Template addon is loaded." )
	self._nRoundNumber = 1
	self._currentRound = nil
  
  self:_ReadGameConfiguration()
  
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetHeroSelectionTime( TIME_TO_PICK )
	GameRules:SetPreGameTime( PRE_GAME_TIME)
  
  ListenToGameEvent('player_connect_full', Dynamic_Wrap(CAddonTemplateGameMode, 'AutoAssignPlayer'), self)
	-- ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(CAddonTemplateGameMode, 'AbilityUsed'), self)
  ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( CAddonTemplateGameMode, "OnGameRulesStateChange" ), self )
  
	-- self._entGoalGood = CreateUnitByName('npc_candySoccer_goal', Vector(-2000, 0, 0), true, nil, nil, DOTA_TEAM_NOTEAM)
	-- self._entGoalBad = CreateUnitByName('npc_candySoccer_goal', Vector(2000, 0, 0), true, nil, nil, DOTA_TEAM_NOTEAM)
  goodTeamScore = 0
  badTeamScore = 0
end

function CAddonTemplateGameMode:_ReadGameConfiguration()
	local kv = LoadKeyValues( "scripts/maps/" .. GetMapName() .. ".txt" )
	kv = kv or {} -- Handle the case where there is not keyvalues file

	self._flPrepTimeBetweenRounds = tonumber( kv.PrepTimeBetweenRounds or 5 )
  self._flMatchTimeLeft = tonumber( kv.MatchLength or MATCH_LENGTH )
	self:_ReadBallSpawnsConfiguration( kv["Spawners"] )
  self:_ReadRoundConfigurations( kv )
end

-- Verify spawners if random is set
function CAddonTemplateGameMode:ChooseRandomSpawnInfo()
	if #self._vBallSpawnsList == 0 then
		error( "Attempt to choose a random spawn, but no random spawns are specified in the data." )
		return nil
	end
	return self._vBallSpawnsList[ RandomInt( 1, #self._vBallSpawnsList ) ]
end

-- Verify valid spawns are defined and build a table with them from the keyvalues file
function CAddonTemplateGameMode:_ReadBallSpawnsConfiguration( kvSpawns )
	self._vBallSpawnsList = {}
	if type( kvSpawns ) ~= "table" then
		return
	end
	for _,sp in pairs( kvSpawns ) do			-- Note "_" used as a shortcut to create a temporary throwaway variable
		table.insert( self._vBallSpawnsList, {
			szSpawnerName = sp.SpawnerName or ""
		} )
	end
end

-- Set number of rounds without requiring index in text file
function CAddonTemplateGameMode:_ReadRoundConfigurations( kv )
	self._vRounds = {}
	while true do
		local szRoundName = string.format("Round%d", #self._vRounds + 1 )
		local kvRoundData = kv[ szRoundName ]
		if kvRoundData == nil then
			return
		end
		local roundObj = CCandySoccerGameRound()
		roundObj:ReadConfiguration( kvRoundData, self, #self._vRounds + 1 )
		table.insert( self._vRounds, roundObj )
	end
end

function CAddonTemplateGameMode:CaptureGameMode()
  if GameMode == nil then
    GameMode = GameRules:GetGameModeEntity()
    GameMode:SetTopBarTeamValuesOverride ( true )
	  GameMode:SetCameraDistanceOverride( 1504.0 )
    
    Log('Beginning Think' )
    -- GameMode:SetContextThink("CandySoccerThink", _gameThink, THINK_TIME )-- old one
   -- GameMode:SetThink( "Think", self, THINK_TIME )
    GameMode:SetThink( "GameThink", self, "GameThink", THINK_TIME )
  end
end

-- When game state changes set state in script
function CAddonTemplateGameMode:OnGameRulesStateChange()
  Log("OnGameRuleStageChange: " .. tostring(GameRules:State_Get()))
  Log("DOTA_GAMERULES_STATE_PRE_GAME: " .. tostring(DOTA_GAMERULES_STATE_PRE_GAME))
  Log("DOTA_GAMERULES_STATE_GAME_IN_PROGRESS: " .. tostring(DOTA_GAMERULES_STATE_GAME_IN_PROGRESS))
  Log("DOTA_GAMERULES_STATE_POST_GAME: " .. tostring(DOTA_GAMERULES_STATE_POST_GAME))
	local nNewState = GameRules:State_Get()
	if nNewState == DOTA_GAMERULES_STATE_PRE_GAME then
		ShowGenericPopup( "#holdout_instructions_title", "#holdout_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )
	elseif nNewState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
    self:_InitializeWaitForNewRound()
	end
end

function CAddonTemplateGameMode:AutoAssignPlayer(keys)
  local self = GameRules.AddonTemplate -- still don't know how to pass self..
  Log('AutoAssignPlayer')
  PrintTable(keys)
  CAddonTemplateGameMode:CaptureGameMode()
  
  local entIndex = keys.index+1
  -- The Player entity of the joining user
  local ply = PlayerInstanceFromIndex(entIndex)
  if self.vPlayers == nil then
    Log("self.vPlayers touched second?")
    self.vPlayers = {}
  end
  PrintTable(ply)
  -- The Player ID of the joining player
  local playerID = ply:GetPlayerID()
  Log("Player has connected ! his id is: " .. playerID .. " and his index is : " .. entIndex)
  Log("self.vPlayers filled")
  self.vPlayers[keys["userid"]] = ply
  return Time() + 1.0
end

function CAddonTemplateGameMode:LoopOverPlayers(callback)
  local self = GameRules.AddonTemplate
  if self.vPlayers == nil then
    Log("self.vPlayers is nil !!!")
    return
  end
  for k, v in pairs(self.vPlayers) do
    -- Validate the player
    if IsValidEntity(v:GetAssignedHero()) then
      -- Run the callback
      if callback(v, v:GetAssignedHero():GetPlayerID()) then
        break
      end
    end
  end
end

function CAddonTemplateGameMode:AbilityUsed(keys)
  Log('AbilityUsed')
  PrintTable(keys)
  
  -- CandySoccerGameMode coding of abilities
  
  if (keys["abilityname"] == "candySoccer_kick_ball") then
    -- Log("We tried to kick!")
    local hero = self.vPlayers[keys["player"]]:GetAssignedHero()
    if (self.candySoccer_ball == nil) or (hero == nil) then
      return
    end
    Log("ball position: " .. self.candySoccer_ball:GetAbsOrigin().x .. "," ..self.candySoccer_ball:GetAbsOrigin().y .. "," .. self.candySoccer_ball:GetAbsOrigin().z)
    Log("hero position: " .. hero:GetAbsOrigin().x .. "," .. hero:GetAbsOrigin().y .. "," .. hero:GetAbsOrigin().z)
    
    local distance = hero:GetAbsOrigin() - self.candySoccer_ball:GetAbsOrigin()
    if distance:Length() < 250 then
      -- Log("Kicking !")
      -- Log("cursorPosition: " .. tostring(hero:GetCursorPosition()) .. " ; ballPosition: " .. tostring(self.candySoccer_ball:GetAbsOrigin()))
      local distanceToKick = hero:GetCursorPosition() - self.candySoccer_ball:GetAbsOrigin()
      local direction = (distanceToKick * 1.5)
      direction.z = hero:GetAbsOrigin().z -- avoid clicking in weird place to shoot strangely
      self.candySoccer_ball:ApplyAbsVelocityImpulse(direction)
      self.candySoccer_ball.owner = self.vPlayers[keys["player"]]
      hero._flTimeUnableToShoot = 1
    end	
  end
end

function CAddonTemplateGameMode:InitializeRound()
    --local entity = Entities:First()
    --while entity ~= nil do
      --Log("an entity:")
      --Log(entity:GetName())
      --entity = Entities:Next(entity)
    --end
  Log("Initializing round...")
	Log("gametime: " .. GameRules:GetGameTime())
	self._currentRound = self._vRounds[ 1 ]
	self._currentRound:Begin()
  self.candySoccer_ball = self._currentRound._entBall
	
  self._bInitialized = true
end

function CAddonTemplateGameMode:GameThink( )
  local self = GameRules.AddonTemplate -- don't know how to pass self to that..
  if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
    
    -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
    local now = GameRules:GetGameTime()
    if self.t0 == nil then
      self.t0 = now
    end
    local dt = now - self.t0
    self.t0 = now
    -- Log("timeleft: ".. tostring(self._flPrepTimeLeft) .. " ; deltaTime: " .. dt)
    if self._flPrepTimeLeft ~= nil then
      self:_thinkState_Prep( dt )
      -- Log('preparation time')
    else
      self:_thinkState_Match( dt )
      -- Log('match time')
    end
  elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then		-- Safe guard catching any state that may exist beyond DOTA_GAMERULES_STATE_POST_GAME
    return nil
  end
  return THINK_TIME
end

function CAddonTemplateGameMode:_thinkState_Prep( dt )
  -- Log("TimeLeft: "..  tostring(self._flPrepTimeLeft))
  
  if self._flPrepTimeLeft <= 0 then
    self:InitializeRound()
    self._flPrepTimeLeft = nil
    if self._entPrepTimeQuest then
			UTIL_RemoveImmediate( self._entPrepTimeQuest )
			self._entPrepTimeQuest = nil
		end
    return
  end
  
  if not self._entPrepTimeQuest then
		self._entPrepTimeQuest = SpawnEntityFromTableSynchronous( "quest", { name = "PrepTime", title = "#DOTA_Quest_CandySoccer_PrepTime" } )
		self._entPrepTimeQuest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_ROUND, self._nRoundNumber )

		-- self._vRounds[ self._nRoundNumber ]:Precache()
    -- self._vRounds[ 1 ]:Precache()
	end
	self._entPrepTimeQuest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_CURRENT_VALUE, self._flPrepTimeLeft)
  		self._entPrepTimeQuest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_ROUND, self._flPrepTimeLeft )
  self._flPrepTimeLeft = self._flPrepTimeLeft - dt
end

function CAddonTemplateGameMode:passiveKick(dt, player, player_id) -- TODO: make this an ability
	local hero = player:GetAssignedHero()
	if (self.candySoccer_ball == nil) or (hero == nil) then
		return
	end
  if hero._flTimeUnableToShoot ~= nil and hero._flTimeUnableToShoot > 0 then
    hero._flTimeUnableToShoot = hero._flTimeUnableToShoot - dt
    return 
  end
	local distance = hero:GetAbsOrigin() - self.candySoccer_ball:GetAbsOrigin()
	if distance:Length() < 150 then
		Log("collision with a unit")
		local direction = - (distance:Normalized())
		self.candySoccer_ball:ApplyAbsVelocityImpulse(direction * 100)
		self.candySoccer_ball.owner = player
    hero._flTimeUnableToShoot = 0.5
	end	
end

 function CAddonTemplateGameMode:celebrateFor(player)
  ParticleManager:CreateParticle("legion_commander_duel_winner_rays", PATTACH_OVERHEAD_FOLLOW, player:GetAssignedHero())
  ParticleManager:CreateParticle("legion_commander_duel_victory", PATTACH_OVERHEAD_FOLLOW, player:GetAssignedHero())
  player:GetAssignedHero():EmitSound("Hero_LegionCommander.Duel.Victory")
 end
 
function CAddonTemplateGameMode:_InitializeWaitForNewRound()
  self._flPrepTimeLeft = self._flPrepTimeBetweenRounds
  self._bInitialized = false
  Log("Now waiting for a new round ! " .. self._flPrepTimeLeft .. " time left")
  return THINK_TIME
end

function CAddonTemplateGameMode:_thinkState_Match( dt )
	if not self.candySoccer_ball then
		return
	end
  -- Bind "self" in the callback
  local function _passiveKick(...)
      return self:passiveKick(dt, ...)
  end
	CAddonTemplateGameMode:LoopOverPlayers(_passiveKick)
  
	if self._currentRound ~= nil then
    self._currentRound:Think()
    if self._currentRound:IsFinished() then
      self._currentRound:End()
      self._currentRound = nil

      self._nRoundNumber = self._nRoundNumber + 1
    end
  end
  
	local distanceGoalBad = self.candySoccer_ball:GetAbsOrigin() - self._currentRound._entGoalBad:GetAbsOrigin()
	if (distanceGoalBad:Length() < 200) then
		Log("GOAL!!!")
		self.candySoccer_ball.owner:GetAssignedHero():IncrementKills(1)
    goodTeamScore = goodTeamScore + 1
		GameMode:SetTopBarTeamValue(DOTA_TEAM_GOODGUYS, goodTeamScore)

		CAddonTemplateGameMode:celebrateFor(self.candySoccer_ball.owner)
    self._currentRound:End()
    self._currentRound = nil
    self._nRoundNumber = self._nRoundNumber + 1
    self:_InitializeWaitForNewRound()
	elseif ((self.candySoccer_ball:GetAbsOrigin() - self._currentRound._entGoalGood:GetAbsOrigin()):Length() < 200) then
		Log("GOAL!!!")
		self.candySoccer_ball.owner:GetAssignedHero():IncrementKills(1)
		badTeamScore = badTeamScore + 1
		GameMode:SetTopBarTeamValue(DOTA_TEAM_BADGUYS, badTeamScore)
		
		CAddonTemplateGameMode:celebrateFor(self.candySoccer_ball.owner)
    self._currentRound:End()
		self._currentRound = nil
    self._nRoundNumber = self._nRoundNumber + 1
    self:_InitializeWaitForNewRound()
	end
  
  if (self._flMatchTimeLeft < 0) then
    if (goodTeamScore > badTeamScore) then
      GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
    elseif (badTeamScore > goodTeamScore) then
      GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)			
    else
      GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS) -- TODO: avoid draw
    end
    -- self.thinkState = postGame -- code post game function
  else
    self._flMatchTimeLeft = self._flMatchTimeLeft - dt
  end
	return
end

function CAddonTemplateGameMode:HandleEventError(name, event, err)
  -- This gets fired when an event throws an error

  -- Log to console
  print(err)

  -- Ensure we have data
  name = tostring(name or 'unknown')
  event = tostring(event or 'unknown')
  err = tostring(err or 'unknown')

  -- Tell everyone there was an error
  Say(nil, name .. ' threw an error on event '..event, false)
  Say(nil, err, false)

  -- Prevent loop arounds
  if not self.errorHandled then
    -- Store that we handled an error
    self.errorHandled = true
  end
end

function CAddonTemplateGameMode:Think()
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return nil
  end
  -- Process timers
  if CAddonTemplateGameMode.timers == nil then
    return THINK_TIME
  end
  for k,v in pairs(CAddonTemplateGameMode.timers) do
    local bUseGameTime = false
    if v.useGameTime and v.useGameTime == true then
      bUseGameTime = true;
    end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      CAddonTemplateGameMode.timers[k] = nil

      -- Run the callback
      local status, nextCall = pcall(v.callback, CAddonTemplateGameMode, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          CAddonTemplateGameMode.timers[k] = v
        end

      else
        -- Nope, handle the error
        CAddonTemplateGameMode:HandleEventError('Timer', k, nextCall)
      end
    end
  end

  return THINK_TIME
end

function CAddonTemplateGameMode:CreateTimer(name, args)
  --[[
  args: {
  endTime = Time you want this timer to end: Time() + 30 (for 30 seconds from now),
  useGameTime = use Game Time instead of Time()
  callback = function(frota, args) to run when this timer expires,
  text = text to display to clients,
  send = set this to true if you want clients to get this,
  persist = bool: Should we keep this timer even if the match ends?
  }

  If you want your timer to loop, simply return the time of the next callback inside of your callback, for example:

  callback = function()
  return Time() + 30 -- Will fire again in 30 seconds
  end
  ]]

  if not args.endTime or not args.callback then
    print("Invalid timer created: "..name)
    return
  end

  -- Store the timer
  if self.timers == nil then
    self.timers = {}
  end
  self.timers[name] = args
end

function CAddonTemplateGameMode:RemoveTimer(name)
  -- Remove this timer
  self.timers[name] = nil
end

function CAddonTemplateGameMode:RemoveTimers(killAll)
  local timers = {}

  -- If we shouldn't kill all timers
  if not killAll then
    -- Loop over all timers
    for k,v in pairs(self.timers) do
      -- Check if it is persistant
      if v.persist then
        -- Add it to our new timer list
        timers[k] = v
      end
    end
  end

  -- Store the new batch of timers
  self.timers = timers
end