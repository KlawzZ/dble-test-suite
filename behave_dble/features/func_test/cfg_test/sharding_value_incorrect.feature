# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.
# Created by lizizi at 2020/7/3
Feature: config sharding config files incorrect and restart dble or reload configs




  @NORMAL @restore_mysql_config
  Scenario: config sharding property, reload the configs #5
   """
   {'restore_mysql_config':{'mysql-master1':{'lower_case_table_names':0},'mysql-master2':{'lower_case_table_names':0}}}
   """
    Given restart mysql in "mysql-master1" with sed cmds to update mysql config
    """
     /lower_case_table_names/d
     /server-id/a lower_case_table_names = 1
     """
    Given restart mysql in "mysql-master2" with sed cmds to update mysql config
    """
     /lower_case_table_names/d
     /server-id/a lower_case_table_names = 1
     """
    Given add xml segment to node with attribute "{'tag':'schema'}" in "sharding.xml"
    """
      <singleTable name="Tb_Single" shardingNode="dn5" sqlMaxLimit="105"/>
    """
    Given Restart dble in "dble-1" success
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                | expect                   | db      |
      | conn_0 | False   | drop table if exists Tb_Single                     | success                  | schema1 |
      | conn_0 | False   | create table Tb_Single(id int,name char(20))       | success                  | schema1 |
      | conn_0 | False   | insert into tb_single(id) value(1)                 | success                  | schema1 |
      | conn_0 | False   | select id from TB_Single                           | success                  | schema1 |
      | conn_0 | False   | select tb_single.id from Tb_Single                 | success                  | schema1 |
      | conn_0 | False   | select Tb_Single.id from tb_single                 | success                  | schema1 |
      | conn_0 | False   | select schema1.tb_single.id from schema1.Tb_Single | success                  | schema1 |
      | conn_0 | False   | select schema1.Tb_Single.id from schema1.tb_single | success                  | schema1 |
      | conn_0 | True    | select schema1.Tb_Single.id from schema1.Tb_Single | success                  | schema1 |


  Scenario: config sharding property, reload the configs #1
    Given update file content "/opt/dble/conf/sharding.xml" in "dble-1" with sed cmds
    """
      /<shardingNode dbGroup/d
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      shardingNode 'dn5' is not found!
    """


  Scenario: config sharding property, reload the configs #2
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
      <schema shardingNode="" name="schema1" sqlMaxLimit="100"/>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      sharding schema1 didn't config tables,so you must set shardingNode property
    """


  Scenario: config sharding property, reload the configs #3
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
      <shardingNode dbGroup="ha_group1" name="dn5"/>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      Attribute 'database' must appear on element 'shardingNode'
    """


  Scenario: config sharding property, reload the configs #4
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
      <shardingNode dbGroup="ha_group1" database="db3" name="" />
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      shardingNode  define error ,attribute can't be empty
    """


  Scenario: config sharding property, reload the configs #6
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
      <function class="Hash" name="hash-two-fake">
        <property name="partitionCount_fake">2</property>
        <property name="partitionLength_fake">1</property>
      </function>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      These properties of function [hash-two-fake] is not recognized: partitionLength_fake,partitionCount_fake
    """


  Scenario: shardingnode duplicate in one shardtable, reload the configs #7
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
     <schema shardingNode="dn5" name="schema1" sqlMaxLimit="100">
        <globalTable name="test" shardingNode="dn1,dn1,dn3,dn4" />
        <shardingTable name="sharding_4_t1" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
     </schema>
    """
    Then execute admin cmd "reload @@config" get the following output
      """
      invalid shardingNode config: dn1,dn1,dn3,dn4 for GlobalTableConfig test,the nodes duplicated!
      """
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
     <schema shardingNode="dn5" name="schema1" sqlMaxLimit="100">
        <shardingTable name="sharding_2_t1" shardingNode="dn1,dn2" function="hash-two" shardingColumn="id" />
        <shardingTable name="sharding_4_t1" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
     </schema>
     <schema shardingNode="dn5" name="schema2">
        <shardingTable name="sharding_2_t2" shardingNode="dn1,dn2" function="hash-two" shardingColumn="id" />
        <shardingTable name="sharding_4_t2" shardingNode="dn1,dn2,dn3,dn3" function="hash-four" shardingColumn="id"/>
     </schema>
    """
    Then execute admin cmd "reload @@config" get the following output
      """
      invalid shardingNode config: dn1,dn2,dn3,dn3 for ShardingTableConfig sharding_4_t2 ,the nodes duplicated
      """