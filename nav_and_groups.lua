-- Vim-style window focus/swap that understands Hyprland tab groups.
-- primozs.vim-nav-and-groups: managed module
-- Pure Lua: no shell helpers, no jq. Requires Omarchy Hyprland Lua (hl / o).

local DIRS = {
  h = { focus = "l" },
  l = { focus = "r" },
  k = { focus = "u" },
  j = { focus = "d" },
}

local function dispatch(dsp)
  hl.dispatch(dsp)
end

local function active_window()
  return hl.get_active_window()
end

-- Multi-tab group only (size > 1). Lone toggled groups are treated as normal tiles.
local function multi_group(win)
  local g = win and win.group
  if g and g.size and g.size > 1 then
    return g
  end
  return nil
end

local function group_size(win)
  local g = win and win.group
  return (g and g.size) or 0
end

local function mapped_workspace_windows()
  local ws = hl.get_active_workspace()
  if not ws then
    return {}
  end
  local out = {}
  for _, win in ipairs(ws:get_windows() or {}) do
    if win.mapped and not win.hidden then
      out[#out + 1] = win
    end
  end
  return out
end

local function with_animations_off(fn)
  local prev = hl.get_config("animations.enabled")
  hl.config({ animations = { enabled = false } })
  local ok, err = pcall(fn)
  hl.config({ animations = { enabled = prev } })
  if not ok then
    error(err)
  end
end

--- Focus: in a multi-tab group, cycle tabs; h/l at the edge leave the group.
local function nav(key)
  local d = DIRS[key]
  if not d then
    return
  end

  local win = active_window()
  local g = multi_group(win)
  if not g then
    dispatch(hl.dsp.focus({ direction = d.focus }))
    return
  end

  if key == "h" or key == "l" then
    local idx = g.current_index
    if (key == "h" and idx == 1) or (key == "l" and idx == g.size) then
      dispatch(hl.dsp.focus({ direction = d.focus }))
    elseif key == "h" then
      dispatch(hl.dsp.group.prev())
    else
      dispatch(hl.dsp.group.next())
    end
    return
  end

  if key == "k" then
    dispatch(hl.dsp.group.prev())
  else
    dispatch(hl.dsp.group.next())
  end
end

--- Move/swap: reorder or eject tabs; otherwise join a neighbor group or swap.
local function move(key)
  local d = DIRS[key]
  if not d then
    return
  end

  local win = active_window()
  local g = multi_group(win)

  if g then
    if key == "h" or key == "l" then
      local idx = g.current_index
      if key == "h" and idx == 1 then
        dispatch(hl.dsp.window.move({ out_of_group = "l" }))
      elseif key == "l" and idx == g.size then
        dispatch(hl.dsp.window.move({ out_of_group = "r" }))
      elseif key == "h" then
        dispatch(hl.dsp.group.move_window({ forward = false }))
      else
        dispatch(hl.dsp.group.move_window({ forward = true }))
      end
      return
    end

    dispatch(hl.dsp.window.move({ into_group = d.focus }))
    return
  end

  if key == "h" or key == "l" then
    local before = group_size(win)
    dispatch(hl.dsp.window.move({ into_group = d.focus }))
    if group_size(active_window()) > before then
      return
    end
  end

  dispatch(hl.dsp.window.swap({ direction = d.focus }))
end

--- Super+G: fold every window on this workspace into one group, or dissolve it.
local function group_workspace()
  local active = active_window()
  if not active then
    return
  end

  local wins = mapped_workspace_windows()
  if #wins == 0 then
    return
  end

  local has_multi = false
  for _, win in ipairs(wins) do
    if multi_group(win) then
      has_multi = true
      break
    end
  end

  with_animations_off(function()
    if has_multi then
      for _, win in ipairs(wins) do
        if win.group and win.group.size and win.group.size > 0 then
          dispatch(hl.dsp.focus({ window = win }))
          dispatch(hl.dsp.group.toggle())
        end
      end
      dispatch(hl.dsp.focus({ window = active }))
      return
    end

    if #wins == 1 then
      dispatch(hl.dsp.focus({ window = wins[1] }))
      dispatch(hl.dsp.group.toggle())
      return
    end

    dispatch(hl.dsp.focus({ window = wins[1] }))
    if group_size(active_window()) == 0 then
      dispatch(hl.dsp.group.toggle())
    end

    local function pull_in(win)
      dispatch(hl.dsp.focus({ window = win }))
      for _, dir in ipairs({ "l", "r", "u", "d" }) do
        dispatch(hl.dsp.window.move({ into_group = dir }))
      end
    end

    -- Deep dwindle trees often need a second pass (same as the old bash helper).
    for i = 2, #wins do
      pull_in(wins[i])
    end
    for i = 2, #wins do
      pull_in(wins[i])
    end

    dispatch(hl.dsp.focus({ window = active }))
  end)
end

--- Move the active window to a workspace; eject from a multi-tab group first.
local function move_to_workspace(ws, follow)
  local win = active_window()
  if multi_group(win) then
    dispatch(hl.dsp.window.move({ out_of_group = true }))
  end
  if follow then
    dispatch(hl.dsp.window.move({ workspace = tostring(ws) }))
  else
    dispatch(hl.dsp.window.move({ workspace = tostring(ws), follow = false }))
  end
end

local function rebind(key, description, dispatcher)
  hl.unbind(key)
  o.bind(key, description, dispatcher)
end

-- Free keys the Vim layout needs, then place the displaced Omarchy actions.
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")
hl.unbind("SUPER + G")

-- Close: stock ships Super+W; add Super+Q / Super+Shift+Q as the same action.
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + SHIFT + Q", "Close window", hl.dsp.window.close())

rebind("SUPER + E", "Toggle window split", hl.dsp.layout("togglesplit"))
-- Cheatsheet off Super+K; keep Super+Shift+- as stock shrink-up.
rebind("SUPER + CTRL + SHIFT + K", "Keybindings", "omarchy-menu-keybindings")
rebind("SUPER + D", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
rebind("SUPER + G", "Group all windows on workspace", group_workspace)

-- Descriptions avoid the word "group" so omarchy-menu-keybindings does not
-- bury them at prio 94 (match /group/).
for _, key in ipairs({ "H", "J", "K", "L", "LEFT", "RIGHT", "UP", "DOWN" }) do
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
end

local nav_keys = {
  { key = "H", dir = "h", nav = "Focus left / previous tab / exit tabs", move = "Swap/join left / reorder or eject tab" },
  { key = "L", dir = "l", nav = "Focus right / next tab / exit tabs", move = "Swap/join right / reorder or eject tab" },
  { key = "K", dir = "k", nav = "Focus up / previous tab", move = "Swap up / into tabs" },
  { key = "J", dir = "j", nav = "Focus down / next tab", move = "Swap down / into tabs" },
  { key = "LEFT", dir = "h", nav = "Focus left / previous tab / exit tabs", move = "Swap/join left / reorder or eject tab" },
  { key = "RIGHT", dir = "l", nav = "Focus right / next tab / exit tabs", move = "Swap/join right / reorder or eject tab" },
  { key = "UP", dir = "k", nav = "Focus up / previous tab", move = "Swap up / into tabs" },
  { key = "DOWN", dir = "j", nav = "Focus down / next tab", move = "Swap down / into tabs" },
}

for _, item in ipairs(nav_keys) do
  local dir = item.dir
  o.bind("SUPER + " .. item.key, item.nav, function()
    nav(dir)
  end)
  o.bind("SUPER + SHIFT + " .. item.key, item.move, function()
    move(dir)
  end)
end

for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  local ws = workspace
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("SUPER + SHIFT + ALT + " .. key)
  o.bind("SUPER + SHIFT + " .. key, "Move active window silently to workspace " .. ws, function()
    move_to_workspace(ws, false)
  end)
  o.bind("SUPER + SHIFT + ALT + " .. key, "Move active window to workspace " .. ws, function()
    move_to_workspace(ws, true)
  end)
end

-- Theme-colored group tabs, opaque windows, instant window motion.
require("hypr.group_looknfeel")
