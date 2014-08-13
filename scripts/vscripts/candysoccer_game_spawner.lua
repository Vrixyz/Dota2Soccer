--[[
	CCandySoccerGameSpawner - A single unit spawner for CandySoccer.
]]
if CCandySoccerGameSpawner == nil then
	CCandySoccerGameSpawner = class({})
end


function CCandySoccerGameSpawner:ReadConfiguration( name, kv, gameRound )
	self._gameRound = gameRound
	self._dependentSpawners = {}

	self._szName = name
	self._szNPCClassName = kv.NPCName or ""
	self._szSpawnerName = kv.SpawnerName or ""
  self._bDontOffsetSpawn = ( tonumber( kv.DontOffsetSpawn or 0 ) ~= 0 )
end


function CCandySoccerGameSpawner:Precache()
	PrecacheUnitByNameAsync( self._szNPCClassName, function( sg ) self._sg = sg end )
end


function CCandySoccerGameSpawner:Begin()
	
	self._vecSpawnLocation = nil
	if self._szSpawnerName ~= "" then
		local entSpawner = Entities:FindByName( nil, self._szSpawnerName )
		if not entSpawner then
			print( string.format( "Failed to find spawner named %s for %s\n", self._szSpawnerName, self._szName ) )
		end
		self._vecSpawnLocation = entSpawner:GetAbsOrigin()
	end
  self:DoSpawn()
end

function CCandySoccerGameSpawner:End()
  if self._gameRound._entBall ~= nil then
    self._gameRound._entBall:SetVelocity(Vector(0,0,0))
    self._gameRound._entBall:SetOrigin(self._vHiddenPosition)
  end
end

function CCandySoccerGameSpawner:_GetSpawnLocation()
	return self._vecSpawnLocation
end

function CCandySoccerGameSpawner:_UpdateRandomSpawn()
	self._vecSpawnLocation = Vector( 0, 0, 0 )

	local spawnInfo = self._gameRound:ChooseRandomSpawnInfo()
	if spawnInfo == nil then
		print( string.format( "Failed to get random spawn info for spawner %s.", self._szName ) )
		return
	end
	
	local entSpawner = Entities:FindByName( nil, spawnInfo.szSpawnerName )
	if not entSpawner then
		print( string.format( "Failed to find spawner named %s for %s.", spawnInfo.szSpawnerName, self._szName ) )
		return
	end
	self._vecSpawnLocation = entSpawner:GetAbsOrigin()
end


function CCandySoccerGameSpawner:DoSpawn()
  print("spawn !")
	if self._szSpawnerName == "" then
		self:_UpdateRandomSpawn()
	end

	local vBaseSpawnLocation = self:_GetSpawnLocation()
	if not vBaseSpawnLocation then return end

  local szNPCClassToSpawn = self._szNPCClassName
  if bIsChampion and self._szChampionNPCClassName ~= "" then
    szNPCClassToSpawn = self._szChampionNPCClassName
  end

  local vSpawnLocation = vBaseSpawnLocation
  if not self._bDontOffsetSpawn then
    vSpawnLocation = vSpawnLocation + RandomVector( RandomFloat( 0, 200 ) )
  end

  --local entUnitDisplay = CreateUnitByName( szNPCClassToSpawn, vSpawnLocation, true, nil, nil, DOTA_TEAM_NOTEAM ) -- TODO: noteam shows its position, should make neutral, but then it goes back to position...
  local entUnit = Entities:FindByName(nil, "ball")
  self._vHiddenPosition = entUnit:GetOrigin()
  entUnit:SetOrigin(vSpawnLocation)
  --entUnitDisplay:SetParent(entUnit, "punk")
  if entUnit then
    -- if self._gameRound._entBall ~= nil then
      -- self._gameRound._entBall.RemoveSelf()
    -- end
    self._gameRound._entBall = entUnit
  end
end


function CCandySoccerGameSpawner:StatusReport()
	print( string.format( "** Spawner %s", self._szNPCClassName ) )
	print( string.format( "%d of %d spawned", self._nUnitsSpawnedThisRound, self._nTotalUnitsToSpawn ) )
end