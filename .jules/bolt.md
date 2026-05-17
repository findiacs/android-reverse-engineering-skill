
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.
## 2024-06-05 - Bash Multi-Grep Performance Anti-Pattern
**Learning:** Running multiple `grep` commands sequentially over a large directory of decompiled source files (thousands of files) is extremely slow due to redundant disk I/O and file parsing.
**Action:** When searching for multiple disjoint patterns across many files, use a single-pass `grep` with a combined regex to extract all potentially matching lines into a temporary cache file (`mktemp`). Then, run the specific, targeted `grep` commands against this much smaller cache file. This pattern turned O(N * M) disk reads into O(N + C * M) where C is the small number of matching lines, resulting in a ~75% reduction in execution time for `find-api-calls.sh`.
