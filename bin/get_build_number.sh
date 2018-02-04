#!/usr/bin/env bash
# get_build_number.sh
#
# If the Jenkins BUILD_NUMBER env var exists, we use that to build
# an S3_FILE filename variable, else we use the timestamp of the
# archive file in YYYYMMDDTHHMMSS format to build the filename.
#
# syntax:
#     get_build_number.sh <target_file>

target=${1:-}
BUILD_NUMBER=${BUILD_NUMBER:-}
if [ -n "$BUILD_NUMBER"  ]; then
    echo "$BUILD_NUMBER"
else
    # Thanks to StackOverflow for the nifty perl line.
    # https://unix.stackexchange.com/questions/255524/full-file-date-without-gnu-utilities/255529#255529
    perl -MPOSIX -le 'print strftime("%Y%m%d%H%M%S", localtime((lstat(shift))[9]))' "$target"
fi
