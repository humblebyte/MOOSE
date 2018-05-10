--- **AI** -- (R2.4) - Models the intelligent transportation of infantry and other cargo.
--
-- ===
-- 
-- ### Author: **FlightControl**
-- 
-- ===       
--
-- @module AI_Cargo_Dispatcher

--- @type AI_CARGO_DISPATCHER
-- @extends Core.Fsm#FSM_CONTROLLABLE


--- # AI\_CARGO\_DISPATCHER class, extends @{Core.Base#BASE}
-- 
-- ===
-- 
-- AI\_CARGO\_DISPATCHER brings a dynamic cargo handling capability for AI groups.
-- 
-- Armoured Personnel APCs (APC), Trucks, Jeeps and other carrier equipment can be mobilized to intelligently transport infantry and other cargo within the simulation.
-- The AI\_CARGO\_DISPATCHER module uses the @{Cargo} capabilities within the MOOSE framework.
-- CARGO derived objects must be declared within the mission to make the AI\_CARGO\_DISPATCHER object recognize the cargo.
-- Please consult the @{Cargo} module for more information. 
-- 
-- 
-- 
-- @field #AI_CARGO_DISPATCHER
AI_CARGO_DISPATCHER = {
  ClassName = "AI_CARGO_DISPATCHER",
  SetAPC = nil,
  SetDeployZones = nil,
  AI_CARGO_APC = {}
}

--- @type AI_CARGO_DISPATCHER.AI_CARGO_APC
-- @map <Wrapper.Group#GROUP, AI.AI_Cargo_APC#AI_CARGO_APC>

--- @field #AI_CARGO_DISPATCHER.AI_CARGO_APC 
AI_CARGO_DISPATCHER.AICargoAPC = {}

--- @field #AI_CARGO_DISPATCHER.PickupCargo
AI_CARGO_DISPATCHER.PickupCargo = {}

--- Creates a new AI_CARGO_DISPATCHER object.
-- @param #AI_CARGO_DISPATCHER self
-- @param Core.Set#SET_GROUP SetAPC
-- @param Core.Set#SET_CARGO SetCargo
-- @param Core.Set#SET_ZONE SetDeployZone
-- @return #AI_CARGO_DISPATCHER
-- @usage
-- 
-- -- Create a new cargo dispatcher
-- SetAPC = SET_GROUP:New():FilterPrefixes( "APC" ):FilterStart()
-- SetCargo = SET_CARGO:New():FilterTypes( "Infantry" ):FilterStart()
-- SetDeployZone = SET_ZONE:New():FilterPrefixes( "Deploy" ):FilterStart()
-- AICargoDispatcher = AI_CARGO_DISPATCHER:New( SetAPC, SetCargo )
-- 
function AI_CARGO_DISPATCHER:New( SetAPC, SetCargo, SetDeployZones )

  local self = BASE:Inherit( self, FSM:New() ) -- #AI_CARGO_DISPATCHER

  self.SetAPC = SetAPC -- Core.Set#SET_GROUP
  self.SetCargo = SetCargo -- Core.Set#SET_CARGO
  self.SetDeployZones = SetDeployZones -- Core.Set#SET_ZONE

  self:SetStartState( "Dispatch" ) 
  
  self:AddTransition( "*", "Monitor", "*" )

  self:AddTransition( "*", "Pickup", "*" )
  self:AddTransition( "*", "Loading", "*" )
  self:AddTransition( "*", "Loaded", "*" )

  self:AddTransition( "*", "Deploy", "*" )
  self:AddTransition( "*", "Unloading", "*" )
  self:AddTransition( "*", "Unloaded", "*" )
  
  self.MonitorTimeInterval = 30
  self.DeployRadiusInner = 200
  self.DeployRadiusOuter = 500
  
  return self
end


--- The Start trigger event, which actually takes action at the specified time interval.
-- @param #AI_CARGO_DISPATCHER self
-- @param Wrapper.Group#GROUP APC
-- @return #AI_CARGO_DISPATCHER
function AI_CARGO_DISPATCHER:onafterMonitor()

  for APCGroupName, Carrier in pairs( self.SetAPC:GetSet() ) do
    local Carrier = Carrier -- Wrapper.Group#GROUP
    local AICargoAPC = self.AICargoAPC[Carrier]
    if not AICargoAPC then
    
      -- ok, so this APC does not have yet an AI_CARGO_APC object...
      -- let's create one and also declare the Loaded and UnLoaded handlers.
      self.AICargoAPC[Carrier] = self:AICargo( Carrier, self.SetCargo, self.CombatRadius )
      AICargoAPC = self.AICargoAPC[Carrier]
      
      function AICargoAPC.OnAfterPickup( AICargoAPC, APC, From, Event, To, Cargo )
        self:Pickup( APC, Cargo )
      end
      
      function AICargoAPC.OnAfterLoad( AICargoAPC, APC )
        self:Loading( APC )
      end

      function AICargoAPC.OnAfterLoaded( AICargoAPC, APC, From, Event, To, Cargo )
        self:Loaded( APC, Cargo )
      end

      function AICargoAPC.OnAfterDeploy( AICargoAPC, APC )
        self:Deploy( APC )
      end      

      function AICargoAPC.OnAfterUnload( AICargoAPC, APC )
        self:Unloading( APC )
      end      

      function AICargoAPC.OnAfterUnloaded( AICargoAPC, APC )
        self:Unloaded( APC )
      end      
    end

    -- The Pickup sequence ...
    -- Check if this APC need to go and Pickup something...
    self:I( { IsTransporting = AICargoAPC:IsTransporting() } )
    if AICargoAPC:IsTransporting() == false then
      -- ok, so there is a free APC
      -- now find the first cargo that is Unloaded
      
      local PickupCargo = nil
      
      for CargoName, Cargo in pairs( self.SetCargo:GetSet() ) do
        if Cargo:IsUnLoaded() and not Cargo:IsDeployed() then
          if not self.PickupCargo[Cargo] then
            self.PickupCargo[Cargo] = Carrier
            PickupCargo = Cargo
            break
          end
        end
      end
      if PickupCargo then
        AICargoAPC:Pickup( PickupCargo:GetCoordinate():GetRandomCoordinateInRadius( 25, 50 ), 70 )
        break
      end
    end
  end

  self:__Monitor( self.MonitorTimeInterval )

  return self
end



--- Make a APC run for a cargo deploy action after the cargo Pickup trigger has been initiated, by default.
-- @param #AI_CARGO_DISPATCHER self
-- @param Wrapper.Group#GROUP APC
-- @return #AI_CARGO_DISPATCHER
function AI_CARGO_DISPATCHER:onafterPickup( From, Event, To, APC, Cargo )
  return self
end

--- Make a APC run for a cargo deploy action after the cargo has been loaded, by default.
-- @param #AI_CARGO_DISPATCHER self
-- @param Wrapper.Group#GROUP APC
-- @return #AI_CARGO_DISPATCHER
function AI_CARGO_DISPATCHER:OnAfterLoaded( From, Event, To, APC, Cargo )

  self:I( { "Loaded Dispatcher", APC } )
  local RandomZone = self.SetDeployZones:GetRandomZone()
  self:I( { RandomZone = RandomZone } )
  
  self.AICargoAPC[APC]:Deploy( RandomZone:GetCoordinate():GetRandomCoordinateInRadius(25,100), 70 )
  self.PickupCargo[Cargo] = nil

  return self
end




