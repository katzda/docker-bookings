# docker-bookings
Allows deploymment of the corresponding private repo, provided I registered your public key

1. You need ubuntu 18.04 LTS (be it a VM in a virtual box or an actual server)
2. Git clone this repo into your ~/ directory
3. execute "cp configs.sh-example configs.sh" to create your own (already .gitignored) configuration file
4. give it a password and customize any values (e.g. an email)
5. run script "server-install.sh" (and follow inscructions). You can also inspect arguments with '-h' flag
6. Run the "install.sh" script and enjoy the magic. (also supports '-h' flag)
