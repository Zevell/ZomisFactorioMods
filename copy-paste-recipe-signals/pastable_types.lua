local function mod_exists(mod_name)
    if mods and mods[mod_name] then
        return true
    end
    if game and game.active_mods[mod_name] then
        return true
    end
    return false
end

function pastable_entity_names_table()
    local pastable_types = {
        "constant-combinator",
        "arithmetic-combinator",
        "decider-combinator",
        "pump",
        "inserter"
    }
    if data then
        for k in pairs(data.raw["inserter"]) do
            table.insert(pastable_types, k)
        end
        for k in pairs(data.raw["transport-belt"]) do
            table.insert(pastable_types, k)
        end
        for k in pairs(data.raw["splitter"]) do
            table.insert(pastable_types, k)
        end
        -- Every logistic container that has a requester point is a valid
        -- paste target: the vanilla "requester-chest" plus modded ones
        -- (e.g. Bots Bots Bots' "simple-logistic-chest-requester").
        for name, prototype in pairs(data.raw["logistic-container"]) do
            if prototype.logistic_mode == "requester" then
                table.insert(pastable_types, name)
            end
        end
    else
        table.insert(pastable_types, "requester-chest")
    end

    if mod_exists("LTN_Combinator_Modernized") then
        table.insert(pastable_types, "ltn-combinator")
    end
    return pastable_types
end

-- Make an entity prototype a valid paste target for every entity this mod can
-- copy from. Idempotent: never adds a name twice.
local function make_pastable(entity_type)
    local existing = {}
    if entity_type.additional_pastable_entities then
        for _, name in pairs(entity_type.additional_pastable_entities) do
            existing[name] = true
        end
    end
    for _, other in pairs(pastable_entity_names_table()) do
        if other ~= entity_type.name and not existing[other] then
            if not entity_type.additional_pastable_entities then
                entity_type.additional_pastable_entities = {}
            end
            table.insert(entity_type.additional_pastable_entities, other)
        end
    end
end

return {
    entity_names = pastable_entity_names_table(),
    make_pastable = make_pastable
}
