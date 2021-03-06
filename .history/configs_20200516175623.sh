#!/bin/bash

#1) Customize values
#2) Do not delete this file (for reference in fresh set ups)

# Explanations: These configurations affect both install scripts, the server-install.sh and install.sh.
#               For example Samba will not be installed in PROD or WEB_DOMAIN_NAME and URL_ENDING define
#               the url to add to your host file.

IS_PROD_ENV=false
BRANCH_DEV=develop
BRANCH_PROD=master

SAMBA_SHARE_DIRECTORY=documents

EMAIL_ADDRESS=your@email.com
WEB_DOMAIN_NAME=youdomainname
URL_ENDING=.com

DB_NAME=mydb
DB_USER_NAME=postgres
DB_PORT=5432
DB_USER_PASSWORD=

#Example: git@github.com:github_username/git_repo_title.git
GITHUB_CLONE_SSH_URL=
