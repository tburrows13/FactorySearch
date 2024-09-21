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

local function signal_eq(sig1, sig2)
  return sig1 and sig2 and sig1.type == sig2.type and sig1.name == sig2.name
end

local list_to_map = util.list_to_map
local ingredient_entities = list_to_map{ "assembling-machine", "furnace", "mining-drill", "boiler", "burner-generator", "generator", "reactor", "inserter", "lab", "car", "spider-vehicle", "locomotive" }
local item_ammo_ingredient_entities = list_to_map{ "artillery-turret", "artillery-wagon", "ammo-turret" }  -- spider-vehicle, character
local fluid_ammo_ingredient_entities = list_to_map { "fluid-turret" }
local product_entities = list_to_map{ "assembling-machine", "furnace", "offshore-pump", "mining-drill" }  -- TODO add rocket-silo
local item_storage_entities = list_to_map{ "container", "logistic-container", "linked-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle" }
local neutral_item_storage_entities = list_to_map{ "character-corpse" }  -- force = "neutral"
local fluid_storage_entities = list_to_map{ "storage-tank", "fluid-wagon" }
local modules_entities = list_to_map{ "assembling-machine", "furnace", "rocket-silo", "mining-drill", "lab", "beacon" }
local request_entities = list_to_map{ "logistic-container", "character", "spider-vehicle", "item-request-proxy" }
local item_logistic_entities = list_to_map{ "transport-belt", "splitter", "underground-belt", "loader", "loader-1x1", "inserter", "logistic-robot", "construction-robot" }
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

local function to_chunk_position(map_position)
  return { math.floor(map_position.x / 32), math.floor(map_position.y / 32) }
end

local function is_wire_connected(entity, entity_type)
  if entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" then
    return entity.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output) or entity.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_output)
  else
    return entity.get_circuit_network(defines.wire_type.red) or entity.get_circuit_network(defines.wire_type.green)
  end
end

