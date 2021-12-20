# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.
# Created by wujinling at 2021/12/15

Feature: test split: split src dest [-sschema] [-r500] [-w500] [-l10000] [-ignore]
  @CRITICAL
  Scenario: database name in dump file is testdb which is not in config. from DBLE0REQ-1448 #1
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                        |expect   | db      |
      | conn_0 | False    | drop table if exists bigColumnValue_table  |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_2_t1         |success  | schema1 |
    Given upload file "./assets/split_testdb.sql" to "dble-1" success
    #1.split with no '-s' parameter, split return error and will not split out files
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_testdb.sql-dn*.dump
    """
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                   | expect                                          |
      | split /opt/split_testdb.sql /opt                      | hasStr{schema[testdb] doesn't exist in config}  |
    Then check path "/opt/split_testdb.sql-dn*.dump" in "dble-1" should not exist
    #2.split with '-s' parameter and the schema4 does not exist in dble config, split return error and will not split out files
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                                  | expect                                                   |
      | split /opt/noschema_only_table_data.sql /opt -sschema4               | Default schema[schema4] doesn't exist in config          |
    Then check path "/opt/split_testdb.sql-dn*.dump" in "dble-1" should not exist
    #3.split with '-s' parameter and the schema1 exists in dble config, split success
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                                  | expect     |
      | split /opt/split_testdb.sql /opt -sschema1                           | success    |
    Then check path "/opt/split_testdb.sql-dn1-*.dump" in "dble-1" should exist
    Then check path "/opt/split_testdb.sql-dn2-*.dump" in "dble-1" should exist
    Then check path "/opt/split_testdb.sql-dn3-*.dump" in "dble-1" should exist
    Then check path "/opt/split_testdb.sql-dn4-*.dump" in "dble-1" should exist
    Then check path "/opt/split_testdb.sql-dn5-*.dump" in "dble-1" should exist
    #upload data into every nodes and check data is correct in dble
    Given execute oscmd in "dble-1"
     """
      mv /opt/split_testdb.sql-dn1-*.dump /opt/split_testdb.sql-dn1.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 -Ddb1< /opt/split_testdb.sql-dn1.dump && \
      mv /opt/split_testdb.sql-dn3-*.dump /opt/split_testdb.sql-dn3.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 -Ddb2 < /opt/split_testdb.sql-dn3.dump && \
      mv /opt/split_testdb.sql-dn5-*.dump /opt/split_testdb.sql-dn5.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 -Ddb3< /opt/split_testdb.sql-dn5.dump && \
      mv /opt/split_testdb.sql-dn2-*.dump /opt/split_testdb.sql-dn2.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 -Ddb1< /opt/split_testdb.sql-dn2.dump && \
      mv /opt/split_testdb.sql-dn4-*.dump /opt/split_testdb.sql-dn4.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 -Ddb2< /opt/split_testdb.sql-dn4.dump
     """
    Then execute admin cmd "reload @@metadata"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                                                                        | expect                                      |db          |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/select id from bigColumnValue_table                              | Table 'db1.bigColumnValue_table' doesn't exist | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/select id from bigColumnValue_table                              | Table 'db1.bigColumnValue_table' doesn't exist | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/select id from bigColumnValue_table                              | Table 'db2.bigColumnValue_table' doesn't exist | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/select id from bigColumnValue_table                              | Table 'db2.bigColumnValue_table' doesn't exist | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/select id from bigColumnValue_table                              | length{(0)}                                 | schema1    |
      | conn_0 | False    | select * from bigColumnValue_table                                                         | length{(0)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/select * from sharding_2_t1                                      | has{(2,'2',2),(4,'4',4)}                    | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/select * from sharding_2_t1                                      | has{(1,'1',1),(3,'3',3),(5,'5',5)}          | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/select * from sharding_2_t1                                      | Table 'db2.sharding_2_t1' doesn't exist     | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/select * from sharding_2_t1                                      | Table 'db2.sharding_2_t1' doesn't exist     | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/select * from sharding_2_t1                                      | Table 'db3.sharding_2_t1' doesn't exist     | schema1     |
      | conn_0 | False    | select * from sharding_2_t1                                                                | length{(5)}                                 | schema1     |
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_testdb.sql*.dump
    """

  @CRITICAL @btrace
  Scenario: split command will affected by idleTimeout parameter. After execute split command, the other manager command will affected by idleTimeout. from DBLE0REQ-1510 #2
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"
    Given update file content "/opt/dble/conf/cluster.cnf" in "dble-1" with sed cmds
    """
    $a\idleTimeout=10000
    """
    Then Restart dble in "dble-1" success
    Given upload file "./assets/split_testdb.sql" to "dble-1" success
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_testdb.sql-dn*.dump
    """
   Given update file content "./assets/BtraceGetReadQueueSizeOfPoll.java" in "behave" with sed cmds
    """
    s/Thread.sleep([0-9]*L)/Thread.sleep(10L)/
    /getReadQueueSizeOfPoll/{:a;n;s/Thread.sleep([0-9]*L)/Thread.sleep(5000L)/;/\}/!ba}
    """
    Given prepare a thread run btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"

    Given sleep "5" seconds
    Then execute admin cmd  in "dble-1" at background
      | conn   | toClose | sql                                           | db               |
      | conn_0| True    | split /opt/split_testdb.sql /opt -sschema1;   | dble_information |
    Then check following text exist "N" in file "/tmp/dble_admin_query.log" in host "dble-1"
      """
      ERROR
      """
    Given stop btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"

    Given update file content "./assets/BtraceGetReadQueueSizeOfPoll.java" in "behave" with sed cmds
    """
    s/Thread.sleep([0-9]*L)/Thread.sleep(10L)/
    /startReload/{:a;n;s/Thread.sleep([0-9]*L)/Thread.sleep(10000L)/;/\}/!ba}
    """
    Given prepare a thread run btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Then execute admin cmd  in "dble-1" at background
      | conn   | toClose | sql               | db               |
      | conn_0 | True    | reload @@config   | dble_information |
    Then check btrace "BtraceGetReadQueueSizeOfPoll.java" output in "dble-1"
    """
    befroe startReload
    """
    Then check following text exist "Y" in file "/tmp/dble_admin_query.log" in host "dble-1"
      """
      Lost connection to MySQL server during query
      """
    Given stop btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"


  @CRITICAL @btrace
  Scenario: abort while executing split command #3
    Given upload file "./assets/split_testdb.sql" to "dble-1" success
    #1. abort with kill @@connection id
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_testdb.sql-dn*.dump
    """
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"
    Given update file content "./assets/BtraceGetReadQueueSizeOfPoll.java" in "behave" with sed cmds
    """
    s/Thread.sleep([0-9]*L)/Thread.sleep(10L)/
    /getReadQueueSizeOfPoll/{:a;n;s/Thread.sleep([0-9]*L)/Thread.sleep(5000L)/;/\}/!ba}
    """
    Given prepare a thread run btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Then execute admin cmd  in "dble-1" at background
      | conn   | toClose | sql                                         | db               |
      | conn_0 | True    | split /opt/split_testdb.sql /opt -sschema1  | dble_information |
    Then get index:"0" column value of "select * from dble_information.session_connections" named as "id_A"
    Then kill dble front connection "id_A" in "dble-1" with manager command
    Then check following text exist "Y" in file "/tmp/dble_admin_query.log" in host "dble-1"
      """
      Lost connection to MySQL server during query
      """
    Then check path "/opt/split_testdb.sql-dn*.dump" in "dble-1" should not exist
    Given stop btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"

    #2.abort with kill -9
    Given update file content "./assets/BtraceGetReadQueueSizeOfPoll.java" in "behave" with sed cmds
    """
    s/Thread.sleep([0-9]*L)/Thread.sleep(10L)/
    /getReadQueueSizeOfPoll/{:a;n;s/Thread.sleep([0-9]*L)/Thread.sleep(5000L)/;/\}/!ba}
    """
    Given prepare a thread run btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Then execute admin cmd  in "dble-1" at background
      | conn   | toClose | sql                                         | db               |
      | conn_0 | True    | split /opt/split_testdb.sql /opt -sschema1  | dble_information |
    Then get index:"0" column value of "select * from dble_information.session_connections" named as "id_A"
    Then kill dble front connection "id_A" in "dble-1" with manager command
    Then check following text exist "Y" in file "/tmp/dble_admin_query.log" in host "dble-1"
      """
      Lost connection to MySQL server during query
      """
    Then check path "/opt/split_testdb.sql-dn*.dump" in "dble-1" should not exist
    Given stop btrace script "BtraceGetReadQueueSizeOfPoll.java" in "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java" on "dble-1"
    Given delete file "/opt/dble/BtraceGetReadQueueSizeOfPoll.java.log" on "dble-1"


  @CRITICAL
  Scenario: dump file have table structure and have no data  #4
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
    <schema shardingNode="dn5" name="schema1" sqlMaxLimit="100">
          <globalTable name="test" shardingNode="dn1,dn2,dn3,dn4" />
          <singleTable name="sharding_1_t1" shardingNode="dn1" />
          <shardingTable name="sharding_2_t1" shardingNode="dn1,dn2" function="hash-two" shardingColumn="id" />
          <shardingTable name="sharding_3_t1" shardingNode="dn1,dn2,dn4" function="hash-three" shardingColumn="id" />

		  <shardingTable name="sharding_4_t1" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
		  <shardingTable name="foreign_table" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id_key"/>

		  <shardingTable name="sharding_5_t1" shardingNode="dn1,dn2,dn3,dn4,dn5" function="hashLong-five" shardingColumn="id">
		    <childTable name="tb_child" joinColumn="child_id" parentColumn="id" sqlMaxLimit="201">
                <childTable name="tb_grandson" joinColumn="grandson_id" parentColumn="child_id"/>
            </childTable>
		  </shardingTable>

          <shardingTable name="string_hash_table" shardingNode="dn1,dn2,dn3,dn4,dn6" function="hashSting" shardingColumn="name"/>
          <shardingTable name="enum_table" shardingNode="dn1,dn2,dn3" function="enum" shardingColumn="id"/>
		  <shardingTable name="enum_string_table" shardingNode="dn4,dn5,dn6" function="enum-string" shardingColumn="name"/>
		  <shardingTable name="numberrange_table" shardingNode="dn$1-10" function="rangeLong" shardingColumn="id"/>
		  <shardingTable name="patternrange_table" shardingNode="dn1,dn2,dn3,dn4" function="pattern" shardingColumn="id"/>
		  <shardingTable name="date_table" shardingNode="dn1,dn2,dn3" function="partbydate" shardingColumn="id"/>
		  <shardingTable name="jump_string_hash_table" shardingNode="dn1,dn2,dn3,dn4,dn6" function="jumphash" shardingColumn="name"/>
		  <shardingTable name="global_sequence" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id" incrementColumn="id"/>
		  <shardingTable name="bigColumnValue_table" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id" />

    </schema>

    <schema name="schema2" shardingNode="dn5" sqlMaxLimit="100">
          <globalTable name="test1" shardingNode="dn1,dn2,dn3,dn4" />
          <shardingTable name="sharding_2_t1" shardingNode="dn3,dn4" function="hash-two" shardingColumn="id" />
          <shardingTable name="sharding_4_t3" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
    </schema>

    <schema name="schema3" shardingNode="dn6" sqlMaxLimit="100">
    </schema>

    <shardingNode dbGroup="ha_group1" database="db1" name="dn1" />
    <shardingNode dbGroup="ha_group2" database="db1" name="dn2" />
    <shardingNode dbGroup="ha_group1" database="db2" name="dn3" />
    <shardingNode dbGroup="ha_group2" database="db2" name="dn4" />
    <shardingNode dbGroup="ha_group1" database="db3" name="dn5" />
    <shardingNode dbGroup="ha_group2" database="db3" name="dn6" />
    <shardingNode dbGroup="ha_group3" database="db1" name="dn7" />
    <shardingNode dbGroup="ha_group3" database="db2" name="dn8" />
    <shardingNode dbGroup="ha_group3" database="db3" name="dn9" />
    <shardingNode dbGroup="ha_group3" database="db4" name="dn10" />

    <function class="Hash" name="hash-two">
        <property name="partitionCount">2</property>
        <property name="partitionLength">1</property>
    </function>
    <function class="Hash" name="hash-three">
        <property name="partitionCount">3</property>
        <property name="partitionLength">1</property>
    </function>
    <function class="Hash" name="hash-four">
        <property name="partitionCount">4</property>
        <property name="partitionLength">1</property>
    </function>

    <function class="Hash" name="hashLong-five" >
        <property name="partitionCount">2,3</property>
        <property name="partitionLength">100,50</property>
    </function>

    <function name="hashSting" class="stringhash">
       <property name="partitionCount">2,3</property>
       <property name="partitionLength">100,50</property>
       <property name="hashSlice">1:3</property>
    </function>

    <function name="enum" class="enum">
       <property name="mapFile">enum.txt</property>
       <property name="defaultNode">-1</property>
       <property name="type">0</property>
    </function>

    <function name="enum-string" class="enum">
       <property name="mapFile">enum-string.txt</property>
       <property name="defaultNode">1</property>
       <property name="type">-1</property>
    </function>

    <function name="rangeLong" class="numberrange">
       <property name="mapFile">numberrange.txt</property>
       <property name="defaultNode">4</property>
    </function>

    <function name="pattern" class="patternrange">
       <property name="mapFile">patternrange.txt</property>
       <property name="patternValue">1024</property>
       <property name="defaultNode">2</property>
    </function>

    <function name="partbydate" class="date">
       <property name="dateFormat">yyyy-MM-dd</property>
       <property name="sBeginDate">2021-10-01</property>
       <property name="sEndDate">2021-10-30</property>
       <property name="sPartionDay">10</property>
       <property name="defaultNode">0</property>
    </function>

    <function name="jumphash" class="jumpStringHash">
        <property name="partitionCount">2</property>
        <property name="hashSlice">0:2</property>
    </function>
    """
    When Add some data in "enum.txt"
    """
    1=0
    2=0
    3=0
    4=1
    5=1
    6=1
    7=2
    8=2
    9=2
    """
    When Add some data in "enum-string.txt"
    """
    a1=0
    b2=0
    c3=0
    d4=1
    e5=1
    f6=1
    g7=2
    h8=2
    i9=2
    """
    When Add some data in "numberrange.txt"
    """
    0-49=0
    50-99=1
    100-149=2
    150-199=3
    200-249=4
    250-299=5
    300-349=6
    350-399=7
    400-449=8
    450-499=9
    """
    When Add some data in "patternrange.txt"
    """
    0-255=0
    256-500=1
    501-755=2
    756-1000=3
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
      <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
          <heartbeat>select user()</heartbeat>
          <dbInstance name="hostM3" password="111111" url="172.100.9.4:3307" user="test" maxCon="1000" minCon="10" primary="true" />
      </dbGroup>
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "user.xml"
    """
      <shardingUser name="test" password="111111" schemas="schema1,schema2,schema3"/>
    """
    Then execute admin cmd "reload @@config_all"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                            |expect   | db      |
      | conn_0 | False    | drop table if exists test                   |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_1_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_2_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_3_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists foreign_table         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_4_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists view_s51              |success  | schema1 |
      | conn_0 | False    | drop view  if exists sharding_5_t1         |success  | schema1 |
      | conn_0 | False    | drop view  if exists tb_child              |success  | schema1 |
      | conn_0 | False    | drop view  if exists tb_grandson           |success  | schema1 |
      | conn_0 | False    | drop view  if exists string_hash_table      |success  | schema1 |
      | conn_0 | False    | drop view  if exists enum_table              |success  | schema1 |
      | conn_0 | False    | drop view  if exists enum_string_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists numberrange_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists patternrange_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists date_table              |success  | schema1 |
      | conn_0 | False    | drop view  if exists jump_string_hash_table  |success  | schema1 |
      | conn_0 | False    | drop table if exists global_sequence       |success  | schema1 |
      | conn_0 | False    | drop table if exists nosharding_1          |success  | schema1 |
      | conn_0 | True     | drop table if exists bigColumnValue_table   |success  | schema1 |
      | conn_0 | False    | drop table if exists test1                   |success  | schema2 |
      | conn_0 | False    | drop table if exists sharding_2_t1          |success  | schema2 |
      | conn_0 | True     | drop table if exists sharding_4_t3          |success  | schema2 |
      | conn_0 | False    | drop table if exists nosharding_2          |success  | schema2 |
      | conn_0 | False    | drop table if exists nosharding_3          |success  | schema3 |
      | conn_0 | True     | drop table if exists nosharding_4          |success  | schema3 |
    Given upload file "./assets/split_only_tables.sql" to "dble-1" success
    #1.split with '-s' parameter and the schema does not exist in dble config, split return error
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_only_tables.sql-dn*.dump
    """
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                                  | expect                                             |
      | split /opt/split_only_tables.sql /opt -sschema4                      | Default schema[schema4] doesn't exist in config    |
    Then check path "/opt/split_only_tables.sql-dn*.dump" in "dble-1" should not exist
    #2.split with no '-s' parameter, split success and the split out files will consistent with the original dump file
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                                  | expect                                                   |
      | split /opt/split_only_tables.sql /opt                                | success   |
    #check the split out files exist
    Then check path "/opt/split_only_tables.sql-dn1-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn2-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn3-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn4-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn5-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn6-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn7-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn8-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn9-*.dump" in "dble-1" should exist
    Then check path "/opt/split_only_tables.sql-dn10-*.dump" in "dble-1" should exist
    #upload data into every nodes and check data is correct in dble
    Given execute oscmd in "dble-1"
     """
      mv /opt/split_only_tables.sql-dn1-*.dump /opt/split_only_tables.sql-dn1.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn1.dump && \
      mv /opt/split_only_tables.sql-dn3-*.dump /opt/split_only_tables.sql-dn3.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn3.dump && \
      mv /opt/split_only_tables.sql-dn5-*.dump /opt/split_only_tables.sql-dn5.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn5.dump && \
      mv /opt/split_only_tables.sql-dn2-*.dump /opt/split_only_tables.sql-dn2.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn2.dump && \
      mv /opt/split_only_tables.sql-dn4-*.dump /opt/split_only_tables.sql-dn4.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn4.dump && \
      mv /opt/split_only_tables.sql-dn6-*.dump /opt/split_only_tables.sql-dn6.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn6.dump && \
      mv /opt/split_only_tables.sql-dn7-*.dump /opt/split_only_tables.sql-dn7.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn7.dump && \
      mv /opt/split_only_tables.sql-dn8-*.dump /opt/split_only_tables.sql-dn8.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn8.dump && \
      mv /opt/split_only_tables.sql-dn9-*.dump /opt/split_only_tables.sql-dn9.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn9.dump && \
      mv /opt/split_only_tables.sql-dn10-*.dump /opt/split_only_tables.sql-dn10.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_only_tables.sql-dn10.dump
     """
    Then execute admin cmd "reload @@metadata"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                                                           | expect                                       |db          |
      | conn_0 | True     | show tables                                                                   | length{(18)}                                 | schema1    |
      | conn_0 | True     | show tables                                                                   | length{(8)}                                  | schema2    |
      | conn_0 | True     | show tables                                                                   | length{(6)}                                  | schema3    |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ show tables                                        | length{(17)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ show tables                                        | length{(16)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ show tables                                        | length{(15)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ show tables                                        | length{(15)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ show tables                                        | length{(5)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ show tables                                        | length{(6)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn7*/ show tables                                        | length{(1)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn8*/ show tables                                        | length{(1)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn9*/ show tables                                        | length{(1)}                                 | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn10*/ show tables                                       | length{(1)}                                 | schema1    |
      | conn_0 | True     | desc global_sequence                                                          | hasStr{bigint}                              | schema1     |
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_only_tables.sql*.dump
    """

  @CRITICAL  @aa @skip_restart
  Scenario: test with all type of tables and functions with data in it #5
    Given add xml segment to node with attribute "{'tag':'root'}" in "sharding.xml"
    """
    <schema shardingNode="dn5" name="schema1" sqlMaxLimit="100">
          <globalTable name="test" shardingNode="dn1,dn2,dn3,dn4" />
          <singleTable name="sharding_1_t1" shardingNode="dn1" />
          <shardingTable name="sharding_2_t1" shardingNode="dn1,dn2" function="hash-two" shardingColumn="id" />
          <shardingTable name="sharding_3_t1" shardingNode="dn1,dn2,dn4" function="hash-three" shardingColumn="id" />

		  <shardingTable name="sharding_4_t1" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
		  <shardingTable name="foreign_table" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id_key"/>

		  <shardingTable name="sharding_5_t1" shardingNode="dn1,dn2,dn3,dn4,dn5" function="hashLong-five" shardingColumn="id">
		    <childTable name="tb_child" joinColumn="child_id" parentColumn="id" sqlMaxLimit="201">
                <childTable name="tb_grandson" joinColumn="grandson_id" parentColumn="child_id"/>
            </childTable>
		  </shardingTable>

          <shardingTable name="string_hash_table" shardingNode="dn1,dn2,dn3,dn4,dn6" function="hashSting" shardingColumn="name"/>
          <shardingTable name="enum_table" shardingNode="dn1,dn2,dn3" function="enum" shardingColumn="id"/>
		  <shardingTable name="enum_string_table" shardingNode="dn4,dn5,dn6" function="enum-string" shardingColumn="name"/>
		  <shardingTable name="numberrange_table" shardingNode="dn$1-10" function="rangeLong" shardingColumn="id"/>
		  <shardingTable name="patternrange_table" shardingNode="dn1,dn2,dn3,dn4" function="pattern" shardingColumn="id"/>
		  <shardingTable name="date_table" shardingNode="dn1,dn2,dn3" function="partbydate" shardingColumn="id"/>
		  <shardingTable name="jump_string_hash_table" shardingNode="dn1,dn2,dn3,dn4,dn6" function="jumphash" shardingColumn="name"/>
		  <shardingTable name="global_sequence" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id" incrementColumn="id"/>
		  <shardingTable name="bigColumnValue_table" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id" />

    </schema>

    <schema name="schema2" shardingNode="dn5" sqlMaxLimit="100">
          <globalTable name="test1" shardingNode="dn1,dn2,dn3,dn4" />
          <shardingTable name="sharding_2_t1" shardingNode="dn3,dn4" function="hash-two" shardingColumn="id" />
          <shardingTable name="sharding_4_t3" shardingNode="dn1,dn2,dn3,dn4" function="hash-four" shardingColumn="id"/>
    </schema>

    <schema name="schema3" shardingNode="dn6" sqlMaxLimit="100">
    </schema>

    <shardingNode dbGroup="ha_group1" database="db1" name="dn1" />
    <shardingNode dbGroup="ha_group2" database="db1" name="dn2" />
    <shardingNode dbGroup="ha_group1" database="db2" name="dn3" />
    <shardingNode dbGroup="ha_group2" database="db2" name="dn4" />
    <shardingNode dbGroup="ha_group1" database="db3" name="dn5" />
    <shardingNode dbGroup="ha_group2" database="db3" name="dn6" />
    <shardingNode dbGroup="ha_group3" database="db1" name="dn7" />
    <shardingNode dbGroup="ha_group3" database="db2" name="dn8" />
    <shardingNode dbGroup="ha_group3" database="db3" name="dn9" />
    <shardingNode dbGroup="ha_group3" database="db4" name="dn10" />

    <function class="Hash" name="hash-two">
        <property name="partitionCount">2</property>
        <property name="partitionLength">1</property>
    </function>
    <function class="Hash" name="hash-three">
        <property name="partitionCount">3</property>
        <property name="partitionLength">1</property>
    </function>
    <function class="Hash" name="hash-four">
        <property name="partitionCount">4</property>
        <property name="partitionLength">1</property>
    </function>

    <function class="Hash" name="hashLong-five" >
        <property name="partitionCount">2,3</property>
        <property name="partitionLength">100,50</property>
    </function>

    <function name="hashSting" class="stringhash">
       <property name="partitionCount">2,3</property>
       <property name="partitionLength">100,50</property>
       <property name="hashSlice">1:3</property>
    </function>

    <function name="enum" class="enum">
       <property name="mapFile">enum.txt</property>
       <property name="defaultNode">-1</property>
       <property name="type">0</property>
    </function>

    <function name="enum-string" class="enum">
       <property name="mapFile">enum-string.txt</property>
       <property name="defaultNode">1</property>
       <property name="type">-1</property>
    </function>

    <function name="rangeLong" class="numberrange">
       <property name="mapFile">numberrange.txt</property>
       <property name="defaultNode">4</property>
    </function>

    <function name="pattern" class="patternrange">
       <property name="mapFile">patternrange.txt</property>
       <property name="patternValue">1024</property>
       <property name="defaultNode">2</property>
    </function>

    <function name="partbydate" class="date">
       <property name="dateFormat">yyyy-MM-dd</property>
       <property name="sBeginDate">2021-10-01</property>
       <property name="sEndDate">2021-10-30</property>
       <property name="sPartionDay">10</property>
       <property name="defaultNode">0</property>
    </function>

    <function name="jumphash" class="jumpStringHash">
        <property name="partitionCount">2</property>
        <property name="hashSlice">0:2</property>
    </function>
    """
    When Add some data in "enum.txt"
    """
    1=0
    2=0
    3=0
    4=1
    5=1
    6=1
    7=2
    8=2
    9=2
    """
    When Add some data in "enum-string.txt"
    """
    a1=0
    b2=0
    c3=0
    d4=1
    e5=1
    f6=1
    g7=2
    h8=2
    i9=2
    """
    When Add some data in "numberrange.txt"
    """
    0-49=0
    50-99=1
    100-149=2
    150-199=3
    200-249=4
    250-299=5
    300-349=6
    350-399=7
    400-449=8
    450-499=9
    """
    When Add some data in "patternrange.txt"
    """
    0-255=0
    256-500=1
    501-755=2
    756-1000=3
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
      <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
          <heartbeat>select user()</heartbeat>
          <dbInstance name="hostM3" password="111111" url="172.100.9.4:3307" user="test" maxCon="1000" minCon="10" primary="true" />
      </dbGroup>
    """
    Given add xml segment to node with attribute "{'tag':'root'}" in "user.xml"
    """
      <shardingUser name="test" password="111111" schemas="schema1,schema2,schema3"/>
    """
    Then execute admin cmd "reload @@config_all"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                            |expect   | db      |
      | conn_0 | False    | drop table if exists test                   |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_1_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_2_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_3_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists foreign_table         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_4_t1         |success  | schema1 |
      | conn_0 | False    | drop table if exists sharding_5_t1         |success  | schema1 |
      | conn_0 | False    | drop view  if exists view_s51              |success  | schema1 |
      | conn_0 | False    | drop view  if exists tb_child              |success  | schema1 |
      | conn_0 | False    | drop view  if exists tb_grandson           |success  | schema1 |
      | conn_0 | False    | drop view  if exists string_hash_table      |success  | schema1 |
      | conn_0 | False    | drop view  if exists enum_table              |success  | schema1 |
      | conn_0 | False    | drop view  if exists enum_string_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists numberrange_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists patternrange_table       |success  | schema1 |
      | conn_0 | False    | drop view  if exists date_table              |success  | schema1 |
      | conn_0 | False    | drop view  if exists jump_string_hash_table  |success  | schema1 |
      | conn_0 | False    | drop table if exists global_sequence       |success  | schema1 |
      | conn_0 | False    | drop table if exists nosharding_1          |success  | schema1 |
      | conn_0 | True     | drop table if exists bigColumnValue_table   |success  | schema1 |
      | conn_0 | False    | drop table if exists test1                   |success  | schema2 |
      | conn_0 | False    | drop table if exists sharding_2_t1          |success  | schema2 |
      | conn_0 | False    | drop table if exists sharding_4_t3          |success  | schema2 |
      | conn_0 | True     | drop table if exists nosharding_2          |success  | schema2 |
      | conn_0 | False    | drop table if exists nosharding_3          |success  | schema3 |
      | conn_0 | True     | drop table if exists nosharding_4          |success  | schema3 |
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_test.sql*.dump
    """
    Given upload file "./assets/split_test.sql" to "dble-1" success
    Then execute sql in "dble-1" in "admin" mode
      | sql                                                                                                 | expect               |
      | split /opt/split_test.sql /opt                                                                      | has{('schema1-enum_table',"can't calculate valid shardingnode shardingValue,due to can't find any valid shardingnode shardingValue:0"),("schema1-global_sequence","data type of increment column isn't bigint, dble replaced it by itself."),("schema1-patternrange_table","can't calculate valid shardingnode shardingValue,due to can't find any valid shardingnode shardingValue:1010"),("schema1-tb_child","current stmt[\n--\n-- Table structure for table `tb_child`\n--\n\nDROP TABLE IF EXISTS `tb_child`] error,because:can't process child table, skip."),("schema1-tb_grandson","current stmt[\n--\n-- Table structure for table `tb_grandson`\n--\n\nDROP TABLE IF EXISTS `tb_grandson`] error,because:can't process child table, skip."),("schema1-view_s51","skip view view_s51")}    |
    #check the split out files exist
    Then check path "/opt/split_test.sql-dn1-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn2-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn3-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn4-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn5-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn6-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn7-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn8-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn9-*.dump" in "dble-1" should exist
    Then check path "/opt/split_test.sql-dn10-*.dump" in "dble-1" should exist
    Given execute oscmd in "dble-1"
     """
      mv /opt/split_test.sql-dn1-*.dump /opt/split_test.sql-dn1.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_test.sql-dn1.dump && \
      mv /opt/split_test.sql-dn3-*.dump /opt/split_test.sql-dn3.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_test.sql-dn3.dump && \
      mv /opt/split_test.sql-dn5-*.dump /opt/split_test.sql-dn5.dump && mysql -h172.100.9.5 -utest -P3307 -p111111 < /opt/split_test.sql-dn5.dump && \
      mv /opt/split_test.sql-dn2-*.dump /opt/split_test.sql-dn2.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_test.sql-dn2.dump && \
      mv /opt/split_test.sql-dn4-*.dump /opt/split_test.sql-dn4.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_test.sql-dn4.dump && \
      mv /opt/split_test.sql-dn6-*.dump /opt/split_test.sql-dn6.dump && mysql -h172.100.9.6 -utest -P3307 -p111111 < /opt/split_test.sql-dn6.dump && \
      mv /opt/split_test.sql-dn7-*.dump /opt/split_test.sql-dn7.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_test.sql-dn7.dump && \
      mv /opt/split_test.sql-dn8-*.dump /opt/split_test.sql-dn8.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_test.sql-dn8.dump && \
      mv /opt/split_test.sql-dn9-*.dump /opt/split_test.sql-dn9.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_test.sql-dn9.dump && \
      mv /opt/split_test.sql-dn10-*.dump /opt/split_test.sql-dn10.dump && mysql -h172.100.9.4 -utest -P3307 -p111111 < /opt/split_test.sql-dn10.dump
     """
    Then execute admin cmd "reload @@metadata"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose  | sql                                                                    | expect                                                                                                                          |db          |
#      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from test                          | has{(1,'aaaaaaaaaaaaaaaaaaaaaaaa',20),(2,'bbbbbbbbbb',25),(3,'欢乐',30),(4,'订单归总',33),(102,'换成超大号',50),(201,'201',80)}     | schema1    |
#      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from test                          | has{(1,'aaaaaaaaaaaaaaaaaaaaaaaa',20),(2,'bbbbbbbbbb',25),(3,'欢乐',30),(4,'订单归总',33),(102,'换成超大号',50),(201,'201',80)}     | schema1    |
#      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from test                          | has{(1,'aaaaaaaaaaaaaaaaaaaaaaaa',20),(2,'bbbbbbbbbb',25),(3,'欢乐',30),(4,'订单归总',33),(102,'换成超大号',50),(201,'201',80)}     | schema1    |
#      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from test                          | has{(1,'aaaaaaaaaaaaaaaaaaaaaaaa',20),(2,'bbbbbbbbbb',25),(3,'欢乐',30),(4,'订单归总',33),(102,'换成超大号',50),(201,'201',80)}     | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_1_t1                 | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(5,'5',5)}     | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_1_t1                 | Table 'db1.sharding_1_t1' doesn't exist                    | schema1    |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_2_t1                 | has{(2,'2',2),(4,'4',4)}                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_2_t1                 | has{(1,'1',1),(3,'3',3),(5,'5',5)}                         | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_3_t1                 | has{(3,'3',3)}                                             | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_3_t1                 | has{(1,'1',1),(4,'4',4)}                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from sharding_3_t1                 | Table 'db2.sharding_3_t1' doesn't exist                    | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from sharding_3_t1                 | has{(2,'2',2),(5,'5',5)}                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_4_t1                 | has{(4,'4',4)}                                              | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_4_t1                 | has{(1,'1',1),(5,'5',5)}                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from sharding_4_t1                 | has{(2,'2',2)}                                            | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from sharding_4_t1                 | has{(3,'3',3)}                                             | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_5_t1                 | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(5,'5',5)}     | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_5_t1                 | has{(100,'100',100),(199,'199',199)}                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from sharding_5_t1                 | has{(200,'200',200),(244,'244',244)}                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from sharding_5_t1                 | has{(251,'251',251)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from sharding_5_t1                 | has{(330,'330',330)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from string_hash_table             | has{(1,'a1',1)}                                            | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from string_hash_table             | has{(100,'a100dd',100),(199,'01999',199),(1010,'w1010ldjjd',1010)}  | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from string_hash_table             | has{(200,'22000',200),(244,'8244',244)}                    | schema1     |
#      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from string_hash_table             | has{(251,'d251dd',251)}                                    | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from string_hash_table             | Table 'db3.string_hash_table' doesn't exist                | schema1     |
#      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from string_hash_table             | has{(330,'0330gjjjj',330)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from enum_table                    | has{(1,'1',1),(2,'2',2),(3,'3',3)}                         | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from enum_table                    | has{(4,'4',4),(5,'5',5),(6,'6',6)}                         | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from enum_table                    | has{(7,'7',7),(8,'8',8),(9,'9',9)}                         | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from enum_string_table             | has{(1,'a1',1),(4,'b2',4),(9,'c3',9)}                      | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from enum_string_table             | has{(2,'d4',2),(3,'f6',3),(7,'e5',7),(0,'0',0)}            | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from enum_string_table             | has{(5,'g7',5),(6,'h8',6),(8,'i9',8)}                      | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from numberrange_table             | has{(0,'0',0),(48,'48',48)}                                | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from numberrange_table             | has{(55,'55',55),(99,'99',99)}                             | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from numberrange_table             | has{(102,'102',102)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from numberrange_table             | has{(169,'169',169)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from numberrange_table             | has{(230,'230',230),(10000,'1000qw',1000)}                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from numberrange_table             | has{(250,'250',250)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn7*/ select * from numberrange_table             | has{(333,'333',333)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn8*/ select * from numberrange_table             | has{(376,'376',376)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn9*/ select * from numberrange_table             | has{(405,'405',405)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn10*/ select * from numberrange_table            | has{(482,'482',482)}                                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from patternrange_table            | has{(0,'0',0),(48,'48',48),(55,'55',55),(99,'99',99),(255,'255',255)}  | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from patternrange_table            | has{(333,'333',333),(376,'376',376)}                       | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from patternrange_table            | has{(501,'501',501),(700,'700',700),(1010,'1010',1010)}    | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from patternrange_table            | has{(800,'800',800),(1000,'1000',1000)}                    | schema1     |
#      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from date_table                    | has{('2021-10-01','1',1),('2021-09-10','2',2),('2021-10-04','2',2),('2021-10-10','3',3),('2021-10-31','9',9)} | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from date_table                    | has{(datetime.date(2021, 10, 1), '1', 1), (datetime.date(2021, 9, 10), '2', 2), (datetime.date(2021, 10, 4), '2', 2), (datetime.date(2021, 10, 10), '3', 3), (datetime.date(2021, 10, 31), '9', 9)} | schema1     |
#      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from date_table                    | has{('2021-10-11','4',4),('2021-10-19','5',5)}             | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from date_table                    | has{(datetime.date(2021, 10, 11),'4',4),(datetime.date(2021, 10, 19),'5',5)}             | schema1     |
#      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from date_table                    | has{('2021-10-22','6',6),('2021-10-25','7',7),('2021-10-30','8',8)} | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from date_table                    | has{(datetime.date(2021, 10, 22),'6',6),(datetime.date(2021, 10, 25),'7',7),(datetime.date(2021, 10, 30),'8',8)} | schema1     |

      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from jump_string_hash_table        | has{(1,'a1ytttt',1),(2,'233d4',2),(3,'fddffdf36',3),(4,'fdffb2',4),(5,'khfldg7',5),(6,'NULL',6),(7,'eeefe5',7),(8,'fffi9',8),(9,'fvd6c3',9),(0,'66660',0)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from jump_string_hash_table        | length{(5)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from jump_string_hash_table        | length{(5)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from jump_string_hash_table        | length{(5)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from jump_string_hash_table        | length{(5)}                                 | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from jump_string_hash_table        | length{(5)}                                 | schema1     |

      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from global_sequence               | length{(5)}                                 | schema1     |

      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from nosharding_1                  | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(5,'5',5)}     | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select id from bigColumnValue_table         | has{(4)}                                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select id from bigColumnValue_table         | has{(1)}                                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select id from bigColumnValue_table         | has{(4)}                                                   | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select id from bigColumnValue_table         | has{(3),(7),(11),(15)}                                     | schema1     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from test1                         | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(6,'6',6)}     | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from test1                         | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(6,'6',6)}     | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from test1                         | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(6,'6',6)}     | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from test1                         | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(6,'6',6)}     | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_2_t1                 | has{(2,'2',2)(4,'4',4),(8,'8',8)}                          | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_2_t1                 | has{(1,'1',1),(3,'3',3)}                                   | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn1*/ select * from sharding_4_t3                 | has{(4,'4',4)}                                             | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn2*/ select * from sharding_4_t3                 | has{(1,'1',1)}                                             | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn3*/ select * from sharding_4_t3                 | has{(2,'2',2)}                                             | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn4*/ select * from sharding_4_t3                 | has{(3,'3',3),(7,'7',7)}                                   | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn5*/ select * from nosharding_2                  | has{(1,'1',1),(2,'2',2),(3,'3',3),(4,'4',4),(9,'9',9)}     | schema2     |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from nosharding_3                  | has{(1,'1',1),(3,'3',3),(4,'4',4),(5,'5',5)}               | schema3     |
      | conn_0 | False    | /*#dble:shardingNode=dn6*/ select * from nosharding_4                  | has{(1,'1',1),(2,'2',2),(4,'4',4),(5,'5',5)}               | schema3     |
    Given execute oscmd in "dble-1"
     """
      rm -rf /opt/split_test.sql*.dump
    """
