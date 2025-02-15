

# Load Assemblies we need to access SMO

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.ConnectionInfo”)

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.Smo”)

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.SmoEnum”)

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.SqlEnum”)

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.WmiEnum”)

$asm = [reflection.assembly]::LoadWithPartialName(“Microsoft.SqlServer.SqlWmiManagement”)
##############################################################################

# Description:

# Change the name SQL Server instance name (stored inside SQL Server) to the name

# of the machine.  When a machine is unboxed after being sysprepped, it will still

# use the original SQL Server name as the instance name for SQL Server

#

# Input:

#

# Output:

#

# Author: DDarden

# Date  : 200904030748

#

# Change History

# Date        Author          Description

# ——–    ————–  ————————————————-

#

###############################################################################

function global:Set-SqlServerInstanceName{

    Write “Renaming SQL Server Instance”
    
    $smo = ‘Microsoft.SqlServer.Management.Smo.’
#   $smo
    $server = new-object ($smo + ‘server’) .

    $database = $server.Databases["master"]

    $mc = new-object ($smo + ‘WMI.ManagedComputer’) .


    $newServerName = $mc.Name


    $database.ExecuteNonQuery(“EXEC sp_dropserver @@SERVERNAME”)

    $database.ExecuteNonQuery(“EXEC sp_addserver ‘$newServerName’, ‘local’”)


    Write-Host “Renamed server to ‘$newServerName’`n”

}

# Set the SQL Server instance name to the current machine name

# MSSQLSERVER service needs to be restarted after this change
Set-SqlServerInstanceName