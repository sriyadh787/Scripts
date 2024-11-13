Function Connect-Entra

{
    try {
       # Define required permissions with reasons

        $requiredPermissions = @(
            @{

                Permission = "User.Read.All"

                Reason     = "Required to read user profile information and check group memberships"
            },

            @{
                Permission = "Group.Read.All"

                Reason     = "Needed to read group information and memberships"
            },

            @{
                Permission = "DeviceManagementConfiguration.ReadWrite.All"

                Reason     = "Allows reading Intune device configuration policies and their assignments"
            },

            @{
                Permission = "DeviceManagementApps.ReadWrite.All"

                Reason     = "Necessary to read mobile app management policies and app configurations"
            },

            @{
                Permission = "DeviceManagementManagedDevices.Read.All"

                Reason     = "Required to read managed device information and compliance policies"
            },

            @{

                Permission = "Device.Read.All"

                Reason     = "Needed to read device information from Entra ID"
            }
        )
   
    # Connect

        $permissionsList = ($requiredPermissions | ForEach-Object { $_.Permission }) -join ', '

        $connectionResult = Connect-MgGraph -Scopes $permissionsList -NoWelcome -ErrorAction Stop

       

        # Check and display the current permissions

        $context = Get-MgContext

        $currentPermissions = $context.Scopes

   

        Write-Host "Checking required permissions:" -ForegroundColor Cyan

        $missingPermissions = @()

        foreach ($permissionInfo in $requiredPermissions) {

            $permission = $permissionInfo.Permission

            $reason = $permissionInfo.Reason
            
            # Check if either the exact permission or a "ReadWrite" version of it is granted

            $hasPermission = $currentPermissions -contains $permission -or $currentPermissions -contains $permission.Replace(".Read", ".ReadWrite")
            if ($hasPermission) {

                Write-Host "  [✓] $permission" -ForegroundColor Green

                Write-Host "      Reason: $reason" -ForegroundColor Gray

            }
            else {

                Write-Host "  [✗] $permission" -ForegroundColor Red

                Write-Host "      Reason: $reason" -ForegroundColor Gray

                $missingPermissions += $permission

            }

        }

        if ($missingPermissions.Count -eq 0) {

            Write-Host "All required permissions are present." -ForegroundColor Green

            Write-Host ""

        }

        else {

            Write-Host "WARNING: The following permissions are missing:" -ForegroundColor Red

            $missingPermissions | ForEach-Object {

                $missingPermission = $_

                $reason = ($requiredPermissions | Where-Object { $_.Permission -eq $missingPermission }).Reason

                Write-Host "  - $missingPermission" -ForegroundColor Yellow

                Write-Host "    Reason: $reason" -ForegroundColor Gray

            }

            Write-Host "The script will continue, but it may not function correctly without these permissions." -ForegroundColor Red

            Write-Host "Please ensure these permissions are granted to the app registration for full functionality." -ForegroundColor Yellow

           

            $continueChoice = Read-Host "Do you want to continue anyway? (y/n)"

            if ($continueChoice -ne 'y') {

                Write-Host "Script execution cancelled by user." -ForegroundColor Red

                exit

            }

        }

    }
    catch {

        Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
        exit
    }
}

Connect-Entra
function Get-Configurations {

    param (

        [string]$uri,

        [string]$groupId,

        [string]$type

    )
    $response = Invoke-MgGraphRequest -Uri $uri -Method Get
    $allItems = @()

 

    # Handle pagination

    while ($response) {

        $allItems += $response.value

        $response = if ($response.'@odata.nextLink') {

            Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method Get

        } else {

            $null

        }

    }

 

    # Filter relevant items for the specified group

    $relevantItems = $allItems | Where-Object {

        $itemId = $_.id

        $assignmentsUri = "$uri/$itemId/assignments"

        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get

 

        $assignmentResponse.value | Where-Object {

            $_.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget" -and $_.target.groupId -eq $groupId

        }

    }

 

    return $relevantItems | ForEach-Object {

        [PSCustomObject]@{

            Type = $type

            Name = if ($_.displayName) { $_.displayName } else { $_.name }

        }

    }

}

 

