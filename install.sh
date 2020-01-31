#!/bin/bash
. ./configs.sh
INSTALL_DIR=$HOME/$SAMBA_SHARE_DIRECTORY
UNINSTALL=false
PURGE=false
CLEAN_REPO=false
IMAGES=false
SKIP_POST_INSTALLATION_STEPS=false
INSTALL_DEV_CWD=$(pwd)
HELP_TEXT="This script will install the DB container, create a database with a user, create an image and a container for the web server, download the git repo - making sure it contains the latest commit, run composer, npm install and dev compilation and php artisan command for DB migration. By default every run of this script (install or uninstall deletes dangling images and stopped containers)\n
-h Help text\n
-U UNINSTALL: this will delete the 'configured' Volume, DB, Server, Network and the git REPO and then exit. Can be used with -p, -c and -i flags.\n
-p purge: Deletes all running containers (not just the configured ones), all existing volumes and all networks. This is a goood flag to use often if you are constantly renaming your webserver in the 'configs' file etc and have some previous containers to remove you forgot to uninstall with -U. But this will affect all docker containers and all webservers on the system.\n
-i images: Delete all docker images as well\n
-c clean repo: This can only be used together with -U\n
-s SKIP_POST_INSTALLATION_STEPS - e.g ./install -s will only update docker image but skip the composer and npm install (useful if you are working on docker file and dont want to wait for these irrelevant install steps)";

while getopts h-:U-:p-:i-:c-:s-: option
do
    case "${option}"
    in
        h) echo -e $HELP_TEXT; exit;;
        U) UNINSTALL=true;;
        p) PURGE=true;;
        i) IMAGES=true;;
        c) CLEAN_REPO=true;;
        s) SKIP_POST_INSTALLATION_STEPS=true;;
    esac
done

