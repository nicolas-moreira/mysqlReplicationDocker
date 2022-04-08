#!/bin/bash

docker-compose down
rm -rf ./master/data/*
rm -rf ./slave/data/*
rm -rf ./slave2/data/*
docker-compose build
docker-compose up -d

# import db
importDb() {
    echo " "
    echo " "
    echo "------------------------ Importing sql files for $@ ------------------------"
    echo " "
    echo "Importing tables"
    for eachFile in $( ls ./structure/*_tables.sql ); 
        do
            echo " "
            echo "Importing $eachFile to database"
            docker exec $@ sh -c "export MYSQL_PWD=111; mysql -u root -e '$(< $eachFile)'"
            echo "Done importing with $eachFile"
        done
    echo " "
  
  echo "Populating tables"
    for eachFile in $( ls ./populate/*_populate.sql ); 
        do
            echo " "
            echo "Populating database with $eachFile "
            docker exec $@ sh -c "export MYSQL_PWD=111; mysql -u root -e '$(< $eachFile)'"
            echo "Done populating with $eachFile"
        done
    echo " "

}

docker-ip() {
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"
}

init_replication() {
  echo "------------------------ Waiting for mysql servers ------------------------"

  echo " "
  echo "------------------------ mysql_master ------------------------"


  until docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null;
  do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
  done
  echo "mysql_master is up"

  echo " "
  echo "------------------------ Server mysql_slave ------------------------"

  until docker exec mysql_slave sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null;
  do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
  done 
  echo "mysql_slave is up"

  echo " "
  echo "------------------------ Server mysql_slave2 ------------------------"

  until docker exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"' 2>/dev/null;
  do
    echo "MySQL is unavailable - waiting for it..."
    sleep 4
  done
  echo "mysql_slave2 is up"

  echo " "
  echo "--------------------- Servers are ready -----------------------"


  # import sql files to servers
  importDb mysql_master
  importDb mysql_slave
  importDb mysql_slave2

  # Grant replication for user
  priv_stmt='GRANT REPLICATION SLAVE ON *.* TO "mydb_slave_user"@"%" IDENTIFIED BY "mydb_slave_pwd"; FLUSH PRIVILEGES;'
  docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"

  # get master current log and pos for slaves
  MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
  CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
  CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

  # setup replication for slaves
  start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
  start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
  start_slave_cmd+="$start_slave_stmt"
  start_slave_cmd+='"'

  # run replication setting query in servers
  docker exec mysql_slave sh -c "$start_slave_cmd"
  docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"

  docker exec mysql_slave2 sh -c "$start_slave_cmd"
  docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"
}
# start the script
init_replication