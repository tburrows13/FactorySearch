util = require "__core__.lualib.util"
event = require "scripts.event"
search = require "scripts.search"
local ui = require "scripts.ui"


script.on_init(
  function()
    global.players = {}
  end
)

script.on_configuration_changed(
  function(data)
    -- Destroy all GUIs
    for player_index, player_data in pairs(global.players) do
      ui.destroy_gui(game.get_player(player_index), player_data)
    end
  end
)