--- Split a string using `sep` as a delimiter.
--- @param input string
--- @param sep string
local splitstring = function(input, sep)
	local fragments = {}

	for str in string.gmatch(input, "([^"..sep.."]+)") do
		table.insert(fragments, str)
	end

	return fragments
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

--- Convert a page title to its filename equivalent.
--- @param input string
local slugify = function(input)
	return input:gsub('%s', '_'):lower()
end

--- Mapping of page names to a list of pages that link to them.
--- @type { [string]: string[] }
local pagelinks = {}

--- Convert the Gemtext file at `path` to HTML, and make note of internal links to other pages.
--- @param path string
local buildpage = function(path)
	local output = ''
	local preformatted = false
	local pagename = path:gsub('^%./site/', ''):gsub('%.gmi$', '')

	if not pagelinks[pagename] then
		pagelinks[pagename] = {}
	end

	for line in io.lines(path) do
		-- Preformatted mode
		if line:match('^```') then
			if preformatted then
				output = output .. '</pre></code>\n'
			else
				output = output .. '<code><pre>\n'
			end

			preformatted = not preformatted
		elseif preformatted == true then
			output = output .. escapehtml(line) .. '\n'
		-- H3
		elseif line:match('^###') then
			output = output .. line:gsub('^###%s*(.+)', '<h3>%1</h3>\n')
		-- H2
		elseif line:match('^##') then
			output = output .. line:gsub('^##%s*(.+)', '<h2>%1</h2>\n')
		-- H1
		elseif line:match('^#') then
			output = output .. line:gsub('^#%s*(.+)', '<h1>%1</h1>\n')
		-- Link
		elseif line:match('^=>') then
			output = output .. line:gsub('^=>%s+(%S+)%s(.+)', '<p><a href="%1">%2</a></p>\n')
		-- Remaining possible line types are lists or plain lines, which we parse for {internal links}
		else
			local linkifiedline = line:gsub('%b{}', function(arg)
				local title = arg:gsub('^{', ''):gsub('}$', '')
				local href = slugify(title)

				if not pagelinks[href] then
					pagelinks[href] = {}
				end

				table.insert(pagelinks[href], pagename)

				return string.format('<a href="%s.html">%s</a>', href, title)
			end)

			-- List
			if linkifiedline:match('^*') then
				output = output .. linkifiedline:gsub('^*%s*(.+)', '<li>%1</li>\n')
			-- Text
			else
				output = output .. string.format('<p>%s</p>\n', linkifiedline)
			end
		end
	end

	return output
end

-- Get all pages
local lscmd = io.popen('ls ./site/*.gmi')
assert(lscmd, 'Could not run ls')
--- @type string
local filelist = lscmd:read('a')
lscmd:close()

-- Create the build folder
os.execute('mkdir ./build')

--- Mapping of page names to their HTML contents.
--- @type { [string]: string }
local parsedpages = {}

-- Convert each page from Gemtext to HTML
for _, filename in pairs(splitstring(filelist, '\n')) do
	local pagename = filename:gsub('^%./site/(.+)%.gmi', '%1')

	parsedpages[pagename] = buildpage(filename)
end

-- Load the HTML template
local templatefile = io.open('./site/template.html', 'r')
assert(templatefile, 'No template.html')
---@type string
local template = templatefile:read('a')
templatefile:close()

--- Build an index page that lists every page in the wiki
local createindex = function()
	local output = '<h1>Index</h1>\n'

	for pagename in pairs(parsedpages) do
		output = output .. string.format('<li><a href="%s.html">%s</a></li>', pagename, pagename)
	end

	return output
end

parsedpages.index = createindex()
pagelinks.index = {}

-- Apply the HTML template to each page and write the finished page to disk
for pagename, pagehtml in pairs(parsedpages) do
	local pagepath = './build/' .. pagename .. '.html'
	local file = io.open(pagepath, 'w')

	assert(file, 'Could not open ' .. pagepath)

	local backlinkshtml = ''

	-- Append backlinks
	if #pagelinks[pagename] > 0 then
		backlinkshtml = backlinkshtml .. '<h2>Backlinks</h2>\n'

		for _, backlink in ipairs(pagelinks[pagename]) do
			local listtemplate = '<li><a href="%s.html">%s</a></li>\n'

			backlinkshtml = backlinkshtml .. listtemplate:format(backlink, backlink)
		end
	end

	local wrappedpagecontents = template
		:gsub('{{ title }}', pagename)
		:gsub('{{ body }}', pagehtml)
		:gsub('{{ backlinks }}', backlinkshtml)

	file:write(wrappedpagecontents)
	file:close()
end
