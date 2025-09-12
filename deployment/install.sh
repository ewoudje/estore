#!/bin/bash
# UNTESTED


# lxc-create -t download -n ewoud-estore -- -d alpine -r 3.22 -a amd64
# lxc-attach -n ewoud-estore
# inside lxc: curl https://raw.githubusercontent.com/ewoudje/estore/refs/heads/main/install.sh | sh

apk add curl
wget https://raw.githubusercontent.com/ewoudje/estore/refs/heads/main/deployment/update.sh
wget https://raw.githubusercontent.com/ewoudje/estore/refs/heads/main/deployment/estore.service
chmod +x update.sh
chmod +x estore.service
mv estore.service /etc/init.d/estore
./update.sh
rc-update add estore
echo "*/5 * * * * /root/update.sh" > /etc/crontabs/root
