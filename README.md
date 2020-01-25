# docker-bookings
Allows deploymment of the corresponding private repo, provided I registered your public key

1. You need ubuntu 18.04 LTS from https://ubuntu.com/download/server
  Settings which work in VirtualBox:
  a) RAM 2048MB
  b) HDD dynamic 100GB
  c) during installation, set up static IP mapping 
      - run ipconfig in windows, say your current IP is 192.168.1.3 and gateway 192.168.254
      - name server will be same as gateway
      - network name will end with zero slash mask, e.g 192.168.1.0/24
  d) if it crashes during installation, just start again and it will work
  e) fill in your details like name (josh xxx), server name (my_vm), password (6145),... 
  f) do select install open-ssh and proceed through until restart, remove media, boot up
  g) sudo apt-get update && sudo apt-get upgrade && sudo apt-get install git-all
2. cd into your home dir "cd ~/"
3. git clone this repo
4. cd inside the cloned repo
5. execute "cp configs.sh-example configs.sh" to create your own (already .gitignored) configuration file
6. 'nano configs.sh' and customize any values (e.g. an email, password)
7. run script "./server-install.sh" (and follow inscructions). You can also inspect arguments with '-h' flag
8. Run the "./install.sh" script and enjoy the magic. (also supports '-h' flag)

---------------------------------------------------------
- For development on windows it is practical to install "mtputty" and "putty", link "mtputty" to use "putty" so you can ssh and work easily with the linux VM, rather than working with the actual VM directly (hassle).
- After all installation is done, your repository will live in the samba share directory mapped into the docker container, so you'll be able to access the files from windows ThisPC and use any kind of Windows IDE (e.g VSCode)
