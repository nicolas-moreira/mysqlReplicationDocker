#!/bin/bash

docker-compose rm -s -v -f mysql_master
rm -rf ./master/data/*
docker-compose build --no-cache mysql_master
docker-compose up -d mysql_master

until docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null; do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
done
echo "mysql_master is up"
