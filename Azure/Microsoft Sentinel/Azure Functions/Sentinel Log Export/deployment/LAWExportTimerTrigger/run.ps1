# ============================================================================
# Azure Function Script - Log Export/Import using User-Assigned Managed Identity
# ============================================================================
# This version uses User-Assigned Managed Identity for authentication (no secrets required)
# Deploy this as an Azure Function with a User-Assigned Managed Identity that has:
#   1. "Log Analytics Reader" role on PROD workspace (for querying)
#   2. "Monitoring Metrics Publisher" role on the DCR and DCE (for ingestion)
#   3. "Storage Blob Data Owner" role on Function App storage account
# 
# AZURE_CLIENT_ID environment variable must be set to the User-Assigned MI Client ID
# ============================================================================

# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# ============================================================================
# Read Configuration from Environment Variables (Set in Function App Settings)
# ============================================================================

# Production Workspace Configuration
$prodWorkspaceId = $env:PROD_WORKSPACE_ID
if ([string]::IsNullOrEmpty($prodWorkspaceId)) {
    throw "PROD_WORKSPACE_ID environment variable is not set. Please configure it in Function App Settings."
}

# Azure Monitor Log Ingestion API Configuration
$dcrImmutableId = $env:DCR_IMMUTABLE_ID
$dceEndpoint = $env:DCE_ENDPOINT
$streamName = $env:STREAM_NAME

if ([string]::IsNullOrEmpty($dcrImmutableId) -or [string]::IsNullOrEmpty($dceEndpoint) -or [string]::IsNullOrEmpty($streamName)) {
    throw "One or more required environment variables are missing: DCR_IMMUTABLE_ID, DCE_ENDPOINT, STREAM_NAME. Please configure them in Function App Settings."
}

# Date range configuration (optional, defaults to 7 days)
$daysBack = if ($env:DAYS_BACK) { [int]$env:DAYS_BACK } else { 7 }

# State storage configuration (blob-backed for Flex Consumption; falls back to local file on dedicated plans)
# Keep it simple: use the built-in AzureWebJobsStorage connection and account name, with optional container/blob overrides.
$stateStorageAccount          = $env:AzureWebJobsStorage__accountName
$stateStorageContainer        = if ($env:STATE_STORAGE_CONTAINER) { $env:STATE_STORAGE_CONTAINER } else { 'function-deployments' }
$stateStorageBlobName         = if ($env:STATE_STORAGE_BLOB_NAME) { $env:STATE_STORAGE_BLOB_NAME } else { 'lastrun_timestamp.txt' }
$stateStorageConnectionString = $env:AzureWebJobsStorage  # available by default in Function Apps

# Check if we have a last run timestamp stored
# NOTE: Local file works on Dedicated/Premium plans; Flex Consumption has an ephemeral, read-only filesystem.
$lastRunTimestampFile = "$env:HOME\lastrun_timestamp.txt"
$incrementalEnv = if ($env:USE_INCREMENTAL_SYNC) { $env:USE_INCREMENTAL_SYNC.Trim().ToLowerInvariant() } else { "" }
$useIncrementalSync = ($incrementalEnv -eq "true" -or $incrementalEnv -eq "1")
$useBlobState = $useIncrementalSync -and (
    (-not [string]::IsNullOrEmpty($stateStorageAccount)) -or
    (-not [string]::IsNullOrEmpty($stateStorageConnectionString))
)

$startDate = $null  # will be set below; defaults to full sync if no state found
$isIncrementalMode = $false

# Batch size configuration (optional, defaults to 500)
$batchSize = if ($env:BATCH_SIZE) { [int]$env:BATCH_SIZE } else { 500 }

# Log configuration for verification (without exposing sensitive values)
Write-Host "`nConfiguration loaded from environment variables:" -ForegroundColor Cyan
Write-Host "  PROD_WORKSPACE_ID: $($prodWorkspaceId.Substring(0, 8))..." -ForegroundColor Gray
Write-Host "  DCR_IMMUTABLE_ID: $($dcrImmutableId.Substring(0, 15))..." -ForegroundColor Gray
Write-Host "  DCE_ENDPOINT: $dceEndpoint" -ForegroundColor Gray
Write-Host "  STREAM_NAME: $streamName" -ForegroundColor Gray
Write-Host "  DAYS_BACK: $daysBack" -ForegroundColor Gray
Write-Host "  BATCH_SIZE: $batchSize" -ForegroundColor Gray
Write-Host "  USE_INCREMENTAL_SYNC (raw): $env:USE_INCREMENTAL_SYNC  effective=$useIncrementalSync" -ForegroundColor Gray
Write-Host "  STATE_STORAGE: account=$stateStorageAccount container=$stateStorageContainer blob=$stateStorageBlobName connString=$([string]::IsNullOrEmpty($stateStorageConnectionString) -eq $false)" -ForegroundColor Gray

