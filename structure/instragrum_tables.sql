USE mydb;
DROP TABLE IF EXISTS `user`;  
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
UNLOCK TABLES;
