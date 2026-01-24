# Wiki Content

This directory contains prepared wiki pages for the GitHub wiki.

## Uploading to GitHub Wiki

After creating the GitHub repository:

1. Enable wiki in repository settings

2. Clone the wiki repository:
   ```bash
   git clone https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks.wiki.git
   cd tweakz-fydetab-hacks.wiki
   ```

3. Copy wiki content:
   ```bash
   cp /path/to/tweakz-fydetab-hacks/wiki/*.md .
   ```

4. Commit and push:
   ```bash
   git add .
   git commit -m "Initial wiki content"
   git push
   ```

## Pages

| File | Description |
|------|-------------|
| Home.md | Project overview and quick start |
| Installation.md | Image flashing and first boot |
| GPU-Driver-Fix.md | Panthor driver investigation |
| Recovery.md | Boot recovery procedures |
| Update-Procedure.md | Safe kernel update workflow |
| Building.md | Package and image building |

## Updating

Edit files in this directory, then copy to the wiki repository and push.

Or edit directly in the wiki repo after initial setup.
