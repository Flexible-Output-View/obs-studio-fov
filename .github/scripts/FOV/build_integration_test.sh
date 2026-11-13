#!/bin/bash

KEY_VALUE="${FOV_INTEGRATION_TEST_KEY:-IntegrationTestKey}"

git submodule update --init --recursive

cmake --preset=ubuntu -DCMAKE_BUILD_TYPE=Release -DLINUX_PORTABLE=ON -DENABLE_RELOCATABLE=ON -DENABLE_PORTABLE_CONFIG=ON -DFOV_INTEGRATION_TEST=ON -DFOV_INTEGRATION_TEST_KEY="${KEY_VALUE}" .

cd build
cmake --build .
