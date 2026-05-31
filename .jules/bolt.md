
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-17 - [Optimize multiple greps over large directories]
**Learning:** Running many individual `grep` searches over a large directory structure causes significant I/O and process overhead. Additionally, wrapping `grep` in a bash function without explicitly handling optional flags (like `-i`) causes the flag to be incorrectly treated as the search pattern, silently breaking functionality.
**Action:** Use a two-pass architecture for multiple `grep` searches: a "collect" pass that builds an array of patterns, followed by a single execution of a combined regex `grep` that outputs matches to a temporary cache file. Then, run the individual `grep` searches against the smaller cache file in an "execute" pass. In the "execute" pass, carefully constrain regexes (e.g., `:[0-9]+:.*(pattern)`) to avoid false positives on filenames or line numbers in the cached results. Always parse optional flags correctly in wrapper functions using `shift`.
