#!/usr/bin/env bash
# Usage: ./scripts/bump_version.sh [major|minor|patch]
# Bumps the version in app/pubspec.yaml and outputs the new version.

set -euo pipefail

PUBSPEC="app/pubspec.yaml"
BUMP_TYPE="${1:-patch}"

# Read current version
CURRENT=$(grep -E '^version:' "$PUBSPEC" | head -1 | awk '{print $2}')
VERSION=$(echo "$CURRENT" | cut -d'+' -f1)
BUILD=$(echo "$CURRENT" | cut -d'+' -f2)

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Usage: $0 [major|minor|patch]"; exit 1 ;;
esac

NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${NEW_BUILD}"

# Update pubspec.yaml
sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"

echo "Bumped: $CURRENT -> $NEW_VERSION"
echo "Tag: v${MAJOR}.${MINOR}.${PATCH}"
