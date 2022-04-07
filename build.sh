#!/bin/bash

# Shutdown les containers, effacer les anciennes donnes de fichiers data, build le fichier compose et lancer les containers
docker-compose down 
rm -rf ./master/data/*
rm -rf ./slave/data/*
rm -rf ./slave2/data/*
docker-compose build
docker-compose up -d

# Attendre que l'instance docker mysql_master se lance
until docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql_master database connection..."
    sleep 4
done

tables='USE mydb;DROP TABLE IF EXISTS `user`;  
CREATE TABLE `user` (
  `id_user` int NOT NULL AUTO_INCREMENT,
  `pseudo` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id_user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
DROP TABLE IF EXISTS `post`;
CREATE TABLE `post` (
  `id_post` int NOT NULL AUTO_INCREMENT,
  `contenu` text,
  `user_id` int DEFAULT NULL,
  PRIMARY KEY (`id_post`),
  KEY `user_ind` (`user_id`),
  CONSTRAINT `post_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id_user`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
LOCK TABLES `post` WRITE;
UNLOCK TABLES;'

#population 

populate='USE mydb;INSERT INTO user (pseudo) VALUES ("nicolas");
INSERT INTO post (contenu, user_id) VALUES ("test", 1);'

# Creation des tables
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$tables'"
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$populate'"


# Population



# priv_stmt query sql
# Créé un utilisateur mysql pour les slaves, il donne acces a la replication a cette utilisateur.
priv_stmt='GRANT REPLICATION SLAVE ON *.* TO "mydb_slave_user"@"%" IDENTIFIED BY "mydb_slave_pwd"; FLUSH PRIVILEGES;'
# execution de la query priv_stmt
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"



## slave 1
# Attendre que l'instance docker mysql_master se lance
until docker-compose exec mysql_slave sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql_slave database connection..."
    sleep 4
done

docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e '$tables'"
docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e '$populate'"


# fonction pour recuperer l'ip d'un container precis.
# $(docker-ip mysql_master) > ip de mysql_master container.
# Pour voir les containers cli > docker container ls
docker-ip() {
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"
}

#On chope current log et current pos du master
MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

# On bind notre slave au master
start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
docker exec mysql_slave sh -c "$start_slave_cmd"

# montrer le status du slave1
docker exec mysql_slave sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"


#On chope current log et current pos du master
MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`


#slave 2
priv_stmt2='GRANT REPLICATION SLAVE ON *.* TO "mydb_slave2_user"@"%" IDENTIFIED BY "mydb_slave_pwd"; FLUSH PRIVILEGES;'
# execution de la query priv_stmt
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt2'"

# slave 2
until docker-compose exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql_slave2 database connection..."
    sleep 4
done


docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e '$tables'"
docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e '$populate'"

# On bind notre slave au master
start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='mydb_slave2_user',MASTER_PASSWORD='mydb_slave_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
docker exec mysql_slave2 sh -c "$start_slave_cmd"

# montrer le status du slave
docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"