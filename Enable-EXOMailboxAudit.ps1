<#PSScriptInfo

.VERSION 1.1

.GUID 4bfcebec-6432-4a11-9f5c-5cb9f98f8420

.AUTHOR June Castillote

.COMPANYNAME www.lazyexchangeadmin.com

.COPYRIGHT june.castillote@gmail.com

.TAGS Office365 Script PowerShell Tool Report Export Audit Mailbox

.LICENSEURI

.PROJECTURI https://github.com/junecastillote/Enable-EXOMailboxAudit

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
	
.PRIVATEDATA

#>

<#	
	.DESCRIPTION
	This will enable the Non-Owner Mailbox Audit, and will create a report of mailboxes that were enabled for audit.
	
	.SYNOPSIS
	Use Enable-EXOMailboxAudit.ps1 to enable non mailbox owner access auditing on all mailboxes, with reporting.
		
	.EXAMPLE
	.\Enable-EXOMailboxAudit.ps1
#>
Param(
        # office 365 credential
        # you can pass the credential using variable ($credential = Get-Credential)
        # then use parameter like so: -credential $credential
        # OR created an encrypted XML (Get-Credential | export-clixml <file.xml>)
        # then use parameter like so: -credential (import-clixml <file.xml>)
        [Parameter(Mandatory=$true,Position=0)]
        [pscredential]$credential,        

        #path to the output directory (eg. c:\scripts\output)
        [Parameter(Mandatory=$true,Position=1)]
		[string]$outputDirectory,
		
		#limit the result
        [Parameter(Mandatory=$true,position=2)]
		$resultSizeLimit,
		
		[Parameter(Mandatory=$true,position=3)]
		$AuditLogAgeLimit,

        #path to the log directory (eg. c:\scripts\logs)
        [Parameter()]
        [string]$logDirectory=(Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)+"\Logs",
        
        #Sender Email Address
        [Parameter()]
        [string]$sender,

        #Recipient Email Addresses - separate with comma
        [Parameter()]
        [string[]]$recipients,

        #Switch to enable email report
        [Parameter()]
        [switch]$sendEmail,

        #Delete older files (in days)
        [Parameter()]
		[int]$removeOldFiles,
		
		#Exclusion List
		[Parameter()]
		[string[]]$exclusionList,

		#Test Mode
		[Parameter()]
		[switch]$testMode
)

$script_root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
#Import Functions
. "$script_root\Functions.ps1"

Stop-TxnLogging
Clear-Host
$scriptInfo = Test-ScriptFileInfo -Path $MyInvocation.MyCommand.Definition


#parameter check ----------------------------------------------------------------------------------------------------
$isAllGood = $true

if ($sendEmail)
{
    if (!$sender)
    {
        Write-Host "ERROR: A valid sender email address is not specified." -ForegroundColor Yellow
        $isAllGood = $false
    }

    if (!$recipients)
    {
        Write-Host "ERROR: No recipients specified." -ForegroundColor Yellow
        $isAllGood = $false
    }
}

if ($isAllGood -eq $false)
{
    EXIT
}
#----------------------------------------------------------------------------------------------------



#Set Paths-------------------------------------------------------------------------------------------
$Today=Get-Date
[string]$fileSuffix = '{0:dd-MMM-yyyy_hh-mm_tt}' -f $Today
$logFile = "$($logDirectory)\Log_$($fileSuffix).txt"

#Create folders if not found
if ($logDirectory)
{
    if (!(Test-Path $logDirectory)) 
    {
        New-Item -ItemType Directory -Path $logDirectory | Out-Null
        #start transcribing----------------------------------------------------------------------------------
        Start-TxnLogging $logFile
        #----------------------------------------------------------------------------------------------------
    }
	else
	{
		Start-TxnLogging $logFile
	}
}

