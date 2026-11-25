# Labo IAM hybride — Active Directory + Microsoft Entra ID + Intune

Sécurisation des identités de **RODy**, une entreprise fictive de 100 collaborateurs,
dans un labo hybride construit de zéro.

![Architecture du labo](diagrams/architecture.png)

➡️ Architecture détaillée (infrastructure, structure AD, modèle AGDLP) : [docs/00-architecture.md](docs/00-architecture.md)

## Objectif
Démontrer les compétences d'un administrateur IAM : gestion des identités on-premise,
synchronisation vers le cloud, authentification forte, Zero Trust, privilèges et gouvernance.

## Avancement
| Phase | Sujet | État |
|---|---|---|
| 01 | Réseau Hyper-V (NAT) et création des VM | ✅ |
| 02 | Contrôleur de domaine, OU, 100 comptes, groupes AGDLP, mots de passe, GPO, DHCP | ✅ |
| 03 | Jonction des postes, mises à jour, LAPS, tiering | ✅ |
| 04 | Synchronisation vers Entra ID (Cloud Sync) | ✅ |
| 05 | MFA et accès conditionnel | ✅ |
| 06 | SSO : SAML et OpenID Connect | ⏳ |
| 07 | Intune et postes conformes | ⏳ |
| 08 | PIM et revues d'accès | ⏳ |
| 09 | Automatisation PowerShell / Microsoft Graph | ⏳ |
| 10 | Audit et détection | ⏳ |

## Réalisé jusqu'ici
- Forêt Active Directory `ad.rodylabo.be` (Windows Server 2022), DNS avec redirecteurs, suffixe UPN `rodylabo.be`
- 16 unités d'organisation : services métiers, admins par tier (Tier 0/1/2), comptes de service
- 100 comptes générés et importés par script, avec hiérarchie managériale
- Groupes selon le modèle **AGDLP**
- Stratégie de mots de passe (12 caractères) et **PSO** renforcée pour les admins (16 caractères)
- GPO de sécurité : LLMNR désactivé, verrouillage de session, pare-feu forcé, audit avancé
- Serveur DHCP autorisé dans l'AD
- CLIENT01 (Windows 11) et SYNC01 (Windows Server) joints au domaine, GPO vérifiée sur le poste
- Labo dimensionné pour 16 Go de RAM grâce à la mémoire dynamique Hyper-V
- Serveurs mis à jour (Windows Server 2022 build 20348.5622) avant mise en service
- **Windows LAPS** : mot de passe administrateur local unique par poste, 15 caractères, rotation 30 jours, chiffré dans l'AD
- **Modèle de tiering** : comptes `adm-t0/t1/t2` séparés, Tier 2 administrateur des postes, Tier 0 et Domain Admins interdits de connexion sur les postes (GPO)
- Domaine `rodylabo.be` vérifié dans Entra ID et compte de synchronisation à moindre privilège, créés avec **Microsoft Graph PowerShell**
- **Entra Cloud Sync** sur SYNC01 (compte de service gMSA), hachage des mots de passe, protection contre les suppressions accidentelles
- Résultat vérifié par Graph : **100 utilisateurs et 10 groupes synchronisés, 0 compte d'administration dans le cloud**
- Licences Entra ID P2 attribuées **par groupe** à un pilote de 25 utilisateurs
- **Deux comptes d'urgence** (break-glass) exclus de l'accès conditionnel, protégés par passkey
- Méthodes d'authentification : Authenticator avec contexte affiché, **passkeys**, SMS et appel vocal désactivés
- **Accès conditionnel** (simulé puis activé) : MFA pour tous, authentification héritée bloquée, **MFA résistante au phishing pour les administrateurs**, connexions hors Belgique bloquées

## Environnement
Hyper-V (portable 16 Go de RAM) • Windows Server 2022 • Windows 11 Entreprise • tenant Microsoft Entra ID

## Contenu du dépôt
- `scripts/ad/` : scripts PowerShell de création des comptes
- `scripts/graph/` : scripts Microsoft Graph PowerShell (domaine, synchronisation, licences, comptes d'urgence, méthodes d'authentification, accès conditionnel)
- `docs/` : documentation, architecture et rapports de GPO
- `diagrams/` : schémas d'architecture
- `screenshots/` : captures par phase
- `docs/depannage.md` : **39 problèmes réels rencontrés et résolus**
- `journal.md` : journal de bord

## Auteur
Rody — Junior IAM / Identity Security | CCNA • AZ-104 • MD-102 • SC-300 (en cours)
[LinkedIn](https://www.linkedin.com/in/tchambia-ngandeu-rodi-herman)