---@param entities LuaEntity[]
---@param state SearchState
---@param surface_data SurfaceSearchResult
---@param force LuaForce
function Search.process_found_entities(entities, state, surface_data, force)
  -- Not used for Entity and Tag search modes
  -- Only provide `force` if you want to filter out uncharted entities

    ---@type LuaEntity
  for _, entity in pairs(entities) do
    if force and not force.is_chunk_charted(entity.surface, to_chunk_position(entity.position)) then
      goto continue
    end

    local entity_type = entity.type

    -- Signals
    if state.signals then
      if signal_entities[entity_type] then
        local control_behavior = entity.get_control_behavior()
        if control_behavior and is_wire_connected(entity, entity_type) then
          -- Does everything except mining drill, as API doesn't support that
          if entity_type == "constant-combinator" then
            -- If prototype's `item_slot_count = 0` then .parameters will be nil
            for _, parameter in pairs(control_behavior.parameters or {}) do
              if parameter.signal.name then
                local item_data = Search.get_item_surface_data(surface_data, parameter.signal.type, parameter.signal.name)
                SearchResults.add_entity_signal(entity, item_data.signals, parameter.count)
                SearchResults.add_surface_info("signal_count", parameter.count, item_data.surface_info)
              end
            end
          elseif entity_type == "arithmetic-combinator" or entity_type == "decider-combinator" then
            for _, signal in ipairs(control_behavior.signals_last_tick or {}) do
              if signal.signal.name then
                local item_data = Search.get_item_surface_data(surface_data, signal.signal.type, signal.signal.name)
                SearchResults.add_entity_signal(entity, item_data.signals, signal.count)
                SearchResults.add_surface_info("signal_count", signal.count, item_data.surface_info)
              end
            end
          elseif entity_type == "roboport" then
            for _, signal in pairs({ control_behavior.available_logistic_output_signal, control_behavior.total_logistic_output_signal, control_behavior.available_construction_output_signal, control_behavior.total_construction_output_signal }) do
              if signal.name then
                local item_data = Search.get_item_surface_data(surface_data, signal.type, signal.name)
                SearchResults.add_entity(entity, item_data.signals)
                SearchResults.add_surface_info("signal_count", 1, item_data.surface_info)
              end
            end

            if control_behavior.read_logistics then
              local logistic_network = entity.logistic_network
              if logistic_network then
                for item_name, item_count in pairs(logistic_network.get_contents()) do
                  if item_count > 0 then
                    local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
                    SearchResults.add_entity_signal(entity, item_data.signals, item_count)
                    SearchResults.add_surface_info("signal_count", item_count, item_data.surface_info)
                  end
                end
              end
            end
          elseif entity_type == "train-stop" then
            for _, signal in pairs({ control_behavior.stopped_train_signal, control_behavior.trains_count_signal }) do
              if signal.name then
                local item_data = Search.get_item_surface_data(surface_data, signal.type, signal.name)
                SearchResults.add_entity(entity, item_data.signals)
                SearchResults.add_surface_info("signal_count", 1, item_data.surface_info)
              end
            end

            if control_behavior.read_from_train then
              local train = entity.get_stopped_train()
              if train then
                for item_name, item_count in pairs(train.get_contents()) do
                  if item_count > 0 then
                    local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
                    SearchResults.add_entity_signal(entity, item_data.signals, item_count)
                    SearchResults.add_surface_info("signal_count", item_count, item_data.surface_info)
                  end
                end
                for fluid_name, fluid_count in pairs(logistic_network.get_fluid_contents()) do
                  if fluid_count > 0 then
                    local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
                    SearchResults.add_entity_signal(entity, item_data.signals, fluid_count)
                    SearchResults.add_surface_info("signal_count", fluid_count, item_data.surface_info)
                  end
                end
              end
            end
          elseif entity_type == "accumulator" or entity_type == "wall" then
            if control_behavior.output_signal and control_behavior.output_signal.name then
              local item_data = Search.get_item_surface_data(surface_data, control_behavior.output_signal.type, control_behavior.output_signal.name)
              SearchResults.add_entity(entity, item_data.signals)
              SearchResults.add_surface_info("signal_count", 1, item_data.surface_info)
            end
          elseif entity_type == "rail-signal" then
            for _, signal in pairs({ control_behavior.red_signal, control_behavior.orange_signal, control_behavior.green_signal }) do
              local item_data = Search.get_item_surface_data(surface_data, signal.type, signal.name)
              SearchResults.add_entity(entity, item_data.signals)
              SearchResults.add_surface_info("signal_count", 1, item_data.surface_info)
            end
          elseif entity_type == "rail-chain-signal" then
            for _, signal in pairs({ control_behavior.red_signal, control_behavior.orange_signal, control_behavior.green_signal, control_behavior.blue_signal }) do
              local item_data = Search.get_item_surface_data(surface_data, signal.type, signal.name)
              SearchResults.add_entity(entity, item_data.signals)
              SearchResults.add_surface_info("signal_count", 1, item_data.surface_info)
            end
          elseif entity_type == "container" then
            local inventory = entity.get_inventory(defines.inventory.chest)
            if inventory and inventory.valid then
              for item_name, item_count in pairs(inventory.get_contents()) do
                local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
                SearchResults.add_entity_signal(entity, item_data.signals, item_count)
                SearchResults.add_surface_info("signal_count", item_count, item_data.surface_info)
              end
            end
          elseif entity_type == "logistic-container" then
            if control_behavior.circuit_mode_of_operation == defines.control_behavior.logistic_container.circuit_mode_of_operation.send_contents then
              local inventory = entity.get_inventory(defines.inventory.chest)
              if inventory and inventory.valid then
                for item_name, item_count in pairs(inventory.get_contents()) do
                  local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
                  SearchResults.add_entity_signal(entity, item_data.signals, item_count)
                  SearchResults.add_surface_info("signal_count", item_count, item_data.surface_info)
                end
              end
            end
          elseif entity_type == "inserter" then
            -- Doesn't check inserter if in pulse mode
            if control_behavior.circuit_read_hand_contents and control_behavior.circuit_hand_read_mode == defines.control_behavior.inserter.hand_read_mode.hold then
              local held_stack = entity.held_stack
              if held_stack and held_stack.valid_for_read then
                local item_data = Search.get_item_surface_data(surface_data, 'item', held_stack.name)
                SearchResults.add_entity_signal(entity, item_data.signals, held_stack.count)
                SearchResults.add_surface_info("signal_count", held_stack.count, item_data.surface_info)
              end
            end
          elseif entity_type == "storage-tank" then
            for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
              if fluid_count > 0 then
                local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
                SearchResults.add_entity_signal(entity, item_data.signals, fluid_count)
                SearchResults.add_surface_info("signal_count", fluid_count, item_data.surface_info)
              end
            end
          elseif entity_type == "mining-drill" then
            if control_behavior.circuit_read_resources then
              local resources = control_behavior.resource_read_targets
              local count = 0
              for _, resource in pairs(resources) do
                if resource.initial_amount then
                  count = count + resource.amount / 30000  -- Calculate fluid/s from amount
                else
                  count = count + resource.amount
                end
              end

              if count > 0 then
                local item_data = Search.get_item_surface_data(surface_data, 'item', resource.name)
                SearchResults.add_entity_signal(entity, item_data.signals, count)
                SearchResults.add_surface_info("signal_count", count, item_data.surface_info)
              end
            end
          end
        end
      end
    end

    -- Ingredients / Consumers
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
          local item_data = Search.get_item_surface_data(surface_data, ingredient.type, ingredient.name)
          SearchResults.add_entity_product(entity, item_data.consumers, recipe)
          SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
        end
      end

      if entity_type == "lab" then
        local inventory = entity.get_inventory(defines.inventory.lab_input)
        if inventory and inventory.valid then
          for item_name, _ in pairs(inventory.get_contents()) do
            local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
            SearchResults.add_entity(entity, item_data.consumers)
            SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
          end
        end
      end

      if entity_type == "generator" then
        for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
          if fluid_count > 0 then
            local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
            SearchResults.add_entity(entity, item_data.consumers)
            SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
          end
        end
      end

      local burner = entity.burner
      if burner then
        local currently_burning = burner.currently_burning
        if currently_burning then
          local item_data = Search.get_item_surface_data(surface_data, 'item', currently_burning.name)
          SearchResults.add_entity(entity, item_data.consumers)
          SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
        end
      end

      -- Consuming ammo
      if entity_type == "artillery-turret" or entity_type == "artillery-wagon" or entity_type == "ammo-turret" then
        for inventory_index = 1, entity.get_max_inventory_index() do
          local inventory = entity.get_inventory(inventory_index)
          if inventory and inventory.valid then
            for item_name, item_count in pairs(inventory.get_contents()) do
              local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
              SearchResults.add_entity_storage(entity, item_data.consumers, item_count)
              SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
            end
          end
        end
      elseif entity_type == "fluid-turret" then
        for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
          if fluid_count > 0 then
            local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
            SearchResults.add_entity_storage_fluid(entity, item_data.consumers, fluid_count)
            SearchResults.add_surface_info("consumers_count", 1, item_data.surface_info)
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
        if mining_target then
          local mineable_properties = mining_target.prototype.mineable_properties
          for _, product in pairs(mineable_properties.products or {}) do
            local item_data = Search.get_item_surface_data(surface_data, product.type, product.name)
            SearchResults.add_entity(entity, item_data.producers)
            SearchResults.add_surface_info("producers_count", 1, item_data.surface_info)
          end
        end
      elseif entity_type == "offshore-pump" then
        for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
          if fluid_count > 0 then
            local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
            SearchResults.add_entity(entity, item_data.producers)
            SearchResults.add_surface_info("producers_count", 1, item_data.surface_info)
          end
        end
      end
      if recipe then
        local products = recipe.products
        for _, product in pairs(products) do
          local item_data = Search.get_item_surface_data(surface_data, product.type, product.name)
          SearchResults.add_entity_product(entity, item_data.producers, recipe)
          SearchResults.add_surface_info("producers_count", 1, item_data.surface_info)
        end
      end
    end

    -- Storage
    if state.storage then
      if entity_type == "storage-tank" or entity_type == "fluid-wagon" then
        for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
          if fluid_count > 0 then
            local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
            SearchResults.add_entity_storage_fluid(entity, item_data.storage, fluid_count)
            SearchResults.add_surface_info("fluid_count", fluid_count, item_data.surface_info)
          end
        end
      elseif entity_type == "character-corpse" or item_storage_entities[entity_type] then
        for inventory_index = 1, entity.get_max_inventory_index() do
          local inventory = entity.get_inventory(inventory_index)
          if inventory and inventory.valid then
            for item_name, item_count in pairs(inventory.get_contents()) do
              local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
              SearchResults.add_entity_storage(entity, item_data.storage, item_count)
              SearchResults.add_surface_info("item_count", item_count, item_data.surface_info)
            end
          end
        end
      end
    end

    -- Entities
    if state.entities then
      local item_data = Search.get_item_surface_data(surface_data, 'item', entity.name)
      if entity_type == 'resource' then
        local amount
        if entity.initial_amount then
          amount = entity.amount / 3000  -- Calculate yield from amount
        else
          amount = entity.amount
        end
        SearchResults.add_entity_resource(entity, item_data.entities, amount)
        SearchResults.add_surface_info("resource_count", amount, item_data.surface_info)
      else
        SearchResults.add_entity(entity, item_data.entities)
        SearchResults.add_surface_info("entity_count", 1, item_data.surface_info)
      end
    end

    -- Modules
    if state.modules then
      if modules_entities[entity_type] then
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
        if inventory and inventory.valid then
          for item_name, item_count in pairs(inventory.get_contents()) do
            local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
            SearchResults.add_entity_storage(entity, item_data.modules, item_count)
            SearchResults.add_surface_info("module_count", item_count, item_data.surface_info)
          end
        end
      end
    end

    -- Requesters
    if state.requesters then
      -- Buffer and Requester chests
      if entity_type == "logistic-container" then
        for i=1, entity.request_slot_count do
          local request = entity.get_request_slot(i)
          if request and request.count then
            local item_data = Search.get_item_surface_data(surface_data, 'item', request.name)
            SearchResults.add_entity_storage(entity, item_data.requesters, request.count)
            SearchResults.add_surface_info("request_count", request.count, item_data.surface_info)
          end
        end
      elseif entity_type == "character" then
        for i=1, entity.request_slot_count do
          local request = entity.get_personal_logistic_slot(i)
          if request and request.min then
            local item_data = Search.get_item_surface_data(surface_data, 'item', request.name)
            SearchResults.add_entity_storage(entity, item_data.requesters, request.min)
            SearchResults.add_surface_info("request_count", request.min, item_data.surface_info)
          end
        end
      elseif entity_type == "spider-vehicle" then
        for i=1, entity.request_slot_count do
          local request = entity.get_vehicle_logistic_slot(i)
          if request and request.min then
            local item_data = Search.get_item_surface_data(surface_data, 'item', request.name)
            SearchResults.add_entity_storage(entity, item_data.requesters, request.min)
            SearchResults.add_surface_info("request_count", request.min, item_data.surface_info)
          end
        end
      elseif entity_type == "item-request-proxy" then
        for request_name, request_count in pairs(entity.item_requests) do
          local item_data = Search.get_item_surface_data(surface_data, 'item', request_name)
          SearchResults.add_entity_storage(entity, item_data.requesters, request_count)
          SearchResults.add_surface_info("request_count", request_count, item_data.surface_info)
        end
      end
    end

    -- Ground
    if state.ground_items then
      if entity_type == "item-entity" and entity.name == "item-on-ground" then
        local item_data = Search.get_item_surface_data(surface_data, 'item', entity.stack.name)
        SearchResults.add_entity(entity, item_data.ground_items)
        SearchResults.add_surface_info("ground_count", 1, item_data.surface_info)
      end
    end

    -- Logistics
    if state.logistics then
      if item_logistic_entities[entity_type] then
        if entity_type == "inserter" then
          local held_stack = entity.held_stack
          if held_stack and held_stack.valid_for_read then
            local item_data = Search.get_item_surface_data(surface_data, 'item', held_stack.name)
            SearchResults.add_entity_storage(entity, item_data.logistics, held_stack.count)
            SearchResults.add_surface_info("item_count", held_stack.count, item_data.surface_info)
          end
        else
          for inventory_index = 1, entity.get_max_inventory_index() do
            local inventory = entity.get_inventory(inventory_index)
            if inventory and inventory.valid then
              for item_name, item_count in pairs(inventory.get_contents()) do
                local item_data = Search.get_item_surface_data(surface_data, 'item', item_name)
                SearchResults.add_entity_storage(entity, item_data.logistics, item_count)
                SearchResults.add_surface_info("item_count", item_count, item_data.surface_info)
              end
            end
          end
        end
      elseif fluid_logistic_entities[entity_type] then
        for fluid_name, fluid_count in pairs(entity.get_fluid_contents()) do
          if fluid_count > 0 then
            local item_data = Search.get_item_surface_data(surface_data, 'fluid', fluid_name)
            SearchResults.add_entity_storage_fluid(entity, item_data.logistics, fluid_count)
            SearchResults.add_surface_info("fluid_count", fluid_count, item_data.surface_info)
          end
        end
      end
    end
    ::continue::
  end
