function Get-AbrADSiteReplication {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Microsoft AD Domain Sites Replication information.
    .DESCRIPTION

    .NOTES
        Version:        0.6.3
        Author:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
        [Parameter (
            Position = 0,
            Mandatory)]
            [string]
            $Domain
    )

    begin {
        Write-PscriboMessage "Collecting AD Domain Sites Replication information."
    }

    process {
        Write-PscriboMessage "Collecting AD Domain Sites Replication Summary. (Sites Replication)"
        $DCs = Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ADDomain -Identity $using:Domain | Select-Object -ExpandProperty ReplicaDirectoryServers}
        if ($DCs) {
            Write-PscriboMessage "Discovering Active Directory Sites Replication information on $Domain. (Sites Replication)"
            try {
                Section -Style Heading4 'Sites Replication' {
                    Paragraph "The following section provides a summary of the Active Directory Site Replication information."
                    BlankLine
                    $OutObj = @()
                    foreach ($DC in $DCs) {
                        try {
                            $Replication = Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ADReplicationConnection -Server $using:DC -Properties *}
                            if ($Replication) {
                                Write-PscriboMessage "Collecting Active Directory Sites Replication information on $DC. (Sites Replication)"
                                foreach ($Repl in $Replication) {
                                    try {
                                        $inObj = [ordered] @{
                                            'DC Name' = $DC.ToString().ToUpper().Split(".")[0]
                                            'GUID' = $Repl.ObjectGUID
                                            'Description' = ConvertTo-EmptyToFiller $Repl.Description
                                            'Replicate From Directory Server' = ConvertTo-ADObjectName $Repl.ReplicateFromDirectoryServer.Split(",", 2)[1] -Session $TempPssSession -DC $DC
                                            'Replicate To Directory Server' = ConvertTo-ADObjectName $Repl.ReplicateToDirectoryServer -Session $TempPssSession -DC $DC
                                            'Replicated Naming Contexts' = $Repl.ReplicatedNamingContexts
                                            'Transport Protocol' = $Repl.InterSiteTransportProtocol
                                            'AutoGenerated' =  ConvertTo-TextYN $Repl.AutoGenerated
                                            'Enabled' =  ConvertTo-TextYN $Repl.enabledConnection
                                            'Created' = ($Repl.Created).ToUniversalTime().toString("r")
                                        }
                                        $OutObj = [pscustomobject]$inobj

                                        if ($HealthCheck.Site.Replication) {
                                            $OutObj | Where-Object { $_.'Enabled' -ne 'Yes'} | Set-Style -Style Warning -Property 'Enabled'
                                        }

                                        $TableParams = @{
                                            Name = "Site Replication - $($DC.ToString().ToUpper().Split(".")[0])"
                                            List = $true
                                            ColumnWidths = 40, 60
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $OutObj | Table @TableParams
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Site Replication Item)"
                                    }
                                }
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Site Replication Section)"
                        }
                    }
                }
            }
            catch {
                Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Site Replication)"
            }
        }
        try {
            if (($HealthCheck.Site.Replication) -and (Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ADReplicationFailure -Target $using:Domain -Scope Domain})) {
                Write-PscriboMessage "Discovering Active Directory Sites Replication Failure on $Domain. (Sites Replication Failure)"
                $OutObj = @()
                Write-PscriboMessage "Discovered Active Directory Sites Replication Failure on $Domain. (Sites Replication Failure)"
                $Failures =  Invoke-Command -Session $TempPssSession -ScriptBlock {Get-ADReplicationFailure -Target $using:Domain -Scope Domain}
                if ($Failures) {
                    Section -Style Heading4 'Sites Replication Failure' {
                        Paragraph "The following section provides a summary of the Active Directory Site Replication Failure information."
                        BlankLine
                        foreach ($Fails in $Failures) {
                            try {
                                Write-PscriboMessage "Collecting Active Directory Sites Replication Failure on '$($Fails.Server)'. (Sites Replication Failure)"
                                    $inObj = [ordered] @{
                                        'Server Name' = $Fails.Server.Split(".", 2)[0]
                                        'Partner' =  ConvertTo-ADObjectName $Fails.Partner.Split(",", 2)[1] -Session $TempPssSession -DC $DC
                                        'Last Error' = $Fails.LastError
                                        'Failure Type' =  $Fails.FailureType
                                        'Failure Count' = $Fails.FailureCount
                                        'First Failure Time' = ($Fails.FirstFailureTime).ToUniversalTime().toString("r")
                                    }
                                $OutObj = [pscustomobject]$inobj

                                if ($HealthCheck.Site.Replication) {
                                    $OutObj | Where-Object {$NULL -notlike $_.'Last Error'} | Set-Style -Style Warning -Property 'Last Error', 'Failure Type', 'Failure Count', 'First Failure Time'
                                }

                                $TableParams = @{
                                    Name = "Site Replication Failure - $($Fails.Server.ToUpper().Split(".", 2)[0])"
                                    List = $true
                                    ColumnWidths = 40, 60
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Table @TableParams
                            }
                            catch {
                                Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Site Replication Failure)"
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Site Replication Failure)"
        }
    }

    end {}

}