<#
.SYNOPSIS
    Automatically remediate SCCM clients stuck in provisoning mode or clients having corrupt local group policy files. Two very common problems related to Configuration Manager Client Health
    
.EXAMPLES
    .\SCCM-ClientHealthMonitor.ps1 -TestProvMode -TestGPOFiles (this will run the test and remediation for both options and log to file locally)

    .\SCCM-ClientHealthMonitor.ps1 -TestProvMode -TestGPOFiles -SendEmail (this will run the test and remediation for both options and log to file locally and send an email with the log attached)
   
.DESCRIPTION
    A complete script that fixes two common problems related to Configuration Manager client health:
     
    SCCM clients stuck in provisioning mode has very limited capabilities and does not work properly.
    Windows with corrupt local group policy files are known for not scanning and reporting Software Updates compliance.

.NOTES
    Filename: SCCM-ClientHealthMonitor.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINKS
    My post about the script can be found here alongside some additional information: https://www.imab.dk/sccm-client-health-monitor-automatically-remediate-provisioning-mode-and-corrupt-local-group-policy-files/

    The remediation of the local group policy files are done with inspiration from this: https://itinlegal.wordpress.com/2017/09/09/psa-locating-badcorrupt-registry-pol-files/

    The Write-Log function in this script is this: https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
    
#> 

[CmdletBinding()]
param(
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$SendEmail,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$TestProvMode,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$TestGPOFiles
)

function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        
        # EDIT with your location for the local log file
        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path="$env:SystemRoot\" + "SCCM-ClientHealthMonitor.log",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}

if (-Not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log -Message "The script requires elevation"
    break
    }

$Logfile = "$env:SystemRoot\" + "SCCM-ClientHealthMonitor.log"
$Computer = $env:COMPUTERNAME

# Clearing variable for repeated testing
# Clear-Variable -Name Body
# Creating initial body area, including stylesheet

$Body = "
<html>
<head>
<style type='text/css'>
h1 {
    color: #f07f13;
    font-family: verdana;
    font-size: 20px;
}

h2 {
    color: ##002933;
    font-family: verdana;
    font-size: 15px;
}

body {
    color: #002933;
    font-family: verdana;
    font-size: 13px;
}
</style>
</head>
<h1>SCCM Client Health Monitor</h1>
<body>

</body>
</html>
"

############################ Beginning testing of Provisioning Mode ###############################

if ($PSBoundParameters["TestProvMode"]) {

    Write-Log "**** Beginning testing of SCCM provisioning mode on $Computer *****"
    
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\CCM\CcmExec"
    $ProvMode = (Get-ItemProperty -Path $RegistryPath -Name "ProvisioningMode").ProvisioningMode
    
    if (-Not(Test-Path -Path $RegistryPath)) {
        Write-Log -Message "Registry path not found - breaking" -Level Warn ; break
        }

    if ($ProvMode -eq "true"){
        Write-Log -Message "Provisioning mode = true. Continuing remediation" -Level Warn
        $ProvModeStatus = 1
        try {
            Write-Log -Message "Trying to pull $Computer out of provisioningmode"
            Invoke-WmiMethod -Namespace "root\ccm" -Class "SMS_Client" -Name "SetClientProvisioningMode" $false
        
            $ProvMode = (Get-ItemProperty -Path $RegistryPath -Name "ProvisioningMode").ProvisioningMode

            if ($ProvMode -eq "false") {
                Write-Log -Message "Good times - seems like we are no longer in provisioningmode" -Level Info
                $Body += $Computer + " was in provisioning mode, but we managed to remediate. Please find the log attached." + "<br>"
                }
        
            elseif ($ProvMode -eq "true"){
                Write-Log -Message "$Computer was in provisioning mode and we failed to remediate. Please investigate!"
                $Body += $Computer + " was in provisioningmode and we failed to remediate. Please investigate. The log is attached." + "<br>"
                }
            }

            catch {
                Write-Log -Message "Failed to do everything" -Level Warn
                }
        }

    elseif ($ProvMode -eq "false") {
        Write-Log -Message "Provisioning mode = false. Doing nothing"
        $ProvModeStatus = 0
        }

    else {
        Write-Log -Message "Something went really wrong. Need further troubleshooting." -Level Warn
        }

    Write-Log "**** Ending testing of SCCM provisioning mode on $Computer *****"
}

