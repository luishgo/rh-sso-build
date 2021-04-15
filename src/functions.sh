#!/bin/bash

function set_version {
    if [ "x$1" == "x" ] 
    then
        SSO_VERSION=$(get_default_version)
    else
        SSO_VERSION=$1
        is_supported_version $SSO_VERSION
    fi

    if [ -f dist/rh-sso-$SSO_VERSION.tar.gz ]
    then
        echo "SSO version $SSO_VERSION already built. If you wanna build it again, remove the dist/rh-sso-$SSO_VERSION.tar.gz file" 
        exit 0
    fi
    SSO_SHORT_VERSION=${SSO_VERSION%.*}
    SRC_FILE=rh-sso-${SSO_VERSION}-src.zip
    BUILD_HOME=$(pwd)
    #echo BUILD_HOME=$BUILD_HOME

    echo "Here we go. Building SSO version $SSO_VERSION."
}

function prepare_sso_source {
    download_and_unzip http://ftp.redhat.com/redhat/jboss/sso/$SSO_VERSION/en/source/$SRC_FILE

    KEYCLOAK_PARENT_VERSION=$(basename work/rh-sso-$SSO_SHORT_VERSION-src/keycloak-parent-*)
    KEYCLOAK_PARENT_VERSION=${KEYCLOAK_PARENT_VERSION:16}
    echo "ATTENTION: Be sure to build artifact wildfly-feature-pack from EAP version $(get_eap_version) before SSO. Check README.md for more information."

    cd $BUILD_HOME/work/rh-sso-$SSO_SHORT_VERSION-src/keycloak-parent*
    xml_clean sso
    MVN=mvn
    cd $BUILD_HOME
}

function build_sso {
    cd $BUILD_HOME/work/rh-sso-$SSO_SHORT_VERSION-src/keycloak-parent*
    maven_build
    echo "Build done for SSO $SSO_VERSION"
}

function maven_build {
    if [ -n "$1" ]
    then
        msg="Maven build for $1"
        cd $1
    else
        msg="Maven build from root"
    fi

    # mvn_command="$MVN clean install -s ../../../src/settings.xml -DskipTests -Drelease=true -DlegacyRelease=true -Denforcer.skip -Pdistribution"
    mvn_command="$MVN clean install -s ../../../src/settings.xml -DskipTestsuite -DskipTests -Pdistribution,product -Dmaven.test.skip=true"
    if [ "$MVN_OUTPUT" = "3" ]
    then
        echo "=== $msg (with output level $MVN_OUTPUT) ===" | tee -a $BUILD_HOME/work/build.log
        $mvn_command | tee -a $BUILD_HOME/work/build.log || error "Error in $msg"
	    echo "...done with $msg" | tee -a $BUILD_HOME/work/build.log
    elif [ "$MVN_OUTPUT" = "2" ]
    then
        echo "=== $msg (with output level $MVN_OUTPUT) ===" | tee -a $BUILD_HOME/work/build.log
        $mvn_command | tee -a $BUILD_HOME/work/build.log | grep --invert-match --extended-regexp "Downloading:|Downloaded:" || error "Error in $msg"
	    echo "...done with $msg" | tee -a $BUILD_HOME/work/build.log
    elif [ "$MVN_OUTPUT" = "1" ]
    then
        echo "=== $msg (with output level $MVN_OUTPUT) ===" | tee -a $BUILD_HOME/work/build.log
        $mvn_command | tee -a $BUILD_HOME/work/build.log | grep --extended-regexp "Building JBoss|Building WildFly|ERROR|BUILD SUCCESS" || error "Error in $msg"
	    echo "...done with $msg" | tee -a $BUILD_HOME/work/build.log
    else
        echo "=== $msg ===" >> $BUILD_HOME/work/build.log
        $mvn_command >> $BUILD_HOME/work/build.log 2>&1 || error "Error in $msg"
	    echo "...done with $msg" >> $BUILD_HOME/work/build.log
    fi

    if [ -n "$1" ]
    then
        cd ..
    fi
}

function get_eap_version {
    grep "<eap.version>" $BUILD_HOME/work/rh-sso-$SSO_SHORT_VERSION-src/keycloak-parent-$KEYCLOAK_PARENT_VERSION/pom.xml | sed -e "s/<eap.version>\(.*\)<\/eap.version>/\1/" | sed 's/ //g'
}

function is_supported_version {
    set +e
    supported_versions=$(get_supported_versions)
    supported_version=$(echo "$supported_versions," | grep -G "$1,")
    if [ -z $supported_version ]
    then
        echo "Version $1 is not supported. Supported versions are $supported_versions"
        exit 1
    fi
    set -e
}
function get_supported_versions {
    grep 'versions' src/rh-sso-7.properties | sed -e "s/versions=//g"
}
function get_default_version {
    echo $(get_supported_versions) | sed s/,/\\n/g | sort | tac | sed -n '1p'
}

function xml_clean {
    scope=$1

    xml_to_delete=$(grep "$SSO_VERSION.xpath.delete.$scope" $BUILD_HOME/src/rh-sso-7.properties | sed -e "s/$SSO_VERSION.xpath.delete.$scope=//g" | tr '\n' ' ')
    #echo xml_to_delete : $xml_to_delete
    IFS=' ' read -ra xml_to_delete_array <<< $xml_to_delete
    for line in "${xml_to_delete_array[@]}"; do
        xml_delete $(echo $line| sed -e "s/,/ /g")
    done

    xml_to_insert=$(grep "$SSO_VERSION.xpath.insert.$scope" $BUILD_HOME/src/rh-sso-7.properties | sed -e "s/$SSO_VERSION.xpath.insert.$scope=//g" | tr '\n' ' ')
    #echo xml_to_insert : $xml_to_insert
    IFS=' ' read -ra xml_to_insert_array <<< $xml_to_insert
    for line in "${xml_to_insert_array[@]}"; do
        xml_insert $(echo $line| sed -e "s/,/ /g")
    done

    xml_to_replace=$(grep "$SSO_VERSION.xpath.replace.$scope" $BUILD_HOME/src/rh-sso-7.properties | sed -e "s/$SSO_VERSION.xpath.replace.$scope=//g" | tr '\n' ' ')
    #echo xml_to_replace : $xml_to_replace
    IFS=' ' read -ra xml_to_replace_array <<< $xml_to_replace
    for line in "${xml_to_replace_array[@]}"; do
        xml_replace $(echo $line| sed -e "s/,/ /g")
    done
}
function xml_delete {
    #echo xml_delete $*
    file=$1
    xpath=$2

    cp $file .tmp.xml
    xmlstarlet ed --delete $xpath .tmp.xml > $file
    rm .tmp.xml
}
function xml_insert {
    #echo xml_insert $*
    file=$1
    xpath=$2
    value="$3 $4"

    cp $file .tmp.xml
    xmlstarlet ed --insert "$xpath" --type elem --name "$value" .tmp.xml > $file
    rm .tmp.xml
}
function xml_replace {
    #echo xml_replace $*
    file=$1
    xpath=$2
    value="$3 $4"

    cp $file .tmp.xml
    xmlstarlet ed --update "$xpath" --value "$value" .tmp.xml > $file
    rm .tmp.xml
}
function error {
    echo >&2 $1
    echo >&2 ""
    echo >&2 "Build failed. You may have a look at the work/build.log file, maybe you'll find the reason why it failed."
    exit 1
}
