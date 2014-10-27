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
if [[ -z ${REPO} ]] || \
       [[ -z ${REPO_BRANCH} ]] || \
       [[ -z ${CODEBASE_DIR} ]] || \
       [[ -z ${PIP_INSTALL} ]] || \
       [[ -z ${EXTRA_TOX_ENVS} ]]; then
  echo "A necessary variable is not set in Travis environment. Exiting."
  exit
fi

################################################
# Make wheelhouse if it doesn't already exist. #
################################################
[[ -d ${WHEELHOUSE} ]] || mkdir -p "${WHEELHOUSE}"
# NOTE: Assumes ${WHEELHOUSE} set by .travis.yml.

######################################
# `tox` will be needed by all tests. #
######################################
pip wheel --wheel-dir="${WHEELHOUSE}" tox

##################################################
# Clone the codebase we are building wheels for. #
##################################################
git clone ${REPO} ${CODEBASE_DIR}
pushd ${CODEBASE_DIR}
git checkout ${REPO_BRANCH}
popd

###########################################################
# Don't proceed if "pip install" not overridden in $REPO. #
###########################################################
if [[ ! -f ${PIP_INSTALL} ]]; then
  echo "${CODEBASE_DIR} does not contain a custom pip install script."
  # Exit with error.
  exit 1
fi

#########################################################
# Overwrite custom ${PIP_INSTALL} to just build wheels. #
#########################################################
rm -f ${PIP_INSTALL}
echo '#!/bin/bash' >> ${PIP_INSTALL}
# ${PIP_INSTALL} will be running in a tox environ, so needs a
# copy of `wheel` installed in the `virtualenv`.
echo 'pip install wheel' >> ${PIP_INSTALL}
echo 'pip wheel --wheel-dir=${WHEELHOUSE} "$@"' >> ${PIP_INSTALL}
chmod +x ${PIP_INSTALL}

#################################################
# Make wheels for library and its dependencies. #
#################################################
cd ${CODEBASE_DIR}
tox --notest
# Add dependencies for non-default `tox` environments that
# live outside of `tox.envlist`.
for EXTRA_TOX_ENV in ${EXTRA_TOX_ENVS}
do
  tox -e ${EXTRA_TOX_ENV} --notest
done

##################################
# Display the newly added files. #
##################################
ls "${WHEELHOUSE}"
