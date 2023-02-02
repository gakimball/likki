# likki

> Wiki generator written in Lua

I'm learning Lua (again), and I'm building a simple wiki generator to do so.

Features:

- [x] Converts Gemtext to HTML
  - [x] Text
  - [x] Link
  - [x] Preformatting
  - [x] Heading
  - [x] List
  - [x] Quote
- [x] Wraps pages in an HTML template
- [x] Parses inline links to other pages
- [x] Adds backlinks to each page
- [x] Produces an index (listing of all pages)
- [ ] Support custom link titles, e.g. `{san luis obispo|slo}`
- [ ] Add Markdown-style tables

Issues:

- [ ] Multi-line blockquotes do not work
- [x] Block-level (`=>`) internal links should count as backlinks
- [x] Private pages should not appear in directory or in backlinks
