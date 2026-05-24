#!/usr/bin/env bash
# find-api-calls.sh — Search decompiled source for API calls and HTTP endpoints
set -euo pipefail

usage() {
  cat <<HELP
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
HELP
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

# Optimization: Two-pass execution model
# 1. Collect all patterns to build a combined regex cache.
# 2. Execute searches against the cache to reduce disk I/O.
declare -a ACTIVE_SECTIONS=()
declare -a ACTIVE_PATTERNS=()
declare -a ACTIVE_FLAGS=()
declare -a COMBINED_PATTERNS=()

CURRENT_SECTION=""

section() {
  CURRENT_SECTION="$1"
}

run_grep() {
  local grep_flags=""
  local pattern=""

  if [[ "$1" == "-i" ]]; then
    grep_flags="-i"
    pattern="$2"
  else
    pattern="$1"
  fi

  ACTIVE_SECTIONS+=("$CURRENT_SECTION")
  ACTIVE_PATTERNS+=("$pattern")
  ACTIVE_FLAGS+=("$grep_flags")

  COMBINED_PATTERNS+=("$pattern")
}

register_searches() {
  # --- Retrofit ---
  if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
    section "Retrofit Annotations"
    run_grep '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\('
    section "Retrofit Headers & Parameters"
    run_grep '@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\('
    section "Retrofit Base URL"
    run_grep '(baseUrl|base_url)\s*\('
  fi

  # --- OkHttp ---
  if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
    section "OkHttp Request Building"
    run_grep '(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)'
    section "OkHttp URL Construction"
    run_grep '(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()'
  fi

  # --- Volley ---
  if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
    section "Volley Requests"
    run_grep '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)'
  fi

  # --- Hardcoded URLs ---
  if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
    section "Hardcoded URLs (http:// and https://)"
    run_grep '"https?://[^"]+'
    section "HttpURLConnection"
    run_grep '(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)'
    section "WebView URLs"
    run_grep '(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)'
  fi

  # --- Auth patterns ---
  if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
    section "Authentication & API Keys"
    run_grep -i '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)'
    section "Base URLs and Constants"
    run_grep -i '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)'
  fi
}

# Execute Pass 1: Collect patterns
register_searches

# Build combined regex
if [[ ${#COMBINED_PATTERNS[@]} -eq 0 ]]; then
  echo "No search options selected."
  exit 0
fi

# Join patterns with |
COMBINED_REGEX=$(IFS="|"; echo "${COMBINED_PATTERNS[*]}")

# Create cache
CACHE_FILE=$(mktemp -t api_calls_cache.XXXXXX)
# Ensure cleanup
trap 'rm -f "$CACHE_FILE"' EXIT

# Run combined grep to populate cache.
# We use -i for the combined grep to catch patterns that require case-insensitivity.
# shellcheck disable=SC2086
grep $GREP_OPTS -iE "$COMBINED_REGEX" "$SOURCE_DIR" > "$CACHE_FILE" 2>/dev/null || true

# Execute Pass 2: Run specific queries against cache
last_section=""
for i in "${!ACTIVE_PATTERNS[@]}"; do
  sec="${ACTIVE_SECTIONS[$i]}"
  pat="${ACTIVE_PATTERNS[$i]}"
  flg="${ACTIVE_FLAGS[$i]}"

  if [[ "$sec" != "$last_section" ]]; then
    echo
    echo "==== $sec ===="
    echo
    last_section="$sec"
  fi

  # Search against cache. Format is file:line:content
  # Constraint regex to avoid matching filenames or line numbers:
  # grep -E ':[0-9]+:.*(pattern)'
  # To apply optional flags like -i, we inject them.
  # shellcheck disable=SC2086
  if [[ -n "$flg" ]]; then
    grep -E $flg ":[0-9]+:.*($pat)" "$CACHE_FILE" 2>/dev/null || true
  else
    grep -E ":[0-9]+:.*($pat)" "$CACHE_FILE" 2>/dev/null || true
  fi
done

echo
echo "=== Search complete ==="
