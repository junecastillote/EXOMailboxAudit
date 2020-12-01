
<#PSScriptInfo

.VERSION 1.0

.GUID ef8d8a67-099d-4250-b6ea-bccb73d83a08

.AUTHOR June Castillote

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Helper Functions

#>

#Function to delete old files based on age
Function Invoke-Housekeeping
{
    [CmdletBinding()] 
    param ( 
        [Parameter(Mandatory=$true,position=0)] 
        [string]$folderPath,
    
		[Parameter(Mandatory=$true,position=1)]
		[int]$daysToKeep
    )
    
    $datetoDelete = (Get-Date).AddDays(-$daysToKeep)
    $filesToDelete = Get-ChildItem $FolderPath | Where-Object { $_.LastWriteTime -lt $datetoDelete }

    if (($filesToDelete.Count) -gt 0) {	
		foreach ($file in $filesToDelete) {
            Remove-Item -Path ($file.FullName) -Force -ErrorAction SilentlyContinue
		}
	}
}

#Function to Stop Transaction Logging
Function Stop-TxnLogging
{
	$txnLog=""
	Do {
		try {
			Stop-Transcript | Out-Null
		} 
		catch [System.InvalidOperationException]{
			$txnLog="stopped"
		}
    } While ($txnLog -ne "stopped")
}

#Function to Start Transaction Logging
Function Start-TxnLogging
{
    param 
    (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$logDirectory
    )
	Stop-TxnLogging
    Start-Transcript $logDirectory -Append
}