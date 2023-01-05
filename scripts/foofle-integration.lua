local Gui = require "scripts.gui"

remote.add_interface("factory-search", {
  search = function(player, info)
    local gui = Gui.open(player, global.players[player.index])
    gui.refs.item_select.elem_value = {
        type = info.type,
        name = info.name
    }
    Gui.start_search(player, gui)
  end,
  foofle_support = function(info)
    return info.type == "fluid" or info.type == "item"
  end
})

local function on_start()
  if remote.interfaces["foofle"] then
    remote.call("foofle", "add_integration", "factory-search", {
      button = {
        type = "button",
        caption = { "mod-name.FactorySearch" }
      },
      supported_check = "foofle_support",
      callback = "search"
    })
  end
end

return { on_start = on_start }
