-- MySQL dump 10.13  Distrib 5.7.13, for linux-glibc2.5 (x86_64)
--
-- Host: 127.0.0.1    Database: testdb
-- ------------------------------------------------------
-- Server version	5.7.13-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Position to start replication or point-in-time recovery from
--

-- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000017', MASTER_LOG_POS=194;

--
-- Current Database: `testdb`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `testdb` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `testdb`;

--
-- Table structure for table `bigColumnValue_table`
--

DROP TABLE IF EXISTS `bigColumnValue_table`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bigColumnValue_table` (
  `id` int(11) NOT NULL,
  `name` mediumblob,
  `ageQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ` int(11) DEFAULT '101',
  `age2qqqqqqqqqqqqqqqqq` int(11) DEFAULT '102',
  `age3wwwwwwwwwwww` int(11) DEFAULT '103',
  `age4ffffffffff` int(11) DEFAULT '104',
  `age5kkkkkkk` int(11) DEFAULT '105',
  `age6ooooooooooooooooooooooooooooooooooooooooooo` int(11) DEFAULT '106',
  PRIMARY KEY (`id`),
  KEY `id` (`age5kkkkkkk`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bigColumnValue_table`
--

LOCK TABLES `bigColumnValue_table` WRITE;
/*!40000 ALTER TABLE `bigColumnValue_table` DISABLE KEYS */;
/*!40000 ALTER TABLE `bigColumnValue_table` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sharding_2_t1`
--

DROP TABLE IF EXISTS `sharding_2_t1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sharding_2_t1` (
  `id` int(11) DEFAULT NULL,
  `name` varchar(30) DEFAULT NULL,
  `age` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sharding_2_t1`
--

LOCK TABLES `sharding_2_t1` WRITE;
/*!40000 ALTER TABLE `sharding_2_t1` DISABLE KEYS */;
INSERT INTO `sharding_2_t1` VALUES (1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(5,'5',5);
/*!40000 ALTER TABLE `sharding_2_t1` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2021-12-16 15:10:34
