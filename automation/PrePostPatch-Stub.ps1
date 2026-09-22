# DEMO STUB ONLY.
# Illustrates the shape of a pre/post maintenance event hook for "app-aware" patching.
# It is NOT wired to a real application — it only writes narration-friendly log entries.
param(
    [Parameter(Mandatory = $false)]
    [string]$EventType = 'Unknown' # expected values in a real integration: 'Pre' or 'Post'
)

Write-Output "=== AUM Demo Pre/Post Patch Stub ==="
Write-Output "Event type: $EventType"
Write-Output "Timestamp (UTC): $(Get-Date -AsUTC -Format o)"

switch ($EventType) {
    'Pre' {
        Write-Output "STUB: would drain load balancer / stop app pool / quiesce database here."
    }
    'Post' {
        Write-Output "STUB: would validate app health endpoint / re-enable load balancer here."
    }
    default {
        Write-Output "STUB: no-op — invoked without a recognized event type."
    }
}

Write-Output "=== End of stub — no real application was contacted ==="
