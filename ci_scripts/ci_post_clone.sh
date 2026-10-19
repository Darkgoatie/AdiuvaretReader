#!/bin/sh
# Xcode Cloud runs this after cloning. The Xcode project is generated from project.yml; all packages are local, so nothing else is resolved.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"
brew install xcodegen

# Xcode Cloud numbers builds from 1; App Store Connect already holds builds up to 3 for this version.
BUILD=$((CI_BUILD_NUMBER + ${BUILD_NUMBER_OFFSET:-100}))
export BUILD
perl -pi -e 's/CURRENT_PROJECT_VERSION: "\d+"/CURRENT_PROJECT_VERSION: "$ENV{BUILD}"/' project.yml
xcodegen generate
echo "Build number $BUILD"
