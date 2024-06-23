--- Returns an iterator for the lines of file `path`, and a second function for invoking a
--- function call within the template. After invoking a function, the iterator will switch
--- to reading the output of that function, returning to the original file when all lines
--- of the function invocation have been read.
--- @param path string
local create_page_iterator = function(path)
  local file_lines = io.lines(path)
  local func_lines = nil

  local iterator = function()
    return function()
      return func_lines and func_lines() or file_lines()
    end
  end

  --- @param name string
  local exec_func = function(name)
    func_lines = io.popen('./functions/' .. name .. '.lua', 'r'):lines('l')
  end

  return iterator, exec_func
end

return create_page_iterator
