#!/bin/bash
set -e

src=${1}
dest=${2}
tarball=$(basename ${src})

if [ ! -f ${NGINX_SETUP_DIR}/sources/${tarball} ]; then
  echo "Downloading ${tarball}..."
  mkdir -p ${NGINX_SETUP_DIR}/sources/
  wget ${src} -O ${NGINX_SETUP_DIR}/sources/${tarball}
fi

echo "Extracting ${tarball}..."
mkdir ${dest}
tar -zxf ${NGINX_SETUP_DIR}/sources/${tarball} --no-same-owner --strip=1 -C ${dest}
rm -rf ${NGINX_SETUP_DIR}/sources/${tarball}