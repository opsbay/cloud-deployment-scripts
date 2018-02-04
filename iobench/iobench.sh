#!/usr/bin/env bash

# https://wiki.mikejung.biz/Benchmarking

# nothing to execute ----------------------------------------------------------
if [ "$1" == "" ]; then
    echo -e "\n"
    echo "$0 [ prep | mount | iozone | fio ]"
    echo -e "\n"
    exit 0
fi


MOUNTVOLUME=10.24.168.52:/vol/aws_clientfiles
MOUNTDIR=/tmp/testnfs/netapp
URL=ftp://rpmfind.net/linux/dag/redhat/el7/en/x86_64/dag/RPMS/iozone-3.424-2.el7.rf.x86_64.rpm
IOZONETMPFILE=$MOUNTDIR/iozonefile.tmp
NEWRELIC_KEY=1ab3b1b42a3b9c263cb69ffb5863a3d51f0a9936
NEWRELIC_CONF=/etc/newrelic/nrsysmond.cfg
EFSMOUNTDIR=/tmp/testnfs/efs
EFSVOLUME=fs-f9aa27b0.efs.us-east-1.amazonaws.com:/
EFSOPTS=nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2
NETAPPOPTS=rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,tcp

# PREP - software install and config ------------------------------------------------------------
if [ "$1" == "prep" ]; then

	# configure newrelic sysmond
	if sudo grep REPLACE_WITH_REAL_KEY $NEWRELIC_CONF; then
		sudo sed -i "s/REPLACE_WITH_REAL_KEY/$NEWRELIC_KEY/g" $NEWRELIC_CONF
	fi

	# install newrelic sysmond if not available
	if rpm -qa | grep -q newrelic-sysmond > /dev/null; then
		echo === newrelic-sysmond already installed
	else
		echo === installing newrelic-sysmond
		sudo yum install -y newrelic-sysmond
	fi

	# start it if its not running
	if ps auxw | grep '[/]nrsysmond' > /dev/null; then
		echo === newrelic-sysmond is running
	else
		echo === starting newrelic-sysmond
		sudo service newrelic-sysmond start
	fi

	# create nfs mount point
	if [ ! -d "$MOUNTDIR" ]; then
		echo === creating mount point $MOUNTDIR
		sudo mkdir -p $MOUNTDIR
		sudo chown -R 777 `dirname $MOUNTDIR`
	else
		echo === $MOUNTDIR mount point already exists
	fi

	# create efs mount point
	if [ ! -d "$EFSMOUNTDIR" ]; then
		echo === creating mount point $EFSMOUNTDIR
		sudo mkdir -p $EFSMOUNTDIR
		sudo chown -R 777 `dirname $EFSMOUNTDIR`
	else
		echo === $EFSMOUNTDIR mount point already exists
	fi

	# install iozone
	if rpm -qa | grep -q iozone; then
	    echo === iozone already installed
	else
	    echo === installing iozone
	    sudo yum install -y $URL
	fi

	# install fio if not already available
	if rpm -qa | grep -q fio > /dev/null; then
	    echo === fio already installed
	else
	    echo === installing fio
	    sudo yum install -y fio
	fi

fi


# MOUNT nfs and efs ------------------------------------------------------------
if [ "$1" == "mount" ]; then

	# mount nfs
	if mount | grep $MOUNTVOLUME > /dev/null; then
		echo === nfs mounted
	else
		echo === mounting nfs
		sudo mount -o $NETAPPOPTS $MOUNTVOLUME $MOUNTDIR
	fi

	# mount efs
	if mount | grep $EFSVOLUME > /dev/null; then
		echo === efs mounted
	else
		echo === mounting efs
		sudo mount -t nfs4 -o $EFSOPTS $EFSVOLUME $EFSMOUNTDIR
	fi
	sudo mkdir -p $EFSMOUNTDIR/nfstest/

fi


# IOZONE execution ------------------------------------------------------------
if [ "$1" == "iozone" ]; then
    ### nano size test, ~ 1 minute on a t2.medium
    #PROCESSES=8
    #FILESIZE=128K

    ### small size test, ~ 37 minutes on a t2.medium
    ### small size test, ~ 2 minutes against EFS
    PROCESSES=32
    FILESIZE=8M

    if [ "$2" == "" ]; then
        echo -e "\n"
        echo "$0 iozone [ nfs | efs ]"
        echo -e "\n"
        exit 0
    fi

    if [ "$2" == "nfs" ]; then
        TESTDIR=$MOUNTDIR
        IOZONETMPFILE=$MOUNTDIR/iozonefile.tmp
    else
	PROCESSES=64
	FILESIZE=64M
        TESTDIR=$EFSMOUNTDIR/nfstest
        IOZONETMPFILE=$EFSMOUNTDIR/nfstest/iozonefile.tmp
    fi
    
    echo === performance test
    time sudo iozone -acz -s $FILESIZE -f $IOZONETMPFILE

    echo === throughtput test
    cd $TESTDIR
    time sudo iozone -t $PROCESSES -s $FILESIZE -R
fi

# FIO execution ---------------------------------------------------------------
if [ "$1" == "fio" ]; then
    if [ "$2" == "" ]; then
        echo -e "\n"
        echo "$0 fio [ nfs | efs ]"
        echo -e "\n"
        exit 0
    fi

    if [ "$2" == "nfs" ]; then
        FIODIR=$MOUNTDIR
    else
        FIODIR=$EFSMOUNTDIR/nfstest
    fi
     echo === FIO execution
    # http://www.storagereview.com/fio_flexible_i_o_tester_synthetic_benchmark
    #
    # 4k
    # 100% Read or 100% Write
    # 100% 4k
    fio --filename=$FIODIR/fiotempfile --direct=1 --rw=randrw --refill_buffers --norandommap --randrepeat=0 --ioengine=libaio --bs=4k --rwmixread=100 --iodepth=16 --numjobs=16 --runtime=60 --group_reporting --name=4ktest
    # 8k 70/30
    # 70% Read, 30% Write
    # 100% 8k
    fio --filename=$FIODIR/fiotempfile --direct=1 --rw=randrw --refill_buffers --norandommap --randrepeat=0 --ioengine=libaio --bs=8k --rwmixread=70 --iodepth=16 --numjobs=16 --runtime=60 --group_reporting --name=8k7030test
    #
fi

echo === The end, my only friend, the end.
