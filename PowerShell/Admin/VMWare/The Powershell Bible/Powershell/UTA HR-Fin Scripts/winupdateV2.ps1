<# 
    .SYNOPSIS 
        Powershell Script to Install Updates Based on the Type of update 
    .DESCRIPTION 
        Using the WIndows Update API, Each update has a specific Root category. By selecting with Type of Update you want, you can avoid installing unwanted updates 
    .PARAMETER Reboot 
        If a reboot is required for an update, the system will restart. 
    .PARAMETER ScanOnly 
        As implies, It does not download or install updates, just lists the available ones based on criteria  
    .PARAMETER ProxyAddress 
        *THIS PARAMETER IS STILL BETA!!!* Instead of using the default windows update API, use another endpoint for updates.  
    .PARAMETER UpdateTypes 
        RootCategories that are associated with windows updates. Choose the types you wish to filter for.  
    .EXAMPLE 
            & '.\Invoke-WindowsUpdates.ps1' -Reboot -UpdateTypes Definition, Critical, Security' 
    .Notes 
        Author: Leotus Richard 
        website: http://outboxedsolutions.azurewebsites.net/ 
 
        Version History 
        1.0.0  3/24/2014 
            - Initial Release 
 
        1.0.1  3/25/2014 
            - Adjusted script, SCANONLY is default $true to prevent accidental windows installation.  
            - Added a "ShowCategories" Switch to view the types of updates.   
 

#> 


#Flag to auto reboot
$Reboot = $false  
#Flag to scan only
$ScanOnly = $true  
#Shows possible categories for installation
$ShowCategories = $false

 
    $AvailableUpdates = @() 
    $UpdateIds = @() 
    
 #Types of updates to install
 #$UpdateTypes = "Critical","Definition", "Drivers", "Security", "ServicePacks", "UpdateRollups", "Microsoft" 
 
 $UpdateTypes = "ALL"
 
 
if ($Reboot) { 
    Write-Host "The computer will reboot if needed after installation is complete." 
    Write-Host 
} 
if ($ScanOnly) { 
    Write-Host "Running in scan only mode." 
    Write-Host 
    } 
 
    Write-Verbose "Creating Update Session" 
    $Session = New-Object -com "Microsoft.Update.Session" 
 
 
    if ($ProxyAddress -ne $null) { 
    Write-Verbose "Setting Proxy" 
        $Proxy = New-Object -com "Microsoft.Update.WebProxy" 
        $Session.WebProxy.Address = $Proxyaddress 
        $Session.WebProxy.AutoDetect = $FALSE 
        $Session.WebProxy.BypassProxyOnLocal = $TRUE 
    } 
 
    Write-Verbose "Creating Update Type Array" 
    foreach($UpdateType in $UpdateTypes) 
    { 
        $UpdateID 
        switch ($UpdateType) 
        { 
        "Critical" {$UpdateID = 0} 
        "Definition"{$UpdateID = 1} 
        "Drivers"{$UpdateID = 2} 
        "FeaturePacks"{$UpdateID = 3} 
        "Security"{$UpdateID = 4} 
        "ServicePacks"{$UpdateID = 5} 
        "Tools"{$UpdateID = 6} 
        "UpdateRollups"{$UpdateID = 7} 
        "Updates"{$UpdateID = 8} 
        "Microsoft"{$UpdateID = 9} 
        default {$UpdateID=99} 
        } 
        $UpdateIds += $UpdateID 
    } 
 
    Write-Host "Searching for updates..." 
    $Search = $Session.CreateUpdateSearcher() 
    $SearchResults = $Search.Search("IsInstalled=0 and IsHidden=0") 
    Write-Host "There are " $SearchResults.Updates.Count "TOTAL updates available." 
 
    if($UpdateIds -eq 99) 
    { 
        $AvailableUpdates = $SearchResults.Updates 
    } 
    else{ 
         
        foreach($UpdateID in $UpdateIds) 
        { 
            $AvailableUpdates += $SearchResults.RootCategories.Item($UpdateID).Updates 
        } 
    } 
 
    Write-Host "Updates selected for installation" 
    $AvailableUpdates | ForEach-Object { 
     
        if (($_.InstallationBehavior.CanRequestUserInput) -or ($_.EulaAccepted -eq $FALSE)) { 
            Write-Host $_.Title " *** Requires user input and will not be installed." -ForegroundColor Yellow 
            if($ShowCategories) 
            { 
                $_.Categories | ForEach-Object {Write-Host "     "$_.Name.ToString() -ForegroundColor Cyan} 
                 
            } 
                 
        } 
        else { 
            Write-Host $_.Title -ForegroundColor Green 
            if($ShowCategories) 
            { 
                $_.Categories | ForEach-Object {Write-Host "     "$_.Name.ToString() -ForegroundColor Cyan} 
                 
            } 
        } 
    } 
 
    # Exit script if no updates are available 
    if ($ScanOnly) { 
        Write-Host "Exiting..."; 
        break 
    } 
    if($AvailableUpdates.count -lt 1){ 
        Write-Host "No results meet your criteria. Exiting"; 
        break 
    } 
     
    Write-Verbose "Creating Download Selection" 
    $DownloadCollection = New-Object -com "Microsoft.Update.UpdateColl" 
 
    $AvailableUpdates | ForEach-Object { 
        if ($_.InstallationBehavior.CanRequestUserInput -ne $TRUE) { 
            $DownloadCollection.Add($_) | Out-Null 
            } 
        } 
 
    Write-Verbose "Downloading Updates" 
    Write-Host "Downloading updates..." 
    $Downloader = $Session.CreateUpdateDownloader() 
    $Downloader.Updates = $DownloadCollection 
    $Downloader.Download() 
 
    Write-Host "Download complete." 
 
    Write-Verbose "Creating Installation Object" 
    $InstallCollection = New-Object -com "Microsoft.Update.UpdateColl" 
    $AvailableUpdates | ForEach-Object { 
        if ($_.IsDownloaded) { 
            $InstallCollection.Add($_) | Out-Null 
        } 
    } 
 
    Write-Verbose "Installing Updates" 
    Write-Host "Installing updates..." 
    $Installer = $Session.CreateUpdateInstaller() 
    $Installer.Updates = $InstallCollection 
    $Results = $Installer.Install() 
    Write-Host "Installation complete." 
    Write-Host 
 
 
    # Reboot if needed 
    if ($Results.RebootRequired) { 
        if ($Reboot) { 
            Write-Host "Rebooting..." 
            Restart-Computer ## add computername here 
        } 
        else { 
            Write-Host "Please reboot." 
        } 
    } 
    else { 
        Write-Host "No reboot required." 
    }