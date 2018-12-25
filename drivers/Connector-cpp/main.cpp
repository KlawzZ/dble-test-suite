#include <cstdio>
#include "stdlib.h"
#include<iostream>
#include "ext.h"
#include <unistd.h>  
#include <stdio.h>
#include "mysql_connection.h"
#include "mysql_driver.h"
//#include <cppconn/driver.h>
//#include <cppconn/exception.h>
using namespace std;
using namespace sql;
#ifndef MAX_PATH  
#define MAX_PATH 1024  
#endif

int main()
{
	//�������ݿ�����
	Connection *dbleMcon;
	Connection *dblecon;
	Connection *mysqlcon;
	const char *MhostName = "tcp://10.186.60.61:7171";
	const char *MuserName = "root";
	const char *Mpassword = "111111";
	const char *ChostName = "tcp://10.186.60.61:7131";
	const char *CuserName = "test";
	const char *Cpassword = "111111";
	const char *MysqlhostName = "tcp://10.186.60.61:7144";
	const char *MysqluserName = "test";
	const char *Mysqlpassword = "111111";
	//��ȡ��ǰ·��
	char buffer[MAX_PATH];
	const char *curpath = getcwd(buffer, MAX_PATH);
	//��ȡ��ǰʱ���
	unsigned long stime = time(0);
	string strtime = to_string(stime);
	string path = string(curpath) + '/' + strtime;
	const char *logpath = path.c_str();
	createdir(logpath);
	//��ȡsqlfile·��,���ڴ����ö�ȡ
	string sqlfilename = string(curpath) + '/' + "sql/driver_test_manager.sql";
	//string sqlfilename = string(curpath) + '/' + "sql/driver_test_client.sql";
	const char *sqlfile = sqlfilename.c_str();
	//cout << string(sqlfile) << endl;

	if (findSubstr(sqlfilename,"manager")) {
		dbleMcon = createConn(MhostName, MuserName, Mpassword);
		manager_exec(sqlfile, logpath, dbleMcon);
		delete dbleMcon;
	}
	if (findSubstr(sqlfilename,"client")) {
		dblecon = createConn(ChostName, CuserName, Cpassword);
		mysqlcon = createConn(MysqlhostName, MysqluserName, Mysqlpassword);
		client_exec(sqlfile, logpath, dblecon, mysqlcon);
		delete dblecon;
		delete mysqlcon;
	}
	exit(0);
}

