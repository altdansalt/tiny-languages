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

## Notes

- Many awesome-lists overlap heavily; dedupe by canonical GitHub `owner/repo`.
- Esolang lists yield many trivially-tiny but low-value entries — keep but tag `esolang`.
