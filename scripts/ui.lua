local gui = require("__FactorySearch__.scripts.gui")
require "scripts.open_location"

local function toggle_fab(elem, sprite, state)
  if state then
    elem.style = "fs_flib_selected_frame_action_button"
    elem.sprite = sprite .. "_black"
  else
    elem.style = "frame_action_button"
    elem.sprite = sprite .. "_white"
  end
end

local function get_signal_name(signal)
  if signal.name then
    if signal.type == "item" then
      return game.item_prototypes[signal.name].localised_name
    elseif signal.type == "fluid" then
      return game.fluid_prototypes[signal.name].localised_name
    elseif signal.type == "virtual" then
      return game.virtual_signal_prototypes[signal.name].localised_name
    end
  end
end

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
      local extra_info = ""
      if group.recipe_list then
        extra_info = {""}
        local multiple_recipes = false
        local number_of_recipes = 0
        for _ in pairs(group.recipe_list) do number_of_recipes = number_of_recipes + 1 end

        if number_of_recipes > 1 then
          multiple_recipes = true
        end
        if number_of_recipes <= 20 then
          -- Localised strings must not have more than 20 parameters
          for name, recipe_info in pairs(group.recipe_list) do
            local string = "\n"
            if multiple_recipes then
              string = string .. "x" .. recipe_info.count .. " "
            end
            string = string .. "[recipe=" .. name .. "] "
            table.insert(extra_info, string)
            table.insert(extra_info, recipe_info.localised_name)
          end
        end
      end
      if group.item_count then
        extra_info = {"", "\n[font=default-semibold][color=255, 230, 192]", {"gui-train.add-item-count-condition"}, ":[/color][/font] ", util.format_number(math.floor(group.item_count), true)}
      end
      if group.fluid_count then
        extra_info = {"", "\n[font=default-semibold][color=255, 230, 192]", {"gui-train.add-fluid-count-condition"}, ":[/color][/font] ", util.format_number(math.floor(group.fluid_count), true)}
      end
      if group.request_count then
        extra_info = {"", "\n[font=default-semibold][color=255, 230, 192]", {"search-gui.request-count-tooltip"}, ":[/color][/font] ", util.format_number(math.floor(group.request_count), true)}
      end
      if group.signal_count then
        extra_info = {"", "\n[font=default-semibold][color=255, 230, 192]", {"search-gui.signal-count-tooltip"}, ":[/color][/font] ", util.format_number(math.floor(group.signal_count), true)}
      end
      local sprite = "item/" .. entity_name
      if not game.is_valid_sprite_path(sprite) then
        sprite = "fluid/" .. entity_name
        if not game.is_valid_sprite_path(sprite) then
          sprite = "entity/" .. entity_name
          if not game.is_valid_sprite_path(sprite) then
            sprite = "recipe/" .. entity_name
            if not game.is_valid_sprite_path(sprite) then
              sprite = "virtual-signal/" .. entity_name
              if not game.is_valid_sprite_path(sprite) then
                sprite = "utility/questionmark"
              end
            end
          end
        end
      end
      table.insert(gui_elements,
        {
          type = "sprite-button",
          sprite = sprite,
          tooltip = {  "", "[font=default-bold]", group.localised_name, "[/font]", extra_info, "\n", {"search-gui.result-tooltip"} },
          style = "slot_button",
          number = group.count,
          tags = { position = group.avg_position, surface = surface_name, selection_boxes = get_selection_boxes(group) },
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

local function build_result_gui(data, frame, state_valid)
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
    local surface_contains_results = false
    for _, category_data in pairs(surface_data) do
      surface_contains_results = surface_contains_results or not not next(category_data)
    end
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
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.producers)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.storage)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.logistics)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.entities)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.ground_items)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.requesters)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.signals)
          },
          {
            type = "table",
            column_count = 10,
            style = "logistics_slot_table",
            children = build_surface_results(surface_name, surface_data.map_tags)
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
      style_mods = { maximal_height = 800 },
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
              style = "frame_action_button",
              sprite = "fs_flib_pin_white",
              hovered_sprite = "fs_flib_pin_black",
              clicked_sprite = "fs_flib_pin_black",
              mouse_button_filter = { "left" },
              tooltip = { "search-gui.keep-open" },
              ref = { "pin_button" },
              actions = {
                on_click = { gui = "search", action = "toggle_pin"},
              }
            },
            {
              type = "sprite-button",
              style = "close_button",
              sprite = "utility/close_white",
              hovered_sprite = "utility/close_black",
              clicked_sprite = "utility/close_black",
              mouse_button_filter = { "left" },
              tooltip = { "gui.close-instruction" },
              ref = { "close_button" },
              actions = {
                on_click = { gui = "search", action = "close" },
              },
            },
          },
        },
        {
          type = "frame",
          style = "inside_shallow_frame",
          direction = "vertical",
          children = {
            {
              type = "frame",
              style = "subheader_frame",
              direction = "horizontal",
              children = {
                {
                  type = "flow",
                  style = "horizontal_flow",
                  style_mods = { vertical_align = "center", horizontally_stretchable = true, horizontal_spacing = 12 },
                  children = {
                    {
                      type = "label",
                      style = "subheader_caption_label",
                      ref = { "subheader_title" },
                    },
                    {
                      type = "empty-widget",
                      style_mods = { horizontally_stretchable = true, horizontally_squashable = true }
                    },
                    {
                      type = "checkbox",
                      state = true,
                      caption = { "search-gui.all-surfaces" },
                      --tooltip = {"search-gui.storage-tooltip"},
                      ref = { "all_surfaces" },
                      actions = {
                        on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                      }
                    },
                    {
                      type = "sprite-button",
                      style = "tool_button",
                      sprite = "utility/refresh",
                      tooltip = { "gui.refresh" },
                      mouse_button_filter = { "left" },
                      actions = {
                        on_click = { gui = "search", action = "refresh" },
                      },
                    },
                  }
                }
              }
            },
            {
              type = "flow",
              direction = "vertical",
              style = "vertical_flow_under_subheader",
              children = {
                {
                  type = "flow",
                  direction = "horizontal",
                  style_mods = { horizontal_spacing = 12},
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
                          tooltip = {"search-gui.storage-tooltip", "[entity=steel-chest][entity=logistic-chest-storage][entity=storage-tank][entity=car][entity=spidertron][entity=cargo-wagon][entity=roboport]"},
                          ref = { "include_inventories" },
                          actions = {
                            on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                          }
                        },
                        {
                          type = "checkbox",
                          state = false,
                          caption = {"search-gui.logistics-name"},
                          tooltip = {"search-gui.logistics-tooltip", "[entity=fast-transport-belt][entity=fast-underground-belt][entity=fast-splitter][entity=pipe][entity=fast-inserter][entity=logistic-robot]"},
                          ref = { "include_logistics" },
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
                        {
                          type = "checkbox",
                          state = false,
                          caption = {"search-gui.ground-items-name"},
                          tooltip = {"search-gui.ground-items-tooltip"},
                          ref = { "include_ground_items" },
                          actions = {
                            on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                          }
                        },
                        {
                          type = "checkbox",
                          state = false,
                          caption = {"search-gui.requesters-name"},
                          tooltip = {"search-gui.requesters-tooltip", "[entity=logistic-chest-requester][entity=logistic-chest-buffer]"},
                          ref = { "include_requesters" },
                          actions = {
                            on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                          }
                        },
                        {
                          type = "checkbox",
                          state = false,
                          caption = {"search-gui.signals-name"},
                          tooltip = {"search-gui.signals-tooltip", "[entity=decider-combinator][entity=arithmetic-combinator][entity=constant-combinator][entity=roboport][entity=train-stop][entity=rail-signal][entity=rail-chain-signal][entity=accumulator][entity=stone-wall]"},
                          ref = { "include_signals" },
                          actions = {
                            on_checked_state_changed = { gui = "search", action = "checkbox_toggled" }
                          }
                        },
                        {
                          type = "checkbox",
                          state = false,
                          caption = {"search-gui.map-tags-name"},
                          tooltip = {"search-gui.map-tags-tooltip"},
                          ref = { "include_map_tags" },
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
                      type = "scroll-pane",
                      style = "naked_scroll_pane",
                      horizontal_scroll_policy = "never",
                      vertical_scroll_policy = "auto-and-reserve-space",
                      style_mods = { right_padding = -12, extra_margin_when_activated = -12, extra_padding_when_activated = 12},-- extra_top_margin_when_activated = -12, extra_bottom_margin_when_activated = -12, extra_right_margin_when_activated = -12 },
                      children = {
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
                  }
                }
              }
            },
          }
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
  if not player_data.pinned then
    player.opened = refs.frame
  end
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
  if player_data.ignore_close then
    -- Set when the pin button is pressed just before changing player.opened
    player_data.ignore_close = false
  else
    local refs = player_data.refs
    refs.frame.visible = false
    player.set_shortcut_toggled("search-factory", false)
    if player.opened == refs.frame then
      player.opened = nil
    end
    --destroy_gui(player, player_data)
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
    logistics = refs.include_logistics.state,
    requesters = refs.include_requesters.state,
    ground_items = refs.include_ground_items.state,
    entities = refs.include_entities.state,
    signals = refs.include_signals.state,
    map_tags = refs.include_map_tags.state
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
    local data
    if state_valid then
      local surface
      if not refs.all_surfaces.state then
        surface = player.surface
      end
      data = find_machines(item, force, state, surface)
    end
    build_result_gui(data, refs.result_flow, state_valid)
    refs.subheader_title.caption = get_signal_name(item) or ""
  else
    -- Clear GUI
    local frame = refs.result_flow
    frame.clear()
    gui.build(frame, {
      {
        type = "label",
        caption = {"search-gui.explanation"},
      }
    })
    refs.subheader_title.caption = ""
    clear_markers(player)
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
        --destroy_gui(player, player_data)
      elseif msg == "toggle_pin" then
        player_data.pinned = not player_data.pinned
        toggle_fab(player_data.refs.pin_button, "fs_flib_pin", player_data.pinned)
        if player_data.pinned then
          player_data.ignore_close = true
          player.opened = nil
          player_data.refs.close_button.tooltip = { "gui.close" }
        else
          player.opened = player_data.refs.frame
          player_data.refs.frame.force_auto_center()
          player_data.refs.close_button.tooltip = { "gui.close-instruction" }
        end
      elseif msg == "open_location_in_map" then
        local tags = event.element.tags.FactorySearch
        if event.button == defines.mouse_button_type.left then
          open_location(player, tags)
        elseif event.button == defines.mouse_button_type.right then
          highlight_location(player, tags)
        end
      elseif msg == "refresh" then
        start_search(player, player_data)
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


script.on_event("open-search-prototype",
  function(event)
    local player = game.get_player(event.player_index)
    local player_data = global.players[event.player_index]
    if event.selected_prototype then
      local name = event.selected_prototype.name
      local type
      if game.item_prototypes[name] then
        type = "item"
      elseif game.fluid_prototypes[name] then
        type = "fluid"
      elseif game.virtual_signal_prototypes[name] then
        type = "virtual"
      elseif game.recipe_prototypes[name] then
        local recipe = game.recipe_prototypes[name]
        local main_product = recipe.main_product
        if main_product then
          name = main_product.name
          type = main_product.type
        elseif #recipe.products == 1 then
          local product = recipe.products[1]
          name = product.name
          type = product.type
        end
      elseif game.entity_prototypes[name] then
        local entity = game.entity_prototypes[name]
        local items_to_place_this = entity.items_to_place_this
        if items_to_place_this and items_to_place_this[1] then
          name = items_to_place_this[1].name
          type = "item"
        end
      end
      if not type then
        player.create_local_flying_text{text = { "search-gui.invalid-item" }, create_at_cursor = true}
        return
      end
      open_gui(player, player_data)
      player_data = global.players[event.player_index]
      local refs = player_data.refs
      refs.item_select.elem_value = {type = type, name = name}
      start_search(player, player_data)
    end
  end
)

return {destroy_gui = destroy_gui}