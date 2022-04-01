event = require "scripts.event"
search = require "scripts.search"
local ui = require "scripts.ui"

-- on_entity_settings_pasted, on_gui_closed, on_built_entity

--[[
-- WIP
local function generate_data()
  local data = {}
  for _, force in pairs(game.forces) do
    data[force.index] = {}
  end
  for _, surface in pairs(game.surfaces) do
    for _, force_data in pairs(data) do
      force_data[surface.index] = {}
    end
    entities = surface.find_entities_filtered{
      type = "assembling-machine",
      to_be_deconstructed = false,
    }
    for _, entity in pairs(entities) do
      local recipe = entity.get_recipe()
      if recipe then
        local products = recipe.products
        for _, product in pairs(products) do
          local name = product.name
          existing_data = data[entity.force][surface.index][name] or {}
          table.insert(existing_data, entity)
        end
      end
    end
  end
end

--[[
local function on_update_recipe(entity)
  game.print("Updating recipe")
  if entity and entity.type == "assembling-machine" then
    local recipe = entity.get_recipe()
    if recipe then
      local recipe_table = global.recipes[entity.force.index][entity.surface.index]
      local products = recipe.products
      for _, product in pairs(products) do
        recipe_table[product.name] = entity
      end
    end
  end
end

script.on_event(defines.events.on_entity_settings_pasted,
  function(event)
    game.print("Pasted settings: ")
    on_update_recipe(event.destination)
    -- Remove old?
  end
)

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built},
  function(event)
    game.print("Built entity: ")
    on_update_recipe(event.created_entity or event.entity)
  end
)
]]

event.on_gui_closed(function(event)
  ui.on_gui_closed(event)
  --game.print("Gui closed: ")
  --on_update_recipe(event.entity)
  -- Remove old?
end)
--[[
script.on_event({defines.events.on_pre_build},
  function(event)
    game.print("Pre build: ")
    local player = game.get_player(event.player_index)
    local cursor = player.cursor_stack
    game.print("hello")
  end
)

]]
script.on_init(
  function()
    --[[global.recipes = {}
    for _, force in pairs(game.forces) do
      local surface_table = {}
      for _, surface in pairs(game.surfaces) do
        surface_table[surface.index] = {}
      end
      global.recipes[force.index] = surface_table
    end]]
    global.players = {}
  end
)

--[[
script.on_event(defines.events.on_force_created,
  function(event)
    local surface_table = {}
    for _, surface in pairs(game.surfaces) do
      surface_table[surface.index] = {}
    end
    global.recipes[event.force.index] = surface_table
  end
)

-- todo force merged

script.on_event(defines.events.on_surface_created,
  function(event)
    for _, surface_table in pairs(global.recipes) do
      surface_table[event.surface_index] = {}
    end
  end
)

-- todo other surface events
]]