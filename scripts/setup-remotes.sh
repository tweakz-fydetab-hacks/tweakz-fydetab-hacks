#!/bin/bash
# Set up git remotes for the tweakz-fydetab-hacks project
#
# Run this AFTER creating the GitHub organization and forking/creating repos:
# 1. Create GitHub org: tweakz-fydetab-hacks
# 2. Fork Linux-for-Fydetab-Duo/pkgbuilds to tweakz-fydetab-hacks/pkgbuilds
# 3. Fork Linux-for-Fydetab-Duo/images to tweakz-fydetab-hacks/images
# 4. Fork Linux-for-Fydetab-Duo/calamares-settings to tweakz-fydetab-hacks/calamares-settings
# 5. Create tweakz-fydetab-hacks/tweakz-fydetab-hacks (main repo)
# 6. Run this script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Organization name
ORG="tweakz-fydetab-hacks"

echo "=========================================="
echo "  Git Remote Setup for $ORG"
echo "=========================================="
echo ""
echo "This script will:"
echo "1. Set up remotes for the main repository"
echo "2. Set up remotes for pkgbuilds submodule"
echo "3. Set up remotes for images submodule"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Main repository
log_info "Setting up main repository remotes..."
cd "$ROOT_DIR"

# Check if origin exists
if git remote | grep -q "^origin$"; then
    log_warn "origin remote exists, updating URL..."
    git remote set-url origin "git@github.com:$ORG/tweakz-fydetab-hacks.git"
else
    git remote add origin "git@github.com:$ORG/tweakz-fydetab-hacks.git"
fi

echo "Main repo remotes:"
git remote -v
echo ""

# pkgbuilds submodule
if [ -d "$ROOT_DIR/pkgbuilds/.git" ] || [ -f "$ROOT_DIR/pkgbuilds/.git" ]; then
    log_info "Setting up pkgbuilds submodule remotes..."
    cd "$ROOT_DIR/pkgbuilds"

    # Set origin to org fork
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "git@github.com:$ORG/pkgbuilds.git"
    else
        git remote add origin "git@github.com:$ORG/pkgbuilds.git"
    fi

    # Add upstream for syncing with Linux-for-Fydetab-Duo
    if git remote | grep -q "^upstream$"; then
        git remote set-url upstream "https://github.com/Linux-for-Fydetab-Duo/pkgbuilds.git"
    else
        git remote add upstream "https://github.com/Linux-for-Fydetab-Duo/pkgbuilds.git"
    fi

    echo "pkgbuilds remotes:"
    git remote -v
    echo ""
else
    log_warn "pkgbuilds submodule not initialized"
fi

# images submodule
if [ -d "$ROOT_DIR/images/.git" ] || [ -f "$ROOT_DIR/images/.git" ]; then
    log_info "Setting up images submodule remotes..."
    cd "$ROOT_DIR/images"

    # Set origin to org fork
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "git@github.com:$ORG/images.git"
    else
        git remote add origin "git@github.com:$ORG/images.git"
    fi

    # Add upstream for syncing (note: upstream repo is named "releases")
    if git remote | grep -q "^upstream$"; then
        git remote set-url upstream "https://github.com/Linux-for-Fydetab-Duo/releases.git"
    else
        git remote add upstream "https://github.com/Linux-for-Fydetab-Duo/releases.git"
    fi

    echo "images remotes:"
    git remote -v
    echo ""
else
    log_warn "images submodule not initialized"
fi

# calamares-settings submodule
if [ -d "$ROOT_DIR/calamares-settings/.git" ] || [ -f "$ROOT_DIR/calamares-settings/.git" ]; then
    log_info "Setting up calamares-settings submodule remotes..."
    cd "$ROOT_DIR/calamares-settings"

    # Set origin to org fork
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "git@github.com:$ORG/calamares-settings.git"
    else
        git remote add origin "git@github.com:$ORG/calamares-settings.git"
    fi

    # Add upstream for syncing
    if git remote | grep -q "^upstream$"; then
        git remote set-url upstream "https://github.com/Linux-for-Fydetab-Duo/calamares-settings.git"
    else
        git remote add upstream "https://github.com/Linux-for-Fydetab-Duo/calamares-settings.git"
    fi

    echo "calamares-settings remotes:"
    git remote -v
    echo ""
else
    log_warn "calamares-settings submodule not initialized"
fi

log_info "Remote setup complete!"
echo ""
echo "Next steps:"
echo "1. Verify SSH key is added to GitHub"
echo "2. Push main repo: git push -u origin main"
echo "3. Push submodules from their directories"
echo ""
echo "To sync from upstream later:"
echo "  cd pkgbuilds && git fetch upstream && git merge upstream/main"
