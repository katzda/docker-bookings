#!/bin/bash

if [[ ! -e configs.sh ]]; then
    echo "Before running server-install.sh you need to create configs.sh based on the example.";
    exit;
fi;

#################################################
##OPTIONS: Make this script behave dinamically ##
#################################################
. ./configs.sh
export INSTALL_DIR=$INSTALL_DIR;
export SSH_KEY_TITLE=$SSH_KEY_TITLE;
UNINSTALL=false
SSH_REMOVE_KEY_PAIR=false
SHOW_SAMBA_INSTRUCTIONS=false
SHOW_SSH_INSTRUCTIONS=false
SSH_VERBOUS=false
HELP_TEXT="
\n-h | --help: \t\t\tShow this help text
\n-u | --uninstall: \t\tUninstall everything that this script has installed.
\n-k | --remove-ssh-key-also: \tThis will only apply in case when the database with the name that is set in configs does not exist
\n-s | --samba-instructions: \tShow configuration instructions for windows. This is done automatically when samba has just been installed
\n-p | --ssh-key-instructions\tDisplay public key instructions. This is also done automatically if they needed to be generated
\n-v | --ssh-verbous: \t\tPrint debugging SSH connection info
\n";

############
##OPTIONS:##
############

TEXT_HIGHLIGHT="##############################################################################";

while [ "$1" != "" ]; do
    case $1 in
        -h | --help ) echo -e $HELP_TEXT; exit;;
        -u | --uninstall ) UNINSTALL=true;;
        -k | --remove-ssh-key-also ) SSH_REMOVE_KEY_PAIR=true;;
        -s | --samba-instructions ) SHOW_SAMBA_INSTRUCTIONS=true;;
        -p | --ssh-key-instructions ) SHOW_SSH_INSTRUCTIONS=true;;
        -v | --ssh-verbous ) SSH_VERBOUS=true;;
        * ) echo -e $HELP_TEXT; exit 1;;
    esac
    shift
done

####################################################################################
##FUNCTIONS: Are usually of these kind: Install, IsInstalled, Uninstall, Up, Down ##
####################################################################################

#SUDO
SudoIsInstalled(){
    sudo -V &>/dev/null;
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi
}
SudoInstall(){
    echo "Please enter your superuser password:"
    apt-get update;
    apt-get install sudo;
    usermod -aG sudo $USER;
    if SudoIsInstalled; then
        echo "Program 'sudo' has been installed successfuly";
    else
        echo "Could not install sudo, exiting!";
        exit;
    fi;
}
SudoUP(){
    if ! SudoIsInstalled; then
        echo "Installing sudo";
        SudoInstall;
    fi;
}

#CURL
CurlIsInstalled(){
    curl -V &>/dev/null;
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi;
}
CurlInstall(){
    sudo apt-get install curl;
}
CurlUP(){
    if ! CurlIsInstalled; then
        echo "Installing curl";
        CurlInstall;
    fi;
}

#APACHE2
Apache2IsUninstalled(){
    sudo service apache2 status &>/dev/null;
    if [[ $? -ne 4 ]] ;
        then return 1;
        else return 0;
    fi
}
Apache2Uninstall(){
    sudo service apache2 stop;
    sudo apt-get purge apache2 apache2-utils apache2.2-bin -y;
    sudo apt autoremove -y;
}
Apache2Down(){
    if ! Apache2IsUninstalled ; then
        echo "Uninstalling Apache2 Server (because it's blocking port 80 and we have it inside docker)";
        Apache2Uninstall;
    fi;
}

#OpenSSHServer
OpenSSHServerIsInstalled(){
    ssh -V &>/dev/null
    if [[ $? -ne 0 ]] ;
        then return 1;
        else return 0;
    fi
}
OpenSSHServerInstall(){
    sudo apt-get update;
    sudo apt-get install openssh-server -y;
    sudo ufw allow ssh
    sudo systemctl enable ssh
    sudo systemctl start ssh
}
OpenSSHServerUninstall(){
    sudo service ssh stop;
    sudo apt-get remove *ssh* --purge -y;
    sudo apt autoremove -y;
}
OpenSSHServerServerUP(){
    if ! OpenSSHServerIsInstalled ; then
        echo "installing OpenSSH Server";
        OpenSSHServerInstall;
    fi
}
OpenSSHServerDown(){
    if OpenSSHServerIsInstalled ; then
        echo "Uninstalling OpenSSH Server";
        OpenSSHServerUninstall;
    fi
}

