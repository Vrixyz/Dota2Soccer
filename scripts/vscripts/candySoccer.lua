USE_LOBBY=false
THINK_TIME = 0.1
ADDON_NAME="CANDYSOCCER"

STARTING_GOLD = 500--650
MAX_LEVEL = 1

-- CandySoccerGameMode
BASE_LEVEL = 2
TIME_TO_PICK = 5
PRE_GAME_TIME = 5
MATCH_LENGTH = 200 -- TODO: Rematch

-- Fill this table up with the required XP per level if you want to change it
XP_PER_LEVEL_TABLE = {}
for i=1,MAX_LEVEL do
  XP_PER_LEVEL_TABLE[i] = i * 100
end

GameMode = nil

function Log(msg)
  print ( '['..ADDON_NAME..'] '..msg )
end

if CandySoccerGameMode == nil then
  Log('creating CandySoccer game mode' )
  CandySoccerGameMode = {}
  CandySoccerGameMode.szEntityClassName = "CandySoccer"
  CandySoccerGameMode.szNativeClassName = "dota_base_game_mode"
  CandySoccerGameMode.__index = CandySoccerGameMode
end

function CandySoccerGameMode:new( o )
  Log('CandySoccerGameMode:new' )
  o = o or {}
  setmetatable( o, CandySoccerGameMode )
  return o
end

function CandySoccerGameMode:InitGameMode()
	Log('Starting to load Barebones gamemode...')

	-- Setup rules
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetHeroSelectionTime( TIME_TO_PICK )
	GameRules:SetPreGameTime( PRE_GAME_TIME)
	GameRules:SetPostGameTime( 60.0 )
	GameRules:SetTreeRegrowTime( 60.0 )
	GameRules:SetUseCustomHeroXPValues ( true )
	GameRules:SetGoldPerTick(0)
	Log('Rules set')

	InitLogFile( "log/CandySoccer.txt","")

	-- Hooks
	ListenToGameEvent('entity_killed', Dynamic_Wrap(CandySoccerGameMode, 'OnEntityKilled'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(CandySoccerGameMode, 'AutoAssignPlayer'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(CandySoccerGameMode, 'CleanupPlayer'), self)
	ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(CandySoccerGameMode, 'ShopReplacement'), self)
	ListenToGameEvent('player_say', Dynamic_Wrap(CandySoccerGameMode, 'PlayerSay'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(CandySoccerGameMode, 'PlayerConnect'), self)
	--ListenToGameEvent('player_info', Dynamic_Wrap(CandySoccerGameMode, 'PlayerInfo'), self)
	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(CandySoccerGameMode, 'AbilityUsed'), self)

	Convars:RegisterCommand( "command_example", Dynamic_Wrap(CandySoccerGameMode, 'ExampleConsoleCommand'), "A console command example", 0 )

	-- Fill server with fake clients
	Convars:RegisterCommand('fake', function()
    -- Check if the server ran it
    if not Convars:GetCommandClient() or DEBUG then
      -- Create fake Players
      SendToServerConsole('dota_create_fake_clients')
        
      self:CreateTimer('assign_fakes', {
        endTime = Time(),
        callback = function(candySoccer, args)
          for i=0, 9 do
            -- Check if this player is a fake one
            if PlayerResource:IsFakeClient(i) then
              -- Grab player instance
              local ply = PlayerResource:GetPlayer(i)
              -- Make sure we actually found a player instance
              if ply then
                CreateHeroForPlayer('npc_dota_hero_axe', ply)
              end
            end
          end
        end})
    end
	end, 'Connects and assigns fake Players.', 0)

	-- Change random seed
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	-- Timers
	self.timers = {}

	-- userID map
	self.vUserNames = {}
	self.vUserIds = {}
	self.vSteamIds = {}
	self.vBots = {}
	self.vBroadcasters = {}

	self.vPlayers = {}
	self.vRadiant = {}
	self.vDire = {}

	-- Active Hero Map
	self.vPlayerHeroData = {}
	Log('values set')

	Log('Precaching stuff...')
	PrecacheUnitByName('npc_precache_everything')
	Log('Done precaching!') 

	Log('Done loading Barebones gamemode!\n\n')
	
	-- CandySoccerGameMode : now custom initialization

	candySoccer_ball = CreateUnitByName('npc_candySoccer_ball', Vector(0, 0, 0), true, nil, nil, DOTA_TEAM_NOTEAM)
	if candySoccer_ball then
		Physics:Unit(candySoccer_ball)
		candySoccer_ball.Slide()
		candySoccer_ball:SetNavCollisionType (PHYSICS_NAV_BOUNCE)
	end
	goalGood = CreateUnitByName('npc_candySoccer_goal', Vector(-2500, 0, 0), true, nil, nil, DOTA_TEAM_NOTEAM)
	goalBad = CreateUnitByName('npc_candySoccer_goal', Vector(2500, 0, 0), true, nil, nil, DOTA_TEAM_NOTEAM)
	
	self.thinkState = Dynamic_Wrap( CandySoccerGameMode, '_thinkState_Prep' )
	
	goodTeamScore = 0
	badTeamScore = 0
	Log('Done loading CandySoccerGameMode!\n\n')
  
end

function CandySoccerGameMode:unStunPlayer(player)
	if player.hero:HasModifier("modifier_stunned") then
		player.hero:RemoveModifierByName("modifier_stunned")
		Log("unstunning hero")
	end
end

function CandySoccerGameMode:CaptureGameMode()
  if GameMode == nil then
    -- Set GameMode parameters
    GameMode = GameRules:GetGameModeEntity()		
    -- Disables recommended items...though I don't think it works
    GameMode:SetRecommendedItemsDisabled( true )
    -- Override the normal camera distance.  Usual is 1134
    GameMode:SetCameraDistanceOverride( 1504.0 )
    -- Set Buyback options
    GameMode:SetCustomBuybackCostEnabled( true )
    GameMode:SetCustomBuybackCooldownEnabled( true )
    GameMode:SetBuybackEnabled( false )
    -- Override the top bar values to show your own settings instead of total deaths
    GameMode:SetTopBarTeamValuesOverride ( true )
    -- Use custom hero level maximum and your own XP per level
    GameMode:SetUseCustomHeroLevels ( true )
    GameMode:SetCustomHeroMaxLevel ( MAX_LEVEL )
    GameMode:SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )
    -- Chage the minimap icon size
    GameRules:SetHeroMinimapIconSize( 300 )

    Log('Beginning Think' ) 
    GameMode:SetContextThink("BarebonesThink", Dynamic_Wrap( CandySoccerGameMode, 'Think' ), 0.1 )
  end
