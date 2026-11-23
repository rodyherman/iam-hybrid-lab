# Add-CustomDomain.ps1
# Ajoute et vérifie un domaine personnalisé dans Microsoft Entra ID avec Microsoft Graph.
# Projet : labo IAM hybride RODy — Phase 4

$domaine = "rodylabo.be"

# --- 1. Installer les modules (une seule fois) ---
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser

# --- 2. Se connecter avec le minimum de droits nécessaires ---
Connect-MgGraph -Scopes "Domain.ReadWrite.All"
Get-MgContext | Select-Object Account, Scopes

# --- 3. Ajouter le domaine et afficher l'enregistrement TXT à créer chez OVH ---
New-MgDomain -Id $domaine
(Get-MgDomainVerificationDnsRecord -DomainId $domaine | Where-Object RecordType -eq "Txt").AdditionalProperties.text

# --- 4. Après l'ajout du TXT chez OVH (5 à 15 min) : vérifier le domaine ---
Confirm-MgDomain -DomainId $domaine
Get-MgDomain | Select-Object Id, IsVerified, IsDefault

# --- 5. Se déconnecter ---
Disconnect-MgGraph