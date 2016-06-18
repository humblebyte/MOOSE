--- This module contains the AIBALANCER class.
-- 
-- ===
-- 
-- 1) @{AIBalancer#AIBALANCER} class, extends @{Base#BASE}
-- ================================================
-- The @{AIBalancer#AIBALANCER} class controls the dynamic spawning of AI GROUPS depending on a SET_CLIENT.
-- There will be as many AI GROUPS spawned as there at CLIENTS in SET_CLIENT not spawned.
-- 
-- 1.1) AIBALANCER construction method:
-- ------------------------------------
-- Create a new AIBALANCER object with the @{#AIBALANCER.New} method:
-- 
--    * @{#AIBALANCER.New}: Creates a new AIBALANCER object.
-- 
-- 1.2) AIBALANCER returns AI to Airbases:
-- ---------------------------------------
-- You can configure to have the AI to return to:
-- 
--    * @{#AIBALANCER.ReturnToHomeAirbase}: Returns the AI to the home @{Airbase#AIRBASE}.
--    * @{#AIBALANCER.ReturnToNearestAirbases}: Returns the AI to the nearest friendly @{Airbase#AIRBASE}.
-- 
-- 1.3) AIBALANCER allows AI to patrol specific zones:
-- ---------------------------------------------------
-- Use @{AIBalancer#AIBALANCER.AddPatrolZone}() to specify zones where airplanes need patrol a zone ( @{Zone} ) for a specific time, at a specific altitude, with a specific speed.
-- Multiple zones can be patrolled, calling @{AIBalancer#AIBALANCER.AddPatrolZone}() multiple times. The AI will patrol at a random zone in the list. 
-- And when the PatrolTime is finished, it will patrol another zone.
-- 
-- 1.4) AIRBALANCER manages AI out of fuel events:
-- -----------------------------------------------
-- Once an AI is out of fuel, it will contact the home base, so that on time, a new replacement AI is spawned, while the old will orbit for a specific time and RTB.
-- Use @{AIBalancer#AIBALANCER.GuardFuel}() to guard for each AI the fuel status.
--
-- ===
-- 
-- CREDITS
-- =======
-- **Dutch_Baron (James)** Who you can search on the Eagle Dynamics Forums.
-- Working together with James has resulted in the creation of the AIBALANCER class. 
-- James has shared his ideas on balancing AI with air units, and together we made a first design which you can use now :-)
-- 
-- **SNAFU**
-- Had a couple of mails with the guys to validate, if the same concept in the GTI/CAP script could be reworked within MOOSE.
-- Non of the script code has been used however within the new AIBALANCER moose class.
-- 
-- @module AIBalancer
-- @author FlightControl

--- AIBALANCER class
-- @type AIBALANCER
-- @field Set#SET_CLIENT SetClient
-- @field Spawn#SPAWN SpawnAI
-- @field #boolean ToNearestAirbase
-- @field Set#SET_AIRBASE ReturnAirbaseSet
-- @field DCSTypes#Distance ReturnTresholdRange
-- @field #boolean ToHomeAirbase
-- @extends Base#BASE
AIBALANCER = {
  ClassName = "AIBALANCER",
}

--- Creates a new AIBALANCER object, building a set of units belonging to a coalitions, categories, countries, types or with defined prefix names.
-- @param #AIBALANCER self
-- @param SetClient A SET_CLIENT object that will contain the CLIENT objects to be monitored if they are alive or not (joined by a player).
-- @param SpawnAI A SPAWN object that will spawn the AI units required, balancing the SetClient.
-- @return #AIBALANCER self
function AIBALANCER:New( SetClient, SpawnAI )

  -- Inherits from BASE
  local self = BASE:Inherit( self, BASE:New() )
  
  self.SetClient = SetClient
  if type( SpawnAI ) == "table" then
    if SpawnAI.ClassName and SpawnAI.ClassName == "SPAWN" then
      self.SpawnAI = { SpawnAI }
    else
      local SpawnObjects = true
      for SpawnObjectID, SpawnObject in pairs( SpawnAI ) do
        if SpawnObject.ClassName and SpawnObject.ClassName == "SPAWN" then
          self:E( SpawnObject.ClassName )
        else
          self:E( "other object" )
          SpawnObjects = false
        end
      end
      if SpawnObjects == true then
        self.SpawnAI = SpawnAI
      else
        error( "No SPAWN object given in parameter SpawnAI, either as a single object or as a table of objects!" )
      end
    end
  end

  self.ToNearestAirbase = false
  self.ReturnHomeAirbase = false

  self.AIMonitorSchedule = SCHEDULER:New( self, self._ClientAliveMonitorScheduler, {}, 1, 10, 0 ) 
  
  return self
end

--- Returns the AI to the nearest friendly @{Airbase#AIRBASE}.
-- @param #AIBALANCER self
-- @param DCSTypes#Distance ReturnTresholdRange If there is an enemy @{Client#CLIENT} within the ReturnTresholdRange given in meters, the AI will not return to the nearest @{Airbase#AIRBASE}.
-- @param Set#SET_AIRBASE ReturnAirbaseSet The SET of @{Set#SET_AIRBASE}s to evaluate where to return to.
function AIBALANCER:ReturnToNearestAirbases( ReturnTresholdRange, ReturnAirbaseSet )

  self.ToNearestAirbase = true
  self.ReturnTresholdRange = ReturnTresholdRange
  self.ReturnAirbaseSet = ReturnAirbaseSet
end

--- Returns the AI to the home @{Airbase#AIRBASE}.
-- @param #AIBALANCER self
-- @param DCSTypes#Distance ReturnTresholdRange If there is an enemy @{Client#CLIENT} within the ReturnTresholdRange given in meters, the AI will not return to the nearest @{Airbase#AIRBASE}.
function AIBALANCER:ReturnToHomeAirbase( ReturnTresholdRange )

  self.ToHomeAirbase = true
  self.ReturnTresholdRange = ReturnTresholdRange
end

--- @param #AIBALANCER self
function AIBALANCER:_ClientAliveMonitorScheduler()

  self.SetClient:ForEachClient(
    --- @param Client#CLIENT Client
    function( Client )
      local ClientAIAliveState = Client:GetState( self, 'AIAlive' )
      self:T( ClientAIAliveState )
      if Client:IsAlive() then
        if ClientAIAliveState == true then
          Client:SetState( self, 'AIAlive', false )
          
          local AIGroup = Client:GetState( self, 'AIGroup' ) -- Group#GROUP
          
          if self.ToNearestAirbase == false and self.ToHomeAirbase == false then
            AIGroup:Destroy()
          else
            -- We test if there is no other CLIENT within the self.ReturnTresholdRange of the first unit of the AI group.
            -- If there is a CLIENT, the AI stays engaged and will not return.
            -- If there is no CLIENT within the self.ReturnTresholdRange, then the unit will return to the Airbase return method selected.

            local ClientInZone = { Value = false }          
            local RangeZone = ZONE_RADIUS:New( 'RangeZone', AIGroup:GetPointVec2(), self.ReturnTresholdRange )
            
            self:E( RangeZone )
            
            _DATABASE:ForEachUnit(
              --- @param Unit#UNIT RangeTestUnit
              function( RangeTestUnit, RangeZone, AIGroup, ClientInZone )
                self:E( { ClientInZone, RangeTestUnit.UnitName, RangeZone.ZoneName } )
                if RangeTestUnit:IsInZone( RangeZone ) == true then
                  self:E( "in zone" )
                  if RangeTestUnit:GetCoalition() ~= AIGroup:GetCoalition() then
                    self:E( "in range" )
                    ClientInZone.Value = true
                  end
                end
              end,
              
              --- @param Zone#ZONE_RADIUS RangeZone
              -- @param Group#GROUP AIGroup
              function( RangeZone, AIGroup, ClientInZone )
                local AIGroupTemplate = AIGroup:GetTemplate()
                if ClientInZone.Value == false then
                  if self.ToHomeAirbase == true then
                    local WayPointCount = #AIGroupTemplate.route.points
                    local SwitchWayPointCommand = AIGroup:CommandSwitchWayPoint( 1, WayPointCount, 1 )
                    AIGroup:SetCommand( SwitchWayPointCommand )
                    AIGroup:MessageToRed( "Returning to home base ...", 30 )
                  else
                    -- Okay, we need to send this Group back to the nearest base of the Coalition of the AI.
                    --TODO: i need to rework the POINT_VEC2 thing.
                    local PointVec2 = POINT_VEC2:New( AIGroup:GetPointVec2().x, AIGroup:GetPointVec2().y  )
                    local ClosestAirbase = self.ReturnAirbaseSet:FindNearestAirbaseFromPointVec2( PointVec2 )
                    self:T( ClosestAirbase.AirbaseName )
                    AIGroup:MessageToRed( "Returning to " .. ClosestAirbase:GetName().. " ...", 30 )
                    local RTBRoute = AIGroup:RouteReturnToAirbase( ClosestAirbase )
                    AIGroupTemplate.route = RTBRoute
                    AIGroup:Respawn( AIGroupTemplate )
                  end
                end
              end
              , RangeZone, AIGroup, ClientInZone
            )
            
          end
        end
      else
        if not ClientAIAliveState or ClientAIAliveState == false then
          Client:SetState( self, 'AIAlive', true )
          
          -- OK, spawn a new group from the SpawnAI objects provided.
          local SpawnAICount = #self.SpawnAI
          local SpawnAIIndex = math.random( 1, SpawnAICount )
          Client:SetState( self, 'AIGroup', self.SpawnAI[SpawnAIIndex]:Spawn() )
        end
      end
    end
  )
  return true
end



