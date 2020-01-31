#!/bin/bash

if [[ ! -e configs.sh ]]; then
    cp ./configs.sh-example ./configs.sh
fi;
. ./configs.sh
INSTALL_DIR=$HOME/$SAMBA_SHARE_DIRECTORY
UNINSTALL=false
SHOW_SAMBA_INSTRUCTIONS=false
SHOW_SSH_INSTRUCTIONS=false
SSH_VERBOUS=false
HELP_TEXT="-h This help text\n
-u Uninstall (unsupported yet): Should uninstall everything that this script has installed.\n
-s Samba: Show configuration instructions for windows. This is done automatically when samba has just been installed\n
-v verbous: Print debugging SSH connection info\n
-p public key: will display public key instructions. This is also done automatically if they needed to be generated."

TEXT_HIGHLIGHT="#########################################################################################################";
while getopts u-:s-:v-:h-:p-: option
do
    case "${option}"
    in
        u) UNINSTALL=true;;
        s) SHOW_SAMBA_INSTRUCTIONS=true;;
        p) SHOW_SSH_INSTRUCTIONS=true;;
        v) SSH_VERBOUS=true;;
        h) echo -e $HELP_TEXT; exit;;
    esac
done

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
}
Apache2Down(){
    if ! Apache2IsUninstalled ; then
        echo "Uninstalling Apache2 Server (because it's blocking port 80 and we have it inside docker)";
        Apache2Uninstall;
    fi;
}
OpenSSHIsInstalled(){
    sudo dpkg -l openssh-server &>/dev/null
    if [[ $? -ne 0 ]] ;
        then return 1;
        else return 0;
    fi
}
OpenSSHInstall(){
    sudo apt-get update;
    sudo apt-get install openssh-server -y;
}
OpenSSHUninstall(){
    sudo service ssh stop;
    apt-get –purge remove openssh-server -y;
}
OpenSSHServerUP(){
    if ! OpenSSHIsInstalled ; then
        echo "installing OpenSSH Server";
        OpenSSHInstall;
    fi
}
OpenSSHServerDown(){
    if OpenSSHIsInstalled ; then
        echo "Uninstalling OpenSSH Server";
        OpenSSHUninstall;
    fi
}
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
    sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
    sudo chmod g+rwx "$HOME/.docker" -R
    echo -e "\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\nBecause we had to install docker, we needed to logout and log in so we can run docker commands without sudo.\n\nPlease log out now, log back in and execute this file again.\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n";
    exit
}

DockerServiceIsRunning(){
    if [[ "$(sudo systemctl is-active docker.service)" == "active" ]] ;
    then return 0;
    else return 1;
    fi;
}

SambaIsInstalled(){
    sudo smbstatus &>/dev/null
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi;
}

SambaIsConfigured(){
    sed -zE "s/(\[)\w+(\]\s*$NUL\s*comment = Samba on Ubuntu$NUL\s*path = \/home\/$USER\/)\w+/\1$SAMBA_SHARE_DIRECTORY\2$SAMBA_SHARE_DIRECTORY/" /etc/samba/smb.conf
}

SambaInstall(){
    SHOW_SAMBA_INSTRUCTIONS=true
    echo -e "Installing Samba"
    sudo apt-get update >/dev/null
    sudo apt install samba -y
    mkdir $INSTALL_DIR

    echo -e "New [$SAMBA_SHARE_DIRECTORY] will point to $INSTALL_DIR"
    sudo chmod 777 /etc/samba/smb.conf
    sudo echo -e "[$SAMBA_SHARE_DIRECTORY]
    comment = Samba on Ubuntu
    path = $INSTALL_DIR
    read only = no
    browsable = yes" >> /etc/samba/smb.conf
    sudo chmod 644 /etc/samba/smb.conf

    sudo service smbd restart
    sudo ufw allow samba

    echo -e "Configuring SAMBA user; Please enter password for user '$USER':"
    sudo smbpasswd -a $USER
    sudo service smbd restart
}

InstructionsSamba(){
    echo -e "$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n - Now, in Windows in This PC, click 'Map network drive' and paste the following address into the 'folder' field (the only field where you can paste anything). Just in case if this is not the correct IP address, it simply is the one of this linux machine):\n"
    adds=$(hostname -I)
    for add in $adds; do echo "\\\\$add\\$SAMBA_SHARE_DIRECTORY"; break; done
    echo -e "\n - Check 'Connect using different credentials'"
    echo -e " - Make sure you use the '$USER' account and the password you used during configuration of Samba user."
    echo -e " - Click OK\n$TEXT_HIGHLIGHT\n$TEXT_HIGHLIGHT\n";
}

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
}

SSH_KEY_TITLE=$WEB_DOMAIN_NAME
SSHDirectoryExists(){
    if [[ -d ~/.ssh ]]; then return 0; else return 1; fi
}

