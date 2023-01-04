local devices = {
  crafter = peripheral.wrap("right"), -- Cooking Pot
  inChest = peripheral.wrap("up"),
  outChest = peripheral.wrap("down")
}

local config = {
  tick = 1, -- seconds
  debug = false,
  crafterInItemSlots = {1, 2, 3, 4, 5, 6},
  crafterContainerSlot = 7,
  crafterOutItemSlot = 8,
  containerItems = {
    Bowl = true
  },
  redstonePulseSide = "back"
}

local state = {
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

local function pushItem(fromChest, toChest, item, slot)
  local toChestName = peripheral.getName(toChest)
  if slot == nil then
    for _, cslot in ipairs(config.crafterInItemSlots) do
      if not toChest.getItemDetail(slot) then -- empty slot
        slot = cslot
      end
    end
  end

  if slot == nil then
    return nil
  else
    fromChest.pushItems(toChestName, item.slot, 1, slot)
    return slot
  end
end

local function crafter()
  -- local crafterName = peripheral.getName(devices.crafter)
  local inChest = devices.inChest

  local inItemAvailable = false
  local item = {}
  local subscribedEvents = {
    inItemAvailable = true,
    outItemAvailable = true,
    inChestEmpty = true
  }
  local currentState = state.idle

  repeat
    local event, param = coroutine.yield()
    if subscribedEvents[event] then
      debug("Crafter - Event - " .. event)
      if event == "inItemAvailable" then
        item = param
        inItemAvailable = true
        redstone.setOutput(config.redstonePulseSide, false)
        currentState = state.crafting
        debug("Crafter - IA:", inItemAvailable, " STATE:", currentState)
        if config.containerItems[item.name] then
          pushItem(devices.inChest, devices.crafter, item, config.crafterContainerSlot)
        else
          pushItem(devices.inChest, devices.crafter, item)
        end
      elseif event == "outItemAvailable" then
        item = param
        pushItem(devices.crafter, devices.outChest, item)
        currentState = state.idle
      end

      if currentState == state.idle then
        redstone.setOutput(config.redstonePulseSide, not redstone.getOutput(config.redstonePulseSide))
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