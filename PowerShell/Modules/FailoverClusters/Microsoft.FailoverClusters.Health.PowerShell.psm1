
#public enum MetricUnitEnum
#{
#    0 // No Units
#    1 // PerSecond
#    2 // bytes PerSecond
#    3 // seconds
#    4 // bytes
#    5 // percent
#    6 // plain Seconds
#}
function Get-ClusterPerformanceHistory
{
    [CmdletBinding(DefaultParameterSetName="ByCluster", SupportsShouldProcess, ConfirmImpact="medium")]
    Param
    (
        [parameter(Mandatory=$true, ParameterSetName="Api")]
        [ValidateNotNullOrEmpty()]
        [string]$SeriesKeyName,

        [parameter(Mandatory=$true, ParameterSetName="Api")]
        [ValidateNotNullOrEmpty()]
        [string]$Stream,

        [string[]]
        [ValidateSet(
            "Volume.IOPS.Read",
            "Volume.IOPS.Write",
            "Volume.IOPS.Total",
            "Volume.Throughput.Read",
            "Volume.Throughput.Write",
            "Volume.Throughput.Total",
            "Volume.Latency.Read",
            "Volume.Latency.Write",
            "Volume.Latency.Average",
            "Node.Cpu.Usage",
            "Node.Cpu.Usage.Guest",
            "Node.Memory.Usage.Guest",
            "VirtualMachine.Memory.Maximum",
            "Node.Memory.Available",
            "Node.Memory.Total",
            "Node.Memory.Usage.Host",
            "Node.Memory.Usage",
            "Node.Cpu.Usage.Host", 
            "Volume.Size.Available",
            "Volume.Size.Total",
            "PhysicalDisk.Size.Available",
            "PhysicalDisk.Size.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByCluster")]
        $ClusterSeriesName=@(
            "Volume.IOPS.Read",
            "Volume.IOPS.Write",
            "Volume.IOPS.Total",
            "Volume.Throughput.Read",
            "Volume.Throughput.Write",
            "Volume.Throughput.Total",
            "Volume.Latency.Read",
            "Volume.Latency.Write",
            "Volume.Latency.Average",
            "Node.Cpu.Usage",
            "Node.Cpu.Usage.Guest",
            "Node.Memory.Usage.Guest",
            "VirtualMachine.Memory.Maximum",
            "Node.Memory.Available",
            "Node.Memory.Total",
            "Node.Memory.Usage.Host",
            "Node.Memory.Usage",
            "Node.Cpu.Usage.Host", 
            "Volume.Size.Available",
            "Volume.Size.Total",
            "PhysicalDisk.Size.Available",
            "PhysicalDisk.Size.Total"
        ),

        [string[]]
        [ValidateSet(
            "Node.Cpu.Usage",
            "Node.Cpu.Usage.Guest",
            "Node.Memory.Usage.Guest",
            "VirtualMachine.Memory.Maximum",
            "Node.Memory.Usage.Host",
            "Node.Cpu.Usage.Host", 
            "Node.Memory.Total",
            "Node.Memory.Available",
            "Node.Memory.Usage",
            "NetworkAdapter.Bytes.Inbound",
            "NetworkAdapter.Bytes.Outbound",
            "NetworkAdapter.Bytes.Total",
            "NetworkAdapter.Bytes.RDMA.Inbound",
            "NetworkAdapter.Bytes.RDMA.Outbound",
            "NetworkAdapter.Bytes.RDMA.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByClusterNode")]
        $ClusterNodeSeriesName=@(
            "Node.Cpu.Usage",
            "Node.Cpu.Usage.Guest",
            "Node.Memory.Usage.Guest",
            "VirtualMachine.Memory.Maximum",
            "Node.Memory.Usage.Host",
            "Node.Cpu.Usage.Host", 
            "Node.Memory.Total",
            "Node.Memory.Available",
            "Node.Memory.Usage",
            "NetworkAdapter.Bytes.Inbound",
            "NetworkAdapter.Bytes.Outbound",
            "NetworkAdapter.Bytes.Total",
            "NetworkAdapter.Bytes.RDMA.Inbound",
            "NetworkAdapter.Bytes.RDMA.Outbound",
            "NetworkAdapter.Bytes.RDMA.Total"
        ),

        [string[]]
        [Validateset(
            "VirtualMachine.Cpu.Usage",
            "VirtualMachine.Memory.Total",
            "VirtualMachine.Memory.Available",
            "VirtualMachine.Memory.Pressure",
            "VirtualMachine.Memory.Assigned",
            "VirtualMachine.Memory.Minimum",
            "VirtualMachine.Memory.Maximum",
            "VirtualMachine.Memory.Startup",
            "VHD.Throughput.Read",
            "VHD.Throughput.Write",
            "VHD.Throughput.Total",
            "VHD.IOPS.Read",
            "VHD.IOPS.Write",
            "VHD.IOPS.Total",
            "VirtualNetworkAdapter.Bytes.Inbound",
            "VirtualNetworkAdapter.Bytes.Outbound",
            "VirtualNetworkAdapter.Bytes.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByVirtualMachine")]
        $VirtualMachineSeriesName=@(
            "VirtualMachine.Cpu.Usage",
            "VirtualMachine.Memory.Total",
            "VirtualMachine.Memory.Available",
            "VirtualMachine.Memory.Pressure",
            "VirtualMachine.Memory.Assigned",
            "VirtualMachine.Memory.Minimum",
            "VirtualMachine.Memory.Maximum",
            "VirtualMachine.Memory.Startup",
            "VHD.Throughput.Read",
            "VHD.Throughput.Write",
            "VHD.Throughput.Total",
            "VHD.IOPS.Read",
            "VHD.IOPS.Write",
            "VHD.IOPS.Total",
            "VirtualNetworkAdapter.Bytes.Inbound",
            "VirtualNetworkAdapter.Bytes.Outbound",
            "VirtualNetworkAdapter.Bytes.Total"
        ),

        [string[]]
        [ValidateSet(
            "VHD.Latency.Average",
            "VHD.Throughput.Read",
            "VHD.Throughput.Write",
            "VHD.Throughput.Total",
            "VHD.IOPS.Read",
            "VHD.IOPS.Write",
            "VHD.IOPS.Total",
            "VHD.Size.Current",
            "VHD.Size.Maximum"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByVHD")]
        $VHDSeriesName=@(
            "VHD.Latency.Average",
            "VHD.Throughput.Read",
            "VHD.Throughput.Write",
            "VHD.Throughput.Total",
            "VHD.IOPS.Read",
            "VHD.IOPS.Write",
            "VHD.IOPS.Total",
            "VHD.Size.Current",
            "VHD.Size.Maximum"
        ),

        [string[]]
        [Validateset(
            "PhysicalDisk.IOPS.Read",
            "PhysicalDisk.IOPS.Write",
            "PhysicalDisk.IOPS.Total",
            "PhysicalDisk.Throughput.Read",
            "PhysicalDisk.Throughput.Write",
            "PhysicalDisk.Throughput.Total",
            "PhysicalDisk.Latency.Read",
            "PhysicalDisk.Latency.Write",
            "PhysicalDisk.Latency.Average",
            "PhysicalDisk.Size.Used",
            "PhysicalDisk.Size.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByPhysicalDisk")]
        $PhysicalDiskSeriesName =@(
            "PhysicalDisk.IOPS.Read",
            "PhysicalDisk.IOPS.Write",
            "PhysicalDisk.IOPS.Total",
            "PhysicalDisk.Throughput.Read",
            "PhysicalDisk.Throughput.Write",
            "PhysicalDisk.Throughput.Total",
            "PhysicalDisk.Latency.Read",
            "PhysicalDisk.Latency.Write",
            "PhysicalDisk.Latency.Average",
            "PhysicalDisk.Size.Used",
            "PhysicalDisk.Size.Total"
        ),

        [string[]]
        [ValidateSet(
            "Volume.IOPS.Read",
            "Volume.IOPS.Write",
            "Volume.IOPS.Total",
            "Volume.Throughput.Read",
            "Volume.Throughput.Write",
            "Volume.Throughput.Total",
            "Volume.Latency.Read",
            "Volume.Latency.Write",
            "Volume.Latency.Average",
            "Volume.Size.Available",
            "Volume.Size.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByVolume")]
        $VolumeSeriesName =@(
            "Volume.IOPS.Read",
            "Volume.IOPS.Write",
            "Volume.IOPS.Total",
            "Volume.Throughput.Read",
            "Volume.Throughput.Write",
            "Volume.Throughput.Total",
            "Volume.Latency.Read",
            "Volume.Latency.Write",
            "Volume.Latency.Average",
            "Volume.Size.Available",
            "Volume.Size.Total"
        ),

        [string[]]
        [ValidateSet(
            "NetworkAdapter.Bytes.Inbound",
            "NetworkAdapter.Bytes.Outbound",
            "NetworkAdapter.Bytes.Total",
            "NetworkAdapter.Bytes.RDMA.Inbound",
            "NetworkAdapter.Bytes.RDMA.Outbound",
            "NetworkAdapter.Bytes.RDMA.Total"
        )]
        [parameter(Position=0, Mandatory=$false, ParameterSetName="ByNetworkAdapter")]
        $NetworkAdapterSeriesName=@(
            "NetworkAdapter.Bytes.Inbound",
            "NetworkAdapter.Bytes.Outbound",
            "NetworkAdapter.Bytes.Total",
            "NetworkAdapter.Bytes.RDMA.Inbound",
            "NetworkAdapter.Bytes.RDMA.Outbound",
            "NetworkAdapter.Bytes.RDMA.Total"
        ),

        [string]
        [ValidateSet("MostRecent","LastHour","LastDay","LastWeek","LastMonth","LastYear")]
        [ValidateNotNullOrEmpty()]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByCluster")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByClusterNode")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByVirtualMachine")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByVHD")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByPhysicalDisk")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByVolume")]
        [parameter(Position=1, Mandatory=$false, ParameterSetName="ByNetworkAdapter")]
        $TimeFrame="MostRecent",

        [Microsoft.FailoverClusters.PowerShell.Cluster]
        [parameter(
            Position=2,
            Mandatory=$false,
            ParameterSetName="ByCluster",
            ValueFromPipeline= $true
        )]
        $Cluster,

        [Microsoft.FailoverClusters.PowerShell.ClusterNode[]]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByClusterNode",
            ValueFromPipeline= $true
        )]
        $ClusterNode,

        [PSObject[]]
        [PSTypeName("Microsoft.HyperV.PowerShell.VirtualMachine")]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByVirtualMachine",
            ValueFromPipeline=$true
        )]
        $VirtualMachine,

        [PSObject[]]
        [PSTypeName("Microsoft.Vhd.PowerShell.VirtualHardDisk")]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByVHD",
            ValueFromPipeline=$true
        )]
        $VHD,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#root/microsoft/windows/storage/MSFT_PhysicalDisk")]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByPhysicalDisk",
            ValueFromPipeline=$true
        )]
        $PhysicalDisk,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#root/microsoft/windows/storage/MSFT_Volume")]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByVolume",
            ValueFromPipeline=$true
        )]
        $Volume,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/StandardCimv2/MSFT_NetAdapter")]
        [parameter(
            Position=2,
            Mandatory=$true,
            ParameterSetName="ByNetworkAdapter",
            ValueFromPipeline=$true
        )]
        $NetworkAdapter,

        [Microsoft.Management.Infrastructure.CimSession]
        $CimSession
    )

    Begin
    {
        $script:results=@()
        $asGroupObject = $true

        switch($psCmdlet.ParameterSetName)
        {
            "Api"
            {
                if($Stream -eq "MostRecent")
                {
                    $asGroupObject=$false
                }
            }
            default
            {
                if($TimeFrame -eq "MostRecent")
                {
                    $asGroupObject=$false
                }
            }
        }
    }

    Process
    {
        $SeriesNames=@{}
        Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 0 -CurrentOperation "Gathering objects" -Status "0/4"
        if (-not $CimSession)
        {
            $CimSession = New-CimSession -Verbose:$false
        }

        $flags=0

        switch($TimeFrame)
        {
            "MostRecent"{break}
            default{Write-Warning -Message "Using TimeFrame $($TimeFrame) is an expensive operation. Consider saving it to a variable in the future to reduce performance impact on the environment."}
        }

        function Initalize-SeriesData
        {
            param
            (
                [string]$TagetId_,
                [string]$ObjectTypeName_,
                [string]$ObjectDescription_,
                [string[]]$SourceSeriesName_
            )
            process
            {
                $SD=@{}
                foreach ($SeriesName_ in $SourceSeriesName_)
                {
                    $SeriesName = "$($SeriesName_),$($ObjectTypeName_)=$($TagetId_)"
                    $SD.Add($SeriesName, $ObjectDescription_)
                }

                return $SD
            }
        }

        function GetClusterUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "Volume.IOPS.Read,*"                { return 1 }
                    "Volume.IOPS.Write,*"               { return 1 }
                    "Volume.IOPS.Total,*"               { return 1 }
                    "Volume.Throughput.Read,*"          { return 2 }
                    "Volume.Throughput.Write,*"         { return 2 }
                    "Volume.Throughput.Total,*"         { return 2 }
                    "Volume.Latency.Read,*"             { return 3 }
                    "Volume.Latency.Write,*"            { return 3 }
                    "Volume.Latency.Average,*"          { return 3 }
                    "Node.Cpu.Usage,*"                  { return 5 }
                    "Node.Cpu.Usage.Guest,*"            { return 5 }
                    "Node.Memory.Usage.Guest,*"         { return 4 }
                    "VirtualMachine.Memory.Maximum,*"   { return 4 }
                    "Node.Memory.Available,*"           { return 4 }
                    "Node.Memory.Total,*"               { return 4 }
                    "Node.Memory.Usage.Host,*"          { return 4 }
                    "Node.Memory.Usage,*"               { return 4 }
                    "Node.Cpu.Usage.Host,*"             { return 5 } 
                    "Volume.Size.Available,*"           { return 4 }
                    "Volume.Size.Total,*"               { return 4 }
                    "PhysicalDisk.Size.Available,*"     { return 4 }
                    "PhysicalDisk.Size.Total,*"         { return 4 }
                    default                             { return 0 }
                }
            }
        }

        function GetClusterNodeUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "Node.Cpu.Usage,*"                                     { return 5 }
                    "Node.Cpu.Usage.Guest,*"                               { return 5 }
                    "Node.Memory.Usage.Guest,*"                            { return 4 }
                    "VirtualMachine.Memory.Maximum,*"                      { return 4 }
                    "Node.Memory.Usage.Host,*"                             { return 4 }
                    "Node.Cpu.Usage.Host,*"                                { return 5 }
                    "Node.Memory.Total,*"                                  { return 4 }
                    "Node.Memory.Available,*"                              { return 4 }
                    "Node.Memory.Usage,*"                              { return 4 }
                    "NetworkAdapter.Bytes.Inbound,*"                   { return 2 }
                    "NetworkAdapter.Bytes.Outbound,*"                  { return 2 }
                    "NetworkAdapter.Bytes.Total,*"                     { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Inbound,*"              { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Outbound,*"             { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Total,*"                { return 2 }
                    default                                                { return 0 }
                }
            }
        }

        function GetVMUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "VirtualMachine.Cpu.Usage,*"                                  { return 5 }
                    "VirtualMachine.Memory.Total,*"                               { return 4 }
                    "VirtualMachine.Memory.Available,*"                           { return 4 }
                    "VirtualMachine.Memory.Pressure,*"                            { return 0 }
                    "VirtualMachine.Memory.Assigned,*"                            { return 4 }
                    "VirtualMachine.Memory.Minimum,*"                             { return 4 }
                    "VirtualMachine.Memory.Maximum,*"                             { return 4 }
                    "VirtualMachine.Memory.Startup,*"                             { return 4 }
                    "VHD.Throughput.Read,*"                                       { return 2 }
                    "VHD.Throughput.Write,*"                                      { return 2 }
                    "VHD.Throughput.Total,*"                                      { return 2 }
                    "VHD.IOPS.Read,*"                                             { return 1 }
                    "VHD.IOPS.Write,*"                                            { return 1 }
                    "VHD.IOPS.Total,*"                                            { return 1 }
                    "VirtualNetworkAdapter.Bytes.Inbound,*"                       { return 2 }
                    "VirtualNetworkAdapter.Bytes.Outbound,*"                      { return 2 }
                    "VirtualNetworkAdapter.Bytes.Total,*"                         { return 2 }
                    default                                                       { return 0 }
                }
            }
        }

        function GetVHDUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "VHD.Latency.Average,*"       { return 3 }
                    "VHD.Throughput.Read,*"       { return 2 }
                    "VHD.Throughput.Write,*"      { return 2 }
                    "VHD.Throughput.Total,*"      { return 2 }
                    "VHD.IOPS.Read,*"             { return 1 }
                    "VHD.IOPS.Write,*"            { return 1 }
                    "VHD.IOPS.Total,*"            { return 1 }
                    "VHD.Size.Current,*"          { return 4 }
                    "VHD.Size.Maximum,*"          { return 4 }
                    default                       { return 0 }
                }
            }
        }

        function GetPhysicalDiskUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "PhysicalDisk.IOPS.*"       { return 1 }
                    "PhysicalDisk.Throughput.*" { return 2 }
                    "PhysicalDisk.Latency.*"    { return 3 }
                    "PhysicalDisk.Size.*"       { return 4 }
                    default                     { return 0 }
                }
            }
        }

        function GetVolumeUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "Volume.IOPS.*"       { return 1 }
                    "Volume.Throughput.*" { return 2 }
                    "Volume.Latency.*"    { return 3 }
                    "Volume.Size.*"       { return 4 }
                    default               { return 0 }
                }
            }
        }

        function GetNetworkAdapterUnits
        {
            param([string]$SeriesName)
            process
            {
                switch -wildcard ($SeriesName)
                {
                    "NetworkAdapter.Bytes.Inbound,*"                   { return 2 }
                    "NetworkAdapter.Bytes.Outbound,*"                  { return 2 }
                    "NetworkAdapter.Bytes.Total,*"                     { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Inbound,*"              { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Outbound,*"             { return 2 }
                    "NetworkAdapter.Bytes.RDMA.Total,*"                { return 2 }
                    default                                                { return 0 }
                }
            }
        }

        $unitFunction=$Function:GetClusterUnits

        switch($psCmdlet.ParameterSetName)
        {
            "ByCluster"
            {
                if(!$Cluster)
                {
                    $Cluster=Get-Cluster
                }

                $SeriesNames += Initalize-SeriesData -TagetId_ "$($Cluster.Name)" -ObjectTypeName_ "Cluster" -ObjectDescription_ "Cluster $($Cluster.Name)" -SourceSeriesName_ $ClusterSeriesName

                $unitFunction=$Function:GetClusterUnits
            }

            "ByClusterNode"
            {
                foreach($clusterNode_ in $ClusterNode)
                {
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($clusterNode_.Name)" -ObjectTypeName_ "Node" -ObjectDescription_ "Node $($clusterNode_.Name)" -SourceSeriesName_ $ClusterNodeSeriesName
                }

                $unitFunction=$Function:GetClusterNodeUnits
            }

            "ByVirtualMachine"
            {
                foreach($virtualMachine_ in $VirtualMachine)
                {
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($virtualMachine_.VMId)" -ObjectTypeName_ "VM" -ObjectDescription_ "VirtualMachine $($virtualMachine_.Name)" -SourceSeriesName_ $VirtualMachineSeriesName
                }

                $unitFunction=$Function:GetVMUnits
            }
            "ByVHD"
            {
                foreach($vhd_ in $VHD)
                {
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($vhd_.Path)" -ObjectTypeName_ "VHD" -ObjectDescription_ "VHD $($vhd_.Path)" -SourceSeriesName_ $VHDSeriesName
                }

                $unitFunction=$Function:GetVHDUnits
            }
            "ByPhysicalDisk"
            {
                foreach($physicalDisk_ in $PhysicalDisk)
                {
                    $subObjectId =$physicalDisk_.ObjectId.Replace("`"","").Split(":")
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($subObjectId[$subObjectId.Count -1])" -ObjectTypeName_ "Disk" -ObjectDescription_ "PhysicalDisk $($physicalDisk_.SerialNumber)" -SourceSeriesName_ $PhysicalDiskSeriesName
                }

                $unitFunction=$Function:GetPhysicalDiskUnits
            }
            "ByVolume"
            {
                foreach($volume_ in $Volume)
                {
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($volume_.UniqueId)" -ObjectTypeName_ "CSV_Volume" -ObjectDescription_ "Volume $($volume_.FileSystemLabel)" -SourceSeriesName_ $VolumeSeriesName
                }

                $unitFunction=$Function:GetVolumeUnits
            }
            "ByNetworkAdapter"
            {
                foreach($networkAdapter_ in $NetworkAdapter)
                {
                    $SeriesNames += Initalize-SeriesData -TagetId_ "$($networkAdapter_.InterfaceGuid)" -ObjectTypeName_ "networkadapter" -ObjectDescription_ "NetAdapter $($networkAdapter_.InterfaceDescription)" -SourceSeriesName_ $NetworkAdapterSeriesName
                }

                $unitFunction=$Function:GetNetworkAdapterUnits
            }
            API
            {

            }
            default
            {
                Write-Error -Message "Not Supported $type"
                return
            }
        }

        Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 30 -CurrentOperation "Gathering objects done" -Status "1/4"

        $apiScriptBlock = {
            param(
                $blockSession,
                [string]$blockKey,
                [string]$blockStreamName,
                $blockFlags
            )

            Import-Module FailoverClusters\ClusterHealthService.cdxml -Verbose:$false

            Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 60 -CurrentOperation "Executing method" -Status "2/4"

            Write-Verbose -Message "SeriesName: '$blockKey' StreamName:'$blockStreamName'"

            # Although its only one key we need to make it an array for WMI
            [string[]]$blockMetricNames=@()
            $blockMetricNames+=$blockKey

            $outputResults = Get-ClusterHealth -CimSession $blockSession | Invoke-CimMethod -MethodName GetMetric -CimSession $blockSession -Arguments @{MetricName=$blockMetricNames;StreamName=$blockStreamName;Flags=$blockFlags} -ErrorAction Stop

            Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 70 -CurrentOperation "Executing method" -Status "3/4"

            foreach($output in $outputResults)
            {
                $member = $output | Get-Member
                if($member[0].TypeName.ToString().Equals("Microsoft.Management.Infrastructure.CimMethodResult#MSCluster_ClusterHealthService#GetMetric", [stringcomparison]::CurrentCultureIgnoreCase))
                {
                    Write-Verbose -Message "Result: $($output.ReturnValue)"
                }
                else
                {
                    $script:results += $output.ItemValue
                }
            }

            Write-Progress -Activity "Get-ClusterPerformanceHistory" -Completed -Status "4/4"
        }

        $defaultScriptBlock = {
            param(
                $blockSession,
                $blockarray,
                [string]$blockStreamName,
                $blockFlags,
                [scriptblock]$blockUnitFunction
            )

            # Cast the objectarray to the right type.
            $blockSeriesNames = $blockarray
            Import-Module FailoverClusters\ClusterHealthService.cdxml -Verbose:$false

            Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 40 -CurrentOperation "Executing method" -Status "2/4"

            [string[]]$blockMetricNames =@()
            $blockMetricNames = $blockSeriesNames.Keys

            $outputResults = Get-ClusterHealth -CimSession $blockSession | Invoke-CimMethod -MethodName GetMetric -CimSession $blockSession -Arguments @{MetricName=$blockMetricNames;StreamName=$blockStreamName;Flags=$blockFlags} -ErrorAction Stop

            Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete 70 -CurrentOperation "Executing method" -Status "3/4"

            $percentageComplete = 70;
            $percentageDisplay = 70;
            $percentageIncrement = 1

            foreach($output in $outputResults.ItemValue)
            {
                if($null -eq $output.MetricId)
                {
                    continue
                }

                $blockObjectName = $blockSeriesNames.Get_Item($output.MetricId)
                $output | Add-Member -MemberType NoteProperty -Name ObjectDescription -Value $blockObjectName
                $output | Add-Member -MemberType NoteProperty -Name Units -Value $($blockUnitFunction.Invoke($output.MetricId) )

                if($i++ % 350 -eq 0)
                {
                    if($percentageDisplay -gt 99)
                    {
                        $percentageDisplay = 70
                    }

                    Write-Progress -Activity "Get-ClusterPerformanceHistory" -PercentComplete $percentageDisplay -CurrentOperation "Executing method" -Status "3/4"
                    $percentageDisplay++
                }
            }

            $script:results += $outputResults[0..$outputResults.count].ItemValue
            Write-Progress -Activity "Get-ClusterPerformanceHistory" -Completed -Status "4/4"
        }

        switch($psCmdlet.ParameterSetName)
        {
            "Api"
            {
                if($psCmdlet.ShouldProcess("Using TimeFrame $($Stream) for: $SeriesKeyName", "Get-Metric"))
                {
                    &$apiScriptBlock $CimSession $SeriesKeyName $Stream $flags
                }
            }
            default
            {
                if ($psCmdlet.ShouldProcess("Using TimeFrame $($TimeFrame) for:`n$($SeriesNames.Keys)", "Get-Metric") )
                {
                    &$defaultScriptBlock $CimSession $SeriesNames $TimeFrame $flags $unitFunction
                }
            }
        }
    }

    End
    {
        switch($psCmdlet.ParameterSetName)
        {
            "Api"
            {
                if($asGroupObject)
                {
                    $groupObjects = $script:results | Group-Object MetricId
                    foreach($groupObject in $groupObjects)
                    {
                        # Inject the type name for custom formatting
                        $groupObject.psobject.TypeNames.Insert(0,"Microsoft.FailoverClusters.Health.PowerShell.MetricGroupInfoApi") | Out-Null
                    }

                    return $groupObjects
                }
                else
                {
                    return $script:results
                }
            }
            default
            {
                if($asGroupObject)
                {
                    $groupObjects = $script:results | Group-Object MetricId
                    foreach($groupObject in $groupObjects)
                    {
                        # Inject the type name for custom formatting
                        $groupObject.psobject.TypeNames.Insert(0,"Microsoft.FailoverClusters.Health.PowerShell.MetricGroupInfo") | Out-Null
                        $objectName = $groupObject.Group[0].ObjectDescription

                        # Inject the object that requested the metric report
                        $groupObject | Add-Member -MemberType NoteProperty -Name ObjectDescription -Value $objectName
                    }
                
                    return $groupObjects
                }
                else
                {
                    return $script:results | Sort-Object ObjectDescription,MetricId
                }
            }
        }
    }
}
Set-Alias Get-ClusterPerf -Value Get-ClusterPerformanceHistory

