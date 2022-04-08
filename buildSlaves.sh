#!/bin/bash

docker-compose rm -s -v -f mysql_slave mysql_slave2
rm -rf ./slave/data/*
rm -rf ./slave2/data/*
docker-compose build --no-cache mysql_slave mysql_slave2
docker-compose up -d mysql_slave mysql_slave2

until docker exec mysql_slave sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null; do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
done
echo "mysql_slave is up"

until docker exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null; do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
done
echo "mysql_slave is up"
