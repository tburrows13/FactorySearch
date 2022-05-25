local add_vector = math2d.position.add
local subtract_vector = math2d.position.subtract
local rotate_vector = math2d.position.rotate_vector

local LINE_COLOR = { r = 0, g = 0.9, b = 0, a = 1 }
local LINE_WIDTH = 4
local HALF_WIDTH = (LINE_WIDTH / 2) / 32  -- 32 pixels per tile

function clear_markers(player)
  -- Clear all old markers belonging to player
  if #game.players == 1 then
    rendering.clear("FactorySearch")
  else
    local ids = rendering.get_all_ids("FactorySearch")
    for _, id in pairs(ids) do
      if rendering.get_players(id)[1].index == player.index then
        rendering.destroy(id)
      end
    end
  end
end

local function draw_markers(player, surface, selection_boxes)
  clear_markers(player)

  -- Draw new markers
  for _, selection_box in pairs(selection_boxes) do
    if selection_box.orientation then
      local angle = selection_box.orientation * 360

      -- Four corners
      local left_top = selection_box.left_top
      local right_bottom = selection_box.right_bottom
      local right_top = {x = right_bottom.x, y = left_top.y}
      local left_bottom = {x = left_top.x, y = right_bottom.y}

      -- Extend the end of each line by HALF_WIDTH so that corners are still right angles despite `width`
      local lines = {
        {from = {x = left_top.x - HALF_WIDTH, y = left_top.y}, to = {x = right_top.x + HALF_WIDTH, y = right_top.y}},  -- Top
        {from = {x = left_bottom.x - HALF_WIDTH, y = left_bottom.y}, to = {x = right_bottom.x + HALF_WIDTH, y = right_bottom.y}},  -- Bottom
        {from = {x = left_top.x, y = left_top.y - HALF_WIDTH}, to = {x = left_bottom.x, y = left_bottom.y + HALF_WIDTH}},  -- Left
        {from = {x = right_top.x, y = right_top.y - HALF_WIDTH}, to = {x = right_bottom.x, y = right_bottom.y + HALF_WIDTH}},  -- Right
      }

      local center = {x = (left_top.x + right_bottom.x) / 2, y = (left_top.y + right_bottom.y) / 2}
      for _, line in pairs(lines) do
        -- Translate each point to origin, rotate, then translate back
        local rotated_from = add_vector(rotate_vector(subtract_vector(line.from, center), angle), center)
        local rotated_to = add_vector(rotate_vector(subtract_vector(line.to, center), angle), center)

        rendering.draw_line{
          color = LINE_COLOR,
          width = LINE_WIDTH,
          from = rotated_from,
          to = rotated_to,
          surface = surface,
          time_to_live = 720,
          players = {player},
        }
      end
    else
      rendering.draw_rectangle{
        color = LINE_COLOR,
        width = LINE_WIDTH,
        filled = false,
        left_top = selection_box.left_top,
        right_bottom = selection_box.right_bottom,
        surface = surface,
        time_to_live = 720,
        players = {player},
      }
    end
    --[[game.get_surface(surface).create_entity{
      name = "highlight-box",
      position = {0, 0},  -- Ignored by game
      bounding_box = selection_box,
      box_type = "copy",  -- Green
      render_player_index = player.index,
      time_to_live = 600,

    }]]
  end
end

function open_location(player, data)
  local surface_name = data.surface
  local position = data.position

  draw_markers(player, surface_name, data.selection_boxes)

  if remote.interfaces["space-exploration"] and
    remote.call("space-exploration", "remote_view_is_unlocked", { player = player }) then
    -- If Space Exploration's remote view is an option, then always use it
    if surface_name == "nauvis" then
      surface_name = "Nauvis"
    end
    remote.call("space-exploration", "remote_view_start", {player = player, zone_name = surface_name, position = position})
  else
    if surface_name == player.surface.name then
      player.zoom_to_world(position, 1.7)
    else
      player.create_local_flying_text{text = {"search-gui.wrong-surface"}, create_at_cursor = true}
    end
  end
end
