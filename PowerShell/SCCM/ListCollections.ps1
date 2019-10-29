Clear-History;Clear-Host
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

#Set temporary output file for reading output into variables
Set-Variable -Name OutputFile -Value "$env:USERPROFILE\Desktop\$($(Split-Path $PSCommandPath -Leaf).Split(".")[0]).log"

Function Get-CollectionsInFolder{[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,HelpMessage=”System Center Configuration Manager 2016 Site Server - Server Name”,ValueFromPipelineByPropertyName=$true)]$SiteServer="",
        [Parameter(Mandatory=$true,HelpMessage=”System Center Configuration Manager 2016 Site Server - Site Code”,ValueFromPipelineByPropertyName=$true)][ValidatePattern("\w{3}")][String]$SiteCode="",
        [Parameter(Mandatory=$true,HelpMessage=”System Center Configuration Manager 2016 Site Server - Folder Name”,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String[]]$FolderName="",
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
            $Folder=Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_ObjectContainernode -Filter "ObjectType = $ObjectType AND NAme = '$FolderN'"
            If($Folder-ne$null){
                "Folder: {0} ({1})" -f $Folder.Name, $Folder.ContainerNodeID|Out-File -FilePath $OutputFile -Append
                Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_ObjectContainerItem -Filter "ContainerNodeID = $($Folder.ContainerNodeID)"|Select @{Label="CollectionName"
                    ;Expression={(Get-Wmiobject -ComputerName $SiteServer -Namespace root\sms\site_$SiteCode -Class SMS_Collection -Filter "CollectionID = '$($_.InstanceKey)'").Name}},@{Label="CollectionID"
                    ;Expression={$_.InstanceKey}}|Out-File -FilePath $OutputFile -Append
            }Else{
                Write-Host "$FolderType folder name: $FolderName not found"
            }
        }
    }End{}
 }
Function Get-ObjectLocation{Param([String]$InstanceKey)
    Set-Variable -Name QueryStatement -Value "SELECT ocn.* FROM SMS_ObjectContainerNode AS ocn JOIN SMS_ObjectContainerItem AS oci ON ocn.ContainerNodeID=oci.ContainerNodeID WHERE oci.InstanceKey='$InstanceKey'"
    $ContainerNode=Get-Wmiobject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query $QueryStatement
    If($ContainerNode-ne$null){
        $ObjectFolder=$ContainerNode.Name
        If($ContainerNode.ParentContainerNodeID-eq0){
            $ParentFolder=$false
        }Else{
            $ParentFolder=$true
            $ParentContainerNodeID=$ContainerNode.ParentContainerNodeID
        }
        While($ParentFolder-eq$true){
            $ParentContainerNode=Get-Wmiobject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ParentContainerNodeID'"
            $ObjectFolder=$ParentContainerNode.Name+"\"+$ObjectFolder
            If($ParentContainerNode.ParentContainerNodeID-eq0){
                $ParentFolder=$false
            }Else{
                $ParentContainerNodeID=$ParentContainerNode.ParentContainerNodeID
            }
        }
        $ObjectFolder="Root\"+$ObjectFolder
        Return $ObjectFolder
    }Else{
        $ObjectFolder="Root"
        Return $ObjectFolder
    }
}

#Get SiteServer and SiteCode
$SiteServer=$($(Get-PSDrive -PSProvider CMSite).Root).Split(".")[0]
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
Set-Variable -Name SiteName -Value $null
Switch($SiteCode){
    "A01"{$SiteName="ARDC";Break}
    "B01"{$SiteName="UDCC";Break}
    Default{$SiteName=$null;Break}
}

#Set location within the SCCM environment
Set-location $SiteCode":"

#Get list of Folders and Collections within those folders
Write-Host -ForegroundColor Yellow ("Processing the folders/collections list for: """+$SiteCode+"""")|Out-File -FilePath $OutputFile
Get-CollectionsInFolder -SiteServer $SiteServer -SiteCode $SiteCode -FolderName $FolderList|Out-Null

#Clear the screen and display output file
Clear-History;Clear-Host

#Process output file
Set-Variable -Name CollectionID -Value $null
ForEach($Line In [System.IO.File]::ReadLines($OutputFile)){
    $CollectionID=$null
    If($Line-like"*Folder*"){
        Write-host $LineSeparator
        Write-Host -ForegroundColor Cyan("    Reading contents of "+$Line+".")
    }ElseIf($Line-like"*$($SiteCode)*"){
        $Words=$Line.Split(" ")
        ForEach($Word In $Words){
            If($Word-like"*$($SiteCode)*"){
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
