# Architecture du labo IAM hybride — RODy

Ce document décrit l'architecture du labo : l'infrastructure (machines et réseau),
la structure de l'annuaire Active Directory et le modèle de groupes AGDLP.

> **Légende** — bloc **plein foncé** : déjà en place • bloc **en pointillés** : prévu dans les phases suivantes.

## 1. Infrastructure

```mermaid
flowchart TB
  subgraph HOST["PC hôte — Hyper-V (16 Go RAM, SSD NVMe, mémoire dynamique)"]
    subgraph NET["Réseau LAB-NAT 192.168.50.0/24 — passerelle et NAT : 192.168.50.1"]
      direction LR
      CLIENT01["<b>CLIENT01</b> — DHCP<br/>Windows 11 Entreprise<br/>Joint à l'AD"]
      DC01["<b>DC01</b> — 192.168.50.10<br/>Windows Server 2022<br/>AD DS • DNS • DHCP<br/>ad.rodylabo.be"]
      SYNC01["<b>SYNC01</b> — 192.168.50.20<br/>Windows Server 2022<br/>Membre du domaine<br/>Agent Cloud Sync en phase 4"]
      CLIENT02["<b>CLIENT02</b> — DHCP<br/>Windows 11 Entreprise<br/>Joint à Entra ID"]
      CLIENT01 -- "Kerberos • GPO" --> DC01
      SYNC01 -- "lecture LDAP" --> DC01
    end
  end
  subgraph CLOUD["Tenant Microsoft"]
    direction LR
    DNSPUB["Domaine public<br/>rodylabo.be"]
    ENTRA["<b>Microsoft Entra ID</b><br/>MFA • Accès conditionnel<br/>PIM • Revues d'accès"]
    INTUNE["<b>Intune</b><br/>Conformité • Mises à jour"]
    APPS["<b>Applications SSO</b><br/>SAML • OIDC"]
    DNSPUB -. "TXT de vérification" .-> ENTRA
    ENTRA --> APPS
    ENTRA --> INTUNE
  end
  SYNC01 == "synchronisation HTTPS 443" ==> ENTRA
  CLIENT02 -- "jonction Entra + MDM" --> INTUNE

  classDef done fill:#14284B,stroke:#14284B,color:#ffffff
  classDef todo fill:#ffffff,stroke:#8a94a6,color:#14284B,stroke-dasharray: 5 4
  classDef cloud fill:#ffffff,stroke:#0E6E5C,color:#0E6E5C,stroke-dasharray: 5 4
  class DC01,SYNC01,CLIENT01 done
  class CLIENT02 todo
  class ENTRA,INTUNE,APPS,DNSPUB cloud
  style HOST fill:#F7F9FC,stroke:#9AA8BC
  style NET fill:#EEF3FA,stroke:#1F5FAD
  style CLOUD fill:#EAF6F2,stroke:#0E6E5C
```

| Machine | Système | Adresse | Rôle |
|---|---|---|---|
| **DC01** | Windows Server 2022 | 192.168.50.10 (fixe) | Contrôleur de domaine `ad.rodylabo.be` : AD DS, DNS, DHCP |
| **SYNC01** | Windows Server 2022 | 192.168.50.20 (fixe) | Serveur membre (OU Serveurs) — accueillera l'agent Microsoft Entra Cloud Sync |
| **CLIENT01** | Windows 11 Entreprise | DHCP (192.168.50.100) | Poste joint à l'AD (OU Ordinateurs), géré par GPO |
| **CLIENT02** | Windows 11 Entreprise | DHCP (.100 à .150) | Poste joint à Entra ID, géré par Intune |

**Hôte** : portable 16 Go de RAM, SSD NVMe. Les VM utilisent la **mémoire dynamique** Hyper-V et ne sont démarrées que lorsqu'elles sont nécessaires.

**Réseau** : commutateur Hyper-V interne `LAB-NAT` avec NAT sur l'hôte. Les VM sont isolées du réseau
domestique mais accèdent à Internet (indispensable pour joindre Microsoft Entra ID).
L'agent de synchronisation n'ouvre aucun port entrant : il communique uniquement en sortie (HTTPS 443).

