$testString = "pshah snapshot for adding disk space for DBA EXP - 09/17/2016"

$pattern = "\d{1,2}\/\d{1,2}\/\d{4}$"

if($testString -match $pattern){

    [DateTime]::ParseExact($Matches[0],"MM/dd/yyyy",$null).ToString('MM-dd-yyyy')
    
}
else{
    Write-Host "Date not in correct format"
}