if  [[ ${#EMAIL_ADDRESS} -eq 0 ]] || \
    [[ ${#WEB_DOMAIN_NAME} -eq 0 ]] || \
    [[ ${#URL_ENDING} -eq 0 ]] || \
    [[ ${#GIT_REPO_TITLE} -eq 0 ]] || \
    [[ ${#DB_NAME} -eq 0 ]] || \
    [[ ${#DB_USER_NAME} -eq 0 ]] || \
    [[ ${#DB_PORT} -eq 0 ]] || \
    [[ ${#DB_USER_PASSWORD} -eq 0 ]];
then
    echo "Please supply information for all parameters in 'config.sh':"
    echo -e "EMAIL_ADDRESS\nWEB_DOMAIN_NAME\nURL_ENDING\nGIT_REPO_TITLE\nDB_NAME\nDB_USER_NAME\nDB_PORT\nDB_USER_PASSWORD";
    exit
fi

NETWORK_TITLE="${WEB_DOMAIN_NAME}Network"
NetworkExists(){
    if [ -z $(docker network ls -f name="$NETWORK_TITLE" -q) ];
    then return 1;
    else return 0;
    fi
}
NetworkCreate_(){
    echo "Creating network: '$NETWORK_TITLE'";
    docker network create $NETWORK_TITLE
}
NetworkDelete_(){
    echo "Deleting network: '$NETWORK_TITLE'";
    docker network rm $(docker network ls -f name="$NETWORK_TITLE" -q)
}
NetworkUp(){
    if ! NetworkExists; then
        echo "Network does not exist"
        NetworkCreate_;
    fi;
}
NetworkDown(){
    if NetworkExists; then
        NetworkDelete_;
    fi;
}

VOLUME_TITLE="${WEB_DOMAIN_NAME}Volume"
VolumeExists(){
    if [ -z $(docker volume ls -f name="$VOLUME_TITLE" -q) ];
    then return 1;
    else return 0;
    fi
}
VolumeCreate_(){
    echo "Creating volume: '$VOLUME_TITLE'";
    docker volume create $VOLUME_TITLE
}
VolumeDelete_(){
    echo "Deleting volume: '$VOLUME_TITLE'";
    docker volume rm $(docker volume ls -f name="$VOLUME_TITLE" -q)
}
VolumeUp(){
    if ! VolumeExists; then
        VolumeCreate_;
    fi;
}
VolumeDown(){
    if VolumeExists; then
        VolumeDelete_;
    fi;
}

DB_CONTAINER_NAME="${DB_NAME}Host"
DBHostExists(){
    if [ -z $(docker ps -f name="$DB_CONTAINER_NAME" -q) ];
    then return 1;
    else return 0;
    fi
}
DBHostCreate_(){
    echo "Creating '$DB_CONTAINER_NAME' postgres server with '$DB_NAME' database"
    docker run \
    --rm \
    -d \
    --name $DB_CONTAINER_NAME \
    -v $VOLUME_TITLE:/var/lib/postgresql/data \
    -p $DB_PORT:$DB_PORT \
    -e POSTGRES_USER=$DB_USER_NAME \
    -e POSTGRES_PASSWORD=$DB_USER_PASSWORD \
    -e POSTGRES_DB=$DB_NAME \
    --network=$NETWORK_TITLE \
    postgres
}
DBHostDelete_(){
    echo "Deleting '$DB_CONTAINER_NAME' postgres host container."
    docker rm -f $(docker ps -f name="$DB_CONTAINER_NAME" -q)
}
DBHostUp(){
    if ! DBHostExists; then
        DBHostCreate_;
    fi
}
DBHostDown(){
    if DBHostExists; then
        DBHostDelete_;
    fi
}

#GENERAL CLEAN UP METHODS
#images (all, dangling)
DockerDeleteImagesAll_(){
    if [[ -n $(docker images -q -a) ]]; then
        echo "REMOVING ALL IMAGES:"
        docker rmi -f $(docker images -q -a);
    fi;
}
DockerDeleteImagesDangling_(){
    if [[ -n $(docker images -f "dangling=true" -q) ]]; then
        echo "REMOVING DANGLING IMAGES:"
        docker rmi -f $(docker images -f "dangling=true" -q);
    fi;
}
#containers (all, exited, configured)
DockerDeleteContainersAll_(){
    if [[ -n $(docker ps -a -q) ]]; then
        echo "REMOVING ALL CONTAINERS:";
        docker rm -f $(docker ps -a -q);
    fi;
}
DockerDeleteContainersExited_(){
    if [[ -n $(docker ps -f "status=exited" -q) ]]; then
        echo "REMOVING EXITED CONTAINER(S)):";
        docker rm $(docker ps -f "status=exited" -q);
    fi;
}
DockerDeleteContainersConfigured_(){
    if [[ -n $(docker ps -f "name=$DB_CONTAINER_NAME" -q) ]]; then
        echo "REMOVING CONFIGURED CONTAINER ($DB_CONTAINER_NAME):"
        docker rm -f $(docker ps -f "name=$DB_CONTAINER_NAME" -q);
    fi;
    if [[ -n $(docker ps -f "name=$WEBSERVER_HOSTNAME" -q) ]]; then
        echo "REMOVING CONFIGURED CONTAINER ($WEBSERVER_HOSTNAME):"
        docker rm -f $(docker ps -f "name=$WEBSERVER_HOSTNAME" -q);
    fi;
}
#volumes (all, configured)
DockerDeleteVolumesAll_(){
    if [[ -n $(docker volume ls -q) ]]; then
        echo "REMOVING ALL VOLUMES:"
        docker volume rm $(docker volume ls -q);
    fi;
}
DockerDeleteVolumeConfigured_(){
    if [[ -n $(docker volume ls -f "name=$VOLUME_TITLE" -q) ]]; then
        echo "REMOVING CONFIGURED VOLUME:"
        docker volume rm $(docker volume ls -f "name=$VOLUME_TITLE" -q);
    fi;
}
#networks (all, configured)
DockerDeleteNetworksAll_(){
    docker network prune -f
}
DockerDeleteNetworkConfigured_(){
    if [[ -n $(docker network ls -f "name=$NETWORK_TITLE" -q) ]]; then
        echo "REMOVING CONFIGURED NETWORK:"
        docker network rm $(docker network ls -f "name=$NETWORK_TITLE" -q);
    fi;
}

#prune -p
DockerAllDown(){
    DockerDeleteContainersAll_;
    DockerDeleteVolumesAll_;
    DockerDeleteNetworksAll_;
}
#images -i
DockerImagesDown(){
    DockerDeleteImagesAll_;
}

#Generating the REPO_DIR, cloning
REPO_DIR="$INSTALL_DIR/$GIT_REPO_TITLE"
GitCloneRepo(){
    cd $INSTALL_DIR
    if ! (sudo -u $USER git clone -b develop git@github.com:katzda/$GIT_REPO_TITLE.git); then
        if ! GitRepoExists ; then
            sudo rm -rf $REPO_DIR/*;
        fi
        return 1;
    else
        return 0;
    fi;
}
IsUpToDate(){
    if [[ -n $(git status | grep "Your branch is up to date") ]]; then return 0; else return 1; fi;
}
GitPull(){
    CWD=$(pwd)
    cd $INSTALL_DIR/$GIT_REPO_TITLE
    sudo -u $USER git fetch
    if ! IsUpToDate; then
        git reset --hard "origin/$(git status | sed -E 's/On branch (.*)/\1/;q')";
    fi;
    cd $CWD;
}
GitRepoExists(){
    if [[ -d $REPO_DIR ]] && [[ -d $REPO_DIR/.git ]]; then return 0; else return 1; fi
}
GitRepoDelete_(){
    sudo rm -rf $REPO_DIR;
}
GitRepoDown(){
    if GitRepoExists; then
        echo "Removing the whole $REPO_DIR directory."
        GitRepoDelete_;
    fi;
}
GitRepoUp(){
    if GitRepoExists; then
        if [[ $IS_PROD_ENV = true ]]; then
            if GitPull; then return 0; else return 1; fi;
        fi;
        return 0;
    else
        if GitCloneRepo ; then return 0; else return 1; fi;
    fi;
}

WEBSERVER_HOSTNAME="${WEB_DOMAIN_NAME}Host";
DBWebServerExists(){
    if [ -z $(docker ps -f name="$WEBSERVER_HOSTNAME" -q) ]; then return 1; else return 0; fi;
}
Debug(){
    echo "REPO_DIR=$REPO_DIR";
    echo "GIT_REPO_TITLE=$GIT_REPO_TITLE";
    echo "PATH_TO_PUBLIC=$PATH_TO_PUBLIC";
    echo "PATH_TO_PUBLIC_ESCAPED=$PATH_TO_PUBLIC_ESCAPED";
    echo "PATH_TO_PUBLIC_ESCAPED_TWICE=$PATH_TO_PUBLIC_ESCAPED_TWICE";
    echo "DB_CONTAINER_NAME=$DB_CONTAINER_NAME";
    echo "EMAIL_ADDRESS=$EMAIL_ADDRESS";
    echo "WEB_DOMAIN_NAME=$WEB_DOMAIN_NAME";
    echo "URL_ENDING=$URL_ENDING";
    echo "GIT_REPO_TITLE=$GIT_REPO_TITLE";
    echo "DB_PORT=$DB_PORT";
    echo "DB_NAME=$DB_NAME";
    echo "DB_USER_NAME=$DB_USER_NAME";
    echo "DB_USER_PASSWORD=$DB_USER_PASSWORD";
    echo "IP_ADDRESS=$IP_ADDRESS";
    echo "NETWORK_TITLE=$NETWORK_TITLE";
    exit;
}
DBWebServerCreate_(){
    cd $INSTALL_DEV_CWD;
    PATH_TO_PUBLIC=$(find $REPO_DIR -name index.php | sed -E "s/(.*?)\/$GIT_REPO_TITLE(\/.*)\/public\/index\.php/\2/;s/\/(.*)$/\1/");
    PATH_TO_PUBLIC_ESCAPED=$(echo $PATH_TO_PUBLIC | sed 's/\//\\\//');
    PATH_TO_PUBLIC_ESCAPED_TWICE=$(echo $PATH_TO_PUBLIC_ESCAPED | sed 's/\//\\\\\//');
    IP_ADDRESS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $DB_CONTAINER_NAME);

    sed "s/%email_address%/$EMAIL_ADDRESS/;s/%WEB_DOMAIN_NAME%/$WEB_DOMAIN_NAME/g;s/%URL_ENDING%/$URL_ENDING/g;s/%GIT_REPO_TITLE%/$GIT_REPO_TITLE/;s/%PATH_TO_PUBLIC%/$PATH_TO_PUBLIC_ESCAPED/;s/%PATH_TO_PUBLIC_ESCAPED%/$PATH_TO_PUBLIC_ESCAPED_TWICE/;s/\$DB_CONTAINER_NAME/$DB_CONTAINER_NAME/;s/\$DB_PORT/$DB_PORT/;s/\$DB_NAME/$DB_NAME/;s/\$DB_USER_NAME/$DB_USER_NAME/;s/\$DB_USER_PASSWORD/$DB_USER_PASSWORD/;s/\$WEB_DOMAIN_NAME/$WEB_DOMAIN_NAME/;" ./Dockerfile | \
    docker build -t katzda/bookings:latest . -f -;

    #Create a container
    docker run \
        -v $REPO_DIR/:/var/www/$WEB_DOMAIN_NAME$URL_ENDING \
        --name $WEBSERVER_HOSTNAME \
        -p 80:80 \
        -d \
        --rm \
        --add-host=$DB_CONTAINER_NAME:$IP_ADDRESS \
        --network=$NETWORK_TITLE \
        katzda/bookings:latest;
}
DBWebServerDelete_(){
    docker rm -f $(docker ps -f name="$WEBSERVER_HOSTNAME" -q)
}
DBWebServerUp(){
    if DBWebServerExists; then
        DBWebServerDown;
    fi;

    DBWebServerCreate_;

    if [[ $SKIP_POST_INSTALLATION_STEPS = false ]]; then
        docker exec $WEBSERVER_HOSTNAME bash -c "chmod 775 -R storage";
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c "if [ ! -f .env ]; then mv /home/developer/.env /var/www/$WEB_DOMAIN_NAME$URL_ENDING/$PATH_TO_PUBLIC; fi;";
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'composer install && npm install && npm run dev';
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'if [[ -z $(cat .env | grep APP_KEY | sed -E "s/APP_KEY=(.*)$/\1/;s/\s+//;q") ]]; then php artisan key:generate; fi;';
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'php artisan migrate';
    fi;
}
DBWebServerDown(){
    if DBWebServerExists; then
        echo "REMOVING '$WEBSERVER_HOSTNAME' CONTAINER:"
        DBWebServerDelete_;
    fi;
}

CleanUp(){
    DockerDeleteContainersExited_;
    DockerDeleteImagesDangling_;
    DockerDeleteContainersConfigured_;

    if [[ $PURGE = true ]]; then
        DockerAllDown;
    fi;

    if [[ $IMAGES = true ]]; then
        DockerImagesDown;
    fi;

    if [[ $CLEAN_REPO = true ]]; then
        GitRepoDown;
    fi;
}

if [[ $UNINSTALL = true ]]; then
    DBHostDown;
    DockerDeleteVolumeConfigured_;
    DockerDeleteNetworkConfigured_;
    NetworkDown;
    VolumeDown;
    CleanUp;
    DBWebServerDown;
else
    NetworkUp;
    VolumeUp;
    DBHostUp;
    if ! GitRepoUp; then
        echo "Did you register this PUBLIC KEY in your repo?"
        cat ~/.ssh/$SSH_KEY_TITLE.pub
        echo "Something's wrong with SSH communication, exiting."
        exit;
    else
        DBWebServerUp;
    fi;
fi;
