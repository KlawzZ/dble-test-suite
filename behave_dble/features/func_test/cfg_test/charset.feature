# -*- coding=utf-8 -*-
# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.
# Created by zhaohongjie at 2018/10/8
Feature: set charset in server.xml,check backend charsets are as set
  backend charsets info get via "show @@backend", resultset of column: CHARACTER_SET_CLIENT, COLLATION_CONNECTION,CHARACTER_SET_RESULTS
  front connection charset is not controlled by server.xml property charset,
  but verify the default value here for convenient.

  @BLOCKER
  Scenario: set dble config charset same or different to session charset, session charset priorier to config charset #1
    #   1.1 set backend charset utf8mb4, front charset utf8mb4;
    Given update file content "/opt/dble/conf/bootstrap.cnf" in "dble-1" with sed cmds
    """
    $a\-Dcharset=utf8mb4
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
    <dbGroup rwSplitMode="1" name="ha_group2" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM2" password="111111" url="172.100.9.6:3307" user="test" maxCon="100" minCon="10" primary="true">
        </dbInstance>
        <dbInstance name="hosts1" password="111111" url="172.100.9.2:3307" user="test" maxCon="100" minCon="10" primary="false">
        </dbInstance>
        <dbInstance name="hosts2" password="111111" url="172.100.9.3:3307" user="test" maxCon="100" minCon="10" primary="false">
        </dbInstance>
    </dbGroup>
    """
    Given Restart dble in "dble-1" success
    Given execute single sql in "dble-1" in "admin" mode and save resultset in "backend_rs_A"
      | sql            |
      | show @@backend |
    Then check resultset "backend_rs_A" has lines with following column values
      | HOST-3      | CHARACTER_SET_CLIENT-13 | COLLATION_CONNECTION-14 | CHARACTER_SET_RESULTS-15 |
      | 172.100.9.6 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
      | 172.100.9.2 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
      | 172.100.9.3 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                         | expect  | db     |charset|
      | conn_0 | False   | drop table if exists aly_test               | success | schema1 | utf8  |
      | conn_0 | False   | create table aly_test(id int, name char(10)) default charset=utf8| success | schema1 | utf8  |
      | conn_0 | False   | insert into aly_test value(1, '中')         | success | schema1 | utf8  |
      | conn_0 | False   | select name from aly_test                   | has{('中')}| schema1 | utf8  |
      | conn_0 | False   | set names utf8mb4                              | success | schema1 | utf8  |
    Given execute single sql in "dble-1" in "admin" mode and save resultset in "conn_rs_A"
      | sql               |
      | show @@connection |
    Then check resultset "conn_rs_A" has lines with following column values
      | CHARACTER_SET_CLIENT-7 | COLLATION_CONNECTION-8 | CHARACTER_SET_RESULTS-9 |
      |    utf8mb4                | utf8mb4_general_ci        | utf8mb4                    |
    #   1.2 set backend charset latin1, front charset default latin1;
    Given update file content "/opt/dble/conf/bootstrap.cnf" in "dble-1" with sed cmds
    """
    $a\-Dcharset=latin1
    """
    Given Restart dble in "dble-1" success
    Given execute single sql in "dble-1" in "admin" mode and save resultset in "backend_rs_B"
      | sql            |
      | show @@backend |
    Then check resultset "backend_rs_B" has not lines with following column values
      | HOST-3      | CHARACTER_SET_CLIENT-13 | COLLATION_CONNECTION-14 | CHARACTER_SET_RESULTS-15 |
      | 172.100.9.6 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
      | 172.100.9.2 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
      | 172.100.9.3 |     utf8mb4                | utf8mb4_general_ci         | utf8mb4                     |
    Then check resultset "backend_rs_B" has lines with following column values
      | HOST-3      | CHARACTER_SET_CLIENT-13 | COLLATION_CONNECTION-14 | CHARACTER_SET_RESULTS-15 |
      | 172.100.9.6 |     latin1              | latin1_swedish_ci       | latin1                   |
      | 172.100.9.2 |     latin1              | latin1_swedish_ci       | latin1                   |
      | 172.100.9.3 |     latin1              | latin1_swedish_ci       | latin1                   |
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                         | expect  | db     |
      | conn_1 | False   | drop table if exists aly_test               | success | schema1 |
      | conn_1 | False   | create table aly_test(id int, name char(10)) default charset=utf8mb4| success | schema1 |
      | conn_1 | False   | insert into aly_test value(1, '中')         | ordinal not in range | schema1 |
    Given execute single sql in "dble-1" in "admin" mode and save resultset in "conn_rs_B"
      | sql               |
      | show @@connection |
    Then check resultset "conn_rs_B" has lines with following column values
      | CHARACTER_SET_CLIENT-7 | COLLATION_CONNECTION-8 | CHARACTER_SET_RESULTS-9 |
      |    latin1              | latin1_swedish_ci      | latin1                  |
    #   1.3 set backend charset latin1, but set front charset utf8 to indirectly change used backend charset;
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                 | expect  | db     |charset|
      | conn_2 | False   | insert into aly_test value(1, '中') | success | schema1 |utf8  |
      | conn_2 | False   | select name from aly_test           | has{('中')} | schema1 |utf8  |
      | conn_2 | True    | drop table if exists aly_test       | success | schema1 |utf8  |

  @current
  Scenario: dble should map MySQL's utfmb4 character to utf8.
             In other words,non-ASCII sharding column should be routed to the same shardingNode whether client character-set is utfmb4 or utf8 #2
     Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
     """
       <schema shardingNode="dn1" name="schema1" sqlMaxLimit="100">
            <shardingTable name="sharding_table" shardingNode="dn1,dn2" function="hash-string-into-two" shardingColumn="id" />
       </schema>
    """
    Given update file content "/opt/dble/conf/bootstrap.cnf" in "dble-1" with sed cmds
    """
    $a\-Dcharset=utf8mb4
    """
    Given Restart dble in "dble-1" success
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                               | expect  | db      |charset|
      | conn_0 | False   | drop table if exists sharding_table                               | success | schema1 |utf8   |
      | conn_0 | False   | create table sharding_table(id varchar(50))default charset=utf8;  | success | schema1 |utf8   |
      | conn_0 | True    | insert into sharding_table(id) values('京A00000')                 | dest_node:mysql-master2  | schema1  |utf8    |
      | new    | True    | insert into sharding_table(id) values('京A00000')                 | dest_node:mysql-master2  | schema1  |utf8mb4 |