# ============================================================================
# Function: Get-ManagedIdentityToken
# Gets an OAuth token using the Azure Function's User-Assigned Managed Identity
# Requires AZURE_CLIENT_ID environment variable to be set
# ============================================================================
function Get-ManagedIdentityToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceUrl
    )
    
    Write-Host "Retrieving User-Assigned Managed Identity token for resource: $ResourceUrl" -ForegroundColor Cyan
    
    try {
        # Azure Functions provides IDENTITY_ENDPOINT and IDENTITY_HEADER environment variables
        $tokenAuthURI = $env:IDENTITY_ENDPOINT
        $tokenAuthHeader = $env:IDENTITY_HEADER
        $clientId = $env:AZURE_CLIENT_ID
        
        if ([string]::IsNullOrEmpty($tokenAuthURI)) {
            throw "IDENTITY_ENDPOINT environment variable not found. Ensure Managed Identity is enabled on the Function App."
        }
        
        if ([string]::IsNullOrEmpty($clientId)) {
            throw "AZURE_CLIENT_ID environment variable not found. This is required for User-Assigned Managed Identity authentication."
        }
        
        # Include client_id parameter to specify User-Assigned Managed Identity
        $tokenUri = "$($tokenAuthURI)?resource=$ResourceUrl&api-version=2019-08-01&client_id=$clientId"
        $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER" = "$tokenAuthHeader" } -Uri $tokenUri
        
        if ([string]::IsNullOrEmpty($tokenResponse.access_token)) {
            throw "Failed to retrieve access token from User-Assigned Managed Identity."
        }
        
        Write-Host "✓ User-Assigned Managed Identity token retrieved successfully (Client ID: $clientId)" -ForegroundColor Green
        return $tokenResponse.access_token
    }
    catch {
        Write-Error "Failed to get User-Assigned Managed Identity token: $_"
        throw
    }
}

# ============================================================================
# Function: Send-AzMonitorIngestionData
# Sends data to Azure Monitor using the Logs Ingestion API
# ============================================================================
function Send-AzMonitorIngestionData {
    param (
        [Parameter(Mandatory = $true)] [string]$DceEndpoint,
        [Parameter(Mandatory = $true)] [string]$DcrImmutableId,
        [Parameter(Mandatory = $true)] [string]$StreamName,
        [Parameter(Mandatory = $true)] [string]$AccessToken,
        [Parameter(Mandatory = $true)] [object[]]$Data
    )
 
    $uri = "$DceEndpoint/dataCollectionRules/$DcrImmutableId/streams/$StreamName`?api-version=2023-01-01"
    
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    
    $jsonPayload = $Data | ConvertTo-Json -Depth 10 -AsArray
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $jsonPayload -ErrorAction Stop
        return $response
    }
    catch {
        Write-Error "Error sending batch: $_"
        Write-Error "Status Code: $($_.Exception.Response.StatusCode.value__)"
        throw
    }
}

# =================================================================================
# Functions: State management in Blob Storage using Managed Identity (no Az module)
# =================================================================================
function Get-StorageBearerToken {
    return Get-ManagedIdentityToken -ResourceUrl "https://storage.azure.com"
}

function Invoke-StorageRequest {
    param (
        [Parameter(Mandatory = $true)] [string]$Method,
        [Parameter(Mandatory = $true)] [string]$Uri,
        [Parameter()] [string]$Body,
        [Parameter()] [hashtable]$ExtraHeaders
    )
    $headers = @{
        "Authorization" = "Bearer $(Get-StorageBearerToken)"
        "x-ms-version"  = "2020-10-02"
        "x-ms-date"     = (Get-Date).ToUniversalTime().ToString("R")
    }
    if ($Body) { $headers["Content-Type"] = "text/plain" }
    if ($ExtraHeaders) { $ExtraHeaders.GetEnumerator() | ForEach-Object { $headers[$_.Key] = $_.Value } }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $Body -ErrorAction Stop
}

function Ensure-ContainerExists {
    param (
        [Parameter(Mandatory = $true)] [string]$AccountName,
        [Parameter(Mandatory = $true)] [string]$ContainerName
    )
    $uri = "https://$AccountName.blob.core.windows.net/$ContainerName`?restype=container"
    try {
        Invoke-StorageRequest -Method Put -Uri $uri | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 409) {
            throw
        }
    }
}

