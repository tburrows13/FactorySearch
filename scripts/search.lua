math2d = require "__core__.lualib.math2d"

local group_gap_size = 16

function find_machines(target_item, force)
  local data = {}
  for _, surface in pairs(game.surfaces) do
    -- TODO filter surfaces to avoid 'fake' ones ('-transformer')
    surface_data = {}
    entities = surface.find_entities_filtered{
      type = {"assembling-machine", "furnace"},
      force = force,
      to_be_deconstructed = false,
    }
    for _, entity in pairs(entities) do
      local recipe = entity.get_recipe()
      if not recipe and entity.type == "furnace" then
        -- If the furnace has stopped smelting, this records the last item it was smelting
        recipe = entity.previous_recipe
      end
      if recipe then
        local products = recipe.products
        for _, product in pairs(products) do
          local name = product.name
          if name == target_item then
            -- Group entities
            -- Group contains count, avg_position, bounding_box, entity_name, entities
            local entity_name = entity.name
            local entity_position = entity.position
            local entity_bounding_box = entity.bounding_box
            local assigned_to_group = false
            for _, group in pairs(surface_data) do
              if entity_name == group.entity_name and math2d.bounding_box.collides_with(entity_bounding_box, group.bounding_box) then
                -- Add entity to group
                assigned_to_group = true
                count = group.count
                new_count = count + 1
                group.avg_position = {
                  x = (group.avg_position.x * count + entity_position.x) / new_count,
                  y = (group.avg_position.y * count + entity_position.y) / new_count,
                }
                group.bounding_box = {
                  left_top = {
                    x = math.min(group.bounding_box.left_top.x + group_gap_size, entity_bounding_box.left_top.x) - group_gap_size,
                    y = math.min(group.bounding_box.left_top.y + group_gap_size, entity_bounding_box.left_top.y) - group_gap_size,
                  },
                  right_bottom = {
                    x = math.max(group.bounding_box.right_bottom.x - group_gap_size, entity_bounding_box.right_bottom.x) + group_gap_size,
                    y = math.max(group.bounding_box.right_bottom.y - group_gap_size, entity_bounding_box.right_bottom.y) + group_gap_size,
                  },
                }
                group.count = new_count
                table.insert(group.entities, entity)
                break
              end
            end
            if not assigned_to_group then
              -- Create new group
              table.insert(surface_data, {
                count = 1,
                avg_position = entity_position,
                bounding_box = {
                  left_top = {
                    x = entity_bounding_box.left_top.x - group_gap_size,
                    y = entity_bounding_box.left_top.y - group_gap_size,
                  },
                  right_bottom = {
                    x = entity_bounding_box.right_bottom.x + group_gap_size,
                    y = entity_bounding_box.right_bottom.y + group_gap_size,
                  }
                },
                entity_name = entity_name,
                entities = {entity},
              })
            end
          end
        end
      end
    end
    data[surface.name] = surface_data
  end
  return data
end
