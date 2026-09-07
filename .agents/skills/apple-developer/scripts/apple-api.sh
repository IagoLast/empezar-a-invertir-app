#!/bin/bash
# Apple App Store Connect API Helper
#
# Usage:
#   ./apple-api.sh /v1/apps
#   ./apple-api.sh "/v1/apps?filter[bundleId]=com.example.app"
#   ./apple-api.sh POST /v1/betaTesters '{"data": {...}}'

set -e

# Credentials are supplied by the caller, never inherited from another app.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export SKILL_DIR

generate_token() {
    node <<'NODE'
const jwt = require(process.env.SKILL_DIR + '/node_modules/jsonwebtoken');
const fs = require('fs');
const privateKey = fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH, 'utf8');
console.log(jwt.sign({}, privateKey, {
    algorithm: 'ES256',
    expiresIn: '20m',
    issuer: process.env.APPLE_ISSUER_ID,
    audience: 'appstoreconnect-v1',
    header: { alg: 'ES256', kid: process.env.APPLE_KEY_ID, typ: 'JWT' }
}));
NODE
}

# Main entry point
main() {
    local METHOD="GET"
    local ENDPOINT=""
    local BODY=""

    if [ $# -eq 0 ]; then
        echo "Usage: $0 [METHOD] ENDPOINT [BODY]"
        echo "  METHOD: GET, POST, PATCH, DELETE (default: GET)"
        echo "  ENDPOINT: /v1/apps, /v1/builds, etc."
        echo ""
        echo "Examples:"
        echo "  $0 /v1/apps"
        echo "  $0 \"/v1/apps?filter[bundleId]=com.example\""
        exit 0
    fi

    if [[ "$1" =~ ^(GET|POST|PATCH|DELETE|PUT)$ ]]; then
        METHOD="$1"
        ENDPOINT="$2"
        BODY="$3"
    else
        ENDPOINT="$1"
        BODY="$2"
    fi

    if [ -z "$ENDPOINT" ]; then
        echo "Error: Endpoint required"
        exit 1
    fi

    : "${APPLE_ISSUER_ID:?Set APPLE_ISSUER_ID}"
    : "${APPLE_KEY_ID:?Set APPLE_KEY_ID}"
    : "${APPLE_PRIVATE_KEY_PATH:?Set APPLE_PRIVATE_KEY_PATH to an external .p8 file}"
    export APPLE_ISSUER_ID APPLE_KEY_ID APPLE_PRIVATE_KEY_PATH
    TOKEN=$(generate_token)
    BASE_URL="https://api.appstoreconnect.apple.com"

    if [ -n "$BODY" ]; then
        curl --globoff --silent --show-error --fail-with-body -X "$METHOD" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$BODY" \
            "${BASE_URL}${ENDPOINT}"
    else
        curl --globoff --silent --show-error --fail-with-body -X "$METHOD" \
            -H "Authorization: Bearer $TOKEN" \
            "${BASE_URL}${ENDPOINT}"
    fi
}

main "$@"
