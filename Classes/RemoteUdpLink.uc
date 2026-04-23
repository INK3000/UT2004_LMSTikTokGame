class RemoteUdpLink extends UdpLink;

var MutRemoteControl OwnerMutator;

function Init(int Port)
{
    local int Result;

    LinkMode = MODE_Text;
    Result = BindPort(Port, true);

    Log("[UDP] BindPort requested="$Port$" result="$Result);
}

event ReceivedText(IpAddr Addr, string Text)
{
    local PlayerController PC;

    Log("[UDP] ReceivedText from "$IpAddrToString(Addr)$": '"$Text$"'");

    foreach DynamicActors(class'PlayerController', PC)
    {
        break;
    }

    if (OwnerMutator != None)
    {
        Log("[UDP] Forwarding to mutator: "$Text);
        OwnerMutator.ExecuteExternalCommand(Text, PC);
    }
    else
    {
        Log("[UDP] OwnerMutator is None");
    }
}
