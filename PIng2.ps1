#Requires -Version 2


<#
Script to ping and report on computers.
Data reported: ComputerName, Status, OSVersion, OSCaption, OSArchitecture, IPAddress, MacAddress, VM, Model, Manufacturer, DateBuilt, LastBootTime
Sam Boutros 
    31 October 2014 v1.0 
    4 January 2017  v2.0
    17 March 2017   v3.0 
        - sort and order output properties
        - chnaged the logic to output 1 record per computer even when it has several NICs
#>
$ComputerList = ".\list.txt" 
$CSVFile = ".\Ping-Report-$(Get-Date -format yyyyMMdd_hhmmsstt).csv" 
$LogFile = ".\Ping-Report-$(Get-Date -format yyyyMMdd_hhmmsstt).txt" 



CmdletBinding(ConfirmImpact='Low')] 
parm([Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [String[]]$ComputerName = $Computerlist)

$PCData = foreach ($PC in $ComputerName) {
    Write-Verbose "Checking computer'$PC'"
    try {
        Test-Connection -ComputerName $PC -Count 2 -ErrorAction Stop | Out-Null
        $OS    = Get-WmiObject -ComputerName $PC -Class Win32_OperatingSystem -EA 0
        $Mfg   = Get-WmiObject -ComputerName $PC -Class Win32_ComputerSystem -EA 0
        $IPs   = @()
        $MACs  = @()
        foreach ($IPAddress in ((Get-WmiObject -ComputerName $PC -Class "Win32_NetworkAdapterConfiguration" -EA 0 | 
            Where { $_.IpEnabled -Match "True" }).IPAddress | where { $_ -match "\." })) {
                $IPs  += $IPAddress
                $MACs += (Get-WmiObject -ComputerName $PC -Class "Win32_NetworkAdapterConfiguration" -EA 0 | 
                    Where { $_.IPAddress -eq $IPAddress }).MACAddress
        }
        $Props = @{
            ComputerName   = $PC
            Status         = 'Online'
            IPAddress      = $IPs -join ', '
            MACAddress     = $MACs -join ', '
            DateBuilt      = ([WMI]'').ConvertToDateTime($OS.InstallDate)
            OSVersion      = $OS.Version
            OSCaption      = $OS.Caption
            OSArchitecture = $OS.OSArchitecture
            Model          = $Mfg.model
            Manufacturer   = $Mfg.Manufacturer
            VM             = $(if ($Mfg.Manufacturer -match 'vmware' -or $Mfg.Manufacturer -match 'microsoft') { $true } else { $false })
            LastBootTime   = ([WMI]'').ConvertToDateTime($OS.LastBootUpTime)
        }
        New-Object -TypeName PSObject -Property $Props
    } catch { # either ping failed or access denied 
        try {
            Test-Connection -ComputerName $PC -Count 2 -ErrorAction Stop | Out-Null
            $Props = @{
                ComputerName   = $PC
                Status         = $(if ($Error[0].Exception -match 'Access is denied') { 'Access is denied' } else { $Error[0].Exception })
                IPAddress      = ''
                MACAddress     = ''
                DateBuilt      = ''
                OSVersion      = ''
                OSCaption      = ''
                OSArchitecture = ''
                Model          = ''
                Manufacturer   = ''
                VM             = ''
                LastBootTime   = ''
            }
            New-Object -TypeName PSObject -Property $Props            
        } catch {
            $Props = @{
                ComputerName   = $PC
                Status         = 'No response to ping'
                IPAddress      = ''
                MACAddress     = ''
                DateBuilt      = ''
                OSVersion      = ''
                OSCaption      = ''
                OSArchitecture = ''
                Model          = ''
                Manufacturer   = ''
                VM             = ''
                LastBootTime   = ''
            }
            New-Object -TypeName PSObject -Property $Props              
        }
    }
}
$PCData | sort ComputerName |
    select ComputerName, Status, OSVersion, OSCaption, OSArchitecture, IPAddress, MacAddress, VM, Model, Manufacturer, DateBuilt, LastBootTime