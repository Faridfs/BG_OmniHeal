local _, ns = ...

-- Keys in the sidebar are the same keys used by the page files and settings search.
ns.options = {
  type = "group",
  args = {},
  navigation = {
    { label = "nav_setup", pages = { "general", "profiles", "info" } },
    { label = "grp_frames", pages = { "ally", "enemy", "status" } },
    { label = "nav_combat", pages = { "auras", "targeting", "tracking", "scanner" } },
    { label = "nav_appearance", pages = { "fonts", "animation", "layers" } },
  },
}
