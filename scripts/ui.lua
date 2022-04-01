local gui = require("__FactorySearch__.scripts.gui")

local ui = {}

local function build_surface_results(surface_name, surface_data)
  gui_elements = {}
  for _, group in pairs(surface_data) do
    table.insert(gui_elements,
      {
        type = "flow",
        direction = "horizontal",
        children = {
          --[[{
            type = "label",
            caption = group.count,
            style = "caption_label"
          },]]
          {
            type = "sprite-button",
            sprite = "entity/" .. group.entity_name,
            style = "slot_button_in_shallow_frame",
            number = group.count,
          },
          {
            type = "sprite-button",
            style = "slot_sized_button",
            mouse_button_filter = { "left" },
            sprite = "utility/map",
            tooltip = { "gui-train.open-in-map" },
            tags = {position = group.avg_position, surface = surface_name},
            style_mods = { padding = 4 },
            actions = { on_click = { gui = "search", action = "open_location_in_map" } },
          },
        }
      }
    )
  end
  return gui_elements
end

local function build_result_gui(data, frame)
  for surface_name, surface_data in pairs(data) do
    gui.build(frame, {
      {
        type = "label",
        caption = surface_name,
        style = "bold_label",
        style_mods = { font = "default-large-bold" }
      },
      {
        type = "flow",
        direction = "vertical",
        children = build_surface_results(surface_name, surface_data)
      }
    })
  end
end

local function build_gui(player, player_data)
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
          style = "flib_titlebar_flow",
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
            { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
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
          --style_mods = { top_padding = -2 },
          direction = "vertical",
          children = {
            {
              type = "flow",
              direction = "horizontal",
              children = {
                {
                  type = "choose-elem-button",
                  style = "slot_button_in_shallow_frame",
                  elem_type = "item",
                  mouse_button_filter = {"left"},
                  ref = { "item_select" },
                  actions = {
                    on_elem_changed = { gui = "search", action = "item_selected" }
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
              }
            },
            {
              type = "flow",
              ref = { "result_flow" },
              direction = "vertical",
            }
          },
        },
      }
    }
  })

  refs.frame.force_auto_center()
  refs.titlebar_flow.drag_target = refs.frame
  player.opened = refs.frame
  player.set_shortcut_toggled("search-factory", true)
  player_data.refs = refs
end

local function destroy_gui(player, player_data)
  local main_frame = player.gui.screen.fs_frame
  if main_frame then
    main_frame.destroy()
  end
  player.set_shortcut_toggled("search-factory", false)
  global.players[player.index] = nil
end

local function toggle_gui(player, player_data)
  local main_frame = player.gui.screen.fs_frame

  if main_frame == nil then
      build_gui(player, player_data)
  else
      destroy_gui(player, player_data)
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

        local elem_button = player_data.refs.item_select
        local item = elem_button.elem_value
        if item then
          local force = player.force
          --local force_data = global.recipes[force.index]
          -- Exception if only one surface
          --for surface_index, surface_data in pairs(force_data) do
          --  local surface = game.get_surface(surface_index)
            --local recipe_data = surface_data[item]
            -- TODO
          local data = find_machines(item, force.name)
          player_data.refs.result_flow.clear()
          build_result_gui(data, player_data.refs.result_flow)
        end
      end
    end
  end
)

script.on_event(defines.events.on_gui_click,
  function(event)
    local player = game.get_player(event.player_index)
    local player_data = global.players[event.player_index]

    local action = gui.read_action(event)
    if action then
      local msg = action.action
      if msg == "close" then
        destroy_gui(player)
      elseif msg == "search" then
        local elem_button = player_data.refs.item_select
        local item = elem_button.elem_value
        if item then
          local force = player.force
          --local force_data = global.recipes[force.index]
          -- Exception if only one surface
          --for surface_index, surface_data in pairs(force_data) do
          --  local surface = game.get_surface(surface_index)
            --local recipe_data = surface_data[item]
            -- TODO
          local data = find_machines(item, force.name)
          player_data.refs.result_flow.clear()
          build_result_gui(data, player_data.refs.result_flow)
        end
      elseif msg == "open_location_in_map" then
        local tags = event.element.tags.FactorySearch
        local surface_name = tags.surface
        if surface_name == player.surface.name then
          player.zoom_to_world(event.element.tags.FactorySearch.position, 1.7)
        else
          game.print("Different surface")
        end
      end
    end
  end
)

ui.on_gui_closed = function(event)
  if event.element and event.element.name == "fs_frame" then
    local player = game.get_player(event.player_index)
    destroy_gui(player)
  end
end



local function on_shortcut_pressed(event)
  local player = game.get_player(event.player_index)

  global.players[event.player_index] = global.players[event.player_index] or {}
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

return ui