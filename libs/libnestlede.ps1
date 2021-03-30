# this is some test text
function Initialize-Log {
    Param ([string]$logFolder, [string]$logFile)
    if ((Test-Path $logFolder) -eq $false) {
        New-Item -Path $logFolder -ItemType directory
    }
    if ((Test-Path $logFile) -eq $false) {
        New-Item -Path $logFile -ItemType file
    }
}

function Write-InfoLog {
    Param ([string]$logString)
    $nowTime = Get-Date -format "yyyy-MM-dd HH:mm:ss,fff"

    # Powershell way for reflection :-)
    #$scriptName = $MyInvocation.MyCommand.Name
    $callerName = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Name
    #$line = (Get-PSCallStack)[0].InvocationInfo.ScriptLineNumber
    $logLevel = "INFO"

    Add-content $script:logfile -value "[$nowTime][$logLevel][$callerName] - $logString"
    Write-Host "[$nowTime][$logLevel][$callerName] - $logString" 
}

function Write-DebugLog {
    Param ([string]$logString)
    $nowTime = Get-Date -format "yyyy-MM-dd HH:mm:ss,fff"

    # Powershell way for reflection :-)
    #$scriptName = $MyInvocation.MyCommand.Name
    $callerName = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Name
    #$line = (Get-PSCallStack)[0].InvocationInfo.ScriptLineNumber
    $logLevel = "DEBUG"
	
    if ($DebugPreference -eq 'Continue') {
        Add-content $script:logfile -value "[$nowTime][$logLevel][$callerName] - $logString"
        Write-Debug "[$nowTime][][$callerName] - $logString"
    }	
}

function Write-WarningLog {
    Param ([string]$logString)
    $nowTime = Get-Date -format "yyyy-MM-dd HH:mm:ss,fff"

    # Powershell way for reflection :-)
    #$scriptName = $MyInvocation.MyCommand.Name
    $callerName = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Name
    #$line = (Get-PSCallStack)[0].InvocationInfo.ScriptLineNumber
    $logLevel = "WARNING"

    Add-content $script:logfile -value "[$nowTime][$logLevel][$callerName] - $logString"
    Write-Host "[$nowTime][$logLevel][$callerName] - $logString" 
}

function Write-ErrorLog {
    Param ([string]$logString)
    $nowTime = Get-Date -format "yyyy-MM-dd HH:mm:ss,fff"

    # Powershell way for reflection :-)
    #$scriptName = $MyInvocation.MyCommand.Name
    $callerName = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Name
    #$line = (Get-PSCallStack)[0].InvocationInfo.ScriptLineNumber
    $logLevel = "ERROR"

    Add-content $script:logfile -value "[$nowTime][$logLevel][$callerName] - $logString"
    $Host.UI.WriteErrorLine("[$nowTime][$logLevel][$callerName] - $logString")
}

function Invoke-AutoInitializeLog {
    $callerName = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Name
    Write-Host ("Caller is $callerName" + "!")
    $logFolder = ($env:USERPROFILE + "\PowerLogs\$callerName")
    $currentTime = Get-Date -Format yyy.MM.dd-HHmmss
    $script:logfile = ($logFolder + "\$currentTime.log")
    Initialize-Log -logFolder $logFolder -logFile $script:logfile
    Write-InfoLog "Logging initialisation completed..."
	
}
function Invoke-ErrorSound ($frequency, $duration) {
    [console]::beep($frequenz, $duration)
}

function Expand-ZipfileToFolder($fileName, $destination) {
    Write-InfoLog "ZIP file is $fileName, destination is $destination"
    Write-InfoLog "Loading the .net-Assembly 'System.IO.Compression.FileSystem' ....."
    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')|out-null
    Write-InfoLog "Unzip the file with help of 'System.IO.Compression.ZipFile', grab a coffee and relax ...."
    $startTime = get-date
    [System.IO.Compression.ZipFile]::ExtractToDirectory($fileName, $destination)|out-null
    $endTime = get-date
    $duration = (New-TimeSpan -Start $startTime -End $endTime).TotalSeconds
    Write-InfoLog "Done with unzip, it took $duration seconds"
}

