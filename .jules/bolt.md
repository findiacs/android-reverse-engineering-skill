
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2026-05-26 - [Optimize grep searching via two-pass combined regex]
**Learning:** Using multiple individual `grep -rn` calls on a large codebase results in massive I/O overhead due to repeated full filesystem traverses.
**Action:** Implement a two-pass mechanism where we first construct a large combined regex dynamically, execute a single `grep -rn -E` across the filesystem to build a small cache file, and then run specific sequential `grep` calls strictly targeting the content segment of the cache file output format `(e.g., :[0-9]+:.*pattern)` to maintain search accuracy and structure without false positives from filenames.
