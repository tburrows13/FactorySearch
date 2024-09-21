--- @class SearchState
--- @field consumers boolean
--- @field producers boolean
--- @field storage boolean
--- @field logistics boolean
--- @field modules boolean
--- @field requesters boolean
--- @field ground_items boolean
--- @field entities boolean
--- @field signals boolean
--- @field map_tags boolean


--- SearchResult[surface.name]
--- @alias SearchResult
--- | { [string]: SurfaceSearchResult }

--- SurfaceSearchResult[input_item.type (signal type)]
--- @alias SurfaceSearchResult
--- | { [string]: SurfaceSearchTypeResult }

--- SurfaceSearchTypeResult[input_item.name]
--- @alias SurfaceSearchTypeResult
--- | { [string]: SurfaceSearchNameResult }

--- @class SurfaceSearchNameResult
--- @field consumers CategoryResult
--- @field ground_items CategoryResult
--- @field logistics CategoryResult
--- @field modules CategoryResult
--- @field producers CategoryResult
--- @field requesters CategoryResult
--- @field signals CategoryResult
--- @field storage CategoryResult
--- @field map_tags CategoryResult
--- @field entities CategoryResult
--- @field surface_info SurfaceInfoResult

--- CategoryResult[name (usually entity.name)]
--- @alias CategoryResult
--- | { [string]: ResultGroup[] }

--- @class ResultGroup
--- @field count int
--- @field avg_position MapPosition
--- @field entity_name string
--- @field selection_boxes any
--- @field localised_name string
--- @field recipe_list table -- consumers, producers TODO zjistit typ
--- @field item_count int | nil -- logistics, storage
--- @field fluid_count int | nil -- storage
--- @field module_count int | nil -- modules
--- @field request_count int | nil -- requesters
--- @field signal_count int | nil -- signals
--- @field resource_count int | nil -- resource

--- @class SurfaceInfoResult
--- @field signal_count { [string]: int }
--- @field consumers_count { [string]: int }
--- @field producers_count { [string]: int }
--- @field fluid_count { [string]: int }
--- @field request_count { [string]: int }
--- @field group_count { [string]: int }
--- @field item_count { [string]: int }
--- @field tag_count { [string]: int }
--- @field resource_count { [string]: int }
--- @field module_count { [string]: int }
--- @field ground_count { [string]: int }
--- @field entity_count { [string]: int }