function Get-LastRunFromBlobRest {
    param (
        [Parameter(Mandatory = $true)] [string]$AccountName,
        [Parameter(Mandatory = $true)] [string]$ContainerName,
        [Parameter(Mandatory = $true)] [string]$BlobName
    )
    $uri = "https://$AccountName.blob.core.windows.net/$ContainerName/$BlobName"
    try {
        return Invoke-StorageRequest -Method Get -Uri $uri
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            return $null
        }
        throw
    }
}

function Set-LastRunInBlobRest {
    param (
        [Parameter(Mandatory = $true)] [string]$AccountName,
        [Parameter(Mandatory = $true)] [string]$ContainerName,
        [Parameter(Mandatory = $true)] [string]$BlobName,
        [Parameter(Mandatory = $true)] [string]$Timestamp
    )
    Ensure-ContainerExists -AccountName $AccountName -ContainerName $ContainerName
    $uri = "https://$AccountName.blob.core.windows.net/$ContainerName/$BlobName"
    Invoke-StorageRequest -Method Put -Uri $uri -Body $Timestamp -ExtraHeaders @{ "x-ms-blob-type" = "BlockBlob" } | Out-Null
}

# ============================================================================
# Resolve sync window (prefers blob state, then local file, else full window)
# ============================================================================
if ($useIncrementalSync -and $useBlobState) {
    try {
        $lastRunFromBlob = Get-LastRunFromBlobRest -AccountName $stateStorageAccount -ContainerName $stateStorageContainer -BlobName $stateStorageBlobName
        if ($lastRunFromBlob) {
            $startDate = $lastRunFromBlob.Trim()
            $isIncrementalMode = $true
            Write-Host "Using incremental sync from blob marker: $startDate" -ForegroundColor Yellow
        }
        else {
            Write-Host "No blob marker found; falling back to default window." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Failed to read blob state: $_"
    }
}

# Local fallback disabled when blob state is available; retained for dedicated/local scenarios.
if (-not $startDate -and $useIncrementalSync -and (-not $useBlobState) -and (Test-Path $lastRunTimestampFile)) {
    $lastRunTime = Get-Content $lastRunTimestampFile -Raw
    $startDate = $lastRunTime.Trim()
    $isIncrementalMode = $true
    Write-Host "Using incremental sync from local file: $startDate" -ForegroundColor Yellow
}

if (-not $startDate) {
    $startDate = (Get-Date).AddDays(-$daysBack).ToString("yyyy-MM-ddTHH:mm:ss")
    Write-Host "Using full sync for last $daysBack days" -ForegroundColor Yellow
}

$endDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")  # Current time

# Log the query date range for visibility
$modeLabel = if ($isIncrementalMode) { 'Incremental Sync' } else { 'Full Sync' }
Write-Host "`nQuery Date Range:" -ForegroundColor Cyan
Write-Host "  Start: $startDate" -ForegroundColor White
Write-Host "  End:   $endDate" -ForegroundColor White
Write-Host "  Mode:  $modeLabel" -ForegroundColor $(if ($isIncrementalMode) { 'Green' } else { 'Yellow' })

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "=== Azure Function: Log Export/Import (Managed Identity) ===" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan

try {
    # Step 1: Get Managed Identity token for Azure Monitor Ingestion API
    Write-Host "`n[1/4] Getting OAuth token for Azure Monitor Ingestion API..." -ForegroundColor Cyan
    $bearerToken = Get-ManagedIdentityToken -ResourceUrl "https://monitor.azure.com"

    # Step 2: Get Managed Identity token for Log Analytics API (for querying workspace)
    Write-Host "`n[2/4] Getting OAuth token for Log Analytics API..." -ForegroundColor Cyan
    $logAnalyticsToken = Get-ManagedIdentityToken -ResourceUrl "https://api.loganalytics.io"
    # Step 3: Execute KQL query on PROD workspace using Managed Identity
    Write-Host "`n[3/4] Querying PROD workspace for Fortinet data..." -ForegroundColor Cyan
    
    # TESTING: Using FortinetCustomLog_CL table to verify end-to-end functionality
    # This will send to Custom-FortinetCustomLog_CL stream
    # Customize and tweak the KQL $query variable’s content to change what data is exported
    $query = @"
FortinetCustomLog_CL
| where TimeGenerated >= datetime($startDate) and TimeGenerated < datetime($endDate)
| where Action == "accept"
"@
    
    Write-Host "Executing query:" -ForegroundColor Gray
    Write-Host $query -ForegroundColor DarkGray    
    
    $queryUri = "https://api.loganalytics.azure.com/v1/workspaces/$prodWorkspaceId/query"
    $queryHeaders = @{
        "Authorization" = "Bearer $logAnalyticsToken"
        "Content-Type"  = "application/json"
    }
    $queryBody = @{
        "query" = $query
    } | ConvertTo-Json
    
    try {
        $queryResponse = Invoke-RestMethod -Uri $queryUri -Method Post -Headers $queryHeaders -Body $queryBody -ErrorAction Stop
        $data = @($queryResponse.tables[0].rows)
        
        Write-Host "✓ Query successful. Rows retrieved: $($data.Count)" -ForegroundColor Green
        
        if ($data.Count -eq 0) {
            Write-Host "`n⚠ No data found for the specified date range:" -ForegroundColor Yellow
            Write-Host "  From: $startDate" -ForegroundColor Yellow
            Write-Host "  To:   $endDate" -ForegroundColor Yellow
            Write-Host "  This is normal if no new logs arrived during this period." -ForegroundColor Gray
            Write-Host "`nℹ Next run will continue from: $endDate" -ForegroundColor Cyan
            
            # Still save timestamp even when no data (to advance the sync window)
            if ($useIncrementalSync) {
                try {
                    if ($useBlobState) {
                        Set-LastRunInBlobRest -AccountName $stateStorageAccount -ContainerName $stateStorageContainer -BlobName $stateStorageBlobName -Timestamp $endDate
                    }
                    else {
                        $endDate | Out-File -FilePath $lastRunTimestampFile -NoNewline -Force
                    }
                    Write-Host "✓ Updated sync marker for next run" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Failed to persist sync marker: $_"
                }
            }
            exit
        }
        
        # Convert rows to objects with column names
        $columns = $queryResponse.tables[0].columns.name
        $results = @()
        foreach ($row in $data) {
            $obj = @{}
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $obj[$columns[$i]] = $row[$i]
            }
            $results += [PSCustomObject]$obj
        }
        $data = $results
    }
    catch {
        Write-Error "Failed to query workspace: $_"
        Write-Error "Please verify the Managed Identity has 'Log Analytics Reader' role on the workspace."
        throw
    }
    
    # Step 4: Send data in batches to NON-PROD workspace
    Write-Host "`n[4/4] Sending $($data.Count) rows to NON-PROD workspace..." -ForegroundColor Cyan
    
    $totalBatches = [Math]::Ceiling($data.Count / $batchSize)
    $successCount = 0
    $failureCount = 0
    
    for ($i = 0; $i -lt $data.Count; $i += $batchSize) {
        $currentBatch = [Math]::Floor($i / $batchSize) + 1
        $endIndex = [Math]::Min($i + $batchSize - 1, $data.Count - 1)
        $batch = $data[$i..$endIndex]
        
        Write-Host "  Sending batch $currentBatch of $totalBatches ($($batch.Count) records)..." -ForegroundColor Cyan
        
        try {
            Send-AzMonitorIngestionData `
                -DceEndpoint $dceEndpoint `
                -DcrImmutableId $dcrImmutableId `
                -StreamName $streamName `
                -AccessToken $bearerToken `
                -Data $batch
            
            $successCount += $batch.Count
            Write-Host "  ✓ Batch $currentBatch sent successfully" -ForegroundColor Green
        }
        catch {
            $failureCount += $batch.Count
            Write-Host "  ✗ Batch $currentBatch failed: $_" -ForegroundColor Red
        }
        
        # Small delay to avoid throttling
        Start-Sleep -Milliseconds 100
    }
    
    # Summary
    Write-Host "`n=== Ingestion Summary ===" -ForegroundColor Cyan
    Write-Host "Sync Window: $startDate -> $endDate" -ForegroundColor Gray
    Write-Host "Total records: $($data.Count)" -ForegroundColor White
    Write-Host "Successfully sent: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })
    
    # Save timestamp for next run (only if all batches succeeded)
    if ($failureCount -eq 0 -and $useIncrementalSync) {
        try {
            if ($useBlobState) {
                Set-LastRunInBlobRest -AccountName $stateStorageAccount -ContainerName $stateStorageContainer -BlobName $stateStorageBlobName -Timestamp $endDate
            }
            else {
                $endDate | Out-File -FilePath $lastRunTimestampFile -NoNewline -Force
            }
            Write-Host "✓ Sync marker advanced to: $endDate" -ForegroundColor Green
            Write-Host "ℹ Next run will query from this timestamp forward" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Failed to persist sync marker: $_"
        }
    }
    
    Write-Host "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    # Return success status for Azure Function
    if ($failureCount -eq 0) {
        Write-Host "`n✓ Function execution completed successfully" -ForegroundColor Green
    }
    else {
        Write-Warning "Function completed with $failureCount failed records"
    }
}
catch {
    Write-Error "Function execution failed: $_"
    throw
}
