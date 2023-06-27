# likki

> Wiki generator written in Lua

I'm learning Lua (again), and I'm building a simple wiki generator to do so.

## Installation

Requires Lua, probably 5.4? The script is executable, so you just need to clone it and run it.

```bash
git clone git@github.com:gakimball/likki
```

## Usage

Run the script to build the wiki once:

```bash
./likki.lua
```

Relative to your current working directory, likki is looking for a `site` directory containing:

- `_template.html`, the site template
- `_navigation.txt`, a navigation template
- Files with the `.gmi` extension, which are your wiki pages

The finished site will be output to a `build` directory adjacent to `site`.

To make the development process more fluid, try adding [watchexec](https://github.com/watchexec/watchexec) to recompile the site as you write. Here's a slice of a [justfile](https://github.com/casey/just):

```
watch:
  watchexec --watch site -- just build

build:
  ./likki/likki.lua
```

## Formatting

likki parses pages as [Gemtext](https://gemini.circumlunar.space/docs/gemtext.gmi), with some additions:

Lines starting with a pipe (`|`) are table rows. The first row is assumed to be the header. Cells only containing hyphens are ignored, and can be used to visually separate the header from the body in your markup.

```markdown
| Ingredient | Quantity |
| ---------- | -------- |
| Flour      | 225g     |
| Salt       | 2.5g     |
| Olive oil  | 15ml     |
| Water      | 180ml    |
```

Within a plain text line or a list item line, you can insert internal links to other wiki pages. You can either reference the page directly:

```
Last month, I visited {Iceland}.
```

Or with an alias:

```
Last month, I visisted {iceland|a new country}.
```

Spaces are converted to hyphens to construct the hyperlink.

## Templating

The file `site/_template.html` holds your HTML template. Use these template variables to construct the page:

- `{{ title }}`: page title (derived from the filename)
- `{{ body }}`: page contents
- `{{ outline }}`: table of contents with links to each heading
- `{{ backlinks }}`: list of other pages that link to this one
- `{{ navigation }}`: main site navigation

The infixed spaces are necessary, by the way!

## Navigation

The file `site/_navigation.txt` holds a template for use as the main site navigation. Each line starting with a hyphen is an internal link; all other lines are section titles. Like with internal links, the text of the link can be changed by adding a pipe and the link text.

```
section 1
- page 1
- page 2

section 2
- page 3
- page 4|Page four
```

## Hidden pages

To hide a page, prefix its filename with an underscore. It will still be built and accessible, but its outgoing links are not tracked, and it's not shown in the directory. The filename of the built page removes the underscore.

## Backlinks

likki tracks internal links between pages; you can insert a page's backlinks into your HTML template. On build, likki will print to the console any page that isn't linked to by another page or by the site navigation. Unlisted pages are excluded from this check.

## Directory

A special page called `/directory` is created automatically, which lists every page in your wiki.

## License

MIT &copy; [Geoff Kimball](https://geoffkimball.com)
