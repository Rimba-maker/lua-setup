local wezterm = require 'wezterm'
local act = wezterm.action
local nf = wezterm.nerdfonts
local config = wezterm.config_builder()

-- WezTerm 20240203 atau lebih baru; tidak memerlukan instalasi Lua terpisah.
-- Pindahkan file ini ke ~/.wezterm.lua atau ~/.config/wezterm/wezterm.lua.
-- Perubahan: palet soft-contrast untuk coding di atas gambar; biru/cyan dibedakan,
-- abu-abu terang untuk teks sekunder, aksen tab/status tidak lagi neon penuh.
-- Background opsional/path portabel tetap tersedia; Git sistem tidak diubah.
-- Lapisan dasar solid menghalangi desktop tembus; gambar tetap ditampilkan.
-- Plugin: https://github.com/michaelbrusegard/tabline.wez
-- Internet diperlukan saat plugin pertama diunduh; berikutnya memakai cache
-- WezTerm (cache tidak ikut file backup ini). Git diperlukan untuk status branch.
-- Font ikon memakai fallback Nerd Font Symbols bawaan WezTerm.
--
-- Pintasan kustom:
-- Ctrl+Shift+D/E       split kanan/bawah, mengikuti direktori pane aktif
-- Ctrl+Shift+Arrow     pindah pane
-- Ctrl+Shift+O         pilih pane secara visual
-- Ctrl+Shift+T         tab lokal baru di home
-- Ctrl+Shift+L         launcher shell yang tersedia
-- Ctrl+Shift+Alt+R     rename tab; input kosong mengembalikan judul otomatis
-- Ctrl+Shift+W         tutup pane dengan pemeriksaan konfirmasi
-- Klik kanan          paste langsung dari clipboard
-- Klik kiri pada link buka hyperlink; drag menyeleksi dan menyalin teks
-- Pintasan bawaan tetap aktif: Ctrl+Shift+Alt+Arrow resize pane,
-- Ctrl+Shift+Z zoom pane, Ctrl+Shift+P command palette, Ctrl+Shift+R reload.
--
-- Leader: Ctrl+Space, lepaskan, lalu tekan tombol dalam 1,5 detik.
-- c                   tab baru mengikuti folder/domain pane (bukan home)
-- d/e                 split kanan/bawah mengikuti folder/domain pane
-- h/j/k/l             pindah pane kiri/bawah/atas/kanan
-- o/z/x               pilih pane / toggle zoom / tutup pane dengan konfirmasi
-- n/p/t               tab berikut / sebelumnya / pemilih tab fuzzy
-- r                   mode resize: h/j/k/l atau Arrow, langkah 3 kolom/baris
--                     Enter/Esc, tombol lain, atau 5 detik idle keluar
-- f/q/[               cari output / Quick Select teks / copy mode
-- w/s                 pemilih workspace / buat workspace di folder lokal aktif
-- Ctrl+Space dua kali meneruskan Ctrl+Space ke aplikasi (misalnya completion).
-- Workspace ini hidup selama WezTerm berjalan; tidak ada restore session.

-- ================================
-- PERSONALISASI
-- ================================
-- Kosong = warna solid. Isi path di dalam [[...]] agar backslash Windows aman.
-- Contoh: [[C:\Users\Nama Kamu\Pictures\background.png]] atau [[assets/background.png]].
-- Gambar yang belum tersedia tidak wajib ada; path relatif mengikuti file Lua.
local background_image = [[]]
-- Font bawaan agar siap setelah reset. Ubah ke 'Courier Prime' setelah dipasang.
local font_family = 'JetBrains Mono'
local tab_title_width = 32

-- ================================
-- PATH & SHELL
-- ================================
local is_windows = wezterm.target_triple:find('windows', 1, true) ~= nil
local home = wezterm.home_dir

local function file_exists(path)
  local file = io.open(path, 'rb')
  if not file then
    return false
  end
  file:close()
  return true
end

local function find_executable(name, candidates)
  local separator = is_windows and ';' or ':'
  local executable = name .. (is_windows and '.exe' or '')
  for directory in (os.getenv('PATH') or ''):gmatch('[^' .. separator .. ']+') do
    directory = directory:gsub('^"', ''):gsub('"$', '')
    local path = directory .. '/' .. executable
    if file_exists(path) then
      return path
    end
  end
  for _, path in ipairs(candidates or {}) do
    if file_exists(path) then
      return path
    end
  end
end

local git_roots = {}
for _, variable in ipairs { 'ProgramW6432', 'ProgramFiles', 'ProgramFiles(x86)' } do
  local directory = os.getenv(variable)
  if directory then
    table.insert(git_roots, directory .. '/Git')
  end
end
local local_app_data = os.getenv('LOCALAPPDATA')
if local_app_data then
  table.insert(git_roots, local_app_data .. '/Programs/Git')
end

local git_candidates = {}
for _, root in ipairs(git_roots) do
  table.insert(git_candidates, root .. '/cmd/git.exe')
end
local git_executable = find_executable('git', git_candidates)
-- Git dari PATH juga dapat berasal dari instalasi portabel di luar Program Files.
if git_executable and is_windows then
  local root = git_executable:match('^(.*)[/\\][^/\\]+[/\\][^/\\]+$')
  if root then
    table.insert(git_roots, 1, root)
  end
end

local bash_executable
if is_windows then
  -- Jangan memilih bash.exe milik WSL sebagai pengganti Git Bash.
  for _, root in ipairs(git_roots) do
    local path = root .. '/bin/bash.exe'
    if file_exists(path) then
      bash_executable = path
      break
    end
  end
else
  bash_executable = find_executable('bash')
end

-- Bangun tabel biasa terlebih dahulu: config_builder mengonversi nilai tabel.
local launch_menu = {}
local function register_shell(label, executable, arguments)
  if not executable then
    return
  end
  local args = { executable }
  for _, argument in ipairs(arguments or {}) do
    table.insert(args, argument)
  end
  table.insert(launch_menu, {
    label = label, args = args, cwd = home, domain = { DomainName = 'local' },
  })
end
register_shell('Git Bash', bash_executable, { '-i', '-l' })
register_shell('PowerShell 7', find_executable('pwsh'), { '-NoLogo' })
if is_windows then
  local system_root = os.getenv('SystemRoot') or 'C:/Windows'
  register_shell('Windows PowerShell', find_executable('powershell', {
    system_root .. '/System32/WindowsPowerShell/v1.0/powershell.exe',
  }), { '-NoLogo' })
  register_shell('CMD', find_executable('cmd', { system_root .. '/System32/cmd.exe' }))
end
config.launch_menu = launch_menu
config.default_cwd = home
if launch_menu[1] then
  config.default_prog = launch_menu[1].args
  if not bash_executable then
    wezterm.log_warn('Git Bash tidak ditemukan; shell utama: ' .. launch_menu[1].label)
  end
end

-- ================================
-- PALET SOFT-CONTRAST: TEKS UTAMA NETRAL, AKSEN TIDAK MENYILAUKAN
-- ================================
-- ANSI 0 tetap gelap untuk aplikasi yang memakainya sebagai background.
-- ANSI 8 (bright black) sengaja lebih terang agar komentar/status terbaca.
-- Aplikasi truecolor (misalnya tema Neovim) mengatur warna teksnya sendiri.
local colors = {
  foreground = '#d8dee9',
  background = '#161b26',
  cursor_bg = '#e6b17e',
  cursor_fg = '#10151e',
  cursor_border = '#e6b17e',
  compose_cursor = '#e6c384',
  selection_fg = '#edf2f7',
  selection_bg = '#344563',
  ansi = {
    '#10151e', '#f08f9c', '#a3c995', '#e6c384',
    '#91b9ed', '#c4a7e7', '#8bd5ca', '#cdd6e3',
  },
  brights = {
    '#a4b0c3', '#f5a6b2', '#b5d9a7', '#f0d49a',
    '#accbf5', '#d5bdf2', '#a2e1d8', '#edf2f7',
  },
  tab_bar = { background = '#10151e' },
  scrollbar_thumb = '#66778f',
  split = '#a4b0c3',
  copy_mode_active_highlight_bg = { Color = '#e6c384' },
  copy_mode_active_highlight_fg = { Color = '#10151e' },
  copy_mode_inactive_highlight_bg = { Color = '#344563' },
  copy_mode_inactive_highlight_fg = { Color = '#edf2f7' },
  quick_select_label_bg = { Color = '#e6b17e' },
  quick_select_label_fg = { Color = '#10151e' },
  quick_select_match_bg = { Color = '#8bd5ca' },
  quick_select_match_fg = { Color = '#10151e' },
}
config.colors = colors

-- ================================
-- BACKGROUND OPSIONAL
-- ================================
if background_image ~= '' then
  local absolute = background_image:match('^[/\\]')
    or background_image:match('^%a:[/\\]')
  local path = absolute and background_image or (wezterm.config_dir .. '/' .. background_image)
  if file_exists(path) then
    config.background = {
      -- Dasar opaque mencegah teks/jendela desktop bocor melalui gambar.
      { source = { Color = colors.background }, width = '100%', height = '100%', opacity = 1.0 },
      {
        source = { File = path },
        hsb = { brightness = 0.3, saturation = 0.8 },
        opacity = 0.7,
        attachment = 'Fixed',
        repeat_x = 'NoRepeat', repeat_y = 'NoRepeat',
        horizontal_align = 'Center', vertical_align = 'Middle',
      },
      { source = { Color = colors.background }, width = '100%', height = '100%', opacity = 0.6 },
    }
  else
    wezterm.log_warn('Background tidak ditemukan; memakai warna solid: ' .. path)
  end
end

-- ================================
-- FONT, WINDOW & TAB BAR
-- ================================
config.font = wezterm.font_with_fallback { font_family, 'JetBrains Mono' }
-- Bold tetap memakai bright ANSI: output black+bold tidak menjadi tak terbaca.
config.bold_brightens_ansi_colors = true
config.font_size = 14.0
config.window_background_opacity = 1.0
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'TITLE | RESIZE'
config.default_cursor_style = 'BlinkingBlock'
config.enable_scroll_bar = true
config.scrollback_lines = 10000
-- Opsi wajib tabline diatur langsung; apply_to_config plugin juga menghapus
-- padding/dekorasi window, jadi tidak digunakan.
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.tab_max_width = tab_title_width
config.hyperlink_rules = wezterm.default_hyperlink_rules()
config.window_close_confirmation = 'AlwaysPrompt'
config.skip_close_confirmation_for_processes_named = {
  'bash', 'bash.exe', 'sh', 'sh.exe', 'zsh', 'fish',
  'cmd.exe', 'pwsh.exe', 'powershell.exe',
}

-- ================================
-- TAB BARU LOKAL SELALU DI HOME
-- ================================
local new_home_tab = act.SpawnCommandInNewTab {
  domain = { DomainName = 'local' },
  args = config.default_prog,
  cwd = home,
}
wezterm.on('new-tab-button-click', function(window, pane, button)
  if button == 'Left' then
    window:perform_action(new_home_tab, pane)
    return false
  end
  return true
end)

-- ================================
-- KOMPONEN TABLINE: GIT LOKAL
-- ================================
local function basename(path)
  return path:match('[^/\\]+$') or path
end

local function local_directory(pane)
  if pane:get_domain_name() ~= 'local' then
    return nil
  end
  local process = basename(pane:get_foreground_process_name() or ''):lower():gsub('%.exe$', '')
  if process == 'ssh' or process == 'mosh' or process == 'wsl' or process == 'wslhost' then
    return nil
  end
  local cwd = pane:get_current_working_dir()
  if not cwd or cwd.scheme ~= 'file' then
    return nil
  end
  local host = (cwd.host or ''):lower()
  if host ~= '' and host ~= 'localhost' and host ~= wezterm.hostname():lower() then
    return nil
  end
  local path = cwd.file_path
  if not path or path == '' then
    return nil
  end
  if is_windows then
    -- URL file:///C:/folder -> C:/folder, bukan /C:/folder untuk git.exe.
    path = path:gsub('^/([A-Za-z]:[/\\])', '%1')
  end
  return path
end

local function run_git(directory, arguments)
  local command = { git_executable, '-C', directory }
  for _, argument in ipairs(arguments) do
    table.insert(command, argument)
  end
  local invoked, success, stdout, stderr = pcall(wezterm.run_child_process, command)
  if not invoked then
    return false, '', tostring(success)
  end
  return success, stdout:gsub('%s+$', ''), stderr
end

local function git_status(directory)
  if not git_executable then
    return 'Git unavailable', true
  end
  -- symbolic-ref juga berhasil untuk branch baru yang belum mempunyai commit.
  local success, branch, stderr = run_git(directory, { 'symbolic-ref', '--quiet', '--short', 'HEAD' })
  if success then
    return nf.pl_branch .. ' ' .. branch, false
  end
  if stderr == '' then
    local detached, commit, detached_error = run_git(directory, { 'rev-parse', '--short', 'HEAD' })
    if detached then
      return nf.pl_branch .. ' detached:' .. commit, false
    end
    stderr = detached_error
  end
  if stderr:find('not a git repository', 1, true) then
    return '', false
  end
  if stderr:find('dubious ownership', 1, true) then
    return 'Git: ownership', true, stderr
  end
  return 'Git: error', true, stderr
end

-- Tabline merespons mode tiap 500 ms; Git dibatasi satu cek per 3 detik/window.
config.status_update_interval = 500
local git_by_window = {}
local function git_component(window, pane)
  local directory = local_directory(pane)
  if not directory then
    return ''
  end
  local id, now = window:window_id(), os.time()
  local cached = git_by_window[id]
  if not cached or cached.directory ~= directory or now - cached.checked_at >= 3 then
    local status, failed, detail = git_status(directory)
    if detail and (not cached or detail ~= cached.detail) then
      wezterm.log_warn('Status Git: ' .. detail)
    end
    cached = {
      directory = directory, checked_at = now, detail = detail,
      text = status == '' and '' or wezterm.format {
        { Foreground = { Color = failed and colors.ansi[2] or colors.cursor_bg } },
        { Text = ' ' .. wezterm.truncate_right(status, 24) .. ' ' },
      },
    }
    git_by_window[id] = cached
  end
  return cached.text
end

-- ================================
-- TABLINE: RENAME MANUAL > FOLDER, IKON PROSES, MODE & WORKSPACE
-- ================================
local process_icons = {
  bash = nf.md_console, sh = nf.md_console, zsh = nf.md_console, fish = nf.md_console,
  powershell = nf.md_console, pwsh = nf.md_console, cmd = nf.md_console,
  vim = nf.dev_vim, nvim = nf.dev_vim, node = nf.dev_nodejs_small,
  python = nf.dev_python, python3 = nf.dev_python, git = nf.dev_git,
}
local function tab_title(tab, pane)
  local title = tab.tab_title
  if not title or title == '' then
    title = pane.title
    local cwd = pane.current_working_dir
    if cwd and cwd.scheme == 'file' and cwd.file_path then
      local path = cwd.file_path:gsub('[/\\]+$', '')
      title = path ~= '' and basename(path) or cwd.file_path
    end
    local process = basename(pane.foreground_process_name or ''):lower():gsub('%.exe$', '')
    local icon = process_icons[process]
    if process ~= '' then
      title = (icon or process) .. ' ' .. title
    end
  end
  return ' ' .. wezterm.truncate_right(title, 20) .. ' '
end

local tabline = wezterm.plugin.require 'https://github.com/michaelbrusegard/tabline.wez'
tabline.setup {
  options = {
    theme = colors,
    theme_overrides = {
      normal_mode = {
        a = { fg = colors.ansi[1], bg = colors.ansi[7] },
        b = { fg = colors.ansi[7], bg = '#252e40' },
        c = { fg = colors.foreground, bg = colors.ansi[1] },
      },
      resize_mode = {
        a = { fg = colors.cursor_fg, bg = colors.cursor_bg },
        b = { fg = colors.cursor_bg, bg = '#252e40' },
        c = { fg = colors.foreground, bg = colors.ansi[1] },
      },
      tab = {
        active = { fg = colors.cursor_fg, bg = colors.cursor_bg },
        inactive = { fg = '#a4b0c3', bg = colors.ansi[1] },
        inactive_hover = { fg = colors.ansi[7], bg = '#252e40' },
      },
    },
    component_separators = { left = '', right = '' },
  },
  sections = {
    tabline_a = {
      { 'mode', fmt = function(mode, window)
        return window:leader_is_active() and 'LEADER' or (mode == 'NORMAL' and 'CODE' or mode)
      end },
    },
    tabline_b = {
      { 'workspace', cond = function(window) return window:active_workspace() ~= 'default' end,
        fmt = function(name) return wezterm.truncate_right(name, 12) end },
    },
    tabline_c = {},
    tab_active = { 'index', tab_title, { 'zoomed', padding = 0 } },
    tab_inactive = { 'index', tab_title },
    tabline_x = { git_component },
    tabline_y = { { 'datetime', style = '%H:%M' } },
    tabline_z = {
      { 'domain', cond = function(window)
        return window:active_pane():get_domain_name() ~= 'local'
      end },
    },
  },
}

-- ================================
-- KEYBINDING (DEFAULT TETAP AKTIF)
-- ================================
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1500 }
config.keys = {
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },
  { key = 'o', mods = 'CTRL|SHIFT', action = act.PaneSelect { mode = 'Activate' } },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },
  { key = 't', mods = 'CTRL|SHIFT', action = new_home_tab },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS' } },
  {
    key = 'r', mods = 'CTRL|SHIFT|ALT',
    action = act.PromptInputLine {
      description = 'Nama tab baru (kosong = otomatis):',
      action = wezterm.action_callback(function(window, _, line)
        if line ~= nil then
          window:active_tab():set_title(line)
        end
      end),
    },
  },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  -- Leader = Ctrl+Space, lepaskan, lalu tekan tombol berikut.
  { key = 'Space', mods = 'LEADER|CTRL', action = act.SendKey { key = 'Space', mods = 'CTRL' } },
  { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'd', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'o', mods = 'LEADER', action = act.PaneSelect { mode = 'Activate' } },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = 't', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|TABS' } },
  { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  {
    key = 's', mods = 'LEADER',
    action = act.PromptInputLine {
      description = 'Workspace baru (kosong = batal):',
      action = wezterm.action_callback(function(window, pane, line)
        if line and line:find('%S') then
          window:perform_action(act.SwitchToWorkspace {
            name = line, spawn = { cwd = local_directory(pane) or home },
          }, pane)
        end
      end),
    },
  },
  { key = 'f', mods = 'LEADER', action = act.Search { CaseInSensitiveString = '' } },
  { key = 'q', mods = 'LEADER', action = act.QuickSelect },
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  { key = 'r', mods = 'LEADER', action = act.ActivateKeyTable {
    name = 'resize_mode', one_shot = false, timeout_milliseconds = 5000, until_unknown = true,
  } },
}

-- Enter/Esc, tombol yang tidak dipetakan, atau 5 detik idle keluar dari resize.
config.key_tables = {
  resize_mode = {
    { key = 'h', action = act.AdjustPaneSize { 'Left', 3 } },
    { key = 'j', action = act.AdjustPaneSize { 'Down', 3 } },
    { key = 'k', action = act.AdjustPaneSize { 'Up', 3 } },
    { key = 'l', action = act.AdjustPaneSize { 'Right', 3 } },
    { key = 'LeftArrow', action = act.AdjustPaneSize { 'Left', 3 } },
    { key = 'DownArrow', action = act.AdjustPaneSize { 'Down', 3 } },
    { key = 'UpArrow', action = act.AdjustPaneSize { 'Up', 3 } },
    { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 3 } },
    { key = 'Escape', action = act.PopKeyTable },
    { key = 'Enter', action = act.PopKeyTable },
  },
}

-- ================================
-- MOUSE: PASTE LANGSUNG, KLIK LINK ATAU DRAG SELEKSI
-- ================================
config.mouse_bindings = {
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = act.PasteFrom 'Clipboard' },
  -- Binding kiri bawaan membedakan klik link dengan drag untuk copy.
}

return config
