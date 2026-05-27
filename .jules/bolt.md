
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-27 - [Optimize multiple greps with single-pass regex caching]
**Learning:** Running multiple `grep` commands sequentially across an entire directory tree introduces massive I/O overhead and redundant parsing, especially on large codebases.
**Action:** Use a single `grep -iE` pass with a dynamically built combined pattern to collect all potential matches into a temporary cache file (`mktemp`). Then run subsequent targeted `grep -E ":[0-9]+:.*(pattern)"` queries against this cache file to strictly match the content portion and dramatically reduce I/O time. Ensure temporary files are cleaned securely using `trap 'rm -f "$FILE"' EXIT`.
