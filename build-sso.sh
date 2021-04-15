#!/bin/bash
set -e
source src/functions-common.sh
source src/functions.sh

check_commands wget unzip patch which javac grep curl xmlstarlet
set_version $1

make_directory -f work
make_directory download
make_directory dist

prepare_sso_source
build_sso

save_result