if (!(Test-Path $outputDirectory)) 
{
	New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
#----------------------------------------------------------------------------------------------------

#<mail variables
$subject = "Enable Mailbox Audit Task"
$smtpServer = "smtp.office365.com"
$smtpPort = "587"
#mail variables>

if ($testMode)
{
	Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ': TEST MODE ' -ForegroundColor Yellow
}
#open new Exchange Online Session
Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ': Login to Exchange Online... ' -ForegroundColor Yellow

#Connect to O365 Shell
try 
{
    New-EXOSession $credential
}
catch 
{
    Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": There was an error connecting to Exchange Online. Terminating Script" -ForegroundColor YELLOW
    Stop-TxnLogging
    EXIT
}

$tenantName = (Get-OrganizationConfig).DisplayName

#Get all mailboxes with disabled auditing
Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ': Retrieving Mailbox List... ' -ForegroundColor Yellow
$mailboxes = Get-Mailbox -Filter {(RecipientTypeDetails -eq "UserMailbox" -or RecipientTypeDetails -eq "SharedMailbox" -or RecipientTypeDetails -eq "RoomMailbox" -or RecipientTypeDetails -eq "DiscoveryMailbox") -and (AuditEnabled -eq $false)} | Sort-Object PrimarySMTPAddress
$mailboxCount = ($mailboxes | Measure-Object).Count
Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Found $($mailboxCount) with audit logs disabled" -ForegroundColor Yellow
if ($exclusionList) {
	Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Found $($exclusionList.count) from the Exclusion List" -ForegroundColor Yellow
}

$includedMailbox = 0
if ($mailboxes){

	$outputFile = "$($outputDirectory)\output_$($fileSuffix).txt"
	Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Saving Mailbox List to $($outputFile)" -ForegroundColor Yellow
	#$mailboxes | Select-Object PrimarySMTPAddress | export-csv -nti $outputFile

	Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Enable Mailbox Auditing" -ForegroundColor Yellow

	foreach ($mailbox in $mailboxes)
	{
		if ($exclusionList -and $exclusionList -contains "$($mailbox.PrimarySMTPAddress)")
		{
			Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ":          -->> $($mailbox.PrimarySMTPAddress) -- EXCLUDE" -ForegroundColor RED
		}
		else 
		{
			Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ":          -->> $($mailbox.PrimarySMTPAddress)" -ForegroundColor Green

			if (!$testMode)
			{
				Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $true -AuditLogAgeLimit $AuditLogAgeLimit -AuditAdmin Update, MoveToDeletedItems, SoftDelete, HardDelete, SendAs, SendOnBehalf, Create, UpdateFolderPermission -AuditDelegate Update, SoftDelete, HardDelete, SendAs, Create, UpdateFolderPermissions, MoveToDeletedItems, SendOnBehalf -AuditOwner UpdateFolderPermission, MailboxLogin, Create, SoftDelete, HardDelete, Update, MoveToDeletedItems	
			}
			$mailbox.PrimarySMTPAddress | Out-File $outputFile -Append
			$includedMailbox = $includedMailbox+1
		}		
	}

	if ($sendEmail -and $includedMailbox -gt 0)
	{
		Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Sending Email Report" -ForegroundColor Yellow
		$mailBody = "Attached is the list of mailboxes whose auditing were enabled by this script <br /><a href=""$($scriptInfo.ProjectURI)"">$($scriptInfo.Name)</a> version $($scriptInfo.version)"
		$mailParams = @{
			smtpServer = $smtpServer
			port = $smtpPort
			to = $recipients
			from = $sender
			subject = "[$($tenantName)] $($subject)"
			useSSL = $true
			credential = $credential
			body = $mailBody
			bodyAsHTML = $true
			Attachments = $outputFile
		}
		Send-MailMessage @mailParams
	}
}

#Invoke Housekeeping---------------------------------------------------------------------------------
#if ($enableHousekeeping)
if ($removeOldFiles)
{
	Write-Host (get-date -Format "dd-MMM-yyyy hh:mm:ss tt") ": Deleting backup files older than $($removeOldFiles) days" -ForegroundColor Yellow
	Invoke-Housekeeping -folderPath $outputDirectory -daysToKeep $removeOldFiles
	Invoke-Housekeeping -folderPath $logDirectory -daysToKeep $removeOldFiles
}
#-----------------------------------------------------------------------------------------------

Stop-TxnLogging