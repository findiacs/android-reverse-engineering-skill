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

do_searches() {
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

ALL_PATTERNS=()

# Pass 1: Build ALL_PATTERNS
section() { :; }
run_grep() {
  local flags=""
  if [[ "$1" == "-i" ]]; then
    flags="-i"
    shift
  fi
  ALL_PATTERNS+=("$1")
}

do_searches

if [[ ${#ALL_PATTERNS[@]} -eq 0 ]]; then
  echo "No search patterns selected."
  exit 0
fi

COMBINED_REGEX=$(IFS='|'; echo "${ALL_PATTERNS[*]}")

CACHE_FILE=$(mktemp)
trap 'rm -f "$CACHE_FILE"' EXIT
# shellcheck disable=SC2086
grep $GREP_OPTS -iE "$COMBINED_REGEX" "$SOURCE_DIR" > "$CACHE_FILE" 2>/dev/null || true

# Pass 2: Output results
section() {
  echo
  echo "==== $1 ===="
  echo
}

run_grep() {
  local flags=""
  if [[ "$1" == "-i" ]]; then
    flags="-i"
    shift
  fi
  local pattern="$1"
  if [[ -s "$CACHE_FILE" ]]; then
    # Prefix pattern with :[0-9]+:.* to ensure we only match against the file content
    # and not the filename/line number prefix from the cached grep output,
    # preventing false positives on filenames.
    local safe_pattern=":[0-9]+:.*$pattern"
    if [[ -n "$flags" ]]; then
      grep -E -i "$safe_pattern" "$CACHE_FILE" 2>/dev/null || true
    else
      grep -E "$safe_pattern" "$CACHE_FILE" 2>/dev/null || true
    fi
  fi
}

do_searches

echo
echo "=== Search complete ==="