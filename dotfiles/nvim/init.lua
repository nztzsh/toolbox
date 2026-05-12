-- vanilla nvim 0.12+ config. native vim.pack, no plugin manager.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.termguicolors = true
vim.opt.background = "dark"

vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/folke/tokyonight.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
})

require("tokyonight").setup({
  style = "night",
  transparent = true,
  styles = {
    sidebars = "transparent",
    floats = "transparent",
    comments = { italic = true },
    keywords = { italic = false },
  },
})
pcall(vim.cmd.colorscheme, "tokyonight-night")

-- treesitter: auto-install common parsers, enable highlight
pcall(function()
  require("nvim-treesitter.configs").setup({
    ensure_installed = {
      "bash", "c", "cpp", "css", "go", "html", "javascript", "json", "lua",
      "markdown", "markdown_inline", "python", "rust", "toml", "tsx",
      "typescript", "vim", "vimdoc", "yaml", "diff", "git_config", "gitcommit",
      "gitignore", "regex",
    },
    auto_install = true,
    highlight = { enable = true, additional_vim_regex_highlighting = false },
    indent = { enable = true },
  })
end)

-- transparent background — inherit terminal's dark
local function apply_theme()
  -- transparency
  vim.api.nvim_set_hl(0, "Normal",       { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalNC",     { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalFloat",  { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "SignColumn",   { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "EndOfBuffer",  { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "LineNr",       { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "WinBar",       { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "WinBarNC",     { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLine",   { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "VertSplit",    { bg = "NONE", ctermbg = "NONE" })
  vim.api.nvim_set_hl(0, "WinSeparator", { bg = "NONE", ctermbg = "NONE" })

  -- Claude Code-style diff colors
  -- added: muted green tint
  vim.api.nvim_set_hl(0, "DiffAdd",        { bg = "#1f3a1f" })
  vim.api.nvim_set_hl(0, "GitSignsAdd",    { fg = "#a3d977", bg = "NONE" })
  vim.api.nvim_set_hl(0, "GitSignsAddLn",  { bg = "#1f3a1f" })
  vim.api.nvim_set_hl(0, "GitSignsAddInline", { bg = "#2d5a2d", fg = "#d4f5b8" })
  -- changed: muted yellow
  vim.api.nvim_set_hl(0, "DiffChange",     { bg = "#3a341f" })
  vim.api.nvim_set_hl(0, "DiffText",       { bg = "#5a4a1f", fg = "#f5e0a3" })
  vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#e5c07b", bg = "NONE" })
  vim.api.nvim_set_hl(0, "GitSignsChangeLn", { bg = "#3a341f" })
  vim.api.nvim_set_hl(0, "GitSignsChangeInline", { bg = "#5a4a1f", fg = "#f5e0a3" })
  -- deleted: muted red
  vim.api.nvim_set_hl(0, "DiffDelete",     { bg = "#3a1f1f", fg = "#e5797d" })
  vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#e5797d", bg = "NONE" })
  vim.api.nvim_set_hl(0, "GitSignsDeleteLn", { bg = "#3a1f1f" })
  vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLn", { bg = "#3a1f1f", fg = "#e5797d" })
  vim.api.nvim_set_hl(0, "GitSignsDeleteInline", { bg = "#5a2929", fg = "#f5b8b8" })

  -- file panel highlights
  vim.api.nvim_set_hl(0, "ReviewPanelAdd",    { fg = "#a3d977", bold = true })
  vim.api.nvim_set_hl(0, "ReviewPanelMod",    { fg = "#e5c07b", bold = true })
  vim.api.nvim_set_hl(0, "ReviewPanelDel",    { fg = "#e5797d", bold = true })
  vim.api.nvim_set_hl(0, "ReviewPanelNew",    { fg = "#7dd3fc", bold = true })
  vim.api.nvim_set_hl(0, "ReviewPanelHeader", { fg = "#9ca3af", italic = true })
  vim.api.nvim_set_hl(0, "ReviewWinbarLabel", { fg = "#c4b5fd", bold = true })
  vim.api.nvim_set_hl(0, "ReviewWinbarSep",   { fg = "#4b5563" })
end

apply_theme()
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_theme })

-- never fold unchanged lines
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

require("gitsigns").setup({
  signcolumn = true,
  numhl = false,
  linehl = true,
  word_diff = true,
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "▁" },
    topdelete    = { text = "▔" },
    changedelete = { text = "▎" },
    untracked    = { text = "▎" },
  },
  preview_config = { border = "rounded" },
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map("n", "]c", function() gs.nav_hunk("next") end, "next hunk")
    map("n", "[c", function() gs.nav_hunk("prev") end, "prev hunk")
    map("n", "<leader>hp", gs.preview_hunk, "preview hunk")
    map("n", "<leader>hr", gs.reset_hunk, "reset hunk")
    map("n", "<leader>hs", gs.stage_hunk, "stage hunk")
    map("n", "<leader>td", gs.toggle_deleted, "toggle deleted lines")
    map("n", "<leader>tw", gs.toggle_word_diff, "toggle word diff")
  end,
})

-- show removed lines inline as virtual lines automatically
vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsUpdate",
  callback = function()
    pcall(require("gitsigns").toggle_deleted, true)
  end,
})

---------------------------------------------------------------------------
-- Review file panel: left sidebar lists changed/added/deleted files
---------------------------------------------------------------------------

local Review = {}
Review.panel_buf = nil
Review.panel_win = nil
Review.main_win = nil
Review.entries = {} -- { {status="M", path="..."}, ... }

local STATUS_GROUP = {
  M = "ReviewPanelMod",
  A = "ReviewPanelAdd",
  D = "ReviewPanelDel",
  ["?"] = "ReviewPanelNew",
  R = "ReviewPanelMod",
  C = "ReviewPanelMod",
  U = "ReviewPanelDel",
}

local STATUS_LABEL = {
  M = "modified",
  A = "added",
  D = "deleted",
  ["?"] = "untracked",
  R = "renamed",
  C = "copied",
  U = "conflict",
}

local function collect_entries()
  local entries = {}
  -- staged + unstaged changes vs HEAD
  local diff = vim.fn.systemlist("git -c core.quotePath=false diff --name-status HEAD")
  for _, line in ipairs(diff) do
    local status, path = line:match("^(%S)%s+(.+)$")
    if status and path then
      table.insert(entries, { status = status, path = path })
    end
  end
  -- untracked
  local untracked = vim.fn.systemlist("git -c core.quotePath=false ls-files --others --exclude-standard")
  for _, path in ipairs(untracked) do
    if path ~= "" then
      table.insert(entries, { status = "?", path = path })
    end
  end
  return entries
end

local function render_panel()
  if not Review.panel_buf or not vim.api.nvim_buf_is_valid(Review.panel_buf) then return end
  Review.entries = collect_entries()

  local groups = { M = {}, A = {}, ["?"] = {}, D = {}, R = {}, C = {}, U = {} }
  local order = { "M", "A", "?", "D", "R", "C", "U" }
  for _, e in ipairs(Review.entries) do
    table.insert(groups[e.status] or groups.M, e)
  end

  local lines = {}
  local hl = {} -- { {line, group, col_start, col_end} }
  local line_to_entry = {}
  local total = 0
  for _, e in ipairs(Review.entries) do total = total + 1 end
  table.insert(lines, string.format(" %d changed file%s", total, total == 1 and "" or "s"))
  table.insert(hl, { #lines - 1, "ReviewPanelHeader", 0, -1 })
  table.insert(lines, "")

  for _, status in ipairs(order) do
    local grp = groups[status]
    if #grp > 0 then
      local header = string.format(" %s (%d)", STATUS_LABEL[status], #grp)
      table.insert(lines, header)
      table.insert(hl, { #lines - 1, "ReviewPanelHeader", 0, -1 })
      for _, e in ipairs(grp) do
        local marker = status
        local row = string.format("  %s  %s", marker, e.path)
        table.insert(lines, row)
        local lnum = #lines - 1
        table.insert(hl, { lnum, STATUS_GROUP[status] or "ReviewPanelMod", 2, 3 })
        line_to_entry[lnum + 1] = e -- 1-indexed for cursor
      end
      table.insert(lines, "")
    end
  end

  Review.line_to_entry = line_to_entry

  vim.bo[Review.panel_buf].modifiable = true
  vim.api.nvim_buf_set_lines(Review.panel_buf, 0, -1, false, lines)
  vim.bo[Review.panel_buf].modifiable = false

  local ns = vim.api.nvim_create_namespace("ReviewPanel")
  vim.api.nvim_buf_clear_namespace(Review.panel_buf, ns, 0, -1)
  for _, h in ipairs(hl) do
    vim.api.nvim_buf_add_highlight(Review.panel_buf, ns, h[2], h[1], h[3], h[4])
  end
end

local function ensure_main_win()
  if Review.main_win and vim.api.nvim_win_is_valid(Review.main_win) then
    return Review.main_win
  end
  -- find first non-panel window
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= Review.panel_win then
      Review.main_win = w
      return w
    end
  end
  return nil
end

local function open_entry_under_cursor()
  local lnum = vim.api.nvim_win_get_cursor(Review.panel_win)[1]
  local entry = Review.line_to_entry and Review.line_to_entry[lnum]
  if not entry then return end
  local win = ensure_main_win()
  if not win then return end
  vim.api.nvim_set_current_win(win)
  if entry.status == "D" then
    -- file no longer exists in working tree — show via git show HEAD:path
    vim.cmd("enew")
    local content = vim.fn.systemlist("git show HEAD:" .. vim.fn.shellescape(entry.path))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.api.nvim_buf_set_name(0, entry.path .. " [deleted]")
    vim.bo.modifiable = false
  else
    vim.cmd("edit " .. vim.fn.fnameescape(entry.path))
  end
end

function Review.open()
  -- close existing panel if any
  if Review.panel_win and vim.api.nvim_win_is_valid(Review.panel_win) then
    vim.api.nvim_win_close(Review.panel_win, true)
  end

  Review.main_win = vim.api.nvim_get_current_win()

  -- left split for panel
  vim.cmd("topleft 40vsplit")
  Review.panel_win = vim.api.nvim_get_current_win()
  Review.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(Review.panel_win, Review.panel_buf)

  vim.bo[Review.panel_buf].buftype = "nofile"
  vim.bo[Review.panel_buf].bufhidden = "wipe"
  vim.bo[Review.panel_buf].swapfile = false
  vim.bo[Review.panel_buf].filetype = "ReviewPanel"
  vim.api.nvim_buf_set_name(Review.panel_buf, "Review")
  vim.wo[Review.panel_win].number = false
  vim.wo[Review.panel_win].relativenumber = false
  vim.wo[Review.panel_win].signcolumn = "no"
  vim.wo[Review.panel_win].wrap = false
  vim.wo[Review.panel_win].cursorline = true
  vim.wo[Review.panel_win].winfixwidth = true

  render_panel()

  local function bmap(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = Review.panel_buf, desc = desc, silent = true })
  end
  bmap("<CR>", open_entry_under_cursor, "open file")
  bmap("o", open_entry_under_cursor, "open file")
  bmap("R", function() render_panel() end, "refresh")
  bmap("q", function() vim.api.nvim_win_close(Review.panel_win, true) end, "close panel")
  bmap("j", "j", "down")
  bmap("k", "k", "up")

  -- jump to first entry, open it
  for lnum, _ in pairs(Review.line_to_entry or {}) do
    vim.api.nvim_win_set_cursor(Review.panel_win, { lnum, 0 })
    open_entry_under_cursor()
    break
  end
end

vim.api.nvim_create_user_command("Review", function() Review.open() end, {})

-- toggle focus between panel and main window
vim.keymap.set("n", "<leader>e", function()
  if not (Review.panel_win and vim.api.nvim_win_is_valid(Review.panel_win)) then
    return
  end
  local cur = vim.api.nvim_get_current_win()
  if cur == Review.panel_win then
    local target = ensure_main_win()
    if target then vim.api.nvim_set_current_win(target) end
  else
    Review.main_win = cur
    vim.api.nvim_set_current_win(Review.panel_win)
  end
end, { desc = "toggle focus review panel/main" })

-- winbar cheatsheet on file windows
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
  callback = function()
    if vim.bo.filetype == "ReviewPanel" then
      vim.wo.winbar = "%#ReviewWinbarLabel#[changed files]%* %#ReviewWinbarSep#│%* <CR>:open  R:refresh  q:close"
    elseif vim.bo.buftype == "" then
      vim.wo.winbar = table.concat({
        "%#ReviewWinbarLabel#[review]%* ",
        "%f  ",
        "%#ReviewWinbarSep#│%* ",
        "]c/[c:next/prev-hunk  <leader>hp:preview  <leader>td:toggle-deleted  <leader>tw:toggle-word-diff  <leader>e:focus-panel",
      })
    end
  end,
})
