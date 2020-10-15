#Load Configuration Manager PowerShell Module
Import-module($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+'\ConfigurationManager.psd1')

#Set Globl variables
$Global:LineSeparator="---------------------------------------------------------------------------------------------------------------------------"
$Global:OffRoot=@(
    "Endpoint Protection",
    "Operational",
    "Security Updates",
    "Sites")
$Global:ParentFolder=@(
    $OffRoot[0],
    $OffRoot[1],
    "Clients",
    "Classes: Server",
    "Inventory",
    "Hardware",
    $OffRoot[2],
    "Servers",
    "PeopleSoft")
$Global:FolderList=@(
    $ParentFolder[0],
    "Managed Clients",
    "Managed Servers",
    $ParentFolder[1],
    $ParentFolder[2],
	"Client Health",
	"Client Version",
    $ParentFolder[3],
    "Windows",
    "Linux",
    "Classes: Workstation",
    $ParentFolder[4],
    $ParentFolder[5],
    "Platform",
    "Software",
    "SCCM"
    $ParentFolder[6],
    $ParentFolder[7],
    "Infrastructure",
    $ParentFolder[8],
    "NON",
    "NRP",
    "PRD",
    "Workstations",
    $OffRoot[3])

#Global Multi-dimensional array for folder structure
$Global:FolderStructure=@(
    (0,$OffRoot[0]),
    (1,$FolderList[1]),
    (1,$FolderList[2]),
    (0,$OffRoot[1]),
    (2,$ParentFolder[2]),
    (3,$FolderList[5]),
    (3,$FolderList[6]),
    (3,$ParentFolder[3]),
    (4,$FolderList[8]),
    (4,$FolderList[9]),
    (3,$FolderList[10]),
    (2,$ParentFolder[4]),
    (5,$ParentFolder[5]),
    (6,$FolderList[13]),
    (5,$FolderList[14]),
    (2,$FolderList[15]),
    (0,$OffRoot[2]),
    (7,$ParentFolder[7]),
    (8,$FolderList[18]),
    (8,$ParentFolder[8]),
    (9,$FolderList[20]),
    (9,$FolderList[21]),
    (9,$FolderList[22]),
    (7,$FolderList[23]),
    (0,$OffRoot[3]))

#Set temporary output file for reading output into variables
Set-Variable -Name OutputFile -Value "$env:USERPROFILE\Desktop\$($(Split-Path $PSCommandPath -Leaf).Split(".")[0]).log"

