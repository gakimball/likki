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

--- Slugify text for use with links.
--- @param title string
local slugifytitle = function(title)
	return title:gsub('%s', '-'):lower()
end

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
		slug = slugifytitle(title),
		level = #line:match('^##?#?'),
	}
end

--- Parse the cells of a table line.
--- @param line string
local parsetableline = function(line)
	local cells = splitstring(line, '|')

	for index, cell in ipairs(cells) do
		cells[index] = trimstring(cell)
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
		elseif preformatted then
			prevlinetype = 'pre'
			output = output .. escapehtml(line) .. '\n'
		-- Blockquote
		elseif line:match('^>') then
			if prevlinetype ~= 'blockquote' then
				output = output .. '<blockquote>\n'
			end

			prevlinetype = 'blockquote'
			output = output .. line:gsub('^>%s*(.+)', '%1\n')
		else
			if prevlinetype == 'blockquote' then
				output = output .. '</blockquote>\n'
			end

			if line:match('^|') then
				local element = 'td'

				if prevlinetype ~= 'table' then
					element = 'th'
					output = output .. '<table>\n'
				end

				prevlinetype = 'table'
				local cells = parsetableline(line)

				if not isdecorativerow(cells) then
					output = output .. '<tr>\n'
					for _, cell in ipairs(cells) do
						output = output .. string.format('<%s>%s</%s>\n', element, cell, element)
					end
					output = output .. '</tr>\n'
				end
			else
				if prevlinetype == 'table' then
					output = output .. '</table>\n'
				end

				-- Heading
				if line:match('^##?#?') then
					prevlinetype = 'heading'
					local heading = parseheadingline(line)
					output = output .. line:gsub('^##?#?%s*(.+)', '<h%%s id="%%s">%1</h%%s>\n'):format(heading.level + 1, heading.slug, heading.level + 1)
					table.insert(page.headings, heading)
					-- Link
				elseif line:match('^=>') then
					prevlinetype = 'link'
					local href, text = parseblocklink(line)

					if href:match('%.jpg') then
						output = output .. string.format('<img src="%s" alt="%s" loading="lazy">', href, text)
					else
						if not href:match('://') and not hasvalue(page.links, href) then
							table.insert(page.links, href)
						end

						output = output .. string.format('<p class="link"><a href="%s">%s</a></p>\n', href, text)
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
						local parsedinput = splitstring(arg:gsub('^{(.*)}$', '%1'), '|')
						local href = slugifytitle(parsedinput[1])
						local title = parsedinput[2] or parsedinput[1]

						if not hasvalue(page.links, href) then
							table.insert(page.links, href)
						end

						return string.format('<a href="%s">%s</a>', href, title)
					end)

					-- List
					if linkifiedline:match('^*') then
						prevlinetype = 'list'
						output = output .. linkifiedline:gsub('^*%s*(.+)', '<li>%1</li>\n')
						-- Plain line
					else
						prevlinetype = 'text'
						output = output .. string.format('<p>%s</p>\n', linkifiedline)
					end
				end
			end
		end
	end

	if prevlinetype == 'table' then
		output = output .. '</table>'
	end

	page.body = output

	if page.unlisted then
		page.links = {}
	end

	return pagename, page
end

local buildnavigation = function()
	local output = ''
	--- @type string[]
	local navlinks = {}

	for line in io.lines('./site/_navigation.txt') do
		if not line:match('^%s*$') then
			if line:match('^-') then
				local parsed = splitstring(line:gsub('^-%s+(.*)', '%1'), '|')
				local href = slugifytitle(parsed[1])
				local title = parsed[2] or parsed[1]

				table.insert(navlinks, href)

				output = output .. string.format('<li><a href="%s">%s</a></li>', href, title)
			else
				output = output .. string.format('<p>%s</p>', line)
			end
		end
	end

	return output, navlinks
end

-- Get all pages
local lscmd = io.popen('ls ./site/*.gmi')
assert(lscmd, 'Could not run ls')
--- @type string
local filelist = lscmd:read('a')
lscmd:close()

-- Get navigation
local navigationhtml, navlinks = buildnavigation()

-- Create the build folder
os.execute('mkdir ./build')

--- Mapping of page filenames to the page's metadata.
--- @type { [string]: Page }
local pages = {}

--- List of pages with no backlinks.
--- @type string[]
local orphanedpages = {}

--- Map of pages with broken links.
--- @type { [string]: string[] }
local brokenlinks = {}

-- Convert each page from Gemtext to HTML
for _, filename in pairs(splitstring(filelist, '\n')) do
	local pagename, page = buildpage(filename)

	pages[pagename] = page
end

-- Load the HTML template
local templatefile = io.open('./site/_template.html', 'r')
assert(templatefile, 'No template.html')
--- @type string
local template = templatefile:read('a')
templatefile:close()

-- Add an index page that lists every page in the wiki
pages.directory = {
	title = 'directory',
	unlisted = false,
	body = (function()
		local output = ''
		local sorted_pagenames = {}
		for pagename in pairs(pages) do table.insert(sorted_pagenames, pagename) end
		table.sort(sorted_pagenames)

		for _, pagename in ipairs(sorted_pagenames) do
			local page = pages[pagename]

			if not page.unlisted then
				output = output .. string.format('<p class="link"><a href="%s">%s</a></p>\n', pagename, page.title)
			end
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

	for _, link in ipairs(page.links) do
		if not pages[link] then
			if not brokenlinks[pagename] then brokenlinks[pagename] = {} end
			table.insert(brokenlinks[pagename], link)
		end
	end

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
					output = output .. string.format('<p class="link"><a href="%s">%s</a></p>\n', otherpagename, otherpage.title)
				end
			end

			if
				#output == 0
				and not hasvalue(navlinks, pagename)
				and not page.unlisted
				and pagename ~= 'index'
				and pagename ~= 'directory'
			then
				table.insert(orphanedpages, pagename)
			end

			if #output > 0 then
				output = '<h2>Backlinks</h2>\n' .. output
			end

			return output
		end)
		:gsub('{{ navigation }}', function() return navigationhtml end)

	file:write(wrappedpagecontents)
	file:close()
end

print(string.format("Built in %.0fms", os.clock() * 1000))

for _, pagename in ipairs(orphanedpages) do
	print('Orphaned page: ' .. pagename)
end

for pagename, links in pairs(brokenlinks) do
	print('Broken link: ' .. pagename .. ' => ' .. joinstring(links, ', '))
end

return {
	buildpage = buildpage,
	pages = pages,
}
