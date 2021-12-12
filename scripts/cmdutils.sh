#!/bin/bash

# Some nice command functions which prettify the outputs
function nice_wget {
    # Numper of args is $#
    if [ $# -eq 2 ]
    then
        # URL is $1
        # Output file is $2
        wget -q --show-progress -np -N $1 -O $2
    else
        echo "nice_get invalid arguments, got: $*"
        exit 1
    fi
}