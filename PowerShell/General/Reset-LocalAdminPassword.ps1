Function Test-ADCredential{[CmdletBinding()]Param($UserName,$Password,$HostName)
    if(!($UserName)-or!($Password)){
        Write-Warning 'Test-ADCredential: Please specify both user name and password'
    }else{
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$HostName)
        $DS.ValidateCredentials($UserName,$Password)
    }
}
Function Write-CustomError{param([System.Exception]$exception,$targetObject,[String]$errorID,[System.Management.Automation.ErrorCategory]$errorCategory="NotSpecified")
    $errorRecord=new-object System.Management.Automation.ErrorRecord($exception,$errorID,$errorCategory,$targetObject)
    $PSCmdlet.WriteError($errorRecord)
}
Clear
$ScriptName=$MyInvocation.MyCommand.Name
Write-Host "Beginning '$ScriptName' to reset the local administrator's account password."
Set-Location -Path "C:\Users\Public\Documents"
$ExportFile="ExportList.csv"
$ImportForPMP="ImportForPMP.csv"
If(Test-Path $ExportFile){Remove-Item -Path $ExportFile}
Write-Host "Exporting list of domain computers to '$ExportFile'."
Get-ADComputer -Filter * -Property * | Select-Object Name,OperatingSystem,DNSHostName,DistinguishedName | Export-CSV $ExportFile -NoTypeInformation -Encoding UTF8
Write-Host "Completed export of domain computers to '$ExportFile'."
Write-Host "Adding exported list of domain computers to memory."
$ComputerList=Import-Csv $ExportFile
$ResultFile="Results.log"
$ErrorSettingPWD=$true
$DCCounter=0
$ImportOS="Windows"
Write-Host "Completed import of domain computers to memory."
If(Test-Path $ResultFile){Remove-Item -Path $ResultFile}
If(Test-Path $ImportForPMP){Remove-Item -Path $ImportForPMP}
#Add-Content -Path $ImportForPMP -Value 'ResourceName,DNSName,Description,Department,Location,ResourceType,ResourceURL,UserAccount,Password,Notes,DistinguishedName'
Write-Host "Starting to process imported list of domain computers."
Write-Host ""
ForEach($Computer In $ComputerList){
    If($($Computer.OperatingSystem)-like"Windows Server*"){
        $ErrorSettingPWD=$true
        $OnlineStatus="Offline"
        $DomainController=$false
        $DNSHostName=@($($Computer.DNSHostName))
        Write-Host "Working on current computer:                     $DNSHostName"
        If(@($($Computer.DistinguishedName))-like"*OU=Domain Controllers*"){
            $DCCounter++;$DomainController=$true
        }
        If(($DCCounter-le1-and$DomainController-eq$true)-or($DomainController-eq$false)){
            $AdminPassword='y&8RA!u*6ZC2-%zh'
            $HostName=@($($Computer.Name))
            $ComputerADSI=[ADSI] "WinNT://$($Computer.DNSHostName),Computer"
            foreach($childObject in $ComputerADSI.Children){
                if($childObject.Class-ne"User"){
                    continue
                }
                $type="System.Security.Principal.SecurityIdentifier"
                $childObjectSID=new-object $type($childObject.objectSid[0],0)
                if($childObjectSID.Value.EndsWith("-500")){
                    $UserName=@($($childObject.Name[0]))
                    Write-Host "Local Administrator account name:                $UserName"
                    Write-Host "Local Administrator account SID:                 $($childObjectSID.Value)"
                    try{
                        Write-Host "Attempting to change password on                 '$HostName'."
                        ([ADSI] "WinNT://$HostName/$UserName").SetPassword($AdminPassword)
                        $Resource="$HostName,$DNSHostName,,,,$ImportOS,,$UserName,$AdminPassword,,"
                        $Resource | foreach{Add-Content -Path $ImportForPMP -Value $_}
                        $ErrorSettingPWD=$false
                    }catch [System.Management.Automation.MethodInvocationException]{
                        $message="Cannot reset password for '$HostName\$UserName' due the following error: '$($_.Exception.InnerException.Message)'"
                        $exception=new-object ($_.Exception.GetType().FullName)($message,$_.Exception.InnerException)
                        Write-CustomError $exception "$HostName\$UserName" $ScriptName
                    }
                    Write-Host "Verifying the password was changed on            '$HostName'."
                    If(Test-ADCredential($UserName)($AdminPassword)($HostName)){
                        $OnlineStatus="Online"
                        Write-Host "Successfully changed the password on             '$HostName'."
                    }
                    break
                }
            }
            If($ErrorSettingPWD-eq$true){
                $Message="Wasn't able to set the password for $UserName on server: $DNSHostName."
                Add-Content -Path $ResultFile -Value $Message -PassThru
            }ElseIf($OnlineStatus-eq"Offline"){
                $Message="Server: $DNSHostName is not accessible."
                Add-Content -Path $ResultFile -Value $Message -PassThru
            }
        }
        Write-Host ""
    }
}
Write-Host ""
Write-Host "Completed processing imported list of local administrator's account password."
If(Test-Path $ExportFile){Remove-Item -Path $ExportFile -Force}
Write-Host "Deleted the temporary file '$ExportFile'."
Set-Location -Path "C:\Windows\System32"