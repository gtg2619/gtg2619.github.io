$currentDateTime = Get-Date
$timeStamp = $currentDateTime.ToString("yyyy-MM-ddTHH:mm:sszzz")
Write-Output $timeStamp
Read-Host
exit 0