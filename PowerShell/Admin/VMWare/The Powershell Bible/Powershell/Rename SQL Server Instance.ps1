#Starts SQL Server to rename the instance
net start MSSQLSERVER

#Makes Local Administrator able to administrate SQL Server
sqlcmd -E -Q "exec sp_addsrvrolemember 'BUILTIN\Administrators','sysadmin';"

#Renames SQL Instance to local machine name
sqlcmd -E -Q "exec sp_dropserver @@SERVERNAME; exec sp_addserver '%1',local"

#Stops SQL server
net stop MSSQLSERVER