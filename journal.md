# Journal de bord — Labo IAM hybride RODy

Suivi quotidien du projet : ce qui a été réalisé, les problèmes rencontrés et ce que j'en ai retenu.
Les problèmes sont détaillés dans [docs/depannage.md](docs/depannage.md).

---

## Mardi 17 novembre 2026 — Phase 1 : préparation et réseau Hyper-V

**Réalisé**
- Téléchargement des ISO d'évaluation : Windows Server 2022 et Windows 11 Entreprise 26H2.
- Libération de place sur le disque système : ISO déplacés de OneDrive vers `D:\ISO`, OneDrive passé en « fichiers à la demande ».
- Configuration de Hyper-V pour stocker les VM sur le SSD `D:` (`Set-VMHost`).
- Création du réseau du labo : commutateur interne **LAB-NAT**, passerelle 192.168.50.1, NAT 192.168.50.0/24.
- Création et installation de la VM **DC01** (génération 2, Windows Server 2022 Desktop Experience).
- Activation de la session améliorée (copier-coller hôte ↔ VM).
- Configuration de DC01 : nom, adresse IP fixe 192.168.50.10, DNS sur lui-même, fuseau horaire de Bruxelles.

**Problèmes rencontrés**
- La VM ne démarrait pas sur l'ISO (*The boot loader failed*) : touche non captée → envoi de la touche Entrée par WMI depuis l'hôte.
- Le ping vers la passerelle échouait alors que HTTPS fonctionnait → ICMP bloqué, test validé avec `Test-NetConnection -Port 443`.

**Appris**
- Un switch Hyper-V interne + NAT isole le labo du réseau domestique tout en gardant l'accès à Internet.
- Un ping qui échoue ne prouve pas une panne : on teste le port du service.

---

## Mercredi 18 novembre 2026 — Phase 2 : le domaine Active Directory

**Réalisé**
- Achat du domaine public **rodylabo.be** (OVHcloud) et activation de la double authentification sur le compte OVH.
- Installation du rôle AD DS et création de la forêt **ad.rodylabo.be** (NetBIOS `LABO`, niveau fonctionnel 2016).
- Vérifications : `Get-ADDomain`, `dcdiag`, partages SYSVOL et NETLOGON.
- Redirecteurs DNS (1.1.1.1, 8.8.8.8) et suffixe UPN **rodylabo.be**.
- Arborescence de **16 OU** : services métiers, Groupes, Ordinateurs, Serveurs, Admins (Tier 0/1/2), Comptes_Service, Desactives.
- Génération d'un CSV de **100 collaborateurs** et import par script, avec la hiérarchie des managers.
- **10 groupes AGDLP** : un groupe global et un groupe domaine local par service.
- Stratégie de mots de passe du domaine (12 caractères, verrouillage après 10 essais) et **PSO_Admins** (16 caractères, 5 essais).

**Problèmes rencontrés**
- `Checkpoint-VM` non reconnue : lancée dans la VM au lieu de l'hôte.
- `dcdiag` : DFSREvent en échec, lié à la promotion récente (partages vérifiés, sans gravité).

**Appris**
- Le nom du domaine se choisit avant la création de la forêt : il est ensuite très difficile à changer.
- L'OU sert à ranger et à appliquer des GPO ; le groupe sert à donner des droits.
- En entreprise, la source des comptes est le service RH (cycle Joiner / Mover / Leaver).
- Une seule stratégie de mots de passe par domaine : les PSO permettent de différencier les administrateurs.

---

## Jeudi 19 novembre 2026 — Phase 2 (suite) : GPO, DHCP et publication

**Réalisé**
- GPO **SEC_Postes_Baseline** liée à l'OU Ordinateurs : LLMNR désactivé, verrouillage de session après 10 minutes,
  pare-feu forcé sur les trois profils, audit avancé (validation des identifiants, comptes, groupes, ouvertures de session).
