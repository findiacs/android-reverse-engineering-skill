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
CACHE_FILE=""

# Cleanup trap
cleanup() {
  if [[ -n "${CACHE_FILE:-}" && -f "$CACHE_FILE" ]]; then
    rm -f "$CACHE_FILE"
  fi
}
trap cleanup EXIT

section() {
  echo
  echo "==== $1 ===="
  echo
}

# Pass 1: Build a list of all patterns
declare -a ALL_PATTERNS=()

add_pattern() {
  ALL_PATTERNS+=("$1")
}

if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  add_pattern '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\('
  add_pattern '@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\('
  add_pattern '(baseUrl|base_url)\s*\('
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  add_pattern '(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)'
  add_pattern '(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()'
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  add_pattern '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)'
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  add_pattern '"https?://[^"]+'
  add_pattern '(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)'
  add_pattern '(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)'
fi

if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  # auth patterns need case insensitive match later, but we add them to the combined list
  add_pattern '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)'
  add_pattern '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)'
fi

# Build combined regex
if [[ ${#ALL_PATTERNS[@]} -gt 0 ]]; then
  COMBINED_REGEX=""
  for i in "${!ALL_PATTERNS[@]}"; do
    if [[ $i -eq 0 ]]; then
      COMBINED_REGEX="${ALL_PATTERNS[$i]}"
    else
      COMBINED_REGEX="${COMBINED_REGEX}|${ALL_PATTERNS[$i]}"
    fi
  done

  # Run combined grep into cache file
  CACHE_FILE=$(mktemp)
  # shellcheck disable=SC2086
  grep -i $GREP_OPTS -E "$COMBINED_REGEX" "$SOURCE_DIR" > "$CACHE_FILE" 2>/dev/null || true
fi

run_cached_grep() {
  local pattern="$1"
  local case_insensitive="${2:-}"
  if [[ -n "${CACHE_FILE:-}" && -f "$CACHE_FILE" ]]; then
    # Constrain search to the content portion: filename:line:content
    if [[ "$case_insensitive" == "-i" ]]; then
      grep -i -E ":[0-9]+:.*($pattern)" "$CACHE_FILE" || true
    else
      grep -E ":[0-9]+:.*($pattern)" "$CACHE_FILE" || true
    fi
  fi
}

# Pass 2: Execute specific greps against cache

# --- Retrofit ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  section "Retrofit Annotations"
  run_cached_grep '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\('
  section "Retrofit Headers & Parameters"
  run_cached_grep '@(Headers|Header|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\('
  section "Retrofit Base URL"
  run_cached_grep '(baseUrl|base_url)\s*\('
fi

# --- OkHttp ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  section "OkHttp Request Building"
  run_cached_grep '(Request\.Builder|HttpUrl|\.newCall|\.enqueue|addInterceptor|addNetworkInterceptor)'
  section "OkHttp URL Construction"
  run_cached_grep '(\.url\s*\(|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\()'
fi

# --- Volley ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  section "Volley Requests"
  run_cached_grep '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue)'
fi

# --- Hardcoded URLs ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  section "Hardcoded URLs (http:// and https://)"
  run_cached_grep '"https?://[^"]+'
  section "HttpURLConnection"
  run_cached_grep '(openConnection|setRequestMethod|HttpURLConnection|HttpsURLConnection)'
  section "WebView URLs"
  run_cached_grep '(loadUrl|loadData|evaluateJavascript|addJavascriptInterface|WebViewClient|WebChromeClient)'
fi

# --- Auth patterns ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  section "Authentication & API Keys"
  run_cached_grep '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token)' -i
  section "Base URLs and Constants"
  run_cached_grep '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME)' -i
fi

echo
echo "=== Search complete ==="
