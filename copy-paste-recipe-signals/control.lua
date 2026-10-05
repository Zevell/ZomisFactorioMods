local copy_from = require "copy_from"
local paste_to = require "paste_to"
local paste_picker = require "paste_picker"
local popup = require "popup"

-- A ghost ("entity-ghost") resolves to the prototype of the entity it will
-- become, so a not-yet-built combinator/chest is treated like the real thing.
local function effective_type(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_type
  end
  return entity.type
end

local function get_player_info(event)
  local player_index = event.player_index

  storage.player_info = storage.player_info or {}
  if not storage.player_info[player_index] then
    storage.player_info[player_index] = {
      last_copy = {
        from = nil,
        to = nil,
        index = nil
      }
    }
  end
  local player_info = storage.player_info[player_index]
  if event.source ~= player_info.last_copy.from or event.destination ~= player_info.last_copy.to then
    storage.player_info[player_index] = {
      last_copy = {
        from = nil,
        to = nil,
        index = nil
      }
    }
  end

  return {
    player = game.players[player_index],
    last_copy = storage.player_info[player_index].last_copy or {},
    settings = settings.get_player_settings(player_index)
  }
end

script.on_event(defines.events.on_entity_settings_pasted, function(event)
--  game.print("DO MAGIC!")
  if not event.destination.valid then
    return
  end
  if not event.source.valid then
    return
  end
--  game.print(event.source.name .. "/" .. event.source.type .. " --> " .. event.destination.name .. "/" .. event.destination.type)
  if effective_type(event.destination) == effective_type(event.source) then
    return
  end
  -- A new copy/paste supersedes any picker that is still open.
  paste_picker.dismiss(event.player_index)
  local player_info = get_player_info(event)
  local ok, source_values = pcall(copy_from, event.source, player_info)
  if not ok then
    log("copy-paste-recipe-signals: copy_from error: " .. tostring(source_values))
    return
  end
  -- source_values should be array[Signal]
  -- game.print(serpent.line(source_values))
  if not source_values or table_size(source_values) == 0 then
    -- Nothing to copy
    local source = event.source
    local gps = "(" .. source.position.x .. ", " .. source.position.y .. ", " .. source.surface.name .. ")"
    popup.popup_nothing_to_copy(player_info, source, gps)
    return
  end
  -- With several item signals going into a requester chest, let the player pick
  -- between pasting all of them or a single item.
  if paste_picker.should_prompt(event.destination, source_values, player_info) then
    if paste_picker.open(player_info, event.source, event.destination, source_values) then
      return
    end
  end
  local ok2, update_result, paste_failure = pcall(paste_to, event.destination, source_values, player_info)
  if not ok2 then
    -- Never let an unexpected paste error crash the game; log it and inform the player.
    log("copy-paste-recipe-signals: paste_to error: " .. tostring(update_result))
    pcall(function()
      player_info.player.create_local_flying_text {
        text = "copy-paste-recipe-signals: paste error (see log)",
        create_at_cursor = true
      }
    end)
    return
  end
  if paste_failure then
    popup.popup_paste_failed(player_info, event.destination, paste_failure)
  end
  storage.player_info[event.player_index] = {
    last_copy = {
      from = event.source,
      to = event.destination,
      index = update_result
    }
  }
end)

script.on_event(defines.events.on_gui_click, function(event)
  paste_picker.handle_click(event)
end)

script.on_event(defines.events.on_player_left_game, function(event)
  paste_picker.clear(event.player_index)
end)