function Invoke-TwoFolderSyncBasedOnHash($sourceFolder, $destinationFolder) {
    Write-InfoLog "Syncronize files in $destination with $sourceFolder, it will take a while"
    #Write-InfoLog "Source Folder is $sourceFolder"
    #Write-InfoLog "Destination folder is $destinationFolder"
    $rfd = Get-ChildItem -Recurse $sourceFolder| Where-Object {$_.PsIsContainer}
    $rfd | ForEach-Object {
        # Check if the folder, from $fr, exists with the same path under $fl
        If ( Test-Path ( $_.FullName.Replace($sourceFolder, $destinationFolder) ) ) {
            #Write-InfoLog "Folder ($_.FullName.Replace($fl, $fr) exisits, nothing to do ..."
        }
        else {
            $newDirectory = $_.FullName.Replace($sourceFolder, $destinationFolder)
            New-Item -ItemType directory -Path $newDirectory |Out-Null
            Write-InfoLog "Folder-Update: direcotry $newDirectory was created"
        }  
    }

    # Now compare the files.
    $rff = Get-ChildItem -Recurse $sourceFolder | Where-Object {-not $_.PsIsContainer }
    $rff| ForEach-Object {
        # Check if the file from $rff, exists with the same path under $fl
        # If not, the files on the right side will be copied to the left side
        if (-not (Test-Path ($_.FullName.Replace($sourceFolder, $destinationFolder)))) {
            Copy-Item -Path $_.FullName -Destination $_.FullName.Replace($sourceFolder, $destinationFolder)
            $fileName = $_.FullName
            Write-InfoLog "Folder-Update: New file $fileName will be copied to your system ...."
        }
        else {
            $local = gci $_.FullName.Replace($sourceFolder, $destinationFolder) -ErrorAction SilentlyContinue
            $remote = gci $_.FullName
            # I will compare the hash value of the files on both side.
            # With the help of 'Get-Filehash', things are so easy now ....!
            if ((Get-Filehash $local).Hash -ne (Get-Filehash $remote).Hash) {
                $fileName = $_.FullName
                Write-InfoLog "Folder-Update: file $fileName will be copied to your system ...."
                Copy-Item -Path $remote -Destination $local -Force
            }	
        }
    }

}

function Remove-ReadOnlyFlag($filePath) {
    Set-ItemProperty $filePath -name IsReadOnly -value $false
}
function Add-ReadOnlyFlag($filePath) {
    Set-ItemProperty $filePath -name IsReadOnly -value $true
}
function New-FolderJunction($source, $destination) {
    Write-InfoLog "DEBUG: source is $source"
    Write-InfoLog "DEBUG: destination is $destination"
    cmd.exe /c mklink /J $destination $source
}

function Remove-FolderSecurely($folder) {
    $elements = Get-ChildItem $folder -Recurse
    # Zuerst werden die symbolische Links "sicher" gelöscht, weil rmdir ein alias von Remove-item ist, das nicht nur
    # die symbolische Links löscht, sondern auch den Ursprung!
    foreach ($e in $elements) {
        # mit Hilfe von test-path $e.Fullname werden mögliche Fehlermeldung vermieden, weil in den unteren Zeilen mit rmdir die Symlink von dem Verzeichnis gelöscht wurde.
        if (test-path $e.Fullname) {
            if ((get-item $e.Fullname).Attributes.ToString() -match "ReparsePoint") {
                Write-InfoLog "$e is symlink .."
                if ((get-item $e.Fullname).Attributes.ToString() -match "Directory") {
                    Write-InfoLog "It is directory link"
                    cmd.exe /c rmdir ($e.Fullname)
                }
                ElseIf ((get-item $e.Fullname).Attributes.ToString() -match "Archive") {
                    Write-InfoLog "It is a file sym link"
                    cmd.exe /c del ($e.Fullname)
                }
                else {
                    Write-host "Other types of link"
                }
            }
        }
    }
    # Jetzt werden das Restverzeichnis "normal" gelöscht.
    Remove-Item -Recurse -Force $folder	
}

