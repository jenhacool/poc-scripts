#!/bin/bash

for i in $(wp site list --path=/var/www/$1/htdocs --field=domain --allow-root); do
    if [[ ! -f /etc/nginx/sites-available/$i ]]
	then
		site $i -parked=$1
		IFS='.' read -r -a array <<< $i
		sudo sed -i "s/${array[0]}.${array[0]}/${array[0]}/g" /etc/nginx/sites-available/$i && systemctl restart nginx
		echo $2 | site $i -ssl=on -root=$1
	fi
done