#!/bin/sh
set -x

if [ -z "$*" ]
then
  COMMAND=console
else
  COMMAND=$1
  shift
fi

# run the baumeister web System
VERSION=0.2.0-dev
export PORT=4000
export NODE_NAME="baumeister@`hostname`"
export REPLACE_OS_VARS=1
export MNESIA_HOST="$NODE_NAME"
export COORDINATOR="$NODE_NAME"
# relative to the web dir
export MNESIA_DATA_DIR="priv/mnesia/prod/data"

# run the system interactively
_build/prod/rel/baumeister/bin/baumeister $COMMAND $*