#Docker
DockerIsInstalled(){
    docker --version &>/dev/null
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi;
}
DockerInstall(){
    echo "Installing DOCKER"
    sudo apt-get update >/dev/null
    sudo apt install docker.io -y
    echo "Adding a 'docker' group"
    sudo groupadd docker >/dev/null
    sudo usermod -aG docker $USER
    echo "Starting docker service"
    sudo systemctl start docker >/dev/null
    echo -e "\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\nBecause we had to install docker, we needed to logout and log in so we can run docker commands without sudo.\n\nPlease log out now, log back in and execute this file again.\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n";
    exit
}
DockerUninstall(){
    sudo service docker stop;
    sudo apt-get remove docker-ce docker docker-engine docker.io containerd runc -y;
    sudo apt-get purge docker-ce;
    sudo rm -rf /var/lib/docker;
    sudo apt autoremove -y;
}
DockerUp(){
    if ! DockerIsInstalled ; then
        echo "Installing docker";
        DockerInstall;
    fi
}
DockerDown(){
    if DockerIsInstalled ; then
        echo "Uninstalling docker";
        DockerUninstall;
    fi
}

#DockerCompose
DockerComposeIsInstalled(){
    docker-compose --version &>/dev/null
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi;
}
DockerComposeInstall(){
    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}
DockerComposeUninstall(){
    sudo rm /usr/local/bin/docker-compose
    sudo apt autoremove -y;
}
DockerComposeUP(){
    if ! DockerComposeIsInstalled; then
        echo "Installing docker compose";
        DockerComposeInstall;
    fi;
}
DockerComposeDown(){
    if DockerComposeIsInstalled; then
        echo "Uninstalling docker compose";
        DockerComposeUninstall;
    fi;
}

#Samba
SambaIsInstalled(){
    sudo smbstatus &>/dev/null
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi;
}
SambaInstall(){
    SHOW_SAMBA_INSTRUCTIONS=true
    sudo apt-get update >/dev/null
    sudo apt install samba -y
    mkdir $INSTALL_DIR

    echo -e "New [$SAMBA_SHARE_DIRECTORY] will point to $INSTALL_DIR"
    sudo chmod 777 /etc/samba/smb.conf
    sudo echo -e "[$SAMBA_SHARE_DIRECTORY]
    comment = Samba on Ubuntu
    path = $INSTALL_DIR
    read only = no
    follow symlinks = yes
    wide links = yes
    browsable = yes" >> /etc/samba/smb.conf
    sudo chmod 644 /etc/samba/smb.conf

    sudo service smbd restart
    sudo ufw allow samba

    echo -e "Configuring SAMBA user; Please enter password for user '$USER':"
    sudo smbpasswd -a $USER
    sudo service smbd restart
}
SambaUninstall(){
    sudo apt-get remove --purge samba -y
    sudo apt autoremove -y;
}
SambaUP(){
    if ! SambaIsInstalled; then
        echo "Installing Samba";
        SambaInstall;
    fi;
}
SambaDown(){
    if SambaIsInstalled; then
        echo "Uninstalling Samba";
        SambaUninstall;
    fi;
}

