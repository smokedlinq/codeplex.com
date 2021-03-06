[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $RMS,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Cluster,
    
    [Parameter(Mandatory = $true, Position = 2)]
    [TimeSpan] $Duration,
    
    [ValidateScript({ $_ -le (Get-Date) })]
    [DateTime] $StartTime = (Get-Date),
    
    [ValidateScript({
        if ((Get-PSSnapin |? { $_.Name -eq 'Microsoft.EnterpriseManagement.OperationsManager.Client' } | Measure-Object).Count -eq 0) {
            Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
        }
        
        [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::IsDefined([Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason], $_)
    })]
    [string] $Reason = 'UnplannedOther',
    
    [string] $Comment = "Maintenance mode initiated by ${ENV:USERNAME}"
)

BEGIN {
    if ((Get-PSSnapin |? { $_.Name -eq 'Microsoft.EnterpriseManagement.OperationsManager.Client' } | Measure-Object).Count -eq 0) {
        Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
    }
    
    if ((Get-PSDrive -Name SCOM -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name SCOM -PSProvider OperationsManagerMonitoring -Root \ | Out-Null
    }
    
    Import-Module FailoverClusters
    
    if (!(Test-Path -Path "SCOM:\$RMS" -ErrorAction SilentlyContinue)) {
        New-ManagementGroupConnection -ConnectionString $RMS | Out-Null
    }
    
    $agents    = Get-ClusterNode -Cluster $Cluster | Select-Object -ExpandProperty NodeName
    $instances = Get-ClusterResource -Cluster $Cluster |? { $_.ResourceType.Name -eq 'Network Name' } | Get-ClusterParameter -Name DnsName | Select-Object -ExpandProperty Value
    $objects   = Get-Agent -Path "SCOM:\$RMS" |? { $agents -contains $_.ComputerName } | Select-Object -ExpandProperty HostComputer
    $objects  += $instances |% { Get-MonitoringObject -Path "SCOM:\$RMS" -MonitoringClass (Get-MonitoringClass -Path "SCOM:\$RMS" -Name Microsoft.Windows.Computer) -Criteria "Name LIKE '$_.%'" }
}

END {
    $objects | New-MaintenanceWindow -StartTime $StartTime -EndTime $StartTime.Add($Duration) -Reason $Reason -Comment $Comment
}