#!/bin/bash
set -e

read -p "Clean build ? [y/N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
rm -rf build
fi


cmake --preset macos -DCMAKE_BUILD_TYPE=Debug -DENABLE_WEBRTC=On -DENABLE_RELOCATABLE=ON -DENABLE_PORTABLE_CONFIG=ON

cd build_macos

cmake --build . --config Debug

read -p "Run OBS now ? [y/N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
./rundir/Debug/bin/obs --portable
else
exit 0
fi
