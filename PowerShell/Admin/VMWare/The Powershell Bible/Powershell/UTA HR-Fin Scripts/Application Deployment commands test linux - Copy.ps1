#Add-PSSnapin VMware.VimAutomation.Core
Connect-VIServer -Server devdalvc00.dev.cloudcore.local -Protocol https -User sa_dev_tidal -Password Aec@dallas

#Mount ISO and Execute the bashscript for ISO installation

$autoinstallFileName = "./autoinstall.sh"
$installMethod = "1"
$runCommand = $autoinstallFileName+" "+ $installMethod
$runCommand


#$mountAndRun = "cd /mnt; mkdir cdrom; cd; mount /dev/cdrom /mnt/cdrom; cd /mnt/cdrom;  chmod +rx autoinstall.sh; chmod +rx deploy.sh; $runCommand"


$mountAndRun = "export JAVA_HOME=/usr/java/jre1.7.0_10; export PATH=$PATH:$JAVA_HOME/bin;"



$result = Invoke-VMScript -VM LT201301031338 -GuestUser root -GuestPassword novell123 -ScriptType Bash -ScriptText $mountAndRun


#Unmount mount point

#$unmnt = "umount /media/cdrom"

#Invoke-VMScript -VM $args[4] -HostUser $args[7] -HostPassword $args[8] -GuestUser $args[5] -GuestPassword $args[6] -ScriptType Bash -ScriptText $unmnt

#Disconnect the CDROM Media

#$cdDrive = Get-CDDrive -VM $args[4]
#Remove-CDDrive -CD $cdDrive