function Invoke-SOAPRequest {
    Param (
        [string]$url,
        [string]$content,
        [hashtable]$additionalHeaders,
        [hashtable]$webRequestProperties
    )
	
    $request = [System.Net.WebRequest]::Create($target)
    $encodedContent = [System.Text.Encoding]::UTF8.GetBytes($content)
    if ($additionalHeaders) {
        foreach ($h in $additionalHeaders.GetEnumerator()) {
            $request.Headers.Add($h.Name, $h.Value)
        }
    }
	
    if ($webRequestProperties) {
        foreach ($p in $webRequestProperties.GetEnumerator()) {
            $request.($p.Name) = $p.Value
        }
    }
    else {
        $request.UserAgent = 'PowerWS-Client'
        $request.ContentType = 'text/xml; charset=utf-8'
        $request.Method = 'Post'
    }
	
    if ($encodedContent.length -gt 0) {
        $request.ContentLength = $encodedContent.length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($encodedContent, 0, $encodedContent.length)
        $requestStream.Close()
    }

    [System.Net.WebResponse] $resp = $request.GetResponse();
    if ($resp -ne $null) {
        $rs = $resp.GetResponseStream();
        [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
        [string] $results = $sr.ReadToEnd();

        return $results
    }
    else {
        exit ''
    }
	
}

function Invoke-XMLCheck ([string] $content) {
    [bool]($content -as [xml])
}

function Expand-JarToFolder {
    #($jarFile,$folderToExtract)
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = 'What is the name of the jar file?')]
        [Alias('jar')]
        [string]$jarFile,

        [Parameter(Mandatory = $True,
            HelpMessage = 'What is the name of the folder?')]
        [Alias('folder')]
        [string]$folderToExtract,

        [Parameter(Mandatory = $false,
            HelpMessage = 'What is the path of the jar.exe?')]
        [Alias('jar.exe')]
        [string]$jarCommand

    )
    begin {
        $command = Get-Command jar.exe
        if (($jarCommand -eq $null) -and ($command -eq $null)) {
            Write-InfoLog "jar.exe not found or not passed, exiting ..."
            Exit
        }
    }

    process {
        $currentDir = $pwd.path
        Set-Location $folderToExtract
        $extract = ($jar + " -xvf $jarFile")
        Write-InfoLog "The command for extraction is: $extract"
        Invoke-Expression -command $extract
        Set-Location $currentDir
    }
}

function Expand-FileFromJar($jarFile, $filePath, $extractFolder) {
    $currentDir = $pwd.path
    if ($extractFolder) {Set-Location $extractFolder}
    $extract = $jar + " -xvf $jarFile $filePath"
    Write-InfoLog "The command for extraction is $extract"
    Invoke-Expression -command $extract
    Set-Location $currentDir
}

# Important: $filePath is relative!
# Firstly you must navigate to the folder where all the jars and xmls are extracted.
function Update-FileInJar($jarFile, $filePath) {
    $update = ($jar + " -uvf $jarFile $filePath")
    Write-InfoLog "The command for update is: $update"
    Invoke-Expression -command $update
}

function Compress-FolderToJar($folderPath, $jarFile) {
    $currentDir = $pwd.path
    Set-Location $folderPath
    $create = ($jar + " cf0M $jarFile .") # 0 means no compression
    Write-InfoLog "The command for create is: $create"
    Invoke-Expression -command $create
    Set-Location $currentDir
}

function Compress-FolderToZip ($folderPath, $fileName) {
    Write-DebugLog "The folderPath passed in is: $folderPath"
    Write-DebugLog "The passed fileName is: $fileName"
    Add-Type -assembly "system.io.compression.filesystem"
    Write-InfoLog "Start to create the ZIP file ...."
    [io.compression.zipfile]::CreateFromDirectory($folderPath,$fileName)
    Write-InfoLog "Done with zip creation ..."
}
function Invoke-PSCallWithParameters($scriptPath, $parameters) {
    Invoke-Expression "& `"$scriptPath`" $parameters"
}

Function Expand-MsiContents {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_})]
        [ValidateScript( {$_.EndsWith(".msi")})]
        [String] $MsiPath,

        [Parameter(Mandatory = $false, Position = 1)]
        [String] $TargetDirectory
    )

    if (-not($TargetDirectory)) {
        $currentDir = [System.IO.Path]::GetDirectoryName($MsiPath)
        Write-Warning "A target directory is not specified. The contents of the MSI will be extracted to the location, $currentDir\Temp"
        $TargetDirectory = Join-Path $currentDir "Temp"
    }

    $MsiPath = Resolve-Path $MsiPath

    Write-Verbose "Extracting the contents of $MsiPath to $TargetDirectory"
    Start-Process "MSIEXEC" -ArgumentList "/a $MsiPath /qn TARGETDIR=$TargetDirectory" -Wait -NoNewWindow
}