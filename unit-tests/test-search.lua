local unit_test_functions = require("unit-test-functions")

local LOG = unit_test_functions.print_msg
local SUCCESS = unit_test_functions.test_successful
local FAIL = unit_test_functions.test_failed
local INVALID = unit_test_functions.test_invalid
local ASSERT = unit_test_functions.assert
local ASSERT_EQUAL = unit_test_functions.assert_equal

local test_search = function(tick)
  LOG("Unit testing mod configuration:")
  for mod_name, mod_version in pairs(script.active_mods) do
    LOG(mod_name .. " version " .. mod_version)
  end

  -- Setup
  local player = game.get_player(1)  ---@cast player -?
  player.exit_cutscene()

  local surface = player.surface

  --surface.clear(true)
  local chest = surface.create_entity{
    name = "steel-chest",
    position = {5, 5},
    force = player.force,
  }  ---@cast chest -?

  chest.insert({name = "iron-plate", count = 100})

  -- Run test

  remote.call("factory-search", "set_search_state", player,
  ---@diagnostic disable-next-line: missing-fields
  {
    all_qualities = true,
    all_surfaces = true,
    consumers = false,
    producers = false,
    storage = true,
    logistics = false,
    modules = false,
    requesters = false,
    ground_items = false,
    entities = false,
    signals = false,
    map_tags = false,
  })
  remote.call("factory-search", "search", player, {name = "iron-plate"})

  -- Check result
  local search_frame = player.gui.screen["fs_frame"]
  local results_flow = search_frame
    .children[2]  -- inside_shallow_frame
      .children[2]  -- horizontal flow
        .children[2]  -- scroll pane
          .children[1]  -- vertical flow
            .children[2]  -- result_flow

  local surface_counts_flow = results_flow.children[1]  -- [2] when include_surface_name
  local item_count_label = surface_counts_flow.children[1]
  ASSERT(item_count_label.caption[5] == "100", "Item count label does not show the correct number of items.")

  local results_table = results_flow
    .children[2]  -- vertical frame (slot_button_deep_frame) ([3] when include_surface_name)
      .children[3]  -- table (storage results)

  ASSERT(#results_table.children == 1, "No results found in search table, test failed.")
  local result_button = results_table.children[1]
  ASSERT(result_button.sprite == "entity/steel-chest", "Result button does not have the correct sprite.")
  ASSERT(result_button.number == 1, "Result button does not have the correct number of items.")
  ASSERT(result_button.tags.position.x == 5.5 and result_button.tags.position.y == 5.5,
         "Result button does not have the correct position tags.")
  ASSERT(result_button.tags.surface == surface.name, "Result button does not have the correct surface tag.")
  return SUCCESS
end

return {test_search = test_search}