end

function CandySoccerGameMode:AbilityUsed(keys)
  Log('AbilityUsed')
  PrintTable(keys)
  
  -- CandySoccerGameMode coding of abilities
  
  if (keys["abilityname"] == "candySoccer_kick_ball") then
	Log("We tried to kick!")
	local hero = self.vPlayers[keys["player"] - 1].hero
	if (candySoccer_ball == nil) or (hero == nil) then
		return
	end

	local distance = hero:GetAbsOrigin() - candySoccer_ball:GetAbsOrigin()
	if distance:Length() < 250 then
		Log("Kicking !")
		Log("cursorPosition: " .. tostring(hero:GetCursorPosition()) .. " ; ballPosition: " .. tostring(candySoccer_ball:GetAbsOrigin()))
		local distanceToKick = hero:GetCursorPosition() - candySoccer_ball:GetAbsOrigin()
		local direction = (distanceToKick * 2)
		candySoccer_ball:AddPhysicsVelocity(direction)
		candySoccer_ball.owner = self.vPlayers[keys["player"] - 1]
	end	
  end
end

-- Cleanup a player when they leave
function CandySoccerGameMode:CleanupPlayer(keys)
  Log('Player Disconnected ' .. tostring(keys.userid))
end

function CandySoccerGameMode:CloseServer()
  -- Just exit
  SendToServerConsole('exit')
end

function CandySoccerGameMode:PlayerConnect(keys)
  Log('PlayerConnect')
  PrintTable(keys)
  
  -- Fill in the usernames for this userID
  self.vUserNames[keys.userid] = keys.name
  if keys.bot == 1 then
    -- This user is a Bot, so add it to the bots table
    self.vBots[keys.userid] = 1
  end
end

local hook = nil
local attach = 0
local controlPoints = {}
local particleEffect = ""

