local api = vim.api
local fn = vim.fn
local fs = vim.fs
local log = require("vim.lsp.log")

local M = {}

local buffer_store = {}

function M.clear_buffers()
	buffer_store = {}
	vim.notify("BufferBatch: Store cleared.", vim.log.levels.INFO)
end

function M.add_buffer()
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	if not file_path or file_path == "" then
		vim.notify("BufferBatch: Buffer has no name, cannot add.", vim.log.levels.WARN)
		return
	end

	for _, stored_buf in ipairs(buffer_store) do
		if stored_buf.bufnr == bufnr then
			vim.notify(
				"BufferBatch: Buffer " .. bufnr .. " (" .. file_path .. ") already in store.",
				vim.log.levels.WARN
			)
			return
		end
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	table.insert(buffer_store, {
		bufnr = bufnr,
		name = file_path,
		content = lines,
	})
	vim.notify("BufferBatch: Added buffer " .. bufnr .. " (" .. file_path .. ") to store.", vim.log.levels.INFO)
end

function M.paste_buffers()
	if #buffer_store == 0 then
		vim.notify("BufferBatch: No buffers stored to paste.", vim.log.levels.WARN)
		return
	end
	local current_buf = vim.api.nvim_get_current_buf()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1] - 1
	local lines_to_insert = {}

	for i, buf_data in ipairs(buffer_store) do
		local relative_path = fn.fnamemodify(buf_data.name, ":.")
		table.insert(lines_to_insert, "--- Buffer: " .. (relative_path or "Untitled " .. buf_data.bufnr) .. " ---")
		table.insert(lines_to_insert, "--------")
		vim.list_extend(lines_to_insert, buf_data.content)

		if i < #buffer_store then
			table.insert(lines_to_insert, "")
			table.insert(lines_to_insert, "--------")
			table.insert(lines_to_insert, "")
		end
	end

	vim.api.nvim_buf_set_lines(current_buf, row, row, false, lines_to_insert)

	vim.api.nvim_win_set_cursor(0, { row + #lines_to_insert, 0 })

	vim.notify("BufferBatch: Pasted " .. #buffer_store .. " buffers.", vim.log.levels.INFO)
end

function M.copy_buffers_to_clipboard()
	if #buffer_store == 0 then
		vim.notify("BufferBatch: No buffers stored to copy.", vim.log.levels.WARN)
		return
	end
	local clipboard_lines = {}
	for i, buf_data in ipairs(buffer_store) do
		local relative_path = fn.fnamemodify(buf_data.name, ":.")
		table.insert(clipboard_lines, "--- Buffer: " .. (relative_path or "Untitled " .. buf_data.bufnr) .. " ---")
		table.insert(clipboard_lines, "--------")
		vim.list_extend(clipboard_lines, buf_data.content)

		if i < #buffer_store then
			table.insert(clipboard_lines, "")
			table.insert(clipboard_lines, "--------")
			table.insert(clipboard_lines, "")
		end
	end
	local clipboard_content = table.concat(clipboard_lines, "\n")
	fn.setreg("+", clipboard_content)
	if fn.has("clipboard") then
		fn.setreg("*", clipboard_content)
	end
	vim.notify("BufferBatch: Copied " .. #buffer_store .. " buffers to clipboard (+ register).", vim.log.levels.INFO)
end

local function read_file_content(path)
	if fn.filereadable(path) ~= 1 or fn.isdirectory(path) == 1 then
		log.warn("BufferBatch/FolderCopy: Skipping non-file or unreadable path: " .. path)
		return nil, "Not a readable file"
	end

	local lines, err = fn.readfile(path)
	if err or not lines then
		log.error("BufferBatch/FolderCopy: Failed to read file: " .. path .. " Error: " .. tostring(lines or err))
		return nil, "Error reading file"
	end

	if #lines == 0 then
		return "", nil
	end

	local content = table.concat(lines, "\n")

	return content, nil
end

local function get_formatted_folder_content(base_path)
	local abs_base_path = fn.expand(base_path)

	if fn.isdirectory(abs_base_path) == 0 then
		vim.notify("BufferBatch/FolderCopy: Path is not a valid directory: " .. abs_base_path, vim.log.levels.ERROR)
		return nil
	end

	local files_to_process = {}

	local ok, iterator = pcall(fs.dir, abs_base_path, { depth = math.huge })

	if not ok or not iterator then
		vim.notify(
			"BufferBatch/FolderCopy: Failed to iterate directory: " .. abs_base_path .. (iterator or ""),
			vim.log.levels.ERROR
		)
		return nil
	end

	local iter_ok, file_path, entry_type
	repeat
		iter_ok, file_path, entry_type = pcall(iterator)
		if iter_ok and file_path then
			local full_path = vim.fs.joinpath(abs_base_path, file_path)

			if entry_type == "file" then
				table.insert(files_to_process, full_path)
			end
		elseif not iter_ok then
			log.error("BufferBatch/FolderCopy: Error during directory iteration: " .. tostring(file_path))
		end
	until not file_path

	if #files_to_process == 0 then
		vim.notify("BufferBatch/FolderCopy: No files found in: " .. abs_base_path, vim.log.levels.WARN)
		return ""
	end

	local output_parts = {}

	local clean_abs_base_path = abs_base_path:gsub("[\\/]$", "")
		.. (vim.loop.os_uname().sysname == "Windows_NT" and "\\" or "/")
	local base_pattern = "^" .. vim.pesc(clean_abs_base_path)

	table.sort(files_to_process)

	local added_content = false

	for _, f_path in ipairs(files_to_process) do
		local relative_path = f_path:gsub(base_pattern, "")
		local content, err = read_file_content(f_path)

		if content then
			if added_content then
				table.insert(output_parts, "\n--------\n")
			end
			table.insert(output_parts, "--- File: " .. relative_path .. " ---")
			table.insert(output_parts, "--------")

			if content ~= "" then
				table.insert(output_parts, content)
			end
			added_content = true
		else
			vim.notify(
				"BufferBatch/FolderCopy: Skipping '" .. relative_path .. "' (" .. (err or "Unknown reason") .. ")",
				vim.log.levels.WARN
			)
		end
	end

	if not added_content then
		vim.notify("BufferBatch/FolderCopy: No readable file content found in: " .. abs_base_path, vim.log.levels.WARN)
		return ""
	end

	return table.concat(output_parts, "\n")
end

function M.copy_folder_to_buffer(opts)
	local folder_path = opts.args
	if not folder_path or folder_path == "" then
		local current_buf_path = api.nvim_buf_get_name(0)
		if current_buf_path and current_buf_path ~= "" then
			folder_path = fn.fnamemodify(current_buf_path, ":h")
			vim.notify(
				"BufferBatch/FolderCopy: No path provided, using directory of current buffer: " .. folder_path,
				vim.log.levels.INFO
			)
		else
			vim.notify("BufferBatch/FolderCopy: Please provide a directory path.", vim.log.levels.ERROR)
			return
		end
	end

	local full_content = get_formatted_folder_content(folder_path)

	if full_content and full_content ~= "" then
		local buf = api.nvim_create_buf(false, true)
		api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
		api.nvim_set_option_value("swapfile", false, { buf = buf })

		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(full_content, "\n", { trimempty = false }))
		api.nvim_set_option_value("readonly", true, { buf = buf })
		api.nvim_set_option_value("filetype", "markdown", { buf = buf })

		if #api.nvim_list_wins() > 1 or api.nvim_win_get_config(0).relative ~= "" then
			api.nvim_command("noautocmd vs | buffer " .. buf)
		else
			api.nvim_command("noautocmd buffer " .. buf)
		end

		vim.notify("BufferBatch/FolderCopy: Content copied to new buffer.", vim.log.levels.INFO)
	elseif full_content == "" then
		vim.notify(
			"BufferBatch/FolderCopy: No content generated (folder might be empty or contain only unreadable/binary files).",
			vim.log.levels.WARN
		)
	end
end

function M.copy_folder_to_clipboard(opts)
	local folder_path = opts.args
	if not folder_path or folder_path == "" then
		local current_buf_path = api.nvim_buf_get_name(0)
		if current_buf_path and current_buf_path ~= "" then
			folder_path = fn.fnamemodify(current_buf_path, ":h")
			vim.notify(
				"BufferBatch/FolderCopy: No path provided, using directory of current buffer: " .. folder_path,
				vim.log.levels.INFO
			)
		else
			vim.notify("BufferBatch/FolderCopy: Please provide a directory path.", vim.log.levels.ERROR)
			return
		end
	end

	local full_content = get_formatted_folder_content(folder_path)

	if full_content and full_content ~= "" then
		fn.setreg("+", full_content)
		if fn.has("clipboard") then
			fn.setreg("*", full_content)
		end
		vim.notify(
			"BufferBatch/FolderCopy: Content copied to clipboard (+ register). Length: " .. #full_content,
			vim.log.levels.INFO
		)
	elseif full_content == "" then
		vim.notify(
			"BufferBatch/FolderCopy: No content generated to copy (folder might be empty or contain only unreadable/binary files).",
			vim.log.levels.WARN
		)
	end
end

function M.setup()
	vim.api.nvim_create_user_command(
		"BufferBatchAdd",
		M.add_buffer,
		{ desc = "BufferBatch: Add current buffer to batch store" }
	)
	vim.api.nvim_create_user_command(
		"BufferBatchPaste",
		M.paste_buffers,
		{ desc = "BufferBatch: Paste stored buffers into current buffer" }
	)
	vim.api.nvim_create_user_command(
		"BufferBatchClear",
		M.clear_buffers,
		{ desc = "BufferBatch: Clear the buffer batch store" }
	)
	vim.api.nvim_create_user_command(
		"BufferBatchCopy",
		M.copy_buffers_to_clipboard,
		{ desc = "BufferBatch: Copy stored buffers to clipboard" }
	)

	vim.api.nvim_create_user_command("CopyFolderToBuffer", M.copy_folder_to_buffer, {
		nargs = "?",
		complete = "dir",
		desc = "BufferBatch: Copy content of files in <folder> (or current dir) to a new buffer",
	})
	vim.api.nvim_create_user_command("CopyFolderToClipboard", M.copy_folder_to_clipboard, {
		nargs = "?",
		complete = "dir",
		desc = "BufferBatch: Copy content of files in <folder> (or current dir) to the clipboard (+)",
	})

	vim.keymap.set("n", "<leader>ba", M.add_buffer, { desc = "BufferBatch: Add buffer" })
	vim.keymap.set("n", "<leader>bp", M.paste_buffers, { desc = "BufferBatch: Paste buffers" })
	vim.keymap.set("n", "<leader>bc", M.clear_buffers, { desc = "BufferBatch: Clear store" })
	vim.keymap.set(
		"n",
		"<leader>by",
		M.copy_buffers_to_clipboard,
		{ desc = "BufferBatch: Copy(yank) buffers to clipboard" }
	)
end

return M
