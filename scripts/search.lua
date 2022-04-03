math2d = require "__core__.lualib.math2d"

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
local inventory_entities = {"container", "logistic-container", "roboport", "character", "car", "artillery-wagon", "cargo-wagon", "spider-vehicle"}  -- get_item_count
local fluid_entities = {"storage-tank", "fluid-wagon"}  -- get_fluid_count(fluid_name)
local product_and_inventory_entities = concat(product_entities, inventory_entities)
local product_and_fluid_entities = concat(product_entities, fluid_entities)

-- mining? entity.mining_target.name == "copper-ore", "crude-oil"

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
local function entity_types(item_type, include_products, include_inventories)
  return entity_table[include_products][include_inventories][item_type]
end

local function filtered_surfaces()
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do
    local surface_name = surface.name
    if string.sub(surface_name, -12) ~= "-transformer"  -- Power Overload
        and string.sub(surface_name, 0, 8) ~= "starmap-"  -- Space Exploration
        and string.sub(surface_name, 0, 6) ~= "Vault "    -- Space Exploration
        and surface_name ~= "beltlayer"  -- Beltlayer
        and surface_name ~= "pipelayer"  -- Pipelayer
      then
      table.insert(surfaces, surface)
    end
  end
  return surfaces
end


local function add_entity(entity, surface_data)
  -- Group entities
  -- Group contains count, avg_position, selection_box, entity_name, entities
  local entity_name = entity.name
  local entity_position = entity.position
  local entity_selection_box = entity.selection_box
  local entity_surface_data = surface_data[entity_name] or {}
  local assigned_to_group = false
  for _, group in pairs(entity_surface_data) do
    if entity_name == group.entity_name and math2d.bounding_box.collides_with(entity_selection_box, group.selection_box) then
      -- Add entity to group
      assigned_to_group = true
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
  if not assigned_to_group then
    -- Create new group
    table.insert(entity_surface_data, {
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
    })
  end
  surface_data[entity_name] = entity_surface_data
end

function find_machines(target_item, force, search_products, search_inventories)
  local data = {}
  if target_item.type == "virtual" or not (search_products or search_inventories) then
    return {{}}
  end
  for _, surface in pairs(filtered_surfaces()) do
    -- TODO filter surfaces to avoid 'fake' ones ('-transformer')
    local surface_data = {producers = {}, storage = {},}
    local entities = surface.find_entities_filtered{
      type = entity_types(target_item.type, search_products, search_inventories),
      force = force,
      to_be_deconstructed = false,
    }
    if search_inventories and target_item.type == "item" then
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
        -- Even if the furnace has stopped smelting, this records the last item it was smelting
        recipe = entity.previous_recipe
      elseif entity_type == "mining-drill" then
        local mining_target = entity.mining_target
        if mining_target and mining_target.name == target_item.name then
          add_entity(entity, surface_data.producers)
        end
      elseif target_item.type == "fluid" and entity_type == "offshore-pump" then
        if entity.get_fluid_count(target_item.name) > 0 then
          add_entity(entity, surface_data.producers)
        end
      elseif target_item.type == "fluid" and (entity_type == "storage-tank" or entity_type == "fluid-wagon") then
        if entity.get_fluid_count(target_item.name) > 0 then
          add_entity(entity, surface_data.storage)
        end
      elseif target_item.type == "item" then
        -- Entity is an inventory entity
        if entity.get_item_count(target_item.name) > 0 then
          add_entity(entity, surface_data.storage)
        end
      end
      if recipe then
        local products = recipe.products
        for _, product in pairs(products) do
          local name = product.name
          if name == target_item.name then
            add_entity(entity, surface_data.producers)
          end
        end
      end
    end
    data[surface.name] = surface_data
  end
  return data
end
