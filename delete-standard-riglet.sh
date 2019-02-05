#!/usr/bin/env bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BRANCH=${1:-master}

# Each delete target asks a Y/N question, so we can't just do make delete-environment
# to do unattended deletions, unfortunately
function deleteEnvironment() {
  echo "Y" | make delete-db ENV=${1} && \
  echo "Y" | make delete-compute ENV=${1} && \
  echo "Y" | make delete-foundation ENV=${1} && \
  echo "Y" | make delete-app-deps ENV=${1}
}

function deleteAppsAndBuild() {
  echo "Y" | make delete-app ENV=integration REPO=${1} REPO_BRANCH=${BRANCH} && \
  echo "Y" | make delete-app ENV=staging REPO=${1} REPO_BRANCH=${BRANCH} && \
  echo "Y" | make delete-app ENV=production REPO=${1} REPO_BRANCH=${BRANCH} && \
  echo "Y" | make delete-build REPO=${1} REPO_BRANCH=${BRANCH}
}

cat .make

printf "\n${YELLOW}***${NC} For a clean deletion you must delete the images contained in the ECS repo for this riglet. ${YELLOW}***${NC}\n\n"

printf "${RED}"
echo ":::       :::     :::     :::::::::  ::::    ::: ::::::::::: ::::    :::  ::::::::  ::: ::: ";
echo ":+:       :+:   :+: :+:   :+:    :+: :+:+:   :+:     :+:     :+:+:   :+: :+:    :+: :+: :+: ";
echo "+:+       +:+  +:+   +:+  +:+    +:+ :+:+:+  +:+     +:+     :+:+:+  +:+ +:+        +:+ +:+ ";
echo "+#+  +:+  +#+ +#++:++#++: +#++:++#:  +#+ +:+ +#+     +#+     +#+ +:+ +#+ :#:        +#+ +#+ ";
echo "+#+ +#+#+ +#+ +#+     +#+ +#+    +#+ +#+  +#+#+#     +#+     +#+  +#+#+# +#+   +#+# +#+ +#+ ";
echo " #+#+# #+#+#  #+#     #+# #+#    #+# #+#   #+#+#     #+#     #+#   #+#+# #+#    #+#         ";
echo "  ###   ###   ###     ### ###    ### ###    #### ########### ###    ####  ########  ### ### ";
printf "${NC}"
echo

printf "${YELLOW}***${NC} This will ${RED}DELETE${NC} the riglet environment described above!! ${YELLOW}***${NC}\n"

echo
read -p "Are you ABSOLUTELY SURE you want to proceed?  " -n 1 -r -t 3

if [[ $REPLY =~ ^[Yy]$ ]]
then
  # deleteAppsAndBuild bookit-client-react && \
  # deleteAppsAndBuild bookit-api && \
  deleteEnvironment integration && \
  deleteEnvironment staging && \
  deleteEnvironment production && \
  echo "Y" | make delete-deps
fi
