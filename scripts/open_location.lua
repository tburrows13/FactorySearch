local function draw_markers(player, surface, selection_boxes)
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

  -- Draw new markers
  for _, selection_box in pairs(selection_boxes) do
    rendering.draw_rectangle{
      color = { r = 0, g = 0.9, b = 0, a = 0.9 },
      width = 4,
      filled = false,
      left_top = selection_box.left_top,
      right_bottom = selection_box.right_bottom,
      surface = surface,
      time_to_live = 600,
      players = {player},
    }
  end
end

local function open_location(player, data)
  local surface_name = data.surface
  local position = data.position
  if surface_name == player.surface.name then
    player.zoom_to_world(position, 1.7)
    draw_markers(player, surface_name, data.selection_boxes)
  else
    -- Try using Space Exploration's remote view
    -- /c remote.call("space-exploration", "remote_view_start", {player=game.player, zone_name = "Nauvis", position={x=100,y=200}, location_name="Point of Interest", freeze_history=true})
    if remote.interfaces["space-exploration"] then
      if surface_name == "nauvis" then
        surface_name = "Nauvis"
      end
      remote.call("space-exploration", "remote_view_start", {player=player, zone_name = surface_name, position=position})
      draw_markers(player, surface_name, data.selection_boxes)
    else
      game.print({"search-gui.wrong-surface"})
    end
  end
end

return open_location