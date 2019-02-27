#!/bin/bash
set -e

cd /var/www/html/mapasculturais/scripts
./deploy.sh

if [ ! -f /.deployed ]; then
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8
    touch /.deployed
fi

nohup /recreate-pending-pcache-cron.sh &

exec "$@"
