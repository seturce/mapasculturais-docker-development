#!/bin/bash
set -e

if [ ! -f /.deployed ]; then
    #deploy project, theme and plugins
    cd /var/www/html/mapasculturais
    git clone  https://github.com/secultce/mapasculturais.git .
    git checkout production

    cd /var/www/html/mapasculturais/src/protected/application/themes
    git clone  https://github.com/seturce/theme-Ceara.git Ceara
    
    cd /var/www/html/mapasculturais/src/protected/application/plugins
    git clone  https://github.com/secultce/plugin-MultipleLocalAuth.git MultipleLocalAuth

    #create session and private-files folder
    cd /var/www/html/mapasculturais
    mkdir private-files
    chmod 777 private-files
    cd /var/www/html/mapasculturais/private-files
    mkdir sessions
    chmod 777 sessions

    #remove composer.lock
    rm -rf /var/www/html/mapasculturais/src/protected/composer.lock

    #refresh assets folder
    cd /var/www/html/mapasculturais/src
    mkdir assets
    chmod 777 assets

    #refresh files folder
    cd /var/www/html/mapasculturais/src
    mkdir files
    chmod 777 files

    #copy config file
    cp -r /tmp/config.php /var/www/html/mapasculturais/src/protected/application/conf/config.php
    
    #locale config
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    locale-gen en_US.UTF-8
    
    touch /.deployed
fi

#refresh Doctrine folder
cd /var/www/html/mapasculturais/src/protected
rm -rf ./DoctrineProxies
mkdir DoctrineProxies
chmod 777 DoctrineProxies

#run deploy script
cd /var/www/html/mapasculturais/scripts
./deploy.sh

#run in background permission script
nohup /recreate-pending-pcache-cron.sh &

exec "$@"
