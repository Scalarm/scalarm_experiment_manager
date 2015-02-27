#!/bin/bash

TREE='development'
BUILD_DIR='tmp/sim_build/'
GIT_DIR='scalarm_simulation_manager_go'

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

pushd $BUILD_DIR
    git clone https://github.com/Scalarm/scalarm_simulation_manager_go.git
    pushd $GIT_DIR
        git checkout $TREE
        ./build.sh
    popd
popd

cp -r $BUILD_DIR/$GIT_DIR/packages/* public/scalarm_simulation_manager_go/
