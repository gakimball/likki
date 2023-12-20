local string_utils = require('likki.lib.string-utils')
local table_utils = require('likki.lib.table-utils')
local parsers = require('likki.lib.parsers')

--- @class Heading
--- @field title string
--- @field slug string
--- @field level number

--- @class Page
--- @field title string Title of page.
--- @field body string HTML of page.
--- @field headings Heading[] Page headings.
--- @field unlisted boolean Page is invisible.
--- @field links string[] Outgoing links to other pages.

--- Convert the Gemtext file at `path` to HTML, and make note of internal links to other pages.
--- @param path string
local build_page = function(path)
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
      output = output .. string_utils.escape_html(line) .. '\n'
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
        local cells = parsers.table(line)

        if not parsers.is_decorative_row(cells) then
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
          local heading = parsers.heading(line)
          output = output ..
          line:gsub('^##?#?%s*(.+)', '<h%%s id="%%s">%1</h%%s>\n'):format(heading.level + 1, heading.slug,
            heading.level + 1)
          table.insert(page.headings, heading)
        -- Link
        elseif line:match('^=>') then
          prevlinetype = 'link'
          local href, text = parsers.block_link(line)

          if href:match('%.jpg') then
            output = output .. string.format('<img src="%s" alt="%s" loading="lazy">', href, text)
          else
            if not href:match('://') and not table_utils.has(page.links, href) then
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
            local parsedinput = string_utils.split(arg:gsub('^{(.*)}$', '%1'), '|')

            if #parsedinput == 0 then return arg end

            local href = string_utils.slugify(parsedinput[1])
            local title = parsedinput[2] or parsedinput[1]

            if not table_utils.has(page.links, href) then
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

return build_page