end


---@param surface_data SurfaceSearchResult
---@param target_type string
---@param target_name string
function Search.get_item_surface_data(surface_data, target_type, target_name)
  surface_data[target_type] = surface_data[target_type] or {}
  surface_data[target_type][target_name] = surface_data[target_type][target_name] or table.deepcopy(default_surface_data)
  return surface_data[target_type][target_name]
end

function Search.on_tick()
  local player_index, search_data = next(global.current_searches)
  if not search_data then return end

  --- @type LuaSurface
  local current_surface = search_data.current_surface
  if not current_surface or not current_surface.valid then
    -- Start next surface

    --- @type LuaSurface
    current_surface = table.remove(search_data.not_started_surfaces)
    if not current_surface then
      -- All surfaces are complete
      global.finished_searches[player_index] = search_data.data
      global.current_searches[player_index] = nil
      Gui.build_results(search_data.data, player_index)
      return
    end

    if not current_surface.valid then return end  -- Will try another surface next tick

    -- Setup next surface data
    search_data.current_surface = current_surface
    search_data.surface_data = {}
    search_data.chunk_iterator = current_surface.get_chunks()

    return  -- Start next surface processing on next tick
  end

  local chunk_iterator = search_data.chunk_iterator
  if not chunk_iterator.valid then
    search_data.current_surface = nil
    return
  end

  --- @type LuaForce
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

    --- @type SearchState
    local state = search_data.state
    --- @type SurfaceSearchResult
    local surface_data = search_data.surface_data

    local chunk_area = chunk.area

    local entities = {}
    if state.entities then
      entities = current_surface.find_entities_filtered{
        area = chunk_area,
        force = {force, 'neutral'},
      }
    else
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
    end

    for i, entity in pairs(entities) do
      if not math2d.bounding_box.contains_point(chunk_area, entity.position) then
        entities[i] = nil
      end
    end

    Search.process_found_entities(entities, state, surface_data, force)

    -- Map tags
    if state.map_tags then
      local tags = force.find_chart_tags(current_surface.name, chunk_area)
      for _, tag in pairs(tags) do
        local tag_icon = tag.icon
        if tag_icon then
          local item_data = Search.get_item_surface_data(surface_data, tag_icon.type, tag_icon.name)
          SearchResults.add_tag(tag, item_data.map_tags)
          SearchResults.add_surface_info("tag_count", 1, item_data.surface_info)
        end
      end
    end
    ::continue::
  end
