$logfile =  $PSScriptRoot  + '\MainLog-'+(Get-Date -Format "yyyyMMdd_HH-mm-ss")+'.txt'

#Function to check if user have access to server passed as parameter
function Check-Access {  
    param ($ComputerName) 
    
    $session = New-PSSession $ComputerName -ErrorAction SilentlyContinue
    if ($session -is [System.Management.Automation.Runspaces.PSSession]){
        Remove-PSSession $session
        return $true
    }else{
        return $false
    }
}

#Function to check .NET version on the server passed as parameter
function Check-Version{
    param ($ComputerName)
    $response = invoke-command  $ComputerName {
        $releaseNumber = Get-ChildItem 'hklm:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' | Get-ItemProperty -Name Release
        $version = ""
        switch -regex ($releaseNumber.Release) {
            "378389" { $version = "4.5" }
            "378675|378758" { $version = "4.5.1" }
            "379893" { $version = "4.5.2" }
            "393295|393297" { $version = "4.6" }
            "394254|394271" { $version = "4.6.1" }
            "394802|394806" { $version = "4.6.2" }
            "460798" { $version = "4.7" }
            {$_ -gt 460798} { $version = "Undocumented 4.7 or higher, please update script" }
        }
        return "v" + $version + " (" + $releaseNumber.Release + ")" 
    }
    return $response
}

#Function to check IP of the server passed as parameter
function Check-Ip{
    param ($ComputerName)
    $response = invoke-command  $ComputerName {
        $ip = (gwmi Win32_NetworkAdapterConfiguration | ? { $_.IPAddress -ne $null }).ipaddress
        return $ip 
    }
    return $response
}

#Function to display logs on console and write it to file as well
function Write-Log{
    param ($log)
    $log
    $log | Add-Content $logfile
}

#Reading servers.txt file
$server_file = $PSScriptRoot + "\servers.txt"
if (!(Test-Path $server_file)) {
    Write-Host "[ERROR]Server file not found" -ForegroundColor Red
    "[ERROR]Server file not found" | Add-Content $logfile
    return
}
$servers = Get-Content -Path $server_file

# Looping thru all servers
foreach($server in $servers){
    $serverInfo = New-Object –TypeName PSObject
    Write-Log "---------------------------------------------"
    Write-Log "Server: $server"
    Write-Log "---------------------------------------------"

    if(Check-Access $server){
        $version = Check-Version $server
        $ipAddress = Check-Ip $server

        # New detail can be added like this
        $serverInfo | Add-Member –MemberType NoteProperty –Name ".NET Version" –Value $version
        $serverInfo | Add-Member –MemberType NoteProperty –Name "IPv4 Address" –Value $ipAddress

    }else{
        $serverInfo | Add-Member –MemberType NoteProperty –Name "ERROR" –Value "[ERROR]Unable to access Server $server"
    }

    $out_text = ($serverInfo | Select * | Format-List | Out-String).Trim() + "`n`n"
    Write-Log $out_text
}