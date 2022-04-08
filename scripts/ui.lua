local gui = require("__FactorySearch__.scripts.gui")
local open_location = require "scripts.open_location"

local function get_selection_boxes(group)
  selection_boxes = {}
  for i, entity in pairs(group.entities) do
    selection_boxes[i] = entity.selection_box
  end
  return selection_boxes
end

local function build_surface_results(surface_name, surface_data)
  local gui_elements = {}
  for entity_name, entity_surface_data in pairs(surface_data) do
    for _, group in pairs(entity_surface_data) do
      table.insert(gui_elements,
        {
          type = "sprite-button",
          sprite = "entity/" .. entity_name,
          mouse_button_filter = { "left" },
          tooltip = {  "", group.localised_name, "\n", {"gui-train.open-in-map"} },
          style = "slot_button",
          number = group.count,
          tags = {position = group.avg_position, surface = surface_name, selection_boxes = get_selection_boxes(group)},
          actions = { on_click = { gui = "search", action = "open_location_in_map" } },
        }
      )
    end
  end
  return gui_elements
end

local function build_surface_name(include_surface_name, surface_name)
  if include_surface_name then
    if surface_name == "nauvis" then
      -- Space Exploration capitilises all other planet names, so do Nauvis for consistency
      surface_name = "Nauvis"
    end
    return  {
      type = "label",
      caption = surface_name,
      style = "bold_label",
      style_mods = { font = "default-large-bold" }
    }
  else
    return {}
  end

end

local function build_result_gui(data, frame, state_valid, type_valid)
  frame.clear()

  if not state_valid then
    gui.build(frame, {
      {
        type = "label",
        style_mods = { font_color = {1, 0, 0, 1} },
        caption = {"search-gui.incorrect-config"}
      }
    })
    return
  end

  if not type_valid then
    gui.build(frame, {
      {
        type = "label",
        style_mods = { font_color = {1, 0, 0, 1} },
        caption = {"search-gui.incorrect-type"}
      }
    })
    return
  end

  local include_surface_name = false
  local surface_count = 0
  for _, _ in pairs(data) do
    surface_count = surface_count + 1
  end

  if surface_count > 1 then
    include_surface_name = true
  end

  local result_found = false
  for surface_name, surface_data in pairs(data) do
    local surface_contains_results = not not (next(surface_data.producers) or next(surface_data.storage) or next(surface_data.entities))
    result_found = result_found or surface_contains_results
    if not surface_contains_results then
      goto continue
    end
    gui.build(frame, {
      build_surface_name(include_surface_name, surface_name),
      {
        type = "frame",
        direction = "vertical",
        style = "slot_button_deep_frame",
        children = {
          {
            type = "table",
            column_count = 8,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.producers)
          },
          {
            type = "table",
            column_count = 8,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.storage)
          },
          {
            type = "table",
            column_count = 8,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.entities)
          },
        }
      }
    })
    ::continue::
  end

  if not result_found then
    frame.clear()
    gui.build(frame, {
      {
        type = "label",
        style_mods = { font_color = {1, 0, 0, 1} },
        caption = {"search-gui.no-results"}
      }
    })
  end
end

local function build_gui(player)
  local refs = gui.build(player.gui.screen, {
    {
      type = "frame",
      name = "fs_frame",
      direction = "vertical",
      visible = true,
      ref = { "frame" },
      actions = {
        on_closed = { gui = "search", action = "close" },
        on_location_changed = { gui = "search", action = "update_dimmer_location" },
      },
      children = {
        {
          type = "flow",
          style = "fs_flib_titlebar_flow",
          ref = { "titlebar_flow" },
          actions = {
            on_click = { gui = "search", action = "recenter" },  -- TODO What is this?
          },
          children = {
            {
              type = "label",
              style = "frame_title",
              caption = { "mod-name.FactorySearch" },
              ignored_by_interaction = true,
            },
            { type = "empty-widget", style = "fs_flib_titlebar_drag_handle", ignored_by_interaction = true },
            {
              type = "sprite-button",
              style = "close_button",
              sprite = "utility/close_white",
              hovered_sprite = "utility/close_black",
              clicked_sprite = "utility/close_black",
              actions = {
                on_click = { gui = "search", action = "close" },
              },
            },
          },
        },
        {
          type = "frame",
          style = "inside_shallow_frame_with_padding",
          --style_mods = { horizontal_spacing = 8 },
          direction = "horizontal",
          children = {
            {
              type = "flow",
              direction = "horizontal",
              style_mods = { horizontal_spacing = 12 },
              children = {
                {
                  type = "flow",
                  direction = "vertical",
                  children = {
                    {
                      type = "choose-elem-button",
                      style = "slot_button_in_shallow_frame",
                      elem_type = "signal",
                      mouse_button_filter = {"left"},
                      ref = { "item_select" },
                      style_mods = {
                        width = 80,
                        height = 80,
                      },
                      actions = {
                        on_elem_changed = { gui = "search", action = "item_selected" }
                      }
                    },
                    {
                      type = "checkbox",
                      state = true,
                      caption = {"search-gui.producers-name"},
                      tooltip = {"search-gui.producers-tooltip", "[entity=assembling-machine-2][entity=chemical-plant][entity=steel-furnace][entity=electric-mining-drill][entity=pumpjack]"},
                      ref = { "include_machines" },
                      actions = {
                        on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                      }

                    },
                    {
                      type = "checkbox",
                      state = false,
                      caption = {"search-gui.storage-name"},
                      tooltip = {"search-gui.storage-tooltip", "[entity=steel-chest][entity=logistic-chest-storage][entity=storage-tank][entity=car][entity=spidertron][entity=cargo-wagon]"},
                      ref = { "include_inventories" },
                      actions = {
                        on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                      }
                    },
                    {
                      type = "checkbox",
                      state = false,
                      caption = {"search-gui.entities-name"},
                      tooltip = {"search-gui.entities-tooltip"},
                      ref = { "include_entities" },
                      actions = {
                        on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                      }
                    },
                    --[[{
                      type = "sprite-button",
                      style = "slot_sized_button",
                      sprite = "utility/search_icon",
                      mouse_button_filter = {"left"},
                      ref = { "search" },
                      actions = {
                        on_click = { gui = "search", action = "search" }
                      }
                    },]]
                  },
                },
                {
                  type = "flow",
                  ref = { "result_flow" },
                  direction = "vertical",
                  children = {
                    {
                      type = "label",
                      caption = {"search-gui.explanation"},
                    }
                  }
                }
              }
            }
          },
        },
      }
    }
  })

  local player_data = {}
  refs.titlebar_flow.drag_target = refs.frame
  refs.frame.force_auto_center()
  player_data.refs = refs
  global.players[player.index] = player_data
  return player_data
