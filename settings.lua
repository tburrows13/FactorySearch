data:extend{
  {
    type = "double-setting",
    name = "fs-initial-zoom",
    setting_type = "runtime-per-user",
    default_value = 0.6,
    minimum_value = 0.05,
    maximum_value = 10,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "fs-clear-highlights-with-gui",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "ba"
  },
  {
    type = "int-setting",
    name = "fs-highlight-duration",
    setting_type = "runtime-per-user",
    default_value = 12,
    minimum_value = 0,
    maximum_value = 1000,
    order = "bb"
  }

}