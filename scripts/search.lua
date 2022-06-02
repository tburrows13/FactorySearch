math2d = require "__core__.lualib.math2d"
search_signals = require "__FactorySearch__.scripts.search-signals"

local group_gap_size = 16

local function extend(t1, t2)
  local t1_len = #t1
  local t2_len = #t2
  for i=1, t2_len do
    t1[t1_len + i] = t2[i]
  end
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
}

local list_to_map = util.list_to_map
-- "character-corpse" doesn't have force so must be checked seperately
local product_entities = list_to_map{ "assembling-machine", "furnace", "offshore-pump", "mining-drill" }
local item_storage_entities = list_to_map{ "container", "logistic-container", "linked-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle" }
local fluid_storage_entities = list_to_map{ "storage-tank", "fluid-wagon" }
local modules_entities = list_to_map{ "assembling-machine", "furnace", "rocket-silo", "mining-drill", "lab", "beacon" }
local request_entities = list_to_map{ "logistic-container", "character", "spider-vehicle", "item-request-proxy" }
local item_logistic_entities = list_to_map{ "transport-belt", "splitter", "underground-belt", "inserter", "logistic-robot", "construction-robot" }
local fluid_logistic_entities = list_to_map{ "pipe", "pipe-to-ground", "pump" }
local ground_entities = list_to_map{ "item-entity" }
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

local function filtered_surfaces(override_surface)
  if override_surface then
    return {override_surface}
  end

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

local function add_entity_module(entity, surface_data, module_count)
  local group = add_entity(entity, surface_data)
  local group_module_count = group.module_count or 0
  group.module_count = group_module_count + module_count
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

function add_tag(tag, surface_data)
  -- An alternative to add_entity*, for map tags
  local icon_name = tag.icon.name
  local tag_surface_data = surface_data[icon_name] or {}

  -- Tag groups always have size 1
  local tag_position = tag.position
  local tag_box_size = 8
  local selection_box = {
    left_top = {
      x = tag_position.x - tag_box_size,
      y = tag_position.y - tag_box_size,
    },
    right_bottom = {
      x = tag_position.x + tag_box_size,
      y = tag_position.y + tag_box_size,
    }
  }

  local localised_name = tag.text
  if localised_name == "" then localised_name = { "search-gui.default-map-tag-name" } end

  local group = {
    count = 1,
    avg_position = tag_position,
    entity_name = tag.icon.name,
    entities = {{  -- Mock LuaEntity object, which only has its selection box attribute accessed by ui.lua
      selection_box = selection_box
    }},
    localised_name = localised_name,
  }
  table.insert(tag_surface_data, group)

  surface_data[icon_name] = tag_surface_data
end

function find_machines(target_item, force, state, override_surface)
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

  for _, surface in pairs(filtered_surfaces(override_surface)) do
    local surface_data = { producers = {}, storage = {}, logistics = {}, modules = {}, requesters = {}, ground_items = {}, entities = {}, signals = {}, map_tags = {} }

    local entity_types = {}
    if (target_is_item or target_is_fluid) and state.producers then
      add_entity_type(entity_types, product_entities)
    end
    if target_is_item and state.storage then
      add_entity_type(entity_types, item_storage_entities)
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
      add_entity_type(entity_types, ground_entities)
    end
    if state.signals then
      add_entity_type(entity_types, signal_entities)
    end

    local type_list = map_to_list(entity_types)
    local entities = surface.find_entities_filtered{
      type = type_list,
      force = force,
    }

    -- Corpses don't have a force: find seperately
    if state.storage and target_is_item then
      local corpses = surface.find_entities_filtered{
        type = "character-corpse",
      }
      extend(entities, corpses)
    end

    for _, entity in pairs(entities) do
      local entity_type = entity.type

      -- Signals
      if state.signals then
        if signal_entities[entity_type] then
          search_signals(entity, target_item, surface_data)
        end
      end
      if target_is_virtual then
        -- We've done all processing that there is to be done on virtual signals
        goto continue
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
            add_entity(entity, surface_data.producers)
          end
        elseif target_is_fluid and entity_type == "offshore-pump" then
          if entity.get_fluid_count(target_name) > 0 then
            add_entity(entity, surface_data.producers)
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

      -- Storage
      if state.storage then
        if target_is_fluid and (entity_type == "storage-tank" or entity_type == "fluid-wagon") then
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            add_entity_storage_fluid(entity, surface_data.storage, fluid_count)
          end
        elseif entity_type == "character-corpse" or item_storage_entities[entity_type] then
          -- Entity is an inventory entity
          local item_count = entity.get_item_count(target_name)
          if item_count > 0 then
            add_entity_storage(entity, surface_data.storage, item_count)
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
              add_entity_module(entity, surface_data.modules, item_count)
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
                add_entity_request(entity, surface_data.requesters, count)
              end
            end
          end
        elseif entity_type == "character" then
          for i=1, entity.request_slot_count do
            local request = entity.get_personal_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        elseif entity_type == "spider-vehicle" then
          for i=1, entity.request_slot_count do
            local request = entity.get_vehicle_logistic_slot(i)
            if request and request.name == target_name then
              local count = request.min
              if count and count > 0 then
                add_entity_request(entity, surface_data.requesters, request.min)
              end
            end
          end
        elseif entity_type == "item-request-proxy" then
          local request_count = entity.item_requests[target_name]
          if request_count ~= nil then
            add_entity_request(entity.proxy_target, surface_data.requesters, request_count)
          end
        end
      end

      -- Ground
      if target_is_item and state.ground_items then
        if entity_type == "item-entity" and entity.name == "item-on-ground" then
          if entity.stack.name == target_name then
            add_entity(entity, surface_data.ground_items)
          end
        end
      end

      -- Logistics
      if state.logistics then
        if item_logistic_entities[entity_type] then
          if entity_type == "inserter" then
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
        elseif fluid_logistic_entities[entity_type] then
          -- So target.type == "fluid"
          local fluid_count = entity.get_fluid_count(target_name)
          if fluid_count > 0 then
            add_entity_storage_fluid(entity, surface_data.logistics, fluid_count)
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
          add_tag(tag, surface_data.map_tags)
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
        force = force,
      }
      for _, entity in pairs(entities) do
        add_entity(entity, surface_data.entities)
      end
    end
    data[surface.name] = surface_data
  end
  return data
end
