-- Group bar + opaque windows + instant window motion.
-- primozs.vim-nav-and-groups: managed module
-- Named group_looknfeel.lua so it does not clash with the user's hypr.looknfeel.
--
-- IMPORTANT: groupbar.gradients must stay true. With gradients=false Hyprland
-- skips the tab fill entirely (titles float over the wallpaper). See
-- hyprwm/Hyprland#9352.
--
-- Wallpaper bleed through tabs is also Omarchy's default window opacity
-- (0.985 / 0.96); we force opaque windows below.

local theme_dir = (os.getenv("HOME") or "") .. "/.local/state/omarchy/current/theme"

local function hex_to_rgba(hex, alpha)
  if not hex then
    return nil
  end
  local h = hex:gsub("^#", "")
  if not h:match("^%x%x%x%x%x%x$") then
    return nil
  end
  return "rgba(" .. h .. (alpha or "ff") .. ")"
end

local function parse_toml_file(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local section = ""
  local out = {}
  for line in f:lines() do
    local sec = line:match("^%[([%w%-_]+)%]")
    if sec then
      section = sec
    else
      local key, qval = line:match('^([%w%-_]+)%s*=%s*"(.-)"')
      local nkey, nval = line:match("^([%w%-_]+)%s*=%s*([%d%.]+)%s*$")
      local bkey, bval = line:match("^([%w%-_]+)%s*=%s*(true|false)%s*$")
      local store_key
      if key or nkey or bkey then
        local k = key or nkey or bkey
        store_key = section ~= "" and (section .. "." .. k) or k
      end
      if key and qval then
        out[store_key] = qval
      elseif nkey and nval then
        out[store_key] = tonumber(nval)
      elseif bkey and bval then
        out[store_key] = (bval == "true")
      end
    end
  end
  f:close()
  return out
end

local colors = parse_toml_file(theme_dir .. "/colors.toml")

local active_fill = hex_to_rgba(colors.accent or colors.blue, "ff") or "rgba(7aa2f7ff)"
local inactive_fill = hex_to_rgba(colors.background or colors.dark_background, "ff") or "rgba(1a1b26ff)"
local text_active = hex_to_rgba(colors.darker_background or colors.dark_background, "ff") or "rgba(0e0e14ff)"
local text_inactive = hex_to_rgba(colors.foreground or colors.light_foreground, "ff") or "rgba(a9b1d6ff)"

hl.config({
  group = {
    groupbar = {
      gaps_in = 0,
      gaps_out = 0,
      indicator_gap = 0,
      keep_upper_gap = false,
      blur = false,
      -- Must be true or tab backgrounds do not draw.
      gradients = true,
      rounding = 0,
      gradient_rounding = 0,
      gradient_round_only_edges = false,

      font_family = "monospace",
      font_size = 12,
      -- height 25: a bit taller than Omarchy default 22 for tab labels.
      height = 25,
      -- indicator_height 0: the 1px underline was showing wallpaper through.
      indicator_height = 0,
      text_padding = 5,

      col = {
        active = active_fill,
        inactive = inactive_fill,
        locked_active = active_fill,
        locked_inactive = inactive_fill,
      },
      text_color = text_active,
      text_color_inactive = text_inactive,
      text_color_locked_active = text_active,
      text_color_locked_inactive = text_inactive,
    },
  },
})

-- Fully opaque windows so the wallpaper cannot show through the group bar.
o.window({ tag = "default-opacity" }, { opacity = "1.0 1.0" })

-- Instant windows: no pop-in/out, no slide when grouping / moving.
-- Leaves layer (OSD/menu) animations alone — Omarchy already no_anim's the bar.
hl.animation({ leaf = "windows", enabled = false })
hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "windowsMove", enabled = false })
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeOut", enabled = false })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = false })
