local devices = {
  -- Cooking Pot
  crafter = peripheral.wrap("farmersdelight:cooking_pot_3"),

  -- Chest which receives all items for crafting recipe
  inChest = peripheral.wrap("ironchest:iron_chest_3"),

  -- Chest where container items should be put in
  containerChest = peripheral.wrap("ironchest:iron_chest_4"),

  -- RS crafter, to receive redstone pulse for next item set (redrouter instance)
  rsCrafter = {
    device = peripheral.wrap("redrouter_1"),
    side = "top"
  },

  -- Outgoing pipe, to receive redstone signal to pull crafted item from crafter (redrouter instance)
  pipe = {
    device = peripheral.wrap("redrouter_0"),
    side = "left"
  }
}

local config = {
  tick = 1, -- seconds
  debug = false,
  crafterInItemMaxSlot = 6,
  crafterOutItemSlot = 9,
  containerItems = {
    Bowl = true
  }
}

local state = {
  startup = "STARTUP",
  idle = "IDLE",
  crafting = "CRAFTING"
}

local params = {...}
config["debug"] = #params >= 1 and params[1] == "-d"

local function nextItem(inventory)
  for slot, items in pairs(inventory.list()) do
    return slot, items.name
  end
  return nil, nil
end

local function debug(...)
  if config.debug then
    print(...)
  end
end

local function pushItem(fromChest, toChest, item, maxSlot)
  local toChestName = peripheral.getName(toChest)
  if maxSlot == nil then
    maxSlot = toChest.size()
  end
  local slot = nil
  for cslot = 1, maxSlot, 1 do
    if toChest.getItemDetail(cslot) == nil then -- empty slot
      slot = cslot
      break
    end
  end

  if slot == nil then
    return {nil, nil}
  else
    local movedItems = fromChest.pushItems(toChestName, item.slot, 1, slot)
    return {slot, movedItems}
  end
end

local function setRedstoneOutput(redstoneDevice, on)
  redstoneDevice.device.setOutput(redstoneDevice.side, on)
end

local function toggleRedstoneOutput(redstoneDevice)
  local state = redstoneDevice.device.getOutput(redstoneDevice.side)
  redstoneDevice.device.setOutput(redstoneDevice.side, not state)
end

local function crafter()
  local item = {}
  local subscribedEvents = {
    inItemAvailable = true,
    outItemAvailable = true,
    outChestEmpty = true,
    inChestEmpty = true
  }
  local currentState = state.startup

  repeat
    local event, param = coroutine.yield()
    if subscribedEvents[event] then
      debug("Crafter - Event - " .. event)
      if event == "inItemAvailable" and currentState ~= state.startup then
        if currentState == state.idle then
          setRedstoneOutput(devices.pipe, false)
          -- setRedstoneOutput(devices.rsCrafter, false)
          currentState = state.crafting
        end
        item = param
        debug("Crafter - IA:", item.name, " STATE:", currentState)
        if config.containerItems[item.name] then
          pushItem(devices.inChest, devices.containerChest, item)
        else
          pushItem(devices.inChest, devices.crafter, item, config.crafterInItemMaxSlot)
        end
      elseif event == "outItemAvailable" then
        item = param
        setRedstoneOutput(devices.pipe, true)
        currentState = state.idle
      elseif event == "outChestEmpty" and currentState == state.startup then
        currentState = state.idle
      elseif event == "inChestEmpty" and currentState == state.idle then
        toggleRedstoneOutput(devices.rsCrafter)
      end
    end
  until event == "terminate"
end

local function inChestMonitor()
  repeat
    debug("inChestMonitor - Timer Event")
    local slot, itemName = nextItem(devices.inChest)
    if slot then
      local item = devices.inChest.getItemDetail(slot)
      if item then
        debug("inChestMonitor - Item:".. item.displayName)
        os.queueEvent("inItemAvailable", {slot = slot, name = item.displayName})
      else
        os.queueEvent("inChestEmpty")
      end
    end
    local event = coroutine.yield("timer")
  until event[1] == "terminate"
end

local function outChestMonitor()
  local slot = config.crafterOutItemSlot
  repeat
    debug("outChestMonitor - Timer Event")
    local item = devices.crafter.getItemDetail(slot)
    if item then
      debug("inChestMonitor - Item:".. item.displayName)
      os.queueEvent("outItemAvailable", {slot = slot, name = item.displayName})
    else
      os.queueEvent("outChestEmpty")
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
  outChestMonitor,
  pulseGenerator,
  crafter
)