function Get-HealthFault
{
    [CmdletBinding(DefaultParameterSetName="ByCluster", SupportsShouldProcess, ConfirmImpact="none")]
    param
    (
        [Microsoft.FailoverClusters.PowerShell.Cluster]
        [parameter(
            Position=0,
            Mandatory=$false,
            ParameterSetName="ByCluster",
            ValueFromPipeline= $true
        )]
        $Cluster,

        [parameter(
            Position=0,
            Mandatory=$True,
            ParameterSetName="ByApi",
            ValueFromPipeline=$false
        )]
        $ReportingType,

        [parameter(
            Position=1,
            Mandatory=$True,
            ParameterSetName="ByApi",
            ValueFromPipeline=$false
        )]
        $ReportingKey,

        [Microsoft.Management.Infrastructure.CimSession]
        $CimSession
    )

    Begin
    {
        Import-Module FailoverClusters\ClusterHealthService.cdxml -Verbose:$false
        $script:results=@()
    }

    Process
    {
        [System.String]$ReportingType_ = $null
        [System.String]$ReportingKey_ = $null

        Write-Progress -Activity "Get-HealthFault" -PercentComplete 0 -CurrentOperation "Gathering objects" -Status "0/4"

        if (-not $CimSession)
        {
            $CimSession = New-CimSession -Verbose:$false
        }

        switch($psCmdlet.ParameterSetName)
        {
            "ByCluster"
            {
                #For cluster we allow the default to be the local cluster.
                #If no local cluster then exit.
                if(-not $Cluster)
                {
                    $Cluster = Get-Cluster
                }

                $ReportingKey_ = $Cluster.Name
                $ReportingType_ = "Microsoft.Health.EntityType.Cluster"
            }
            "ByApi"
            {
                $ReportingKey_=$ReportingKey
                $ReportingType_=$ReportingType
            }
            default
            {
                return
            }
        }

        Write-Progress -Activity "Get-HealthFault" -PercentComplete 30 -CurrentOperation "Gathering objects done" -Status "1/4"

        $scriptBlock = {
            [CmdletBinding()]
            param(
                #[Microsoft.Management.Infrastructure.CimSession]
                #Cannot special type it as it gets serialized and deserialized differently
                $_CimSession,

                [System.String]
                $_ReportingKey,

                [System.String]
                $_ReportingType
            )

            process
            {
                Write-Progress -Activity "Get-HealthFault" -PercentComplete 60 -CurrentOperation "Executing  $($VerbosePreference)method" -Status "2/4"

                $script:results = Get-ClusterHealth -CimSession $_CimSession | Get-InternalHealthFault -ReportingKey $_ReportingKey -ReportingType $_ReportingType -ErrorAction Stop -CimSession $_CimSession

                Write-Progress -Activity "Get-HealthFault" -PercentComplete 90 -CurrentOperation "Processing results" -Status "3/4"

                # Sort the results by perceived Severity
                $script:results = $script:results | Sort-Object -Property PerceivedSeverity
            }
        }

        if($PSCmdlet.ShouldProcess("[$ReportingType_]$ReportingKey_", "Get-HealthFault"))
        {
            &$scriptBlock $CimSession $ReportingKey_ $ReportingType_
        }
    }

    End
    {
        Write-Progress -Activity "Get-HealthFault" -Completed -Status "4/4"
        return $script:results
    }
}

Export-ModuleMember Get-ClusterPerformanceHistory 
Export-ModuleMember -Alias Get-ClusterPerf
Export-ModuleMember Get-HealthFault