Function Get-FolderPath{[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Server Name”,ValueFromPipelineByPropertyName=$true)]$SiteServer="",
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Site Code”,ValueFromPipelineByPropertyName=$true)][ValidatePattern("\w{3}")][String]$SiteCode="",
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Folder Name”,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String[]]$FolderName=""
    )
    Process{
        $Folder=Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_ObjectContainernode -Filter "ObjectType = 5000 and Name = '$FolderName'"
        If($Folder.ParentContainerNodeId-ne0){
            $ObjectFolder=$Folder.Name
            If($Folder.ParentContainerNodeID-eq0){
                $ParentFolder=$false
            }Else{
                $ParentFolder=$true
                $ParentContainerNodeID=$Folder.ParentContainerNodeID
            }
            Try{
                While($ParentFolder-eq$true){
                    $ParentContainerNode=Get-Wmiobject -Namespace root/SMS/site_$SiteCode -ComputerName $SiteServer -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ParentContainerNodeID'" -ErrorAction SilentlyContinue
                    $ObjectFolder=$ParentContainerNode.Name+"\"+$ObjectFolder
                    If($ParentContainerNode.ParentContainerNodeID-eq0){
                        $ParentFolder=$false
                    }Else{
                        $ParentContainerNodeID=$ParentContainerNode.ParentContainerNodeID
                    }
                }
                $ObjectFolder=$SiteCode+":\DeviceCollection\"+$ObjectFolder
                Return $ObjectFolder
            }Catch{
                Write-Host -ForegroundColor Red ("Failed to create folder: """+$Folder+""" on Site Server "+$SiteServer+".")
            }
        }Else{
            $ObjectFolder=$SiteCode+":\DeviceCollection\"+$FolderName
            Return $ObjectFolder
        }
    }End{}
}
Function Get-CollectionsInFolder{[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Server Name”,ValueFromPipelineByPropertyName=$true)]$SiteServer="",
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Site Code”,ValueFromPipelineByPropertyName=$true)][ValidatePattern("\w{3}")][String]$SiteCode="",
        [Parameter(Mandatory=$true,HelpMessage=”Microsoft Endpoint Configuration Manager - Folder Name”,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String[]]$FolderName="",
	    [Parameter(Mandatory=$false)][String][ValidateRange("Device","User")]$FolderType="Device"
    )
    Begin{
        Switch($FolderType){
            "Device"{$ObjectType="5000";Break}
            "User"{$ObjectType="5001";Break}
        }
	}
    Process{
        ForEach($FolderN In $FolderName){
            Try{
                $Folder=Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_ObjectContainernode -Filter "ObjectType = $ObjectType and Name = '$FolderN'" -ErrorAction SilentlyContinue
                If($Folder-ne$null){
                    "Folder: {0} ({1})" -f $Folder.Name, $Folder.ContainerNodeID|Out-File -FilePath $OutputFile -Append
                    Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_ObjectContainerItem -Filter "ContainerNodeID = $($Folder.ContainerNodeID)"|Select @{Label="CollectionName"
                        ;Expression={(Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_Collection -Filter "CollectionID = '$($_.InstanceKey)'").Name}},@{Label="CollectionID"
                        ;Expression={$_.InstanceKey}}|Out-File -FilePath $OutputFile -Append
                }Else{
                    Write-Host "$FolderType folder name: $FolderName not found"
                }
            }Catch{
                Write-Host -ForegroundColor Red ("Failed to create folder: """+$FolderN+""" on Site Server "+$SiteServer+".")
            }
        }
    }End{}
 }
Function Get-ObjectLocation{Param([String]$InstanceKey)
    Set-Variable -Name QueryStatement -Value "SELECT ocn.* FROM SMS_ObjectContainerNode AS ocn JOIN SMS_ObjectContainerItem AS oci ON ocn.ContainerNodeID=oci.ContainerNodeID WHERE oci.InstanceKey='$InstanceKey'"
    $ContainerNode=Get-Wmiobject -Namespace root/SMS/site_$($Site) -ComputerName $SiteServer -Query $QueryStatement
    If($ContainerNode-ne$null){
        $ObjectFolder=$ContainerNode.Name
        If($ContainerNode.ParentContainerNodeID-eq0){
            $ParentFolder=$false
        }Else{
            $ParentFolder=$true
            $ParentContainerNodeID=$ContainerNode.ParentContainerNodeID
        }
        Try{
            While($ParentFolder-eq$true){
                $ParentContainerNode=Get-Wmiobject -Namespace root/SMS/site_$Site -ComputerName $SiteServer -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ParentContainerNodeID'" -ErrorAction SilentlyContinue
                $ObjectFolder=$ParentContainerNode.Name+"\"+$ObjectFolder
                If($ParentContainerNode.ParentContainerNodeID-eq0){
                    $ParentFolder=$false
                }Else{
                    $ParentContainerNodeID=$ParentContainerNode.ParentContainerNodeID
                }
            }
            $ObjectFolder="Root\"+$ObjectFolder
            Return $ObjectFolder
        }Catch{
            Write-Host -ForegroundColor Red ("Failed to create folder: """+$ContainerNode+""" on Site Server "+$SiteServer+".")
        }
    }Else{
        $ObjectFolder="Root"
        Return $ObjectFolder
    }
}

#Get SiteCode
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
Set-Variable -Name SiteName -Value $null
Set-Variable -Name SiteNames -Value @{}
$SiteNames="ARDC","UDCC"
#Get user domain
$LDomain=($env:USERDNSDOMAIN).ToLower()
$UDomain=($env:USERDNSDOMAIN).ToUpper()
Clear-History;Clear-Host

ForEach($Site In $SiteCode){
    #Set location within the SCCM environment
    Set-location $Site":"
    #Get SiteServer
    Switch($Site){
        "DFW"{$SiteName=$SiteNames[0];$SiteServer=$($($(Get-PSDrive -PSProvider CMSite).Root)[1]).Split(".")[0];Break}
        "AUS"{$SiteName=$SiteNames[1];$SiteServer=$($($(Get-PSDrive -PSProvider CMSite).Root)[0]).Split(".")[0];Break}
        Default{$SiteName="";$SiteServer=$($($(Get-PSDrive -PSProvider CMSite).Root)[2]).Split(".")[0];Break}
    }
    If($Site-eq"SIS"){
        #Create Folder structure
        ForEach($Folder In $FolderStructure){
            $NewFolder=$null;$ParentContainer=$null;$ContainerData=$null
            Switch($Folder[0]){
                "1"{$ParentContainer=$ParentFolder[0];Break} #Endpoint Protection
                "2"{$ParentContainer=$ParentFolder[1];Break} #Operational
                "3"{$ParentContainer=$ParentFolder[2];Break} #Clients
                "4"{$ParentContainer=$ParentFolder[3];Break} #Servers
                "5"{$ParentContainer=$ParentFolder[4];Break} #Inventory
                "6"{$ParentContainer=$ParentFolder[5];Break} #Hardware
                "7"{$ParentContainer=$ParentFolder[6];Break} #Security Updates
                "8"{$ParentContainer=$ParentFolder[7];Break} #Servers
                "9"{$ParentContainer=$ParentFolder[8];Break} #PeopleSoft
                Default{$ContainerNodeID=0;Break}
            }
            If($Folder[0]-ne0){
                $ContainerNodeID=(Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$Site -Class SMS_ObjectContainernode -Filter "ObjectType = 5000 and Name = '$ParentContainer'").ContainerNodeID
            }
            $NewFolder=@{Name="$($Folder[1])";ObjectType=5000;ParentContainerNodeId=$ContainerNodeID}
            Try{
                $ContainerData=Set-WmiInstance -Namespace "root\sms\site_$($Site)" -Class "SMS_ObjectContainerNode" -Arguments $NewFolder -ComputerName $SiteServer -ErrorAction SilentlyContinue
                If($ContainerData-ne$null){
                    Write-Host -ForegroundColor Green ("Sucessfully created folder: """+$ContainerData.Name+""" on Site Server "+$SiteServer+".")
                }Else{
                    Write-Host -ForegroundColor Yellow ("Folder: """+$Folder[1]+""" already exists on Site Server "+$SiteServer+".")
                }
            }Catch{
                Write-Host -ForegroundColor Red ("Failed to create folder: """+$Folder[1]+""" on Site Server "+$SiteServer+".")
            }
        }
    }
}

#Set Default limiting collections
$LimitingCollection="All Systems"

#Refresh Schedule
$Schedule=New-CMSchedule –RecurInterval Days –RecurCount 7

#Find Existing Collections
$ExistingCollections=Get-CMDeviceCollection -Name "*"|Select-Object CollectionID, Name

#List of Collections Query
$DummyObject=New-Object -TypeName PSObject 
$Collections=@()

<#
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={""}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={""}},@{L="Folder"
; E={"root"}}
#> # Collection  Template

#> Collection <#1
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"All Systems assigned to $($SiteName)"}},@{L="Query"
    ; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SMSAssignedSites = ""$($Site)""")}},@{L="RuleName"
    ; E={@("All Client Systems assigned to $($SiteName)")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={"All Client Systems assigned to $($SiteName)"}},@{L="Folder"
    ; E={"root"}}
}
#> Collection <#2
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"All Systems assigned to $($SiteName) without SCCM Client"}},@{L="Query"
    ; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Client = 0 or SMS_R_System.Client is null ")}},@{L="RuleName"
    ; E={@("All Systems assigned to $($SiteName) without SCCM Client")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All Systems assigned to $($SiteName)"}},@{L="Comment"
    ; E={"All Client Systems assigned to $($SiteName)"}},@{L="Folder"
    ; E={"root"}}
}
#> Collection <#3
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All client servers in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Server%""")}},@{L="RuleName"
; E={@("All windows servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Desktop and Server Clients"}},@{L="Comment"
; E={"All windows servers"}},@{L="Folder"
; E={"Servers"}}
#> Collection <#4
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All client workstations in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Workstation%""")}},@{L="RuleName"
; E={@("All windows workstations")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Desktop and Server Clients"}},@{L="Comment"
; E={"All windows workstations"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#5
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All client systems in $LDomain"}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={0}},@{L="IncludeExcludeCollectionsCount"
; E={2}},@{L="IncludeCollections"
; E={@("All client servers in $LDomain","All client workstations in $LDomain")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Desktop and Server Clients"}},@{L="Comment"
; E={"All Systems"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#6
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Workstations"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from sms_r_system where Client = 1")}},@{L="RuleName"
; E={@("Managed Desktops")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"Endpoint Protection Managed Desktops"}},@{L="Folder"
; E={"Managed Clients"}}
#> Collection <#7
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - Domain Controller"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SystemOUName like ""%DOMAIN CONTROLLERS%""")}},@{L="RuleName"
; E={@("Domain Controllers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"Domain Controllers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#8
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - Configuration Manager"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SERVER_FEATURE on SMS_G_System_SERVER_FEATURE.ResourceId = SMS_R_System.ResourceId where SMS_G_System_SERVER_FEATURE.Name = ""Windows Server Update Services""")}},@{L="RuleName"
; E={@("Configuration Manager Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"Configuration Manager Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#9
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - DHCP"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SERVER_FEATURE on SMS_G_System_SERVER_FEATURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SERVER_FEATURE.Name = ""DHCP Server""")}},@{L="RuleName"
; E={@("DHCP Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"DHCP Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#10
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - SQL Server"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SERVER_FEATURE on SMS_G_System_SERVER_FEATURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SERVER_FEATURE.Name = ""SQL Server Connectivity""")}},@{L="RuleName"
; E={@("Microsoft SQL Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"Microsoft SQL Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#11
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - PUM Server"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%PUM%""")}},@{L="RuleName"
; E={@("Peoplesoft Update Manager Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={4}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("Endpoint Protection Managed Servers - Domain Controller","Endpoint Protection Managed Servers - Configuration Manager","Endpoint Protection Managed Servers - DHCP","Endpoint Protection Managed Servers - SQL Server")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"Peoplesoft Update Manager Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#12
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - File Server"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SERVER_FEATURE on SMS_G_System_SERVER_FEATURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SERVER_FEATURE.Name = ""File Server""")}},@{L="RuleName"
; E={@("File Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={5}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("Endpoint Protection Managed Servers - Domain Controller","Endpoint Protection Managed Servers - Configuration Manager","Endpoint Protection Managed Servers - DHCP","Endpoint Protection Managed Servers - SQL Server","Endpoint Protection Managed Servers - PUM Server")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"File Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#13
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - IIS"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SERVER_FEATURE on SMS_G_System_SERVER_FEATURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SERVER_FEATURE.Name = ""Web Server (IIS)""")}},@{L="RuleName"
; E={@("IIS Web Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={6}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("Endpoint Protection Managed Servers - Domain Controller","Endpoint Protection Managed Servers - Configuration Manager","Endpoint Protection Managed Servers - DHCP","Endpoint Protection Managed Servers - File Server","Endpoint Protection Managed Servers - SQL Server","Endpoint Protection Managed Servers - PUM Server")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"IIS Web Servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#14
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - Process Scheduler"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%$($SiteNaming)%""")}},@{L="RuleName"
; E={@("Process Scheduler Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={7}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("Endpoint Protection Managed Servers - Domain Controller","Endpoint Protection Managed Servers - Configuration Manager","Endpoint Protection Managed Servers - DHCP","Endpoint Protection Managed Servers - IIS","Endpoint Protection Managed Servers - File Server","Endpoint Protection Managed Servers - SQL Server","Endpoint Protection Managed Servers - PUM Server")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"Process Scheduler"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#15
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Endpoint Protection Managed Servers - Others"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System")}},@{L="RuleName"
; E={@("All windows servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={8}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("Endpoint Protection Managed Servers - Domain Controller","Endpoint Protection Managed Servers - Configuration Manager","Endpoint Protection Managed Servers - DHCP","Endpoint Protection Managed Servers - IIS","Endpoint Protection Managed Servers - File Server","Endpoint Protection Managed Servers - SQL Server","Endpoint Protection Managed Servers - PUM Server","Endpoint Protection Managed Servers - Process Scheduler")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All other windows servers"}},@{L="Folder"
; E={"Managed Servers"}}
#> Collection <#16
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Advanced Server 10.0"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 10.0""")}},@{L="RuleName"
; E={@("All Windows Server 2016 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#17
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Workstation 10.0"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Workstation 10.0""")}},@{L="RuleName"
; E={@("All Windows Workstation 10 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Windows Workstation 10 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#18
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Advanced Server 6.3"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 6.3""")}},@{L="RuleName"
; E={@("All Windows Server 2016 R2 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 R2 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#19
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Server 10.0"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 10.0""")}},@{L="RuleName"
; E={@("All Windows Server 2016 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#20
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Server 6.1"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.1""")}},@{L="RuleName"
; E={@("All Windows Server 2008 R2 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2008 R2 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#21
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Server 6.3"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.3""")}},@{L="RuleName"
; E={@("All Windows Server 2016 clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#22
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Workstation 10.0 (Tablet Edition)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Workstation 10.0 (Tablet Edition)""")}},@{L="RuleName"
; E={@("All Windows Workstation 10 (Tablet Edition) clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Windows Workstation 10 (Tablet Edition) clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#23
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Microsoft Windows NT Workstation 6.3 (Tablet Edition)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Workstation 6.3 (Tablet Edition)""")}},@{L="RuleName"
; E={@("All Windows Workstation 8.1 (Tablet Edition) clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Windows Workstation 8.1 (Tablet Edition) clients"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#24
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All client systems with unknown operating system"}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={0}},@{L="IncludeExcludeCollectionsCount"
; E={8}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Microsoft Windows NT Advanced Server 10.0","All Microsoft Windows NT Workstation 10.0","All Microsoft Windows NT Advanced Server 6.3","All Microsoft Windows NT Server 10.0","All Microsoft Windows NT Server 6.1","All Microsoft Windows NT Server 6.3","All Microsoft Windows NT Workstation 10.0 (Tablet Edition)","All Microsoft Windows NT Workstation 6.3 (Tablet Edition)")}},@{L="LimitingCollection"
; E={"All client systems in $LDomain"}},@{L="Comment"
; E={"All unknown client systems"}},@{L="Folder"
; E={"Security Updates"}}
#> Collection <#25
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 8.1 clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Workstation%6.3%"" and SMS_R_System.Build like ""6.3.%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 6.3 (Tablet Edition)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 6.3 (Tablet Edition)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#26
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients (1809)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Microsoft%Windows%Workstation%10.0%"" and SMS_R_System.Build like ""%17763%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0 on code (1809)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 10.0 on code (1809)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#27
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients (1803)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Microsoft%Windows%Workstation%10.0%"" and SMS_R_System.Build like ""%17134%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0 on code (1803)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 10.0 on code (1803)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#28
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients (1709)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Microsoft%Windows%Workstation%10.0%"" and SMS_R_System.Build like ""%16299%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0 on code (1709)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 10.0 on code (1709)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#29
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients (1703)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Microsoft%Windows%Workstation%10.0%"" and SMS_R_System.Build like ""%15063%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0 on code (1703)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 10.0 on code (1703)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#30
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients (1607)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Microsoft%Windows%Workstation%10.0%"" and SMS_R_System.Build like ""%14393%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0 on code (1607)")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Microsoft Windows NT Workstation 10.0 on code (1607)"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#31
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Ready to upgrade in All Windows Workstation 8.1 clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_UAComputerStatus on SMS_G_System_UAComputerStatus.ResourceId = SMS_R_System.ResourceId where SMS_G_System_UAComputerStatus.UpgradeAnalyticsStatus=""1""")}},@{L="RuleName"
; E={@("All Windows Workstations running 8.1 that are ready to upgrade")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows Workstation 8.1 clients"}},@{L="Comment"
; E={"All Windows Workstations running 8.1 that are ready to upgrade"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#32
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"$($SiteName) Workstations (SCCM Clients)"}},@{L="Query"
    ; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SMSAssignedSites = ""$($Site)""")}},@{L="RuleName"
    ; E={@("All client workstations assigned to $($SiteName)")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All client workstations in $LDomain"}},@{L="Comment"
    ; E={"All client workstations assigned to $($SiteName)"}},@{L="Folder"
    ; E={"Workstations"}}
}
#> Collection <#33
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Workstation 10 clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Workstation%10%""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Workstation 10.0")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={5}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Windows Workstation 10 clients (1809)","All Windows Workstation 10 clients (1803)","All Windows Workstation 10 clients (1709)","All Windows Workstation 10 clients (1703)","All Windows Workstation 10 clients (1607)")}},@{L="LimitingCollection"
; E={"All client workstations in $LDomain"}},@{L="Comment"
; E={"All Windows Workstation 10 clients"}},@{L="Folder"
; E={"Workstations"}}
#> Collection <#34
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"All Client Windows Servers ($($SiteName))"}},@{L="Query"
    ; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ADSiteName = ""$($SiteName)""")}},@{L="RuleName"
    ; E={@("All Client Windows Servers ($($SiteName))")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All client servers in $LDomain"}},@{L="Comment"
    ; E={"All Client Windows Servers ($($SiteName))"}},@{L="Folder"
    ; E={"Servers"}}
}
#> Collection <#35
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Servers"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like ""%Server%""")}},@{L="RuleName"
; E={@("All Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Servers"}},@{L="Folder"
; E={"Servers"}}
#> Collection <#36
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Domain Controller client servers in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System")}},@{L="RuleName"
; E={@("All Domain Controller windows servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"Endpoint Protection Managed Servers - Domain Controller"}},@{L="Comment"
; E={"All Domain Controller windows servers"}},@{L="Folder"
; E={"Infrastructure"}}
#> Collection <#37
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All NON client servers in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%DEV%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%DMO%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%TST%""")}},@{L="RuleName"
; E={@("All TST client servers in $LDomain","All DEV client servers in $LDomain","All DMO client servers in $LDomain")}},@{L="CollectionQueries"
; E={3}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All non-production windows servers"}},@{L="Folder"
; E={"NON"}}
#> Collection <#38
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All NRP client servers in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%CFG%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%CON%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%FLY%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%SBX%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%TRN%""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%TRN%""")}},@{L="RuleName"
; E={@("All CFG client servers in $LDomain","All CON client servers in $LDomain","All FLY client servers in $LDomain","All SBX client servers in $LDomain","All TRN client servers in $LDomain","All UAT client servers in $LDomain")}},@{L="CollectionQueries"
; E={6}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All near-production windows servers"}},@{L="Folder"
; E={"NRP"}}
#> Collection <#39
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All PRD client servers in $LDomain"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like ""%PRD%"" or SMS_R_System.Name like ""%RPT%""")}},@{L="RuleName"
; E={@("All production windows servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All production windows servers"}},@{L="Folder"
; E={"PRD"}}
#> Collection <#40
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All PeopleSoft client servers in $LDomain"}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={0}},@{L="IncludeExcludeCollectionsCount"
; E={3}},@{L="IncludeCollections"
; E={@("All NON client servers in $LDomain","All NRP client servers in $LDomain","All PRD client servers in $LDomain")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All PeopleSoft client servers"}},@{L="Folder"
; E={"PeopleSoft"}}
#> Collection <#41
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"All Infrastructure Servers ($($SiteName))"}},@{L="Query"
    ; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.IPSubnets = ""10.118.0.0"" or SMS_R_System.IPSubnets = ""10.118.1.0"" or SMS_R_System.IPSubnets = ""10.118.32.0""")}},@{L="RuleName"
    ; E={@("All Infrastructure Servers ($($SiteName)")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={2}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("All PeopleSoft client servers in $LDomain","All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
    ; E={"All client servers in $LDomain"}},@{L="Comment"
    ; E={"All Infrastructure Servers ($($SiteName)"}},@{L="Folder"
    ; E={"Infrastructure"}}
}
#> Collection <#42
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Infrastructure Servers"}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={0}},@{L="IncludeExcludeCollectionsCount"
; E={2}},@{L="IncludeCollections"
; E={@("All Infrastructure Servers (ARDC)","All Infrastructure Servers (UDCC)")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All client servers in $LDomain"}},@{L="Comment"
; E={"All Infrastructure Servers excluding Domain Controllers"}},@{L="Folder"
; E={"Infrastructure"}}
#> Collection <#43
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 clients (Infrastructure)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 10.0""")}},@{L="RuleName"
; E={@("All Windows Server 2016 clients (Infrastructure) excluding Domain Controllers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All Infrastructure Servers"}},@{L="Comment"
; E={"All Windows Server 2016 clients (Infrastructure) excluding Domain Controllers"}},@{L="Folder"
; E={"Infrastructure"}}
#> Collection <#44
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 R2 clients (Infrastructure)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.3""")}},@{L="RuleName"
; E={@("All Windows Server 2016 R2 clients (Infrastructure) excluding Domain Controllers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All Infrastructure Servers"}},@{L="Comment"
; E={"All Windows Server 2016 R2 clients (Infrastructure) excluding Domain Controllers"}},@{L="Folder"
; E={"Infrastructure"}}
#> Collection <#45
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2008 R2 clients (Infrastructure)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.1""")}},@{L="RuleName"
; E={@("All Windows Server 2008 R2 clients (Infrastructure) excluding Domain Controllers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={1}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("All Domain Controller client servers in $LDomain")}},@{L="LimitingCollection"
; E={"All Infrastructure Servers"}},@{L="Comment"
; E={"All Windows Server 2008 R2 clients (Infrastructure) excluding Domain Controllers"}},@{L="Folder"
; E={"Infrastructure"}}
#> Collection <#46
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 clients (NON)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 10.0""", "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 10.0""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 10.0","All Microsoft Windows NT Server 10.0")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NON client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"NON"}}
#> Collection <#47
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 R2 clients (NON)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 6.3""", "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.3""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 6.3","All Microsoft Windows NT Server 6.3")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NON client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 R2 clients"}},@{L="Folder"
; E={"NON"}}
#> Collection <#48
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2008 R2 clients (NON)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.1""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Server 6.1")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NON client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2008 R2 clients"}},@{L="Folder"
; E={"NON"}}
#> Collection <#49
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 clients (NRP)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 10.0""", "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 10.0""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 10.0","All Microsoft Windows NT Server 10.0")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NRP client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"NRP"}}
#> Collection <#50
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 R2 clients (NRP)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 6.3""", "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.3""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 6.3","All Microsoft Windows NT Server 6.3")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NRP client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 R2 clients"}},@{L="Folder"
; E={"NRP"}}
#> Collection <#51
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2008 R2 clients (NRP)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.1""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Server 6.1")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All NRP client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2008 R2 clients"}},@{L="Folder"
; E={"NRP"}}
#> Collection <#52
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 clients (PRD)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 10.0""", "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 10.0""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 10.0","All Microsoft Windows NT Server 10.0")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All PRD client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 clients"}},@{L="Folder"
; E={"PRD"}}
#> Collection <#53
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2016 R2 clients (PRD)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Advanced Server 6.3""","select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.3""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Advanced Server 6.3","All Microsoft Windows NT Server 6.3")}},@{L="CollectionQueries"
; E={2}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All PRD client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2016 R2 clients"}},@{L="Folder"
; E={"PRD"}}
#> Collection <#54
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows Server 2008 R2 clients (PRD)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion = ""Microsoft Windows NT Server 6.1""")}},@{L="RuleName"
; E={@("All Microsoft Windows NT Server 6.1")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All PRD client servers in $LDomain"}},@{L="Comment"
; E={"All Windows Server 2008 R2 clients"}},@{L="Folder"
; E={"PRD"}}
#> Collection <#55
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"$($SiteName) Workstations (No Client)"}},@{L="Query"
    ; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where (SMS_R_System.Client = 0 or SMS_R_System.Client is null ) and SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Workstation%""")}},@{L="RuleName"
    ; E={@("$($SiteName) - Client Workstations")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All Systems assigned to $($SiteName) without SCCM Client"}},@{L="Comment"
    ; E={"Collection for identifying workstations without SCCM Client"}},@{L="Folder"
    ; E={"Sites"}}
}
#> Collection <#56
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"$($SiteName) Servers (No Client)"}},@{L="Query"
    ; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where (SMS_R_System.Client = 0 or SMS_R_System.Client is null ) and SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Server%""")}},@{L="RuleName"
    ; E={@("$($SiteName) - Client Servers")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All Systems assigned to $($SiteName) without SCCM Client"}},@{L="Comment"
    ; E={"Collection for identifying servers without SCCM Client"}},@{L="Folder"
    ; E={"Sites"}}
}
#> Collection <#57
ForEach($SiteName In $SiteNames){
    $Collections+=
    $DummyObject|
    Select-Object @{L="Name"
    ; E={"$($SiteName) (Assigned Site)"}},@{L="Query"
    ; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SystemOUName = ""API.$UDomain/ALLSERVERS"" or SMS_R_System.SystemOUName = ""API.$UDomain/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""UAT.$UDomain/ALLSERVERS"" or SMS_R_System.SystemOUName = ""UAT.$UDomain/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""PRD.$UDomain/ALLSERVERS"" or SMS_R_System.SystemOUName = ""PRD.$UDomain/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""$UDomain/ALLWRKSTNS"" or SMS_R_System.SystemOUName = ""$UDomain/ALLSERVERS"" or SMS_R_System.SystemOUName = ""$UDomain/DOMAIN CONTROLLERS""")}},@{L="RuleName"
    ; E={@("$($SiteName) - Client systems")}},@{L="CollectionQueries"
    ; E={1}},@{L="IncludeExcludeCollectionsCount"
    ; E={0}},@{L="IncludeCollections"
    ; E={@("")}},@{L="ExcludeCollections"
    ; E={@("")}},@{L="LimitingCollection"
    ; E={"All Systems assigned to $($SiteName)"}},@{L="Comment"
    ; E={"Collection for identifying systems with SCCM Client"}},@{L="Folder"
    ; E={"Sites"}}
}
#> Collection <#58
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Client = 1")}},@{L="RuleName"
; E={@("All devices detected by SCCM")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices detected by SCCM"}},@{L="Folder"
; E={"Clients"}}
#> Collection <#59
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All without client software"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Client = 0 OR SMS_R_System.Client is NULL")}},@{L="RuleName"
; E={@("All devices without SCCM client installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices without SCCM client installed"}},@{L="Folder"
; E={"Clients"}}
#> Collection <#60
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All clients without at least version 1806"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion not like '5.00.8692.10%'")}},@{L="RuleName"
; E={@("All devices without SCCM client version 1806")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Clients"}},@{L="Comment"
; E={"All devices without SCCM client version 1806"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#61
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU1"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1203'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU1 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU1 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#62
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU2"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1303'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU2 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU2 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#63
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU3"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.7958.14%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU3 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU3 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#64
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU4"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1501'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU4 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU4 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#65
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU5"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1604'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU5 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU5 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#66
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 CU0"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1000'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 CU0 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU0 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#67
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 SP1"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8239.1000'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 SP1 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#68
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 SP1 CU1"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8239.1203'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 SP1 CU1 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU1 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#69
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 SP1 CU2"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8239.1301'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 SP1 CU2 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU2 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#70
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - R2 SP1 CU3"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8239.1403'")}},@{L="RuleName"
; E={@("All systems with SCCM client version R2 SP1 CU3 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU3 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#71
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1511"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8325.1000'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1511 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1511 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#72
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1602"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.8355.1000'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1602 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1602 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#73
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1606"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8412.100%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1606 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1606 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#74
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1610"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8458.100%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1610 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1610 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#75
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1702"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8498.100%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1702 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1702 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#76
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1706"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8540.100%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1706 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1706 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#77
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1710"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8577.100%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1710 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1710 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#78
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Clients Not Reporting since 14 Days"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_WORKSTATION_STATUS on SMS_G_System_WORKSTATION_STATUS.ResourceID = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_WORKSTATION_STATUS.LastHardwareScan,GetDate()) > 14)")}},@{L="RuleName"
; E={@("All devices with SCCM client that have not communicated with hardware inventory over 14 days")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Clients"}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with hardware inventory over 14 days"}},@{L="Folder"
; E={"Hardware"}}
#> Collection <#79
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Linux Clients"}},@{L="Query"
; E={@("select * from SMS_R_System where SMS_R_System.ClientEdition = 13")}},@{L="RuleName"
; E={@("All systems with Linux")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with Linux"}},@{L="Folder"
; E={"Linux"}}
#> Collection <#80
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All systems with the SCCM Console installed"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like '%Configuration Manager Console%'")}},@{L="RuleName"
; E={@("All systems with SCCM console installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM console installed"}},@{L="Folder"
; E={"SCCM"}}
#> Collection <#81
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"SCCM Site Servers"}},@{L="Query"
; E={@("select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System where SMS_R_System.SystemRoles = 'SMS Site Server'")}},@{L="RuleName"
; E={@("All systems that is SCCM site server")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM site server"}},@{L="Folder"
; E={"SCCM"}}
#> Collection <#82
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"SCCM Site Systems"}},@{L="Query"
; E={@("select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System where SMS_R_System.SystemRoles = 'SMS Site System' or SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)")}},@{L="RuleName"
; E={@("All systems that is SCCM site system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM site system"}},@{L="Folder"
; E={"SCCM"}}
#> Collection <#83
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Distribution Points"}},@{L="Query"
; E={@("select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System where SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)")}},@{L="RuleName"
; E={@("All systems that is SCCM distribution point")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM distribution point"}},@{L="Folder"
; E={"SCCM"}}
#> Collection <#84
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Server Systems"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where OperatingSystemNameandVersion like '%Server%'")}},@{L="RuleName"
; E={@("All servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All servers"}},@{L="Folder"
; E={"Classes: Server"}}
#> Collection <#85
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Active Servers"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0")}},@{L="RuleName"
; E={@("All servers with active state")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All servers with active state"}},@{L="Folder"
; E={"Classes: Server"}}
#> Collection <#86
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Physical Servers"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ResourceId not in (select SMS_R_SYSTEM.ResourceID from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_R_System.IsVirtualMachine = 'True') and SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Server%'")}},@{L="RuleName"
; E={@("All physical servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All physical servers"}},@{L="Folder"
; E={"Classes: Server"}}
#> Collection <#87
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Virtual Servers"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.IsVirtualMachine = 'True' and SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Server%'")}},@{L="RuleName"
; E={@("All virtual servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All virtual servers"}},@{L="Folder"
; E={"Classes: Server"}}
#> Collection <#88
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 2008 and 2008 R2"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Server 6.0%' or OperatingSystemNameandVersion like '%Server 6.1%'")}},@{L="RuleName"
; E={@("All servers with Windows 2008 or 2008 R2 operating system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All servers with Windows 2008 or 2008 R2 operating system"}},@{L="Folder"
; E={"Windows"}}
#> Collection <#89
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 2012 and 2012 R2"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Server 6.2%' or OperatingSystemNameandVersion like '%Server 6.3%'")}},@{L="RuleName"
; E={@("All servers with Windows 2012 or 2012 R2 operating system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All servers with Windows 2012 or 2012 R2 operating system"}},@{L="Folder"
; E={"Windows"}}
#> Collection <#90
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 2016"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Server 10%'")}},@{L="RuleName"
; E={@("All Servers with Windows 2016")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Server Systems"}},@{L="Comment"
; E={"All Servers with Windows 2016"}},@{L="Folder"
; E={"Windows"}}
#> Collection <#91
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Clients Not Reporting within 30 Days"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_LastSoftwareScan on SMS_G_System_LastSoftwareScan.ResourceId = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_LastSoftwareScan.LastScanDate,GetDate()) > 30)")}},@{L="RuleName"
; E={@("All devices with SCCM client that have not communicated with software inventory over 30 days")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with software inventory over 30 days"}},@{L="Folder"
; E={"Software"}}
#> Collection <#92
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Active Clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0")}},@{L="RuleName"
; E={@("All devices with SCCM client state active")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Clients"}},@{L="Comment"
; E={"All devices with SCCM client state active"}},@{L="Folder"
; E={"Client Health"}}
#> Collection <#93
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Inactive Clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 0 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0")}},@{L="RuleName"
; E={@("All devices with SCCM client state inactive")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Clients"}},@{L="Comment"
; E={"All devices with SCCM client state inactive"}},@{L="Folder"
; E={"Client Health"}}
#> Collection <#94
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Disabled Clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.UserAccountControl ='4098'")}},@{L="RuleName"
; E={@("All systems with client state disabled")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with client state disabled"}},@{L="Folder"
; E={"Client Health"}}
#> Collection <#95
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Obsolete Systems"}},@{L="Query"
; E={@("select * from SMS_R_System where SMS_R_System.Obsolete = 1")}},@{L="RuleName"
; E={@("All devices with SCCM client state obsolete")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client state obsolete"}},@{L="Folder"
; E={"Client Health"}}
#> Collection <#96
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"x86 Systems"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X86-based PC'")}},@{L="RuleName"
; E={@("All systems with 32-bit system type")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 32-bit system type"}},@{L="Folder"
; E={"Platform"}}
#> Collection <#97
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"x64 Systems"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X64-based PC'")}},@{L="RuleName"
; E={@("All systems with 64-bit system type")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 64-bit system type"}},@{L="Folder"
; E={"Platform"}}
#> Collection <#98
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Systems Created within last 24 hours"}},@{L="Query"
; E={@("select SMS_R_System.Name, SMS_R_System.CreationDate FROM SMS_R_System WHERE DateDiff(dd,SMS_R_System.CreationDate, GetDate()) <= 1")}},@{L="RuleName"
; E={@("All systems created in the last 24 hours")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems created in the last 24 hours"}},@{L="Folder"
; E={"Inventory"}}
#> Collection <#99
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Workstations"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where OperatingSystemNameandVersion like '%Workstation%'")}},@{L="RuleName"
; E={@("All workstations")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All workstations"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#102
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Active Workstations"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where (SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Workstation%' or SMS_R_System.OperatingSystemNameandVersion = 'Windows 7 Entreprise 6.1') and SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0")}},@{L="RuleName"
; E={@("All workstations with active state")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"All workstations with active state"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#103
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 8"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Workstation 6.2%'")}},@{L="RuleName"
; E={@("All workstations with Windows 8 operating system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"All workstations with Windows 8 operating system"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#104
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 8.1"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Workstation 6.3%'")}},@{L="RuleName"
; E={@("All workstations with Windows 8.1 operating system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"All workstations with Windows 8.1 operating system"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#105
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10"}},@{L="Query"
; E={@("select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System where OperatingSystemNameandVersion like '%Workstation 10.0%'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#106
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1507"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.10240'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system v1507")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1507"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#107
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1511"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.10586'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system v1511")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1511"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#108
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1607"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.14393'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system v1607")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1607"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#109
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1703"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.15063'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system v1703")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1703"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#110
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1709"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.16299'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 operating system v1709")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1709"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#111
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Current Branch (CB)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OSBranch = '0'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 CB")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CB"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#112
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Current Branch for Business (CBB)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OSBranch = '1'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 CBB")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CBB"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#113
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Long Term Servicing Branch (LTSB)"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OSBranch = '2'")}},@{L="RuleName"
; E={@("All workstations with Windows 10 LTSB")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 LTSB"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#114
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Support State - Current"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '2'")}},@{L="RuleName"
; E={@("Windows 10 Support State - Current")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"Windows 10 Support State - Current"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#115
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Support State - Expired Soon"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '3'")}},@{L="RuleName"
; E={@("Windows 10 Support State - Expired Soon")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"Windows 10 Support State - Expired Soon"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#116
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 Support State - Expired"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '4'")}},@{L="RuleName"
; E={@("Windows 10 Support State - Expired")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Workstations"}},@{L="Comment"
; E={"Windows 10 Support State - Expired"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#117
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1802"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8634.10%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1802 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1802 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#118
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Online Clients"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ResourceId in (select resourceid from SMS_CollectionMemberClientBaselineStatus where SMS_CollectionMemberClientBaselineStatus.CNIsOnline = 1)")}},@{L="RuleName"
; E={@("All Online Clients")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Online Clients"}},@{L="Folder"
; E={"Client Health"}}
#> Collection <#119
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Windows 10 v1803"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.17134'")}},@{L="RuleName"
; E={@("All Windows 10 v1803")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All workstations"}},@{L="Comment"
; E={"All Windows 10 v1803"}},@{L="Folder"
; E={"Classes: Workstation"}}
#> Collection <#120
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1806"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8692.10%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1806 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1806 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#121
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1810"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8740.10%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1810 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1810 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#122
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"Clients Version - 1902"}},@{L="Query"
; E={@("select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8790.10%'")}},@{L="RuleName"
; E={@("All systems with SCCM client version 1902 installed")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1902 installed"}},@{L="Folder"
; E={"Client Version"}}
#> Collection <#123
$Collections+=
$DummyObject|
Select-Object @{L="Name"
; E={"All Duplicate Device Name"}},@{L="Query"
; E={@("select R.ResourceID,R.ResourceType,R.Name,R.SMSUniqueIdentifier,R.ResourceDomainORWorkgroup,R.Client from SMS_R_System as r full join SMS_R_System as s1 on s1.ResourceId = r.ResourceId full join SMS_R_System as s2 on s2.Name = s1.Name where s1.Name = s2.Name and s1.ResourceId != s2.ResourceId")}},@{L="RuleName"
; E={@("All systems having a duplicate device record")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems having a duplicate device record"}},@{L="Folder"
; E={"Client Health"}}
#> # Customized Device Collections #


#Check Existing Collections
$Overwrite=1
$ErrorCount=0
$ErrorHeader="The script has already been run. The following collections already exist in your environment:`n`r"
$ErrorCollections=@()
$ErrorFooter="Would you like to delete and recreate the collections above? (Default : No) "
$ExistingCollections|Sort-Object Name|ForEach-Object{If($Collections.Name-Contains$_.Name){$ErrorCount+=1;$ErrorCollections+=$_.Name}}

#Error
If($ErrorCount-ge1){
    Write-Host $ErrorHeader $($ErrorCollections|ForEach-Object{(" "+$_+"`n`r")})$ErrorFooter -ForegroundColor Yellow -NoNewline
    $ConfirmOverwrite=Read-Host "[Y/N]"
    If($ConfirmOverwrite-ne"Y"){$Overwrite=0}
}

#Create Collection And Move the collection to the right folder
If($Overwrite-eq1){
    $ErrorCount=0
    ForEach($Collection In $($Collections|Sort-Object LimitingCollection -Descending)){
        If($ErrorCollections-Contains$Collection.Name){
            Get-CMDeviceCollection -Name $Collection.Name|Remove-CMDeviceCollection -Force
            Write-host *** Collection $Collection.Name removed and will be recreated ***
        }
    }
    ForEach($Collection In $Collections){
        Try{
            New-CMDeviceCollection -Name $Collection.Name -Comment $Collection.Comment -LimitingCollectionName $Collection.LimitingCollection -RefreshSchedule $Schedule -RefreshType 2|Out-Null
            Set-Variable -Name QueryCount -Value $Collection.CollectionQueries
            If($Collection.CollectionQueries-gt0){
                $QueryExpression=$null;$RuleName=$null
                If($Collection.CollectionQueries-gt1){
                    For($QueryCount=0;$QueryCount-lt$Collection.CollectionQueries;$QueryCount++){
                        Switch($QueryCount){
                            Default{$QueryExpression=$Collection.Query[$QueryCount];$RuleName=$Collection.RuleName[$QueryCount];Break}
                        }
                        If(!($QueryExpression-eq$null)){
                            Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $QueryExpression -RuleName $RuleName
                        }
                    }
                }Else{
                    $QueryExpression=$Collection.Query
                    $RuleName=$Collection.RuleName
                    Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $QueryExpression -RuleName $RuleName
                }
            }
            If($Collection.IncludeExcludeCollectionsCount-gt0){
                $Include=$null;$Exclude=$null
                If($Collection.IncludeExcludeCollectionsCount-gt1){
                    For($Count=0;$Count-lt$Collection.IncludeExcludeCollectionsCount;$Count++){
                        $VerifyCollection=$null
                        Switch ($Count){
                            Default{$Include=$Collection.IncludeCollections[$Count];$Exclude=$Collection.ExcludeCollections[$Count];Break}
                        }
                        If(!($Include-eq$null)){
                            $VerifyCollection=Get-CMDeviceCollection -Name $Include
                            If(!($VerifyCollection-eq$null)){
                                Add-CMDeviceCollectionIncludeMembershipRule -CollectionName $Collection.Name -IncludeCollectionName $Include
                            }Else{
                                Write-host -ForegroundColor Red ("The collection: """+$Include+""" doesn't exist and can't be included.")
                            }
                        }
                        If(!($Exclude-eq$null)){
                            $VerifyCollection=Get-CMDeviceCollection -Name $Exclude
                            If(!($VerifyCollection-eq$null)){
                                Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $Collection.Name -ExcludeCollectionName $Exclude
                            }Else{
                                Write-host -ForegroundColor Red ("The collection: """+$Exclude+""" doesn't exist and can't be excluded.")
                            }
                        }
                    }
                }Else{
                    $VerifyCollection=$null
                    $Include=$Collection.IncludeCollections
                    $Exclude=$Collection.ExcludeCollections
                    If(!($Include-eq"")){
                        $VerifyCollection=Get-CMDeviceCollection -Name $Include
                        If(!($VerifyCollection-eq$null)){
                            Add-CMDeviceCollectionIncludeMembershipRule -CollectionName $Collection.Name -IncludeCollectionName $Include
                        }Else{
                            Write-host -ForegroundColor Red ("The collection: """+$Include+""" doesn't exist and can't be included.")
                        }
                    }
                    If(!($Exclude-eq"")){
                        $VerifyCollection=Get-CMDeviceCollection -Name $Exclude
                        If(!($VerifyCollection-eq$null)){
                            Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $Collection.Name -ExcludeCollectionName $Exclude
                        }Else{
                            Write-host -ForegroundColor Red ("The collection: """+$Exclude+""" doesn't exist and can't be excluded.")
                        }
                    }
                }
            }
            Write-host -ForegroundColor Green ("*** Collection $($Collection.Name) created ***")
        }Catch{
            Write-host $LineSeparator
            Write-host -ForegroundColor Red ("There was an error creating the: "+$Collection.Name+" collection.")
            Write-host $LineSeparator
            $ErrorCount+=1
            Pause
        }
        If(!($Collection.Folder-eq"root")){
            $FolderPath=(Get-FolderPath -SiteServer $SiteServer -Site $Site -FolderName $Collection.Folder)
            Try{
                Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $Collection.Name)
                Write-host -ForegroundColor Cyan ("*** Collection $($Collection.Name) moved to $($Collection.Folder) folder***")
            }Catch{
                Write-host $LineSeparator
                Write-host -ForegroundColor Red ("There was an error moving the: "+$Collection.Name+" collection to "+$Collection.Folder+".")
                Write-host $LineSeparator
                $ErrorCount+=1
                Pause
            }
        }
    }
    If($ErrorCount-ge1){
        Write-host $LineSeparator
        Write-Host -ForegroundColor Red "The script execution completed, but with errors."
        Write-host $LineSeparator
        Pause
    }Else{
        Write-host $LineSeparator
        Write-Host -ForegroundColor Green "Script execution completed without error. Operational Collections created sucessfully."
        Write-host $LineSeparator
        Pause
    }
}Else{
    Write-host $LineSeparator
    Write-host -ForegroundColor Red("The following collections already exist in your environment:`n`r"+$($ErrorCollections|ForEach-Object{(" "+$_+"`n`r")})+"Please delete all collections manually or rename them before re-executing the script! You can also select Y to do it automaticaly")
    Write-host $LineSeparator
    Pause
}
#Get list of Folders and Collections within those folders
Write-Host -ForegroundColor Yellow ("Processing the folders/collections list for: """+$Site+"""")|Out-File -FilePath $OutputFile
Get-CollectionsInFolder -SiteServer $SiteServer -Site $Site -FolderName $FolderList|Out-Null

#Clear the screen and display output file
Clear-History;Clear-Host

#Process output file
Set-Variable -Name CollectionID -Value $null
ForEach($Line In [System.IO.File]::ReadLines($OutputFile)){
    $CollectionID=$null
    If($Line-like"*Folder*"){
        Write-host $LineSeparator
        Write-Host -ForegroundColor Cyan("    Reading contents of "+$Line+".")
    }ElseIf($Line-like"*$($Site)*"){
        $Words=$Line.Split(" ")
        ForEach($Word In $Words){
            If($Word-like"*$($Site)*"){
                $CollectionID=$Word;Break
            }
        }
        If($CollectionID-ne$null){
            $FullPath=Get-ObjectLocation -InstanceKey $CollectionID
            Write-Host -ForegroundColor Green("        "+$FullPath+"\"+$Line)
        }
    }
}

#Clean up temporary output files
If(Test-Path -LiteralPath $OutputFile){Remove-Item $OutputFile -Force}

#Return powershell prompt back to root drive
Set-Location "$env:SystemRoot\System32"
