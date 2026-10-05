local pastable_types = require "pastable_types"
local pastable_entity_names_table = pastable_types.entity_names
local make_pastable = pastable_types.make_pastable

for _, entity_type in pairs(data.raw["assembling-machine"]) do
    make_pastable(entity_type)
end

for _, entity_type in pairs(data.raw["furnace"]) do
    make_pastable(entity_type)
end

--- PASTE DIFFERENT VALUES when copying to a constant-combinator. e.g. copy water=-1000, water=-2400 based on the other values
for _, entity_type in pairs(data.raw["storage-tank"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["pipe"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["splitter"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["underground-belt"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["pipe-to-ground"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["transport-belt"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["container"]) do
    make_pastable(entity_type)
end
for _, entity_type in pairs(data.raw["inserter"]) do
    make_pastable(entity_type)
end

for _, entity_type in pairs(data.raw["furnace"]) do
    make_pastable(entity_type)
end

for _, entity_type in pairs(data.raw["constant-combinator"]) do
    make_pastable(entity_type)
end

-- Modded requester chests (e.g. Bots Bots Bots' "simple-logistic-chest-requester")
-- must explicitly allow being paste targets of the entities this mod copies from,
-- otherwise the engine never fires on_entity_settings_pasted for
-- combinator -> modded-chest copies. Make_pastable is idempotent, so this is safe
-- to run regardless of load order relative to the mods defining the chests.
for _, entity_type in pairs(data.raw["logistic-container"]) do
    make_pastable(entity_type)
end
