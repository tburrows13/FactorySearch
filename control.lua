---@type event_handler_lib
event_handler = require "event_handler"
util = require "util"

gui = require "scripts.flib-gui"
CustomInput = require "scripts.custom-input"
Search = require "scripts.search"
SearchResults = require "scripts.search-results"
ResultLocation = require "scripts.result-location"
SearchGui = require "scripts.search-gui"
require "scripts.remote"

---@class (exact) SearchGuiRefs
---@field frame LuaGuiElement frame
---@field pin_button LuaGuiElement sprite-button
---@field close_button LuaGuiElement sprite-button
---@field subheader_title LuaGuiElement label
---@field all_surfaces LuaGuiElement checkbox
---@field all_qualities LuaGuiElement checkbox
---@field item_select LuaGuiElement choose-elem-button
---@field include_consumers LuaGuiElement checkbox
---@field include_machines LuaGuiElement checkbox
---@field include_inventories LuaGuiElement checkbox
---@field include_logistics LuaGuiElement checkbox
---@field include_modules LuaGuiElement checkbox
---@field include_entities LuaGuiElement checkbox
---@field include_ground_items LuaGuiElement checkbox
---@field include_requesters LuaGuiElement checkbox
---@field include_signals LuaGuiElement checkbox
---@field include_map_tags LuaGuiElement checkbox
---@field result_flow LuaGuiElement flow
---@field highlighted_button? LuaGuiElement sprite-button

---@class (exact) PlayerData
---@field refs SearchGuiRefs
---@field pinned? boolean
---@field ignore_close? boolean

---@class (exact) SearchGuiState
---@field consumers boolean
---@field producers boolean
---@field storage boolean
---@field logistics boolean
---@field modules boolean
---@field requesters boolean
---@field ground_items boolean
---@field entities boolean
---@field signals boolean
---@field map_tags boolean

---@class (exact) CurrentSurfaceSearchData
---@field surface LuaSurface
---@field surface_data SurfaceData
---@field surface_statistics SurfaceStatistics
---@field chunk_iterator LuaChunkIterator

---@class (exact) SearchData
---@field blocking boolean
---@field tick_triggered GameTick
---@field force LuaForce
---@field state SearchGuiState
---@field target_item SignalID
---@field type_list string[]
---@field neutral_type_list string[]
---@field player LuaPlayer
---@field data table<SurfaceName, SurfaceData>
---@field statistics table<SurfaceName, SurfaceStatistics>
---@field not_started_surfaces LuaSurface[]
---@field search_complete boolean
---@field current_surface_search_data? CurrentSurfaceSearchData Used for non-blocking searches

---@class (exact) EntityGroup
---@field count number
---@field avg_position MapPosition
---@field selection_box BoundingBox
---@field entity_name EntityName
---@field selection_boxes BoundingBox[]
---@field localised_name LocalisedString
---@field recipe_list? table<string, {localised_name: LocalisedString, count: number}>
---@field item_count? number
---@field fluid_count? number
---@field module_count? number
---@field request_count? number
---@field signal_count? number
---@field resource_count? number
---@field distance? number

---@alias EntitySurfaceData EntityGroup[]

---@alias EntityName string
---@alias CategorisedSurfaceData table<EntityName, EntitySurfaceData>

---@alias SurfaceDataCategoryName "consumers"|"producers"|"storage"|"logistics"|"modules"|"requesters"|"ground_items"|"entities"|"signals"|"map_tags"
---@alias SurfaceData table<SurfaceDataCategoryName, CategorisedSurfaceData>

---@alias SurfaceStatisticsCategoryName "consumers_count"|"producers_count"|"item_count"|"fluid_count"|"module_count"|"entity_count"|"resource_count"|"ground_count"|"request_count"|"signal_count"|"tag_count"
---@alias SurfaceStatistics table <SurfaceStatisticsCategoryName, number>

---@class ResultLocationData
---@field position MapPosition
---@field surface SurfaceName
---@field selection_boxes BoundingBox[]

DEBOUNCE_TICKS = 60

Control = {}