function Get-AllConfigurations {

    param (

        [string]$groupId

    )

 

    $uris = @{

        DeviceConfigurations = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"

        SettingsCatalog = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

        AdminTemplates = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations"

        CompliancePolicies = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"

        ComplianceScripts = "https://graph.microsoft.com/beta/deviceManagement/deviceComplianceScripts"

        PlatformScripts = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"

        RemediationScripts = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"

        WindowsUpdateProfiles = "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles"

        EnrollmentConfigs = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations"

        AutopilotDeploymentProfiles = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"

        DriverUpdateProfiles = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"

        FeatureUpdateProfiles = "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"

        GroupPolicyConfigurations = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations"

        MobileAppConfigurations = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations"

        IosManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections"

        AndroidManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections"

        WindowsManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections"

        MdmWindowsInformationProtectionPolicies = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies"

    }

   

    # Initialize a hashtable to hold results for each configuration type

    $results = @{

        DeviceConfigurations = @()

        SettingsCatalogs = @()

        AdminTemplates = @()

        CompliancePolicies = @()

        ComplianceScripts = @()

        PlatformScripts = @()

        RemediationScripts = @()

        WindowsUpdateProfiles = @()

        EnrollmentConfigs = @()

        AutopilotDeploymentProfiles = @()

        DriverUpdateProfiles = @()

        FeatureUpdateProfiles = @()

        GroupPolicyConfigurations = @()

        MobileAppConfigurations = @()

        IosManagedAppProtections = @()

        AndroidManagedAppProtections = @()

        WindowsManagedAppProtections = @()

        MdmWindowsInformationProtectionPolicies = @()

    }

   

    # Fetch configurations for each type and add to respective arrays

    foreach ($key in $uris.Keys) {

        $results[$key] += Get-Configurations -uri $uris[$key] -groupId $groupId -type $key

    }

 

   

    # Output the results

    return $results

}

function Get-AppAssignments {

    param (

        [string]$groupId

    )

 

    # Define URIs for Windows and mobile app configurations

    $windowsAppAssignmentsUri = "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppConfigurations"

    $mobileAppAssignmentsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations"

 

    # Initialize a hashtable to hold results

    $results = @()

 

    # Fetch Windows app assignments

    $windowsAppConfigurations = Invoke-MgGraphRequest -Uri $windowsAppAssignmentsUri -Method Get

 

    foreach ($app in $windowsAppConfigurations.value) {

        $assignmentsUri = "$windowsAppAssignmentsUri/$($app.id)/assignments"

        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get

 

        foreach ($assignment in $assignmentResponse.value) {

            if ($assignment.target.groupId -eq $groupId) {

                $results += [PSCustomObject]@{

                    AppName = $app.displayName

                    AssignmentType = $assignment.intent

                    Status = $assignment.target.groupId -eq $groupId ? "Assigned" : "Not Assigned"

                }

            }

        }

    }

 

    # Fetch Mobile app assignments

    $mobileAppConfigurations = Invoke-MgGraphRequest -Uri $mobileAppAssignmentsUri -Method Get

 

    foreach ($app in $mobileAppConfigurations.value) {

        $assignmentsUri = "$mobileAppAssignmentsUri/$($app.id)/assignments"

        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get

 

        foreach ($assignment in $assignmentResponse.value) {

            if ($assignment.target.groupId -eq $groupId) {

                $results += [PSCustomObject]@{

                    AppName = $app.displayName

                    AssignmentType = $assignment.intent

                    Status = $assignment.target.groupId -eq $groupId ? "Assigned" : "Not Assigned"

                }

            }

        }

    }

 

    # Output the results

    return $results

}

 

# Prompt for the group name

Write-Host "Enter Group Name"

$groupName = Read-Host

 

# Construct the URI to find the group by name

$groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'"

$groupResponse = Invoke-MgGraphRequest -Uri $groupUri -Method Get

 

# Check if the group exists

if ($groupResponse.value.Count -eq 0) {

    Write-Host "No group found with name: $groupName" -ForegroundColor Red

    return  # Exit the script if no group is found

}

 

# Get the group ID

$groupId = $groupResponse.value[0].id

Write-Host "Group Name: $groupName, Group ID: $groupId" -ForegroundColor Green

 

# Run the inventory functions

$allConfigurations = Get-AllConfigurations -groupId $groupId

 

# Display the results

foreach ($key in $allConfigurations.Keys) {

    Write-Host "`n$key Results:" -ForegroundColor Cyan

    $configurations = $allConfigurations[$key]

   

    if ($configurations.Count -eq 0) {

        Write-Host "No configurations found for $key." -ForegroundColor Yellow

    } else {

        foreach ($config in $configurations) {

            Write-Host "$($config.Type): $($config.Name)"

        }

    }

}

 

$exportData = @()

 

# Collect data for export

foreach ($key in $allConfigurations.Keys) {

    foreach ($config in $allConfigurations[$key]) {

        $exportData += [PSCustomObject]@{

            Type = $config.Type

            Name = $config.Name

        }

    }

}

 

# Export to Excel

$exportData | Export-Excel -Path "C:\temp\intune.xlsx" -AutoSize -WorksheetName "Configurations"

Write-Host "Data exported to C:\temp\intune.xlsx" -ForegroundColor Green
