#!/bin/bash
. ./configs.sh

#################################################
##OPTIONS: Make this script behave dinamically ##
#################################################

INSTALL_DIR=$HOME/$SAMBA_SHARE_DIRECTORY
UNINSTALL=false
PURGE=false
CLEAN_REPO=false
IMAGES=false
SKIP_POST_INSTALLATION_STEPS=false
INSTALL_DEV_CWD=$(pwd)
FLAG_VOLUME_DELETE=false
HELP_TEXT="This script will install the DB container, create a database with a user, create an image and a container for the web server, download the git repo - making sure it contains the latest commit, run composer, npm install and dev compilation and php artisan command for DB migration. By default every run of this script (install or uninstall deletes dangling images and stopped containers)\n
-h Help text\n
-U UNINSTALL: this will delete the 'configured' PostgresContainer (not the volume!), Apache Server container, Networks (the containers use to communicate) and the git REPO and then exit. This can be used with -R -I -P -V flags.\n
-R Repo: Deletes the entire repo directory (so the automatic setup will have to reinstall all dependencies again)\n
-I Images: Delete all docker images as well (so they will have to be recreated from scratch again)\n
-P Purge: Deletes all running containers (not just the configured ones) and all networks (but not the volumes unless running with -V and not in prod). This is a good flag to use often if you are constantly renaming your webserver in the 'configs' file etc and have some previous containers to remove you forgot to uninstall with -U. But this will affect all docker containers and all webservers on the system.\n
-V Volume: This flag must be explicitely used with -U to include removal of DB volume(s). This step basically destroys the DB data in a dev environment. If \$IS_PROD_ENV is set to true (in configs.sh) this will still not delete any volume(s)\n
-s SKIP_POST_INSTALLATION_STEPS - e.g ./install -s will only update docker image but skip the composer and npm install (useful if you are working on docker file and dont want to wait for these irrelevant install steps)";

while getopts h-:U-:R-:I-:P-:V-:s-: option
do
    case "${option}"
    in
        h) echo -e $HELP_TEXT; exit;;
        U) UNINSTALL=true;;
        R) CLEAN_REPO=true;;
        I) IMAGES=true;;
        P) PURGE=true;;
        V) FLAG_VOLUME_DELETE=true;;
        s) SKIP_POST_INSTALLATION_STEPS=true;;
    esac
done

