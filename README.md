# Building RH SSO, or something similar...

## Why?

I was trying to keep my [Keycloak](https://github.com/keycloak/keycloak) instances versions in sync with [RH SSO](https://access.redhat.com/products/red-hat-single-sign-on) but couldn't find the specified releases on Keycloak Github repository.

So, inspired by [@hasalex](https://github.com/hasalex) work on get [JBoss EAP builds](https://github.com/hasalex/eap-build) from source code, I tried the same approach to RH SSO.

## How?

As RH SSO runs over JBoss EAP, you have to build it first.
### wildfly-feature-pack dependency

You have to build the artifact `wildfly-feature-pack` from JBoss EAP sources in the required version for your SSO build succeed. You can verify the correct version in the [Red Hat Single Sign-On Component Details](https://access.redhat.com/articles/2342881) page. This can be achieved by using [eap-build](https://github.com/hasalex/eap-build) scripts mentioned above. 

First, you have to run the full EAP build. After that, you can build `wildfly-feature-pack` found in `work/jboss-eap-X.X-src/feature-pack` using `mvn clean install -s ../../../src/settings.xml -DskipTests -Drelease=true -DlegacyRelease=true -Denforcer.skip`.

### RH SSO build

With the dependencies set, you can get the RH SSO build script with git or wget.
### With git

If you want to run the script :

    git clone git://github.com/luishgo/rh-sso-build.git
    cd rh-sso-build
    ./build-sso.sh

By default, it builds the latest RH-SSO 7 update. You can build other versions by passing the number to the build :

    ./build-sso.sh 7.4.5

### Without git

If you don't want to use git, download the archive, unzip it and run the main script :

    wget https://github.com/luishgo/rh-sso-build/archive/master.zip
    unzip master.zip
    cd rh-sso-master
    ./build-sso.sh

### Galleon maven plugin warning

The `build-sso.sh` uses a custom maven `settings.xml` which seems to be ignored by `galleon-maven-plugin`. Keep that in mind if you have a custom `setting.xml` on your own, particularly a `localRepository` setting.

## Versions

The build-sso.sh script supports 7.4.5->7.4.9.

## Prerequisite and systems supported

The script is in bash. It should run on almost all bash-compatible systems. You have to install **wget**, **unzip**, **patch**, **java (JDK)**, **grep**, **curl** and **xmlstarlet** first.
