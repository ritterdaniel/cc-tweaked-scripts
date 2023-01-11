require "peripherals"

  -- Energizing Orb
local crafter = Inventory:new("powah:energizing_orb_0", {first = 2}, {first = 1, last = 1})

--   -- Chest which receives all items for crafting recipe
-- local inChest = Inventory:new("ironchest:iron_chest_3")

  -- Chest which receives crafted items
local outChest = Inventory:new("ironchest:iron_chest_5")

  -- RS crafter, to receive redstone pulse for next item set (redrouter instance)
local rsCrafter = RedstoneSignalSender:new("redstoneIntegrator_0", "back")


local config = {
  tick = 1, -- seconds
  debug = false
  -- crafterOutItemSlot = 1
}

local state = {
  startup = "STARTUP",
  idle = "IDLE",
  crafting = "CRAFTING"
}

local params = {...}
config["debug"] = #params >= 1 and params[1] == "-d"


local function debug(...)
  if config.debug then
    print(...)
  end
end

local function craftingHandler()
  local subscribedEvents = {
    inItemAvailable = true,
    inItemNotAvailable = true,
    craftedItemAvailable = true,
    craftedItemNotAvailable = true
  }
  local currentState = state.startup

  repeat
    local event, param = coroutine.yield()
    if subscribedEvents[event] then
      debug("Crafter - Event - " .. event)
      if event == "inItemAvailable" and currentState ~= state.startup then
        if currentState == state.idle then
          currentState = state.crafting
        end
        debug("Crafter - STATE:", currentState)
        -- os.queueEvent("inChestCheckNextItem")
      elseif event == "craftedItemAvailable" then
        local itemStack = param
        local result = outChest:importItemStack(itemStack)
        if result == 0 then
          currentState = state.idle
        end
        debug("Crafter - IA:", itemStack.name, " STATE:", currentState, " COUNT: ", result)
      elseif event == "craftedItemNotAvailable" and currentState == state.startup then
        currentState = state.idle
        debug("Crafter - STATE:", currentState)
      elseif event == "inItemNotAvailable" and currentState == state.idle then
        debug("Crafter - PULSE")
        rsCrafter:toggleOutput()
      end
    end
  until event == "terminate"
end

local function inChestMonitor()
  local subscribedEvents = {
    timer = true,
    inChestCheckNextItem = true
  }
  repeat
    local event, _ = coroutine.yield()
    if subscribedEvents[event] then
      debug("inChestMonitor - Event - ".. event)
      if crafter:hasImportedItems() then
        os.queueEvent("inItemAvailable")
      else
        os.queueEvent("inItemNotAvailable")
      end
    end
  until event == "terminate"
end

local function craftedItemMonitor()
  repeat
    debug("craftedItemMonitor - Timer Event")
    local itemStack = crafter:nextExportableItemStack()
    if itemStack then
      debug("craftedItemMonitor - Item:".. itemStack.displayName)
      os.queueEvent("craftedItemAvailable", itemStack)
    else
      os.queueEvent("craftedItemNotAvailable")
    end
    local event = coroutine.yield("timer")
  until event[1] == "terminate"
end

local function pulseGenerator()
  repeat
      os.startTimer(config.tick)
      local event = coroutine.yield("timer")
  until event == "terminate"
end

parallel.waitForAny(
  inChestMonitor,
  craftedItemMonitor,
  pulseGenerator,
  craftingHandler
)