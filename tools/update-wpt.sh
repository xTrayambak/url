#!/usr/bin/env sh

WPT_REPO="https://github.com/web-platform-tests/wpt" #/tree/master/url/resources
WD=$(pwd)
BRANCH="master"

git clone --no-checkout --depth=1 $WPT_REPO tests/wpt
cd tests/wpt && 
	git sparse-checkout init --cone &&
	git sparse-checkout set url/resources &&
	git checkout $BRANCH

rm -rf $WPT_REPO/.git # To prevent any accidents
cd $WD