- Rapport HTML de la GPO pour la documentation.
- Rôle **DHCP** sur DC01 : serveur autorisé dans l'AD, étendue LAB-Clients (192.168.50.100 à .150), options 003, 006 et 015.
- Durée maximale des mots de passe portée à 365 jours (choix documenté).
- Création du compte GitHub, installation de Git, premier envoi du dépôt **iam-hybrid-lab** et tag `v0.2-active-directory`.
- Schémas d'architecture (infrastructure, structure AD, AGDLP) ajoutés au dépôt.

**Problèmes rencontrés**
- L'éditeur de GPO affichait « Not Configured » après la commande PowerShell.
- Nombre de membres des groupes DL affiché `{}` (`.Count` sur un objet unique).
- Git non reconnu après installation (PATH non rechargé).
- Règle `.gitignore` trop large qui aurait exclu une capture.

**Appris**
- Une GPO peut se construire en PowerShell ou à la souris, mais certains réglages (audit avancé) passent par la console.
- Un serveur DHCP doit être autorisé dans l'AD : protection contre les serveurs DHCP pirates.
- Toujours vérifier `git status` avant un commit, et ne jamais publier de secret.

---

## Vendredi 20 novembre 2026 — Phase 3 : postes et serveur membres

**Réalisé**
- Création des VM **SYNC01** et **CLIENT01** (TPM virtuel pour Windows 11).
- Adaptation du labo à **16 Go de RAM** : mémoire dynamique sur DC01, SYNC01 et CLIENT01.
- Installation de CLIENT01 (compte local via *Domain join instead*), adresse **192.168.50.100** reçue du DHCP de DC01.
- Jonction de CLIENT01 au domaine (renommé à la jonction) : rangé automatiquement dans l'OU Ordinateurs.
- Première connexion d'un employé : **arthur.martin@rodylabo.be**, authentifié par `\\DC01`.
- Vérification de la GPO sur CLIENT01 : `EnableMulticast = 0` (LLMNR désactivé).
- Installation de SYNC01, IP fixe 192.168.50.20, jonction au domaine dans l'**OU Serveurs**.
- Mises à jour Windows sur DC01 et SYNC01 : build 20348.169 → **20348.5622** (prérequis de Windows LAPS).
- **Windows LAPS** : extension du schéma, permission sur l'OU Ordinateurs, réglages dans la GPO (AD, 15 caractères, 30 jours, chiffrement).
  Mot de passe de CLIENT01 lu depuis DC01 : `Source : EncryptedPassword`, déchiffrable uniquement par `LABO\Domain Admins`.
- **Tiering** : comptes `adm-t0-rody` (Domain Admins + Protected Users), `adm-t1-rody`, `adm-t2-rody`, groupes `GG_Admins_Tier0/1/2`,
  PSO_Admins étendue aux trois niveaux.
- GPO **ADM_Postes_Tier2** : `GG_Admins_Tier2` administrateur local des postes ; `Domain Admins` et `GG_Admins_Tier0`
  interdits de connexion locale et RDP. Test : `adm-t2-rody` administrateur de CLIENT01, `LABO\Administrator` refusé.

**Problèmes rencontrés**
- Échec de démarrage de SYNC01 : RAM insuffisante (PC à 16 Go et non 32).
- Connexion d'Arthur refusée en session améliorée (droit RDP).
- `gpresult` et `auditpol` refusés dans un terminal non administrateur.
- `Update-LapsADSchema` absente : Windows Server 2022 non mis à jour depuis l'ISO de 2021.
- Plusieurs commandes lancées sur la mauvaise machine (hôte ↔ VM).
- LAPS : compte Administrator intégré désactivé (événement 10067) et attribut de schéma manquant (événement 10108).
- Tous les paramètres LAPS activés par erreur, puis réduits aux cinq utiles.
- Faute de frappe dans le nom du groupe d'une préférence de GPO (`GG_Admind_Tier2`).

