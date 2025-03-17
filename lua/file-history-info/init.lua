local ret_func = {}


local file_info_records_augroup = vim.api.nvim_create_augroup("custom_file_info_augroup", {clear = true})
ALL_FILE_HISTORY_DATA = {}


local OS_FILE_SEP = package.config:sub(1, 1)
local PYTHON_PATH_SCRIPT = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'scripts' .. OS_FILE_SEP
local DATA_DIR_PATH = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'data' .. OS_FILE_SEP
local PYTHON_MAIN_CMD = 'python'

local PYTHON_FILE_ADD_NEW_FILE_INFO = 'add_new_file_info.py'
local PYTHON_FILE_CHECK_DB = 'check_db_table.py'
local PYTHON_FILE_GET_FILE_HISTORY = 'get_all_file_history.py'
local DATA_DB_FILENAME = 'data_storage.db'



local function escape_pattern(string_val)
    return string_val:gsub("([^%w])", "%%%1")
end


local function check_db_table_exists ()
    local cmd_to_run = ' ' .. PYTHON_MAIN_CMD .. ' ./' .. PYTHON_FILE_CHECK_DB .. ' --db_path ' .. DATA_DIR_PATH .. DATA_DB_FILENAME
    local job_check_db_table = vim.fn.jobstart(
	cmd_to_run,
	{
	    stdout_buffered = true,
	    cwd = PYTHON_PATH_SCRIPT,
	}
    )
    vim.fn.jobwait({job_check_db_table}, -1)
end


local function is_substring_found_in_string (main_string, sub_string, case_sensitive)
    local m_string
    local s_string

    if case_sensitive then
	m_string = main_string
	s_string = sub_string
    else
	m_string = string.lower(main_string)
	s_string = string.lower(sub_string)
    end

    for match_str in string.gmatch(m_string, s_string) do
	return true
    end
    return false
end


local function update_file_history_list(main_file_history_win, filter_string)
    local data_list = {}
    for _, values in ipairs(ALL_FILE_HISTORY_DATA.data) do
	if filter_string then
	    -- TODO: Add filter string
	    if is_substring_found_in_string(values.RelativeFilePath, filter_string, false) then
		table.insert(data_list, values.CreatedTimestamp .. " | " .. values.RelativeFilePath)
	    end
	else
	    table.insert(data_list, values.CreatedTimestamp .. " | " .. values.RelativeFilePath)
	end
    end

    vim.api.nvim_buf_set_lines(main_file_history_win.bufnr, 0, -1, false, data_list)
end


local function read_all_file_history (main_file_history_win, offset_hour)
    local cmd_to_run = ' ' .. PYTHON_MAIN_CMD .. ' ./' .. PYTHON_FILE_GET_FILE_HISTORY ..  ' --offset_hour ' .. offset_hour .. ' --db_path ' .. DATA_DIR_PATH .. DATA_DB_FILENAME
    local job_read_all_file_history = vim.fn.jobstart(
	cmd_to_run,
	{
	    stdout_buffered = true,
	    cwd = PYTHON_PATH_SCRIPT,
	    on_stdout = function (chanid, data, name)
		local arr_data = {data[1]}
		ALL_FILE_HISTORY_DATA = vim.fn.json_decode(arr_data[1])

		update_file_history_list(main_file_history_win)
	    end,
	}
    )
    vim.fn.jobwait({job_read_all_file_history}, -1)
end


local function add_new_file_info (full_file_path, relative_file_path, current_working_dir, git_top_level_path, git_repo_remote_url)
    local cmd_to_run = ' ' .. PYTHON_MAIN_CMD .. ' ./' .. PYTHON_FILE_ADD_NEW_FILE_INFO .. ' --full_file_path "' .. full_file_path .. '" --relative_file_path "' .. relative_file_path .. '" --current_working_dir "' .. current_working_dir .. '" --git_top_level_path "' .. git_top_level_path .. '" --git_repo_remote_url "' .. git_repo_remote_url .. '" --db_path ' .. DATA_DIR_PATH .. DATA_DB_FILENAME
    local job_add_new_file_info = vim.fn.jobstart(
	cmd_to_run,
	{
	    stdout_buffered = true,
	    cwd = PYTHON_PATH_SCRIPT,
	}
    )
    vim.fn.jobwait({job_add_new_file_info}, -1)
