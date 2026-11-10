#!/usr/bin/env bash
# Builds the zip that is uploaded to CurseForge (or used as a test build).
#
# The zip contains one folder, "Mentor", with only the files the game needs:
# the .toc, the Lua files and the Media folder. Repository files (.github,
# tools, README, CHANGELOG, RELEASING) are left out.
#
# The version in the file name comes from "## Version:" in Mentor.toc, so a
# test build is called Mentor-1.9.0+dev.zip and a release Mentor-1.9.0.zip.
#
# Usage:  tools/package.sh [output_directory]   (default: dist/)

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
output_directory="${1:-$repository_root/dist}"
addon_version="$(sed -n 's/^## Version: *//p' "$repository_root/Mentor.toc" | tr -d '\r')"

if [ -z "$addon_version" ]; then
    echo "Could not read '## Version:' from Mentor.toc" >&2
    exit 1
fi

# Copy the game files into a clean "Mentor" folder, then zip that folder.
staging_directory="$(mktemp -d)"
trap 'rm -rf "$staging_directory"' EXIT
mkdir -p "$staging_directory/Mentor"
cp "$repository_root/Mentor.toc" "$repository_root"/*.lua "$staging_directory/Mentor/"
cp -r "$repository_root/Media" "$staging_directory/Mentor/"

mkdir -p "$output_directory"
zip_path="$output_directory/Mentor-$addon_version.zip"
rm -f "$zip_path"
(cd "$staging_directory" && zip -qr "$zip_path" Mentor)

if [[ "$addon_version" == *+dev* ]]; then
    echo "Test build (not for CurseForge): $zip_path"
else
    echo "Release build: $zip_path"
fi