---@return LuaSurface[]
function filtered_surfaces()
  -- Skip certain modded surfaces that won't have assemblers/chests placed on them
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do
    local surface_name = surface.name
    if string.sub(surface_name, -12) ~= "-transformer"  -- Power Overload
        and string.sub(surface_name, 1, 17) ~= "nullius-landfill-"  -- Nullius
        and string.sub(surface_name, 0, 8) ~= "starmap-"  -- Space Exploration
        and string.sub(surface_name, 0, 15) ~= "EE_TESTSURFACE_"  -- Editor Extensions
        and string.sub(surface_name, 0, 10) ~= "BPL_TheLab"  -- Blueprint Designer Lab
        and string.sub(surface_name, 0, 9) ~= "bpsb-lab-"  -- Blueprint Sandboxes
        and surface.name ~= "IR-limbo"  -- Industrial Revolution 2/3
        and surface_name ~= "aai-signals"  -- AAI Signals
        and surface_name ~= "secret_companion_surface_please_dont_touch"  -- Companion Drones
      then
      table.insert(surfaces, surface)
    end
  end
  return surfaces
end

local function update_surface_count()
  -- Hides 'All surfaces' button
  local multiple_surfaces = #filtered_surfaces() > 1

  if multiple_surfaces ~= storage.multiple_surfaces then
    for _, player_data in pairs(storage.players) do
      local all_surfaces = player_data.refs.all_surfaces
      all_surfaces.visible = multiple_surfaces
    end
  end

  storage.multiple_surfaces = multiple_surfaces
end

local function generate_item_to_entity_table()
  -- Make map of {item_name -> list[entity_name]}
  -- First try items_to_place_this, then mineable_properties
  -- Exception in mineable_properties is we don't want to include entity_name when type == "simple-entity" if item_name is a resource
  -- This prevents things like rocks showing when searching for stone

  local resource_prototypes = prototypes.get_entity_filtered({{filter = "type", type = "resource"}})
  local is_resource = {}
  for _, resource in pairs(resource_prototypes) do
    is_resource[resource.name] = true
  end


  local prototypes = prototypes.get_entity_filtered({})
  -- Filter out rocks
  local item_to_entities = {}
  for _, prototype in pairs(prototypes) do
    local items_to_place_this = prototype.items_to_place_this
    if items_to_place_this then
      for _, item in pairs(items_to_place_this) do
        local item_name = item.name
        local associated_entities = item_to_entities[item_name] or {}
        table.insert(associated_entities, prototype.name)
        item_to_entities[item_name] = associated_entities
      end
    else
      local properties = prototype.mineable_properties
      if properties.minable and properties.products then
        for _, item in pairs(prototype.mineable_properties.products) do
          local item_name = item.name
          if prototype.type ~= "simple-entity" or not is_resource[item_name] then
            local associated_entities = item_to_entities[item_name] or {}
            table.insert(associated_entities, prototype.name)
            item_to_entities[item_name] = associated_entities
          end
        end
      end
    end
  end

  -- Hardcode some Pyanodons associations
  if script.active_mods["pypetroleumhandling"] then
    --  or {} in case something removed those items or playing an older version of Py
    table.insert(item_to_entities["raw-gas"] or {}, "bitumen-seep")
    table.insert(item_to_entities["tar"] or {}, "bitumen-seep")
    table.insert(item_to_entities["crude-oil"] or {}, "bitumen-seep")
  end

  storage.item_to_entities = item_to_entities
end

local function on_init()
  ---@type table<PlayerIndex, PlayerData>
  storage.players = {}
  ---@type table<PlayerIndex, SearchData>
  storage.current_searches = {}
  ---@type boolean
  storage.multiple_surfaces = false
  update_surface_count()
  generate_item_to_entity_table()
end

local function on_configuration_changed()
  -- Destroy all GUIs
  for player_index, player_data in pairs(storage.players) do
    local player = game.get_player(player_index)
    if player then
      SearchGui.destroy(player, player_data)
    else
      storage.players[player_index] = nil
    end
  end

  -- Stop in-progress non-blocking searches
  storage.current_searches = {}

  storage.multiple_surfaces = false
  update_surface_count()
  generate_item_to_entity_table()
end

Control.on_init = on_init
Control.on_configuration_changed = on_configuration_changed
Control.events = {
  [defines.events.on_surface_created] = update_surface_count,
  [defines.events.on_surface_deleted] = update_surface_count
}

event_handler.add_libraries{
  gui --[[@as event_handler]],
  Control,
  CustomInput,
  Search,
  SearchResults,
  ResultLocation,
  SearchGui,
}