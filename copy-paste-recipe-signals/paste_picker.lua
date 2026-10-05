-- Paste-selection GUI.
--
-- When the copied signals contain two or more item signals and the paste target
-- is a requester/buffer chest, the player is asked what to paste: ALL item
-- signals at once, or just one specific item.
--
-- The engine's on_entity_settings_pasted event cannot be blocked, so the paste
-- is deferred: the pending paste is stored and applied when the player clicks
-- a button.

local paste_to = require("paste_to")
local popup = require("popup")

local FRAME_NAME = "copy-paste-recipe-signals-paste-picker"
local ALL_SPRITE = "virtual-signal/signal-everything"

local function get_player(player_index)
    local player = game.get_player(player_index)
    if player and player.valid then
        return player
    end
    return nil
end

-- The item signals that can actually be requested by a chest.
local function item_signals(signals)
    local result = {}
    for _, signal in ipairs(signals) do
        local id = signal.signal
        if id and id.type == "item" and prototypes.item[id.name] then
            table.insert(result, signal)
        end
    end
    return result
end

local function pending_store()
    storage.paste_picker = storage.paste_picker or {}
    return storage.paste_picker
end

local function destroy_gui(player)
    if not player then
        return
    end
    local existing = player.gui.center[FRAME_NAME]
    if existing and existing.valid then
        existing.destroy()
    end
end

-- Forgets the pending paste and closes the picker.
local function clear(player_index)
    local store = pending_store()
    store[player_index] = nil
    destroy_gui(get_player(player_index))
end

-- Should the picker be shown for this paste?
local function should_prompt(destination, signals, player_info)
    local player_settings = player_info and player_info.settings
    if player_settings and player_settings["copy-paste-recipe-signals-paste-picker"] then
        if not player_settings["copy-paste-recipe-signals-paste-picker"].value then
            return false
        end
    end
    if not paste_to.is_requester_chest(destination) then
      return false
    end
    -- Only ask when the requests can actually be written. A ghost requester
    -- chest, for example, exposes no usable requester point in 2.0, so asking
    -- would only lead to a failed paste afterwards.
    if not paste_to.get_requester_section(destination) then
        return false
    end
    return #item_signals(signals) >= 2
end

local function add_signal_button(flow, tags, sprite, fallback_caption, tooltip)
    if sprite and helpers.is_valid_sprite_path(sprite) then
        flow.add {
            type = "sprite-button",
            sprite = sprite,
            tooltip = tooltip,
            tags = tags,
            style = "slot_button",
        }
    else
        flow.add {
            type = "button",
            caption = fallback_caption,
            tooltip = tooltip,
            tags = tags,
        }
    end
end

local function add_item_button(flow, signal, index)
    local id = signal.signal
    local count = paste_to.count_for_signal(signal)
    local tooltip = { "copy-paste-recipe-signals-gui.paste-item-tooltip", { "item-name." .. id.name }, count }
    local sprite = "item/" .. id.name
    if helpers.is_valid_sprite_path(sprite) then
        flow.add {
            type = "sprite-button",
            sprite = sprite,
            number = count,
            quality = (id.quality and id.quality ~= "normal") and id.quality or nil,
            tooltip = tooltip,
            tags = { cprs = "one", index = index },
            style = "slot_button",
        }
    else
        flow.add {
            type = "button",
            caption = { "item-name." .. id.name },
            tooltip = tooltip,
            tags = { cprs = "one", index = index },
        }
    end
end

local function build_gui(player, signals)
    local list = item_signals(signals)

    local frame = player.gui.center.add {
        type = "frame",
        name = FRAME_NAME,
        direction = "vertical",
    }
    frame.add {
        type = "label",
        caption = { "copy-paste-recipe-signals-gui.paste-picker-title" },
    }
    local flow = frame.add {
        type = "flow",
        direction = "horizontal",
    }

    add_signal_button(
        flow,
        { cprs = "all" },
        ALL_SPRITE,
        { "copy-paste-recipe-signals-gui.all" },
        { "copy-paste-recipe-signals-gui.paste-all-tooltip" }
    )
    for index, signal in ipairs(list) do
        add_item_button(flow, signal, index)
    end

    frame.add {
        type = "button",
        caption = { "copy-paste-recipe-signals-gui.cancel" },
        tags = { cprs = "cancel" },
    }
end

-- Opens the picker for a paste that was intercepted before it happened.
-- Returns true when the picker was shown.
local function open(player_info, source, destination, signals)
    local player = player_info and player_info.player
    if not player or not player.valid then
        return false
    end
    local player_index = player.index
    clear(player_index)
    pending_store()[player_index] = {
        source = source,
        destination = destination,
        signals = signals,
    }
    local ok, err = pcall(build_gui, player, signals)
    if not ok then
        -- Never let a GUI problem crash the game or leave a stale pending paste.
        clear(player_index)
        log("copy-paste-recipe-signals: paste picker GUI error: " .. tostring(err))
        return false
    end
    return true
end

-- Closes an open picker and forgets the pending paste (used when a new
-- copy/paste starts, or when the player leaves the game).
local function dismiss(player_index)
    clear(player_index)
end

-- Applies the player's choice. Returns true if the click belonged to us.
local function handle_click(event)
    local element = event.element
    if not element or not element.valid then
        return false
    end
    local tags = element.tags
    if not tags or tags.cprs == nil then
        return false
    end

    local player_index = event.player_index
    local player = get_player(player_index)
    local store = pending_store()
    local pending = store[player_index]
    store[player_index] = nil
    destroy_gui(player)

    if tags.cprs == "cancel" then
        return true
    end

    if not pending or not pending.destination or not pending.destination.valid then
        if player then
            player.create_local_flying_text {
                text = { "copy-paste-recipe-signals-gui.no-destination" },
                create_at_cursor = true,
                time_to_live = 60 * 8,
            }
        end
        return true
    end

    local chosen
    if tags.cprs == "all" then
        chosen = pending.signals
    else
        local signal = item_signals(pending.signals)[tags.index]
        if not signal then
            return true
        end
        chosen = { signal }
    end

    local player_info = {
        player = player,
        last_copy = {},
        settings = settings.get_player_settings(player_index),
    }

    local ok, paste_index, failure = pcall(paste_to, pending.destination, chosen, player_info)
    if not ok then
        log("copy-paste-recipe-signals: paste picker error: " .. tostring(paste_index))
        if player then
            player.create_local_flying_text {
                text = "copy-paste-recipe-signals: paste error (see log)",
                create_at_cursor = true,
            }
        end
        return true
    end

    if failure then
        popup.popup_paste_failed(player_info, pending.destination, failure)
    end

    storage.player_info = storage.player_info or {}
    local info = storage.player_info[player_index] or {}
    info.last_copy = {
        from = pending.source,
        to = pending.destination,
        index = paste_index,
    }
    storage.player_info[player_index] = info

    return true
end

return {
    should_prompt = should_prompt,
    open = open,
    dismiss = dismiss,
    clear = clear,
    handle_click = handle_click,
    item_signals = item_signals,
}
