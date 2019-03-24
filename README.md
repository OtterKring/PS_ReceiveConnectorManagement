<center><a href="https://otterkring.github.io/MainPage" style="font-size:75%;">return to MainPage</a></center>

# PS_ReceiveConnectorManagement
## Managing RemoteIPRanges of Receive Connectors using Exchange Management Console on-premise

### Why ...

Are you whitelisting certain IP addresses on some of your Receive Connectors on Exchange? Simple, if you have a small environment, maybe with just one exchange server. But as soon as you have more servers and the Receive Connector is present on several servers, you have to keep the whitelists in sync, and this does not happen automatically.

Adding or removing an IP range must be done one by one for every single server, let alone checking, if an IP address or -range is already included in the list. Using the Exchange GUI is really annoying for this task. It involves a lot of clicking around and eye strain when reading longer and longer growing lists of IP address ranges.
<br>
<br>
### Test-ReceiveConnectorRemoteIPRange -IPRange

You want to know, if an IP address or -range (or several of them) are included in any of your receive connectors? Then this is the function for you:

    Test-ReceiveConnectorRemoteIPRange -IPRange '10.0.0.1'

... or ...

    '10.0.0.1','128.32.62.0/28','192.168.0.10-192.168.0.15' | Test-ReceiveConnectorRemoteIPRange

... will test the IP address ranges you provide against all your Receive Connectors and return those connectors and their IPv4 RemoteIPRanges where your ranges overlap or match with an already listed one.
As you can see in the second example you can provide a single IP address, a simple dash connected range or a CIDR notated range. The function can detect and handle all of them.

*NOTE: This function works for Exchange Management Console (Exchange on-premise) only!*
<br>
<br>
### Add-ReceiveConnectorRemoteIPRange -Identity -IPRanges[]

For adding one or more IP address ranges to your Receive Connector(s) use this function:

    Add-ReceiveConnectorRemoteIPRange -Identity 'EXCServer01\RC01' -IPRanges '10.0.0.1'

... adds a single IP address to the single Receive Connector provided for the `-Identity` parameter.

    Get-ReceiveConnector | Where-Object {$_.Name -eq 'RC01'} | Add-ReceiveConnectorRemoteIPRange -IPRanges '10.0.0.1','128.32.62.0/28','192.168.0.10-192.168.0.15'

... adds a bunch of IP ranges provided as an array to `-IPRanges` to all Receive Connectors name 'RC01'.

IP ranges will ONLY be added, if they do not match or overlap with any range already on the list.

*NOTE: This function works for Exchange Management Console (Exchange on-premise) only!*
<br>
<br>
<br>
### Some words on the code

If you have been googling for a solution how to do this in Powershell you might have come over solutions like this:

[Paul Cunningham on adding remote ip addresses to receive connectors](https://practical365.com/exchange-server/how-to-add-remote-ip-addresses-to-existing-receive-connectors/)

I want to take this opportunity to say thank you to [Mr Cunningham](https://paulcunningham.me) for giving me a lot of good ideas about scripting for Exchange. I find myself building on his code samples quite a lot.

If you have already had a look at my code, you might wonder why it is so much more complicated. Well, most of it is the checking if an IP address already exists on the list of the Receive Connector. But in fact I decided to take a slightly different approach for two reasons:

#### 1) As soon as I see `$array += $newelement` my performance alarm bell rings

The "+=" operator is about the slowest option for adding elements to a collection of data. If possible I try to build arrays from the output of a loop, like ...

    $array = foreach ($element in $list) {
        # return something to store in the array
    }

... or, marginally slower, use a `[System.Collections.Arraylist]` and its included functions:

    [System.Collections.Arraylist]$arraylist = @()
    $arraylist.Add($element)

(Thank you to [Tobias Weltner](https://twitter.com/TobiasPSP) for teaching me this!)

It might take a bit more thinking about your code using these methods over the "+=" operator, but if you want your code to be reused by others, you never know how much data they will push over the pipeline or how often your function will be called in a loop. You will do them and in the end yourself a favor in saving execution time where you can.

Btw ... the `foreach ($element in $list)` loop is also faster than the so widely spread use of `$list | foreach-Object {...}`. If you are looking for speed, I'd generally try to avoid the pipeline within a function or script.

#### 2) Use of "native" data format

Exchange Management Console includes a lot of data structures which do not exist in imported sessions or standard powershell consoles. Just like `Get-Mailbox mcfly | Select-Object -ExpandProperty EmailAddresses` suddenly results in a lot more information than you might have asked for in EMC, the same is true for `Get-ReceiveConnector 'EXC01/RC01' | Select-Object -ExpandProperty RemoteIPRanges`. The resulting data is not just simple IP ranges, but a new sub-structure. Further investigation with `Get-Member` reveils that we are talking about `[Microsoft.Exchange.Data.IPRange]` which to my big pleasure also provides additional functions for dealing with IP address ranges, like ...

    [Microsoft.Exchange.Data.IPRange]::Parse()

... and a lot of others.

*NOTE TO MICROSOFT: Why is such a useful class for dealing with IP address not available in general .Net? I searched a long time and only found instructions on how to build your own IP address manipulations classes.*

`Parse()` is a great method:
- it checks your string for being a valid IPv4 address
- and transforms it to a `[Microsoft.Exchange.Data.IPRange]` data object, the native format for Exchange, including the calculation of bottom and top address of your provided range. This again eases up checking the new range against the already existing list A LOT!
<br>
<br>

### Final words

I am happy about how this functions work. However, the use of the `[Microsoft.Exchange.Data.IPRange]` structure is most likely the reason, why this code will not work for Exchange Online.
I have not tried, yet, but I expect it just like any other `[Microsoft.Exchange...]` structure to not exist in imported exchange sessions (which the EOL console is).

I will update the function for EOL compatibility as my time allows.
<br>
<br>
<br>
In the meantime, I hope these little helpers can help you, too.
Happy coding!

Max.