#SSH KEY
#boolean returning functions
SSHEnsureDirectoryExists(){
    if [[ ! -d ~/.ssh ]]; then
        mkdir ~/.ssh;
        chmod 750 ~/.ssh
        chown $USER:$USER ~/.ssh
    fi;
}
SSHKeysExist(){
    RSA=$(ls ~/.ssh | grep $SSH_KEY_TITLE)
    if [[ ${#RSA} -eq 0 ]];
        then return 1;
        else return 0;
    fi
}
SSHConfigExists(){
    ssh_host=$(grep -r -e "Host github.com" ~/.ssh 2>/dev/null)
    ssh_identity=$(grep -r -e "IdentityFile = ~/.ssh/$SSH_KEY_TITLE" ~/.ssh 2>/dev/null)
    if [ ${#ssh_host} -gt 0 ] && [ ${#ssh_identity} -gt 0 ];
        then return 0;
        else return 1;
    fi
}
#set, unset
SSHKeysSet(){
    CWD="$(pwd)";
    SSHEnsureDirectoryExists;
    cd ~/.ssh
    ssh-keygen -t rsa -b 4096 -C "${USER}_vm" -P "" -f $SSH_KEY_TITLE
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/$SSH_KEY_TITLE
    cd "$CWD";
    chmod 400 ~/.ssh/$SSH_KEY_TITLE.pub
    chmod 400 ~/.ssh/$SSH_KEY_TITLE
}
SSHKeysUnset(){
    rm -f ~/.ssh/*;
}
SSHConfigSet(){
    ssh_configuration_text="Host github.com\n";
    ssh_configuration_text+="  Hostname github.com\n";
    ssh_configuration_text+="  StrictHostKeyChecking no\n";
    ssh_configuration_text+="  IdentityFile = ~/.ssh/$SSH_KEY_TITLE\n";
    echo -e $ssh_configuration_text >> ~/.ssh/config
}
SSHConfigUnset(){
    sed -z -i "s/Host github.com//;s/ Hostname github.com//;s/ StrictHostKeyChecking no//;s/ IdentityFile = .*//;/^\s*$/ d" ~/.ssh/config
}
#UP and DOWN
SSHUp(){
    if ! SSHKeysExist; then
        echo "Generating a new SSH key pair";
        SSHKeysSet;
    fi;
    if ! SSHConfigExists; then
        echo "Registering the keys.";
        SSHConfigSet;
    fi;
}
SSHDown(){
    if SSHConfigExists; then
        echo "Unregistering the keys.";
        SSHConfigUnset;
    fi;
    if SSHKeysExist && [[ $SSH_REMOVE_KEY_PAIR = true ]]; then
        echo "Removing public and private SSH keys";
        SSHKeysUnset;
    fi;
}
SSHConnectivityTest(){
    echo "Executing SSH connectivity test";
    if [[ $SSH_VERBOUS = true ]];
        then ssh -vT git@github.com
        else ssh -T git@github.com
    fi;
    if [[ $? -eq 1 ]];
    then return 0;
    else return 1;
    fi;
}

##############################
## FINAL MESSAGES FUNCTIONS ##
##############################

InstructionsSamba(){
    echo -e "$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n - Now, in Windows in This PC, click 'Map network drive' and paste the following address into the 'folder' field (the only field where you can paste anything). Just in case if this is not the correct IP address, it simply is the one of this linux machine):\n"
    adds=$(hostname -I)
    for add in $adds; do echo "\\\\$add\\$SAMBA_SHARE_DIRECTORY"; break; done
    echo -e "\n - Check 'Connect using different credentials'"
    echo -e " - Make sure you use the '$USER' account and the password you used during configuration of Samba user."
    echo -e " - Click OK\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n";
}

PrintPublicKeyInfo(){
    echo -e "\n$TEXT_HIGHLIGHT\nNow you need to register this public key in the repository you want to clone from:\n$TEXT_HIGHLIGHT\n";
    cat ~/.ssh/$SSH_KEY_TITLE.pub
    echo -e "\n$TEXT_HIGHLIGHT\nThen execute this file again or resolve whatever issue manually\n$TEXT_HIGHLIGHT\n"
}

PrintFinalMessage(){
    echo -e "This script did its job. All done!"
}

############################################################################################################################
#CHECK METHODS: These serve as high level managers to know what needs to be done based on options and set configurations, ##
############### e.g: "-U" or "IS_PROD_ENV=true" ############################################################################
############################################################################################################################

CheckSudo(){
    SudoUP;
}
CheckCurl(){
    CurlUP;
}
CheckApache2(){
    Apache2Down;
}
CheckOpenSSHServer(){
    if [[ $UNINSTALL = true ]]; then
        OpenSSHServerDown;
    else
        OpenSSHServerServerUP;
    fi;
}
CheckDocker(){
    if [[ $UNINSTALL = true ]]; then
        DockerDown;
    else
        DockerUp;
    fi;
}
CheckDockerCompose(){
    if [[ $UNINSTALL = true ]]; then
        DockerComposeDown;
    else
        DockerComposeUP;
    fi;
}
CheckSamba(){
    if [[ $UNINSTALL = true ]] || [[ $IS_PROD_ENV = true ]]; then
        SambaDown;
    else
        SambaUP;
    fi;
}
CheckSSHConfiguration(){
    if [[ $UNINSTALL = true ]]; then
        SSHDown;
    else
        SSHUp;
        if ! SSHConnectivityTest; then
            SHOW_SSH_INSTRUCTIONS=true;
        fi;
    fi;
}
CheckFinalMessagesPrint(){
    if [[ "$SHOW_SAMBA_INSTRUCTIONS" = true ]]; then
        InstructionsSamba;
    fi
    if [[ "$SHOW_SSH_INSTRUCTIONS" = true ]]; then
        echo "Printing public key info:";
        PrintPublicKeyInfo;
    fi
    if DockerIsInstalled && SambaIsInstalled && DockerComposeIsInstalled; then
        PrintFinalMessage;
    fi;
}

#Calls
CheckSudo;
CheckCurl;
CheckApache2;
CheckOpenSSHServer;
CheckDocker;
CheckDockerCompose;
CheckSamba;
CheckSSHConfiguration;
CheckFinalMessagesPrint;