function CandySoccerGameMode:PlayerSay(keys)
  Log('PlayerSay')
  PrintTable(keys)
  
  -- Get the player entity for the user speaking
  local ply = self.vUserIds[keys.userid]
  if ply == nil then
    return
  end
  
  -- Get the player ID for the user speaking
  local plyID = ply:GetPlayerID()
  if not PlayerResource:IsValidPlayer(plyID) then
    return
  end
  
  -- Should have a valid, in-game player saying something at this point
  -- The text the person said
  local text = keys.text
  
  -- Match the text against something
  local matchA, matchB = string.match(text, "^-swap%s+(%d)%s+(%d)")
  if matchA ~= nil and matchB ~= nil then
    -- Act on the match
  end
  
end

function CandySoccerGameMode:AutoAssignPlayer(keys)
  Log('AutoAssignPlayer')
  PrintTable(keys)
  CandySoccerGameMode:CaptureGameMode()
  
  local entIndex = keys.index+1
  -- The Player entity of the joining user
  local ply = EntIndexToHScript(entIndex)
  
  -- The Player ID of the joining player
  local playerID = ply:GetPlayerID()
  
  -- Update the user ID table with this user
  self.vUserIds[keys.userid] = ply
  -- Update the Steam ID table
  self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = ply
  
  -- If the player is a broadcaster flag it in the Broadcasters table
  if PlayerResource:IsBroadcaster(playerID) then
    self.vBroadcasters[keys.userid] = 1
    return
  end
  
  -- If this player is a bot (spectator) flag it and continue on
  if self.vBots[keys.userid] ~= nil then
    return
  end

  
  playerID = ply:GetPlayerID()
  -- Figure out if this player is just reconnecting after a disconnect
  if self.vPlayers[playerID] ~= nil then
    self.vUserIds[keys.userid] = ply
    return
  end
  
  -- If we're not on D2MODD.in, assign players round robin to teams
  if not USE_LOBBY and playerID == -1 then
    if #self.vRadiant > #self.vDire then
      ply:SetTeam(DOTA_TEAM_BADGUYS)
      ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_BADGUYS)
      table.insert (self.vDire, ply)
    else
      ply:SetTeam(DOTA_TEAM_GOODGUYS)
      ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_GOODGUYS)
      table.insert (self.vRadiant, ply)
    end
    playerID = ply:GetPlayerID()
  end

  --Autoassign player
  self:CreateTimer('assign_player_'..entIndex, {
  endTime = Time(),
  callback = function(candySoccer, args)
    -- Make sure the game has started
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
      -- Assign a hero to a fake client
      local heroEntity = ply:GetAssignedHero()
      if PlayerResource:IsFakeClient(playerID) then
        if heroEntity == nil then
          CreateHeroForPlayer('npc_dota_hero_axe', ply)
        else
          PlayerResource:ReplaceHeroWith(playerID, 'npc_dota_hero_axe', 0, 0)
        end
      end
      heroEntity = ply:GetAssignedHero()
      -- Check if we have a reference for this player's hero
      if heroEntity ~= nil and IsValidEntity(heroEntity) then
        -- Set up a heroTable containing the state for each player to be tracked
        local heroTable = {
          hero = heroEntity,
          nTeam = ply:GetTeam(),
          bRoundInit = false,
          name = self.vUserNames[keys.userid],
        }
        self.vPlayers[playerID] = heroTable
		
		-- CandySoccerGameMode:

			-- if not heroEntity:HasModifier("modifier_stunned") then
				-- heroEntity:AddNewModifier( heroEntity, nil , "modifier_stunned", {})
				-- Log("Stunning hero")
				-- heroEntity:SetRespawnPosition(heroEntity:GetAbsOrigin())
			-- end
		
		
		for i = 1,BASE_LEVEL, 1 do
			heroEntity:HeroLevelUp(false)
		end
		Physics:Unit(heroEntity)
        return
      end
    end

    return Time() + 1.0
  end
})
end

function CandySoccerGameMode:LoopOverPlayers(callback)
  for k, v in pairs(self.vPlayers) do
    -- Validate the player
    if IsValidEntity(v.hero) then
      -- Run the callback
      if callback(v, v.hero:GetPlayerID()) then
        break
      end
    end
  end
end

function CandySoccerGameMode:ShopReplacement( keys )
  Log('ShopReplacement' )
  PrintTable(keys)

  -- The playerID of the hero who is buying something
  local plyID = keys.PlayerID
  if not plyID then return end

  -- The name of the item purchased
  local itemName = keys.itemname 
  
  -- The cost of the item purchased
  local itemcost = keys.itemcost
  
