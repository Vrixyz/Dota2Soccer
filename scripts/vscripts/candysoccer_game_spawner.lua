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
  self._szUnitName = kv.UnitName or ""
	self._szNPCClassName = kv.NPCName or ""
  self._szUnitNameToTeleport = kv.UnitNameToTeleport or ""
	self._szSpawnerName = kv.SpawnerName or ""
  self._bDontOffsetSpawn = ( tonumber( kv.DontOffsetSpawn or 0 ) ~= 0 )
  if kv.Team ~= nil then
    if kv.Team == "DOTA_TEAM_BADGUYS" then
      self._nTeam = DOTA_TEAM_BADGUYS
    elseif kv.Team == "DOTA_TEAM_GOODGUYS" then
      self._nTeam = DOTA_TEAM_GOODGUYS
    else
      self._nTeam = DOTA_TEAM_NOTEAM
    end
  end
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
  return self:DoSpawn()
end

function CCandySoccerGameSpawner:End()
  if self._szNPCClassName == "" then
    self._entUnit:SetVelocity(Vector(0,0,0))
    self._entUnit:SetOrigin(self._vHiddenPosition)
  else
    self._entUnit:RemoveSelf()
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


  local vSpawnLocation = vBaseSpawnLocation
  if not self._bDontOffsetSpawn then
    vSpawnLocation = vSpawnLocation + RandomVector( RandomFloat( 0, 200 ) )
  end
  
  if szNPCClassToSpawn ~= "" then
    self._entUnit = CreateUnitByName( szNPCClassToSpawn, vSpawnLocation, true, nil, nil, self._nTeam ) -- TODO: noteam shows its position, should make neutral, but then it goes back to position...
    self._entUnit:SetUnitName(self._szUnitName)
  else
    self._entUnit = Entities:FindByName(nil, "ball")
    self._vHiddenPosition = self._entUnit:GetOrigin()
    self._entUnit:SetOrigin(vSpawnLocation)
  end
  return self._entUnit -- TODO: get that return and do logic there
end


function CCandySoccerGameSpawner:StatusReport()
	print( string.format( "** Spawner %s", self._szNPCClassName ) )
	print( string.format( "%d of %d spawned", self._nUnitsSpawnedThisRound, self._nTotalUnitsToSpawn ) )
end