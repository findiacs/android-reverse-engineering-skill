#!/usr/bin/env bash
# find-api-calls.sh — Search decompiled source for API calls and HTTP endpoints
set -euo pipefail

usage() {
  cat <<EOF
Usage: find-api-calls.sh <source-dir> [OPTIONS]

Search decompiled Java/Kotlin source for HTTP API calls and endpoints.

Arguments:
  <source-dir>    Path to the decompiled sources directory

Options:
  --retrofit      Search only for Retrofit annotations
  --okhttp        Search only for OkHttp patterns
  --volley        Search only for Volley patterns
  --urls          Search only for hardcoded URLs
  --auth          Search only for auth-related patterns
  --all           Search all patterns (default)
  -h, --help      Show this help message

Output:
  Results are printed as file:line:match for easy navigation.
EOF
  exit 0
}

SOURCE_DIR=""
SEARCH_RETROFIT=false
SEARCH_OKHTTP=false
SEARCH_VOLLEY=false
SEARCH_URLS=false
SEARCH_AUTH=false
SEARCH_ALL=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --retrofit) SEARCH_RETROFIT=true; SEARCH_ALL=false; shift ;;
    --okhttp)   SEARCH_OKHTTP=true;   SEARCH_ALL=false; shift ;;
    --volley)   SEARCH_VOLLEY=true;    SEARCH_ALL=false; shift ;;
    --urls)     SEARCH_URLS=true;      SEARCH_ALL=false; shift ;;
    --auth)     SEARCH_AUTH=true;      SEARCH_ALL=false; shift ;;
    --all)      SEARCH_ALL=true; shift ;;
    -h|--help)  usage ;;
    -*)         echo "Error: Unknown option $1" >&2; usage ;;
    *)          SOURCE_DIR="$1"; shift ;;
  esac
done

if [[ -z "$SOURCE_DIR" ]]; then
  echo "Error: No source directory specified." >&2
  usage
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: Directory not found: $SOURCE_DIR" >&2
  exit 1
fi

GREP_OPTS="-rn --include=*.java --include=*.kt"

# Define patterns to search for to maintain DRY principles
# Note: we use arrays to make iterating and combining easier
PATTERNS_RETROFIT=(
  '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\('
  '@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\('
  '(baseUrl|base_url)\s*\('
)

PATTERNS_OKHTTP=(
  '(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)'
  '(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()'
)

PATTERNS_VOLLEY=(
  '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)'
)

PATTERNS_URLS=(
  '"https?://[^"]+'
  '(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)'
  '(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)'
)

PATTERNS_AUTH=(
  '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)'
  '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)'
)

# Build a single combined regex for the initial cache pass to reduce I/O overhead
ALL_PATTERNS_ARRAY=()
[[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]] && ALL_PATTERNS_ARRAY+=("${PATTERNS_RETROFIT[@]}")
[[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]] && ALL_PATTERNS_ARRAY+=("${PATTERNS_OKHTTP[@]}")
[[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]] && ALL_PATTERNS_ARRAY+=("${PATTERNS_VOLLEY[@]}")
[[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]] && ALL_PATTERNS_ARRAY+=("${PATTERNS_URLS[@]}")
[[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]] && ALL_PATTERNS_ARRAY+=("${PATTERNS_AUTH[@]}")

# Join all patterns with '|'
COMBINED_PATTERN=$(IFS="|"; echo "${ALL_PATTERNS_ARRAY[*]}")

CACHE_FILE=$(mktemp -t "find-api-calls.XXXXXX")
# Clean up temp file on exit
trap 'rm -f "$CACHE_FILE"' EXIT

# First pass: search everything requested, output matching lines to cache file
# shellcheck disable=SC2086
grep $GREP_OPTS -iE "$COMBINED_PATTERN" "$SOURCE_DIR" > "$CACHE_FILE" 2>/dev/null || true

section() {
  echo
  echo "==== $1 ===="
  echo
}

run_grep() {
  local opts=""
  if [[ "$1" == "-i" ]]; then
    opts="-i"
    shift
  fi
  local pattern="$1"
  # Subsequent greps only read the much smaller cache file
  grep -E $opts "$pattern" "$CACHE_FILE" 2>/dev/null || true
}

# --- Retrofit ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  section "Retrofit Annotations"
  run_grep "${PATTERNS_RETROFIT[0]}"
  section "Retrofit Headers & Parameters"
  run_grep "${PATTERNS_RETROFIT[1]}"
  section "Retrofit Base URL"
  run_grep "${PATTERNS_RETROFIT[2]}"
fi

# --- OkHttp ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  section "OkHttp Request Building"
  run_grep "${PATTERNS_OKHTTP[0]}"
  section "OkHttp URL Construction"
  run_grep "${PATTERNS_OKHTTP[1]}"
fi

# --- Volley ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  section "Volley Requests"
  run_grep "${PATTERNS_VOLLEY[0]}"
fi

# --- Hardcoded URLs ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  section "Hardcoded URLs (http:// and https://)"
  run_grep "${PATTERNS_URLS[0]}"
  section "HttpURLConnection"
  run_grep "${PATTERNS_URLS[1]}"
  section "WebView URLs"
  run_grep "${PATTERNS_URLS[2]}"
fi

# --- Auth patterns ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  section "Authentication & API Keys"
  run_grep -i "${PATTERNS_AUTH[0]}"
  section "Base URLs and Constants"
  run_grep -i "${PATTERNS_AUTH[1]}"
fi

echo
echo "=== Search complete ==="
