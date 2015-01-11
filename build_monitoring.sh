#!/bin/bash

TREE='master'
GIT_DIR='scalarm_monitoring'
BUILD_DIR="tmp/${GIT_DIR}_build/"


rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

pushd $BUILD_DIR
    mkdir src
    pushd src
        git clone https://github.com/mpaciore/scalarm_monitoring.git
        pushd $GIT_DIR
            git checkout $TREE
        popd
    popd
    
    export GOPATH=`pwd`
    PACKAGES_DIR=packages/

    rm -rf $PACKAGES_DIR/*

    for OS in linux; do
        for ARCH in amd64 386; do
            BIN_PATH="$PACKAGES_DIR/${OS}_${ARCH}/$GIT_DIR"
            echo "Building: $OS $ARCH in ${BIN_PATH}..."
            GOOS=$OS GOARCH=$ARCH CGO_ENABLED=0 go build -o $PACKAGES_DIR/${OS}_${ARCH}/${GIT_DIR} ${GIT_DIR}
            strip $BIN_PATH
            xz $BIN_PATH
        done
    done


popd

cp -r $BUILD_DIR/packages/* public/$GIT_DIR/
