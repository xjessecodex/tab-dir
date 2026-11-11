# Tab-dir
This project allows you to save a neovim tab to a json file and to load it later.
It also allows you to set side-bars on all directions that are collapsible.

There are 5 main keybinds: (all start with `<leader>`)
- ts: save the tab, use existing name or create new name if new tab
- tl: load a tab, pops up dialogue asking for index with list of choices
- tcb: create a bar: pops up dialogue asking for right, left, top, or bottom bar
- tfb: finalize a bar: assign a buffer once buffer has been chosen using normal `:e` command
- ttb: toggle a bar: pop a bar open or close it, compatible with simple `:q` command
