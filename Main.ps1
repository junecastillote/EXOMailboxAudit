#EDIT THESE VALUES
#1. Where is your script file (.PS1) located?
$scriptFile = "C:\Scripts\Enable-EXOMailboxAudit"

#2. Where do we save the backup?
$outputDirectory = "C:\Scripts\Enable-EXOMailboxAudit\Output"

#3. Where do we put the transcript log?
$logDirectory = "C:\Scripts\Enable-EXOMailboxAudit\Log"

#4. Which XML file contains your Office 365 Login?
#   If you don't have this yet, run this: Get-Credential | Export-CliXML <file.xml>
$credentialFile = "C:\Scripts\Enable-EXOMailboxAudit\credential.xml"

#5. If we will send the email summary, what is the sender email address we should use?
#   This must be a valid, existing mailbox and address in Office 365
#   The account you use for the Credential File must have "Send As" permission on this mailbox
$sender = "sender@domain.com"

#6. Who are the recipients?
#   Multiple recipients can be added (eg. "recipient1@domain.com","recipient2@domain.com")
$recipients = "recipient1@domain.com","recipient2@domain.com"

#7. If you want to delete older backups, define the age in days.
$removeOldFiles = 60

#8. Do you want to send the email summary? $true or $false
$sendEmail = $true

#10. Audit Log Age Limit
$AuditLogAgeLimit = 180

#11. text file containing the list of PrimarySMTPAddress to exclude
$exclusionListFile = "C:\Scripts\Enable-EXOMailboxAudit\exclusionList.txt"

#12. Test Mode - if specified, the script will execute but will NOT apply auditing configuration
$testMode = $true

#------------------------------------------

#DO NOT TOUCH THE BELOW CODES
$credential = Import-Clixml $credentialFile
$exclusionList = Get-Content $exclusionListFile
$params = @{
    outputDirectory = $outputDirectory
    logDirectory = $logDirectory
    credential = $credential
    sender = $sender
    recipients = $recipients
    removeOldFiles = $removeOldFiles
    sendEmail = $sendEmail
    AuditLogAgeLimit = $AuditLogAgeLimit
    exclusionList = $exclusionList
    testMode = $testMode
}

& "$scriptFile" @params