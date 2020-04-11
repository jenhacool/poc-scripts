#!/bin/bash

# poc new domain username email id
if [ $1 = 'new' ]; then
	# Create Wordpress site
	sudo site $2 -wp

	# Set defaul site
	sudo webinoly -default-site=$2

	# Turn of HTTP Auth for wp-admin
	sudo httpauth $2 -wp-admin=off

	# Move config file
	sudo mv /var/www/$2/wp-config.php /var/www/$2/htdocs

	# Generate random password
	admin_password=$(pwgen -s -1 16)

	# Install Wordpress
	sudo wp core install --url=$2 --title=POC --admin_user=$3 --admin_password=$admin_password --admin_email=$4 --path=/var/www/$2/htdocs --allow-root

	# Add config
	sudo wp config set POC_SERVER "${5}" --path=/var/www/$2/htdocs --allow-root

	# Multisite convert
	sudo wp core multisite-convert --path=/var/www/$2/htdocs --subdomains --allow-root

	# Send login information
	curl -X GET "https://client.hostletter.com/poc.php?server_id=${5}&username=${3}&password=${admin_password}"

	# Callback
	curl -X GET "https://api.hostletter.com/api/server/${5}/complete"
# poc changedomain old_domain new_domain email id
else
	sudo cp /var/www/$2/htdocs/wp-config.php /var/www/$2

	# Create new site by cloning old site
	sudo site $3 -clone-from=$2

	sudo rm /var/www/$3/htdocs/wp-config.php

	sudo mv /var/www/$3/wp-config.php /var/www/$3/htdocs

	# Set defaul site
	sudo webinoly -default-site=$3

	# Turn of HTTP Auth for wp-admin
	sudo httpauth $3 -wp-admin=off

	# Delete old site
	for i in $(wp site list --path=/var/www/$2/htdocs --field=domain --allow-root); do
	    if [[ -f /etc/nginx/sites-available/$i ]]
		then
			echo 'Y' | sudo site $i -delete -revoke=on
		fi
	done

	# Search and replace in database
	sudo wp search-replace "$2" "$3" --path=/var/www/$3/htdocs --allow-root --network

	# Edit config
	sudo wp config set DOMAIN_CURRENT_SITE "${3}" --path=/var/www/$3/htdocs --allow-root

	# SSL
	echo $4 | sudo site $3 -ssl=on

	# SSL for network sites
	for i in $(wp site list --path=/var/www/$3/htdocs --field=domain --allow-root); do
	    if [[ ! -f /etc/nginx/sites-available/$i ]]
		then
			site $i -parked=$3
			IFS='.' read -r -a array <<< $i
			sudo sed -i "s/${array[0]}.${array[0]}/${array[0]}/g" /etc/nginx/sites-available/$i && systemctl restart nginx
			echo $4 | site $i -ssl=on -root=$1
		fi
	done

	# Remove old crontab job
	crontab -l | grep -v "sudo poc_cron ${2} ${4}" | crontab -

	# Callback
	curl -X GET "https://api.hostletter.com/api/server/${5}/complete"

	# Add new crontab job for new domain
	(crontab -u ubuntu -l; echo "* * * * * sudo poc_cron ${3} ${4}") | crontab -u ubuntu -
fi	