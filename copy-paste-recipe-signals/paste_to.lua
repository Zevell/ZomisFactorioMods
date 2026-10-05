local oldtables = require("mytable")
local tables = require("__flib__.table")
local popup = require("popup")
local circuit_condition_types = require("circuit_condition_types")

-- Factorio 2.0 can configure ghosts through most of the entity API, so paste
-- targets may be an "entity-ghost" whose real prototype lives in
-- ghost_name/ghost_type. All dispatch below goes through these helpers so a
-- ghost is handled exactly like the entity it will become.
local function effective_name(entity)
    if entity.type == "entity-ghost" then
        return entity.ghost_name
    end
    return entity.name
end

local function effective_type(entity)
    if entity.type == "entity-ghost" then
        return entity.ghost_type
    end
    return entity.type
end

local function effective_prototype(entity)
    if entity.type == "entity-ghost" then
        return entity.ghost_prototype
    end
    return entity.prototype
end

-- A requester or buffer chest (vanilla or modded) is the only logistic
-- container that can take pasted item requests. Provider/storage chests report
-- a different logistic_mode and are rejected by paste_to_requester.
local function is_requester_chest(destination)
    if effective_type(destination) ~= "logistic-container" then
        return false
    end
    local prototype = effective_prototype(destination)
    local mode = prototype and prototype.logistic_mode
    return mode == "requester" or mode == "buffer"
end

-- Finds the manual logistic section that holds the requests. Uses the
-- requester point when available and falls back to the generic logistic
-- sections (which also works for ghosts that do not expose a requester point).
local function get_requester_section(destination)
    local ok, point = pcall(destination.get_requester_point, destination)
    if ok and point and point.valid then
        for index = 1, point.sections_count do
            local candidate = point.get_section(index)
            if candidate and candidate.valid and candidate.is_manual then
                return candidate
            end
        end
        return nil
    end

    local sections_ok, sections = pcall(destination.get_logistic_sections, destination)
    if sections_ok and sections and sections.valid and sections.sections_count > 0 then
        for index = 1, sections.sections_count do
            local candidate = sections.get_section(index)
            if candidate and candidate.valid and candidate.is_manual then
                return candidate
            end
        end
    end
    return nil
end

local function iterate(options, player_info)
    local options_count = table_size(options)
    local current_index = player_info.last_copy.index

    if current_index == nil then
        current_index = 1
--   Include empty after iterating through all once or not?
--      elseif current_index == options_count then
--        destination.set_filter(1, nil)
--        return
    else
        current_index = (current_index % options_count) + 1
    end
    return current_index, options[current_index]
end

local function paste_to_circuit_condition(destination, signals, player_info)
    local player_settings = player_info.settings
    if not player_settings["copy-paste-circuit-condition"].value then
        return nil
    end
    local behavior = destination.get_or_create_control_behavior()
    local previous_condition = behavior.circuit_condition or {}
    local index, next_value = iterate(signals, player_info)

    behavior.circuit_condition = {
        first_signal = next_value.signal, -- SignalID
        second_signal = previous_condition.second_signal,
        constant = previous_condition.constant,
        comparator = previous_condition.comparator
    }
    -- Only some control behaviors support enabling via circuit condition, and the
    -- flag name differs (LuaGenericOnOffControlBehavior vs
    -- LuaLogisticContainerControlBehavior). Reading/writing an attribute that a
    -- behavior does not have throws, so guard each write.
    pcall(function() behavior.circuit_enable_disable = true end)
    if behavior.object_name == "LuaLogisticContainerControlBehavior" then
        pcall(function() behavior.circuit_condition_enabled = true end)
    end

    popup.popup_circuit_condition(player_info, behavior.circuit_condition)
    return index
end

local function paste_to_inserter(destination, signals, player_info)
    local options = tables.filter(signals, function(v) return v.signal.type == "item" end, true) -- array[Signal]
    local options_count = table_size(options)
    if options_count == 0 then
        return nil, "paste-no-item-signals"
    end

    -- Not sure what feature is desired for regular filter inserters?
    if effective_name(destination) == "stack-filter-inserter" then
        local index, next_value = iterate(options, player_info)
        destination.set_filter(1, next_value and next_value.signal.name)
        return index
    end
