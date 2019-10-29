
#region: Load VMware Snapin or Module (if not already loaded)  

if (!(Get-Module -Name VMware.VimAutomation.Core) -and (Get-Module -ListAvailable -Name VMware.VimAutomation.Core)) {  
    Write-Output "loading the VMware COre Module..."  
    if (!(Import-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {  
        # Error out if loading fails  
        Write-Error "`nERROR: Cannot load the VMware Module. Is the PowerCLI installed?"  
     }  
    $Loaded = $True  
    }  
    elseif (!(Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -and !(Get-Module -Name VMware.VimAutomation.Core) -and ($Loaded -ne $True)) {  
        Write-Output "loading the VMware Core Snapin..."  
     if (!(Add-PSSnapin -PassThru VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {  
     # Error out if loading fails  
     Write-Error "`nERROR: Cannot load the VMware Snapin or Module. Is the PowerCLI installed?"  
     }  
    }  
#endregion  

Connect-VIServer "vcmgra01.inf.utshare.local"

Get-Cluster -name PRD-A | Get-VMHost | ForEach {Stop-VMHostService -HostService ($_ | Get-VMHostService | Where {$_.Key -eq “TSM-SSH”})}