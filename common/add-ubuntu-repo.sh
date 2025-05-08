#!/bin/bash
readonly repo="$1"

if ! which add-apt-repository; then
    echo "Installing add-apt-repository"
    apt-get install -y software-properties-common
fi

# !!!! syntax of add-apt-repository changes depending upon version...
add-apt-repository "${repo}"
