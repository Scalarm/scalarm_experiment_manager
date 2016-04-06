#!/bin/bash

SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )
curl http://plgrid-sca.wcss.wroc.pl/crl.pem > ${SCRIPT_PATH}/../config/plgrid_crl.pem