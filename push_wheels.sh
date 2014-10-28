#!/bin/bash

# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ev

##########################################################
# Settings relevant to project we are making wheels for. #
##########################################################
if [[ -z ${FRESH_REPO_DIR} ]]; then
  echo "The FRESH_REPO_DIR variable is not set in Travis environment. Exiting."
  exit
fi

#############################################################
# Clone a fresh copy of the repository with our auth token. #
#############################################################
git config --global user.email "travis@travis-ci.org"
git config --global user.name "travis-ci"
git clone --quiet --branch=master \
    "https://${GH_OAUTH_TOKEN}@github.com//${GH_OWNER}/${GH_PROJECT_NAME}" \
    "${FRESH_REPO_DIR}"
# NOTE: Assumes ${GH_OAUTH_TOKEN}, ${GH_OWNER} and ${GH_PROJECT_NAME} are
#       set in Travis build settings for project.
cd "${FRESH_REPO_DIR}"

###############################################
# (Optionally) make wheelhouse in fresh repo. #
###############################################
[[ -d wheelhouse ]] || mkdir -p wheelhouse

#################################################
# Check for new wheel files and remove expired. #
#################################################
# H/T: http://unix.stackexchange.com/a/9045/89278
UNUSED_WHEELS=$(comm -23 <(ls -b wheelhouse/) <(ls -b "${WHEELHOUSE}"))
NEW_WHEELS=$(comm -13 <(ls -b wheelhouse/) <(ls -b "${WHEELHOUSE}"))
# NOTE: This assumes there are no subdirectories.
# NOTE: Assumes ${WHEELHOUSE} set by .travis.yml.

#####################################
# Add new wheels to the wheelhouse. #
#####################################
# NOTE: We explicitly don't use "set -e" because we allow "git add"
#       below to fail on ignored files.
set +e
for NEW_WHEEL in ${NEW_WHEELS}
do
  cp "${WHEELHOUSE}/${NEW_WHEEL}" wheelhouse/
  git add "wheelhouse/${NEW_WHEEL}"
done
set -e

##########################################
# Remove old wheels from the wheelhouse. #
##########################################
for UNUSED_WHEEL in ${UNUSED_WHEELS}
do
  rm -f "wheelhouse/${UNUSED_WHEEL}"
  git rm "wheelhouse/${UNUSED_WHEEL}"
done

#######################################
# Display git status and push wheels. #
#######################################
git status
# H/T: http://stackoverflow.com/a/5139346/1068170
if [[ -n "$(git status --porcelain)" ]]; then
  git commit -m "Latest wheels build by travis-ci. [ci skip]"
  git status
  git push origin master
else
  echo "Nothing to commit. Exiting without pushing changes."
fi
