# ================== Config ==================
$AccountID   = "YOUR_ACCOUNT_ID"       # Cloudflare Account ID
$TunnelID    = "YOUR_TUNNEL_ID"        # Cloudflare Tunnel ID
$API_Token   = "YOUR_API_TOKEN"        # Cloudflare API Token
$RouteDesc   = "Laptop-Local-IPv4"     # Route description

# ================== Get local IPv4 ==================
$CurrentIPv4 = (Get-NetIPAddress -AddressFamily IPv4 `
                | Where-Object { $_.PrefixOrigin -eq "Dhcp" -and $_.IPAddress -notlike "169.254.*" } `
                | Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $CurrentIPv4) {
    Write-Output "No local IPv4 found."
    pause
    exit
}

Write-Output "Current local IPv4: $CurrentIPv4"

# ================== Cloudflare API ==================
$Headers = @{ Authorization = "Bearer $API_Token"; "Content-Type" = "application/json" }
$RouteUrl = "https://api.cloudflare.com/client/v4/accounts/$AccountID/teamnet/routes"

# Get existing routes
$Routes = Invoke-RestMethod -Method Get -Uri $RouteUrl -Headers $Headers
$ExistingRoute = $Routes.result | Where-Object { $_.comment -eq $RouteDesc }

# ================== Check and update ==================
if ($ExistingRoute) {
    if ($ExistingRoute.network -ne "$CurrentIPv4/32") {
        Write-Output "Updating route: $($ExistingRoute.network) -> $CurrentIPv4/32"

        # Delete old route
        Invoke-RestMethod -Method Delete -Uri "$RouteUrl/$($ExistingRoute.id)" -Headers $Headers

        # Add new route
        $Body = @{
            network   = "$CurrentIPv4/32"
            tunnel_id = $TunnelID
            comment   = $RouteDesc
        } | ConvertTo-Json

        Invoke-RestMethod -Method Post -Uri $RouteUrl -Headers $Headers -Body $Body
        Write-Output "Route updated."
    }
    else {
        Write-Output "IPv4 unchanged. No update required."
    }
}
else {
    Write-Output "Adding new route: $CurrentIPv4/32"
    $Body = @{
        network   = "$CurrentIPv4/32"
        tunnel_id = $TunnelID
        comment   = $RouteDesc
    } | ConvertTo-Json

    Invoke-RestMethod -Method Post -Uri $RouteUrl -Headers $Headers -Body $Body
    Write-Output "Route added."
}

pause
