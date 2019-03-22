function Add-ReceiveConnectorRemoteIPRange {
    [CmdletBinding()]
    param (
        # Parameter "ReceiveConnector" refers to the Exchange Receive Connector where the IPRange should be added. Requires the identity attribute of the Receive Connector for identification.
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]
        $Identity,
        # Parameter "IPRanges". They array may hold a single IP-Adress, an IP-Range (1.1.1.1-1.1.1.3) or an IP-Range in CIDR notation (1.1.1.1/24)
        [Parameter(Mandatory)]
        [string[]]
        $IPRanges
    )
    
    begin {

        # Function must have access to Exchange cmdlets
        if (-not([bool](Get-Command -Name Get-ReceiveConnector -ErrorAction SilentlyContinue))) {
            Throw 'Exchange cmdlet Get-ReceiveConnector not available. This is mandatory to run this function.'
        }

        [System.Collections.ArrayList]$ReceiveConnectors = @()

    }
    
    process {

        # Get the RemoteIPRanges of the requested Receive Connector
        if ($ReceiveConnector = Get-ReceiveConnector -Identity $Identity -ErrorAction SilentlyContinue) {

            # a collection to hold the newly added IPs for final output
            [System.Collections.ArrayList]$NewIPs = @()

            foreach ($IPRange in $IPRanges) {

                if ($ParsedIPRange = [Microsoft.Exchange.Data.IPRange]::Parse($IPRange)) {

                    # create version types from ParsedIPRange's Lower- and Upperbound, so we only have to do the conversion once
                    $ParsedLowerBoundAsVersion = [version]$ParsedIPRange.LowerBound.ToString()
                    $ParsedUpperBoundAsVersion = [version]$ParsedIPRange.UpperBound.ToString()

                    $IPExists = foreach ($RemoteIPRange in $ReceiveConnector.RemoteIPRanges) {

                        # create version types from RemoteIPRange's Lower- and Upperbound, so we only have to do the conversion once
                        $RemoteIPRangeLowerBoundAsVersion = [version]$RemoteIPRange.LowerBound.ToString()
                        $RemoteIPRangeUpperBoundAsVersion = [version]$RemoteIPRange.UpperBound.ToString()
                        # check IPRange overlap...
                        #          |------------|
                        #                 |---------|
                        # or
                        #          |------------|
                        #      |-------|      
                        # or
                        #          |------------|
                        #      |-------------------|         
                        # or
                        #          |------------|
                        #             |-------|                     
                        if (($ParsedLowerBoundAsVersion -le $RemoteIPRangeUpperBoundAsVersion -and $ParsedLowerBoundAsVersion -ge $RemoteIPRangeLowerBoundAsVersion) `
                            -or ($ParsedUpperBoundAsVersion -ge $RemoteIPRangeLowerBoundAsVersion -and $ParsedUpperBoundAsVersion -le $RemoteIPRangeUpperBoundAsVersion) `
                            -or ($ParsedLowerBoundAsVersion -le $RemoteIPRangeLowerBoundAsVersion -and $ParsedUpperBoundAsVersion -ge $RemoteIPRangeUpperBoundAsVersion) `
                            -or ($ParsedLowerBoundAsVersion -ge $RemoteIPRangeLowerBoundAsVersion -and $ParsedUpperBoundAsVersion -le $RemoteIPRangeUpperBoundAsVersion)) {
                            $true
                            break
                        }
                    }

                    if (-not($IPExists)) {
                        $null = $ReceiveConnector.RemoteIPRanges.Add($ParsedIPRange)
                        $null = $NewIPs.Add($ParsedIPRange)
                    } else {
                        Write-Error "IPRange $IPRange or a subset of it already exist in RemoteIPRanges."
                    }     

                } else {
                    Write-Error $error[0].Exception
                }
            
            }

            if ($NewIPs) {
                # Collect working and changed receive connectors for later data upload. Data upload must happen in the end{} part, because in case any provided rc fails we don't want to upload any data at all and there is on need to call Set-ReceiveConnector for an rc that did not change.
                $ReceiveConnector | Add-Member -MemberType NoteProperty -Name 'NewRemoteIPRanges' -Value $NewIPs
                $null = $ReceiveConnectors.Add($ReceiveConnector)
            }

        } else {
            Throw "Receive Connector `"$Identity`" not found."
        }

    }
    
    end {
        # DATA MODIFICATION --- BEGIN
        foreach ($ModifiedReceiveConnector in $ReceiveConnectors) {
            Set-ReceiveConnector -Identity $ModifiedReceiveConnector.Identity -RemoteIPRanges $ModifiedReceiveConnector.RemoteIPRanges #-Whatif
            $ModifiedReceiveConnector | Select-Object Identity,NewRemoteIPRanges
        }
        # DATA MODIFICATION --- END
    }
}