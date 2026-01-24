# Project Setup Guide

This document walks through setting up the GitHub organization and repositories.

## Phase 1: Create GitHub Organization

1. Go to https://github.com/organizations/new
2. Choose "Free" plan
3. Organization name: `tweakz-fydetab-hacks`
4. Contact email: your email
5. This organization belongs to: My personal account
6. Complete setup

## Phase 2: Fork Repositories

### Fork pkgbuilds

1. Go to https://github.com/Linux-for-Fydetab-Duo/pkgbuilds
2. Click "Fork"
3. Owner: `tweakz-fydetab-hacks`
4. Repository name: `pkgbuilds`
5. Click "Create fork"

### Fork images

1. Go to https://github.com/Linux-for-Fydetab-Duo/images
2. Click "Fork"
3. Owner: `tweakz-fydetab-hacks`
4. Repository name: `images`
5. Click "Create fork"

## Phase 3: Create Main Repository

1. Go to https://github.com/organizations/tweakz-fydetab-hacks/repositories/new
2. Repository name: `tweakz-fydetab-hacks`
3. Description: "Personal Arch Linux setup for FydeTab Duo"
4. Public
5. Do NOT initialize with README (we have local content)
6. Click "Create repository"

## Phase 4: Push Local Content

### Main Repository

```bash
cd ~/builds/tweakz-fydetab-hacks

# Set up remote
git remote add origin git@github.com:tweakz-fydetab-hacks/tweakz-fydetab-hacks.git

# Add files and commit
git add .
git commit -m "Initial project structure"

git push -u origin main
```

### Update Existing pkgbuilds

Your local pkgbuilds at `~/builds/pkgbuilds` has uncommitted changes.

```bash
cd ~/builds/pkgbuilds

# Update remote to point to your fork
git remote set-url origin git@github.com:tweakz-fydetab-hacks/pkgbuilds.git

# Add upstream for syncing
git remote add upstream https://github.com/Linux-for-Fydetab-Duo/pkgbuilds.git

# Commit your changes
git add linux-fydetab/
git commit -m "Add Panthor GPU patch and build improvements

- Add enable-panthor-gpu.patch for Mali G610 support
- Add build.sh with logging and diagnostics
- Update kernel config: disable CONFIG_TRUSTED_KEYS
- Add documentation (RECOVERY.md, UPDATE-PROCEDURE.md, etc.)"

git push -u origin main
```

### Update Existing images

```bash
cd ~/builds/fydetab-images

# Update remote
git remote set-url origin git@github.com:tweakz-fydetab-hacks/images.git
git remote add upstream https://github.com/Linux-for-Fydetab-Duo/images.git

# Commit changes
git add .
git commit -m "Switch to mainline Mesa for Panthor support

- Change mesa-panfork-git to mesa in packages.aarch64
- Add local package cache support in pacman.conf"

# Push
git push -u origin main
```

## Phase 5: Add Submodules to Main Repo

After pushing both forks:

```bash
cd ~/builds/tweakz-fydetab-hacks

# Remove the .gitmodules placeholder
rm .gitmodules

# Add submodules pointing to your forks
git submodule add git@github.com:tweakz-fydetab-hacks/pkgbuilds.git pkgbuilds
git submodule add git@github.com:tweakz-fydetab-hacks/images.git images

# Commit
git add .gitmodules pkgbuilds images
git commit -m "Add pkgbuilds and images as submodules"

# Push
git push
```

## Phase 6: Enable Wiki

1. Go to https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks/settings
2. Scroll to "Features" section
3. Check "Wikis"
4. Save

### Push Wiki Content

```bash
# Clone the wiki repo
cd ~/builds
git clone git@github.com:tweakz-fydetab-hacks/tweakz-fydetab-hacks.wiki.git

# Copy prepared content
cp tweakz-fydetab-hacks/wiki/*.md tweakz-fydetab-hacks.wiki/

# Push
cd tweakz-fydetab-hacks.wiki
git add .
git commit -m "Initial wiki content"
git push
```

## Verification Checklist

After completing all phases:

- [ ] Organization exists: https://github.com/tweakz-fydetab-hacks
- [ ] Main repo exists with README visible
- [ ] pkgbuilds fork has your commits
- [ ] images fork has Mesa change
- [ ] Submodules show as links in main repo
- [ ] Wiki has pages: Home, GPU-Driver-Fix, Recovery, etc.

## Syncing with Upstream

To pull changes from Linux-for-Fydetab-Duo:

```bash
cd pkgbuilds  # or images
git fetch upstream
git merge upstream/main
# Resolve any conflicts
git push origin main
```

