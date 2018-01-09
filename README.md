![status: inactive](https://img.shields.io/badge/status-inactive-red.svg)

This project is no longer actively developed or maintained.

gcloud-python-wheels
====================

Generation and storage of Python [wheels][1] for building
[`gcloud-python`][2] on [Travis][3]. This allows use of `tox`
environments without excessively slow builds.

Inspired by the proof-of-concept [`pelson/travis-wheels`][4].

## How does it work? TLDR

This repository builds all the dependencies for a given project
as Python wheels by running

```
tox --notest
```

to determine the dependencies and then builds them into a
specific directory:

```
pip wheel --wheel-dir=${WHEELHOUSE}
```

In order to avoid adding a wheel for the main project, `.gitignore`
contains `*gcloud*`.

## Using Pre-built Wheels

After building a `wheelhouse` of dependencies for a project's build,
the wheels can be reused to drastically (YMMV) speed up build time.

This can be done in two main parts:

1. Specify a custom install command in your project's `tox` config:

   ```
   ...
   [testenv]
   install_command =
       {toxinidir}/scripts/custom_pip_install.sh {opts} {packages}
   ...
   ```

2. Instead of the default `pip install`, install from the wheelhouse
   with no connection and then (optionally) try to update if your pre-built
   wheels are out-of-date:

   ```
   #!/bin/bash
   if [[ -d ${WHEELHOUSE} ]]; then
       pip install --no-index --find-links=${WHEELHOUSE} "$@"
   fi
   # Update if the locally cached wheels are out-of-date.
   pip install --upgrade "$@"
   ```

This presumes your project build clones the wheelhouse
as a `before_install` step in Travis and refers to the pre-built wheels
as `${WHEELHOUSE}`.

## When will a new build occur

A new build occurs on any commit to `master` that is not a pull request.

A possible strategy for forcing new builds would be to add a small file
from a build of a dependent project (here that is `gcloud-python`).
After doing that, push a new commit to this project from the dependent
project's build and it will kick off a new Travis build. If no
dependencies have changed, no wheelhouse commit will be added.

For example a file `LATEST_COMMIT` containing the most recent commit in
the dependent project could be added by the dependent project.

## How does it work? More Details

The main project (i.e. not the wheelhouse) is determined by the values

- `REPO="https://github.com/GoogleCloudPlatform/gcloud-python"`
- `REPO_BRANCH="master"`

set as Travis environment variables (see [below](#installation-and-set-up)).

After a new commit is pushed, the Travis build will check out the
repository (`${REPO}`) we are building for and then replace the
`scripts/custom_pip_install.sh` file in that repository.

This assumes that `${REPO}` defines a custom `pip install` command
and registers it with `tox` as discussed above.

> **NOTE**: The project relative path to that command is set via:
>
> ```
> CODEBASE_DIR="gcloud-python"
> PIP_INSTALL="${CODEBASE_DIR}/scripts/custom_pip_install.sh"
> ```
>
> as Travis environment variables (see [below](#installation-and-set-up)).

The custom `pip install` script is replaced with

```
#!/bin/bash
pip install wheel
pip wheel --wheel-dir=${WHEELHOUSE}
```

which simply creates the wheels without installing them into
the current `tox` virtual environment.

In addition, the variable

```
EXTRA_TOX_ENVS="coveralls regression"
```

allows building for extra `tox` environments not defined in the
default `envlist`.

After building the dependencies in the Travis environment, the script
`push_wheels.sh` checks with new files / versions have been created,
then removes obsolete wheels, adds any new ones and then creates
and pushes a new commit to this repository.

## Installation and Set-up

In order to use `gcloud-python-wheels`, you'll need to set Travis
environment variables to allow building for the right project
and providing authentication to allow Travis to make commits
to your wheelhouse project.

To do this:

1. [Install][6] the `travis` command-line tool.

1. Visit your GitHub [Applications settings][5] to generate an OAuth token
   to use with the `travis` CLI tool. Be sure to select `public_repo`
   and `user:email` (or `user`) for the token scopes.

1. Copy the token and save it in a read-only file called `travis.token`.
   Put this in the root of your `git` repository fork of
   `gcloud-python-wheels`.

1. Log in to Travis via the CLI tool:

   ```
   travis login --github-token=`cat travis.token`
   ```

1. Define and export the following environment variables:

   ```
   # Variables used to push new commits to the wheelhouse.
   export GH_OWNER="GoogleCloudPlatform"
   export GH_PROJECT_NAME="gcloud-python-wheels"
   # Variables used to build wheels for ${REPO}.
   export REPO="https://github.com/GoogleCloudPlatform/gcloud-python"
   export REPO_BRANCH="master"
   export CODEBASE_DIR="gcloud-python"
   export PIP_INSTALL="${CODEBASE_DIR}/scripts/custom_pip_install.sh"
   export EXTRA_TOX_ENVS="coveralls regression"
   # Variables used to git commit and push new wheels.
   export FRESH_REPO_DIR="gcloud-python-wheels"
   ```

   Notice that these variables are closely tied to this repository. If
   you'd like to use a similar wheel build process, you'll need to
   tailor these values to your main project repository (`${REPO}`) and
   your wheelhouse repository (`${GH_PROJECT_NAME}`).

1. Set the Travis environment variables:

   ```
   # Variables used to push new commits to the wheelhouse.
   travis env set GH_OWNER "${GH_OWNER}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   travis env set GH_PROJECT_NAME "${GH_PROJECT_NAME}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   travis env set GH_OAUTH_TOKEN `cat travis.token` --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   # Variables used to build wheels for ${REPO}.
   travis env set REPO "${REPO}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   travis env set REPO_BRANCH "${REPO_BRANCH}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   travis env set CODEBASE_DIR "${CODEBASE_DIR}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   travis env set PIP_INSTALL "${PIP_INSTALL}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   # Make EXTRA_TOX_ENVS public since it may change.
   travis env set --public EXTRA_TOX_ENVS "${EXTRA_TOX_ENVS}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   # Variables used to git commit and push new wheels.
   travis env set FRESH_REPO_DIR "${FRESH_REPO_DIR}" --repo "${GH_OWNER}/${GH_PROJECT_NAME}"
   ```

1. Log out of Travis:

   ```
   travis logout
   ```

[1]: http://pythonwheels.com/
[2]: https://github.com/GoogleCloudPlatform/gcloud-python
[3]: https://travis-ci.org
[4]: https://github.com/pelson/travis-wheels
[5]: https://github.com/settings/tokens/new
[6]: https://github.com/travis-ci/travis.rb#installation
