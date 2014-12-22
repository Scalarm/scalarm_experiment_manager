#!/bin/sh
REPO_URL=http://scalarm.com/repository/

for OS in linux; do
    for ARCH in amd64 386; do
        # get Go Monitoring
        MON_DIR="public/scalarm_monitoring/"
        MON_PACKAGE_PATH="${OS}_${ARCH}/scalarm_monitoring.xz"
        mkdir -p ${MON_DIR}/${OS}_${ARCH}
        curl ${REPO_URL}/scalarm_monitoring/${MON_PACKAGE_PATH} > ${MON_DIR}/${MON_PACKAGE_PATH}
    done
done

