# ChunkHound Supported Languages

## Programming languages

| Language        | Extensions / filenames                                                 |
|-----------------|------------------------------------------------------------------------|
| Python          | `.py`, `.pyi`, `.pyw`                                                  |
| Java            | `.java`                                                                |
| C#              | `.cs`, `.csx`                                                          |
| TypeScript      | `.ts`, `.mts`, `.cts`                                                  |
| JavaScript      | `.js`, `.mjs`, `.cjs`                                                  |
| TSX             | `.tsx`                                                                 |
| JSX             | `.jsx`                                                                 |
| Groovy          | `.groovy`, `.gvy`, `.gy`, `.gsh`                                       |
| Kotlin          | `.kt`, `.kts`                                                          |
| Go              | `.go`                                                                  |
| Haskell         | `.hs`, `.lhs`, `.hs-boot`, `.hsig`, `.hsc`                             |
| Rust            | `.rs`                                                                  |
| Zig             | `.zig`                                                                 |
| Bash / shell    | `.sh`, `.bash`, `.zsh`, `.fish`                                        |
| C               | `.c`, `.h`                                                             |
| C++             | `.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`           |
| MATLAB          | `.m` (ambiguous with Objective-C; ChunkHound disambiguates by content) |
| Objective-C     | `.mm`                                                                  |
| PHP             | `.php`, `.phtml`, `.php3`, `.php4`, `.php5`, `.phps`                   |
| SQL             | `.sql`                                                                 |
| Swift           | `.swift`, `.swiftinterface`                                            |
| Dart            | `.dart`                                                                |
| Elixir          | `.ex`, `.exs`                                                          |
| Lua             | `.lua`                                                                 |
| TwinCAT (PLC)   | `.tcpou`, `.TcPOU`                                                     |

## Build and infrastructure

| Language        | Extensions / filenames                              |
|-----------------|-----------------------------------------------------|
| Makefile        | `.mk`, `.mak`, `.make`, `Makefile`, `GNUmakefile`   |
| HCL / Terraform | `.hcl`, `.tf`, `.tfvars`                            |

## Web and UI

| Language        | Extensions / filenames                                            |
|-----------------|-------------------------------------------------------------------|
| HTML            | `.html`, `.htm`, `.xhtml`                                         |
| CSS             | `.css`                                                            |
| SCSS            | `.scss` (falls back to text when the SCSS grammar is unavailable) |
| Vue             | `.vue`                                                            |
| Svelte          | `.svelte`                                                         |
| Jinja templates | `.jinja`, `.j2`, `.njk` (parsed with the HTML grammar)            |

## Data and configuration

| Language        | Extensions / filenames                                |
|-----------------|-------------------------------------------------------|
| JSON            | `.json`                                               |
| YAML            | `.yaml`, `.yml`                                       |
| TOML            | `.toml`                                               |
| Markdown        | `.md`, `.markdown`, `.mdown`, `.mkd`, `.mdx`          |

## Fallback parsers

Line-based chunks, no structural understanding. `search` (regex / semantic) still matches their content; `code_research` will not surface architectural relationships.

| Language | Extensions / filenames     |
|----------|----------------------------|
| Text     | `.txt`, `.text`, `.sass`   |
| PDF      | `.pdf`                     |
