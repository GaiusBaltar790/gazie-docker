#!/bin/bash

source conf

set -e

# Proxy configuration setting
if [ "$HTTP_PROXY" != "" ]; then
  export http_proxy="$HTTP_PROXY"
fi
if [ "$HTTPS_PROXY" != "" ]; then
  export https_proxy="$HTTPS_PROXY"
fi

# Control gazie directory
if [ -d "$PATH_LOCAL/gazie" ]; then
  echo "Esiste la directory $PATH_LOCAL/gazie! La elimino!";
  rm -rf $PATH_LOCAL/gazie
  sleep 5
fi

# Download versions
if [ "$GAZIE_VERSION" == "dev" ]; then 
  echo "Scarico versione GAZIE di Development: svn checkout https://svn.code.sf.net/p/gazie/code/trunk gazie"
  svn checkout --username=$USER_SOURCEFORGE svn+ssh://$USER_SOURCEFORGE@svn.code.sf.net/p/gazie/code/trunk gazie
  chmod -R 777 gazie
else
  if [ ! -d "$PATH_LOCAL/gazie" ]; then
    if [ $GAZIE_VERSION == "7.15" ]; then
      LINK_DOWNLOAD="https://downloads.sourceforge.net/project/gazie/gazie/gazie$GAZIE_VERSION.zip"
    else
      LINK_DOWNLOAD="https://sourceforge.net/projects/gazie/files/gazie/$GAZIE_VERSION/gazie$GAZIE_VERSION.zip/download"
    fi
    echo "Download Gazie $GAZIE_VERSION dal sito $LINK_DOWNLOAD"
    if [ "$http_proxy" == "" ]; then
	curl -fsSL -o gazie.zip "$LINK_DOWNLOAD"
    else
	curl -x $http_proxy -fsSL -o gazie.zip "$LINK_DOWNLOAD"
    fi
    echo "Unzip Gazie $GAZIE_VERSION"
    unzip  -q gazie.zip  
  fi
fi


# Copy configuration and modify
echo "Modify gconfig.php..."
mkdir -p $PATH_CONFIG

if [[ "$GAZIE_VERSION" < "7.16" ]]; then
  # Valid for gazie version < 7.16
  echo "Version < 7.16"
  sed 's/3306/3307/' < gazie/config/config/gconfig.php | sed 's/localhost/db/' | sed "s/\"gazie/\"$NAME_DB/" | sed "s/\$Password = \"\"/\$Password = \"$PASS_DB\"/" > $PATH_CONFIG/gconfig.myconf.php
  cp $PATH_CONFIG/gconfig.myconf.php $PATH_CONFIG/gconfig.php
else
  # Valid for gazie version >= 7.16
  echo "Version >= 7.16"
  cp -af gazie/config/config/gconfig.php $PATH_CONFIG/gconfig.php
  sed 's/3306/3307/' < gazie/config/config/gconfig.myconf.default.php | sed 's/localhost/db/' | sed "s/'gazie/'$NAME_DB/" | sed "s/Password', '/Password', '$PASS_DB/" > $PATH_CONFIG/gconfig.myconf.php
fi

# Valid for gazie version < 7.16
#sed 's/3306/3307/' < gazie/config/config/gconfig.php | sed 's/localhost/db/' | sed "s/\"gazie/\"$NAME_DB/" | sed "s/\$Password = \"\"/\$Password = \"$PASS_DB\"/" > $PATH_CONFIG/gconfig.myconf.php
#cp $PATH_CONFIG/gconfig.myconf.php $PATH_CONFIG/gconfig.php

# Config DNS
echo "Modify DNS..."
sed "s/localhost/$DNS/" < $PATH_LOCAL/nginx/nginx.conf.example > $PATH_LOCAL/nginx/nginx.conf

# Build Nginx
echo "Build Nginx..."
cd nginx
mv ../gazie/ . 
./build.sh ${GAZIE_VERSION}
mv gazie ..

# Build PHP-FPM
echo "Build PHP-FPM..."
cd ../php-fpm
mv ../gazie/ . 
./build.sh ${GAZIE_VERSION}
mv gazie ..

# Build Database in Strict-mode
cd ../mariadb
./build.sh ${GAZIE_VERSION}


# Clean
cd ..

if [ -f "$PATH_LOCAL/gazie.zip" ]; then
  echo "Deleted gazie.zip"
  rm $PATH_LOCAL/gazie.zip
fi