end


local function get_file_info ()
    local full_file_path = vim.fn.expand('%:p')
    --local relative_file_path = vim.fn.expand('%:p.')
    local current_working_dir = vim.fn.getcwd()
    local current_git_top_path = vim.fn.system('git rev-parse --show-toplevel')
    local current_git_remote_url = vim.fn.system('git config --get remote.origin.url')

    -- Check git folder
    if current_git_top_path:find('fatal: not a git repository') then
	current_git_top_path = " "
     else
	current_git_top_path = current_git_top_path:gsub("%s+$", "")
    end

    if current_git_remote_url == "" then
	current_git_remote_url = " "
    else
	current_git_remote_url = current_git_remote_url:gsub("%s+$", "")
    end

    -- Normalize path seperation between OS
    full_file_path = full_file_path:gsub("\\", "/")
    current_working_dir = current_working_dir:gsub("\\", "/")

    local escaped_current_working_dir = escape_pattern(current_working_dir)
    local relative_file_path = full_file_path:gsub("^" .. escaped_current_working_dir .. "/", "")

    add_new_file_info(full_file_path, relative_file_path, current_working_dir, current_git_top_path, current_git_remote_url)
end



local function create_floating_windows (input_buffer, opt, should_enter_win)
    win_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(win_buf, 0, - 1, false, input_buffer)

    vim.cmd "setlocal nocursorcolumn"
    local win_info = {
	state = 'start',
	bufnr = win_buf,
	winnr = vim.api.nvim_open_win(win_buf, should_enter_win, opt)
    }
    vim.api.nvim_win_set_option(win_info.winnr, "winblend", 10)
    vim.api.nvim_win_set_option(win_info.winnr, "cursorline", true)

    return win_info
end


local function is_current_window_in_table_win_list (all_table_id)
    local current_window_id = vim.fn.win_getid()
    local isFocused = false

    for _, value in ipairs(all_table_id) do
	if value.winnr == current_window_id then
	    isFocused = true
	    break
	end
    end
    return isFocused
end


local function remove_autocmd_group (augroup_id)
    vim.api.nvim_clear_autocmds (
	{
	    group = augroup_id,
	}
    )
end


local function close_all_floating_window (all_table_id)
    for _, value in ipairs(all_table_id) do
	if value.state == 'start' then
	    vim.api.nvim_win_close(value.winnr, true)
	    value.state = 'end'
	end
    end
end


function ret_func.setup_start()
    local autocmd_id_buf_read_post = vim.api.nvim_create_autocmd(
	"BufReadPost",
	{
	    group = file_info_records_augroup,
	    callback = function ()
		check_db_table_exists()
		get_file_info()
	    end,
	}
    )
end


function ret_func.show_file_history(user_settings)
    local user_curr_focused_win = vim.fn.win_getid()

    local main_file_history_win = create_floating_windows(
	{},
	{
	    title = 'File History',
	    relative = "editor",
	    focusable = true,
	    width = 80,
	    height = 32,
	    row = 5,
	    col = 10,
	    style = "minimal",
	    border = 'single',
	},
	true
    )

    local cwd_win = create_floating_windows(
	{},
	{
	    title = 'CWD',
	    relative = "editor",
	    focusable = true,
	    width = 100,
	    height = 32,
	    row = 5,
	    col = 92,
	    border = 'single',
	},
	false
    )

    local all_floating_window_id = {}
    table.insert(all_floating_window_id, main_file_history_win)
    table.insert(all_floating_window_id, cwd_win)

    local autocmd_id_enter_buf = vim.api.nvim_create_autocmd(
	"BufEnter",
	{
	    group = file_info_records_augroup,
	    callback = function ()
		if is_current_window_in_table_win_list(all_floating_window_id) == false then
		    vim.api.nvim_set_current_win(user_curr_focused_win)
		    remove_autocmd_group(file_info_records_augroup)
		    close_all_floating_window(all_floating_window_id)
		end
	    end
	}
    )

    check_db_table_exists()
    read_all_file_history(main_file_history_win, user_settings.offset_hour)
end


return ret_func
