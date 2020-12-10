## Dot-Source all functions
Get-ChildItem "$($PSScriptRoot)\source\*.ps1" |
ForEach-Object {
    . $_.FullName
}

## import the applicable actions for each logon type
## reference: https://docs.microsoft.com/en-us/microsoft-365/compliance/enable-mailbox-auditing?view=o365-worldwide#mailbox-actions-for-user-mailboxes-and-shared-mailboxes
$global:MailboxAuditSet = Import-Csv -Path "$($PSScriptRoot)\source\MailboxAuditSet.csv"