end

local function paste_to_splitter(destination, signals, player_info)
    local options = tables.filter(signals, function(v) return v.signal.type == "item" end, true) -- array[Signal]
    local options_count = table_size(options)
    if options_count == 0 then
        return nil, "paste-no-item-signals"
    end
    local index, next_value = iterate(options, player_info)
    if destination.splitter_output_priority == "none" then
        destination.splitter_output_priority = "left"
    end
    destination.splitter_filter = {
        name = next_value.signal.name,
        quality = next_value.signal.quality,
        comparator = "="
    }

    return index
end

local function paste_to_computing_combinator(destination, signals, player_info)
    local player_settings = player_info.settings
    local allow_arithmetic = player_settings["copy-paste-recipe-time-paste-product-arithmetic"].value
    local allow_decider = player_settings["copy-paste-recipe-time-paste-product-decider"].value

    local destination_name = effective_name(destination)

    if destination_name == "arithmetic-combinator" and allow_arithmetic then
        local behavior = destination.get_or_create_control_behavior()
        local previous = behavior.parameters
        local previous_out = previous.output_signal
        local previous_in = previous.first_signal

        local index, next_value = iterate(signals, player_info)
        local output_was_each = previous_out and previous_out.type == "virtual" and previous_out.name == "signal-each"
        if output_was_each or tables.deep_compare(previous_in, previous_out) then
            previous.output_signal = next_value.signal
        end
        if previous.second_signal and tables.deep_compare(previous_in, previous.second_signal) then
            previous.second_signal = next_value.signal
        end
        behavior.parameters = {
          first_signal = next_value.signal,
          second_signal = previous.second_signal,
          operation = previous.operation,
          second_constant = previous.second_constant,
          output_signal = previous.output_signal
        }
        return index
    elseif destination_name == "decider-combinator" and allow_decider then
        local behavior = destination.get_or_create_control_behavior()
        local index, next_value = iterate(signals, player_info)

        -- Factorio 2.0: decider combinators use per-index conditions/outputs
        -- (get_condition/set_condition/get_output/set_output). The old flat
        -- parameters table no longer exists.
        local condition = behavior.get_condition(1)
        local output = behavior.get_output(1)
        local previous_first = condition and condition.first_signal or nil
        local previous_out = output and output.signal or nil
        local output_was_each = previous_out and previous_out.type == "virtual" and previous_out.name == "signal-each"

        if condition then
            condition.first_signal = next_value.signal
            behavior.set_condition(1, condition)
        end
        if output and (output_was_each or (previous_out and tables.deep_compare(previous_first, previous_out))) then
            output.signal = next_value.signal
            behavior.set_output(1, output)
        end
        return index
    end
end

local function signal_to_filter(signal, count_override)
    return {
        value = {
            type = signal.signal.type,
            name = signal.signal.name,
            quality = signal.signal.quality,
        },
        min = count_override or signal.count,
    }
end

local function paste_to_logisitic_section(section, signals)
    -- change filters of section
    -- type, name, quality, comparator

    -- Need to clear everything first to avoid any potential conflicts
    local count = section.filters_count
    for index = 1, count do
        section.clear_slot(index)
    end

    local signalsStartIndex = 0
    for index, signal in pairs(signals) do
        section.set_slot(index + signalsStartIndex, signal_to_filter(signal))
    end

    return nil
end

local function paste_to_constant_combinator(destination, signals, player_info)
    local behavior = destination.get_or_create_control_behavior()

    local destination_name = effective_name(destination)
    if destination_name == "constant-combinator" or destination_name == "ltn-combinator" then
      -- The ltn-combinator has 28 signals, however the 14 first signals should
      -- be used for LTN specific signals, we try to preserve these so LTN configurations is not lost
      local signalsStartIndex = destination_name == "ltn-combinator" and (14) or 0

      -- loop through sections, check for section.is_manual and active
      for i, section in pairs(behavior.sections) do
        if section.is_manual and section.active then
          paste_to_logisitic_section(section, signals)
        end
      end
    end
