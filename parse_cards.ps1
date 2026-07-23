$content = Get-Content -Raw "C:\Users\Leahbee\.gemini\antigravity\brain\8fa5e3f3-8ec4-466f-88b5-d0f7eb1cbda7\.system_generated\steps\14\content.md"
$jsonStr = $content -replace '(?s).*---[\r\n]*', ''
$json = $jsonStr | ConvertFrom-Json
$typed = $json.results | Where-Object { $_.type.id -ne 0 }
$grouped = $typed | Group-Object -Property { $_.type.name }
Write-Host 'Total Typed Cards:' $typed.Count
$grouped | Format-Table Count, Name -AutoSize
