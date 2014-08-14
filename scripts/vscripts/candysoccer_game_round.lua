--[[
	CCandySoccerGameRound - A single round of Holdout
]]

if CCandySoccerGameRound == nil then
	CCandySoccerGameRound = class({})
end


function CCandySoccerGameRound:ReadConfiguration( kv, gameMode, roundNumber )
	self._gameMode = gameMode
	self._nRoundNumber = roundNumber

	self._vSpawners = {}
	for k, v in pairs( kv ) do
		if type( v ) == "table" and v.SpawnerName then
			local spawner = CCandySoccerGameSpawner()
			spawner:ReadConfiguration( k, v, self )
			self._vSpawners[ k ] = spawner
		end
	end
end


function CCandySoccerGameRound:Precache()
	for _, spawner in pairs( self._vSpawners ) do
		spawner:Precache()
	end
end

function CCandySoccerGameRound:Begin()
  self._flTimeStart = GameRules:GetGameTime()
  self._flTimeElapsed = 0
  self.bIsFinished = false
	self._vEventHandles = {
		ListenToGameEvent( "entity_killed", Dynamic_Wrap( CCandySoccerGameRound, "OnEntityKilled" ), self ),
	}

	self._vPlayerStats = {}
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		self._vPlayerStats[ nPlayerID ] = {
			nBallPassReceived = 0,
			nBallPassSucceed = 0,
      nBallLost = 0,
      nGoal = 0,
      nBallTaken = 0,
      flBallAvgTimePossession = 0,
		}
	end

  self._entBall = self._vSpawners["Ball"]:Begin()
  self._entGoalGood = self._vSpawners["GoalGood"]:Begin()
  self._entGoalBad = self._vSpawners["GoalBad"]:Begin()
	--for _, spawner in pairs( self._vSpawners ) do
    
		--spawner:Begin()
	--end
end


function CCandySoccerGameRound:End()
	for _, eID in pairs( self._vEventHandles ) do
		StopListeningToGameEvent( eID )
	end
	self._vEventHandles = {}

	for _,spawner in pairs( self._vSpawners ) do
		spawner:End()
	end
  
	local roundEndSummary = {
		nRoundNumber = self._nRoundNumber - 1,
		-- flTimeElapsed = self._flTimeElapsed,
    nIdPlayerGoal = 0, -- TODO: update this properly
    nTeamScoring = DOTA_TEAM_GOODGUYS,
	}

	local playerSummaryCount = 0
	for i = 1, DOTA_MAX_TEAM_PLAYERS do
		local nPlayerID = i-1
		if PlayerResource:HasSelectedHero( nPlayerID ) then
			local szPlayerPrefix = string.format( "Player_%d_", playerSummaryCount)
			playerSummaryCount = playerSummaryCount + 1
			local playerStats = self._vPlayerStats[ nPlayerID ]
			roundEndSummary[ szPlayerPrefix .. "HeroName" ] = PlayerResource:GetSelectedHeroName( nPlayerID )
			roundEndSummary[ szPlayerPrefix .. "PassReceived" ] = playerStats.nBallPassReceived
			roundEndSummary[ szPlayerPrefix .. "PassSucceed" ] = playerStats.nBallPassSucceed
			roundEndSummary[ szPlayerPrefix .. "BallLost" ] = playerStats.nBallLost
      roundEndSummary[ szPlayerPrefix .. "BallTaken" ] = playerStats.nBallTaken
      -- roundEndSummary[ szPlayerPrefix .. "AvgTimePossession" ] = playerStats.flBallAvgTimePossession
		end
	end
	FireGameEvent( "candysoccer_show_round_end_summary", roundEndSummary )
end


function CCandySoccerGameRound:Think()
	-- for _, spawner in pairs( self._vSpawners ) do
		-- spawner:Think()
	-- end
  
  -- self._entBall:Think() -- check if our ball is near a goal !
  
  -- TODO: update players information ?
end


function CCandySoccerGameRound:ChooseRandomSpawnInfo()
	return self._gameMode:ChooseRandomSpawnInfo()
end


function CCandySoccerGameRound:IsFinished()
  return self._bIsFinished
end