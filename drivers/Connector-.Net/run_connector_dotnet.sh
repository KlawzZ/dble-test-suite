#!/bin/bash
set -e
# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.

echo '=======                 restore the running environment              ======='
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd ${DIR}/../../behave_dble/compose/docker-build-behave && bash resetReplication.sh

echo '=======           restart dble with sql_cover_sharding               ======='
cd ${DIR}/../../behave_dble && pipenv run behave --stop -D dble_conf=sql_cover_sharding features/setup.feature

echo '=======                       compile                                ======='
cd ${DIR}/netdriver && csc -out:test.exe -r:MySql.Data.dll -r:YamlDotNet.dll *.cs

echo '=======                        driver test                           ======='
cd ${DIR} && bash do_run_connector_dotnet.sh -c