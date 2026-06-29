#!/bin/sh
# Obtain a bearer token for the seeded dev user (tim@apple.dev).
# Only the token is written to stdout; all diagnostic output goes to stderr.
set -e

BASE_URL="${TWENTY_BASE_URL:-http://localhost:3000}"
EMAIL="tim@apple.dev"
PASSWORD="tim@apple.dev"

log() { printf '%s\n' "$*" >&2; }

# Step 1 — get a short-lived login token via GraphQL mutation
LOGIN_BODY=$(jq -n \
  --arg email    "$EMAIL" \
  --arg password "$PASSWORD" \
  --arg origin   "$BASE_URL" \
  '{
    query: "mutation GetLoginTokenFromCredentials($email:String!,$password:String!,$origin:String!){ getLoginTokenFromCredentials(email:$email,password:$password,origin:$origin){ loginToken{ token } } }",
    variables: { email: $email, password: $password, origin: $origin }
  }')

log "Requesting login token for ${EMAIL}..."
LOGIN_RESPONSE=$(curl -sf -X POST "${BASE_URL}/metadata" \
  -H "Content-Type: application/json" \
  -H "Origin: ${BASE_URL}" \
  -d "$LOGIN_BODY")

LOGIN_TOKEN=$(printf '%s' "$LOGIN_RESPONSE" | \
  jq -r '.data.getLoginTokenFromCredentials.loginToken.token // empty')

if [ -z "$LOGIN_TOKEN" ]; then
  log "ERROR: could not get login token"
  log "Response: $LOGIN_RESPONSE"
  exit 1
fi

# Step 2 — exchange the login token for a workspace-agnostic access token
AUTH_BODY=$(jq -n \
  --arg loginToken "$LOGIN_TOKEN" \
  --arg origin     "$BASE_URL" \
  '{
    query: "mutation GetAuthTokensFromLoginToken($loginToken:String!,$origin:String!){ getAuthTokensFromLoginToken(loginToken:$loginToken,origin:$origin){ tokens{ accessOrWorkspaceAgnosticToken{ token } } } }",
    variables: { loginToken: $loginToken, origin: $origin }
  }')

log "Exchanging login token for access token..."
AUTH_RESPONSE=$(curl -sf -X POST "${BASE_URL}/metadata" \
  -H "Content-Type: application/json" \
  -H "Origin: ${BASE_URL}" \
  -d "$AUTH_BODY")

ACCESS_TOKEN=$(printf '%s' "$AUTH_RESPONSE" | \
  jq -r '.data.getAuthTokensFromLoginToken.tokens.accessOrWorkspaceAgnosticToken.token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  log "ERROR: could not get access token"
  log "Response: $AUTH_RESPONSE"
  exit 1
fi

log "Successfully obtained access token"
printf '%s' "$ACCESS_TOKEN"
