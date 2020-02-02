# docker-bookings
Allows deploymment of the corresponding private repo

1. You need ubuntu 18.04 LTS from https://ubuntu.com/download/server<br>
  Settings which work in VirtualBox:<br><i>
  a) RAM 2048MB<br>
  b) HDD dynamic 100GB<br>
  c) during installation, set up static IP mapping<br>
        -run ipconfig in windows, say your current IP is 192.168.1.3 and gateway 192.168.254<br>
        -name server will be same as gateway<br>
        -network name will end with zero slash mask, e.g 192.168.1.0/24<br>
  d) if it crashes during installation, just start again and it will work<br>
  e) fill in your details like name (josh xxx), server name (my_vm), password (6145),... <br>
  f) do select install open-ssh and proceed through until restart, remove media, boot up <br>
  g) sudo apt-get update && sudo apt-get upgrade && sudo apt-get install git-all<br></i>
2. cd into your home dir "cd ~/"
3. git clone this repo
4. cd inside the cloned repo
5. run script "./server-install.sh" (and follow inscructions). You can also inspect arguments with '-h' flag
6. Run the "./install.sh" script and enjoy the magic. (also supports '-h' flag)

---------------------------------------------------------
- For development on windows it is practical to install on windows "mtputty" and "putty", link "mtputty" to use "putty" so you can ssh and work easily with the linux VM, rather than working with the actual VM directly (hassle).
- After all installation is done, your repository will live in the samba share directory mapped into the docker container, so you'll be able to access the files from windows ThisPC and use any kind of Windows IDE (e.g VSCode)
