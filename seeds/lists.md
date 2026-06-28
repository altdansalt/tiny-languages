# Source lists

Lists we mine for candidate tiny languages. The pipeline can scrape these for
GitHub repo links (`scripts/fetch_lists.sh`).

## Seed lists (provided)

- https://github.com/hummanta/awesome-compilers
- https://github.com/BaseMax/AwesomeInterpreter
- https://github.com/ChessMax/awesome-programming-languages
- https://github.com/appcypher/awesome-wasm-langs

## Additional lists (found / known)

- https://github.com/marcobambini/awesome-interpreters
- https://github.com/aalhour/awesome-compilers (frequently-referenced compiler list)
- https://github.com/pfultz2/awesome-interpreters
- https://github.com/leereilly/list-of-programming-languages (esolang-heavy)
- https://github.com/angrykoala/awesome-esolangs (tiny by nature)
- https://github.com/kanaka/mal (Make-a-Lisp: 80+ tiny Lisp implementations in one repo)
- https://rosettacode.org (cross-reference for small language tasks)

## Ways to find more lists (pipeline ideas)

- GitHub topic search: `topic:awesome-list` + (`compiler` OR `interpreter` OR `programming-language`).
- GitHub search for repos with `topic:tiny-language`, `topic:scripting-language`,
  `topic:embeddable`, `topic:small-language`.
- Crawl "awesome-*" READMEs for links to *other* awesome lists (lists of lists),
  e.g. https://github.com/sindresorhus/awesome.
- Search for "single-file" / "header-only" interpreters (good tiny signal).

## Bootstrap-the-world seeds (the floor of the stack)

For tracing a path from a tiny binary seed up to a full C toolchain — see
`BOOTSTRAP.md`. These are the canonical projects to turn into verified recipes:

- https://github.com/oriansj/stage0 — hex0 → hex1 → … from a few hundred bytes
- https://github.com/oriansj/M2-Planet — a minimal C compiler reachable from stage0
- https://github.com/oriansj/mes / https://www.gnu.org/software/mes/ — Scheme + mescc;
  can build a tinycc that can build GCC
- https://github.com/fosslinux/live-bootstrap — the full documented path from a
  ~357-byte seed to a working GCC/userland
- https://github.com/TinyCC/tinycc — tcc self-host + `tccboot` (built Linux 2.4)
- https://musl.libc.org / https://github.com/bminor/musl — a small libc to build from source

## Notes

- Many awesome-lists overlap heavily; dedupe by canonical GitHub `owner/repo`.
- Esolang lists yield many trivially-tiny but low-value entries — keep but tag `esolang`.
