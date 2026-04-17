local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

-- ================================
-- SHELL
-- ================================
config.default_prog = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' }
config.default_cwd = 'C:\\Users\\Admin'

-- ================================
-- ARTHUR COLOR SCHEME
-- ================================
local scheme = wezterm.color.load_scheme('C:\\Users\\Admin\\iTerm2-Color-Schemes\\wezterm\\Arthur.toml')
config.colors = scheme

config.colors.foreground = '#c8d6e5'
config.colors.background = '#12181f'
config.colors.cursor_bg = '#ff6b00'
config.colors.cursor_fg = '#080c10'
config.colors.cursor_border = '#ff6b00'

config.colors.selection_fg = '#080c10'
config.colors.selection_bg = '#00e5ff'

config.colors.ansi = {
  '#080c10',
  '#ff3d3d',
  '#00ff9f',
  '#ffe600',
  '#00e5ff',
  '#ff00ff',
  '#00fff7',
  '#c8d6e5',
}
config.colors.brights = {
  '#1a2233',
  '#ff6b6b',
  '#00ffb3',
  '#fff176',
  '#40eeff',
  '#ff40ff',
  '#40fffa',
  '#ffffff',
}

config.colors.tab_bar = {
  background = 'rgba(8, 12, 16, 0.95)',
  active_tab = {
    bg_color = '#ff6b00',
    fg_color = '#080c10',
    intensity = 'Bold',
  },
  inactive_tab = {
    bg_color = 'rgba(8, 12, 16, 0.5)',
    fg_color = '#3a6b8a',
  },
  inactive_tab_hover = {
    bg_color = 'rgba(13, 31, 45, 0.8)',
    fg_color = '#00e5ff',
    italic = true,
  },
  new_tab = {
    bg_color = 'rgba(8, 12, 16, 0.5)',
    fg_color = '#00e5ff',
  },
  new_tab_hover = {
    bg_color = 'rgba(13, 31, 45, 0.8)',
    fg_color = '#ff6b00',
  },
}
config.colors.scrollbar_thumb = '#ff6b00'

-- ================================
-- BACKGROUND IMAGE
-- ================================
config.background = {
  {
    source = { File = 'C:\\Users\\Admin\\Gambar\\aira-bg.png' },
    hsb = { brightness = 0.3, saturation = 1.0 },
    opacity = 0.7,
    attachment = 'Fixed',
    repeat_x = 'NoRepeat',
    repeat_y = 'NoRepeat',
    horizontal_align = 'Center',
    vertical_align = 'Middle',
  },
  {
    source = { Color = '#12181f' },
    width = '100%',
    height = '100%',
    opacity = 0.6,
  },
}

-- ================================
-- FONT
-- ================================
config.font = wezterm.font('Courier Prime')
config.font_size = 14.0

-- ================================
-- WINDOW
-- ================================
config.window_background_opacity = 1.0
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'TITLE | RESIZE'

-- ================================
-- CURSOR
-- ================================
config.default_cursor_style = 'BlinkingBlock'

-- ================================
-- SCROLLBAR
-- ================================
config.enable_scroll_bar = true
config.scrollback_lines = 10000

-- ================================
-- CLOSE TAB TANPA HANG
-- ================================
config.skip_close_confirmation_for_processes_named = {
  'bash',
  'sh',
  'zsh',
  'fish',
  'cmd.exe',
  'powershell.exe',
}

-- ================================
-- HYPERLINK
-- ================================
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- ================================
-- TAB BAR
-- ================================
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.tab_max_width = 32
config.tab_bar_style = {}

-- ================================
-- LAUNCH MENU (multi shell)
-- ================================
config.launch_menu = {
  { label = 'Git Bash', args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' } },
  { label = 'PowerShell', args = { 'powershell.exe' } },
  { label = 'CMD', args = { 'cmd.exe' } },
}

-- ================================
-- NEW TAB BUTTON SELALU KE HOME
-- ================================
wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
  if button == 'Left' then
    window:perform_action(
      act.SpawnCommandInNewTab {
        args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' },
        cwd = 'C:\\Users\\Admin',
      },
      pane
    )
    return false
  end
  return true
end)

-- ================================
-- STATUS BAR (jam + git branch)
-- ================================
wezterm.on('update-right-status', function(window, pane)
  local date = wezterm.strftime('%a %d %b  %H:%M')

  local cwd = pane:get_current_working_dir()
  local branch = ''
  if cwd then
    local cwd_str = cwd.file_path or ''
    local success, stdout = wezterm.run_child_process({
      'C:\\Program Files\\Git\\bin\\git.exe',
      '-C', cwd_str,
      'rev-parse', '--abbrev-ref', 'HEAD'
    })
    if success then
      branch = ' \u{e0a0} ' .. stdout:gsub('\n', '')
    end
  end

  window:set_right_status(wezterm.format({
    { Foreground = { Color = '#ff6b00' } },
    { Text = branch },
    { Foreground = { Color = '#c8d6e5' } },
    { Text = '   ' .. date .. '  ' },
  }))
end)

-- ================================
-- TAB RENAME OTOMATIS + ICON
-- ================================
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local title = pane.title

  local cwd = pane.current_working_dir
  if cwd then
    local folder = cwd.file_path:match('[^/\\]+$') or cwd.file_path
    title = folder
  end

  local process = pane.foreground_process_name
  if process then
    local exe = process:match('[^/\\]+$') or process
    exe = exe:gsub('%.exe$', '')

    if exe == 'bash' or exe == 'sh' then
      title = '󰆍  ' .. title
    elseif exe == 'vim' or exe == 'nvim' then
      title = '  ' .. title
    elseif exe == 'node' then
      title = '  ' .. title
    elseif exe == 'python' or exe == 'python3' then
      title = '🐍 ' .. title
    elseif exe == 'git' then
      title = '  ' .. title
    else
      title = '⚡ ' .. exe .. ' — ' .. title
    end
  end

  if #title > max_width then
    title = wezterm.truncate_right(title, max_width - 1) .. '…'
  end

  if tab.is_active then
    return {
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ' .. title .. ' ' },
    }
  end

  return {
    { Attribute = { Intensity = 'Normal' } },
    { Text = ' ' .. title .. ' ' },
  }
end)

-- ================================
-- KEYBINDING
-- ================================
config.keys = {
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewTab {
      args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' },
      cwd = 'C:\\Users\\Admin',
    }
  },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS' } },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
}

-- ================================
-- MOUSE BINDING
-- ================================
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },
}

return config