PowerShell Set-ExecutionPolicy -ExecutionPolicy ByPass
PowerShell Set-ExecutionPolicy Unrestricted
Clear-History;Clear-Host
Set-Variable -Name AdminSession -Value $null
Set-Variable -Name CurrentUser -Value $env:USERNAME
Set-Variable -Name ComputerName -Value $env:COMPUTERNAME
$Global:Answer=$null
$Global:AdminCreds=$null
Set-Variable -Name LogonDomain -Value $($($env:USERDNSDOMAIN).Split(".")[0]).ToUpper()
Set-Variable -Name ParentPath -Value "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$AdminCreds=Get-Credential -Credential "$LogonDomain\$CurrentUser" -ErrorAction SilentlyContinue
Function RemoteSession-Open{Param([Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][string]$Answer)
    $Results=Test-WSMan -ComputerName $Answer;Clear
    If($Results-eq$null){
        $PSExecPath="\\$LogonDomain\replication\SysAdmins\SysInternals\psexec64.exe"
        Start-Process -FilePath "$PSExecPath" -Credential $AdminCreds -ArgumentList "\\$Answer cmd /c powershell enable-psremoting -force""" -Wait
    }
    $AdminSession=New-PSSession -Credential $AdminCreds -ComputerName $Answer
    Enter-PSSession $AdminSession
    gpupdate /force
    Return $Answer
}
<#

    Set-Location "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    Dir

    ###
    ###    Locate the correct registry profile
    ###    Focus on the last four/five digits of SID for the account that you're fixing
    ###    The ProfileImagePath will need to be changed.  You will change that first
    ###
    ###    In the next line, copy and paste to the SID at the below registry prompt
    ###

    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\###{SID of the user account that you're fixing}###" -Name ProfileImagePath

    ###
    ###    EXAMPLE:
    ###
    ###    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-1993002232-2661840759-1735431652-17172" -Name ProfileImagePath
    ###
    ###
    ###    The above command will return the value that you want to change if it is formatted correctly
    ###    Once you verify that you have the correct registry value being returned from the pervious command
    ###    Up arrow one time on the keyboard to reveil the pervious command and hit the HOME key and change
    ###    the "GET" command to "SET", then hit the END key and add the new value for the profile path
    ###    An example of the complete command is below for what the SET command should look like for ProfileImagePath
    ###

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-1993002232-2661840759-1735431652-17172" -Name ProfileImagePath -Value "C:\Users\ro1000829946"

    ###
    ###    The next value that is needed to be changed is the STATE value.  If you use the same sentax as the
    ###    pervious GET statement, you'll need to change the -NAME from "ProfileImagePath" to "State"
    ###    You'll need to change the "State" value from it's current random value to "16" for Remote profile
    ###
    ###    An example of the complete command is below for what the SET command should look like for State
    ###

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-1993002232-2661840759-1735431652-17172" -Name State -Value 16

    ###
    ###    The registry values for the profile are now fixed, but the files in the C:\Users directory are still their
    ###    We will now change the focus of PowerShell from the registry to the local system drive "C:\Windows\System32"
    ###

    Set-Location $env:SystemRoot\System32

    ###
    ###    From the current location you'll remove all profile directories that exist for the fixed account
    ###
    ###    An example of the command we'll use is formatted completely below to list all files and directories being removed
    ###

    Remove-Item C:\Users\ro1000829946.* -Recurse -Force -Verbose

    ###
    ###    Once you've completed cleaning up the remote computer, make sure that you close the session and run the last function
    ###    Before closing the remote session, make sure that you have the UserName for the RemoteSession-Close command
    ###

    Exit-PSSession

    ###
    ###    Running the "RemoteSession-Close sy##########" command will copy the remote image profile to the users account
    ###    This process will verify all the initial settings are in place on the user's profile
    ###
    ###    An example of the complete Function call is: RemoteSession-Close "ro1000829946"
    ###

    Echo $Answer

    ###
    ###    If the above variable doesn't return the correct value, then set the correct value before running the below
    ###    function.  To set the correct value type, $Answer="HOSTNAME" at the PS prompt.
    ###

#>
Function RemoteSession-Close{Param([Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$UserName)
    Set-Variable -Name StoredProfiles -Value "\\w16adfs01.inf.utshare.local\VPRepository"
    Set-Variable -Name LocalUserProfile -Value "\\$Answer\C$\Users\$UserName"
    If(Test-Path -Path "$StoredProfiles\$UserName.V6"){
        $StoredProfiles="$StoredProfiles\$UserName.V6"
    }Else{
        $StoredProfiles="$StoredProfiles\w10_gld_img.V6"
    }
    Start-Process -FilePath "PowerShell" -Credential $AdminCreds -ArgumentList "-noexit RoboCopy $StoredProfiles $LocalUserProfile /E""" -Wait
    Set-Location $env:SystemRoot\System32
    Clear
}