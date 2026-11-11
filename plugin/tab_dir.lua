vim.keymap.set('n', '<leader>ts', function() require('tab_dir').saveTab() end, { desc = "Save the current tab" })
vim.keymap.set('n', '<leader>tl', function() require('tab_dir').loadTab() end, { desc = "Load a tab" })
vim.keymap.set('n', '<leader>tcb', function() require('tab_dir').createBar() end, { desc = "Create a bar for a tab" })
vim.keymap.set('n', '<leader>tfb', function() require('tab_dir').barFinalize() end,
  { desc = "Finalize a bar fo the tab" })
vim.keymap.set('n', '<leader>ttb', function() require('tab_dir').barToggle() end,
  { desc = "Toggle a bar to show or not show" })
