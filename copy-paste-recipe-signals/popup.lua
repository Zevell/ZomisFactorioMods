-- User-facing feedback for copy-paste actions. Uses create_local_flying_text
-- exclusively: no GUI frames, no timers, no per-player state to clean up.
--
-- Factorio 2.0 notes:
--  * LuaEntity has `localised_name`, NOT `local_name` (reading the latter throws).
--  * There is no `localization` global; LocalisedStrings are passed around as
--    tables and must never be concatenated with `..`.

local function signal_text(signal_id)
    if not signal_id then
        return "nil"
    end

    local signal_type = signal_id.type or "item"
    local quality = signal_id.quality or "normal"
    if signal_type == "virtual" then signal_type = "virtual-signal" end
    return "[" .. signal_type .. "=" .. signal_id.name .. ",quality=" .. quality .. "]"
end

local function popup_circuit_condition(player_info, circuit_condition)
    local cond = circuit_condition.condition or circuit_condition
    local second_signal = cond.second_signal and signal_text(cond.second_signal) or tostring(cond.constant)

    player_info.player.create_local_flying_text {
        text = {
            "copy-paste-action.copy-paste-recipe-signals-popup",
            signal_text(cond.first_signal),
            cond.comparator,
            second_signal
        },
        create_at_cursor = true
    }
end

-- Shown when the player tried to copy an entity that has no signals to copy
local function popup_nothing_to_copy(player_info, source, gps)
    player_info.player.create_local_flying_text {
        text = { "copy-paste-popup.nothing-to-copy-title" },
        create_at_cursor = true,
        time_to_live = 60 * 8,
    }
    player_info.player.create_local_flying_text {
        text = { "copy-paste-popup.nothing-to-copy-message", source.localised_name, gps },
        create_at_cursor = true,
        time_to_live = 60 * 8,
    }
end

-- Shown when nothing could be pasted to the destination entity
local function popup_paste_failed(player_info, destination, failure)
    local message_key = "copy-paste-popup.paste-unsupported"
    if failure == "paste-no-item-signals" then
        message_key = "copy-paste-popup.no-item-signals"
    end
    player_info.player.create_local_flying_text {
        text = { "copy-paste-popup.paste-failed-title" },
        create_at_cursor = true,
        time_to_live = 60 * 8,
    }
    player_info.player.create_local_flying_text {
        text = { message_key, destination.localised_name },
        create_at_cursor = true,
        time_to_live = 60 * 8,
    }
end

return {
    popup_circuit_condition = popup_circuit_condition,
    popup_nothing_to_copy = popup_nothing_to_copy,
    popup_paste_failed = popup_paste_failed,
}