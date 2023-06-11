require "/scripts/kheAA/transferUtil.lua"

function init()
    self.storagePos = nil

	transferUtil.init()
	transferUtil.vars.inContainers = {}
	transferUtil.vars.outContainers = {}
	transferUtil.vars.containerId = nil
end

function update(dt)
	if dt < 0 then
		return
	end

	findStorage()

	object.setOutputNodeLevel(transferUtil.vars.outDataNode, self.storagePos ~= nil)

	stackFood()
end

function findStorage()
	transferUtil.zoneAwake(transferUtil.pos2Rect(storage.position, 1))
	transferUtil.vars.containerId = nil
	self.storagePos = nil
	transferUtil.vars.inContainers = {}
	transferUtil.vars.outContainers = {}

	local srcPos = {storage.position[1], storage.position[2]}
	srcPos[1] = srcPos[1] + util.clamp(object.direction(), 0, 1) * 2
	local objectIds = world.objectQuery(srcPos, -0.5, { order = "nearest" })
	for _, objectId in pairs(objectIds) do
		local tSize = world.containerSize(objectId)
        if tSize and (tSize > 0) and not world.getObjectParameter(objectId, "notItemStorage", false) and world.getObjectParameter(objectId, "itemAgeMultiplier", 1.0) < 0.01 then
			transferUtil.vars.containerId = objectId
            self.storagePos = world.entityPosition(objectId)
			transferUtil.vars.inContainers[objectId] = self.storagePos
			transferUtil.vars.outContainers[objectId] = self.storagePos
			break
		end
	end
end

function stackFood()
	 if self.storagePos and isEnabled() then
		local eid = transferUtil.vars.containerId
		local containerItems = world.containerItems(eid)
		local fstFoods = {}

		for slot, item in pairs(containerItems) do
			local stats = getFoodStats(item)
			if stats then
				local firstFood = fstFoods[stats.name]
				if firstFood then
					local statDelta = math.max(stats.time, firstFood.time) - math.min(stats.time, firstFood.time)
					local firstItem = world.containerItemAt(eid, firstFood.slot)
					local firstMax = maxStack(firstItem)

					firstItem.parameters.timeToRot = math.floor(firstFood.time + statDelta / 2)
					firstItem.count = firstItem.count + item.count

					if firstItem.count > firstMax then
						local countDelta = firstItem.count - firstMax

						firstItem.count = firstMax
						world.containerSwapItemsNoCombine(eid, firstItem, firstFood.slot)

						item.count = item.count - countDelta
						world.containerSwapItemsNoCombine(eid, item, slot-1)

						fstFoods[stats.name] = {slot=slot-1, time=stats.time, count=item.count}
					else
						world.containerSwapItemsNoCombine(eid, firstItem, firstFood.slot)
						world.containerSwapItemsNoCombine(eid, nil, slot-1)

						fstFoods[stats.name] = nil
					end
				elseif item.count < maxStack(item) then
					fstFoods[stats.name] = {slot=slot-1, time=stats.time, count=item.count}
				end
			end
		end
	 end
end

function getFoodStats(item)
	if item and item.parameters and item.parameters.timeToRot then
		return {name=item.name, time=item.parameters.timeToRot}
	end

	return nil
end

function maxStack(item)
	local cfg = root.itemConfig(item).config
	
	if cfg and cfg.maxStack then
		return cfg.maxStack
	else
		return root.assetJson("/items/defaultParameters.config").defaultMaxStack
	end
end

function isEnabled()
	return not object.isInputNodeConnected(0) or object.getInputNodeLevel(0)
end