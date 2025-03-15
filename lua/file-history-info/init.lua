local ret_func = {}


local OS_FILE_SEP = package.config:sub(1, 1)
local PYTHON_PATH_SCRIPT = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'scripts' .. OS_FILE_SEP
local DATA_DIR_PATH = string.sub(debug.getinfo(1).source, 2, string.len('/lua/file-history-info/init.lua') * -1 ) .. 'data' .. OS_FILE_SEP
local PYTHON_MAIN_CMD = 'python'

local PYTHON_FILE_ADD_NEW_FILE_INFO = 'add_new_file_info.py'
local PYTHON_FILE_CHECK_DB = 'check_db_table.py'
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


function ret_func.setup_start()
    local file_info_records_augroup = vim.api.nvim_create_augroup("custom_file_info_augroup", {clear = true})
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


return ret_func