end

local function open_gui(player, player_data)
  if not player_data then
    player_data = build_gui(player)
  end
  local refs = player_data.refs
  player.opened = refs.frame
  refs.frame.visible = true
  refs.frame.bring_to_front()
  player.set_shortcut_toggled("search-factory", true)
end

local function destroy_gui(player, player_data)
  local main_frame = player_data.refs.frame
  if main_frame then
    main_frame.destroy()
  end
  player.set_shortcut_toggled("search-factory", false)
  global.players[player.index] = nil
end

local function close_gui(player, player_data)
  local refs = player_data.refs
  refs.frame.visible = false
  player.set_shortcut_toggled("search-factory", false)
  if player.opened == refs.frame then
    player.opened = nil
  end
end

local function toggle_gui(player, player_data)
  if player_data and player_data.refs.frame.visible then
    close_gui(player, player_data)
  else
    open_gui(player, player_data)
  end
end

local function generate_state(refs)
  return {
    producers = refs.include_machines.state,
    storage = refs.include_inventories.state,
    entities = refs.include_entities.state,
  }
end

local function is_valid_state(state)  -- TODO rename
  local some_checked = false
  for _, checked in pairs(state) do
    some_checked = some_checked or checked
  end
  return some_checked
end

local function start_search(player, player_data)
  local refs = player_data.refs
  local elem_button = refs.item_select
  local item = elem_button.elem_value
  if item then
    local force = player.force
    local state = generate_state(refs)
    local state_valid = is_valid_state(state)
    local type_valid = item.type ~= "virtual"
    local data
    if state_valid and type_valid then
      data = find_machines(item, force.name, state)
    end
    build_result_gui(data, refs.result_flow, state_valid, type_valid)
  end
end

event.on_gui_elem_changed(
  function(event)
    local player = game.get_player(event.player_index)
    local player_data = global.players[event.player_index]
    local action = gui.read_action(event)
    if action then
      local msg = action.action
      if msg == "item_selected" then
        start_search(player, player_data)
      end
    end
  end
)

event.on_gui_checked_state_changed(
  function(event)
    local player = game.get_player(event.player_index)
    local player_data = global.players[event.player_index]
    local action = gui.read_action(event)
    if action then
      local msg = action.action
      if msg == "checkbox_toggled" then
        start_search(player, player_data)
      end
    end
  end
)


event.on_gui_click(
  function(event)
    local player = game.get_player(event.player_index)
    local player_data = global.players[event.player_index]

    local action = gui.read_action(event)
    if action then
      local msg = action.action
      if msg == "close" then
        close_gui(player, player_data)
      elseif msg == "open_location_in_map" then
        local tags = event.element.tags.FactorySearch
        open_location(player, tags)
      elseif msg == "checkbox_toggled" then
        start_search(player, player_data)
      end
    end
  end
)

event.on_gui_closed(
  function(event)
    if event.element and event.element.name == "fs_frame" then
      local player = game.get_player(event.player_index)
      close_gui(player, global.players[event.player_index])
    end
  end
)


local function on_shortcut_pressed(event)
  local player = game.get_player(event.player_index)

  local player_data = global.players[event.player_index]
  toggle_gui(player, player_data)
end
event.on_lua_shortcut(
  function(event)
    if event.prototype_name == "search-factory" then
      on_shortcut_pressed(event)
    end
  end
)
script.on_event("search-factory", on_shortcut_pressed)

return {destroy_gui = destroy_gui}