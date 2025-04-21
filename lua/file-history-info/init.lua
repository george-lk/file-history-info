local ret_func = {}


local file_info_records_augroup = vim.api.nvim_create_augroup("custom_file_info_augroup", {clear = true})
ALL_FILE_HISTORY_DATA = {}
CWD_LIST_HISTORY_DATA = {}

local OS_FILE_SEP = package.config:sub(1, 1)
local PYTHON_PATH_SCRIPT = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'scripts' .. OS_FILE_SEP
local DATA_DIR_PATH = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'data' .. OS_FILE_SEP
local PYTHON_MAIN_CMD = 'python'

local PYTHON_FILE_ADD_NEW_FILE_INFO = 'add_new_file_info.py'
local PYTHON_FILE_CHECK_DB = 'check_db_table.py'
local PYTHON_FILE_GET_FILE_HISTORY = 'get_all_file_history.py'
local PYTHON_FILE_GET_CWD_LIST_HISTORY = 'get_cwd_list_history.py'
local DATA_DB_FILENAME = 'data_storage.db'


local function custom_trim(string_input)
    return (string_input:gsub("^%s*(.-)%s*$", "%1"))
end


local function custom_split_string (string_val, sep, optional_sep)
    local result_list = {}
    local regex_pattern = "([^"..sep.."]+)"

    if optional_sep == true then
	regex_pattern = "([^".. sep .."]*)".. sep .."?"
    end

    for str in string.gmatch(string_val, regex_pattern ) do
	table.insert(result_list, str)
    end
    return result_list
end


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


local function normalize_string_length(string_val, num_char)
    local final_str
    if #string_val > num_char then
	final_str = "..."
	local truncate_string_index = #string_val - num_char + #final_str
	for str_index = 1, #string_val do
	    if str_index > truncate_string_index then
		local curr_char = string.sub(string_val,str_index,str_index)
		final_str = final_str .. curr_char
	    end
	end
    else
	final_str = string_val
	if #string_val < num_char then
	    local string_padding_num = num_char - #string_val
	    for str_index = 1, string_padding_num do
		final_str = final_str .. " "
	    end
	end
    end
    return final_str
end


