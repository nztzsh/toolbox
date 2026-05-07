-- vanilla nvim 0.12+ config. native vim.pack, no plugin manager.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/sindrets/diffview.nvim",
})

require("diffview").setup({
  default_args = {
    DiffviewOpen = { "--untracked-files=true" },
  },
})

-- contextual cheatsheet via winbar. shows only keys applicable to active panel
-- plus general diffview nav. press g? inside view for full help.
local hints = {
  DiffviewFiles = table.concat({
    "%#DiffviewWinbarLabel#[file panel]%* ",
    "j/k:move  <CR>/o:open  -:stage  S:stage-all  U:unstage-all  X:restore  R:refresh  i:tree  ",
    "%#DiffviewWinbarSep#│%* <Tab>/<S-Tab>:next/prev  <leader>e:focus  <leader>b:toggle  g?:help",
  }),
  DiffviewFileHistory = table.concat({
    "%#DiffviewWinbarLabel#[history]%* ",
    "j/k:move  <CR>/o:open  y:copy-hash  L:open-log  ",
    "%#DiffviewWinbarSep#│%* <Tab>/<S-Tab>:next/prev  <leader>e:focus  g?:help",
  }),
  diff = table.concat({
    "%#DiffviewWinbarLabel#[diff]%* ",
    "]c/[c:next/prev-hunk  ]x/[x:next/prev-conflict  dp:put  do:get  ",
    "%#DiffviewWinbarSep#│%* <Tab>/<S-Tab>:next/prev-file  <leader>e:focus-panel  g<C-x>:cycle-layout",
  }),
}

vim.api.nvim_set_hl(0, "DiffviewWinbarLabel", { link = "Title", default = true })
vim.api.nvim_set_hl(0, "DiffviewWinbarSep", { link = "Comment", default = true })

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local hint = hints[ft]
    -- diff buffers: any buffer with diff option set inside a diffview tab
    if not hint and vim.wo.diff then
      hint = hints.diff
    end
    if hint then
      vim.wo.winbar = hint
    end
  end,
})
