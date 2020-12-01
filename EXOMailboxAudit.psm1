Get-ChildItem "$($PSScriptRoot)\function\*.ps1" |
ForEach-Object {
    . $_.FullName
}