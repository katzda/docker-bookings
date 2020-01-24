#!/bin/bash
. ./configs.sh
INSTALL_DIR=$HOME/$SAMBA_SHARE_DIRECTORY
UNINSTALL=false
SHOW_SAMBA_INSTRUCTIONS=false
SSH_VERBOUS=false
HELP_TEXT="-h This help text\n
-u Uninstall (unsupported yet): Should uninstall everything that this script has installed.\n
-s Samba: Show configuration instructions for windows. This is done automatically when samba has just been installed\n
-v verbous: Print debugging SSH connection info\n"

while getopts u-:s-:v-:h-: option
do
    case "${option}"
    in
        u) UNINSTALL=true;;
        s) SHOW_SAMBA_INSTRUCTIONS=true;;
        v) SSH_VERBOUS=true;;
        h) echo -e $HELP_TEXT; exit;;
    esac
done

DockerIsInstalled(){
    docker --version &>/dev/null
    if [[ $? -ne 0 ]] ;
    then return 1;
    else return 0;
    fi
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
    echo "Because we had to install docker, we needed to logout and log in so we can run docker commands as a docker user."
    echo "Please log out and log in"
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

SambaInstall(){
    SHOW_SAMBA_INSTRUCTIONS=true
    echo "Installing Samba"
    sudo apt-get update >/dev/null
    sudo apt install samba -y
    mkdir $INSTALL_DIR

    echo "New [$SAMBA_SHARE_DIRECTORY] will point to $INSTALL_DIR"
    sudo chmod 777 /etc/samba/smb.conf
    sudo echo "[$SAMBA_SHARE_DIRECTORY]
    comment = Samba on Ubuntu
    path = $INSTALL_DIR
    read only = no
    browsable = yes" >> /etc/samba/smb.conf
    sudo chmod 644 /etc/samba/smb.conf

    sudo service smbd restart
    sudo ufw allow samba

    echo "Configuring SAMBA user; Please enter password for user '$USER':"
    sudo smbpasswd -a $USER
}

InstructionsSamba(){
    echo " - Now in Windows in This PC, click 'Map network drive' and paste the following address (or if this is not the correct one, it simply needs to be the IP of this linux machine):"
    adds=$(hostname -I)
    for add in $adds; do echo "\\\\$add\\$SAMBA_SHARE_DIRECTORY"; break; done
    echo " - Check 'Connect using different credentials'"
    echo " - Make sure you use the '$USER' account and the password you used during configuration of Samba user."
    echo " - Click OK"
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
        echo "Resetting the corresponsing txt configuration from ~/.ssh/config"
        sed -z -i "s/Host github.com//;s/ Hostname github.com//;s/ User katzda//;s/ IdentityFile = .*$NUL Port 22//;/^\s*$/ d" ~/.ssh/config
    fi
}

SSHKeyExists(){
    if [[ $UNINSTALL = true ]]; then
        echo "Deleting these shh keys:";
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
    cd ~/.ssh
    ssh-keygen -t rsa -b 4096 -C "${USER}_vm" -P "" -f $SSH_KEY_TITLE
    chmod 400 ~/.ssh/$SSH_KEY_TITLE.pub
    chmod 400 ~/.ssh/$SSH_KEY_TITLE
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/$SSH_KEY_TITLE
}

RepairSSHconfig(){
    was_ssh_configuration_ok=0
    #SSH Directory
    if ! SSHDirectoryExists ; then
        echo "Creating '~/.ssh' directory";
        SSHDirectoryCreate;
        was_ssh_configuration_ok=1;
    fi
    #SSH KEYS
    if ! SSHKeyExists ; then
        echo "Generating SSH PRIVATE KEY and PUBLIC LOCK"
        SSHKeyGenerate
        was_ssh_configuration_ok=1;
    fi
    #SSH/CONFIG FILE
    if ! SSHConfigExists ; then
        echo "(Re) writing SSH config settings (~/.ssh/config)"
        SSHConfigWrite
        was_ssh_configuration_ok=1;
    fi
    return $was_ssh_configuration_ok
}

#INSTALL DOCKER
if ! DockerIsInstalled ; then
    DockerInstall;
fi

#INSTALL SAMBA
if ! SambaIsInstalled ; then
    SambaInstall;
fi

#INSTALL DOCKER COMPOSE
if ! DockerComposeIsInstalled; then
    DockerComposeInstall;
fi;

#CONFIGURE SSH
if ! RepairSSHconfig || [[ $SSH_VERBOUS = true ]]; then
    echo "Executing ssh connection test:"
    if [[ $SSH_VERBOUS = true ]]; then
        ssh -vvvT katzda@github.com
    else
        ssh katzda@github.com
    fi
else
    echo "SSH was already setup correctly"
fi

#Samba instructions
if [[ "$SHOW_SAMBA_INSTRUCTIONS" = true ]]; then
    InstructionsSamba
fi