end
event.on_tick(Search.on_tick)


---@param force LuaForce
---@param state SearchState
---@param player LuaPlayer
---@param override_surface any
---@param immediate any
---@return boolean
function Search.find_machines(force, state, player, override_surface, immediate)
  local entity_types = {}
  local neutral_entity_types = {}
  if state.consumers then
    add_entity_type(entity_types, ingredient_entities)
    add_entity_type(entity_types, item_ammo_ingredient_entities)
    add_entity_type(entity_types, fluid_ammo_ingredient_entities)
  end
  if state.producers then
    add_entity_type(entity_types, product_entities)
  end
  if state.storage then
    add_entity_type(entity_types, item_storage_entities)
    add_entity_type(neutral_entity_types, neutral_item_storage_entities)
  end
  if state.storage then
    add_entity_type(entity_types, fluid_storage_entities)
  end
  if state.requesters then
    add_entity_type(entity_types, request_entities)
  end
  if state.modules then
    add_entity_type(entity_types, modules_entities)
  end
  if state.logistics then
    add_entity_type(entity_types, item_logistic_entities)
  end
  if state.logistics then
    add_entity_type(entity_types, fluid_logistic_entities)
  end
  if state.ground_items then
    add_entity_type(neutral_entity_types, ground_entities)
  end
  if state.signals then
    add_entity_type(entity_types, signal_entities)
  end
  local type_list = map_to_list(entity_types)
  local neutral_type_list = map_to_list(neutral_entity_types)

  local surface_list = filtered_surfaces(override_surface, player.surface)

  global.finished_searches[player.index] = nil
  global.current_searches[player.index] = {
    tick_triggered = game.tick - (immediate and DEBOUNCE_TICKS or 0),
    force = force,
    state = state,
    type_list = type_list,
    neutral_type_list = neutral_type_list,
    player = player,
    data = {},
    not_started_surfaces = surface_list,
    completed_surfaces = {}
  }
  return true
end

return Search