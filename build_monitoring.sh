#!/bin/bash

if [ -z "$TREE" ]; then
    TREE='master'
fi
GIT_DIR='scalarm_workers_manager'
BUILD_DIR="tmp/${GIT_DIR}_build"

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

pushd $BUILD_DIR
    git clone https://github.com/Scalarm/scalarm_workers_manager.git
    pushd $GIT_DIR
        git checkout $TREE
        ./build.sh
    popd
popd

cp -r $BUILD_DIR/$GIT_DIR/packages/* public/scalarm_monitoring/
