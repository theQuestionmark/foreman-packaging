#!/bin/bash -e

NPM_MODULE_NAME=$1
VERSION=${2:-auto}
STRATEGY=$3
KOJI_TAG=foreman-nightly-el8
DISTRO=${KOJI_TAG##*-}
BASE_DIR=${4:-foreman}

REWRITE_ON_SAME_VERSION=${REWRITE_ON_SAME_VERSION:-true}

PACKAGE_MODULE=${NPM_MODULE_NAME##*/}
PACKAGE_VENDOR=${NPM_MODULE_NAME%%/*}
PACKAGE_VENDOR=${PACKAGE_VENDOR##@}
if [[ $NPM_MODULE_NAME == */* ]]; then
  PACKAGE_NAME=nodejs-${PACKAGE_VENDOR}-${PACKAGE_MODULE}
else
  PACKAGE_NAME=nodejs-${PACKAGE_MODULE}
fi
PACKAGE_DIR=packages/$BASE_DIR/$PACKAGE_NAME

ROOT=$(git rev-parse --show-toplevel)

program_exists() {
  which "$@" &> /dev/null
}

ensure_program() {
  if !(program_exists $1); then
    echo "$1 is not installed - you can install it with"
    if [[ $1 == "npm2pm" ]] ; then
      echo "sudo npm install npm2rpm"
    elif [[ $1 == "spectool" ]] ; then
      echo "sudo yum install rpmdevtools"
    else
      echo "sudo yum install $1"
    fi
    exit 1
  fi
}

generate_npm_package() {
  echo -n "Making directory..."
  if [[ $UPDATE == true ]] ; then
    sed -n '/%changelog/,$p' $PACKAGE_DIR/*.spec > OLD_CHANGELOG
    git rm -r $PACKAGE_DIR
  fi
  mkdir $PACKAGE_DIR
  echo "FINISHED"
  echo -n "Creating specs and downloading sources..."
  npm2rpm -n $NPM_MODULE_NAME -v $VERSION -s $STRATEGY -o $PACKAGE_DIR
  echo "FINISHED"
  if [[ $UPDATE == true ]]; then
    echo "Restoring changelogs..."
    cat OLD_CHANGELOG >> $PACKAGE_DIR/*.spec
    sed -i '/^%changelog/,/^%changelog/{0,//!d}' $PACKAGE_DIR/*.spec
    rm OLD_CHANGELOG
    CHANGELOG="- Update to $VERSION"
  else
    CHANGELOG="- Add $PACKAGE_NAME generated by npm2rpm using the $STRATEGY strategy"
  fi
  echo "$CHANGELOG" | $ROOT/add_changelog.sh $PACKAGE_DIR/*.spec ${VERSION}-1
  echo "FINISHED"
  echo -n "Downloading sources..."
  spectool --list-files $PACKAGE_DIR/*.spec | awk '/https?:/ { print $2 }' | xargs --no-run-if-empty wget --directory-prefix=$PACKAGE_DIR --no-verbose
  echo "FINISHED"

  if [ "$STRATEGY" = "bundle" ]; then
    echo -e "Adding npmjs cache binary... - "
    git add $PACKAGE_DIR/*-registry.npmjs.org.tgz
    echo "FINISHED"
  fi
  echo -e "Adding spec to git... - "
  git add $PACKAGE_DIR/*.spec
  echo "FINISHED"
  echo -e "Annexing sources... - "
  find "$PACKAGE_DIR" -name '*.tgz' -exec git annex add {} +
  echo "FINISHED"
}

add_npm_to_comps() {
  local comps_package="${PACKAGE_NAME}"
  local comps_file="foreman"

  ./add_to_comps.rb comps/comps-${comps_file}-${DISTRO}.xml $comps_package
  ./comps_doc.sh
  git add comps/
}

add_npm_to_manifest() {
  local package="${PACKAGE_NAME}"
  local section="foreman_nodejs_packages"

  ./add_host.py "$section" "$package"
  git add package_manifest.yaml
}

npm_info() {
  local name=$(python3 -c "import urllib.parse ; print(urllib.parse.quote('$NPM_MODULE_NAME', safe=''))")
  curl -s https://api.npms.io/v2/package/$name
}

# Main script

if [[ -z $NPM_MODULE_NAME ]]; then
  echo "This script adds a new npm package based on the module found on npmjs.org"
  echo -e "\nUsage:\n$0 NPM_MODULE_NAME [VERSION [STRATEGY]] \n"
  echo "VERSION is optional but can be an exact version number or auto to use the latest version"
  echo "STRATEGY is optional but can be bundle or single"
  exit 1
fi

ensure_program npm2rpm
ensure_program spectool

if [[ $VERSION == "auto" ]] ; then
  ensure_program curl
  ensure_program jq

  VERSION=$(npm_info | jq -r .collected.metadata.version)

  if [[ $VERSION == "null" ]] ; then
    echo "Could not determine the version for $NPM_MODULE_NAME"
    exit 1
  fi
fi

if [[ -z $STRATEGY ]] ; then
  ensure_program curl
  ensure_program jq

  DEPENDENCIES=$(npm_info | jq -r '.collected.metadata.dependencies|length')
  if [[ $DEPENDENCIES -gt 2 ]] ; then
    STRATEGY="bundle"
  else
    STRATEGY="single"
  fi
  echo "Found $DEPENDENCIES dependencies - using $STRATEGY strategy"
fi

if [ -f "$PACKAGE_DIR"/*.spec ]; then
  echo -n "Detected update..."
  UPDATE=true
else
  UPDATE=false
fi

if [[ $UPDATE == true ]] ; then
  EXISTING_VERSION=$(rpmspec --query --srpm --queryformat '%{VERSION}' $PACKAGE_DIR/*.spec)
  if [[ $REWRITE_ON_SAME_VERSION == true ]] || [[ $VERSION != $EXISTING_VERSION ]]; then
    generate_npm_package
    git commit -m "Bump $PACKAGE_NAME to $VERSION"
  else
    echo "$PACKAGE_NAME is already at version $VERSION"
  fi
else
  generate_npm_package
  echo -e "Updating comps... - "
  add_npm_to_comps
  echo "FINISHED"
  echo -e "Updating manifest... - "
  add_npm_to_manifest
  echo "FINISHED"
  git commit -m "Add $PACKAGE_NAME package"
fi
echo "Done! Now review the generated file and send a pull request"
