#!/bin/bash

TREE='master'

rm -rf tmp/monitoring_build
mkdir -p tmp/monitoring_build

pushd tmp/monitoring_build
    mkdir src
    pushd src
        git clone https://github.com/mpaciore/scalarm_monitoring.git
        pushd scalarm_monitoring
            git checkout $TREE
        popd
    popd
    GOPATH=`pwd` go install scalarm_monitoring
    pushd bin
        mv scalarm_monitoring scalarm_monitoring_linux_x86_64
        strip scalarm_monitoring_linux_x86_64
        xz scalarm_monitoring_linux_x86_64
    popd
popd

cp tmp/monitoring_build/bin/scalarm_monitoring_linux_x86_64.xz public/scalarm_monitoring/
