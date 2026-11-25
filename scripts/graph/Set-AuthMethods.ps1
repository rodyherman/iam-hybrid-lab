# Set-AuthMethods.ps1 - Methodes d'authentification du tenant
# Authenticator (appli + lieu affiches), passkeys FIDO2 actives, SMS et appel vocal coupes
# Rody - labo IAM RODy, phase 5

Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
Connect-MgGraph -Scopes "Policy.ReadWrite.AuthenticationMethod"

$tous = @{ targetType = "group"; id = "all_users" }

# Authenticator : on affiche l'appli et le lieu dans la notif (contre la MFA fatigue)
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId "MicrosoftAuthenticator" -BodyParameter @{
  "@odata.type"   = "#microsoft.graph.microsoftAuthenticatorAuthenticationMethodConfiguration"
  state           = "enabled"
  includeTargets  = @(@{ targetType = "group"; id = "all_users"; authenticationMode = "any" })
  featureSettings = @{
    displayAppInformationRequiredState      = @{ state = "enabled"; includeTarget = $tous }
    displayLocationInformationRequiredState = @{ state = "enabled"; includeTarget = $tous }
  }
}

# Passkeys : attestation desactivee pour accepter celles d'Authenticator (pas de cle physique)
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId "Fido2" -BodyParameter @{
  "@odata.type"                    = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
  state                            = "enabled"
  isSelfServiceRegistrationAllowed = $true
  isAttestationEnforced            = $false
  includeTargets                   = @($tous)
}

# SMS et vocal : trop faibles (interception, SIM swapping)
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId "Sms" `
  -BodyParameter @{ "@odata.type" = "#microsoft.graph.smsAuthenticationMethodConfiguration"; state = "disabled" }
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId "Voice" `
  -BodyParameter @{ "@odata.type" = "#microsoft.graph.voiceAuthenticationMethodConfiguration"; state = "disabled" }

(Get-MgPolicyAuthenticationMethodPolicy).AuthenticationMethodConfigurations | Format-Table Id, State

Disconnect-MgGraph | Out-Null
