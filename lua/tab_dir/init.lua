local M = {}

local defaults = {
  data_dir = vim.fn.stdpath('data') .. '/tab-dir/'
}

local opts = {}

-- Helper function for tabline render that filters floating windows
function M._filterFloatWins(winids)
  local nonFloats = {}
  for _, winid in pairs(winids) do
    if vim.api.nvim_win_get_config(winid).relative == "" then
      nonFloats[#nonFloats + 1] = winid
    end
  end
  return nonFloats
end

-- Render the tabline
function M.render()
  local s = '%#TabLineFill#'

  local curTabID = vim.api.nvim_get_current_tabpage()
  for _, tabID in pairs(vim.api.nvim_list_tabpages()) do
    if not vim.api.nvim_tabpage_is_valid(tabID) then break end
    local tabNum = vim.api.nvim_tabpage_get_number(tabID)

    s = s .. ((tabID == curTabID) and "%#TabLineSel#" or "%#TabLine#") -- Highlighing
    s = s .. " "
    s = s .. "%" .. tabNum .. "T"                                      -- Selectable
    s = s .. tabNum .. " "                                             -- Tab number

    local winids = M._filterFloatWins(vim.api.nvim_tabpage_list_wins(tabID))
    if #winids > 1 then
      s = s .. "<" .. (#winids) .. "W> "
    end

    -- Use name or buffer path
    local tabName = vim.t[tabID].name
    if tabName then
      s = s .. tabName
    else
      local window = vim.api.nvim_tabpage_get_win(tabID)
      local buffer = vim.api.nvim_win_get_buf(window)
      local bufname = vim.fn.bufname(buffer)
      if bufname == "" then
        s = s .. "[No name]"
      else
        local path = vim.fn.pathshorten(bufname)
        s = s .. path
      end
    end

    s = s .. " "
  end
  s = s .. '%#TabLineFill#'
  s = s .. "%="
  s = s .. "%" .. curTabID .. "X"
  s = s .. "X"
  return s
end

function M._recordTabInfo()
  -- Record all window configs in json dictionary
  local jsonDic = { windows = {} }
  local windows = vim.api.nvim_tabpage_list_wins(0)
  for _, window in ipairs(windows) do
    local bufName = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
    table.insert(jsonDic.windows, {
      bufName = bufName,
      config = vim.api.nvim_win_get_config(window)
    })
  end
  return jsonDic
end

function M._recordJsonDict(jsonDict)
  -- Ensure there is a data directory at the required location
  if not vim.fn.isdirectory(opts.data_dir) and not vim.fn.mkdir(opts.data_dir) then
    vim.notify("Could not create " .. opts.data_dir .. " directory, aborting.", vim.log.levels.ERROR)
    return false
  end

  -- Write the json dictionary to the file
  local path = opts.data_dir .. vim.t.name .. ".json"
  local fd = io.open(path, "w")
  if fd == nil then
    vim.notify("could not open " .. path .. " for writing", vim.log.levels.ERROR)
    return false
  end
  fd:write(vim.fn.json_encode(jsonDict))
  fd:close()
end

function M.saveTab()
  -- Ask for the tab name, use existing tabname if it's there
  if not vim.t.name then
    vim.ui.input({ prompt = "Enter new tab name: " }, function(input)
      vim.t.name = input
    end)
  end

  -- Record all window configs in json dictionary

  local currentJsonDict = M._readData(opts.data_dir .. vim.t.name .. ".json")
  local jsonDic = M._recordTabInfo()
  local newDict = vim.tbl_deep_extend('force', currentJsonDict, jsonDic)

  -- Save the info to a json file
  M._recordJsonDict(newDict)
end

function M._readData(fullDataFilePath)
  local fd = io.open(fullDataFilePath, "r")
  if (fd == nil) then
    vim.notify("Unable to read" .. fullDataFilePath .. " exiting...", vim.log.levels.ERROR)
    return false
  end
  local tabDict = vim.fn.json_decode(fd:read("*a"))
  fd:close()
  return tabDict
end

function M.loadTab()
  local lines = ""
  local i = 0
  local fileArr = {}

  -- Get all the names of files in the data directory and their indices
  for name, type in vim.fs.dir(opts.data_dir) do
    i = i + 1
    if not (type == "file" and name:match("%.json$")) then
      vim.notify("Invalid file " .. name .. " found in data directory", vim.log.levels.ERROR)
      return false
    end
    lines = lines .. i .. "\t" .. name .. "\n"
    table.insert(fileArr, name)
  end
  print(lines)

  -- Get the index of the file the person wants to get
  local fullDataFilePath = opts.data_dir
  vim.ui.input({ prompt = "Enter tab index (0-" .. i .. ") " }, function(input)
    input = tonumber(input)
    if not input or input < 1 or input > i then
      vim.notify("Invalid index input, try again", vim.log.levels.ERROR)
      return false
    end
    fullDataFilePath = fullDataFilePath .. fileArr[input]
    vim.cmd("messages clear")
  end)

  -- Read the json file he wants
  local tabDict = M._readData(fullDataFilePath)

  -- set the windows according to the desired configuration
  vim.cmd("tabnew")
  vim.t.name = vim.fn.fnamemodify(fullDataFilePath, ":t:r")
  local orig_window = vim.api.nvim_get_current_win()
  for _, window in ipairs(tabDict.windows) do
    local buf = vim.fn.bufnr(window.bufName, 1)
    window.config.win = orig_window
    vim.api.nvim_open_win(buf, false, window.config)
  end
  vim.api.nvim_win_close(orig_window, true)
end

function M.createBar()
  -- Check that it's a valid named tab
  if not vim.t.name then
    vim.notify("Not a saved tab, cannot add a bar.", vim.log.levels.ERROR)
    return false
  end

  -- Load the tab info
  local tabDict = M._readData(opts.data_dir .. vim.t.name .. ".json")

  -- Ask for bar type
  local barType = ""
  vim.ui.input({ prompt = "Enter bar type (b/t/r/l): " }, function(input)
    if not input:match("[lrtb]") then
      vim.notify(input .. " is not one of [btrl].. aborting.", vim.log.levels.ERROR)
      return false
    end
    barType = input
  end)

  -- Create the bar window
  local rows = vim.o.lines
  local cols = vim.o.columns
  local buf = vim.api.nvim_create_buf(false, true)

  local config
  if barType == "l" then
    config = { split = "left", width = math.floor(cols * 0.2), win = -1 }
  elseif barType == "r" then
    config = { split = "right", width = math.floor(cols * 0.2), win = -1 }
  elseif barType == "t" then
    config = { split = "above", height = math.floor(rows * 0.2), win = -1 }
  else
    config = { split = "below", height = math.floor(rows * 0.2), win = -1 }
  end

  local winID = vim.api.nvim_open_win(buf, true, config)

  -- save the configuration
  tabDict[barType] = {
    open = winID,
    config = config
  }
  M._recordJsonDict(tabDict)
end

function M.barFinalize()
  -- check we're in a valid named tab and read it's file
  if not vim.t.name then
    vim.notify("Not a saved tab, cannot add a bar.", vim.log.levels.ERROR)
    return false
  end
  local tabDict = M._readData(opts.data_dir .. vim.t.name .. ".json")

  -- Check we're in a bar and get the key of that bar
  local curWin = vim.api.nvim_get_current_win()
  local k = ""
  for key, val in pairs(tabDict) do
    if rawget(val, "open") ~= nil and val.open == curWin then
      k = key
    end
  end
  if k == "" then
    vim.notify("Not a bar, must finalize a bar", vim.log.levels.ERROR)
    return false
  end

  -- Set buffer name of bar
  local bufName = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(curWin))
  tabDict[k].bufName = bufName
  M._recordJsonDict(tabDict)
end

function M.barToggle()
  -- check we're in a valid named tab and read it's file
  if not vim.t.name then
    vim.notify("Not a saved tab, cannot add a bar.", vim.log.levels.ERROR)
    return false
  end
  local tabDict = M._readData(opts.data_dir .. vim.t.name .. ".json")

  -- Ask for which bar to toggle
  local barType
  vim.ui.input({ prompt = "Enter bar type (b/t/r/l): " }, function(input)
    if not input:match("[lrtb]") then
      vim.notify(input .. " is not one of [btrl].. aborting.", vim.log.levels.ERROR)
      return false
    end
    barType = input
  end)
  if barType == nil then
    vim.notify(input .. " is not one of [btrl].. aborting.", vim.log.levels.ERROR)
    return false
  end

  -- Check it has anything set
  if rawget(tabDict[barType], "open") == nil then
    vim.notify("Cannot toggle " .. barType .. " tab because it was never created", vim.log.levels.ERROR)
    return false
  end
  if tabDict[barType].open ~= -1 then -- Tab is open
    vim.api.nvim_win_close(tabDict[barType].open, false)
    tabDict[barType].open = -1
    M._recordJsonDict(tabDict)
  else --  tab is closed
    if rawget(tabDict[barType], "bufName") == nil then
      vim.notify("Cannot re-open " .. barType .. " tab because bufName was never set", vim.log.levels.ERROR)
      return false
    end
    local buf = vim.fn.bufnr(tabDict[barType].bufName, 1)
    local winID = vim.api.nvim_open_win(buf, false, tabDict[barType].config)
    tabDict[barType].open = winID
    M._recordJsonDict(tabDict)
  end
end

function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      if not vim.t.name then
        return false
      end
      local closed_win = tonumber(args.match)
      local tabDict = M._readData(opts.data_dir .. vim.t.name .. ".json")
      for key, val in pairs(tabDict) do
        if rawget(val, "open") ~= nil and val.open == closed_win then
          val.open = -1
          M._recordJsonDict(tabDict)
          return
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    callback = function()
      vim.api.nvim_set_hl(0, "TabLineSel", { fg = "#ffffff", bg = "#000000", bold = true, nocombine = true })
    end,
  })
  vim.opt.showtabline = 2
  vim.go.tabline = "%!v:lua.require'tab_dir'.render()"
end

return M
