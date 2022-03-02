#!/bin/bash

PAPER_VERSION=1.18.1

[ "$USER" == minecraft ] || {
  sudo -u minecraft "$0"
  exit
}
cd "$(dirname "$0")" || exit

LATEST_BUILD=$(curl -s -X GET https://papermc.io/api/v2/projects/paper/versions/"$PAPER_VERSION" |
  python3 -c "import sys, json; print(json.load(sys.stdin)['builds'][-1])")
FILE_NAME=$(curl -s -X GET https://papermc.io/api/v2/projects/paper/versions/"$PAPER_VERSION"/builds/"$LATEST_BUILD" |
  python3 -c "import sys, json; print(json.load(sys.stdin)['downloads']['application']['name'])")
curl -o server.jar https://papermc.io/api/v2/projects/paper/versions/"$PAPER_VERSION"/builds/"$LATEST_BUILD"/downloads/"$FILE_NAME"
