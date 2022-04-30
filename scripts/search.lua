math2d = require "__core__.lualib.math2d"
search_signals = require "__FactorySearch__.scripts.search-signals"

local group_gap_size = 16


local function concat(t1,t2)
  local new_table = {}
  local t1_len = #t1
  local t2_len = #t2

  for i=1, t1_len do
      new_table[i] = t1[i]
  end
  for i=1, t2_len do
    new_table[t1_len + i] = t2[i]
  end
  return new_table
end

local function extend(t1, t2)
  local t1_len = #t1
  local t2_len = #t2
  for i=1, t2_len do
    t1[t1_len + i] = t2[i]
  end
end

-- "character-corpse" doesn't have force so must be checked seperately
local product_entities = {"assembling-machine", "furnace", "offshore-pump", "mining-drill"}
local inventory_entities = {"container", "logistic-container", "linked-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle"}  -- get_item_count
local fluid_entities = {"storage-tank", "fluid-wagon"}
local product_and_inventory_entities = concat(product_entities, inventory_entities)
local product_and_fluid_entities = concat(product_entities, fluid_entities)

-- lookup tree in order: include_products, include_inventories, item_type
local entity_table = {
  [true] = {
    [true] = {
      item = product_and_inventory_entities,
      fluid = product_and_fluid_entities,
    },
    [false] = {
      item = product_entities,
      fluid = product_entities,
    }
  },
  [false] = {
    [true] = {
      item = inventory_entities,
      fluid = fluid_entities,
    },
    [false] = {
      item = {},
      fluid = {},
    }
  }
}
local function entity_types(item_type, state)
  return entity_table[state.producers][state.storage][item_type]
end

local function filtered_surfaces()
  -- Skip certain modded surfaces that won't have assemblers/chests placed on them
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do
    local surface_name = surface.name
    if string.sub(surface_name, -12) ~= "-transformer"  -- Power Overload
        and string.sub(surface_name, 0, 8) ~= "starmap-"  -- Space Exploration
        and surface_name ~= "aai-signals"  -- AAI Signals
      then
      table.insert(surfaces, surface)
    end
  end
  return surfaces
end


function add_entity(entity, surface_data)
  -- Group entities
  -- Group contains count, avg_position, selection_box, entity_name, entities
  local entity_name = entity.name
  local entity_position = entity.position
  local entity_selection_box = entity.selection_box
  local entity_surface_data = surface_data[entity_name] or {}
  local assigned_group
  for _, group in pairs(entity_surface_data) do
    if entity_name == group.entity_name and math2d.bounding_box.collides_with(entity_selection_box, group.selection_box) then
      -- Add entity to group
      assigned_group = group
      local count = group.count
      local new_count = count + 1
      group.avg_position = {
        x = (group.avg_position.x * count + entity_position.x) / new_count,
        y = (group.avg_position.y * count + entity_position.y) / new_count,
      }
      group.selection_box = {
        left_top = {
          x = math.min(group.selection_box.left_top.x + group_gap_size, entity_selection_box.left_top.x) - group_gap_size,
          y = math.min(group.selection_box.left_top.y + group_gap_size, entity_selection_box.left_top.y) - group_gap_size,
        },
        right_bottom = {
          x = math.max(group.selection_box.right_bottom.x - group_gap_size, entity_selection_box.right_bottom.x) + group_gap_size,
          y = math.max(group.selection_box.right_bottom.y - group_gap_size, entity_selection_box.right_bottom.y) + group_gap_size,
        },
      }
      group.count = new_count
      table.insert(group.entities, entity)
      break
    end
  end
  if not assigned_group then
    -- Create new group
    assigned_group = {
      count = 1,
      avg_position = entity_position,
      selection_box = {
        left_top = {
          x = entity_selection_box.left_top.x - group_gap_size,
          y = entity_selection_box.left_top.y - group_gap_size,
        },
        right_bottom = {
          x = entity_selection_box.right_bottom.x + group_gap_size,
          y = entity_selection_box.right_bottom.y + group_gap_size,
        }
      },
      entity_name = entity_name,
      entities = {entity},
      localised_name = entity.localised_name,
    }
    table.insert(entity_surface_data, assigned_group)
  end
  surface_data[entity_name] = entity_surface_data
  return assigned_group
end

local function add_entity_product(entity, surface_data, recipe)
  local group = add_entity(entity, surface_data)
  local group_recipe_list = group.recipe_list or {}
  recipe_name_info = group_recipe_list[recipe.name] or {localised_name = recipe.localised_name, count = 0}
  recipe_name_info.count = recipe_name_info.count + 1
  group_recipe_list[recipe.name] = recipe_name_info
  group.recipe_list = group_recipe_list
end

local function add_entity_storage(entity, surface_data, item_count)
  local group = add_entity(entity, surface_data)
  local group_item_count = group.item_count or 0
  group.item_count = group_item_count + item_count
end

local function add_entity_storage_fluid(entity, surface_data, fluid_count)
  local group = add_entity(entity, surface_data)
  local group_fluid_count = group.fluid_count or 0
  group.fluid_count = group_fluid_count + fluid_count