local function update_file_history_list(main_file_history_win, filter_string)
    local data_list = {}
    local id_str_length = 4
    local date_str_length = 19
    local cwd_str_length = 110
    local rel_file_path_str_length = 50
    for _, values in ipairs(ALL_FILE_HISTORY_DATA.data) do
	if filter_string then
	    -- TODO: Add filter string
	    if is_substring_found_in_string(values.RelativeFilePath, filter_string, false) then
		table.insert(data_list, values.CreatedTimestamp .. " | " .. values.RelativeFilePath)
	    end
	else
            local disp_id = normalize_string_length(tostring(values.Id), id_str_length)
            local disp_date = normalize_string_length(tostring(values.CreatedTimestamp), date_str_length)
            local disp_current_working_dir = normalize_string_length(values.CurrentWorkingDir, cwd_str_length)
            local disp_relative_file_path = normalize_string_length(values.RelativeFilePath, rel_file_path_str_length)

            table.insert(data_list,disp_id .. " | " .. disp_date .. " | " .. disp_current_working_dir .. " | " .. disp_relative_file_path .. " |")
	end
    end

    if main_file_history_win.bufnr_read_only == true then
        vim.api.nvim_buf_set_option(main_file_history_win.bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_option(main_file_history_win.bufnr, 'readonly', false)
    end
    vim.api.nvim_buf_set_lines(main_file_history_win.bufnr, 0, -1, false, data_list)
    if main_file_history_win.bufnr_read_only == true then
        vim.api.nvim_buf_set_option(main_file_history_win.bufnr, 'modifiable', false)
        vim.api.nvim_buf_set_option(main_file_history_win.bufnr, 'readonly', true)
    end

    vim.api.nvim_set_hl(0, "custom_all_file_history_view_column_id", {fg = "#99FF33"})
    vim.api.nvim_set_hl(0, "custom_all_file_history_view_column_date", {fg = "#3399FF"})
    vim.api.nvim_set_hl(0, "custom_all_file_history_view_column_cwd", {fg = "#f45eff"})
    vim.api.nvim_set_hl(0, "custom_all_file_history_view_column_rel_file_path", {fg = "#ff4f95"})

    local buffer_lines = vim.api.nvim_buf_line_count(main_file_history_win.bufnr)
    local id_str_pos = {
        start_pos = 0,
        end_pos = id_str_length,
    }

    local date_str_pos = {
        start_pos = id_str_length + 3,
        end_pos = id_str_length + 3 + date_str_length,
    }
    local cwd_str_pos = {
        start_pos = id_str_length + 3 + date_str_length + 3,
        end_pos = id_str_length + 3 + date_str_length + 3 + cwd_str_length,
    }
    local rel_file_path_str_pos = {
        start_pos = id_str_length + 3 + date_str_length + 3 + cwd_str_length + 3,
        end_pos = id_str_length + 3 + date_str_length + 3 + cwd_str_length + 3 + rel_file_path_str_length,
    }

    for current_line = 0, buffer_lines - 1 do
        vim.api.nvim_buf_add_highlight(main_file_history_win.bufnr, 0, "custom_all_file_history_view_column_id", current_line, id_str_pos.start_pos, id_str_pos.end_pos)
        vim.api.nvim_buf_add_highlight(main_file_history_win.bufnr, 0, "custom_all_file_history_view_column_date", current_line, date_str_pos.start_pos, date_str_pos.end_pos)
        vim.api.nvim_buf_add_highlight(main_file_history_win.bufnr, 0, "custom_all_file_history_view_column_cwd", current_line, cwd_str_pos.start_pos, cwd_str_pos.end_pos)
        vim.api.nvim_buf_add_highlight(main_file_history_win.bufnr, 0, "custom_all_file_history_view_column_rel_file_path", current_line, rel_file_path_str_pos.start_pos, rel_file_path_str_pos.end_pos)
    end
end


local function update_cwd_list_history(main_cwd_history_win)
    local data_list = {}
    local id_str_length = 3
    local latest_open_time_str_length = 19
    local file_open_count_str_length = 3
    local cwd_str_length = 110
    local current_date_sel = ""
    for _, values in ipairs(CWD_LIST_HISTORY_DATA.data) do
        local disp_id = normalize_string_length(tostring(values.Id), id_str_length)
        local disp_latest_open_time = normalize_string_length(values.LatestOpenTime, latest_open_time_str_length)
        local disp_file_open_count = normalize_string_length(tostring(values.FileOpenCount), file_open_count_str_length)
        local disp_current_working_directory = normalize_string_length(values.CurrentWorkingDir, cwd_str_length)

        if values.Date ~= current_date_sel then
            if current_date_sel ~= "" then
                table.insert(data_list, "")
                table.insert(data_list, "")
            end
            table.insert(data_list, "-- " .. values.Date)
            current_date_sel = values.Date
        end

        table.insert(data_list, "++ | " .. disp_id .. " | " .. disp_latest_open_time .. " | " .. disp_file_open_count .. " | " .. disp_current_working_directory)
    end

    if main_cwd_history_win.bufnr_read_only == true then
        vim.api.nvim_buf_set_option(main_cwd_history_win.bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_option(main_cwd_history_win.bufnr, 'readonly', false)
    end
    vim.api.nvim_buf_set_lines(main_cwd_history_win.bufnr, 0, -1, false, data_list)
    if main_cwd_history_win.bufnr_read_only == true then
        vim.api.nvim_buf_set_option(main_cwd_history_win.bufnr, 'modifiable', false)
        vim.api.nvim_buf_set_option(main_cwd_history_win.bufnr, 'readonly', true)
    end

    vim.api.nvim_set_hl(0, "custom_cwd_list_history_view_column_latest_open_time", {fg = "#99FF33"})
    vim.api.nvim_set_hl(0, "custom_cwd_list_history_view_column_file_open_count", {fg = "#3399FF"})
    vim.api.nvim_set_hl(0, "custom_cwd_list_history_view_column_cwd", {fg = "#f59842"})
    vim.api.nvim_set_hl(0, "custom_cwd_list_history_view_column_label", {fg = "#c4c4c4"})

    vim.api.nvim_set_hl(0, "custom_cwd_list_history_view_header_date", {fg = "#c4c4c4"})

    local buffer_lines = vim.api.nvim_buf_line_count(main_cwd_history_win.bufnr)
    local label_str_pos = {
        start_pos = 0,
        end_pos = 2,
    }
    local id_str_pos = {
        start_pos = 5,
        end_pos = 5 + id_str_length
    }
    local latest_open_time_str_pos = {
        start_pos = 5 + id_str_length + 3,
        end_pos = 5 + id_str_length + 3 + latest_open_time_str_length,
    }
    local file_open_count_str_pos = {
        start_pos = 5 + id_str_length + 3 + latest_open_time_str_length + 3,
        end_pos = 5 + id_str_length + 3 + latest_open_time_str_length + 3 + file_open_count_str_length,
    }
    local cwd_str_pos = {
        start_pos = 5 + id_str_length + 3 + latest_open_time_str_length + 3 + file_open_count_str_length + 3,
        end_pos = 5 + id_str_length + 3 + latest_open_time_str_length + 3 + file_open_count_str_length + 3 + cwd_str_length,
    }

    for current_line = 0, buffer_lines - 1 do
        local eval_buf_line_str = vim.api.nvim_buf_get_lines(main_cwd_history_win.bufnr, current_line, current_line + 1, false)
        if string.sub(eval_buf_line_str[1], 1, 2) == "++" then
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_column_label", current_line, label_str_pos.start_pos, label_str_pos.end_pos)
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_column_label", current_line, id_str_pos.start_pos, id_str_pos.end_pos)
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_column_latest_open_time", current_line, latest_open_time_str_pos.start_pos, latest_open_time_str_pos.end_pos)
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_column_file_open_count", current_line, file_open_count_str_pos.start_pos, file_open_count_str_pos.end_pos)
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_column_cwd", current_line, cwd_str_pos.start_pos, cwd_str_pos.end_pos)
        elseif string.sub(eval_buf_line_str[1], 1, 2) == "--" then
            vim.api.nvim_buf_add_highlight(main_cwd_history_win.bufnr, 0, "custom_cwd_list_history_view_header_date", current_line, 0, -1)
        end
    end
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


local function read_cwd_list_history (main_cwd_history_win, offset_hour)
    local cmd_to_run = ' ' .. PYTHON_MAIN_CMD .. ' ./' .. PYTHON_FILE_GET_CWD_LIST_HISTORY ..  ' --offset_hour ' .. offset_hour .. ' --db_path ' .. DATA_DIR_PATH .. DATA_DB_FILENAME
    local job_read_cwd_list_history = vim.fn.jobstart(
	cmd_to_run,
	{
	    stdout_buffered = true,
	    cwd = PYTHON_PATH_SCRIPT,
	    on_stdout = function (chanid, data, name)
		local arr_data = {data[1]}
		CWD_LIST_HISTORY_DATA = vim.fn.json_decode(arr_data[1])

		update_cwd_list_history(main_cwd_history_win)
	    end,
	}
    )
    vim.fn.jobwait({job_read_cwd_list_history}, -1)
end


local function add_new_file_info (full_file_path, relative_file_path, current_working_dir, git_top_level_path, git_repo_remote_url)
    local cmd_to_run = ' ' .. PYTHON_MAIN_CMD .. ' ./' .. PYTHON_FILE_ADD_NEW_FILE_INFO .. ' --full_file_path "' .. full_file_path .. '" --relative_file_path "' .. relative_file_path .. '" --current_working_dir "' .. current_working_dir .. '" --git_top_level_path "' .. git_top_level_path .. '" --git_repo_remote_url "' .. git_repo_remote_url .. '" --db_path ' .. DATA_DIR_PATH .. DATA_DB_FILENAME
    local job_add_new_file_info = vim.fn.jobstart(
	cmd_to_run,
	{
            stdout_buffered = true,
            cwd = PYTHON_PATH_SCRIPT,
                on_stdout = function (chanid, data, name)
                print(vim.inspect(data))
            end,
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



local function create_floating_windows (input_buffer, opt, should_enter_win, is_read_only)
    win_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(win_buf, 0, - 1, false, input_buffer)

    if is_read_only == true then
        vim.api.nvim_buf_set_option(win_buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(win_buf, 'readonly', true)
    end

    vim.cmd "setlocal nocursorcolumn"
    local win_info = {
        state = 'start',
        bufnr = win_buf,
        bufnr_read_only = is_read_only,
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


function ret_func.show_all_file_history(user_settings)
    local user_curr_focused_win = vim.fn.win_getid()

    local main_file_history_win = create_floating_windows(
        {},
        {
        title = 'File History',
        relative = "editor",
        focusable = true,
        width = 200,
        height = 32,
        row = 5,
        col = 10,
        style = "minimal",
        border = 'single',
        },
        true,
        true
    )

    local cwd_win = create_floating_windows(
        {},
        {
            title = 'CWD filter',
            relative = "editor",
            focusable = true,
            width = 200,
            height = 1,
            row = 39,
            col = 10,
            border = 'single',
        },
        false,
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

    local buf_cmd_close_window = '<Cmd>lua vim.api.nvim_set_current_win(' .. user_curr_focused_win .. '); <CR>'
    for _, value in ipairs(all_floating_window_id) do
	vim.api.nvim_buf_set_keymap(value.bufnr, 'n', user_settings.exit_note_window, buf_cmd_close_window, {noremap = true, silent = true})
    end

    vim.keymap.set('n', user_settings.open_cwd,
	function ()
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local current_buf_line_str = vim.api.nvim_buf_get_lines(main_file_history_win.bufnr, row-1, row, false)
            split_str = custom_split_string(current_buf_line_str[1], '|', true)
            current_id_str = custom_trim(split_str[1])
            current_selected_id = tonumber(current_id_str)
            for _, values in ipairs(ALL_FILE_HISTORY_DATA.data) do
                if values.Id == current_selected_id then
                    selected_cwd = values.CurrentWorkingDir
                    break
                end
            end
            vim.api.nvim_set_current_dir(selected_cwd)
            vim.api.nvim_set_current_win(user_curr_focused_win);
	end
    )

    vim.keymap.set('n', user_settings.new_tab_cwd,
	function ()
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local current_buf_line_str = vim.api.nvim_buf_get_lines(main_file_history_win.bufnr, row-1, row, false)
            split_str = custom_split_string(current_buf_line_str[1], '|', true)
            current_id_str = custom_trim(split_str[1])
            current_selected_id = tonumber(current_id_str)
            for _, values in ipairs(ALL_FILE_HISTORY_DATA.data) do
                if values.Id == current_selected_id then
                    selected_cwd = values.CurrentWorkingDir
                    break
                end
            end

            local curr_os_name = vim.loop.os_uname().sysname
            if curr_os_name == 'Windows_NT' then
                local cmd_to_run = 'wt.exe -w 0 nt -d "' .. selected_cwd .. '" powershell.exe -NoExit -Command "' .. user_settings.editor_cmd_open_current_cwd .. '"'
                local windows_terminal_new_tab = vim.fn.jobstart(
                    cmd_to_run,
                    {
                        stdout_buffered = true,
                    }
                )
            end
	end
    )

    check_db_table_exists()
    read_all_file_history(main_file_history_win, user_settings.offset_hour)
end


function ret_func.show_open_cwd_history(user_settings)
    local user_curr_focused_win = vim.fn.win_getid()

    local main_cwd_history_win = create_floating_windows(
        {},
        {
            title = 'CWD History',
            relative = "editor",
            focusable = true,
            width = 200,
            height = 32,
            row = 5,
            col = 10,
            style = "minimal",
            border = 'single',
        },
        true,
        true
    )

    local all_floating_window_id = {}
    table.insert(all_floating_window_id, main_cwd_history_win)

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

    local buf_cmd_close_window = '<Cmd>lua vim.api.nvim_set_current_win(' .. user_curr_focused_win .. '); <CR>'
    for _, value in ipairs(all_floating_window_id) do
	vim.api.nvim_buf_set_keymap(value.bufnr, 'n', user_settings.exit_note_window, buf_cmd_close_window, {noremap = true, silent = true})
    end

    vim.keymap.set('n', user_settings.new_tab_cwd,
	function ()
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local current_buf_line_str = vim.api.nvim_buf_get_lines(main_cwd_history_win.bufnr, row-1, row, false)
            if string.sub(current_buf_line_str[1], 1, 2) == "++" then
                local split_str = custom_split_string(current_buf_line_str[1], '|', true)
                local cwd_selected = ''
                local current_id_str = custom_trim(split_str[2])
                local current_selected_id = tonumber(current_id_str)
                for _, values in ipairs(CWD_LIST_HISTORY_DATA.data) do
                    if values.Id == current_selected_id then
                        cwd_selected = values.CurrentWorkingDir
                        break
                    end
                end

                print("cwd_selected: " .. cwd_selected)

                local curr_os_name = vim.loop.os_uname().sysname
                if curr_os_name == 'Windows_NT' then
                    local cmd_to_run = 'wt.exe -w 0 nt -d "' .. cwd_selected .. '" powershell.exe -NoExit -Command "' .. user_settings.editor_cmd_open_current_cwd .. '"'
                    local windows_terminal_new_tab = vim.fn.jobstart(
                        cmd_to_run,
                        {
                            stdout_buffered = true,
                        }
                    )
                end
            else
                print("Please select valid line")
            end


	end
    )

    check_db_table_exists()
    read_cwd_list_history(main_cwd_history_win, user_settings.offset_hour)
end


return ret_func
