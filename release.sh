#!/bin/bash
# release.sh old new
set -x

# old is always with -dev
old="0.1.0"
new="0.2.0-dev"
# do not set any variables beyond this line
old_version="$old-dev"
release_version="$old"
new_version="$new"
tag_name=v$release_version
set +x

git branch | grep '* master' > /dev/null
if [ 1 -eq $? ]; then
	echo "ERROR: Not on branch master"
	exit 1
fi

read -p "Check the variables. Press Ctrl-C for exit, return for continueing"

ORIG='.orig'

# update version in all mix.exs files
sed -i $ORIG "s/\(version: \"\)$old_version\",/\\1$release_version\",/" mix.exs apps/*/mix.exs

# add to git
git commit -m "bump version to $release_version" mix.exs apps/*/mix.exs

# tag the commit
git tag -a -m "new release version v$release_version" v$release_version

read -p "Check the commits. Press Ctrl-C for exit, return for continueing"

# Upload to Hex.PM (both package and docs)
# mix hex.publish
echo "No Upload to Hex.PM since they do not support Umbrella Projects!"

# update version in all mix.exs files
sed -i $ORIG "s/\(version: \"\)$release_version\",/\\1$new_version\",/" mix.exs apps/*/mix.exs

# add to git
git commit -m "bump version to $new_version" mix.exs apps/*/mix.exs

# push to github
git push origin master --tags
