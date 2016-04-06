#!/bin/sh
REPO_URL=http://scalarm.com/repository/

for OS in linux darwin; do
    for ARCH in amd64 386; do
        # get Go SiM
        SIM_DIR="public/scalarm_simulation_manager_go/"
        SIM_PACKAGE_PATH="${OS}_${ARCH}/scalarm_simulation_manager.xz"
        mkdir -p ${SIM_DIR}/${OS}_${ARCH}
        echo "download:  ${REPO_URL}/scalarm_simulation_manager_go/${SIM_PACKAGE_PATH}"
        curl ${REPO_URL}/scalarm_simulation_manager_go/${SIM_PACKAGE_PATH} > ${SIM_DIR}/${SIM_PACKAGE_PATH}
    done
done

