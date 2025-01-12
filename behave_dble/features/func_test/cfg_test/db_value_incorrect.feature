# Copyright (C) 2016-2021 ActionTech.
# License: https://www.mozilla.org/en-US/MPL/2.0 MPL version 2 or higher.
# Created by lizizi at 2020/7/7
Feature: config db config files incorrect and restart dble or reload configs

  Scenario: config db property, reload the configs #1
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM3" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" primary="true"/>
        <dbInstance name="hostM4" password="111111" url="172.100.9.2:3307" user="test" maxCon="1000" minCon="10" primary="true"/>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      dbGroup[ha_group3] has multi primary instance
    """

  Scenario: config db property, reload the configs #2
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM3" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" primary="false"/>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      dbGroup[ha_group3] has no primary instance
    """

  Scenario: config db property, reload the configs #3
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="h~ost@M3" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" primary="true"/>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      'h~ost@M3' is not a valid value for 'NMTOKEN'
    """

  Scenario: config db property, reload the configs #4
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100">
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM3" password="111111" url="" user="test" maxCon="1000" minCon="10" primary="true"/>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      dbGroup ha_group3 define error,some attributes of this element is empty: hostM3
    """

  Scenario: config db property, reload the configs #5
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100">
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM3" password="111111" user="test" maxCon="1000" minCon="10" primary="true"/>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      Attribute 'url' must appear on element 'dbInstance'
    """

  Scenario: config db property, reload the configs #6
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
      <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" disableHA="false">
        <heartbeat timeout="0" errorRetryCount="0">select user()</heartbeat>
        <dbInstance name="hostM2" password="111111" url="172.100.9.6:3307" user="test" usingDecrypt="false" maxCon="1000" minCon="10" readWeight="0" primary="true" disabled="false">
          <property name="evictorShutdownTimeoutMillis_fake">10L * 1000L</property>
        </dbInstance>
      </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      These properties of system are not recognized: evictorShutdownTimeoutMillis_fake
    """

  Scenario: config db property, reload the configs #7
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml" with duplicate name
    """
     <dbGroup rwSplitMode="0" name="ha_group3" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
     </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
    """
      The content of element 'dbGroup' is not complete. One of '{dbInstance}' is expected
    """

  @test-no-dbgroup
  Scenario: config db property, reload the configs #8
    ####  dmp initialization config
    Given update file content "/opt/dble/conf/db.xml" in "dble-1" with sed cmds
      """
      4,14d
      """
    Given update file content "/opt/dble/conf/sharding.xml" in "dble-1" with sed cmds
      """
      4,14d
      """
    Then execute admin cmd "reload @@config_all"
    Given execute linux command in "dble-1" and contains exception "Access denied for user 'test', because there are some empty dbGroup/fake dbInstance"
    """
    mysql -utest -p111111 -P8066 -h172.100.9.1 -Dschema1 -e "select version()"
    """
    Then restart dble in "dble-1" failed for
      """
      User\[name:test\]'s schema \[schema1\] is not exist
      """
    Given update file content "/opt/dble/conf/user.xml" in "dble-1" with sed cmds
      """
      5d
      """
    Given Restart dble in "dble-1" success



  Scenario: dbInstance's url duplicate in one dbGroup, reload the configs #9
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
    <dbGroup rwSplitMode="0" name="ha_group2" delayThreshold="100" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM2" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" primary="true" />
        <dbInstance name="hostS2" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" />
    </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
      """
      dbGroup[ha_group2]'s child url [172.100.9.6:3307]  duplicated!
      """


  Scenario: dbInstance's has non-exist parameters, reload the configs #10
     #dble-9114
    Given add xml segment to node with attribute "{'tag':'root'}" in "db.xml"
    """
    <dbGroup rwSplitMode="0" name="ha_group2" delayThreshold="100" switchType="1" >
        <heartbeat>select user()</heartbeat>
        <dbInstance name="hostM2" password="111111" url="172.100.9.6:3307" user="test" maxCon="1000" minCon="10" primary="true" />
    </dbGroup>
    """
    Then execute admin cmd "reload @@config_all" get the following output
      """
      Attribute 'switchType' is not allowed to appear in element 'dbGroup'
      """