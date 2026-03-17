#!/bin/bash
# release.sh — Build, package, create GitHub release, and update Homebrew formula
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAP_REPO="${TAP_REPO:-$HOME/Github/homebrew-tap}"
GITHUB_REPO="ebarti/claude-notifier"

# -----------------------------------------------------------------------
# 1. Determine version
# -----------------------------------------------------------------------
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh <version>"
    echo "  e.g. ./release.sh 1.1.0"
    exit 1
fi

TAG="v$VERSION"
TARBALL_NAME="claude-notifier-${VERSION}-macos.tar.gz"

echo "==> Releasing $TAG"

# -----------------------------------------------------------------------
# 2. Verify working tree is clean
# -----------------------------------------------------------------------
if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]; then
    echo "Error: Working tree is not clean. Commit or stash changes first."
    exit 1
fi

# -----------------------------------------------------------------------
# 3. Build
# -----------------------------------------------------------------------
echo "==> Building..."
make -C "$SCRIPT_DIR" clean
make -C "$SCRIPT_DIR" build

# -----------------------------------------------------------------------
# 4. Package tarball (with proper top-level directory for Homebrew)
# -----------------------------------------------------------------------
echo "==> Packaging tarball..."
STAGING_DIR=$(mktemp -d)
PKG_DIR="$STAGING_DIR/claude-notifier-$VERSION"
mkdir -p "$PKG_DIR"
cp -R "$SCRIPT_DIR/build/ClaudeNotifier.app" "$PKG_DIR/"
TARBALL="$STAGING_DIR/$TARBALL_NAME"
tar -czf "$TARBALL" -C "$STAGING_DIR" "claude-notifier-$VERSION"

SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
echo "    SHA256: $SHA256"

# -----------------------------------------------------------------------
# 5. Tag and push
# -----------------------------------------------------------------------
echo "==> Tagging $TAG..."
git -C "$SCRIPT_DIR" tag -f "$TAG"
git -C "$SCRIPT_DIR" push origin "$TAG" --force

# -----------------------------------------------------------------------
# 6. Create GitHub release
# -----------------------------------------------------------------------
echo "==> Creating GitHub release..."
gh release delete "$TAG" --repo "$GITHUB_REPO" --yes 2>/dev/null || true
gh release create "$TAG" "$TARBALL" \
    --repo "$GITHUB_REPO" \
    --title "$TAG" \
    --notes "Release $TAG"

# -----------------------------------------------------------------------
# 7. Update Homebrew formula
# -----------------------------------------------------------------------
if [ -d "$TAP_REPO" ]; then
    echo "==> Updating Homebrew formula..."
    FORMULA="$TAP_REPO/Formula/claude-notifier.rb"

    if [ ! -f "$FORMULA" ]; then
        echo "Error: Formula not found at $FORMULA"
        exit 1
    fi

    # Update version in URL
    sed -i '' "s|/download/v[^/]*/claude-notifier-[^\"]*|/download/$TAG/$TARBALL_NAME|" "$FORMULA"
    # Update SHA256
    sed -i '' "s/sha256 \"[a-f0-9]*\"/sha256 \"$SHA256\"/" "$FORMULA"

    cd "$TAP_REPO"
    git add Formula/claude-notifier.rb
    git commit -m "Update claude-notifier to $TAG"
    git push
    echo "    Homebrew formula updated and pushed."
else
    echo ""
    echo "    Homebrew tap not found at $TAP_REPO"
    echo "    Update the formula manually with:"
    echo "      url: https://github.com/$GITHUB_REPO/releases/download/$TAG/$TARBALL_NAME"
    echo "      sha256: $SHA256"
fi

# -----------------------------------------------------------------------
# 8. Cleanup
# -----------------------------------------------------------------------
rm -rf "$STAGING_DIR"

echo ""
echo "==> Released $TAG"
echo "    GitHub:   https://github.com/$GITHUB_REPO/releases/tag/$TAG"
echo "    Homebrew: brew update && brew upgrade claude-notifier"
