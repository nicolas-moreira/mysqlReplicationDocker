#!/bin/bash

docker-compose down 
rm -rf ./master/data/*
rm -rf ./slave/data/*
rm -rf ./slave2/data/*
docker-compose build
docker-compose up -d

tables() {
    echo "----------Getting _table.sql files------------"
    for eachFile in $( ls ./structure/*_tables.sql ); 
        do
            echo "Adding " $eachFile " to database"
            docker exec $@ sh -c "export MYSQL_PWD=111; mysql -u root -e '$(< $eachFile)'"
            echo "Done with " $eachFile
        done
    echo "----------Done with structure files------------"
}

populate() {
    echo "----------Getting _populate.sql files------------"
    for eachFile in $( ls ./populate/*_populate.sql ); 
        do
            echo "Population with " $eachFile " file"
            docker exec $@ sh -c "export MYSQL_PWD=111; mysql -u root -e '$(< $eachFile)'"
            echo "Done with " $eachFile
        done
    echo "----------Done populating tables------------"
}

docker-ip() {
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"
}

mysql_master() {

    until docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
    do
        echo "Waiting for mysql_master database connection..."
        sleep 4
    done
    sleep 3
    tables mysql_master
    populate mysql_master

    priv_stmt='GRANT REPLICATION SLAVE ON *.* TO "mydb_slave_user"@"%" IDENTIFIED BY "mydb_slave_pwd"; FLUSH PRIVILEGES;'
    docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"
}

mysql_slave() {
    until docker-compose exec mysql_slave sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
    do
        echo "Waiting for mysql_slave database connection..."
        sleep 4
    done

    tables mysql_slave
    populate mysql_slave

    MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
    CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
    CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

    start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
    start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
    start_slave_cmd+="$start_slave_stmt"
    start_slave_cmd+='"'
    docker exec mysql_slave sh -c "$start_slave_cmd"

    docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"
}

mysql_slave2() {

    MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
    CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
    CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

    until docker-compose exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
    do
        echo "Waiting for mysql_slave2 database connection..."
        sleep 4
    done

    tables mysql_slave2
    populate mysql_slave2

    start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
    start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
    start_slave_cmd+="$start_slave_stmt"
    start_slave_cmd+='"'
    docker exec mysql_slave2 sh -c "$start_slave_cmd"

    docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"
}

mysql_master
mysql_slave
mysql_slave2
