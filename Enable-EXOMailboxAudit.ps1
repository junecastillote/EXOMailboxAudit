<#	
	.NOTES
	===========================================================================
	 Created on:   	7-August-2018
	 Created by:   	June Castillote
					june.castillote@gmail.com
	 Filename:     	Enable-EXOMailboxAudit.ps1
	 Version:		1.0 (7-August-2018)
	===========================================================================

	.LINK
		https://www.lazyexchangeadmin.com/2018/09/EnableEXOMailboxAudit.html

	.SYNOPSIS
		Use Enable-EXOMailboxAudit.ps1 to enable non mailbox owner access auditing on all mailboxes, with reporting.

	.DESCRIPTION
		This will enable the Non-Owner Mailbox Audit, and will create a report of mailboxes that were enabled for audit.
		
	.EXAMPLE
		.\Enable-EXOMailboxAudit.ps1

#>

$scriptVersion = "1.0"

#Function to create new EXO Session
Function New-EXOSession()
{
	param([parameter(mandatory=$true)]$exoCredential)

	#discard all PSSession
	Get-PSSession | Remove-PSSession -Confirm:$false

	#create new Exchange Online Session
	$EXOSession = New-PSSession -ConfigurationName "Microsoft.Exchange" -ConnectionUri 'https://ps.outlook.com/powershell' -Credential $exoCredential -Authentication Basic -AllowRedirection
	$office365_Session = Import-PSSession $EXOSession -DisableNameChecking
}

$enableDebug = $true

$script_root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

#Start Debug Log
if ($enableDebug) {Start-Transcript -Path ($script_root + "\debugLog.txt") -Append}

#<O365 CREDENTIALS
#Note: This uses an encrypted credential (XML). To store the credential:
#1. Login to the Server/Computer using the account that will be used to run the script/task
#2. Run this "Get-Credential | Export-CliXml Office365StoredCredential.xml"
#3. Make sure that Office365StoredCredential.xml is in the same folder as the script.
$onLineCredential = Import-Clixml "$($script_root)\Office365StoredCredential.xml"
#O365 CREDENTIALS>

#<mail variables
$sendEmail = $true
$sender = "Office 365 Report <office365report@lazyexchangeadmin.com>"
$recipients = "june.castillote@lazyexchangeadmin.com"
$subject = "[Office 365] Enable Non-Owner Mailbox Audit"
$smtpServer = "smtp.office365.com"
$smtpPort = "587"
#mail variables>

#open new Exchange Online Session
Write-Host (Get-Date) ': Login to Exchange Online... ' -ForegroundColor Yellow
New-EXOSession $onlineCredential

#Get all mailboxes with disabled auditing
Write-Host (Get-Date) ': Retrieving Mailbox List... ' -ForegroundColor Yellow -NoNewLine
$mailboxes = Get-Mailbox -ResultSize Unlimited -Filter {(RecipientTypeDetails -eq "UserMailbox" -or RecipientTypeDetails -eq "SharedMailbox" -or RecipientTypeDetails -eq "RoomMailbox" -or RecipientTypeDetails -eq "DiscoveryMailbox") -and (AuditEnabled -eq $false)} | Sort-Object PrimarySMTPAddress
Write-Host 'Done' -ForegroundColor Green
$mailboxCount = ($mailboxes | Measure-Object).Count
Write-Host (Get-Date) ": Found $($mailboxCount) with audit logs disabled" -ForegroundColor Yellow

if ($mailboxes){

	$outputCsvFile = $script_root +"\EnableMailboxAudit$((get-date).tostring("yyyy_MM_dd-hh_mm_tt")).csv"
	Write-Host (Get-Date) ": Saving Mailbox List to $($outputCsvFile)" -ForegroundColor Yellow
	$mailboxes | Select-Object PrimarySMTPAddress | export-csv -nti $outputCsvFile

	Write-Host (Get-Date) ": Enable Mailbox Auditing" -ForegroundColor Yellow

	foreach ($mailbox in $mailboxes)
	{
		Write-Host (Get-Date) ":          -->> $($mailbox.PrimarySMTPAddress)" -ForegroundColor Green
		#Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $true -AuditLogAgeLimit 180 -AuditAdmin Update, MoveToDeletedItems, SoftDelete, HardDelete, SendAs, SendOnBehalf, Create, UpdateFolderPermission -AuditDelegate Update, SoftDelete, HardDelete, SendAs, Create, UpdateFolderPermissions, MoveToDeletedItems, SendOnBehalf -AuditOwner UpdateFolderPermission, MailboxLogin, Create, SoftDelete, HardDelete, Update, MoveToDeletedItems 
	}

	if ($sendEmail -eq $true)
		{
			Write-Host (Get-Date) ": Sending Email Report" -ForegroundColor Yellow
			$mailBody = "Attached is the list of mailboxes whose auditing were enabled by this script <br /><a href=""https://www.lazyexchangeadmin.com/2018/09/EnableEXOMailboxAudit.html"">Enable-EXOMailboxAudit.ps1 v$($scriptVersion)</a>"
			Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -To $recipients -From $sender -Subject $subject -Body $mailBody -BodyAsHTML -Credential $onlineCredential -UseSSL -Attachments $outputCsvFile
		}
}

if ($enableDebug) {Stop-Transcript}