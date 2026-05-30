
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-30 - [Optimize massive grep scanning with two-pass combined regex]
**Learning:** Running multiple `grep -rn` commands sequentially across a large file tree causes significant I/O bottleneck overhead, especially when searching for many independent regex patterns.
**Action:** Implement a two-pass grep execution model: a "collection" pass that builds a combined `|` regex pattern, followed by a single full-tree `grep` that saves results to a temporary cache file (`mktemp`). Then, execute the original, specific pattern searches against this much smaller cache file using strictly constrained regex matching (e.g., `:[0-9]+:.*($pattern)`) to drastically reduce disk I/O while preserving original match behavior without false positives.
