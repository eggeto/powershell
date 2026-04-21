<# 
    .SYNOPSIS
    Get the devices from user(s) with more then 1 device

    .DESCRIPTION
    For this script, you need to install the powershell mgraph module.
    It is made for filerting users with more then 1 Company Device(s)!
    from a group or single user
    You can modify the script, for example more then 3 company devices or Personal devices or ...

    .INPUTS
    A group Id from a group, where the member(s) are user(s) => UsersWithMoreCompanyDevices -groupId $groupId
    or for one user, principal name or email => CountCompanyDevices -upn $upn

    .OUTPUTS
    The output is an psobject, contains the user mail and the device names in a list
    you can modify this also to an array or ...

    Made by Eggeto

    .logs
    made 02/06/2025
    added a filter in function UsersWithMoreCompanyDevices,
    no filter yet for function CountCompanyDevices, need to think about that

    .to do
    ask what the user preffer, number of devices, company or personal
#>

Connect-MgGraph -Scopes User.Read.All,GroupMember.Read.All,Group.Read.All

#update in progress

DisConnect-MgGraph
