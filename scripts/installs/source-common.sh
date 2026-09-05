#!/usr/bin/env bash
# Small mechanics shared by the standalone source installers.
#
# Keep application policy (release discovery, versions, configure flags, and
# recipes) in the entrypoint that owns that application.  Every function here
# takes explicit arguments and returns status; there is no shared recipe state.

set -o pipefail

source_common_validate_jobs() {
    case "$1" in
        ''|*[!0-9]*)
            printf '%s\n' '--jobs must be a positive integer' >&2
            return 1
            ;;
    esac
    [ "$1" -gt 0 ] 2>/dev/null || {
        printf '%s\n' '--jobs must be a positive integer' >&2
        return 1
    }
}

source_common_validate_prefix() {
    local prefix="$1"
    [ -n "$prefix" ] || {
        printf '%s\n' 'prefix must not be empty' >&2
        return 1
    }
    case "$prefix" in
        /)
            printf '%s\n' 'refusing root directory as installation prefix' >&2
            return 1
            ;;
        /*) ;;
        *)
            printf '%s\n' "prefix must be an absolute path (got: $prefix)" >&2
            return 1
            ;;
    esac
    case "$prefix" in
        *[[:space:]]*)
            printf '%s\n' 'prefix must not contain whitespace: upstream build rules do not support it' >&2
            return 1
            ;;
    esac
}

source_common_cleanup() {
    local build_root="$1"
    if [ -n "$build_root" ] && [ -d "$build_root" ]; then
        rm -rf "$build_root"
    fi
}

source_common_download() {
    local url="$1"
    local destination="$2"
    printf '%s\n' "Downloading $url"
    rm -f "$destination"
    local status
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --silent --show-error --output "$destination" "$url"
        status=$?
    elif command -v wget >/dev/null 2>&1; then
        wget --output-document="$destination" "$url"
        status=$?
    else
        printf '%s\n' 'curl or wget is required to download release archives' >&2
        return 1
    fi
    [ "$status" -eq 0 ] || {
        printf '%s\n' "Download failed (status $status): $url" >&2
        return "$status"
    }
    [ -s "$destination" ] || {
        printf '%s\n' "Download produced an empty archive: $url" >&2
        return 1
    }
}

# Extract an archive only when it has the expected top-level source directory.
# The expected name is supplied by the owning entrypoint, so this helper does
# not need to know any application's archive naming policy.
source_common_extract() {
    local archive="$1"
    local destination="$2"
    local expected_root="$3"
    local top_root
    top_root=$(tar -tzf "$archive" | sed -n 's#^\([^/][^/]*\)/.*#\1#p' | sed -n '1p') || {
        printf '%s\n' "Cannot inspect source archive: $archive" >&2
        return 1
    }
    [ "$top_root" = "$expected_root" ] || {
        printf '%s\n' "Source archive has unexpected top-level directory: ${top_root:-none} (expected $expected_root)" >&2
        return 1
    }
    tar -xzf "$archive" -C "$destination" || {
        printf '%s\n' "Cannot extract source archive: $archive" >&2
        return 1
    }
    [ -d "$destination/$expected_root" ] || {
        printf '%s\n' "Source archive extracted without expected directory: $expected_root" >&2
        return 1
    }
}

# Supporting libraries/tools are pinned by the tmux entrypoint.  Use the
# native checksum utility on Linux or macOS and verify before extraction.
source_common_verify_sha256() {
    local archive="$1"
    local expected="$2"
    local actual
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$archive" | sed -n 's/^[[:space:]]*\([0-9a-fA-F]*\)[[:space:]].*/\1/p')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$archive" | sed -n 's/^[[:space:]]*\([0-9a-fA-F]*\)[[:space:]].*/\1/p')
    else
        printf '%s\n' 'sha256sum or shasum is required to verify pinned source archives' >&2
        return 1
    fi
    [ "$actual" = "$expected" ] || {
        printf '%s\n' "SHA256 verification failed for $archive" >&2
        printf '  expected: %s\n  actual:   %s\n' "$expected" "${actual:-unavailable}" >&2
        return 1
    }
}
