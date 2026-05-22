
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-24 - Bash Multi-Grep Performance Optimization
**Learning:** Running multiple sequential `grep` operations over a large decompiled source directory (thousands of files) results in severe I/O bottlenecking and redundant disk reads. `run_grep` wrapper functions that use `shift` incorrectly or omit checking for optional flags (like `-i`) can swallow flags as patterns.
**Action:** When a bash script needs to do multiple regex searches across a large file tree, first build a combined regex `(pattern1|pattern2|...)` and do a single-pass `grep` redirecting output to a temporary cache file (`mktemp`). Then, run the specific `grep` queries against this cache file to dramatically reduce execution time. When wrapping `grep` in a bash function, explicitly parse optional flags (like `-i`) to ensure the pattern parameter is not overwritten.
