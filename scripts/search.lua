math2d = require "__core__.lualib.math2d"
search_signals = require "__FactorySearch__.scripts.search-signals"

local Search = {}

local function extend(t1, t2)
  local t1_len = #t1
  local t2_len = #t2
  for i=1, t2_len do
    t1[t1_len + i] = t2[i]
  end
end

local function signal_eq(sig1, sig2)
  return sig1 and sig2 and sig1.type == sig2.type and sig1.name == sig2.name
end

-- Some entities are secretly swapped around by their mod. This allows all entities associated
-- with an item to be found by 'Entity' search
local mod_placeholder_entities = {
  ['sp-spidertron-dock'] =  -- SpidertronPatrols
    {'sp-spidertron-dock-0', 'sp-spidertron-dock-30', 'sp-spidertron-dock-80', 'sp-spidertron-dock-100'},

  ['offshore-pump-0'] = 'offshore-pump-0',  -- P-U-M-P-S
  ['offshore-pump-1'] = 'offshore-pump-1',
  ['offshore-pump-2'] = 'offshore-pump-2',
  ['offshore-pump-3'] = 'offshore-pump-3',
  ['offshore-pump-4'] = 'offshore-pump-4',

  ['burner-offshore-pump'] = 'burner-offshore-pump',  -- BurnerOffshorePump
  ['electric-offshore-pump'] = 'electric-offshore-pump',
  ['se-core-fragment-omni'] = {'se-core-fragment-omni', 'se-core-fragment-omni-sealed'},
  ['se-core-fragment-iron-ore'] = {'se-core-fragment-iron-ore', 'se-core-fragment-iron-ore-sealed'},
  ['se-core-fragment-copper-ore'] = {'se-core-fragment-copper-ore', 'se-core-fragment-copper-ore-sealed'},
  ['se-core-fragment-coal'] = {'se-core-fragment-coal', 'se-core-fragment-coal-sealed'},
  ['se-core-fragment-stone'] = {'se-core-fragment-stone', 'se-core-fragment-stone-sealed'},
  ['se-core-fragment-uranium-ore'] = {'se-core-fragment-uranium-ore', 'se-core-fragment-uranium-ore-sealed'},
  ['se-core-fragment-crude-oil'] = {'se-core-fragment-crude-oil', 'se-core-fragment-crude-oil-sealed'},
  ['se-core-fragment-se-beryllium-ore'] = {'se-core-fragment-beryllium-ore', 'se-core-fragment-beryllium-ore-sealed'},
  ['se-core-fragment-se-cryonite'] = {'se-core-fragment-se-cryonite', 'se-core-fragment-se-cryonite-sealed'},
  ['se-core-fragment-se-holmium-ore'] = {'se-core-fragment-se-holmium-ore', 'se-core-fragment-se-holmium-ore-sealed'},
  ['se-core-fragment-se-iridium-ore'] = {'se-core-fragment-se-iridium-ore', 'se-core-fragment-se-iridium-ore-sealed'},
  ['se-core-fragment-se-vulcanite'] = {'se-core-fragment-se-vulcanite', 'se-core-fragment-se-vulcanite-sealed'},
  ['se-core-fragment-se-vitemelange'] = {'se-core-fragment-se-vitemelange', 'se-core-fragment-se-vitemelange-sealed'},
}

local list_to_map = util.list_to_map
local ingredient_entities = list_to_map{ "assembling-machine", "furnace", "mining-drill", "boiler", "burner-generator", "generator", "reactor", "inserter", "lab", "car", "spider-vehicle", "locomotive" }
local product_entities = list_to_map{ "assembling-machine", "furnace", "offshore-pump", "mining-drill" }  -- TODO add rocket-silo
local item_storage_entities = list_to_map{ "container", "logistic-container", "linked-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle" }
local neutral_item_storage_entities = list_to_map{ "character-corpse" }  -- force = "neutral"
local fluid_storage_entities = list_to_map{ "storage-tank", "fluid-wagon" }
local modules_entities = list_to_map{ "assembling-machine", "furnace", "rocket-silo", "mining-drill", "lab", "beacon" }
local request_entities = list_to_map{ "logistic-container", "character", "spider-vehicle", "item-request-proxy" }
local item_logistic_entities = list_to_map{ "transport-belt", "splitter", "underground-belt", "loader", "loader-1x1", "inserter", "logistic-robot", "construction-robot" }
local fluid_logistic_entities = list_to_map{ "pipe", "pipe-to-ground", "pump" }
local ground_entities = list_to_map{ "item-entity" }  -- force = "neutral"
local signal_entities = list_to_map{ "roboport", "train-stop", "arithmetic-combinator", "decider-combinator", "constant-combinator", "accumulator", "rail-signal", "rail-chain-signal", "wall" }