**Identité** : domaine AD `ad.rodylabo.be` (NetBIOS `LABO`), suffixe UPN public `rodylabo.be`.
Les utilisateurs se connectent avec `prenom.nom@rodylabo.be`, identique en local et dans le cloud.

## 2. Structure de l'annuaire Active Directory

```mermaid
flowchart TD
  DOM["<b>ad.rodylabo.be</b><br/>NetBIOS : LABO"] --> LABO["OU LABO"]
  LABO --> U["OU Utilisateurs"]
  LABO --> G["OU Groupes"]
  LABO --> O["OU Ordinateurs<br/>GPO : SEC_Postes_Baseline"]
  LABO --> S["OU Serveurs"]
  LABO --> A["OU Admins<br/><i>jamais synchronisée</i>"]
  LABO --> CS["OU Comptes_Service"]
  LABO --> D["OU Desactives"]
  U --> U1["Direction (5)"]
  U --> U2["RH (10)"]
  U --> U3["Finance (15)"]
  U --> U4["IT (15)"]
  U --> U5["Commercial (55)"]
  A --> T0["Tier0<br/>PSO_Admins : 16 car."]
  A --> T1["Tier1"]
  A --> T2["Tier2"]

  classDef dom fill:#14284B,stroke:#14284B,color:#fff
  classDef ou fill:#DDE6F3,stroke:#1F5FAD,color:#14284B
  classDef adm fill:#FDECEC,stroke:#C0392B,color:#7a1f16
  class DOM dom
  class LABO,U,G,O,S,CS,D,U1,U2,U3,U4,U5 ou
  class A,T0,T1,T2 adm
```

- **Une OU par service** sous `Utilisateurs` : ce sont les OU synchronisées vers Entra ID.
- **`Admins` n'est jamais synchronisée** : un compte à privilèges de l'AD ne doit pas exister dans le cloud.
- **Tiering** (Tier 0/1/2) : un compte d'administration Tier 0 ne se connecte jamais sur un poste Tier 2.
- **`Ordinateurs`** reçoit la GPO `SEC_Postes_Baseline` (LLMNR désactivé, verrouillage après 10 min, pare-feu forcé, audit avancé).
- Stratégie de mots de passe du domaine : 12 caractères, verrouillage après 10 essais.
  **PSO_Admins** pour les administrateurs : 16 caractères, verrouillage après 5 essais.

## 3. Modèle de groupes AGDLP

```mermaid
flowchart LR
  A["<b>A</b>ccounts<br/>Arthur Martin<br/>Elena Peeters<br/>… (15 comptes)"] -- "membres de" --> G["<b>G</b>lobal<br/>GG_Finance<br/><i>qui travaille à la Finance</i>"]
  G -- "membre de" --> DL["<b>D</b>omain <b>L</b>ocal<br/>DL_Partage_Finance_RW<br/><i>qui peut modifier le partage</i>"]
  DL -- "reçoit" --> P["<b>P</b>ermissions<br/>Modification du<br/>dossier partagé Finance"]
  classDef a fill:#ffffff,stroke:#1F5FAD,color:#14284B
  classDef g fill:#DDE6F3,stroke:#1F5FAD,color:#14284B
  classDef dl fill:#1F5FAD,stroke:#1F5FAD,color:#fff
  classDef p fill:#14284B,stroke:#14284B,color:#fff
  class A a
  class G g
  class DL dl
  class P p
```

Les **comptes** sont membres de groupes **globaux** (par métier), eux-mêmes membres de groupes
**domaine local** (par ressource), qui seuls reçoivent les **permissions**.
Quand un employé change de service, on le change simplement de groupe global : ses droits suivent automatiquement.

| Service | Groupe global | Groupe domaine local | Membres |
|---|---|---|---|
| Direction | GG_Direction | DL_Partage_Direction_RW | 5 |
| RH | GG_RH | DL_Partage_RH_RW | 10 |
| Finance | GG_Finance | DL_Partage_Finance_RW | 15 |
| IT | GG_IT | DL_Partage_IT_RW | 15 |
| Commercial | GG_Commercial | DL_Partage_Commercial_RW | 55 |
