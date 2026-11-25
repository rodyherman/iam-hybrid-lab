# New-CAPolicies.ps1 - Regles d'acces conditionnel CA001 a CA004
# Creees en report-only, puis activees une par une apres lecture des journaux
# Les comptes d'urgence (GRP_Exclusion_CA_BreakGlass) sont exclus partout
# Rody - labo IAM RODy, phase 5

Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Policy.Read.All", "Group.Read.All"

$exclusion = (Get-MgGroup -Filter "displayName eq 'GRP_Exclusion_CA_BreakGlass'").Id
"Groupe d'exclusion : $exclusion"     # si vide -> on arrete tout
$mode = "enabledForReportingButNotEnforced"

# Roles admin vises par CA003 (ID identiques dans tous les tenants)
$rolesAdmin = @(
  "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
  "e8611ab8-c189-46e8-94e1-60213ab1f814", # Privileged Role Administrator
  "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
  "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9", # Conditional Access Administrator
  "fe930be7-5e62-47db-91af-98c3a49a38b1", # User Administrator
  "c4e39bd9-1100-46d3-8c65-fb160da0071f", # Authentication Administrator
  "729827e3-9c14-49f7-bb1b-9608f156bbb8", # Helpdesk Administrator
  "8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2", # Hybrid Identity Administrator
  "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3", # Application Administrator
  "158c047a-c907-4556-b7ef-446551a6b5f7", # Cloud Application Administrator
  "29232cdf-9323-42fd-ade2-1d097af3e4de", # Exchange Administrator
  "f28a1f50-f6e7-4571-818b-6a12f2af6b6c", # SharePoint Administrator
  "b0f54661-2d74-4c50-afa3-1ec803f12efe"  # Billing Administrator
)
$phishingResistant = "00000000-0000-0000-0000-000000000004"   # force d'authentification integree

# Emplacement nomme pour CA004
$nomLieu = "Pays autorises - Belgique"
$lieu = Get-MgIdentityConditionalAccessNamedLocation -All | Where-Object DisplayName -eq $nomLieu
if (-not $lieu) {
  $lieu = New-MgIdentityConditionalAccessNamedLocation -BodyParameter @{
    "@odata.type"                     = "#microsoft.graph.countryNamedLocation"
    displayName                       = $nomLieu
    countriesAndRegions               = @("BE")
    includeUnknownCountriesAndRegions = $false
  }
}

$tous = @{ includeUsers = @("All"); excludeGroups = @($exclusion) }
$apps = @{ includeApplications = @("All") }

$regles = @(
  @{ displayName = "CA001 - Tous les utilisateurs - Toutes les apps - Exiger MFA"; state = $mode
     conditions = @{ users = $tous; applications = $apps; clientAppTypes = @("all") }
     grantControls = @{ operator = "OR"; builtInControls = @("mfa") } },

  # l'authentification heritee ne sait pas faire de MFA -> password spray
  @{ displayName = "CA002 - Tous les utilisateurs - Authentification heritee - Bloquer"; state = $mode
     conditions = @{ users = $tous; applications = $apps; clientAppTypes = @("exchangeActiveSync", "other") }
     grantControls = @{ operator = "OR"; builtInControls = @("block") } },

  @{ displayName = "CA003 - Roles admin - Toutes les apps - MFA resistante au phishing"; state = $mode
     conditions = @{ users = @{ includeRoles = $rolesAdmin; excludeGroups = @($exclusion) }
                     applications = $apps; clientAppTypes = @("all") }
     grantControls = @{ operator = "OR"; authenticationStrength = @{ id = $phishingResistant } } },

  @{ displayName = "CA004 - Tous les utilisateurs - Hors Belgique - Bloquer"; state = $mode
     conditions = @{ users = $tous; applications = $apps; clientAppTypes = @("all")
                     locations = @{ includeLocations = @("All"); excludeLocations = @($lieu.Id) } }
     grantControls = @{ operator = "OR"; builtInControls = @("block") } }
)

$existantes = (Get-MgIdentityConditionalAccessPolicy -All).DisplayName
foreach ($r in $regles) {
  if ($existantes -contains $r.displayName) { "Deja presente : $($r.displayName)"; continue }
  New-MgIdentityConditionalAccessPolicy -BodyParameter $r | Out-Null
  "Creee : $($r.displayName)"
}

# Security Defaults incompatibles avec l'acces conditionnel.
# Attention : plus de MFA imposee tant que CA001 n'est pas activee.
Update-MgPolicyIdentitySecurityDefaultEnforcementPolicy -IsEnabled:$false

"Security Defaults : " + (Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy).IsEnabled
Get-MgIdentityConditionalAccessPolicy -All | Sort-Object DisplayName | Format-Table DisplayName, State

# Activation, une regle a la fois, avec un test entre chaque :
#   Enable-CA "CA002" ; Enable-CA "CA001" ; Enable-CA "CA003" ; Enable-CA "CA004"
function Enable-CA ($numero) {
  $p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object DisplayName -like "$numero *"
  Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $p.Id -State "enabled"
  "$($p.DisplayName) -> activee"
}
