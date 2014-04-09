#!/bin/bash

if [ -z $1 ]; then
  echo "Usage: create_drupal_site.sh newprojectname"
  exit 0
fi

NAME=${1:0:64}
SQLNAME=${NAME:0:16}

cd ~/htdocs
drush make https://bitbucket.org/alexfisher/compro_install_profile/raw/master/make/compro.make $NAME

cd $NAME

# Create drush alias file.
mkdir sites/all/drush
touch sites/all/drush/$NAME.aliases.drushrc.php
echo "Creating drush alias file..."
echo "<?php" >> sites/all/drush/$NAME.aliases.drushrc.php
echo "" >> sites/all/drush/$NAME.aliases.drushrc.php
echo "\$aliases['dev-"$USER"'] = array(" >> sites/all/drush/$NAME.aliases.drushrc.php
echo "  'uri' => '"$NAME".dev'," >> sites/all/drush/$NAME.aliases.drushrc.php
echo "  'root' => '/home/"$USER"/htdocs/"$NAME"'," >> sites/all/drush/$NAME.aliases.drushrc.php
echo ");" >> sites/all/drush/$NAME.aliases.drushrc.php

# Create files directory.
echo "Creating files directory..."
mkdir sites/default/files
chmod 777 sites/default/files

# Create settings.php file.
echo "Creating settings.php file..."
cp sites/default/default.settings.php sites/default/settings.php
chmod 777 sites/default/settings.php

# Create a password.
PASS=${NAME//o/0}
PASS=${PASS//i/1}
PASS=${PASS//e/3}
PASS=${PASS//a/@}

# Create database.
read -s -p "Enter your MYSQL root user password: " SQLPASS
mysql -uroot -p$SQLPASS -e "create database $NAME"
mysql -uroot -p$SQLPASS -e "grant all on $NAME.* to $SQLNAME@localhost identified by '$PASS'"

# Install site.
drush site-install compro --db-url=mysql://$SQLNAME:$PASS@localhost/$NAME --account-name=admin --account-pass=$PASS --site-name=$NAME

# Setup apache vhost.
APACHE=/etc/apache2/sites-available
sudo touch $APACHE/$NAME
echo Wrote the following to $APACHE/$NAME.conf
echo "<VirtualHost *:80>" | sudo tee -a $APACHE/$NAME.conf
echo "        ServerName "$NAME.dev | sudo tee -a $APACHE/$NAME.conf
echo "        ServerAlias *."$NAME.dev | sudo tee -a $APACHE/$NAME.conf
echo "        DirectoryIndex index.php index.html" | sudo tee -a $APACHE/$NAME.conf
echo "        DocumentRoot /home/"$USER"/htdocs/"$NAME | sudo tee -a $APACHE/$NAME.conf
echo "        <Directory /home/"$USER"/htdocs/"$NAME">" | sudo tee -a $APACHE/$NAME.conf
echo "                Options Indexes FollowSymLinks" | sudo tee -a $APACHE/$NAME.conf
echo "                AllowOverride All" | sudo tee -a $APACHE/$NAME.conf
echo "                Require all granted" | sudo tee -a $APACHE/$NAME.conf
echo "        </Directory>" | sudo tee -a $APACHE/$NAME.conf
echo "        ErrorLog /var/log/apache2/"$NAME.local_error.log | sudo tee -a $APACHE/$NAME.conf
echo "        CustomLog /var/log/apache2/"$NAME.local_access.log combined | sudo tee -a $APACHE/$NAME.conf
echo "</VirtualHost>" | sudo tee -a $APACHE/$NAME.conf

echo Activating site...
sudo a2ensite $NAME.conf
echo Done.

echo Restarting apache2...
sudo service apache2 restart
echo Done.

# Add hosts entry.
echo Adding vhost entry to hosts file...
echo 127.0.0.1"       "$NAME.dev | sudo tee -a /etc/hosts
echo Done.

# Initial git commit.
git init
git add .
git commit -m "Initial commit."
git branch -m master stage
git branch qa
git branch prod

echo Visit the new site @ http://$NAME.dev
echo Username: admin
echo Password: $PASS

# Change settings.php permissions 
chmod 444 sites/default/settings.php

exit 0
