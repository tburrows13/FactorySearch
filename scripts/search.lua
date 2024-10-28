math2d = require "math2d"

local Search = {}

local default_surface_data = {
  consumers = {}, producers = {}, storage = {}, logistics = {}, modules = {}, requesters = {}, ground_items = {}, entities = {}, signals = {}, map_tags = {},
  surface_info = {},
}

local function extend(t1, t2)
  local t1_len = #t1
  local t2_len = #t2
  for i=1, t2_len do
    t1[t1_len + i] = t2[i]
  end
end

--- @param sig1 SignalID
--- @param sig2 SignalID
--- @return boolean
local function signal_eq(sig1, sig2)
  return sig1 and sig2 and (sig1.type or 'item') == (sig2.type or 'item') and sig1.name == sig2.name
end

-- Mod-specific overrides for "Entity" search
local mod_placeholder_entities = {
  ['ff-ferrous-nodule'] = {'ff-seamount'},  -- Freight Forwarding
  ['ff-cupric-nodule'] = {'ff-seamount'},
  ['ff-cobalt-crust'] = {'ff-seamount'},

  ['ff-hot-titansteel-plate'] =  -- Freight Forwarding
    {'ff-lava-pool', 'ff-lava-pool-small'},

  ['se-core-fragment-omni'] = {'se-core-fragment-omni', 'se-core-fragment-omni-sealed'},  -- space-exploration
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
local ingredient_entities = list_to_map{ "assembling-machine", "furnace", "mining-drill", "boiler", "burner-generator", "generator", "fusion-reactor", "fusion-generator", "reactor", "inserter", "lab", "car", "spider-vehicle", "locomotive", "thruster" }
local item_ammo_ingredient_entities = list_to_map{ "artillery-turret", "artillery-wagon", "ammo-turret" }  -- spider-vehicle, character
local fluid_ammo_ingredient_entities = list_to_map { "fluid-turret" }
local product_entities = list_to_map{ "assembling-machine", "furnace", "offshore-pump", "mining-drill", "fusion-generator" }  -- TODO add rocket-silo
local item_storage_entities = list_to_map{ "container", "logistic-container", "linked-container", "temporary-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle", "cargo-landing-pad", "space-platform-hub" }
local neutral_item_storage_entities = list_to_map{ "character-corpse" }  -- force = "neutral"
local fluid_storage_entities = list_to_map{ "storage-tank", "fluid-wagon" }
local modules_entities = list_to_map{ "assembling-machine", "furnace", "rocket-silo", "mining-drill", "lab", "beacon" }
local request_entities = list_to_map{ "logistic-container", "character", "spider-vehicle", "roboport", "space-platform-hub", "cargo-landing-pad", "item-request-proxy" }
local item_logistic_entities = list_to_map{ "transport-belt", "splitter", "underground-belt", "linked-belt", "lane-splitter", "loader", "loader-1x1", "inserter", "logistic-robot", "construction-robot" }
local fluid_logistic_entities = list_to_map{ "pipe", "pipe-to-ground", "pump" }
local ground_entities = list_to_map{ "item-entity" }  -- force = "neutral"
local signal_entities = list_to_map{ "roboport", "train-stop", "arithmetic-combinator", "decider-combinator", "constant-combinator", "accumulator", "rail-signal", "rail-chain-signal", "wall", "container", "logistic-container", "inserter", "storage-tank", "mining-drill" }

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
  for category_name, entity_groups in pairs(surface_data) do
    if category_name ~= "surface_info" then
      for _, groups in pairs(entity_groups) do
        for _, group in pairs(groups) do
          group.distance = distance(group.avg_position, player_position)
        end
        table.sort(groups, function (k1, k2) return k1.distance < k2.distance end)
      end
    end
  end
end

local function to_chunk_position(map_position)
  return { math.floor(map_position.x / 32), math.floor(map_position.y / 32) }
end

local function is_wire_connected(entity, entity_type)
  if entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" then
    return entity.get_circuit_network(defines.wire_connector_id.combinator_output_red) or entity.get_circuit_network(defines.wire_connector_id.combinator_output_green)
  else
    return entity.get_circuit_network(defines.wire_connector_id.circuit_red) or entity.get_circuit_network(defines.wire_connector_id.circuit_green)
  end
end

function Search.process_found_entities(entities, state, surface_data, target_item, force)
  -- Not used for Entity and Tag search modes
  -- Only provide `force` if you want to filter out uncharted entities
  local target_name = target_item.name
  local target_type = target_item.type or "item"
  local target_is_item = target_type == "item"
  local target_is_fluid = target_type == "fluid"
  local target_is_virtual = target_type == "virtual"

  for _, entity in pairs(entities) do
    if force and not force.is_chunk_charted(entity.surface, to_chunk_position(entity.position)) then
      goto continue
    end

    local entity_type = entity.type

    -- Signals
    if state.signals then
      if signal_entities[entity_type] then
        local control_behavior = entity.get_control_behavior()
        if control_behavior then
          local signals = {}
          if entity_type == "accumulator" then
            if control_behavior.read_charge then
              table.insert(signals, control_behavior.output_signal)
            end
          elseif entity_type == "assembling-machine" then
            if control_behavior.circuit_read_recipe_finished then
              table.insert(signals, control_behavior.circuit_recipe_finished_signal)
            end
            if control_behavior.circuit_read_working then
              table.insert(signals, control_behavior.circuit_working_signal)
            end
          elseif entity_type == "rail-signal" and control_behavior.read_signal then
            if control_behavior.read_signal then
              table.insert(signals, control_behavior.red_signal)
              table.insert(signals, control_behavior.orange_signal)
              table.insert(signals, control_behavior.green_signal)
            end
          elseif entity_type == "rail-chain-signal" then
            if control_behavior.read_signal then
              table.insert(signals, control_behavior.red_signal)
              table.insert(signals, control_behavior.orange_signal)
              table.insert(signals, control_behavior.blue_signal)
              table.insert(signals, control_behavior.green_signal)
            end
          elseif entity_type == "reactor" then
            if control_behavior.read_temperature then
              table.insert(signals, control_behavior.temperature_signal)
            end
          elseif entity_type == "roboport" then
            if control_behavior.read_robot_stats then
              table.insert(signals, control_behavior.available_logistic_output_signal)
              table.insert(signals, control_behavior.total_logistic_output_signal)
              table.insert(signals, control_behavior.available_construction_output_signal)
              table.insert(signals, control_behavior.total_construction_output_signal)
              table.insert(signals, control_behavior.roboport_count_output_signal)
            end
          elseif entity_type == "space-platform" then
            if control_behavior.read_speed then
              table.insert(signals, control_behavior.speed_signal)
            end
            if control_behavior.read_damage_taken then
              table.insert(signals, control_behavior.damage_taken_signal)
            end
          elseif entity_type == "train-stop" then
            if control_behavior.read_stopped_train then
              table.insert(signals, control_behavior.stopped_train_signal)
            end
            if control_behavior.read_trains_count then
              table.insert(signals, control_behavior.trains_count_signal)
            end
          elseif entity_type == "wall" then
            if control_behavior.read_sensor then
              table.insert(signals, control_behavior.output_signal)
            end
          end

          for _, signal in ipairs(signals) do
            if signal_eq(target_item, signal) then
              SearchResults.add_entity(entity, surface_data.signals)
              SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              break
            end
          end

          if entity_type == 'assembling-machine' then
            -- to avoid duplicate when both circuit_read_contents and circuit_read_ingredients are enabled
            local added_signals = {}

            if control_behavior.circuit_read_contents then
              -- doesn't include current working recipe, but we can't access it at the moment
              local signal_count = entity.get_item_count(target_name)
              if signal_count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                added_signals[target_type..'/'..target_name] = true
              end
            end
            if control_behavior.circuit_read_ingredients then
              local inventory = entity.get_inventory(defines.inventory.assembling_machine_input)
              if inventory then
                local signal_count = inventory.get_item_count(target_name)
                if signal_count > 0 and not added_signals[target_type..'/'..target_name] then
                  SearchResults.add_entity(entity, surface_data.signals)
                  SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                end
              end
            end
          elseif entity_type == "constant-combinator" then
            for _, section in ipairs(control_behavior.sections) do
              for _, filter in ipairs(section.filters) do
                if signal_eq(target_item, filter.value) then
                  SearchResults.add_entity(entity, surface_data.signals)
                  SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                  goto break_both
                end
              end
            end
            ::break_both::
          elseif entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" or entity_type == 'selector-combinator' then
            local signal_count = control_behavior.get_signal_last_tick(target_item)
            if signal_count and signal_count > 0 then
              SearchResults.add_entity(entity, surface_data.signals)
              SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
            end
          elseif entity_type == "reactor" then
            local signal_count = entity.burner.inventory.get_item_count(target_name)
            if signal_count > 0 then
              SearchResults.add_entity(entity, surface_data.signals)
              SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
            elseif signal_eq(target_item, entity.burner.currently_burning) then
              SearchResults.add_entity(entity, surface_data.signals)
              SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
            end
          elseif entity_type == "roboport" then
            if control_behavior.read_items_mode == defines.control_behavior.roboport.read_items_mode.logistics then
              local logistic_network = entity.logistic_network
              if logistic_network then
                local signal_count = logistic_network.get_item_count(target_name)
                if signal_count > 0 then
                  SearchResults.add_entity(entity, surface_data.signals)
                  SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                end
              end
            elseif control_behavior.read_items_mode == defines.control_behavior.roboport.read_items_mode.missing_requests then
              -- TODO not possible right now
            end
          elseif entity_type == 'space-platform-hub' then
            if control_behavior.read_contents then
              local signal_count = entity.get_item_count(target_name)
              if signal_count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              end
            elseif control_behavior.read_moving_from then
              -- TODO would be really hacky to get
            elseif control_behavior.read_moving_to then
              -- TODO would be really hacky to get
            end
          elseif entity_type == "train-stop" then
            if control_behavior.read_from_train then
              local train = entity.get_stopped_train()
              if train then
                if target_is_item then
                  local signal_count = train.get_item_count(target_name)
                  if signal_count > 0 then
                    SearchResults.add_entity(entity, surface_data.signals)
                    SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                  end
                elseif target_is_fluid then
                  local signal_count = train.get_fluid_count(target_name)
                  if signal_count > 0 then
                    SearchResults.add_entity(entity, surface_data.signals)
                    SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
                  end
                end
              end
            end
          elseif entity_type == "container" and target_is_item then
            if control_behavior.read_contents then
              local signal_count = entity.get_item_count(target_name)
              if signal_count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              end
            end
          elseif entity_type == "logistic-container" and target_is_item then
            if control_behavior.circuit_exclusive_mode_of_operation == defines.control_behavior.logistic_container.exclusive_mode.send_contents then
              local signal_count = entity.get_item_count(target_name)
              if signal_count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              end
            end
          elseif entity_type == "inserter" and target_is_item then
            -- Doesn't check inserter if in pulse mode
            if control_behavior.circuit_read_hand_contents and control_behavior.circuit_hand_read_mode == defines.control_behavior.inserter.hand_read_mode.hold then
              local held_stack = entity.held_stack
              if held_stack and held_stack.valid_for_read and signal_eq(target_item, held_stack) then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              end
            end
          elseif entity_type == "storage-tank" and target_is_fluid then
            if control_behavior.read_contents then
              local signal_count = entity.get_fluid_count(target_name)
              if signal_count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
              end
            end
          elseif entity_type == "mining-drill" then
            if control_behavior.circuit_read_resources then
              local resources = control_behavior.resource_read_targets
              local count = 0
              for _, resource in pairs(resources) do
                if resource.name == target_name then
                  if resource.initial_amount then
                    count = count + (resource.amount / 30000)  -- Calculate fluid/s from amount
                  else
                    count = count + resource.amount
                  end
                end
              end
              if count > 0 then
                SearchResults.add_entity(entity, surface_data.signals)
                SearchResults.add_surface_info("signal_count", 1, surface_data.surface_info)
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

    -- Ingredients / Consumers
    if state.consumers then
      local recipe
      if entity_type == "assembling-machine" then
        recipe = entity.get_recipe()
      elseif entity_type == "furnace" then
        -- Even if the furnace has stopped smelting, this records the last item it was smelting
        recipe = entity.get_recipe() or entity.previous_recipe
      end

      if recipe and recipe.ingredients then
        for _, ingredient in pairs(recipe.ingredients) do
          if signal_eq(target_item, ingredient) then
            SearchResults.add_entity_product(entity, surface_data.consumers, recipe)
            SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
            break
          end
        end
      elseif target_is_item and entity_type == "lab" then
        local item_count = entity.get_item_count(target_name)
        if item_count > 0 then
          SearchResults.add_entity(entity, surface_data.consumers)
          SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
        end
      elseif target_is_fluid then
        if entity_type == "generator" or entity_type == "thruster" then
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            SearchResults.add_entity(entity, surface_data.consumers)
            SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
          end
        else
          local input_fluidbox = entity.prototype.fluidbox_prototypes[1]  -- TODO check assumption
          if input_fluidbox and input_fluidbox.filter and input_fluidbox.filter.name == target_name then
            SearchResults.add_entity(entity, surface_data.consumers)
            SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
          end
        end
      end

      local burner = entity.burner
      if burner then
        local currently_burning = burner.currently_burning
        if currently_burning and signal_eq(target_item, currently_burning.name) then
          SearchResults.add_entity(entity, surface_data.consumers)
          SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
        end
      end

      -- Consuming ammo
      if target_is_item and (entity_type == "artillery-turret" or entity_type == "artillery-wagon" or entity_type == "ammo-turret") then
        local item_count = entity.get_item_count(target_name)
        if item_count > 0 then
          SearchResults.add_entity(entity, surface_data.consumers)
          SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
        end
      elseif target_is_fluid and entity_type == "fluid-turret" then
        local fluid_count = entity.get_fluid_count(target_name)
        if fluid_count > 0 then
          SearchResults.add_entity(entity, surface_data.consumers)
          SearchResults.add_surface_info("consumers_count", 1, surface_data.surface_info)
        end
      end
    end

    -- Producers
    if state.producers then
      local recipe
      if entity_type == "assembling-machine" then
        recipe = entity.get_recipe()
      elseif entity_type == "furnace" then
        -- Even if the furnace has stopped smelting, this records the last item it was smelting
        recipe = entity.get_recipe() or entity.previous_recipe
      end

      if recipe and recipe.products then
        for _, product in pairs(recipe.products) do
          if signal_eq(target_item, product) then
            SearchResults.add_entity_product(entity, surface_data.producers, recipe)
            SearchResults.add_surface_info("producers_count", 1, surface_data.surface_info)
            break
          end
        end
      elseif entity_type == "mining-drill" then
        local mining_target = entity.mining_target
        if mining_target then
          local mineable_properties = mining_target.prototype.mineable_properties
          for _, product in pairs(mineable_properties.products or {}) do
            if signal_eq(target_item, product) then
              SearchResults.add_entity(entity, surface_data.producers)
              SearchResults.add_surface_info("producers_count", 1, surface_data.surface_info)
              break
            end
          end
        end
      elseif target_is_fluid and entity_type == "offshore-pump" then
        if entity.get_fluid_count(target_name) > 0 then
          SearchResults.add_entity(entity, surface_data.producers)
          SearchResults.add_surface_info("producers_count", 1, surface_data.surface_info)
        end
      elseif target_is_fluid and (entity_type == "fusion-generator") then
        local prototype = entity.prototype
        local fluidboxes = prototype.fluidbox_prototypes
        local output = fluidboxes[2]  -- TODO check assumption
        if output.filter.name == target_name then
          SearchResults.add_entity(entity, surface_data.producers)
          SearchResults.add_surface_info("producers_count", 1, surface_data.surface_info)
        end
      end
    end

    -- Storage
    if state.storage then
      if target_is_fluid and (entity_type == "storage-tank" or entity_type == "fluid-wagon") then
        local fluid_count = entity.get_fluid_count(target_name)
        if fluid_count > 0 then
          SearchResults.add_entity_storage_fluid(entity, surface_data.storage, fluid_count)
          SearchResults.add_surface_info("fluid_count", fluid_count, surface_data.surface_info)
        end
      elseif target_is_item and (entity_type == "character-corpse" or item_storage_entities[entity_type]) then
        -- Entity is an inventory entity
        local item_count = entity.get_item_count(target_name)
        if item_count > 0 then
          SearchResults.add_entity_storage(entity, surface_data.storage, item_count)
          SearchResults.add_surface_info("item_count", item_count, surface_data.surface_info)
        end
      end
    end

    -- Modules
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
            SearchResults.add_surface_info("module_count", item_count, surface_data.surface_info)
          end
        end
      end
    end

    -- Requesters
    if target_is_item and state.requesters then
      -- Buffer and Requester chests, character, and spidertron
      if entity_type == "logistic-container" or entity_type == "character" or entity_type == "spider-vehicle" then
        local logistic_points = entity.get_logistic_point()
        for _, logistic_point in pairs(logistic_points) do
          for _, filter in pairs(logistic_point.filters or {}) do
            if filter and filter.name == target_name then
              SearchResults.add_entity_request(entity, surface_data.requesters, filter.count)
              SearchResults.add_surface_info("request_count", filter.count, surface_data.surface_info)
            end
          end
        end
      elseif entity_type == "item-request-proxy" then
        local requests = entity.item_requests
        for _, item in pairs(requests) do
          if item.name == target_name then
            SearchResults.add_entity_request(entity.proxy_target, surface_data.requesters, item.count)
            SearchResults.add_surface_info("request_count", item.count, surface_data.surface_info)
          end
        end
      end
    end

    -- Ground
    if target_is_item and state.ground_items then
      if entity_type == "item-entity" and entity.name == "item-on-ground" then
        if entity.stack.name == target_name then
          SearchResults.add_entity(entity, surface_data.ground_items)
          SearchResults.add_surface_info("ground_count", 1, surface_data.surface_info)
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
            SearchResults.add_surface_info("item_count", held_stack.count, surface_data.surface_info)
          end
        else
          local item_count = entity.get_item_count(target_name)
          if item_count > 0 then
            SearchResults.add_entity_storage(entity, surface_data.logistics, item_count)
            SearchResults.add_surface_info("item_count", item_count, surface_data.surface_info)
          end
        end
      elseif fluid_logistic_entities[entity_type] then
        -- So target.type == "fluid"
        local fluid_count = entity.get_fluid_count(target_name)
        if fluid_count > 0 then
          SearchResults.add_entity_storage_fluid(entity, surface_data.logistics, fluid_count)
          SearchResults.add_surface_info("fluid_count", fluid_count, surface_data.surface_info)
        end
      end
    end
    ::continue::
  end
end

function Search.blocking_search(force, state, target_item, surface_list, type_list, neutral_type_list, player)
  local target_name = target_item.name
  local target_type = target_item.type or "item"
  local target_is_item = target_type == "item"
  local target_is_fluid = target_type == "fluid"
  local target_is_virtual = target_type == "virtual"
  local target_is_entity = target_type == "entity"

  local data = {}

  for _, surface in pairs(surface_list) do
    if not surface.valid then goto continue end
    local surface_data = table.deepcopy(default_surface_data)

    local entities = {}
    if next(type_list) then
      entities = surface.find_entities_filtered{
        type = type_list,
        force = force,
      }
    end

    -- Corpses and items on ground don't have a force: find seperately
    if next(neutral_type_list) then
      local neutral_entities = surface.find_entities_filtered{
        type = neutral_type_list,
      }
      extend(entities, neutral_entities)
    end

    Search.process_found_entities(entities, state, surface_data, target_item, force)

    -- Map tags
    if state.map_tags then
      local tags = force.find_chart_tags(surface.name)
      for _, tag in pairs(tags) do
        local tag_icon = tag.icon
        if tag_icon and signal_eq(target_item, tag_icon) then
          SearchResults.add_tag(tag, surface_data.map_tags)
          SearchResults.add_surface_info("tag_count", 1, surface_data.surface_info)
        end
      end
    end

    -- Entities
    if state.entities then
      local target_entity_name = target_is_entity and target_name
      if target_is_entity then
        target_entity_name = target_name
      else
        target_entity_name = mod_placeholder_entities[target_name]
      end
      if not target_entity_name then
        -- Check if the item is produced by mining any entities
        target_entity_name = storage.item_to_entities[target_name]
      end
      if not target_entity_name and prototypes.item[target_name] and prototypes.item[target_name].place_result then
        -- Check for the item's place_result
        target_entity_name = prototypes.item[target_name].place_result.name
      end
      if not target_entity_name then
        -- Or just try an entity with the same name as the item
        target_entity_name = target_name
      end
      -- Type will be table if storage.item_to_entities succeeded. We know they are all valid entities
      if type(target_entity_name) == "table" or prototypes.entity[target_entity_name] then
        entities = surface.find_entities_filtered{
          name = target_entity_name,
          force = { force, "neutral" },
        }
        for _, entity in pairs(entities) do
          if entity.type == "resource" then
            local amount
            if entity.initial_amount then
              amount = entity.amount / 3000  -- Calculate yield from amount
            else
              amount = entity.amount
            end
            SearchResults.add_entity_resource(entity, surface_data.entities, amount)
            SearchResults.add_surface_info("resource_count", amount, surface_data.surface_info)
          else
            SearchResults.add_entity(entity, surface_data.entities)
            SearchResults.add_surface_info("entity_count", 1, surface_data.surface_info)
          end
        end
      end
    end

    if surface == player.surface then
      generate_distance_data(surface_data, player.position)
    end
    data[surface.name] = surface_data
    ::continue::
  end

  local player_data = storage.players[player.index]
  local refs = player_data.refs
  Gui.build_results(data, refs.result_flow)
  storage.current_searches[player.index] = nil
end

function Search.on_tick()
  local player_index, search_data = next(storage.current_searches)
  if not search_data then return end

  -- First, check to see if we can trigger a blocking search
  if search_data.blocking then
    if search_data.tick_triggered + DEBOUNCE_TICKS < game.tick then
      -- TODO Check player is still online?
      Search.blocking_search(search_data.force, search_data.state, search_data.target_item, search_data.not_started_surfaces, search_data.type_list, search_data.neutral_type_list, search_data.player)
    end
    return
  end

  if search_data.search_complete then
    local player_data = storage.players[player_index]
    local refs = player_data.refs
    Gui.build_results(search_data.data, refs.result_flow)
    storage.current_searches[player_index] = nil
  end

  local current_surface = search_data.current_surface
  if not current_surface or not current_surface.valid then
    -- Start next surface
    current_surface = table.remove(search_data.not_started_surfaces)
    if not current_surface then
      -- All surfaces are complete
      local player = search_data.player
      local surface_data = search_data.data[player.surface.name]
      if surface_data then
        generate_distance_data(surface_data, player.position)
      end
      search_data.search_complete = true
      return
    end

    if not current_surface.valid then return end  -- Will try another surface next tick

    -- Setup next surface data
    search_data.current_surface = current_surface
    search_data.surface_data = table.deepcopy(default_surface_data)
    search_data.chunk_iterator = current_surface.get_chunks()

    -- Update results
    local player_data = storage.players[player_index]
    local refs = player_data.refs
    Gui.build_results(search_data.data, refs.result_flow, false, true)
    Gui.add_loading_results(refs.result_flow)
    return  -- Start next surface processing on next tick
  end


  local chunk_iterator = search_data.chunk_iterator
  if not chunk_iterator.valid then
    search_data.current_surface = nil
    return
  end

  local force = search_data.force
  local chunks_processed = 0
  local chunks_per_tick = settings.global["fs-chunks-per-tick"].value
  while chunks_processed < chunks_per_tick do
    local chunk = chunk_iterator()
    if not chunk then
      -- Surface is complete
      search_data.data[current_surface.name] = search_data.surface_data
      search_data.current_surface = nil
      return
    end

    if force.is_chunk_charted(current_surface, chunk) then
      chunks_processed = chunks_processed + 1
    else
      goto continue
    end

    local target_item = search_data.target_item
    local target_name = target_item.name
    local target_type = target_item.type or "item"
    local target_is_item = target_type == "item"
    local target_is_fluid = target_type == "fluid"
    local target_is_virtual = target_type == "virtual"
    local target_is_entity = target_type == "entity"

    local state = search_data.state
    local surface_data = search_data.surface_data

    local chunk_area = chunk.area

    local entities = {}
    if next(search_data.type_list) then
      entities = current_surface.find_entities_filtered{
        area = chunk_area,
        type = search_data.type_list,
        force = force,
      }
    end

    -- Corpses and items on ground don't have a force: find seperately
    if next(search_data.neutral_type_list) then
      local neutral_entities = current_surface.find_entities_filtered{
        area = chunk_area,
        type = search_data.neutral_type_list,
      }
      extend(entities, neutral_entities)
    end

    for i, entity in pairs(entities) do
      if not math2d.bounding_box.contains_point(chunk_area, entity.position) then
        entities[i] = nil
      end
    end

    Search.process_found_entities(entities, state, surface_data, target_item)

    -- Map tags
    if state.map_tags then
      local slightly_smaller_chunk_area = {left_top = {chunk_area.left_top.x, chunk_area.left_top.y}, right_bottom = {chunk_area.right_bottom.x - 1, chunk_area.right_bottom.y - 1}}
      local tags = force.find_chart_tags(current_surface.name, slightly_smaller_chunk_area)
      for _, tag in ipairs(tags) do
        if math2d.bounding_box.contains_point(chunk_area, tag.position) then
          local tag_icon = tag.icon
          if tag_icon and signal_eq(target_item, tag_icon) then
            SearchResults.add_tag(tag, surface_data.map_tags)
            SearchResults.add_surface_info("tag_count", 1, surface_data.surface_info)
          end
        end
      end
    end

    -- Entities
    if state.entities then
      local target_entity_name = target_is_entity and target_name
      if target_is_entity then
        target_entity_name = target_name
      else
        target_entity_name = mod_placeholder_entities[target_name]
      end
      if not target_entity_name then
        -- Check if the item is produced by mining any entities
        target_entity_name = storage.item_to_entities[target_name]
      end
      if not target_entity_name and prototypes.item[target_name] and prototypes.item[target_name].place_result then
        -- Check for the item's place_result
        target_entity_name = prototypes.item[target_name].place_result.name
      end
      if not target_entity_name then
        -- Or just try an entity with the same name as the item
        target_entity_name = target_name
      end

      if type(target_entity_name) == "table" or prototypes.entity[target_entity_name] then
        entities = current_surface.find_entities_filtered{
          area = chunk_area,
          name = target_entity_name,
          force = { force, "neutral" },
        }
        for _, entity in pairs(entities) do
          if math2d.bounding_box.contains_point(chunk_area, entity.position) then
            if entity.type == "resource" then
              local amount
              if entity.initial_amount then
                amount = entity.amount / 3000  -- Calculate yield from amount
              else
                amount = entity.amount
              end
              SearchResults.add_entity_resource(entity, surface_data.entities, amount)
              SearchResults.add_surface_info("resource_count", amount, surface_data.surface_info)
            else
              SearchResults.add_entity(entity, surface_data.entities)
              SearchResults.add_surface_info("entity_count", 1, surface_data.surface_info)
            end
          end
        end
      end
    end
    ::continue::
  end

end
event.on_tick(Search.on_tick)

function Search.find_machines(target_item, force, state, player, override_surface, immediate)
  local target_name = target_item.name
  if target_name == nil then
    -- 'Unknown signal selected'
    return false
  end

  -- Crafting Combinator adds signals for recipes, which players sometimes mistake for items/fluids
  if target_item.type == "virtual" and not state.signals
    and (game.active_mods["crafting_combinator"] or game.active_mods["crafting_combinator_xeraph"]) then
    local recipe = prototypes.recipe[target_name]
    if recipe then
      player.print("[Factory Search] It looks like you selected a recipe from the \"Crafting combinator recipes\" tab. Instead select an item or fluid from a different tab.")
      return false
    end
  end

  local target_type = target_item.type or "item"
  local target_is_item = target_type == "item"
  local target_is_fluid = target_type == "fluid"
  local target_is_virtual = target_type == "virtual"

  local entity_types = {}
  local neutral_entity_types = {}
  if (target_is_item or target_is_fluid) and state.consumers then
    add_entity_type(entity_types, ingredient_entities)

    -- Only add turrets if target is ammo
    if target_is_item and prototypes.get_item_filtered({{filter = "type", type = "ammo"}})[target_name] then
      add_entity_type(entity_types, item_ammo_ingredient_entities)
    elseif target_is_fluid then
      add_entity_type(entity_types, fluid_ammo_ingredient_entities)
    end
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
  if target_is_item and state.modules then
    add_entity_type(entity_types, modules_entities)
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

  local surface_list = filtered_surfaces(override_surface, player.surface)

  local non_blocking_setting = settings.global["fs-non-blocking-search"].value
  if non_blocking_setting == "on" or (non_blocking_setting == "multiplayer" and game.is_multiplayer()) then
    non_blocking_search = true
  else
    non_blocking_search = false
  end
  search_data = {
    blocking = not non_blocking_search,
    tick_triggered = game.tick - (immediate and DEBOUNCE_TICKS or 0),
    force = force,
    state = state,
    target_item = target_item,
    type_list = type_list,
    neutral_type_list = neutral_type_list,
    player = player,
    data = {},
    not_started_surfaces = surface_list,
    completed_surfaces = {}
  }
  storage.current_searches[player.index] = search_data
  return true
end

return Search