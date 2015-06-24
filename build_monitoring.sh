#!/bin/bash

if [ -z "$TREE" ]; then
    TREE='master'
fi
GIT_DIR='github.com/scalarm/scalarm_workers_manager'
BUILD_DIR="`pwd`/tmp/scalarm_workers_manager_build"
SRC_DIR="${BUILD_DIR}/src"

export GOPATH=$BUILD_DIR

rm -rf $BUILD_DIR
mkdir -p $SRC_DIR
pushd $SRC_DIR
    go get $GIT_DIR
    pushd $GIT_DIR
        git checkout $TREE
        ./build.sh
    popd
popd

cp -r $SRC_DIR/$GIT_DIR/packages/* public/scalarm_monitoring/
