##########################################################
# Notice: This module requires PowerShell 2 or later
##########################################################

#region TypeDefinitions

Add-Type -TypeDefinition @"
namespace VMware.VimAutomation.PowerCliExtensions
{
    public class CounterLevelMapping
    {
        #region Private data

        private string _name;
        private string _aggregateLevel;
        private string _perDeviceLevel;
        private string _server;
        #endregion Private data

        #region Public properties

        public string Name {
           get {
              return _name;
           }
        }

        public string AggregateLevel {
           get {
              return _aggregateLevel;
           }
        }

        public string PerDeviceLevel {
           get {
              return _perDeviceLevel;
           }
        }

        // Server is intentionally the last parameter so that
        // the last column may be left out of .csv files
        public string Server {
           get { return _server; }
        }

        #endregion Public properties

        public CounterLevelMapping(string aggregateLevel, string name, string perDeviceLevel, string server) {
           _aggregateLevel = aggregateLevel;
           _name = name;
           _perDeviceLevel = perDeviceLevel;
           _server = server;
        }
    }
}
"@ # -ReferencedAssemblies $referencedAssemblies
#endregion

# Composes the counter name based on a VMware.Vim counter object
function script:Get-CounterName($counter) {
   $gik = $counter.GroupInfo.Key;
   $nik = $counter.NameInfo.Key;
   $rut = $counter.rollUpType;
   return $gik + "." + $nik + "." + $rut
}

