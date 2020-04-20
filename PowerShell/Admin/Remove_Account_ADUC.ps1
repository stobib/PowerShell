Clear-Host;Clear-History
Import-Module ActiveDirectory
Import-Module ProcessCredentials
$Global:StartPath=Get-Location
$Global:SecureCredentials=$null
$Global:DomainUser=($env:USERNAME.ToLower())
$Global:Domain=($env:USERDNSDOMAIN.ToLower())
$ScriptPath=$MyInvocation.MyCommand.Definition
$ScriptName=$MyInvocation.MyCommand.Name
Set-Location ($ScriptPath.Replace($ScriptName,""))
Set-Variable -Name OpenFile -Value $null
Switch($DomainUser){
    {($_-like"sy100*")-or($_-like"sy600*")}{Break}
    Default{$DomainUser=(("sy1000829946@"+$Domain).ToLower());Break}
}
$SecureCredentials=SetCredentials -SecureUser $DomainUser -Domain ($Domain).Split(".")[0]
If(!($SecureCredentials)){$SecureCredentials=Get-Credential}
Function ExcelToCsv($FileName){
    $NewFileName=$FileName.replace(".xlsx",".csv")
    $Excel=New-Object -ComObject Excel.Application
    $wb=$Excel.Workbooks.Open($FileName)
    ForEach($ws in $wb.Worksheets){
        If(Test-Path -Path $NewFileName){
            Remove-Item $NewFileName -Force
        }
        $ws.SaveAs($NewFileName,6)
    }
    $Excel.Quit()
    Return $NewFileName
}
If(($SecureCredentials)){
    $CurrentPath=Get-Location
    Start-Sleep -Seconds 1
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser=New-Object System.Windows.Forms.OpenFileDialog -Property @{InitialDirectory=$CurrentPath.Path;Filter='SpreadSheet (*.xlsx)|*.xlsx'}
    $null=$FileBrowser.ShowDialog()
    $OpenFile=$FileBrowser.FileName
    If(Test-Path -Path $OpenFile){
        $CSVFileName=ExcelToCsv -FileName $OpenFile
        $SpreadSheet=Import-Csv $CSVFileName
        ForEach($RowEntry In $SpreadSheet){
            $FoundAcct=""
            Try{
                $FoundAcct=Get-ADUser -Identity $($RowEntry.UserName) -ErrorAction SilentlyContinue
                If($FoundAcct){
                    Set-ADUser -Identity $($RowEntry.UserName) -Enabled $false|Out-Null
                    Remove-ADUser ($FoundAcct.SamAccountName).Trim() -Confirm $true #|Out-Null
                    Write-Host ("User account: ["+$FoundAcct.SamAccountName+"] was successfully removed from the ["+$Domain+"] domain.")
                }
            }Catch{
                Write-Host ("Was not able to find account: ["+$RowEntry.UserName+"].  It may have already been removed.")
            }
        }
        If(Test-Path -Path $CSVFileName){Remove-Item $CSVFileName -Force}
    }
}
Set-Location $StartPath
