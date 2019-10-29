Clear-Host;Clear-History
Set-Location $env:SystemRoot\System32
$StartingPath=Get-Location
Set-Variable -Name MainPath -Value "E:\Shared\Storage\s"
Do{
    Set-Variable -Name WorkingPath -Value $MainPath
    If(!(Test-Path -LiteralPath $MainPath)){Break}
    Set-Location -Path $WorkingPath
    Set-Variable -Name Folders -Value $null
    Set-Variable -Name Files -Value $null
    Set-Variable -Name AlphaNum -Value "0123456789abcdefghijklmnopqrstuvwxyz"
    Do{
        Set-Variable -Name DirLoop -Value 0
        Set-Variable -Name DirCount -Value 0
        Set-Variable -Name FileCount -Value 0
        Set-Variable -Name CurrentPath -Value $null
        $Folders=Get-ChildItem -Path $WorkingPath|?{$_.PSISContainer}
        If($Folders-ne$null){
            ForEach($Folder In $Folders){
                If($CurrentPath-eq$null){
                    $DirCount=$Folders.Count
                    $CurrentPath=$Folder.FullName
                    $WorkingPath=$CurrentPath
                    Echo $CurrentPath
                }
                $Files=Get-ChildItem -Path $Folder.FullName -File
                $FileCount=$Files.Count
                $varLenght=0
                If($FileCount-gt0){
                    Switch ($FileCount){
                        {$_-lt36}{$varLenght=1;Break}
                        {$_-lt36*36}{$varLenght=2;Break}
                        {$_-lt36*36*36}{$varLenght=3;Break}
                        Default{$varLenght=4;Break}
                    }
                    $FileLoop=0
                    ForEach($File In $Files){
                        $FileName=$File.FullName
                        $NewName=$AlphaNum.Substring($FileLoop,1)+$File.Extension
                        If($File.Name-ne$NewName){
                            Rename-Item -LiteralPath $FileName -NewName $NewName
                        }
                        $FileLoop++
                    }
                }
                If($($Folder.Name).Length-gt1){
                    $DirName=$Folder.FullName
                    $NewDir=$AlphaNum.Substring($DirLoop,1)
                    If($Folder.Name-ne$NewDir){
                        Rename-Item -LiteralPath $DirName -NewName $NewDir
                        If($DirLoop-eq0){
                            $PathSize=$($DirName).Length
                            $DirSize=$($Folder.Name).Length
                            $DirLength=$PathSize-$DirSize
                            $WorkingPath=$($DirName.Substring(0,$DirLength))+$NewDir
                            Remove-Item -LiteralPath $WorkingPath -Recurse -Force
                        }
                    }
                }
                $DirLoop++
            }
        }Else{
            Set-Location -Path $StartingPath
            Remove-Item -LiteralPath $MainPath -Recurse -Force
            Break
        }
    }Until($StartingPath-eq$WorkingPath)
}While(Test-Path -LiteralPath $MainPath)