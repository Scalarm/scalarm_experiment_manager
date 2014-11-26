#!/bin/bash

TREE='master'
BUILD_DIR='$BUILD_DIR/'


rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

pushd $BUILD_DIR
    mkdir src
    pushd src
        git clone https://github.com/Scalarm/scalarm_simulation_manager_go.git
        pushd scalarm_monitoring
            git checkout $TREE
        popd
    popd
    ./build.sh
popd

cp -r $BUILD_DIR/pkg/* public/scalarm_simulation_manager_go/
