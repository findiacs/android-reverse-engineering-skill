
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-21 - [Optimize massive grep operations via regex caching]
**Learning:** Running `grep -rn` multiple times with specific string patterns over a massive source tree creates an enormous I/O bottleneck due to repeatedly traversing all directories and parsing all files from scratch for every specific query.
**Action:** Instead, build a combined dynamic regex by joining an array of all needed specific search strings with the OR operator (`|`). Execute one massive single-pass case-insensitive `grep` into a temporary `mktemp` cache file. Subsequent specific `grep` queries then execute against this tiny cache file instead of the filesystem, resulting in an O(n) -> O(1) performance increase on subsequent checks (e.g. 6x faster on just 2k files, exponentially more on real decompiled projects). Ensure to `trap` the temporary file securely.
