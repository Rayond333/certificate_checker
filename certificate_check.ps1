<#
    .DESCRIPTION
    certificate_check.ps1 was designed to create alert messages if ssl certificates will expire soon.
    
    This script will send an email to predefined users.
    Email targets can be specified in settings.json

    Export.ps1 uses log4net as it's logging engine. Details can be configured in log4net.config.

    Return values on console level: Negative values are console error levels (expected by task sheduler)
    
    .PARAMETER ConfigFile
    json-Config file
    The json-Config file is expected either in the same location as Powershell script

    .EXAMPLE
    .\certificate_check.ps1

    .NOTES
    Authors: Sascha Roth ND-DTS
	Edited by: Raimund Holzinger ND-DTS
#>

# Define some variables
$ErrorActionPreference = "Stop"
$currentFolder = Split-Path $Script:MyInvocation.MyCommand.Path -parent
$currentTime = Get-Date -Format yyy.MM.dd-HHmmss


# Automatically load the libraries and modules and functions

try {
    $libFiles = Get-ChildItem (Join-Path -Path $currentFolder -ChildPath  "libs")|?{($_.name -match "\.ps1") -and !($_.PSIsContainer)}
    foreach ($f in $libFiles){
        . $f.Fullname
    }

    $functions = Get-ChildItem  $PSScriptRoot|?{$_.name -match "^functions.*\.ps1"}
    foreach ($f in $functions){
        . $f.Fullname
    }

    $settings = Get-Content -Raw -Path "$currentfolder\settings.json" | ConvertFrom-Json
}
catch {
    Write-ErrorLog "Library Import failed"
    Write-ErrorLog $_
    return -2
}

#define some more variables

$DaysToExpiration = $settings.DaysToExpiration
$expirationDate = (Get-Date).AddDays($DaysToExpiration)
$script:logfile = "$currentFolder\Logs\$currentTime.log"
Initialize-Log -logFolder "$currentFolder\Logs" -logFile $script:logfile

$keystore = "F:\Atlassian\JIRA\jre\lib\security\cacerts"
$storepass = "changeit"

#Get certificates that will expire soon
try {
    Import-Module Webadministration
    
    Write-InfoLog "Get all Sites in IIS"
    $sites = Get-ChildItem -Path IIS:\Sites | Where-Object {$_.State -eq "Started"}

    Write-InfoLog "Get all issued certificates for those sites"
    Write-InfoLog $sites.Name
    $certs = Get-ChildItem IIS:SSLBindings | Where-Object {$sites.Name -contains $_.Sites.value }
	Write-InfoLog $certs.Thumbprint
	
	Write-InfoLog "Get Java Truststore/ Keystore certificates"
	$jre_keystore = keytool -list -keystore $keystore -storepass $storepass | Select-String -Pattern 'Certificate' -NotMatch
	$arr_list = [System.Collections.ArrayList]$jre_keystore
	
		#Remove first 6 lines, because they are empty
		$arr_list.RemoveRange(0, 5)
		
		#Format arraylist in order to be able to work with the dates
		foreach($key in $arr_list) {
			$obj1 = $key.Line.Replace(", 2"," 2")
			$obj2 = $obj1.split(",")[1]
			$dates = $obj2.substring(1)
			#Write-InfoLog $dates
		}
		
	
    Write-InfoLog "Get all certificates that will expire in $DaysToExpiration days"
    $cert_value = Get-ChildItem cert:\LocalMachine #| Where-Object {$certs.Thumbprint -contains $_.Thumbprint -and $_.NotAfter -lt $expirationDate}
    #For full information on the object: $cert_value | Format-List
	$cert_value | Format-Table 

    $output = $certs | ForEach-Object {$f = $_; $cert_value | Where-Object {$f.Thumbprint -eq $_.Thumbprint} | Select Thumbprint,NotAfter,Subject,@{n='SiteName';e={$f.Sites.value}}}
	$output
}
catch {
    Write-ErrorLog $_
    return -2
}


if (!$cert_value){
    Write-InfoLog "There is no license that will expire in the next $DaysToExpiration days"
}
else{
    #Send Email to recipient
    Write-InfoLog "Email sent to ${settings.EmailRecipients}"
    $mailTo = $settings.EmailRecipients.Split(";")  
    $mailSubject = $settings.EmailSubject
    $mailBody = "This Email is sent to you, cause a ssl certificate on your server will expire soon </br></br>"
    
    foreach ($item in $output) {
        $mailBody += "[Certificate] : "
        $mailBody += $item.Subject
        $mailBody += "</br>"
        $mailBody += "[ExpiryDate DD/MM/YYYY] : "
        $mailBody += $item.NotAfter
        $mailBody += "</br>"
        $mailBody += "[Thumbprint] : "
        $mailBody += $item.Thumbprint
        $mailBody += "</br>"
        $mailBody += "[Site Name] : "
        $mailBody += $item.SiteName
        $mailBody += "</br></br>"
    }
    
    try {
        #$mailBody >> expiredCerts.txt
		Send-MailMessage -To $mailTo -SmtpServer "localhost" -Subject $mailSubject -BodyAsHtml $mailBody -From $settings.EmailSender 
    }
    catch {
        Write-ErrorLog "Email could not be sent"
        Write-ErrorLog $_
        return -2
    }
    
}

Write-InfoLog "Script finished"