############################ Beginning testing of Registry Policy Files ###############################

if ($PSBoundParameters["TestGPOFiles"]) {

    Write-Log "**** Beginning testing of Registry Pol Files on $Computer *****"
    $MachineRegistryFile = "$env:Windir\System32\GroupPolicy\Machine\Registry.pol"
    $UserRegistryFile = "$env:Windir\System32\GroupPolicy\User\Registry.pol"
    $MachineFileContent = ((Get-Content -Encoding Byte -Path $MachineRegistryFile -TotalCount 4 -ErrorAction SilentlyContinue) -join '')
    $UserFileContent = ((Get-Content -Encoding Byte -Path $UserRegistryFile -TotalCount 4 -ErrorAction SilentlyContinue) -join '')

    if(-Not(Test-Path -Path $MachineRegistryFile -PathType Leaf)) {
        Write-Log -Message "Machine registry file not found" -Level Warn
        $MachineFileStatus = 0
    }
        
    else {
        if ($MachineFileContent -ne '8082101103') {
            Write-Log -Message "Machine registry file is corrupt" -Level Warn
            $MachineFileStatus = 1
        
            try { 
                Write-Log -Message "Trying to remove the machine policy file"
                Remove-Item $MachineRegistryFile -Force -ErrorAction SilentlyContinue
                $Body += $Computer + " had a corrupt machine policy file, but we managed to remediate. Please find the log attached." + "<br>"
                }
            catch {
                Write-Log -Message "Failed to remove machine policy file" -Level Warn
                $Body += $Computer + " has a corrupt machine policy file, and we failed to remediate. Please find the log attached." + "<br>"
                }

            }
        
        else {
            Write-Log -Message "Machine policy file is good. Doing nothing."
            $MachineFileStatus = 0
            }
    }

    if(-Not(Test-Path -Path $UserRegistryFile -PathType Leaf)) {
        Write-Log -Message "User registry file not found" -Level Warn
        $UserFileStatus = 0
    }
    
    else {
        if ($UserFileContent -ne '8082101103'){
            Write-Log -Message "User registry file is corrupt" -Level Warn
            $UserFileStatus = 1
        
            try {
                Write-Log -Message "Trying to remove the user policy file"
                Remove-Item $UserRegistryFile -Force -ErrorAction SilentlyContinue
                $Body += $Computer + " had a corrupt user policy file, but we managed to remediate. Please find the log attached." + "<br>"
                }
            catch {
                Write-Log -Message "Failed to remove user policy file" -Level Warn
                $Body += $Computer + " has a corrupt user policy file, and we failed to remediate. Please find the log attached." + "<br>"
                }
            }
    
        else {
            Write-Log -Message "User policy file is good. Doing nothing."
            $UserFileStatus = 0
            }
        }
    
    if (($MachineFileStatus -eq 0) -and ($UserFileStatus -eq 0)) {
        Write-Log -Message "Both registry files are all good. Doing nothing"
        $RegistryFilesStatus = 0
        }

    elseif (($MachineFileStatus -eq 1) -or ($UserFileStatus -eq 1)) {
        $RegistryFilesStatus = 1 
        }
    
    Write-Log "**** Ending testing of Registry Pol Files on $Computer *****"

}

if ($PSBoundParameters["SendEmail"]) {
    
    Write-Log -Message "SendEmail selected. Email will be send, if we have something to report"

    $AnonUsername = "anonymous"
    $AnonPassword = ConvertTo-SecureString -String "anonymous" -AsPlainText -Force
    $AnonCredentials = New-Object System.Management.Automation.PSCredential($AnonUsername,$AnonPassword)
    $SMTPServer = "YOUR SMTP SERVER HERE”
    $To = "RECIPIENT HERE"
    $From = "SCCM Client Health Monitor<SCCMMonitor@YourDomain.com>"
    $Subject = "SCCM Client Health Monitor"
    
    if (($ProvModeStatus -eq 1) -or ($RegistryFilesStatus -eq 1)) {
        Write-Log -Message "Sending status + logfile to intended receipient(s)" -Level Info
        Send-MailMessage -To $To -From $From -Subject $Subject -Body $Body -smtpServer $SMTPServer -BodyAsHtml -Credential $AnonCredentials -Attachments $Logfile
    }
}