
## 2024-05-16 - [Optimize basename in bash loops]
**Learning:** Calling the external command `basename` inside loops in shell scripts creates significant subshell process-forking overhead.
**Action:** Use native bash parameter expansion (e.g., `${var##*/}` for basename, and `${var%.ext}` to remove extensions) to achieve the same result orders of magnitude faster.

## 2024-05-28 - [Single-pass combined regex grep with cache]
**Learning:** Running multiple `grep` commands across a large directory is extremely slow due to repeated I/O operations and directory traversal overhead. Additionally, when searching a cached file containing `filename:line:content`, running a naive grep on it will result in false positives (e.g. searching for `WebViewClient` might match a filename `WebViewClient.java`).
**Action:** Use a two-pass approach. First, build an array of all patterns to be searched. Combine these into a single regex string (e.g. `(pattern1|pattern2)`). Perform one `grep` traversal of the directory with this combined pattern and save the results to a temporary file created via `mktemp` (ensuring to set up a `trap` for cleanup). Then, run individual specific queries against this much smaller cache file using a constrained regex like `:[0-9]+:.*(pattern)` to isolate matching to the content portion only.
