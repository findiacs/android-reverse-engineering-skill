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

# --- Performance Optimization ---
# To avoid multiple full directory scans via grep, we build a combined regex of all
# possible patterns. We run a single case-insensitive search over the directory,
# saving matching lines to a temporary cache file. Then, individual section greps
# are executed against this much smaller cache file, significantly reducing I/O overhead.

# Create a temporary file securely
TMP_CACHE=$(mktemp)
# Ensure temporary file is cleaned up on exit
trap 'rm -f "$TMP_CACHE"' EXIT

# Build the combined regex dynamically to maintain DRY principles
PATTERNS=()
if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  PATTERNS+=('@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\(')
  PATTERNS+=('@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\(')
  PATTERNS+=('(baseUrl|base_url)\s*\(')
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  PATTERNS+=('(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)')
  PATTERNS+=('(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()')
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  PATTERNS+=('(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)')
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  PATTERNS+=('"https?://[^"]+')
  PATTERNS+=('(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)')
  PATTERNS+=('(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)')
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  PATTERNS+=('(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)')
  PATTERNS+=('(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)')
fi

# Join patterns with OR operator '|'
COMBINED_REGEX=$(IFS='|'; echo "${PATTERNS[*]}")

# Perform a single pass scan into the temp file.
# Note: Since auth search might be case insensitive, we use -i for the combined search.
if [[ -n "$COMBINED_REGEX" ]]; then
  # shellcheck disable=SC2086
  grep $GREP_OPTS -E -i "$COMBINED_REGEX" "$SOURCE_DIR" > "$TMP_CACHE" 2>/dev/null || true
fi

section() {
  echo
  echo "==== $1 ===="
  echo
}

run_grep() {
  local pattern="$1"
  local is_case_insensitive="${2:-false}"

  # Only run grep if the cache file is not empty
  if [[ -s "$TMP_CACHE" ]]; then
    if [[ "$is_case_insensitive" == "true" ]]; then
      grep -E -i "$pattern" "$TMP_CACHE" || true
    else
      grep -E "$pattern" "$TMP_CACHE" || true
    fi
  fi
}

# --- Retrofit ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  section "Retrofit Annotations"
  run_grep '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\(' false
  section "Retrofit Headers & Parameters"
  run_grep '@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\(' false
  section "Retrofit Base URL"
  run_grep '(baseUrl|base_url)\s*\(' false
fi

# --- OkHttp ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  section "OkHttp Request Building"
  run_grep '(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)' false
  section "OkHttp URL Construction"
  run_grep '(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()' false
fi

# --- Volley ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  section "Volley Requests"
  run_grep '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)' false
fi

# --- Hardcoded URLs ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  section "Hardcoded URLs (http:// and https://)"
  run_grep '"https?://[^"]+' false
  section "HttpURLConnection"
  run_grep '(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)' false
  section "WebView URLs"
  run_grep '(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)' false
fi

# --- Auth patterns ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  section "Authentication & API Keys"
  run_grep '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)' true
  section "Base URLs and Constants"
  run_grep '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)' true
fi

echo
echo "=== Search complete ==="