if  [[ ${#IS_PROD_ENV} -eq 0 ]] || \
    [[ ${#BRANCH_DEV} -eq 0 ]] || \
    [[ ${#BRANCH_PROD} -eq 0 ]] || \
    [[ ${#EMAIL_ADDRESS} -eq 0 ]] || \
    [[ ${#WEB_DOMAIN_NAME} -eq 0 ]] || \
    [[ ${#URL_ENDING} -eq 0 ]] || \
    [[ ${#DB_NAME} -eq 0 ]] || \
    [[ ${#DB_USER_NAME} -eq 0 ]] || \
    [[ ${#DB_PORT} -eq 0 ]] || \
    [[ ${#DB_USER_PASSWORD} -eq 0 ]] || \
    [[ ${#GITHUB_CLONE_SSH_URL} -eq 0 ]];
then
    echo "Please supply information for all parameters in 'config.sh':"
    exit
fi;

####################################################################################
##FUNCTIONS: Are usually of these kind: Install, IsInstalled, Uninstall, Up, Down ##
####################################################################################

#Networks
NETWORK_TITLE="${WEB_DOMAIN_NAME}Network"
NetworkExists(){
    if [ -z $(docker network ls -f name="$NETWORK_TITLE" -q) ];
    then return 1;
    else return 0;
    fi
}
NetworkOthersExist(){
    if [ -z $(docker network ls -q) ];
    then return 1;
    else return 0;
    fi
}
NetworkCreate_(){
    docker network create $NETWORK_TITLE
}
NetworkDelete_(){
    docker network rm $(docker network ls -f name="$NETWORK_TITLE" -q)
}
NetworkDeleteAll_(){
    docker network prune -f;
}
NetworkUp(){
    if ! NetworkExists; then
        echo "Creating network: '$NETWORK_TITLE'";
        NetworkCreate_;
    fi;
}
NetworkDown(){
    if NetworkExists; then
        echo "Deleting network: '$NETWORK_TITLE'";
        NetworkDelete_;
    fi;
}
NetworkAllDown(){
    if NetworkOthersExist; then
        echo "Deleting all networks";
        NetworkDeleteAll_;
    fi;
}

#Volumes
VOLUME_TITLE="${WEB_DOMAIN_NAME}Volume"
VolumeExists(){
    if [ -z $(docker volume ls -f name="$VOLUME_TITLE" -q) ];
    then return 1;
    else return 0;
    fi
}
VolumesOtherExist(){
    if [ -z $(docker volume ls -q) ];
    then return 1;
    else return 0;
    fi
}
VolumeCreate_(){
    docker volume create $VOLUME_TITLE
}
VolumeDelete_(){
    docker volume rm $(docker volume ls -f name="$VOLUME_TITLE" -q)
}
VolumesDeleteAll_(){
    docker volume rm $(docker volume ls -q);
}
VolumeUp(){
    if ! VolumeExists; then
        echo "Creating volume: '$VOLUME_TITLE'";
        VolumeCreate_;
    fi;
}
VolumeDown(){
    if VolumeExists; then
        echo "Deleting volume: '$VOLUME_TITLE'";
        VolumeDelete_;
    fi;
}
VolumesAllDown(){
    if VolumesOtherExist; then
        echo "Deleting all volumes";
        VolumesDeleteAll_;
    fi;
}

#REPOSITORY
GIT_REPO_TITLE=$(echo $GITHUB_CLONE_SSH_URL | sed -E "s/.*:[a-z]+\/([a-z.\-]+)\.git/\1/");
if [[ $IS_PROD_ENV = true ]]; then
    BRANCH_TO_USE=$BRANCH_PROD;
else
    BRANCH_TO_USE=$BRANCH_DEV;
fi;
REPO_DIR="$INSTALL_DIR/$GIT_REPO_TITLE"
GitCloneRepo(){
    mkdir $REPO_DIR;
    if ! (sudo -u $USER git clone -b $BRANCH_TO_USE $GITHUB_CLONE_SSH_URL $REPO_DIR); then
        if ! GitRepoExists ; then
            sudo rm -rf $REPO_DIR/*;
        fi
        return 1;
    else
        return 0;
    fi;
}
GitPull(){
    CWD=$(pwd)
    cd $INSTALL_DIR/$GIT_REPO_TITLE
    sudo -u $USER git fetch
    git reset --hard "origin/$(git status | sed -E 's/On branch (.*)/\1/;q')";
    git checkout $BRANCH_TO_USE;
    git reset --hard "origin/$BRANCH_TO_USE";
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
    if GitRepoExists;
        then GitPull;
        else GitCloneRepo;
    fi;
}

#Images - all at once
IMAGE_WebServer_NAME="$WEB_DOMAIN_NAME.img"
ImageDBExists(){
    if [[ -n $(docker images postgres:latest -q) ]];
    then return 0;
    else return 1;
    fi
}
ImageServerExists(){
    if [[ -n $(docker images $IMAGE_WebServer_NAME -q) ]];
    then return 0;
    else return 1;
    fi
}
ImagesOthersExist(){
    if [[ -n $(docker images -a -q) ]];
    then return 0;
    else return 1;
    fi
}
ImageDBCreate_(){
    docker pull postgres:latest;
}
ImageServerCreate_(){
    PATH_TO_PUBLIC=$(find $REPO_DIR -name index.php | sed -E "s/(.*?)\/$GIT_REPO_TITLE(\/.*)\/public\/index\.php/\2/;s/\/(.*)$/\1/");
    PATH_TO_PUBLIC_ESCAPED=$(echo $PATH_TO_PUBLIC | sed 's/\//\\\//');
    PATH_TO_PUBLIC_ESCAPED_TWICE=$(echo $PATH_TO_PUBLIC_ESCAPED | sed 's/\//\\\\\//');
    IP_ADDRESS=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $DB_CONTAINER_NAME);

    sed "s/%email_address%/$EMAIL_ADDRESS/;s/%WEB_DOMAIN_NAME%/$WEB_DOMAIN_NAME/g;s/%URL_ENDING%/$URL_ENDING/g;s/%GIT_REPO_TITLE%/$GIT_REPO_TITLE/;s/%PATH_TO_PUBLIC%/$PATH_TO_PUBLIC_ESCAPED/;s/%PATH_TO_PUBLIC_ESCAPED%/$PATH_TO_PUBLIC_ESCAPED_TWICE/;s/\$DB_CONTAINER_NAME/$DB_CONTAINER_NAME/;s/\$DB_PORT/$DB_PORT/;s/\$DB_NAME/$DB_NAME/;s/\$DB_USER_NAME/$DB_USER_NAME/;s/\$DB_USER_PASSWORD/$DB_USER_PASSWORD/;s/\$WEB_DOMAIN_NAME/$WEB_DOMAIN_NAME/;" INSTALL_DEV_CWD/Dockerfile | \
    docker build -t $IMAGE_WebServer_NAME INSTALL_DEV_CWD -f -;
}
ImageDBDelete_(){
    docker rmi -f $(docker images postgres -q);
}
ImageServerDelete_(){
    docker rmi -f $(docker images $IMAGE_WebServer_NAME -q);
}
ImageDeleteAll_(){
    docker rmi -f $(docker images -a -q);
}
ImageDBUp(){
    if ! ImageDBExists; then
        ImageDBCreate_;
    fi;
}
ImageServerUp(){
    if ! ImageServerExists; then
        ImageServerCreate_;
    fi;
}
ImageDBDown(){
    if ImageDBExists; then
        ImageDBDelete_;
    fi;
}
ImageServerDown(){
    if ImageServerExists; then
        ImageServerDelete_;
    fi;
}
ImagesPrune(){
    if ImagesOthersExist; then
        ImageDeleteAll_;
    fi;
}

#Containers
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
DB_CONTAINER_NAME="${DB_NAME}Host"
WEBSERVER_HOSTNAME="${WEB_DOMAIN_NAME}Host";
ContainerDBExists(){
    if [ -z $(docker ps -a -f name="$DB_CONTAINER_NAME" -q) ];
    then return 1;
    else return 0;
    fi
}
ContainerServerExists(){
    if [ -z $(docker ps -a -f name="$WEBSERVER_HOSTNAME" -q) ]; then return 1; else return 0; fi;
}
ContainerOthersExist(){
    if [ -z $(docker ps -a -q) ];
    then return 1;
    else return 0;
    fi
}
ContainerDBCreate_(){
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
    postgres:latest
}
ContainerServerCreate_(){
    docker run \
        -v $REPO_DIR/:/var/www/$WEB_DOMAIN_NAME$URL_ENDING \
        --name $WEBSERVER_HOSTNAME \
        -p 80:80 \
        -d \
        --rm \
        --add-host=$DB_CONTAINER_NAME:$IP_ADDRESS \
        --network=$NETWORK_TITLE \
        "$WEB_DOMAIN_NAME.img";

    if [[ $SKIP_POST_INSTALLATION_STEPS = false ]]; then
        docker exec $WEBSERVER_HOSTNAME bash -c "chmod 775 -R storage";
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c "if [ ! -f .env ]; then mv /home/developer/.env /var/www/$WEB_DOMAIN_NAME$URL_ENDING/$PATH_TO_PUBLIC; fi;";
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'composer install && npm install && npm run dev';
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'if [[ -z $(cat .env | grep APP_KEY | sed -E "s/APP_KEY=(.*)$/\1/;s/\s+//;q") ]]; then php artisan key:generate; fi;';
        docker exec -u developer $WEBSERVER_HOSTNAME bash -c 'php artisan migrate';
    fi;
}
ContainerDBDelete_(){
    docker rm -f $(docker ps -a -f name="$DB_CONTAINER_NAME" -q)
}
ContainerServerDelete_(){
    docker rm -f $(docker ps -a -f name="$WEBSERVER_HOSTNAME" -q);
}
ContainerDeleteAll_(){
    docker rm -f $(docker ps -a -q)
}
ContainerDBUp(){
    if ! ContainerDBExists; then
        echo "Creating DB container ($DB_CONTAINER_NAME)"
        ContainerDBCreate_;
    fi;
}
ContainerDBDown(){
    if ContainerDBExists; then
        echo "Deleting DB container ($DB_CONTAINER_NAME)"
        ContainerDBDelete_;
    fi;
}
ContainerServerUp(){
    if ! ImageServerExists; then
        echo "Creating Apache2 image ($IMAGE_WebServer_NAME)"
        ImageServerCreate_;
    fi;
    if ! ContainerServerExists; then
        echo "Creating Apache2 container ($WEBSERVER_HOSTNAME)"
        ContainerServerCreate_;
    fi;
}
ContainerServerDown(){
    if ContainerServerExists; then
        echo "Deleting Apache2 container ($WEBSERVER_HOSTNAME)"
        ContainerServerDelete_;
    fi;
}
ContainersPrune(){
    if ContainerOthersExist; then
        echo "Deleting all containers."
        ContainerDeleteAll_;
    fi;
}

############################################################################################################################
#CHECK METHODS: These serve as high level managers to know what needs to be done based on options and set configurations, ##
############### e.g: "-U" or "IS_PROD_ENV=true" ############################################################################
############################################################################################################################

CheckNetworks(){
    #Options: U, REPO, IMAGES, PURGE, VOLUME
    if [[ $UNINSTALL = false ]]; then
        NetworkUp;
    else
        if [[ $PURGE = false ]]; then
            NetworkDown;
        else
            NetworkAllDown;
        fi;
    fi;
}

CheckVolumes(){
    #Options: U, REPO, IMAGES, PURGE, VOLUME
    if [[ $UNINSTALL = false ]]; then
        NetworkUp;
    else
        if [[ $IS_PROD_ENV = false ]] && [[ $FLAG_VOLUME_DELETE = true ]]; then
            if [[ $PURGE = false ]]; then
                VolumeDown;
            else
                VolumesAllDown;
            fi;
        fi;
    fi;
}

CheckRepo(){
    #Options: U, REPO, IMAGES, PURGE, VOLUME
    if [[ $UNINSTALL = false ]]; then
        GitRepoUp;
    else
        if [[ $CLEAN_REPO = true ]]; then
            GitRepoDown;
        fi;
    fi;
}

CheckImages(){
    #Options: U, REPO, IMAGES, PURGE, VOLUME
    if [[ $UNINSTALL = false ]]; then
        ImageDBUp;
        ImageServerUp;
    else
        if [[ $IMAGES = true ]]; then
            if [[ $PURGE = false ]]; then
                ImageServerDown;
                ImageDBDown;
            else
                ImagesPrune;
            fi;
        fi;
    fi;
}

CheckContainers(){
    #Options: U, REPO, IMAGES, PURGE, VOLUME
    if [[ $UNINSTALL = false ]]; then
        ContainerDBUp;
        ContainerServerUp;
    else
        if [[ $PURGE = false ]]; then
            ContainerServerDown;
            ContainerDBDown;
        else
            ContainersPrune;
        fi;
    fi;
}


########################################################################################################
#DEPENDENCY FUNCTION: The order of check functions matter differently when UNINTALL is true and false ##
########################################################################################################

Setup(){
    if [[ $UNINSTALL = false ]]; then
        CheckNetworks;
        CheckVolumes;
        CheckRepo;
        CheckImages;
        CheckContainers;
    else
        CheckContainers;
        CheckImages;
        CheckRepo;
        CheckNetworks;
        CheckVolumes;
    fi;
}

Setup;