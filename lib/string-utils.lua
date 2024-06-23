--- Split a string using `sep` as a delimiter.
--- @param input string
--- @param sep string
--- @return string[]
local splitstring = function(input, sep)
	local fragments = {}

	for str in string.gmatch(input, "([^"..sep.."]+)") do
		table.insert(fragments, str)
	end

	return fragments
end

--- Join an ordered table into a string using `sep` as a separator.
--- @param input string[]
--- @param sep string
--- @return string
local joinstring = function(input, sep)
	local str = ''
	for index, item in ipairs(input) do
		str = str .. item
		if index < #input then str = str .. sep end
	end
	return str
end

--- Remove leading and trailing whitespace from a string.
--- @param input string
local trimstring = function(input)
  return input:gsub("^%s*(.-)%s*$", "%1")
end

--- Escape the HTML of a string.
--- @param input string
local escapehtml = function(input)
	return input
		-- Escape key HTML characters
		:gsub('&', '&amp;')
		:gsub('<', '&lt;')
		:gsub('>', '&gt;')
		-- Escape braces, which are used by the template
		:gsub('{', '&#123;')
		:gsub('}', '&#125;')
end

--- Slugify text for use with links.
--- @param title string
local slugifytitle = function(title)
	return title:gsub('%s', '-'):lower()
end

local image_extensions = { 'jpg', 'jpeg', 'png', 'gif', 'webp' }

--- Check if a URL is for an image by checking its extension.
--- @param path string
local is_image_path = function(path)
	for _, ext in ipairs(image_extensions) do
		if path:match('%.'..ext) then
			return true
		end
	end

	return false
end

return {
  split = splitstring,
  join = joinstring,
  trim = trimstring,
  escape_html = escapehtml,
	slugify = slugifytitle,
	is_image_path = is_image_path,
}
