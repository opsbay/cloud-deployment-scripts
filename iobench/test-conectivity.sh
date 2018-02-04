#!/bin/bash

function testNFS() {
	title=$1
	address=$2
	port=$3
	version=$4
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	NC='\033[0m' # No Color
	echo "== $title ($address:$port)"
	rpcinfo -u $address nfs $version > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\t${GREEN}IS UP AND ACCESSIBLE.${NC}"
	else
		echo -e "\t${RED}IS DOWN OR INACCESSIBLE.${NC}"
	fi
}

function testTCP() {
	title=$1
	address=$2
	port=$3
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	NC='\033[0m' # No Color
	echo "== $title ($address:$port)"
	#nc -c "echo ''" -i 20 $address $port
	curl --connect-timeout 1 http://$address:$port > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\t${GREEN}IS UP AND ACCESSIBLE.${NC}"
	else
		echo -e "\t${RED}IS DOWN OR INACCESSIBLE.${NC}"
	fi
}

env=$1

# nothing to execute ----------------------------------------------------------
if [ "$env" == "" ]; then
	echo -e "\n"
	echo "$0 [ prod | dev ]"
	echo -e "\n"
	exit 0
fi

if [ "$env" == "prod" ]; then

	echo == Testing Production environment

	echo == EDOCS API
	testTCP "iad1kpu-edocsadmin01"    10.32.102.11 8050
	#testTCP "iad1kpu-edocsconf01"     10.32.102.12 8050 # KEVIN SAID IT(tm)
	testTCP "iad1kpu-edocsdata01"     10.32.102.13 8050
	testTCP "iad1kpu-edocsinst01"     10.32.102.14 8050
	testTCP "iad1kpu-edocskeeper01"   10.32.102.15 8050
	testTCP "iad1kpu-edocsmtm01"      10.32.102.16 8050
	testTCP "iad1kpu-edocsmtm02"      10.32.102.17 8050
	testTCP "iad1kpu-edocsmtm03"      10.32.102.18 8050
	testTCP "iad1kpu-edocsmtm04"      10.32.102.25 8050
	testTCP "iad1kpu-edocsrcv01"      10.32.102.19 8050
	testTCP "iad1kpu-edocsrcv02"      10.32.102.20 8050
	testTCP "iad1kpu-edocssub01"      10.32.102.21 8050
	testTCP "iad1kpu-edocssubpar01"   10.32.102.22 8050
	testTCP "iad1kpu-edocsupload01"   10.32.102.23 8050
	testTCP "iad1kpu-edocsupload02"   10.32.102.24 8050

	echo == Services API
	testTCP "iad1kpw-navsrv01"     10.32.105.11 80
	testTCP "iad1kpw-navsrv02"     10.32.105.12 80
	testTCP "iad1kpw-navsrv03"     10.32.105.13 80
	testTCP "iad1kpw-navsrv04"     10.32.105.14 80

	echo == Legacy API
	testTCP "iad1kpw-legacyapi01"  10.32.104.21 8740
	testTCP "iad1kpw-legacyapi02"  10.32.104.22 8740

	echo == Learn API
	testTCP "iad1kpu-learnapi01"   10.32.104.11 6060
	testTCP "iad1kpu-learnapi02"   10.32.104.12 6060

	echo == Birt
	testTCP "iad1kpu-navbirt01"    10.32.108.11 8080
	testTCP "iad1kpu-navbirt02"    10.32.108.12 8080
	testTCP "iad1kpu-navbirt03"    10.32.108.13 8080

	#echo == NJQ
	#testTCP "iad1kpu-njq01"        10.32.102.31 80 # KEVIN SAID IT(tm)
	#testTCP "iad1kpu-njq02"        10.32.102.32 80 # KEVIN SAID IT(tm)
	#testTCP "iad1kpu-njq03"        10.32.102.33 80 # KEVIN SAID IT(tm)

	echo == NFS
 	testNFS "Production NFS server" 10.32.10.25 2049 3

else

	echo == Testing Development environment
	echo == TBD.
	#echo == Aurora instances
	#testTCP "#1" tf-aurora-qa-v2.cluster-c5nlhcuq5q88.us-east-1.rds.amazonaws.com 3306
	#testTCP "#2" qa-v2-0.c5nlhcuq5q88.us-east-1.rds.amazonaws.com 3306

fi
