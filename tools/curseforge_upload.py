#!/usr/bin/env python3
"""Uploads a finished Mentor release to CurseForge.

Run by the GitHub Action in .github/workflows/curseforge.yml. It only uses the
Python standard library, so nothing has to be installed on the runner.

Two modes:
  list-versions   Prints CurseForge's WoW game versions that look like WoW
                  Forever (a dry run: checks the token and which game version
                  the upload would use, uploads nothing).
  upload <zip>    Uploads the zip as a Release with this version's changelog.

Settings come from environment variables:
  CF_API_KEY          CurseForge API token (a GitHub secret - never in the repo)
  CF_PROJECT_ID       CurseForge project id (Mentor: 1795097)
  CF_GAME_VERSION_ID  Optional: the exact CurseForge game version id to use.
                      When empty, the newest version whose type is "Forever"
                      is picked automatically.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

CURSEFORGE_API_ROOT = "https://wow.curseforge.com/api"
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOREVER_TYPE_WORD = "forever"


def read_required_setting(setting_name):
    setting_value = os.environ.get(setting_name, "").strip()
    if not setting_value:
        sys.exit(f"Missing setting {setting_name} (add it under the repository's Actions secrets/variables).")
    return setting_value


def call_curseforge(path, api_token, request_body=None, content_type=None):
    """GET (or POST when a body is given) a CurseForge API path and return the parsed JSON."""
    request = urllib.request.Request(CURSEFORGE_API_ROOT + path, data=request_body)
    request.add_header("X-Api-Token", api_token)
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as http_error:
        error_text = http_error.read().decode("utf-8", "replace")
        sys.exit(f"CurseForge answered {http_error.code} for {path}: {error_text}")


def find_forever_game_versions(api_token):
    """Returns (forever_types, forever_versions) as CurseForge lists them."""
    version_types = call_curseforge("/game/version-types", api_token)
    forever_types = [
        version_type for version_type in version_types
        if FOREVER_TYPE_WORD in (version_type.get("name", "") + " " + version_type.get("slug", "")).lower()
    ]
    forever_type_ids = {version_type["id"] for version_type in forever_types}
    all_versions = call_curseforge("/game/versions", api_token)
    forever_versions = [
        game_version for game_version in all_versions
        if game_version.get("gameVersionTypeID") in forever_type_ids
    ]
    return forever_types, forever_versions


def choose_game_version_id(api_token):
    configured_version_id = os.environ.get("CF_GAME_VERSION_ID", "").strip()
    if configured_version_id:
        return int(configured_version_id)
    _, forever_versions = find_forever_game_versions(api_token)
    if not forever_versions:
        sys.exit("CurseForge lists no 'Forever' game version. Run the action with "
                 "'list-versions' and set the repository variable CF_GAME_VERSION_ID by hand.")
    # The newest Forever version has the highest id.
    return max(game_version["id"] for game_version in forever_versions)


def read_addon_version():
    with open(os.path.join(REPOSITORY_ROOT, "Mentor.toc"), encoding="utf-8") as toc_file:
        for toc_line in toc_file:
            version_match = re.match(r"## Version:\s*(\S+)", toc_line)
            if version_match:
                return version_match.group(1)
    sys.exit("Could not read '## Version:' from Mentor.toc")


def read_changelog_section(addon_version):
    """The lines under '## <version> - <date>' in CHANGELOG.md, up to the next '## '."""
    with open(os.path.join(REPOSITORY_ROOT, "CHANGELOG.md"), encoding="utf-8") as changelog_file:
        changelog_lines = changelog_file.read().splitlines()
    section_lines, is_inside_section = [], False
    for changelog_line in changelog_lines:
        if changelog_line.startswith("## "):
            if is_inside_section:
                break
            is_inside_section = changelog_line.startswith(f"## {addon_version} ")
            continue
        if is_inside_section:
            section_lines.append(changelog_line)
    changelog_text = "\n".join(section_lines).strip()
    if not changelog_text:
        sys.exit(f"CHANGELOG.md has no section for {addon_version}.")
    return changelog_text


def build_multipart_body(metadata, zip_path):
    boundary = uuid.uuid4().hex
    with open(zip_path, "rb") as zip_file:
        zip_bytes = zip_file.read()
    body_parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
        f"Content-Type: application/json\r\n\r\n{json.dumps(metadata)}\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(zip_path)}\"\r\n"
        f"Content-Type: application/zip\r\n\r\n".encode("utf-8"),
        zip_bytes,
        f"\r\n--{boundary}--\r\n".encode("utf-8"),
    ]
    return b"".join(body_parts), f"multipart/form-data; boundary={boundary}"


def list_versions():
    api_token = read_required_setting("CF_API_KEY")
    forever_types, forever_versions = find_forever_game_versions(api_token)
    print("Token works.")
    print("Forever version types:", [(version_type["id"], version_type.get("name")) for version_type in forever_types])
    for game_version in sorted(forever_versions, key=lambda version: version["id"]):
        print(f"  game version id {game_version['id']}: {game_version.get('name')}")
    if forever_versions:
        print("An upload would use id", choose_game_version_id(api_token))
    else:
        print("No Forever version found - set CF_GAME_VERSION_ID by hand.")


def upload(zip_path):
    api_token = read_required_setting("CF_API_KEY")
    project_id = read_required_setting("CF_PROJECT_ID")
    addon_version = read_addon_version()
    if "+dev" in addon_version:
        sys.exit(f"{addon_version} is a test build - only finished releases are uploaded.")
    metadata = {
        "displayName": f"Mentor {addon_version}",
        "changelog": read_changelog_section(addon_version),
        "changelogType": "markdown",
        "gameVersions": [choose_game_version_id(api_token)],
        "releaseType": "release",
    }
    request_body, content_type = build_multipart_body(metadata, zip_path)
    upload_answer = call_curseforge(f"/projects/{project_id}/upload-file", api_token, request_body, content_type)
    print(f"Uploaded Mentor {addon_version} to CurseForge (file id {upload_answer.get('id')}).")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list-versions":
        list_versions()
    elif len(sys.argv) >= 3 and sys.argv[1] == "upload":
        upload(sys.argv[2])
    else:
        sys.exit("Usage: curseforge_upload.py list-versions | upload <zip>")
