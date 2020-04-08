--- **Ops** - Airwing Squadron.
--
-- **Main Features:**
--
--    * Set parameters like livery, skill valid for all squadron members.
--    * Define modex and callsigns.
--    * Define mission types, this squadron can perform (see Ops.Auftrag#AUFTRAG).
--    * Pause/unpause squadron operations.
--
-- ===
--
-- ### Author: **funkyfranky**
-- @module Ops.Squadron
-- @image OPS_Squadron.png


--- SQUADRON class.
-- @type SQUADRON
-- @field #string ClassName Name of the class.
-- @field #boolean Debug Debug mode. Messages to all about status.
-- @field #string lid Class id string for output to DCS log file.
-- @field #string name Name of the squadron.
-- @field #string templatename Name of the template group.
-- @field Wrapper.Group#GROUP templategroup Template group.
-- @field #table assets Squadron assets.
-- @field #table missiontypes Mission types the squadron can perform.
-- @field #string livery Livery of the squadron.
-- @field #number skill Skill of squadron members.
-- @field #number modex Modex.
-- @field #number modexcounter Counter to incease modex number for assets.
-- @field #string callsignName Callsign name.
-- @field #number callsigncounter Counter to increase callsign names for new assets.
-- @field Ops.AirWing#AIRWING airwing The AIRWING object the squadron belongs to.
-- @field #number Ngroups Number of asset flight groups this squadron has. 
-- @field #number engageRange Engagement range in meters.
-- @field #string attribute Generalized attribute of the squadron template group.
-- @field #number tankerSystem For tanker squads, the refuel system used (boom=0 or probpe=1). Default nil.
-- @field #number refuelSystem For refuelable squads, the refuel system used (boom=0 or probpe=1). Default nil.
-- @field #number TACANmin TACAN min channel.
-- @field #number TACANmax TACAN max channel.
-- @field #table TACANused Table of used TACAN channels.
-- @extends Core.Fsm#FSM

--- Be surprised!
--
-- ===
--
-- ![Banner Image](..\Presentations\CarrierAirWing\SQUADRON_Main.jpg)
--
-- # The SQUADRON Concept
--
--
--
-- @field #SQUADRON
SQUADRON = {
  ClassName      = "SQUADRON",
  Debug          =   nil,
  lid            =   nil,
  name           =   nil,
  templatename   =   nil,
  assets         =    {},
  missiontypes   =    {},
  livery         =   nil,
  skill          =   nil,
  modex          =   nil,
  modexcounter   =     0,
  callsignName   =   nil,
  callsigncounter=    11,
  airwing        =   nil,
  Ngroups        =   nil,
  engageRange    =   nil,
  tankerSystem   =   nil,
  refuelSystem   =   nil,
  TACANmin       =   nil,
  TACANmax       =   nil,
  TACANused      =    {},
}

--- SQUADRON class version.
-- @field #string version
SQUADRON.version="0.0.5"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- TODO list
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- DONE: Engage radius.
-- DONE: Modex.
-- DONE: Call signs.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new SQUADRON object and start the FSM.
-- @param #SQUADRON self
-- @param #string TemplateGroupName Name of the template group.
-- @param #number Ngroups Number of asset groups of this squadron. Default 3.
-- @param #string SquadronName Name of the squadron, e.g. "VFA-37".
-- @return #SQUADRON self
function SQUADRON:New(TemplateGroupName, Ngroups, SquadronName)

  -- Inherit everything from FSM class.
  local self=BASE:Inherit(self, FSM:New()) -- #SQUADRON

  -- Name of the template group.
  self.templatename=TemplateGroupName

  -- Squadron name.
  self.name=tostring(SquadronName or TemplateGroupName)
  
  -- Set some string id for output to DCS.log file.
  self.lid=string.format("SQUADRON %s | ", self.name)

  
  -- Template group.
  self.templategroup=GROUP:FindByName(self.templatename)
  
  -- Check if template group exists.
  if not self.templategroup then
    self:E(self.lid..string.format("ERROR: Template group %s does not exist!", tostring(self.templatename)))
    return nil
  end
  
  -- Defaults.
  self.Ngroups=Ngroups or 3  
  self:SetEngagementRange()
  
  self.attribute=self.templategroup:GetAttribute()
  
  self.refuelSystem=select(2, self.templategroup:GetUnit(1):IsRefuelable())
  self.tankerSystem=select(2, self.templategroup:GetUnit(1):IsTanker())


  -- Start State.
  self:SetStartState("Stopped")
  
  -- Add FSM transitions.
  --                 From State  -->   Event        -->     To State
  self:AddTransition("Stopped",       "Start",              "OnDuty")      -- Start FSM.
  self:AddTransition("*",             "Status",             "*")           -- Status update.
  self:AddTransition("OnDuty",        "Pause",              "Paused")      -- Pause squadron.
  self:AddTransition("Paused",        "Unpause",            "OnDuty")      -- Unpause squadron.
  self:AddTransition("*",             "Stop",               "Stopped")     -- Stop squadron.


  ------------------------
  --- Pseudo Functions ---
  ------------------------

  --- Triggers the FSM event "Start". Starts the SQUADRON. Initializes parameters and starts event handlers.
  -- @function [parent=#SQUADRON] Start
  -- @param #SQUADRON self

  --- Triggers the FSM event "Start" after a delay. Starts the SQUADRON. Initializes parameters and starts event handlers.
  -- @function [parent=#SQUADRON] __Start
  -- @param #SQUADRON self
  -- @param #number delay Delay in seconds.

  --- Triggers the FSM event "Stop". Stops the SQUADRON and all its event handlers.
  -- @param #SQUADRON self

  --- Triggers the FSM event "Stop" after a delay. Stops the SQUADRON and all its event handlers.
  -- @function [parent=#SQUADRON] __Stop
  -- @param #SQUADRON self
  -- @param #number delay Delay in seconds.

  --- Triggers the FSM event "Status".
  -- @function [parent=#SQUADRON] Status
  -- @param #SQUADRON self

  --- Triggers the FSM event "Status" after a delay.
  -- @function [parent=#SQUADRON] __Status
  -- @param #SQUADRON self
  -- @param #number delay Delay in seconds.


  -- Debug trace.
  if false then
    self.Debug=true
    BASE:TraceOnOff(true)
    BASE:TraceClass(self.ClassName)
    BASE:TraceLevel(1)
  end
  self.Debug=true


  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- User functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set livery painted on all squadron aircraft.
-- Note that the livery name in general is different from the name shown in the mission editor.
-- 
-- Valid names are the names of the **livery directories**. Check out the folder in your DCS installation:
-- 
-- * `DCS World OpenBeta\CoreMods\aircraft\<Aircraft Type>\<Livery Name>`
-- * `DCS World OpenBeta\Bazar\Liveries\<Aircraft Type>\<Livery Name>`
-- 
-- Or personal liveries you have installed somewhere in your saved games folder.
--  
-- @param #SQUADRON self
-- @param #string LiveryName Name of the livery.
-- @return #SQUADRON self
function SQUADRON:SetLivery(LiveryName)
  self.livery=LiveryName
  return self
end

--- Set skill level of all squadron team members.
-- @param #SQUADRON self
-- @param #string Skill Skill of all flights.
-- @usage mysquadron:SetSkill(AI.Skill.EXCELLENT)
-- @return #SQUADRON self
function SQUADRON:SetSkill(Skill)
  self.skill=Skill
  return self
end

--- Set mission types this squadron is able to perform.
-- @param #SQUADRON self
-- @param #table MissionTypes Table of mission types. Can also be passed as a #string if only one type.
-- @return #SQUADRON self
function SQUADRON:SetMissonTypes(MissionTypes)

  -- Ensure Missiontypes is a table.
  if MissionTypes and type(MissionTypes)~="table" then
    MissionTypes={MissionTypes}
  end
  
  -- Add ORBIT for all.  
  if not self:CheckMissionType(AUFTRAG.Type.ORBIT, MissionTypes) then
    table.insert(MissionTypes, AUFTRAG.Type.ORBIT)
  end

  -- Set table.
  self.missiontypes=MissionTypes
  
  self:I(self.missiontypes)
  
  return self
end

--- Get mission types this squadron is able to perform.
-- @param #SQUADRON self
-- @param #table MissionTypes Table of mission types.
function SQUADRON:GetMissonTypes()
  return self.missiontypes
end

--- Set max engagement range.
-- @param #SQUADRON self
-- @param #number EngageRange Engagement range in NM. Default 80 NM.
-- @return #SQUADRON self
function SQUADRON:SetEngagementRange(EngageRange)
  self.engageRange=UTILS.NMToMeters(EngageRange or 80)
  return self
end

--- Set call sign.
-- @param #SQUADRON self
-- @param #number Callsign Callsign from CALLSIGN.Aircraft, e.g. "Chevy" for CALLSIGN.Aircraft.CHEVY.
-- @param #number Index Callsign index, Chevy-**1**.
-- @return #SQUADRON self
function SQUADRON:SetCallsign(Callsign, Index)
  self.callsignName=Callsign
  self.callsignIndex=Index
  return self
end

--- Set modex.
-- @param #SQUADRON self
-- @param #number Modex A number like 100.
-- @param #string Prefix A prefix string, which is put before the `Modex` number.
-- @param #string Suffix A suffix string, which is put after the `Modex` number. 
-- @return #SQUADRON self
function SQUADRON:SetModex(Modex, Prefix, Suffix)
  self.modex=Modex
  self.modexPrefix=Prefix
  self.modexSuffix=Suffix
  return self
end

--- Set airwing.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING Airwing The airwing.
-- @return #SQUADRON self
function SQUADRON:SetAirwing(Airwing)
  self.airwing=Airwing
  return self
end

--- Add airwing asset to squadron.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING.SquadronAsset Asset The airwing asset.
-- @return #SQUADRON self
function SQUADRON:AddAsset(Asset)
  table.insert(self.assets, Asset)
  return self
end

--- Remove airwing asset from squadron.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING.SquadronAsset Asset The airwing asset.
-- @return #SQUADRON self
function SQUADRON:DelAsset(Asset)
  for i,_asset in pairs(self.assets) do
    local asset=_asset --Ops.AirWing#AIRWING.SquadronAsset
    if Asset.uid==asset.uid then
      self:T2(self.lid..string.format("Removing asset %s", asset.spawngroupname))
      table.remove(self.assets, i)
      break
    end
  end
  return self
end

--- Create a callsign for the asset.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING.SquadronAsset Asset The airwing asset.
-- @return #SQUADRON self
function SQUADRON:GetCallsign(Asset)

  if self.callsignName then
  
    Asset.callsign={}
  
    for i=1,Asset.nunits do
    
      local callsign={}
      callsign[1]=self.callsignName
      callsign[2]=math.floor(self.callsigncounter / 10)
      callsign[3]=self.callsigncounter % 10
      if callsign[3]==0 then
        callsign[3]=1
        self.callsigncounter=self.callsigncounter+2
      else
        self.callsigncounter=self.callsigncounter+1
      end
    
      Asset.callsign[i]=callsign
      
      self:T3({callsign=callsign})
    
      --TODO: there is also a table entry .name, which is a string.
    end
  
  
  end

end

--- Create a modex for the asset.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING.SquadronAsset Asset The airwing asset.
-- @return #SQUADRON self
function SQUADRON:GetModex(Asset)

  if self.modex then
  
    Asset.modex={}
  
    for i=1,Asset.nunits do
    
      Asset.modex[i]=string.format("%03d", self.modex+self.modexcounter)
      
      self.modexcounter=self.modexcounter+1
      
      self:T3({modex=Asset.modex[i]})
    
    end
    
  end
  
end

--- Get an unused TACAN channel.
-- @param #SQUADRON self
-- @param Ops.AirWing#AIRWING.SquadronAsset Asset The airwing asset.
-- @return #number TACAN channel or *nil* if no channel is free.
function SQUADRON:GetTACAN()

  if self.TACANmin and self.TACANmax then
  
    for channel=self.TACANmin, self.TACANmax do
    
      if not self.TACANused[channel] then
        self.TACANused[channel]=true
        return channel
      end
    
    end
    
  end

  return nil
end

--- "Return" a used TACAN channel.
-- @param #SQUADRON self
-- @param #number channel The channel that is available again.
function SQUADRON:ReturnTACAN(channel)
  self.TACANused[channel]=false
end

--- Check if squadron is "OnDuty".
-- @param #SQUADRON self
-- @return #boolean If true, squdron is in state "OnDuty".
function SQUADRON:IsOnDuty()
  return self:Is("OnDuty")
end

--- Check if squadron is "Stopped".
-- @param #SQUADRON self
-- @return #boolean If true, squdron is in state "Stopped".
function SQUADRON:IsStopped()
  return self:Is("Stopped")
end

--- Check if squadron is "Paused".
-- @param #SQUADRON self
-- @return #boolean If true, squdron is in state "Paused".
function SQUADRON:IsPaused()
  return self:Is("Paused")
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Start & Status
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- On after Start event. Starts the FLIGHTGROUP FSM and event handlers.
-- @param #SQUADRON self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SQUADRON:onafterStart(From, Event, To)

  -- Short info.
  local text=string.format("Starting SQUADRON", self.name)
  self:I(self.lid..text)

  -- Start the status monitoring.
  self:__Status(-1)
end

--- On after "Status" event.
-- @param #SQUADRON self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SQUADRON:onafterStatus(From, Event, To)

  -- FSM state.
  local fsmstate=self:GetState()
  
  -- Check if group has detected any units.
  --self:_CheckAssetStatus()

  -- Short info.
  local text=string.format("Status %s: Assets %d", fsmstate, #self.assets)
  self:I(self.lid..text)
  
  if not self:IsStopped() then
    self:__Status(-30)
  end
end


--- Check asset status.
-- @param #SQUADRON self
function SQUADRON:_CheckAssetStatus()

  for _,_asset in pairs(self.assets) do
    local asset=_asset --#SQUADRON.Flight
    
    flight.flightgroup:IsSpawned()
    
  end

end

--- On after "Stop" event.
-- @param #SQUADRON self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SQUADRON:onafterStop(From, Event, To)

  self:I(self.lid.."STOPPING Squadron!")

  -- Remove all assets.
  for i=#self.assets,1,-1 do
    local asset=self.assets[i]
    self:DelAsset(asset)
  end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Misc Functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Check if there is a squadron that can execute a given mission type. Optionally, the number of required assets can be specified.
-- @param #SQUADRON self
-- @param Ops.Auftrag#AUFTRAG Mission The mission.
-- @return #boolean If true, Squadron can do that type of mission.
-- @return #table Assets that can do the required mission.
function SQUADRON:CanMission(Mission)
  
  -- Assets available for this mission.
  local assets={}

  -- On duty?=  
  if not self:IsOnDuty() then
    self:I(self.lid..string.format("Sqaud in not OnDuty but in state %s", self:GetState()))
    return false, assets
  end

  -- Check mission type. WARNING: This assumes that all assets of the squad can do the same mission types!
  local cando=self:CheckMissionType(Mission.type, self.missiontypes)
  
  -- Check that tanker mission
  if cando and Mission.type==AUFTRAG.Type.TANKER then
  
    if Mission.refuelSystem and Mission.refuelSystem==self.tankerSystem then
      -- Correct refueling system.
    else
      self:I(self.lid..string.format("INFO: Wrong refueling system requested=%s != %s=available", tostring(Mission.refuelSystem), tostring(self.tankerSystem)))
      cando=false
    end
  
  end
  
  if cando then
      
    -- Distance to target.
    local TargetDistance=Mission:GetTargetDistance(self.airwing:GetCoordinate())
    
    for _,_asset in pairs(self.assets) do
      local asset=_asset --Ops.AirWing#AIRWING.SquadronAsset
      
      local engagerange=Mission.engageMaxDistance and math.min(self.engageRange, Mission.engageMaxDistance) or self.engageRange
      
      -- Set range is valid. Mission engage distance can overrule the squad engage range.
      if TargetDistance<=engagerange then
      
        -- Check if asset is currently on a mission (STARTED or QUEUED).
        if self.airwing:IsAssetOnMission(asset) then
  
          ---
          -- Asset is already on a mission
          ---
  
          -- Check if this asset is currently on a PATROL mission (STARTED or EXECUTING).
          if self.airwing:IsAssetOnMission(asset, AUFTRAG.Type.PATROL) and Mission.type==AUFTRAG.Type.INTERCEPT then
  
            -- Check if the payload of this asset is compatible with the mission.
            -- Note: we do not check the payload as an asset that is on a PATROL mission should be able to do an intercept as well!
            --if self:CheckMissionType(Mission.type, asset.payload.missiontypes) then
              -- TODO: Check if asset actually has weapons left. Difficult!
              table.insert(assets, asset)
            --end
            
          end      
        
        else
        
          ---
          -- Asset as no current mission
          ---
  
          if asset.spawned then
          
            ---
            -- Asset is already SPAWNED (could be uncontrolled on the airfield)
            ---
          
            local combatready=false
            local flightgroup=asset.flightgroup
            if flightgroup then
            
              if (flightgroup:IsAirborne() or flightgroup:IsWaiting()) and not flightgroup:IsFuelLow() then
                combatready=true
              end
            
            end
          
            -- This asset is "combatready". Let's check if it has the right payload.
            if combatready and self:CheckMissionType(Mission.type, asset.payload.missiontypes) then
              table.insert(assets, asset)
            end
            
          else
          
            ---
            -- Asset is still in STOCK
            ---          
          
            -- Check that asset is not already requeseted for another mission.
            if not asset.requested then
          
              -- Check if we got a payload and reserve it for this asset.
              local payload=self.airwing:FetchPayloadFromStock(asset.unittype, Mission.type)
              if payload then
                asset.payload=payload
                table.insert(assets, asset)
              end
              
            end
          end
          
        end
        
      else
        self:I(self.lid..string.format("INFO: Squad is not in range. Target dist=%d > %d NM max engage Range", UTILS.MetersToNM(TargetDistance), UTILS.MetersToNM(engagerange)))
      end
      
    end -- loop over assets
    
  else
    self:I(self.lid..string.format("INFO: Squad cannot do mission type %s", Mission.type))    
  end -- if cando mission type
  
  -- Check if required assets are present.
  if Mission.nassets and Mission.nassets > #assets then
    self:I(self.lid.."INFO: Not enough assets available! Got %d but need at least %d", #assets, Mission.nassets)
    cando=false
  end

  return cando, assets
end


--- Checks if a mission type is contained in a table of possible types.
-- @param #SQUADRON self
-- @param #string MissionType The requested mission type.
-- @param #table PossibleTypes A table with possible mission types.
-- @return #boolean If true, the requested mission type is part of the possible mission types.
function SQUADRON:CheckMissionType(MissionType, PossibleTypes)

  if type(PossibleTypes)=="string" then
    PossibleTypes={PossibleTypes}
  end

  for _,canmission in pairs(PossibleTypes) do
    if canmission==MissionType then
      return true
    end   
  end

  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

