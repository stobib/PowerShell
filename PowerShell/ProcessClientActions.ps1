Function RunClientAction{[CmdletBinding()]param(
    [Parameter(Position=0,Mandatory=$True,HelpMessage="Provide server names",ValueFromPipeline=$true)][string[]]$Computername,
    [ValidateSet('MachinePolicy','DiscoveryData','ComplianceEvaluation','AppDeployment','HardwareInventory','UpdateDeployment','UpdateScan','SoftwareInventory')]
    [string[]]$ClientAction
)
    $ActionResults=@()
    Try{
        $ActionResults=Invoke-Command -ComputerName $Computername{param($ClientAction)} -ArgumentList $ClientAction -ErrorAction Stop | Select-Object @{n='Computer Name';e={$_.pscomputername}},"Action name",Status
        Foreach($Item in $ClientAction){
            $Object=@{} | Select-Object "Action name",Status
            Try{
                $ScheduleIDMappings=@{ 
                    'HardwareInventory'                            = '{00000000-0000-0000-0000-000000000001}'
                    'SoftwareInventory'                            = '{00000000-0000-0000-0000-000000000002}'
                    'DataDiscoveryRecord'                          = '{00000000-0000-0000-0000-000000000003}'
                    'FileCollection'                               = '{00000000-0000-0000-0000-000000000010}'
                    'IDMIFCollection'                              = '{00000000-0000-0000-0000-000000000011}'
                    'ClientMachineAuthentication'                  = '{00000000-0000-0000-0000-000000000012}'
                    'MachinePolicyAssignmentsRequest'              = '{00000000-0000-0000-0000-000000000021}'
                    'MachinePolicyEvaluation'                      = '{00000000-0000-0000-0000-000000000022}'
                    'RefreshDefaultMPTask'                         = '{00000000-0000-0000-0000-000000000023}'
                    'LSRefreshLocationsTask'                       = '{00000000-0000-0000-0000-000000000024}'
                    'LSTimeoutRefreshTask'                         = '{00000000-0000-0000-0000-000000000025}'
                    'PolicyAgentRequestAssignment'                 = '{00000000-0000-0000-0000-000000000026}'
                    'PolicyAgentEvaluateAssignment'                = '{00000000-0000-0000-0000-000000000027}'
                    'SoftwareMeteringGeneratingUsageReport'        = '{00000000-0000-0000-0000-000000000031}'
                    'SourceUpdateMessage'                          = '{00000000-0000-0000-0000-000000000032}'
                    'Clearingproxysettingscache'                   = '{00000000-0000-0000-0000-000000000037}'
                    'MachinePolicyAgentCleanup'                    = '{00000000-0000-0000-0000-000000000040}'
                    'UserPolicyAgentCleanup'                       = '{00000000-0000-0000-0000-000000000041}'
                    'PolicyAgentValidateMachinePolicy'             = '{00000000-0000-0000-0000-000000000042}'
                    'PolicyAgentValidateUserPolicy'                = '{00000000-0000-0000-0000-000000000043}'
                    'RefreshingcertificatesinADonMP'               = '{00000000-0000-0000-0000-000000000051}'
                    'PeerDPStatusreporting'                        = '{00000000-0000-0000-0000-000000000061}'
                    'PeerDPPendingpackagecheckschedule'            = '{00000000-0000-0000-0000-000000000062}'
                    'SUMUpdatesinstallschedule'                    = '{00000000-0000-0000-0000-000000000063}'
                    'HardwareInventoryCollectionCycle'             = '{00000000-0000-0000-0000-000000000101}'
                    'SoftwareInventoryCollectionCycle'             = '{00000000-0000-0000-0000-000000000102}'
                    'DiscoveryDataCollectionCycle'                 = '{00000000-0000-0000-0000-000000000103}'
                    'FileCollectionCycle'                          = '{00000000-0000-0000-0000-000000000104}'
                    'IDMIFCollectionCycle'                         = '{00000000-0000-0000-0000-000000000105}'
                    'SoftwareMeteringUsageReportCycle'             = '{00000000-0000-0000-0000-000000000106}'
                    'WindowsInstallerSourceListUpdateCycle'        = '{00000000-0000-0000-0000-000000000107}'
                    'SoftwareUpdatesAssignmentsEvaluationCycle'    = '{00000000-0000-0000-0000-000000000108}'
                    'BranchDistributionPointMaintenanceTask'       = '{00000000-0000-0000-0000-000000000109}'
                    'SendUnsentStateMessage'                       = '{00000000-0000-0000-0000-000000000111}'
                    'StateSystempolicycachecleanout'               = '{00000000-0000-0000-0000-000000000112}'
                    'ScanbyUpdateSource'                           = '{00000000-0000-0000-0000-000000000113}'
                    'UpdateStorePolicy'                            = '{00000000-0000-0000-0000-000000000114}'
                    'Statesystempolicybulksendhigh'                = '{00000000-0000-0000-0000-000000000115}'
                    'Statesystempolicybulksendlow'                 = '{00000000-0000-0000-0000-000000000116}'
                    'Applicationmanagerpolicyaction'               = '{00000000-0000-0000-0000-000000000121}'
                    'Applicationmanageruserpolicyaction'           = '{00000000-0000-0000-0000-000000000122}'
                    'Applicationmanagerglobalevaluationaction'     = '{00000000-0000-0000-0000-000000000123}'
                    'Powermanagementstartsummarizer'               = '{00000000-0000-0000-0000-000000000131}'
                    'Endpointdeploymentreevaluate'                 = '{00000000-0000-0000-0000-000000000221}'
                    'EndpointAMpolicyreevaluate'                   = '{00000000-0000-0000-0000-000000000222}'
                    'Externaleventdetection'                       = '{00000000-0000-0000-0000-000000000223}'
                }
                $ScheduleID=$ScheduleIDMappings[$item]
                Write-Verbose "Processing $Item - $ScheduleID"
                [void]([wmiclass] "root\ccm:SMS_Client").TriggerSchedule($ScheduleID);
                $Status="Success"
                Write-Verbose "Operation status - $status"
            }
            Catch{
                $Status="Failed"
                Write-Verbose "Operation status - $status"
            }
            $Object."Action name"=$item
            $Object.Status=$Status
            $Object
        }
    }
    Catch{
        Write-Error $_.Exception.Message
    }
    Return $ActionResults
}
RunClientAction -Computername $env:ComputerName -ClientAction 'AppDeployment','ComplianceEvaluation','SoftwareInventory'