end

-- Request amounts: ten stacks of the item (1000 iron plates, 2000 copper cable),
-- which is as much as one request slot is meant to hold. The engine stores any
-- amount it is given, so this ceiling is the mod's rule rather than the game's;
-- it is clamped so that an outsized stack size in a mod set cannot overflow the
-- int32 field a logistic slot uses.
local STACKS_PER_REQUEST = 10
local MAX_REQUEST_AMOUNT = 1000000000
local function count_for_signal(signal)
    local item = prototypes.item[signal.signal.name]
    local stack = item and item.stack_size or 1
    return math.max(1, math.floor(math.min(stack * STACKS_PER_REQUEST, MAX_REQUEST_AMOUNT)))
end

local function paste_to_requester(destination, signals, player_info)
    -- A requester chest (Factorio 2.0+, e.g. "requester-chest" or Bots Bots
    -- Bots' "simple-logistic-chest-requester") stores its requests in the
    -- manual section of its requester logistic point. Buffer chests have
    -- request slots too, so they are accepted as well; provider/storage chests
    -- have no requester point and are rejected below.
    local section = get_requester_section(destination)
    if not section then
        return nil, "paste-unsupported"
    end

    -- Clear all existing filters so the chest ends up with exactly the
    -- signals we are pasting. NOTE: on a fresh chest the manual section reports
    -- filters_count == 0 (slots materialize on demand via set_slot), so we
    -- clear only if the section reports capacity and simply attempt writes.
    if section.filters_count > 0 then
        for index = 1, section.filters_count do
            section.clear_slot(index)
        end
    end

    local max_slots = section.filters_count
    local slot = 0
    for _, signal in ipairs(signals) do
        local sig = signal.signal
        -- Only ITEM signals that reference an existing item can be requested
        if sig and sig.type == "item" and prototypes.item[sig.name] then
            if max_slots > 0 and slot >= max_slots then
                break
            end
            slot = slot + 1
            section.set_slot(slot, signal_to_filter(signal, count_for_signal(signal)))
        end
    end

    if slot == 0 then
        return nil, "paste-no-item-signals"
    end
    return nil
end

-- Returns the index of the signal that was used (for iterative paste targets)
-- and optionally a failure reason ("paste-no-item-signals" or "paste-unsupported")
-- used by the caller to show the player a helpful popup.
local paste_to_impl = function(destination, signals, player_info)
    local name = effective_name(destination)
    local destination_type = effective_type(destination)

    if name == "constant-combinator" or name == "ltn-combinator" then
        return paste_to_constant_combinator(destination, signals, player_info)
    end
    if name == "arithmetic-combinator" or name == "decider-combinator" then
        return paste_to_computing_combinator(destination, signals, player_info)
    end
    if name == "stack-filter-inserter" then
        return paste_to_inserter(destination, signals, player_info)
    end
    if destination_type == "splitter" then
        return paste_to_splitter(destination, signals, player_info)
    end
    if destination_type == "logistic-container" then
        -- paste_to_requester returns "paste-unsupported" for provider/storage
        -- chests (no requester section); requester and buffer chests are pasted.
        return paste_to_requester(destination, signals, player_info)
    end
    if circuit_condition_types[destination_type] then
        return paste_to_circuit_condition(destination, signals, player_info)
    end
    return nil, "paste-unsupported"
end

-- The module is callable (paste_to(entity, signals, player_info)) and also
-- exposes a few helpers used by the paste picker GUI.
local paste_to = {}
setmetatable(paste_to, {
    __call = function(_, destination, signals, player_info)
        return paste_to_impl(destination, signals, player_info)
    end,
})
paste_to.is_requester_chest = is_requester_chest
paste_to.get_requester_section = get_requester_section
paste_to.count_for_signal = count_for_signal
paste_to.signal_to_filter = signal_to_filter
paste_to.effective_name = effective_name
paste_to.effective_type = effective_type

return paste_to
