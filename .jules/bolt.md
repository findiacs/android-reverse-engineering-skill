
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-24 - [Optimize find-api-calls.sh execution model]
**Learning:** Shell scripts using multiple sequential `grep` executions over large filesystems (like decompiled apps) suffer severely from disk I/O bottlenecks. Standardizing on a two-pass architecture (collect all regex patterns, do one massive `grep` run to a temp cache, then search against the cache) can reduce execution time by over 70%.
**Action:** When creating tools that need to search for many diverse patterns across a large codebase, use a dynamic two-pass cache execution model. Gather patterns in arrays, combine them into a single Regex search constraint string (`IFS="|"; COMB="$*"`) and run a single filesystem pass to `mktemp`, followed by granular cache lookups.