end

function CandySoccerGameMode:getItemByName( hero, name )
  -- Find item by slot
  for i=0,11 do
    local item = hero:GetItemInSlot( i )
    if item ~= nil then
      local lname = item:GetAbilityName()
      if lname == name then
        return item
      end
    end
  end

  return nil
end

function CandySoccerGameMode:_thinkState_Prep( dt )
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
      -- Waiting on the game to start...
	  return
	end
    Log("Round started !")
  	CandySoccerGameMode:CreateTimer(DoUniqueString("dothislater"), {
		endTime =  GameRules:GetGameTime() + MATCH_LENGTH,
		useGameTime = true,
		callback = function()
			Log("GAME OVER!!!")
			Log("gametime: " .. GameRules:GetGameTime())
			Log("servertime: " .. Time())

			if (goodTeamScore > badTeamScore) then
				GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
			elseif (badTeamScore > goodTeamScore) then
				GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)			
			else
				GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS) -- TODO: avoid draw
			end
		end
	})
  self.thinkState = Dynamic_Wrap( CandySoccerGameMode, '_thinkState_Match' )
  self:InitializeRound()
end

function CandySoccerGameMode:InitializeRound()
	Log("Initializing round...")
	Log("gametime: " .. GameRules:GetGameTime())
	Log("servertime: " .. Time())
	CandySoccerGameMode:LoopOverPlayers(function(player)
		if player.hero:HasModifier("modifier_stunned") then
			player.hero:RemoveModifierByName("modifier_stunned")
		end
		player.hero:RespawnHero(false, false, false)
		candySoccer_ball:SetAbsOrigin(Vector(0,0,0))
		candySoccer_ball:SetPhysicsVelocity(Vector(0,0,0))
	end)
end

function CandySoccerGameMode:passiveKick(player, player_id)
	local hero = player.hero
	if (candySoccer_ball == nil) or (hero == nil) then
		return
	end

	local distance = hero:GetAbsOrigin() - candySoccer_ball:GetAbsOrigin()
	if distance:Length() < 150 then
		Log("collision with a unit")
		local direction = - (distance:Normalized())
		candySoccer_ball:AddPhysicsVelocity(direction * 200)
		candySoccer_ball.owner = player
	end	
end

function CandySoccerGameMode:_thinkState_WaitForNewRound( dt )

 end

function CandySoccerGameMode:_thinkState_Match( dt )
	if not candySoccer_ball then
		return
	end
    -- Bind "self" in the callback
    local function _passiveKick(...)
        return self:passiveKick(...)
    end
	CandySoccerGameMode:LoopOverPlayers(_passiveKick)
	
	local distanceGoalBad = candySoccer_ball:GetAbsOrigin() - goalBad:GetAbsOrigin()
	if (distanceGoalBad:Length() < 200) then
		Log("GOAL!!!")
		candySoccer_ball.owner.hero:IncrementKills(1)
		goodTeamScore = goodTeamScore + 1
		GameMode:SetTopBarTeamValue(DOTA_TEAM_GOODGUYS, goodTeamScore)
		
		candySoccer_ball.owner.hero:AddNewModifier( candySoccer_ball.owner.hero, nil , "modifier_legion_commander_duel_damage_boost", {})
		candySoccer_ball.owner.hero:EmitSound("Hero_LegionCommander.Duel.Victory")
		self.thinkState = Dynamic_Wrap( CandySoccerGameMode, '_thinkState_WaitForNewRound' )
		CandySoccerGameMode:CreateTimer(DoUniqueString("newround"), {
		    endTime = GameRules:GetGameTime() + 5,
		    useGameTime = true,
		    callback = function(teamfight, args)
				candySoccer_ball.owner.hero:RemoveModifierByName("modifier_legion_commander_duel_damage_boost")
				CandySoccerGameMode:InitializeRound()
			end
		})
		
		-- CandySoccerGameMode:InitializeRound()
		-- candySoccer_ball:Remove()
		-- candySoccer_ball = nil
	end
	
	local distanceGoalGood = candySoccer_ball:GetAbsOrigin() - goalGood:GetAbsOrigin()
	if (distanceGoalGood:Length() < 200) then
		Log("GOAL!!!")
		candySoccer_ball.owner.hero:IncrementKills(1)
		badTeamScore = badTeamScore + 1
		GameMode:SetTopBarTeamValue(DOTA_TEAM_BADGUYS, badTeamScore)
		
		CandySoccerGameMode:InitializeRound()
		-- candySoccer_ball:Remove()
		-- candySoccer_ball = nil
	end
	return