**Appris**
- `hostname` avant toute série de commandes ; dans ce labo, l'hôte est en français et les VM en anglais.
- Un serveur installé depuis un ancien média doit être patché avant sa mise en service.
- Un utilisateur standard ne peut pas consulter la sécurité de son poste : c'est voulu.
- Une règle « Deny » l'emporte sur un droit accordé : même un Admin du domaine est bloqué sur les postes.
- Dans une GPO, sélectionner les comptes avec le bouton de recherche (résolution du SID) plutôt que de taper le nom.

**Prochaine étape**
- Phase 4 : tenant Microsoft, vérification de rodylabo.be chez OVH et synchronisation avec **Entra Cloud Sync** depuis SYNC01.

---

## Lundi 23 et mardi 24 novembre 2026 — Phase 4 : synchronisation vers Entra ID

**Réalisé**
- Choix de conserver le tenant existant `rody.onmicrosoft.com` (la création d'un nouveau tenant exige désormais une licence payante).
- Travail côté Entra en **Microsoft Graph PowerShell** depuis VS Code, avec des scopes minimaux et une déconnexion après chaque tâche.
- Ajout du domaine **rodylabo.be** par Graph, enregistrement TXT chez OVH, vérification (`IsVerified : True`).
- Compte cloud **admin-sync** avec le seul rôle *Hybrid Identity Administrator*, créé par script (`New-SyncAdmin.ps1`).
- Réactivation du compte Tier 0 `adm-t0-rody` et prise en main de **PowerShell Direct**.
- Point de contrôle « Avant Cloud Sync » sur DC01 et SYNC01, clé KDS vérifiée (déjà créée par LAPS).
- Installation de l'agent **Microsoft Entra Cloud Sync** sur SYNC01 : gMSA `provAgentgMSA`, dont seul `SYNC01$` peut récupérer le mot de passe.
- Configuration : périmètre limité aux OU **Utilisateurs** et **Groupes**, hachage des mots de passe, protection contre les suppressions accidentelles (seuil 10).
- Test à la demande sur `arthur.martin` (créé), puis sur `adm-t0-rody` (ignoré).
- Activation : statut **Healthy**. Vérification Graph : **100 utilisateurs**, **10 groupes**, **0 compte admin** dans Entra ID.
- Connexion cloud d'Arthur avec son mot de passe AD : le hachage des mots de passe fonctionne, et les Security Defaults imposent l'enregistrement MFA.
- Renumérotation des captures sans trou, point de contrôle « Phase 4 OK - Cloud Sync », tag `v0.4-cloud-sync`.

**Problèmes rencontrés**
- Sous-domaine vide refusé par OVH, variables PowerShell vides, propriétés Graph non renvoyées sans `-Property`.
- Commandes Hyper-V refusées dans le terminal non élevé de VS Code, copier-coller impossible en session de base.
- PowerShell Direct refusé : `adm-t0-rody` était désactivé depuis sa création.
- Enregistrement de l'agent en échec : TLS fort non forcé pour .NET.
- Assistant de l'agent utilisant les identifiants cloud pour chercher le contrôleur de domaine.
- Test à la demande déclarant « in scope » un compte hors périmètre, sans pour autant le créer.

**Appris**
- Deux annuaires, deux comptes : le compte cloud enregistre l'agent, le Domain Admin ne sert qu'à créer le gMSA.
- Un gMSA supprime le problème du mot de passe de compte de service : personne ne le connaît, et il change seul.
- Les comptes d'administration de l'AD ne doivent jamais exister dans le cloud : le périmètre de synchronisation fait partie du tiering.
- `Test-NetConnection` valide TCP, pas TLS.
- Un contrôle de sécurité se prouve sur le résultat réel, pas sur un outil de test.

**Prochaine étape**
- Phase 5 : essai Entra ID P2, comptes d'urgence, méthodes d'authentification résistantes au phishing, remplacement des Security Defaults par l'accès conditionnel.

