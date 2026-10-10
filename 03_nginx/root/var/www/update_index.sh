#!/bin/bash -xe

ROOT=$(dirname $0)

# This machine's name: "Machine name" in ~/AGENTS.md (copy it identically)
m=${JR_MACHINE_NAME:-$(if [ "$(uname)" = Darwin ]; then scutil --get HostName; else cat /etc/hostname; fi 2>/dev/null)} || :
m=${m%%.*}; [[ $m =~ ^[A-Za-z0-9-]+$ ]] || m='?'
title=$m
full_title=$(hostname -f)
if [ -d $ROOT/html/html_links ]; then
	links=$(cat $ROOT/html/html_links/*.html)
fi

if [ -z "$links" ]; then
	echo 'It seems that there is no application installed on the server yet...'
fi


eval "cat <<EOF
$( < $ROOT/template.html.sh)
EOF
" 2> /dev/null > $ROOT/html/index.html