end

function CandySoccerGameMode:Think()
  -- If the game's over, it's over.
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return
  end

  -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
  local now = GameRules:GetGameTime()
  if CandySoccerGameMode.t0 == nil then
    CandySoccerGameMode.t0 = now
  end
  local dt = now - CandySoccerGameMode.t0
  CandySoccerGameMode.t0 = now

  CandySoccerGameMode:thinkState( dt )

  -- Process timers
  for k,v in pairs(CandySoccerGameMode.timers) do
    local bUseGameTime = false
    if v.useGameTime and v.useGameTime == true then
      bUseGameTime = true;
    end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      CandySoccerGameMode.timers[k] = nil

      -- Run the callback
      local status, nextCall = pcall(v.callback, CandySoccerGameMode, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          CandySoccerGameMode.timers[k] = v
        end

      else
        -- Nope, handle the error
        CandySoccerGameMode:HandleEventError('Timer', k, nextCall)
      end
    end
  end

  return THINK_TIME
end

function CandySoccerGameMode:HandleEventError(name, event, err)
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

function CandySoccerGameMode:CreateTimer(name, args)
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
  self.timers[name] = args
end

function CandySoccerGameMode:RemoveTimer(name)
  -- Remove this timer
  self.timers[name] = nil
end

function CandySoccerGameMode:RemoveTimers(killAll)
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

function CandySoccerGameMode:ExampleConsoleCommand()
  print( '******* Example Console Command ***************' )
  local cmdPlayer = Convars:GetCommandClient()
  if cmdPlayer then
    local playerID = cmdPlayer:GetPlayerID()
    if playerID ~= nil and playerID ~= -1 then
      -- Do something here for the player who called this command
    end
  end

  print( '*********************************************' )
end

function CandySoccerGameMode:OnEntityKilled( keys )
  Log('OnEntityKilled Called' )
  PrintTable( keys )
  
  -- The Unit that was Killed
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  -- The Killing entity
  local killerEntity = nil

  if keys.entindex_attacker ~= nil then
    killerEntity = EntIndexToHScript( keys.entindex_attacker )
  end

  -- Put code here to handle when an entity gets killed
end

-- A helper function for dealing damage from a source unit to a target unit.  Damage dealt is pure damage
function dealDamage(source, target, damage)
  local unit = nil
  if damage == 0 then
    return
  end
  
  if source ~= nil then
    unit = CreateUnitByName("npc_dummy_unit", target:GetAbsOrigin(), false, source, source, source:GetTeamNumber())
  else
    unit = CreateUnitByName("npc_dummy_unit", target:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_NOTEAM)
  end
  unit:AddNewModifier(unit, nil, "modifier_invulnerable", {})
  unit:AddNewModifier(unit, nil, "modifier_phased", {})
  local dummy = unit:FindAbilityByName("reflex_dummy_unit")
  dummy:SetLevel(1)
  
  local abilIndex = math.floor((damage-1) / 20) + 1
  local abilLevel = math.floor(((damage-1) % 20)) + 1
  if abilIndex > 100 then
    abilIndex = 100
    abilLevel = 20
  end
  
  local abilityName = "modifier_damage_applier" .. abilIndex
  unit:AddAbility(abilityName)
  ability = unit:FindAbilityByName( abilityName )
  ability:SetLevel(abilLevel)
  
  local diff = nil
  
  local hp = target:GetHealth()
  
  diff = target:GetAbsOrigin() - unit:GetAbsOrigin()
  diff.z = 0
  unit:SetForwardVector(diff:Normalized())
  unit:CastAbilityOnTarget(target, ability, 0 )
  
  CandySoccerGameMode:CreateTimer(DoUniqueString("damage"), {
    endTime = GameRules:GetGameTime() + 0.3,
    useGameTime = true,
    callback = function(candySoccer, args)
      unit:Destroy()
      if target:GetHealth() == hp and hp ~= 0 and damage ~= 0 then
        Log("WARNING: dealDamage did no damage: " .. hp)
        dealDamage(source, target, damage)
      end
    end
  })
end
