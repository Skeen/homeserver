#!/bin/bash

ssh root@awful.engineer "cd /opt/homeserver/homeserver; git pull --rebase; ./up.sh"
