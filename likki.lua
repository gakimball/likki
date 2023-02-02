#!/usr/bin/env lua

--- @class Page
--- @field title string Title of page.
--- @field body string HTML of page.
--- @field headings Heading[] Page headings.
--- @field unlisted boolean Page is invisible.
--- @field links string[] Outgoing links to other pages.

--- @class Heading
--- @field title string
--- @field slug string
--- @field level number

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

--- Check if a list-like table contains a value.
--- @param list any[]
--- @param value any
local hasvalue = function(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end

	return false
end

--- @param title string
local slugifytitle = function(title)
	return title:gsub('%s', '-'):lower()
end

--- Convert the Gemtext file at `path` to HTML, and make note of internal links to other pages.
--- @param path string
local buildpage = function(path)
	local output = ''
	local preformatted = false
	local filename = path:gsub('^%./site/', '')
	local pagename = filename:gsub('^_', ''):gsub('%.gmi$', '')
	local prevlinetype = nil

	--- @type Page
	local page = {
		title = pagename:gsub('-', ' '),
		body = '',
		headings = {},
		unlisted = filename:match('^_') ~= nil,
		links = {},
	}

	for line in io.lines(path) do
		-- Preformatted mode
		if line:match('^```') then
			prevlinetype = 'pre'

			if preformatted then
				output = output .. '</pre></code>\n'
			else
				output = output .. '<code><pre>'
			end

			preformatted = not preformatted
		elseif preformatted == true then
			prevlinetype = 'pre'
			output = output .. escapehtml(line) .. '\n'
		-- H3
		elseif line:match('^###') then
			prevlinetype = 'heading'
			local title = line:gsub('^###%s*', '')
			local slug = slugifytitle(title)
			output = output .. line:gsub('^###%s*(.+)', '<h4 id="%%s">%1</h3>\n'):format(slug)
			table.insert(page.headings, {
				title = title,
				slug = slug,
				level = 3,
			})
		-- H2
		elseif line:match('^##') then
			prevlinetype = 'heading'
			local title = line:gsub('^##%s*', '')
			local slug = slugifytitle(title)
			output = output .. line:gsub('^##%s*(.+)', '<h3 id="%%s">%1</h2>\n'):format(slug)
			table.insert(page.headings, {
				title = title,
				slug = slug,
				level = 2,
			})
		-- H1
		elseif line:match('^#') then
			prevlinetype = 'heading'
			local title = line:gsub('^#%s*', '')
			local slug = slugifytitle(title)
			output = output .. line:gsub('^#%s*(.+)', '<h2 id="%%s">%1</h1>\n'):format(slug)
			table.insert(page.headings, {
				title = title,
				slug = slug,
				level = 1,
			})
		-- Link
		elseif line:match('^=>') then
			prevlinetype = 'link'

			local url = ''
			local text = ''

			if line:match('^=>%s+(%S+)%s(.+)') then
				line:gsub('^=>%s+(%S+)%s(.+)', function(foundUrl, foundText)
					url = foundUrl
					text = foundText
				end)
			else
				line:gsub('^=>%s+(%S+)', function(foundUrl)
					url = foundUrl
					text = foundUrl
				end)
			end

			if url:match('%.jpg$') then
				output = output .. string.format('<img src="%s" alt="%s" loading="lazy">', url, text)
			else
				output = output .. string.format('<p class="link"><a href="%s">%s</a></p>\n', url, text)
			end
		-- Blockquote
		elseif line:match('^>') then
			if prevlinetype ~= 'blockquote' then
				output = output .. '<blockquote>\n'
			end

			prevlinetype = 'blockquote'
			output = output .. line:gsub('^>%s*(.+)', '%1\n')
		-- Remaining possible line types are lists or plain lines, which we parse for {internal links}
		else
			local linkifiedline = line:gsub('%b{}', function(arg)
				local title = arg:gsub('^{(.*)}$', '%1')
				local href = title:gsub('%s', '-'):lower()

				if not hasvalue(page.links, href) then
					table.insert(page.links, href)
				end

				return string.format('<a href="%s.html">%s</a>', href, title)
			end)

			-- List
			if linkifiedline:match('^*') then
				prevlinetype = 'list'
				output = output .. linkifiedline:gsub('^*%s*(.+)', '<li>%1</li>\n')
			-- Text
			else
				prevlinetype = 'text'
				output = output .. string.format('<p>%s</p>\n', linkifiedline)
			end
		end

		if prevlinetype == 'blockquote' then
			output = output .. '</blockquote>\n'
		end
	end

	page.body = output

	return pagename, page
end

-- Get all pages
local lscmd = io.popen('ls ./site/*.gmi')
assert(lscmd, 'Could not run ls')
--- @type string
local filelist = lscmd:read('a')
lscmd:close()

-- Create the build folder
os.execute('mkdir ./build')

--- Mapping of page filenames to the page's metadata.
--- @type { [string]: Page }
local pages = {}

-- Convert each page from Gemtext to HTML
for _, filename in pairs(splitstring(filelist, '\n')) do
	local pagename, page = buildpage(filename)

	pages[pagename] = page
end

-- Load the HTML template
local templatefile = io.open('./site/_template.html', 'r')
assert(templatefile, 'No template.html')
---@type string
local template = templatefile:read('a')
templatefile:close()

-- Add an index page that lists every page in the wiki
pages.directory = {
	title = 'Directory',
	unlisted = false,
	body = (function()
		local output = ''

		for pagename, page in pairs(pages) do
			output = output .. string.format('<li><a href="%s.html">%s</a></li>\n', pagename, page.title)
		end

		return output
	end)(),
	headings = {},
	links = {},
}

-- Apply the HTML template to each page and write the finished page to disk
for pagename, page in pairs(pages) do
	local pagepath = './build/' .. pagename .. '.html'
	local file = io.open(pagepath, 'w')

	assert(file, 'Could not open ' .. pagepath)

	local wrappedpagecontents = template
		:gsub('{{ title }}', function() return page.title end)
		:gsub('{{ body }}', function() return page.body end)
		:gsub('{{ outline }}', function()
			local output = '<ul>'

			for _, heading in ipairs(page.headings) do
				output = output .. string.format('<li data-level="%s"><a href="#%s">%s</a></li>\n', heading.level, heading.slug, heading.title)
			end

			return output .. '</ul>'
		end)
		:gsub('{{ backlinks }}', function()
			local output = ''

			for otherpagename, otherpage in pairs(pages) do
				if hasvalue(otherpage.links, pagename) then
					output = output .. string.format('<li><a href="%s">%s</a></li>\n', otherpagename, otherpage.title)
				end
			end

			if #output > 0 then
				output = '<h2>Backlinks</h2>\n' .. output
			end

			return output
		end)

	file:write(wrappedpagecontents)
	file:close()
end
