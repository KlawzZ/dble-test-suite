# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.
# update by quexiuping at 2021/7/22
# modified by wujinling at 2021/10/20

Feature: test flow_control about complex query
  @delete_mysql_tables
  Scenario: test flow_control about complex query   # 1
    """
    {'delete_mysql_tables':['mysql-master1','mysql-master2']}
    """
    Given update file content "/opt/dble/conf/bootstrap.cnf" in "dble-1" with sed cmds
       """
       s/-Xmx1G/-Xmx4G/
       s/-XX:MaxDirectMemorySize=1G/-XX:MaxDirectMemorySize=4G/
       s/-Dprocessors=1/-Dprocessors=4/
       s/-DprocessorExecutor=1/-DprocessorExecutor=8/

       $a -DenableFlowControl=true
       $a -DflowControlHighLevel=1048576
       $a -DflowControlLowLevel=262144
       $a -DsqlExecuteTimeout=1800000
       $a -DidleTimeout=1800000
       """
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
    <dbGroup rwSplitMode="0" name="ha_group1" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="M1" password="111111" url="172.100.9.5:3307" user="test" maxCon="100" minCon="10" primary="true">
             <property name="flowHighLevel">4048576</property>
             <property name="flowLowLevel">262144</property>
        </dbInstance>
     </dbGroup>

    <dbGroup rwSplitMode="0" name="ha_group2" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM2" password="111111" url="172.100.9.6:3307" user="test" maxCon="100" minCon="10" primary="true">
             <property name="flowHighLevel">4048576</property>
             <property name="flowLowLevel">262144</property>
        </dbInstance>
    </dbGroup>
     """
    Then Restart dble in "dble-1" success

    # prepare data
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                                                                                                                                  | expect  | db      | charset |
      | conn_1 | true    | drop table if exists sharding_2_t1                                                                                                                                   | success | schema1 | utf8mb4 |
      | conn_1 | true    | drop table if exists sharding_4_t1                                                                                                                                   | success | schema1 | utf8mb4 |
      | conn_1 | true    | create table sharding_2_t1 (id int,a varchar(120) ,b varchar(120) ,c varchar(120) ,d varchar(120) ) default charset=utf8                                             | success | schema1 | utf8mb4 |
      | conn_1 | true    | create table sharding_4_t1 (id int,a varchar(120) ,b varchar(120) ,c varchar(120) ,d varchar(120) ) default charset=utf8                                             | success | schema1 | utf8mb4 |
      | conn_1 | true    | insert into sharding_2_t1 values (1,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)),(2,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)) | success | schema1 | utf8mb4 |
      | conn_1 | true    | insert into sharding_4_t1 values (1,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)),(2,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)) | success | schema1 | utf8mb4 |
      | conn_1 | true    | insert into sharding_4_t1 values (3,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)),(4,repeat("中",32),repeat("华",32),repeat("民",32),repeat("国",32)) | success | schema1 | utf8mb4 |
    #prepare more data
    Given execute sql "22" times in "dble-1" at concurrent 22
      | sql                                                                                | db      |
      | insert into sharding_2_t1(id,a,b,c,d) select id,a,b,c,d from sharding_2_t1         | schema1 |
    Given execute sql "18" times in "dble-1" at concurrent 18
      | sql                                                                                | db      |
      | insert into sharding_4_t1(id,a,b,c,d) select id,a,b,c,d from sharding_4_t1         | schema1 |

    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect  | db      | charset |
      | conn_1 | true    | drop view if exists view1                             | success | schema1 | utf8mb4 |
      | conn_1 | true    | drop view if exists view2                             | success | schema1 | utf8mb4 |
      | conn_1 | true    | create view view1 as select * from sharding_2_t1      | success | schema1 | utf8mb4 |
      | conn_1 | true    | create view view2 as select * from sharding_4_t1      | success | schema1 | utf8mb4 |

    #####  case 1: view select #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                 | db      | charset |
      | conn_2  | true    | select * from view1 join view2      | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
      | conn_0 | true    | flow_control @@set flowControlHighLevel=131072 flowControlLowLevel=65536                | success | dble_information |
    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "3" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from view1 join view2
      """
    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """
    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    #check not effect the flowing sqls and the small sql will not trigger flow control
    Given record current dble log line number in "log_linenu"
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |
    Then check following text exist "N" in file "/opt/dble/logs/dble.log" after line "log_linenu" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This front connection begins flow control, currentWritingSize=
      """
    #restart dble for generate new dble.log
    Then Restart dble in "dble-1" success


    #####  case 2: view sub-query #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                        | db      | charset |
      | conn_3  | true    | select * from (select * from view1) a      | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
      | conn_0 | true    | flow_control @@set flowControlHighLevel=65536 flowControlLowLevel=2000                | success | dble_information |

    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "3" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from (select * from view1) a
      """
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |

    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """
    Then Restart dble in "dble-1" success

    #####  case 3: complex select  #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                                                                     | db      | charset |
      | conn_5  | true    | select * from sharding_2_t1 where id in (select id from sharding_4_t1) order by id      | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                              | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
      | conn_0 | true    | flow_control @@set flowControlHighLevel=262144 flowControlLowLevel=65536                | success | dble_information |
    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "20" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from sharding_2_t1 where id in (select id from sharding_4_t1) order by id
      """
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                              | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |
    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """
    Then Restart dble in "dble-1" success


    #####  case 4: complex select  #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                                | db      | charset |
      | conn_6  | true    | select * from (select * from sharding_2_t1) a      | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |
    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "10" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from (select * from sharding_2_t1) a
      """
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |

    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |

    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """
    Then Restart dble in "dble-1" success


    #####  case 5: complex select  #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                                                       | db      | charset |
      | conn_7  | true    | select * from sharding_2_t1 union all select * from sharding_4_t1         | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |

    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "5" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from sharding_2_t1 union all select * from sharding_4_t1
      """
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |

    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |

    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """
    Then Restart dble in "dble-1" success

    #####  case 6: complex select  #####
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                                          | db      | charset |
      | conn_8  | true    | select * from sharding_2_t1 order by id limit 1000000000     | schema1 | utf8mb4 |
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |

    Then check following text exist "N" in file "/tmp/dble_user_query.log" in host "dble-1"
      """
      closed
      Lost connection
      """
    Given sleep "10" seconds
    Given kill mysql query in "dble-1" forcely
      """
      select * from sharding_2_t1 order by id limit 1000000000
      """
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect  | db               |
      | conn_0 | true    | select * from dble_flow_control where flow_controlled=true                                | success | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | success | dble_information |

    Then check following text exist "Y" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This backend connection stop flow control, currentReadingSize=
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |

    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      NullPointerException
      caught err:
      """

    #####  case 7: close flow control, select big results will occur OOM  #####
    Then execute sql in "dble-1" in "admin" mode
      | conn   | toClose | sql                                                                                     | expect      | db               |
      | conn_0 | true    | flow_control @@set enableFlowControl=false                                              | success     | dble_information |
      | conn_0 | true    | flow_control @@show                                                                     | length{(0)} | dble_information |
      | conn_0 | true    | flow_control @@list                                                                     | length{(0)} | dble_information |
    Given record current dble log line number in "log_linenu"
    Given execute sqls in "dble-1" at background
      | conn    | toClose | sql                                                          | db      | charset |
      | conn_8  | true    | select * from sharding_2_t1 join sharding_4_t1               | schema1 | utf8mb4 |
    #这里可能需要超过1min才能返回oom
    Given sleep "120" seconds
    Then check following text exist "Y" in file "/tmp/dble_user_query.log" in host "dble-1"
    """
    java.lang.OutOfMemoryError
    """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                                   | expect        | db      | charset |
      | conn_1 | true    | select * from sharding_2_t1 limit 100                 | length{(100)} | schema1 | utf8mb4 |
    Then check following text exist "N" in file "/opt/dble/logs/dble.log" in host "dble-1"
      """
      This backend connection begins flow control, currentReadingSize=
      This front connection begins flow control, currentWritingSize=
      """
    Given execute linux command in "dble-1"
      """
      rm -rf /opt/dble/Memory*
      """
    Then execute sql in "dble-1" in "user" mode
      | conn   | toClose | sql                                         | expect  | db      | charset |
      | conn_1 | true    | drop table if exists sharding_2_t1          | success | schema1 | utf8mb4 |
      | conn_1 | true    | drop table if exists sharding_4_t1          | success | schema1 | utf8mb4 |
      | conn_1 | true    | drop view if exists view1                   | success | schema1 | utf8mb4 |
      | conn_1 | true    | drop view if exists view2                   | success | schema1 | utf8mb4 |