SSHDirectoryCreate(){
    mkdir ~/.ssh;
    chmod 750 ~/.ssh
    chown $USER:$USER ~/.ssh
}

SSHConfigExists(){
    ssh_host=$(grep -r -e "Host github.com" ~/.ssh 2>/dev/null)
    ssh_identity=$(grep -r -e "IdentityFile = ~/.ssh/$SSH_KEY_TITLE" ~/.ssh 2>/dev/null)
    if [ ${#ssh_host} -gt 0 ] && [ ${#ssh_identity} -gt 0 ];
        then return 0;
        else return 1;
    fi
}

SSHConfigWrite(){
    ssh_configuration_text="Host github.com\n";
    ssh_configuration_text+="  Hostname github.com\n";
    ssh_configuration_text+="  User katzda\n";
    ssh_configuration_text+="  IdentityFile = ~/.ssh/$SSH_KEY_TITLE\n";
    ssh_configuration_text+="  Port 22\n\n";

    echo -e $ssh_configuration_text >> ~/.ssh/config
}

SSHConfigUndo(){
    if [[ $UNINSTALL = true ]]; then
        echo -e "Resetting the corresponsing txt configuration from ~/.ssh/config"
        sed -z -i "s/Host github.com//;s/ Hostname github.com//;s/ User katzda//;s/ IdentityFile = .*$NUL Port 22//;/^\s*$/ d" ~/.ssh/config
    fi
}

SSHKeyExists(){
    if [[ $UNINSTALL = true ]]; then
        echo -e "Deleting these shh keys:";
        ll "${SSH_KEY_DIR}/${SSH_KEY_TITLE}*";
        rm "${SSH_KEY_DIR}/${SSH_KEY_TITLE}*";
    fi;
    RSA=$(ls ~/.ssh | grep $SSH_KEY_TITLE)
    if [[ ${#RSA} -eq 0 ]];
        then return 1;
        else return 0;
    fi
}

SSHKeyGenerate(){
    CWD="$(pwd)"
    cd ~/.ssh
    ssh-keygen -t rsa -b 4096 -C "${USER}_vm" -P "" -f $SSH_KEY_TITLE
    chmod 400 ~/.ssh/$SSH_KEY_TITLE.pub
    chmod 400 ~/.ssh/$SSH_KEY_TITLE
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/$SSH_KEY_TITLE
    cd "$CWD";
}
SSHKeyTest(){
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

PrintPublicKeyInfo(){
    echo -e "\n$TEXT_HIGHLIGHT\nContact the owner of the target repository and ask them to register the following public key (without empty line breaks and these hightlighing '#'):\n$TEXT_HIGHLIGHT\n";
    cat ~/.ssh/$SSH_KEY_TITLE.pub
    echo -e "\n$TEXT_HIGHLIGHT\nThen execute this file again or resolve whatever issue manually\n$TEXT_HIGHLIGHT\n"
}

SSHCheckHealth(){
    #SSH Directory
    if ! SSHDirectoryExists ; then
        echo "Creating '~/.ssh' directory";
        SSHDirectoryCreate;
    fi;
    #SSH KEYS
    if ! SSHKeyExists ; then
        echo "Generating SSH PRIVATE KEY and PUBLIC LOCK"
        SSHKeyGenerate
    fi;
    #SSH/CONFIG FILE
    if ! SSHConfigExists ; then
        echo "(Re) writing SSH config settings (~/.ssh/config)"
        SSHConfigWrite
    fi;
    if ! SSHKeyTest; then
        SHOW_SSH_INSTRUCTIONS=true;
    fi;
}

Apache2Down;
OpenSSHServerUP;

#INSTALL SUDO
if ! SudoIsInstalled ; then
    echo "installing sudo";
    SudoInstall;
fi

#INSTALL CURL
if ! CurlIsInstalled ; then
    echo "installing curl";
    CurlInstall;
fi

#INSTALL DOCKER
if ! DockerIsInstalled ; then
    echo "installing docker";
    DockerInstall;
fi

#INSTALL SAMBA
if ! SambaIsInstalled ; then
    echo "installing samba";
    SambaInstall;
fi

#INSTALL DOCKER COMPOSE
if ! DockerComposeIsInstalled; then
    echo "installing docker compose";
    DockerComposeInstall;
fi;

#Check SSH
SSHCheckHealth;

#Samba instructions
if [[ "$SHOW_SAMBA_INSTRUCTIONS" = true ]]; then
    InstructionsSamba
fi

#SSH instructions
if [[ "$SHOW_SSH_INSTRUCTIONS" = true ]]; then
    echo "Printing public key info:";
    PrintPublicKeyInfo
fi

#Final message
if DockerIsInstalled && SambaIsInstalled && DockerComposeIsInstalled; then
    echo -e "This script did its job. All done!\nNow don't forget to set a password in configs.sh and run ./install.sh";
fi;
