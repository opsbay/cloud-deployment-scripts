#!/bin/bash

systemctl stop learnapi

INSTALL_DIR=/opt/naviance/learnapi

if [ -d "${INSTALL_DIR}" ] ; then
  systemctl stop learnapi
  mv /etc/systemd/system/learnapi.service "${INSTALL_DIR}"
  # save old content
  saveolddir="${INSTALL_DIR}.$$.old"
  rm -fr "${saveolddir}"
  mv "${INSTALL_DIR}" "${saveolddir}"
fi