end

local function add_entity_request(entity, surface_data, request_count)
  local group = add_entity(entity, surface_data)
  local group_request_count = group.request_count or 0
  group.request_count = group_request_count + request_count
end

function add_entity_signal(entity, surface_data, signal_count)
  local group = add_entity(entity, surface_data)
  local group_signal_count = group.signal_count or 0
  group.signal_count = group_signal_count + signal_count
end


function find_machines(target_item, force, state)
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

  for _, surface in pairs(filtered_surfaces()) do
    local surface_data = { producers = {}, storage = {}, logistics = {}, requesters = {}, ground_items = {}, entities = {}, signals = {} }

    -- Signals
    if state.signals then
      search_signals(target_item, force, surface, surface_data)
      if target_is_virtual then
        goto continue
      end
    end

    -- Producers and Storage
    if (state.producers or state.storage) then
      local entities = surface.find_entities_filtered{
        type = entity_types(target_item.type, state),
        force = force,
      }
      if state.storage and target_is_item then
        -- Corpses don't have a force
        local corpses = surface.find_entities_filtered{
          type = "character-corpse",
        }
        extend(entities, corpses)
      end

      for _, entity in pairs(entities) do
        local recipe
        local entity_type = entity.type
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
            add_entity(entity, surface_data.producers)
          end
        elseif target_is_fluid and entity_type == "offshore-pump" then
          if entity.get_fluid_count(target_name) > 0 then
            add_entity(entity, surface_data.producers)
          end
        elseif target_is_fluid and (entity_type == "storage-tank" or entity_type == "fluid-wagon") then
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            add_entity_storage_fluid(entity, surface_data.storage, fluid_count)
          end
        elseif target_is_item then
          -- Entity is an inventory entity
          local item_count = entity.get_item_count(target_name)
          if item_count > 0 then
            add_entity_storage(entity, surface_data.storage, item_count)
          end
        end
        if recipe then
          local products = recipe.products
          for _, product in pairs(products) do
            local name = product.name
            if name == target_name then
              add_entity_product(entity, surface_data.producers, recipe)
            end
          end
        end
      end
    end

    -- Requesters
    if target_is_item and state.requesters then
      local entities = surface.find_entities_filtered{
        type = { "logistic-container", "character", "spider-vehicle", "item-request-proxy" } ,
        force = force,
      }
      for _, entity in pairs(entities) do
        -- Buffer and Requester chests
        if entity.type == "logistic-container" then
          for i=1, entity.request_slot_count do
            local request = entity.get_request_slot(i)
            if request and request.name == target_name then
              local count = request.count
              if count then
                add_entity_request(entity, surface_data.requesters, count)
              end
            end
          end
        elseif entity.type == "character" then
          for i=1, entity.request_slot_count do
            local request = entity.get_personal_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        elseif entity.type == "spider-vehicle" then
          for i=1, entity.request_slot_count do
            local request = entity.get_vehicle_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        else
          local request_count = entity.item_requests[target_name]
          if request_count ~= nil then
            add_entity_request(entity.proxy_target, surface_data.requesters, request_count)
          end
        end
      end
    end

    -- Ground
    if target_is_item and state.ground_items then
      local entities = surface.find_entities_filtered{
        type = "item-entity",
        name = "item-on-ground",
      }
      for _, entity in pairs(entities) do
        if entity.stack.name == target_name then
          add_entity(entity, surface_data.ground_items)
        end
      end
    end

    -- Logistics
    if state.logistics then
      if target_is_item then
        local entities = surface.find_entities_filtered{
          type = { "transport-belt", "splitter", "underground-belt", "inserter", "logistic-robot", "construction-robot" },
          force = force,
        }
        for _, entity in pairs(entities) do
          if entity.type == "inserter" then
            local held_stack = entity.held_stack
            if held_stack and held_stack.valid_for_read and held_stack.name == target_name then
              add_entity_storage(entity, surface_data.logistics, held_stack.count)
            end
          else
            local item_count = entity.get_item_count(target_name)
            if item_count > 0 then
              add_entity_storage(entity, surface_data.logistics, item_count)
            end
          end
        end
      else
        -- So target.type == "fluid"
        local entities = surface.find_entities_filtered{
          type = { "pipe", "pipe-to-ground", "pump" },
          force = force,
        }
        for _, entity in pairs(entities) do
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            add_entity_storage_fluid(entity, surface_data.logistics, fluid_count)
          end
        end
      end
    end

    -- Entities
    if target_is_item and state.entities then
      local item_prototype = game.item_prototypes[target_name]
      local target_entity_name = target_name
      if item_prototype.place_result then
        target_entity_name = item_prototype.place_result.name
      end
      local entities = surface.find_entities_filtered{
        name = target_entity_name,
        force = force,
      }
      for _, entity in pairs(entities) do
        add_entity(entity, surface_data.entities)
      end
    end
    ::continue::
    data[surface.name] = surface_data
  end
  return data
end
