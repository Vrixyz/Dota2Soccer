require("util")

function onKick(keys) 
  print('onKick')
  PrintTable(keys)
  
  -- CandySoccerGameMode coding of abilities
  candySoccer_ball = GameRules.AddonTemplate.candySoccer_ball
  -- print("We tried to kick!")
  local hero = keys["attacker"]
  if (candySoccer_ball == nil) or (hero == nil) then
    print ( "candySoccer_ball: ".. tostring(candySoccer_ball))
    return
  end
  print("ball position: " .. candySoccer_ball:GetAbsOrigin().x .. "," ..candySoccer_ball:GetAbsOrigin().y .. "," .. candySoccer_ball:GetAbsOrigin().z)
  print("hero position: " .. hero:GetAbsOrigin().x .. "," .. hero:GetAbsOrigin().y .. "," .. hero:GetAbsOrigin().z)
  
  local distance = hero:GetAbsOrigin() - candySoccer_ball:GetAbsOrigin()
  if distance:Length() < 250 then
    -- print("Kicking !")
    -- print("cursorPosition: " .. tostring(hero:GetCursorPosition()) .. " ; ballPosition: " .. tostring(candySoccer_ball:GetAbsOrigin()))
    local distanceToKick = keys["target_points"][1] - candySoccer_ball:GetAbsOrigin()
    local direction = (distanceToKick * 1.5)
    direction.z = hero:GetAbsOrigin().z -- avoid clicking in weird place to shoot strangely
    candySoccer_ball:ApplyAbsVelocityImpulse(direction)
    print ("playerId: " .. hero:GetPlayerID())
    PrintTable(GameRules.AddonTemplate.vPlayers)
    candySoccer_ball.owner = GameRules.AddonTemplate.vPlayers[hero:GetPlayerID() + 1]
    hero._flTimeUnableToShoot = 1
  end
end