local function add_entity_type(type_list, to_add_list)
  for name, _ in pairs(to_add_list) do
    type_list[name] = true
  end
end

local function map_to_list(map)
  local i = 1
  local list = {}
  for name, _ in pairs(map) do
    list[i] = name
    i = i + 1
  end
  return list
end

local function generate_distance_data(surface_data, player_position)
  local distance = math2d.position.distance
  for _, entity_groups in pairs(surface_data) do
    for _, groups in pairs(entity_groups) do
      for _, group in pairs(groups) do
        group.distance = distance(group.avg_position, player_position)
      end
    end
  end
end

function Search.find_machines(target_item, force, state, player_position, player_surface, override_surface)
  local data = {}
  local target_name = target_item.name
  if target_name == nil then
    -- 'Unknown signal selected'
    return data
  end
  local target_type = target_item.type
  local target_is_item = target_type == "item"
  local target_is_fluid = target_type == "fluid"
  local target_is_virtual = target_type == "virtual"

  local entity_types = {}
  local neutral_entity_types = {}
  if (target_is_item or target_is_fluid) and state.consumers then
    add_entity_type(entity_types, ingredient_entities)
  end
  if (target_is_item or target_is_fluid) and state.producers then
    add_entity_type(entity_types, product_entities)
  end
  if target_is_item and state.storage then
    add_entity_type(entity_types, item_storage_entities)
    add_entity_type(neutral_entity_types, neutral_item_storage_entities)
  end
  if target_is_fluid and state.storage then
    add_entity_type(entity_types, fluid_storage_entities)
  end
  if target_is_item and state.requesters then
    add_entity_type(entity_types, request_entities)
  end
  if target_is_item and state.logistics then
    add_entity_type(entity_types, item_logistic_entities)
  end
  if target_is_fluid and state.logistics then
    add_entity_type(entity_types, fluid_logistic_entities)
  end
  if target_is_item and state.ground_items then
    add_entity_type(neutral_entity_types, ground_entities)
  end
  if state.signals then
    add_entity_type(entity_types, signal_entities)
  end
  local type_list = map_to_list(entity_types)
  local neutral_type_list = map_to_list(neutral_entity_types)

  for _, surface in pairs(filtered_surfaces(override_surface, player_surface)) do
    local surface_data = { consumers = {}, producers = {}, storage = {}, logistics = {}, modules = {}, requesters = {}, ground_items = {}, entities = {}, signals = {}, map_tags = {} }

    local entities = surface.find_entities_filtered{
      type = type_list,
      force = force,
    }

    -- Corpses and items on ground don't have a force: find seperately
    if next(neutral_entity_types) then
      local neutral_entities = surface.find_entities_filtered{
        type = neutral_type_list,
      }
      extend(entities, neutral_entities)
    end

    for _, entity in pairs(entities) do
      local entity_type = entity.type

      -- Signals
      if state.signals then
        if signal_entities[entity_type] then
          local control_behavior = entity.get_control_behavior()
          if control_behavior then
            if entity_type == "constant-combinator" then
              -- If prototype's `item_slot_count = 0` then .parameters will be nil
              for _, parameter in pairs(control_behavior.parameters or {}) do
                if signal_eq(parameter.signal, target_item) then
                  SearchResults.add_entity_signal(entity, surface_data.signals, parameter.count)
                end
              end
            elseif entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" then
              local signal_count = control_behavior.get_signal_last_tick(target_item)
              if signal_count ~= nil then
                SearchResults.add_entity_signal(entity, surface_data.signals, signal_count)
              end
            elseif entity_type == "roboport" then
              for _, signal in pairs({ control_behavior.available_logistic_output_signal, control_behavior.total_logistic_output_signal, control_behavior.available_construction_output_signal, control_behavior.total_construction_output_signal }) do
                if signal_eq(signal, target_item) then
                  SearchResults.add_entity(entity, surface_data.signals)
                  break
                end
              end
            elseif entity_type == "train-stop" then
              if signal_eq(control_behavior.stopped_train_signal, target_item) or signal_eq(control_behavior.trains_count_signal, target_item) then
                SearchResults.add_entity(entity, surface_data.signals)
              end
            elseif entity_type == "accumulator" or entity_type == "wall" then
              if signal_eq(control_behavior.output_signal, target_item) then
                SearchResults.add_entity(entity, surface_data.signals)
              end
            elseif entity_type == "rail-signal" then
              for _, signal in pairs({ control_behavior.red_signal, control_behavior.orange_signal, control_behavior.green_signal }) do
                if signal_eq(signal, target_item) then
                  SearchResults.add_entity(entity, surface_data.signals)
                  break
                end
              end
            elseif entity_type == "rail-chain-signal" then
              for _, signal in pairs({ control_behavior.red_signal, control_behavior.orange_signal, control_behavior.green_signal, control_behavior.blue_signal }) do
                if signal_eq(signal, target_item) then
                  SearchResults.add_entity(entity, surface_data.signals)
                  break
                end
              end
            end
          end
        end
      end
      if target_is_virtual then
        -- We've done all processing that there is to be done on virtual signals
        goto continue
      end

      if state.consumers then
        local recipe
        if entity_type == "assembling-machine" then
          recipe = entity.get_recipe()
        elseif entity_type == "furnace" then
          recipe = entity.get_recipe()
          if recipe == nil then
            -- Even if the furnace has stopped smelting, this records the last item it was smelting
            recipe = entity.previous_recipe
          end
        end
        if recipe then
          local ingredients = recipe.ingredients
          for _, ingredient in pairs(ingredients) do
            local name = ingredient.name
            if name == target_name then
              SearchResults.add_entity_product(entity, surface_data.consumers, recipe)
            end
          end
        end
        if target_is_item and entity_type == "lab" then
          local item_count = entity.get_item_count(target_name)
          if item_count > 0 then
            SearchResults.add_entity(entity, surface_data.consumers)
          end
        end
        if target_is_fluid and entity_type == "generator" then
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            SearchResults.add_entity(entity, surface_data.consumers)
          end
        end
        local burner = entity.burner
        if burner then
          local currently_burning = burner.currently_burning
          if currently_burning then
            if currently_burning.name == target_name then
              SearchResults.add_entity(entity, surface_data.consumers)
            end
          end
        end
      end

      -- Producers
      if state.producers then
        local recipe
        if entity_type == "assembling-machine" then
          recipe = entity.get_recipe()
        elseif entity_type == "furnace" then
          recipe = entity.get_recipe()
          if recipe == nil then
            -- Even if the furnace has stopped smelting, this records the last item it was smelting
            recipe = entity.previous_recipe
          end
        elseif entity_type == "mining-drill" then
          local mining_target = entity.mining_target
          if mining_target and mining_target.name == target_name then
            SearchResults.add_entity(entity, surface_data.producers)
          end
        elseif target_is_fluid and entity_type == "offshore-pump" then
          if entity.get_fluid_count(target_name) > 0 then
            SearchResults.add_entity(entity, surface_data.producers)
          end
        end
        if recipe then
          local products = recipe.products
          for _, product in pairs(products) do
            local name = product.name
            if name == target_name then
              SearchResults.add_entity_product(entity, surface_data.producers, recipe)
            end
          end
        end
      end

      -- Storage
      if state.storage then
        if target_is_fluid and (entity_type == "storage-tank" or entity_type == "fluid-wagon") then
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            SearchResults.add_entity_storage_fluid(entity, surface_data.storage, fluid_count)
          end
        elseif target_is_item and (entity_type == "character-corpse" or item_storage_entities[entity_type]) then
          -- Entity is an inventory entity
          local item_count = entity.get_item_count(target_name)
          if item_count > 0 then
            SearchResults.add_entity_storage(entity, surface_data.storage, item_count)
          end
        end
      end

      if state.modules then
        if target_is_item and modules_entities[entity_type] then
          local inventory
          if entity_type == "beacon" then
            inventory = entity.get_inventory(defines.inventory.beacon_modules)
          elseif entity_type == "lab" then
            inventory = entity.get_inventory(defines.inventory.lab_modules)
          elseif entity_type == "mining-drill" then
            inventory = entity.get_inventory(defines.inventory.mining_drill_modules)
          elseif entity_type == "assembling-machine" or entity_type == "furnace" or entity_type == "rocket-silo" then
            inventory = entity.get_inventory(defines.inventory.assembling_machine_modules)
          end
          if inventory then
            local item_count = inventory.get_item_count(target_name)
            if item_count > 0 then
              SearchResults.add_entity_module(entity, surface_data.modules, item_count)
            end
          end
        end
      end

      -- Requesters
      if target_is_item and state.requesters then
        -- Buffer and Requester chests
        if entity_type == "logistic-container" then
          for i=1, entity.request_slot_count do
            local request = entity.get_request_slot(i)
            if request and request.name == target_name then
              local count = request.count
              if count then
                SearchResults.add_entity_request(entity, surface_data.requesters, count)
              end
            end
          end
        elseif entity_type == "character" then
          for i=1, entity.request_slot_count do
            local request = entity.get_personal_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                SearchResults.add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        elseif entity_type == "spider-vehicle" then
          for i=1, entity.request_slot_count do
            local request = entity.get_vehicle_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                SearchResults.add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        elseif entity_type == "item-request-proxy" then
          local request_count = entity.item_requests[target_name]
          if request_count ~= nil then
            SearchResults.add_entity_request(entity.proxy_target, surface_data.requesters, request_count)
          end
        end
      end

      -- Ground
      if target_is_item and state.ground_items then
        if entity_type == "item-entity" and entity.name == "item-on-ground" then
          if entity.stack.name == target_name then
            SearchResults.add_entity(entity, surface_data.ground_items)
          end
        end
      end

      -- Logistics
      if state.logistics then
        if item_logistic_entities[entity_type] then
          if entity_type == "inserter" then
            local held_stack = entity.held_stack
            if held_stack and held_stack.valid_for_read and held_stack.name == target_name then
              SearchResults.add_entity_storage(entity, surface_data.logistics, held_stack.count)
            end
          else
            local item_count = entity.get_item_count(target_name)
            if item_count > 0 then
              SearchResults.add_entity_storage(entity, surface_data.logistics, item_count)
            end
          end
        elseif fluid_logistic_entities[entity_type] then
          -- So target.type == "fluid"
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            SearchResults.add_entity_storage_fluid(entity, surface_data.logistics, fluid_count)
          end
        end
      end
      ::continue::
    end

    -- Map tags
    if state.map_tags then
      local tags = force.find_chart_tags(surface.name)
      for _, tag in pairs(tags) do
        local tag_icon = tag.icon
        if tag_icon and tag_icon.type == target_type and tag_icon.name == target_name then
          SearchResults.add_tag(tag, surface_data.map_tags)
        end
      end
    end

    -- Entities
    if target_is_item and state.entities then
      local target_entity_name = mod_placeholder_entities[target_name]

      if not target_entity_name then
        local item_prototype = game.item_prototypes[target_name]
        target_entity_name = target_name
        if item_prototype.place_result then
          target_entity_name = item_prototype.place_result.name
        end
      end

      entities = surface.find_entities_filtered{
        name = target_entity_name,
        force = { force, "neutral" },
      }
      for _, entity in pairs(entities) do
        SearchResults.add_entity(entity, surface_data.entities)
      end
    end
    if surface == player_surface then
      generate_distance_data(surface_data, player_position)
    end
    data[surface.name] = surface_data
  end
  return data
end

return Search