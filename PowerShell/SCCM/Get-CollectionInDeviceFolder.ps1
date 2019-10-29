Clear-History;Clear-Host
Function Get-CollectionsInFolder{
<#
    .SYNOPSIS
        A function for listing collections inside af configmgr 2012 device folder
        This function defaults to Device Collections! use FolderType parameter to switch to user collections
	
    .PARAMETER  siteServer
        NETBIOS or FQDN address for the configurations manager 2012 site server
	
    .PARAMETER  siteCide
        Site Code for the configurations manager 2012 site server
	
    .PARAMETER  FolderName
        Folder name(s) of the folder(s) to list
	
    .PARAMETER  FolderType
        Device or User Collection (Valid Inputs: Device, User)

    .EXAMPLE
        Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1" -folderName "Coretech"
        Listing all collections inside Coretech Folder on CTCM01
	
    .EXAMPLE
        Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1" -folderName "Coretech","HTA-Test"
        Listing all collections inside multiple folders
	
    .EXAMPLE
        "HTA-Test", "Coretech" | Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1"
        Listing all collections inside multiple folders using pipe
	
    .EXAMPLE
        Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1"  -FolderName "CCO" -FolderType "User"
        Listing all collections inside a user collection folder
	
    .INPUTS
        Accepts a collection of strings that contain folder name, and each folder will be processed
	
    .OUTPUTS
        Custom Object (Properties: CollectionName, CollectionID)
	
    .NOTES
        Developed by Jakob Gottlieb Svendsen - Coretech A/S
        Version 1.0
	
    .LINK
        https://blog.ctglobalservices.com
        https://blog.ctglobalservices.com/jgs
#>
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="Low")]param(
        [parameter(Mandatory=$true, HelpMessage=”System Center Configuration Manager 2012 Site Server - Server Name”,ValueFromPipelineByPropertyName=$true)]$siteServer = "",
        [parameter(Mandatory=$true, HelpMessage=”System Center Configuration Manager 2012 Site Server - Site Code”,ValueFromPipelineByPropertyName=$true)][ValidatePattern("\w{3}")][String] $siteCode = "",
        [parameter(Mandatory=$true, HelpMessage=”System Center Configuration Manager 2012 Site Server - Folder Name”,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String[]]$folderName = "",
	    [parameter(Mandatory=$false)][String][ValidateRange("Device","User")]$FolderType = "Device"
    )
    Begin{
        Switch ($FolderType){
            "Device"{$ObjectType = "5000"}
            "User"{$ObjectType = "5001"}
        }
	}
    Process{
        ForEach($folderN In $folderName){
            $folder = get-wmiobject -ComputerName $siteServer -Namespace root\sms\site_$siteCode  -class SMS_ObjectContainernode -filter "ObjectType = $ObjectType AND NAme = '$folderN'"
            If($folder -ne $null){
                "Folder: {0} ({1})" -f $folder.Name, $folder.ContainerNodeID | out-host
                get-wmiobject -ComputerName $siteServer -Namespace root\sms\site_$siteCode  -class SMS_ObjectContainerItem -filter "ContainerNodeID = $($folder.ContainerNodeID)" | Select @{Label="CollectionName"
                    ;Expression={(get-wmiobject -ComputerName $siteServer -Namespace root\sms\site_$siteCode  -class SMS_Collection -filter "CollectionID = '$($_.InstanceKey)'").Name}},@{Label="CollectionID"
                    ;Expression={$_.InstanceKey}}
            }Else{
                Write-Host "$FolderType Folder Name: $folderName not found"
            }
        }
    }End{}
 }
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
$SiteServer=$($(Get-PSDrive -PSProvider CMSite).Root).Split(".")[0]
Set-Variable -Name CollectionFolderList -Value @("Endpoint Protection","Managed Clients","Managed Servers","Security Updates","Servers","Infrastructure","PeopleSoft","NON","NRP","PRD","Workstations","Sites")
Get-CollectionsInFolder -siteServer $SiteServer -siteCode $SiteCode -folderName $CollectionFolderList
#Examples
#Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1" -folderName "CCO" -FolderType User
#Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1" -folderName "Coretech","HTA-Test"
#"HTA-Test", "Coretech" | Get-CollectionsInFolder -siteServer "CTCM01" -siteCode "PS1"