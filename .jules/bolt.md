
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-18 - Single-Pass Grep Filename Matching Caveat
**Learning:** When optimizing scripts to use a single-pass `grep -rn` caching strategy, the resulting cache file contains lines formatted as `filename:line:content`. Subsequent `grep` queries against this cache file might accidentally match against the filename string instead of just the content string (e.g. searching for `BASE_URL` hits a file named `BASE_URL.java` regardless of the file content).
**Action:** Accept this minor false positive trade-off for reconnaissance scripts where speed is favored over perfect parsing, rather than introducing complex `awk`/`sed` logic to strip and re-add filenames.
