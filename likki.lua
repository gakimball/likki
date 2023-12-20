#!/usr/bin/env lua

local string_utils = require('likki.lib.string-utils')
local table_utils = require('likki.lib.table-utils')
local build_page = require('likki.lib.build-page')

local buildnavigation = function()
	local output = ''
	--- @type string[]
	local navlinks = {}

	for line in io.lines('./site/_navigation.txt') do
		if not line:match('^%s*$') then
			if line:match('^-') then
				local parsed = string_utils.split(line:gsub('^-%s+(.*)', '%1'), '|')
				local href = string_utils.slugify(parsed[1])
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
for _, filename in pairs(string_utils.split(filelist, '\n')) do
	local pagename, page = build_page(filename)

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
				if table_utils.has(otherpage.links, pagename) then
					output = output .. string.format('<p class="link"><a href="%s">%s</a></p>\n', otherpagename, otherpage.title)
				end
			end

			if
				#output == 0
				and not table_utils.has(navlinks, pagename)
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
	print('Broken link: ' .. pagename .. ' => ' .. string_utils.join(links, ', '))
end

return {
	pages = pages,
}
