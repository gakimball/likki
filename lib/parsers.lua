local string_utils = require('likki.lib.string-utils')

--- Parse the target URL and text from a block-level link.
--- @param input string
local parseblocklink = function(input)
	local href = ''
	local text = ''

	if input:match('^=>%s+(%S+)%s(.+)') then
		input:gsub('^=>%s+(%S+)%s(.+)', function(foundUrl, foundText)
			href = foundUrl
			text = foundText
		end)
	else
		input:gsub('^=>%s+(%S+)', function(foundUrl)
			href = foundUrl
			text = foundUrl
		end)
	end

	return href, text
end

--- Parse the title and level from a heading line.
--- @param line string
--- @return Heading
local parseheadingline = function(line)
	local title = line:gsub('^##?#?%s*', '')

	return {
		title = title,
		slug = string_utils.slugify(title),
		level = #line:match('^##?#?'),
	}
end

--- Parse the cells of a table line.
--- @param line string
local parsetableline = function(line)
	local cells = string_utils.split(line, '|')

	for index, cell in ipairs(cells) do
		cells[index] = string_utils.trim(cell)
	end

	return cells
end

--- @param cells string[]
local isdecorativerow = function(cells)
	for _, cell in ipairs(cells) do
		if not cell:match('^%-+$') then
			return false
		end
	end

	return true
end

return {
  block_link = parseblocklink,
  heading = parseheadingline,
  table = parsetableline,
  is_decorative_row = isdecorativerow,
}
