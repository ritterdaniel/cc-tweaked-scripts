SlotRange = {
  first = nil,
  last = nil
}

function SlotRange:new(params, maxSlots)
  local o = {
    first = 1
  }
  if params and params.first then
    o.first = params.first
  end
  if params and params.last then
    o.last = params.last
  else
    o.last = maxSlots
  end
  setmetatable(o, self)
  self.__index = self
  return o
end

Inventory = {
  device = nil,
  name = "",
  inSlots = nil,
  outSlots = nil
}

function Inventory:new(deviceName, inSlotParams, outSlotParams)
  local o = {
    device = peripheral.wrap(deviceName),
    name = deviceName
  }
  o.outSlots = SlotRange:new(outSlotParams, o.device.size())
  o.inSlots = SlotRange:new(inSlotParams, o.device.size())
  setmetatable(o, self)
  self.__index = self
  return o
end

function Inventory:nextExportableItemStack()
  for slot = self.outSlots.first, self.outSlots.last do
    local itemStack = self.device.getItemDetail(slot)
    if itemStack then
      itemStack.slot = slot
      itemStack.inventory = self
      return itemStack
    end
  end
  return nil
end

function Inventory:hasImportedItems()
  for slot = self.inSlots.first, self.inSlots.last do
    local itemStack = self.device.getItemDetail(slot)
    if itemStack then
      return true
    end
  end
  return false
end


function Inventory:importItemStack(itemStack)
  local remainder = itemStack.count
  for slot = self.inSlots.first, self.inSlots.last do
    local slotItem = self.device.getItemDetail(slot)
    if slotItem == nil or slotItem.name == itemStack.name then
      local movedItemCount = self.device.pullItems(itemStack.inventory.name, itemStack.slot, remainder, slot)
      remainder = remainder - movedItemCount
      if remainder == 0 then
        break
      end
    end
  end
  return remainder
end

RedstoneSignalSender = {
  device = nil,
  name = "",
  side = nil
}

function RedstoneSignalSender:new(deviceName, side)
  local o = {
    device = peripheral.wrap(deviceName),
    name = deviceName,
    side = side
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function RedstoneSignalSender:setOutput(on)
  self.device.setOutput(self.side, on)
end

function RedstoneSignalSender:toggleOutput()
  local state = self.device.getOutput(self.side)
  self.device.setOutput(self.side, not state)
end