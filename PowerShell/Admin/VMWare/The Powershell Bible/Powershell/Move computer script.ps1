$AdmDT = "10"
$AdmDTLoc = "OU=Administration Desktops,OU=Administration Computers,OU=Administration,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"
$AdmLT = "11"
$AdmLTLoc = "OU=Administration Laptops,OU=Administration Computers,OU=Administration,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"
$StaffDT = "20"
$StaffDTLoc = "OU=Staff Desktops,OU=Staff Computers,OU=Staff,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"
$StaffLT = "21"
$StaffLTLoc = "OU=Staff Laptops,OU=Staff Computers,OU=Staff,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"
$StuDT = "30"
$StuDTLoc =  "OU=Student Desktops,OU=Student Computers,OU=Student,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"
$STuLT = "31"
$STuLTLoc = "OU=Student Laptops,OU=Student Computers,OU=Student,OU=waco ISD,DC=ad,DC=wacoisd,DC=org"

$Base = "OU=District Computers,OU=waco isd,DC=ad,DC=wacoisd,DC=org"

$computerList = Get-ADObject -Filter 'Name -like "*"' -Searchbase $base -SearchScope OneLevel
foreach ($c in $computerlist) {
    $computer = $c.name
    $sub = $computer.substring(3,2)
    
    if ($sub -match $admDT){
        "Administration Desktop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $admdtloc
        } 
        
    if ($sub -match $admLT){
        "Administration Laptop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $admltloc
        }
        
    if ($sub -match $StaffDT){
        "Staff Desktop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $StaffDTLoc
        }
        
    if ($sub -match $StaffLT){
        "Staff Laptoptop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $StaffLTLoc
        }
        
    if ($sub -match $StuDT){
        "Student Desktop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $studtloc
        }
        
    if ($sub -match $StuLT){
        "Student Laptop " + $computer
        get-adobject -filter 'Name -like $computer' | Move-ADObject -TargetPath $stultloc
        }
}


# Move-ADObject -TargetPath $target