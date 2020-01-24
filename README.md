# docker-bookings
Allows deploymment of the corresponding private repo, provided I registered your public key

1. You need ubuntu 18.04 LTS (be it a VM in a virtual box or an actual server)
2. cd into your home dir "cd ~/"
3. git clone this repo
4. cd inside the cloned repo
5. execute "cp configs.sh-example configs.sh" to create your own (already .gitignored) configuration file
6. 'nano configs.sh' and customize any values (e.g. an email, password)
7. run script "./server-install.sh" (and follow inscructions). You can also inspect arguments with '-h' flag
8. Run the "./install.sh" script and enjoy the magic. (also supports '-h' flag)

---------------------------------------------------------
- For development on windows it is practical to install "mtputty" and "putty", link "mtputty" to use "putty" so you can ssh and work easily with the linux VM, rather working with the actual VM directly (hassle).
- After all installation is done, your repository will live in the samba share directory mapped into the docker container, so you'll be able to access the files from windows ThisPC and use any kind of Windows IDE.
