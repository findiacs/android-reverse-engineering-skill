
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.
## 2024-05-25 - [Optimize grep searching]
**Learning:** Performing multiple recursive \`grep\` scans over a large codebase introduces significant disk I/O overhead.
**Action:** When creating bash scripts that execute multiple regex searches on large directories, combine patterns into a single execution pass to generate a smaller cache file using \`grep -rn\`, then perform targeted \`grep -E ':[0-9]+:.*(pattern)'\` queries against the cache to substantially improve script performance.
