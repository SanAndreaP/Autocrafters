filterRequest = nil
msgRequest = nil
msgCooldown = -1

function init()
    world.sendEntityMessage(pane.containerEntityId(), "SetPlayer", player.id());
end

function update(dt)
    filterRequest = request(filterRequest, function(res)
        widget.setItemSlotItem("filterSlot", res)
    end, "GetFilter")

    msgRequest = request(msgRequest, function(res)
        msg(res)
    end, "GetMessage")

    if msgCooldown > 0 then
        msgCooldown = msgCooldown - 1
    elseif msgCooldown == 0 then
        widget.setText("lblMessage", "")
        msgCooldown = -1
    end
end

function onFilterClick(_)
    --Get (a copy of) the item descriptor the player was holding
    setFilter(player.swapSlotItem())
end

-- do the same as on left click
function onOutputRightClick(_)
    setFilter()
end

function onMoneyClick(_)
    setFilter({name="money", count=10})
end

function request(req, onSuccess, msg)
    if req and req:finished() then
        onSuccess(req:result())
        return nil
    elseif not req then
        return world.sendEntityMessage(pane.containerEntityId(), msg)
    else
        return req
    end
end

function setFilter(item)
    local eid = pane.containerEntityId()

    if item then
        msgRequest = world.sendEntityMessage(eid, "SetFilter", item)
    else
        world.sendEntityMessage(eid, "EmptyFilter")
    end
end

function msg(msg)
    if msg and string.len(msg) > 0 then
        widget.setText("lblMessage", msg)
        msgCooldown = 15
    end
end