function Test-ReceiveConnectorRemoteIPRange {
    [CmdletBinding()]
    param (
        # Parameter "IPRange". Will take values from the pipeline
        [Parameter(ValueFromPipeline)]
        [string]
        $IPRange
    )
    
    begin {

        # Function must have access to Exchange cmdlets
        if (-not([bool](Get-Command -Name Get-ReceiveConnector -ErrorAction SilentlyContinue))) {
            Throw 'Exchange cmdlet Get-ReceiveConnector not available. This is mandatory to run this function.'
        }

        $ReceiveConnectors = Get-ReceiveConnector | Select-Object Identity,Name,RemoteIPRanges

    }
    
    process {

        foreach ($ReceiveConnector in $ReceiveConnectors) {

            if ($ParsedIPRange = [Microsoft.Exchange.Data.IPRange]::Parse($IPRange)) {

                # create version types from ParsedIPRange's Lower- and Upperbound, so we only have to do the conversion once
                $ParsedLowerBoundAsVersion = [version]$ParsedIPRange.LowerBound.ToString()
                $ParsedUpperBoundAsVersion = [version]$ParsedIPRange.UpperBound.ToString()

                foreach ($RemoteIPRange in $ReceiveConnector.RemoteIPRanges) {

                    # only check IPv4 ranges
                    if ($RemoteIPRange.Expression -notmatch ':') {

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
                            [PSCustomObject]@{
                                Identity = $ReceiveConnector.Identity
                                Name = $ReceiveConnector.Name
                                MatchedIPRange = $IPRange
                                RemoteIPRanges = $ReceiveConnector.RemoteIPRanges
                            }
                            break
                        }    

                    }

                } 

            }

        }

    }
    
    end {
        # nothing yet
    }
}