# Resolves the -Server argument
function ResolveServer($globs, [string[]]$actual) {
   if($null -eq $Globs -or $Globs.Length -eq 0) {
      if ($actual.Length -eq 0) {
         throw "You are not currently connected to any servers. " + `
         "Please connect first using a Connect cmdlet."
      }
      return $actual
   }
   $result = @()
   foreach ($expr in $Globs) {
      if($actual -contains $expr) {
         $result += $expr
      }
   }
   if ($result.Length -eq 0) {
      throw "Could not find server specified by name."
   }
   return $result
}


# Check that we have a valid set of levels for updating
function CheckLevels($name, $agg, $dev) {
   if ($name.length) {
      $for = " for $name"
   }
   if ($null -ne $agg -and 1..4 -notcontains $agg) {
      throw "AggregateLevel '$agg'$for must be null or in the range 1..4"
   }
   if ($null -ne $dev -and 1..4 -notcontains $dev) {
      throw "PerDeviceLevel '$dev'$for must be null or in the range 1..4"
   }
   if ($null -eq $agg -and -$null -eq $dev) {
      throw "At least one of AggregateLevel and PerDeviceLevel must be non-null"
   }
}
#endregion


<#
.SYNOPSIS
Retrieves VIServer counter level mappings.
.DESCRIPTION
Retrieves VIServer performance counters from the specified server.
If -Server parameter is not specified, uses the default servers in $global:DefaultViServers.
.OUTPUTS
Zero or more CounterLevelMapping objects.
.NOTES
.EXAMPLE
Get-PxCounterLevelMapping -Server server1.example.com
.EXAMPLE
Get-PxCounterLevelMapping | Export-csv -path c:\counter.csv
.EXAMPLE
Get-PxCounterLevelMapping | Export-clixml -path c:\counter.xml
.PARAMETER Server
IP address of VC Server. Multiple servers address separated with comma can be passed
#>
function Get-PxCounterLevelMapping {
   [CmdletBinding()]
   param (
      [Parameter()]
      $Server
   )
   BEGIN {
      $viServer = ResolveServer $Server $global:DefaultVIServers
   }
   PROCESS {
      foreach ($serverInstance in $viServer) {
         $si = Get-View ServiceInstance -Server $serverInstance
         $perfManager = Get-View $si.Content.PerfManager -Server $serverInstance
         foreach ($counter in $perfManager.perfCounter) {
            $result =
               New-Object `
                  -TypeName 'VMware.VimAutomation.PowerCliExtensions.CounterLevelMapping' `
                  -ArgumentList ($counter.Level, (Get-CounterName $counter), $counter.PerDeviceLevel,$serverInstance)
            Write-Output $result
         }
      }
   }
}

<#
.SYNOPSIS
Updates or resets VIServer performance counters.
.DESCRIPTION
Updates or resets the performance counters from pipeline.
Passed aggregate and device values must be in interval [1,4]
To reset the performance counters values to its default levels, optional switch reset should be passed to it.
Mappings from same server can only be applied to multiple servers to avoid dealing with duplicates
.OUTPUTS
The updated CounterLevelMapping objects.
.NOTES
.EXAMPLE
Get-PxCounterLevelMapping | where { $_.Name -like "cpu.usage.*" } |
   Set-PxCounterLevelMapping -AggregateLevel 3 -PerDeviceLevel 4
.EXAMPLE
Import-clixml -Path c:\pc.xml |
   Set-PxCounterLevelMapping -Server server.example.com -AggregateLevel 2
.EXAMPLE
Import-csv -Path c:\pc.csv |
   Set-PxCounterLevelMapping -Server server.example.com
.EXAMPLE
Get-PxCounterLevelMapping |
   Set-PxCounterLevelMapping -Server server.example.com -Reset
.EXAMPLE
Import-clixml -Path c:\pc.xml |
   Set-PxCounterLevelMapping -Server server.example.com -Reset
.PARAMETER CounterLevelMapping
Zero or more CounterLevelMapping objects to modify.
.PARAMETER AggregateLevel
The aggregate level ranging from 1-4 to set.
.PARAMETER PerDeviceLevel
The per-device level ranging from 1-4 to set.
.PARAMETER Server
IP address of VC Server. Multiple servers address separated with comma can be passed
.PARAMETER Reset
Resets statistics collection levels for a counter to their default values.
#>
function Set-PxCounterLevelMapping {
   [CmdletBinding(DefaultParameterSetName = "Update", SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
   param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
      [System.object[]] $CounterLevelMapping,
      [Parameter(ParameterSetName="Update")]
      [System.object] $AggregateLevel,
      [Parameter(ParameterSetName="Update")]
      [System.object] $PerDeviceLevel,
      [Parameter()]
      [System.object[]] $Server,
      [Parameter(Mandatory = $true, ParameterSetName="Reset")]
      [switch] $Reset
   )
   BEGIN {
      $levelMap = @()
      $serverList = @()
      CheckLevels $Name $AggregateLevel $PerDeviceLevel
      $viServer = ResolveServer $Server $global:DefaultVIServers
   }
   PROCESS {
      foreach ($counterInstance in $CounterLevelMapping){
         if($serverList -notcontains $counterInstance.Server) {
            $serverList += $counterInstance.Server
            CheckLevels $Name $counterInstance.AggregateLevel $counterInstance.PerDeviceLevel
         }
         $levelMap += $counterInstance
      }
   }
   END {
      if (!$Reset -and $serverList.Length -gt 1) {
         write-host "Script can map only from a single server, terminating script"
         return
      }
      foreach ($serverInstance in $viServer) {
         $si = Get-View ServiceInstance -Server $serverInstance
         $perfManager = Get-View $si.Content.PerfManager -Server $serverInstance
         # Keys dont have the same value across different servers
         $counterNameToIdMap = @{}
         foreach ($counter in $perfManager.perfCounter) {
            $counterNameToIdMap[(Get-CounterName $counter)] = $counter.Key
         }
         if (!$Reset) {
            $counterLevelMapList = @()
            foreach ($counterInstance in $levelMap) {
               $counterLevelMap = New-Object VMware.Vim.PerformanceManagerCounterLevelMapping
               $key = $counterNameToIdMap[$counterInstance.Name]
               if($key -ne $null){
                  $counterLevelMap.CounterId = $key
                  if($AggregateLevel -ne $null){
                     $al = [int]$AggregateLevel
                  } else {
                     $al = $counterInstance.AggregateLevel
                  }
                  if($PerDeviceLevel -ne $null){
                     $pl = [int]$PerDeviceLevel
                  } else {
                     $pl = $counterInstance.PerDeviceLevel
                  }
                  $counterLevelMap.AggregateLevel = $al
                  $counterLevelMap.PerDeviceLevel = $pl
                  write-host "Updating $($counterInstance.Name) in server $serverInstance"
                  $counterLevelMapList += $counterLevelMap
               }
            }
            if($counterLevelMapList.length -ne 0) {
               try {
                  $perfManager.UpdateCounterLevelMapping($counterLevelMapList)
               }
               catch {
                  Write-host $_ | fl * -Force
                  Write-host "If you are running a 5.0GA systems, VC throws up errors if Aggregate Level is set greater than Per Device Level"
               }
            }
         }
         else {
            $keyList = @()
            foreach ($counterInstance in $levelMap) {
               $key = $counterNameToIdMap[$counterInstance.Name]
               if( $key -ne $null){
                  $keyList += $key
                  write-host "Reseting $($counterInstance.Name) in server $serverInstance"
               } else {
                  write-host "Counter $($counterInstance.Name) not present in server $serverInstance"
               }
            }
            if($keyList.length -ne 0) {
               try {
                  $perfManager.ResetCounterLevelMapping($keyList)
               }
               catch {
                  Write-host $_ | fl * -Force
                  Write-host "If you are running a 5.0GA systems, VC throws up errors while reseting for following counters"  `
                  "disk.throughput.usage.average, disk.throughput.contention.average, disk.capacity.provisioned.average" `
                  "datastore.throughput.usage.average, datastore.throughput.contention.average, virtualDisk.throughput.usage.average" `
                  "storagePath.throughput.usage.average"
               }
            }
         }
      }
   }
}

Export-ModuleMember -Function Get-PxCounterLevelMapping
Export-ModuleMember -Function Set-PxCounterLevelMapping