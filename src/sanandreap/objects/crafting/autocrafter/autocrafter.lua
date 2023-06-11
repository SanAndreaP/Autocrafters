-- https://github.com/Kherae/Automation-Aides/blob/master/objects/kheAA/kheAA_containerLink/kheAA_containerLink.lua
require "/scripts/kheAA/transferUtil.lua"


function init()
    self.stationPos = nil
	self.group = nil
	self.prevGroup = nil

	storage.filterItem = storage.filterItem or nil
	storage.currentRecipes = nil

	message.setHandler("GetFilter", function(_, _)
		return storage.filterItem
	end)
	message.setHandler("SetFilter", function(_, _, item)
		storage.filterItem = {name=item.name, count=1}
		cancelCraft()
		storage.currentRecipes = nil
	end)
	message.setHandler("EmptyFilter", function(_, _)
		storage.filterItem = nil
	end)
	message.setHandler("GetMessage", function(_, _)
		if not hasGroup() then
			return "^red;NO ADJ. STATION"
		elseif not isEnabled() then
			return "^yellow;PAUSED"
		elseif not hasRecipe() then
			return "^red;UNKNOWN RECIPE"
		elseif storage.currentRecipes and storage.currentRecipes.current then
			return "^green;CRAFTING..."
		else
			return ""
		end
	end)

	transferUtil.loadSelfContainer()
end

function update(dt)
	if dt < 0 then
		return
	end

	findStation()

	object.setOutputNodeLevel(transferUtil.vars.outDataNode, self.group ~= nil)

	local diffGroup = not hasGroup() or not hasGroup(self.prevGroup)
	if diffGroup or not storage.filterItem then
		cancelCraft()
		storage.currentRecipes = not diffGroup and storage.currentRecipes or nil
		self.prevGroup = self.group
	elseif hasGroup() and isEnabled() then
		doCraft(dt)
	end
end

function hasRecipe()
	return storage.currentRecipes and storage.currentRecipes.all and next(storage.currentRecipes.all)
end

function isEnabled()
	return not object.isInputNodeConnected(0) or object.getInputNodeLevel(0)
end

function findStation()
	transferUtil.zoneAwake(transferUtil.pos2Rect(storage.position, 1))
	self.stationPos=nil
	self.group=nil

	local srcPos = {storage.position[1], storage.position[2]}
	srcPos[1] = srcPos[1] + util.clamp(object.direction(), 0, 1) * 2
	local objectIds = world.objectQuery(srcPos, -1, { order = "nearest" })
	for _, objectId in pairs(objectIds) do
		self.group = world.getObjectParameter(objectId, "recipeGroup")
		if self.group ~= nil then
			self.stationPos = world.entityPosition(objectId)
			break
		elseif world.getObjectParameter(objectId, "interactAction") == "OpenCraftingInterface" then
			self.group = world.getObjectParameter(objectId, "interactData", {filter=nil}).filter
			if self.group ~= nil then
				self.stationPos = world.entityPosition(objectId)
				break
			end
		elseif world.getObjectParameter(objectId, "upgradeStages") then
			stage = world.callScriptedEntity(objectId, "currentStageData")
			if stage and stage.interactData and stage.interactData.filter then
				self.stationPos = world.entityPosition(objectId)
				self.group = stage.interactData.filter
				break
			end
		end
	end
end

function hasGroup(group)
	if group then
		if type(self.group) ~= "table" then
			return (type(group) == "table") and hasValue(group, self.group) or (self.group == group)
		else
			return hasValue(self.group, group)
		end
	else
		return self.group ~= nil
	end

	return false
end

function hasValue(tab, val)
	local valIsTable = type(val) == "table"
    for _, v in pairs(tab) do
		if valIsTable and hasValue(val, v) then
			return true
		elseif v == val then
            return true
        end
    end

    return false
end

function doCraft(dt)
	if storage.currentRecipes and (storage.currentRecipes.current or next(storage.currentRecipes.all)) then
		if storage.currentRecipes.current then
			local recipe = storage.currentRecipes.current

			for i=1, calcCraftingAmount(recipe, dt), 1 do
				if grabIngredients(recipe.input, recipe.matchInputParameters, true) then
					local eid = entity.id()
					local currOut = world.containerItemAt(eid, 12)

					if not currOut or itemFits(recipe.output, currOut) then
						grabIngredients(recipe.input, recipe.matchInputParameters, false)
						local rest = world.containerPutItemsAt(eid, recipe.output, 12)
					else
						cancelCraft()
						break
					end
				else
					cancelCraft()
					break
				end
			end
		else
			for _, recipe in pairs(storage.currentRecipes.all) do
				if grabIngredients(recipe.input, recipe.matchInputParameters, true) then
					storage.currentRecipes.current = recipe
					break
				end
			end
		end
	else
		local recipes = root.recipesForItem(storage.filterItem.name)
		if recipes then
			storage.currentRecipes = {current=nil, consumed={}, all={}}
			for _, recipe in pairs(recipes) do
				if hasGroup(recipe.groups) then
					table.insert(storage.currentRecipes.all, recipe)
				end
			end
		end
	end
end

function calcCraftingAmount(recipe, dt)
	local amt = 1
	
	if recipe.duration and (dt > recipe.duration) then
		local durRel = dt / recipe.duration
		amt = math.floor(durRel)
		recipe._durationRest = (recipe._durationRest or 0) + durRel - amt
		if recipe._durationRest >= 1 then
			recipe._durationRest = recipe._durationRest - 1
			amt = amt + 1
		end
	elseif recipe.duration and (dt < recipe.duration) then
		recipe._durationRest = (recipe._durationRest or 0) + dt
		if recipe._durationRest >= recipe.duration then
			local durRel = recipe._durationRest / recipe.duration
			amt = math.floor(durRel)
			recipe._durationRest = recipe._durationRest - recipe.duration
		else
			amt = 0
		end
	end

	return amt
end

function grabIngredients(inputs, matchParam, simulate)
	local eid = entity.id()
	local consumed = {}
	local containerItems = world.containerItems(eid)

	for _, input in pairs(inputs) do
		local found = false

		for slot, item in pairs(containerItems) do
			if itemIs(item, input, matchParam) and item.count >= input.count then
				if simulate then
					table.insert(consumed, input)
				else
					table.insert(consumed, world.containerTakeNumItemsAt(eid, slot - 1, input.count))
				end

				found = true
				break
			end
		end

		if not found then return nil end
	end

	return consumed
end

function itemIs(item1, item2, matchParam)
	return item1 and item2 and item1.name == item2.name and (not matchParam or item1.parameters == item2.parameters)
end

function itemFits(item, toItem, matchParam)
	if not toItem then
		return item ~= nil
	else
		return itemIs(toItem, item, matchParam) and maxStack(toItem) - toItem.count >= item.count
	end
end

function maxStack(item)
	local cfg = root.itemConfig(item).config
	
	if cfg and cfg.maxStack then
		return cfg.maxStack
	else
		return root.assetJson("/items/defaultParameters.config").defaultMaxStack
	end
end

function cancelCraft()
	if storage.currentRecipes then
		storage.currentRecipes.current = nil
	end
end