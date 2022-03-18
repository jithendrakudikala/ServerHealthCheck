<#
.synopsis
   <<synopsis goes here>>
.Description
  Server health check
.Notes
  ScriptName  : Serverhealthcheck.PS1
  Requires    : Powershell Version 5.0
  Author      : Jithendra Kudikala
  EMAIL       : jithendra.kudikala@gmail.com
  Version     : 1.1 Script will connect to remote server and fetch healthcheck information 
.Parameter
   None
 .Example
   None
#>
$servers = Get-Content "Enter servers in .txt path"

foreach($server in $servers)
{
    $session = New-PSSession -ComputerName $server
    Invoke-Command -Session $session -ScriptBlock {
        $outputfile = "any common locaiton .txt file to update all servers details at one location" 
        Get-Date <#-Verbose 2>&1 4>&1 #> | Out-File $outputfile
        [System.Net.Dns]::GetHostName() >> $outputfile
        if(get-cluster) #check if local lost is part of windows cluster or not
        {
        get-clusternode -erroraction silentlycontinue >> $outputfile #CLusterNode 
        get-clustergroup -erroraction silentlycontinue >> $outputfile #CLustergroup
        get-clusterresource -erroraction silentlycontinue >> $outputfile #clusterresource
        get-winevent -filterhashtable @{Logname='system';ID=1135} -maxevents 1 | Format-Table timecreated, message -Wrap >> $outputfile # Cluster event
        }
        Get-PSDrive | findstr "Name file" |Out-File -Append $outputfile #drive details
        (get-wmiobject -class win32_operatingsystem).caption >> $outputfile # OS information
        get-wmiobject win32_computersystem | select name, @{name="totalphysicalmemory(MB)";Expression={($_.totalphysicalmemory/1MB).tostring("NO")}},numberofprocessors >> $outputfile # CPU and Memory
        net statistics server | findstr "since" >> $outputfile #uptime
        get-winevent -filterhashtable @{logname='system';ID=1074} -maxevents 1 | Format-Table timecreated,message -wrao >> $outputfile #Last unexpected reboot
        get-winevent -filterhashtable @{logname='system';ID=6008} -maxevents >> $outputfile #Last reboot
        get-wmiobject -query "select * from win32_operatingsystem" >> $outputfile #WMI check
        get-counter -erroraction silentlycontinue '\process(*)\%process time' | Select-Object -ExpandProperty countersamples | Select-Object -Property instancename, cookedvalue}Where-Object {$_.instancename -notmatch "^(idle|_total|system)$"} | Sort-Object -Property cookedvalue -Descending | Select-Object -First 10 | ft instancename,@{L='CPU';Expression={($_.cookedvalue/100/$env:number_of_processers).tostring('p')}} -AutoSize >> $outputfile #cpu consumers
        get-wmiobject win32_process | Sort-Object -Property ws -Descending | select -First 5 | select processname, @{name="Mem usage(MB)";Expression={[match]::round($_.ws/1mb)}},@{name="processID";Expression={[string]$_.processID}},@{name="userID"; Expression={$_.getowner().user}} >> $outputfile #Memory consumers
        get-process | Sort-Object -Property Handles -Descending | Select-Object -First 5 >> $outputfile #handle consumers
        get-service >> $outputfile #services
        Get-hotfix | Select-Object pscomputername,hotfixid,installedby,installedon | sort installedon -Descending | select -First 10 | ft -AutoSize >> $outputfile #HOTFIXES
        Get-ItemProperty HKLM:\software\Wow6432Node\microsoft\windows\currentversion\uninstall\* | Select-Object Displayname, displayversion,publisher, installdate | Format-Table -AutoSize >> $outputfile #software
        get-winevent -filterhashtable @{Logname='system';ID=16} -maxevents 1 | Format-Table timecreated, message -Wrap >> $outputfile #networkevent
        get-winevent -filterhashtable @{Logname='system';ID=17} -maxevents 1 | Format-Table timecreated, message -Wrap >> $outputfile #networkevent
}
