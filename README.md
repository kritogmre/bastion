# 🛡 Bastion — Scanner de vulnérabilités web

Scanner de vulnérabilités web **local**, en deux parties :

- **Backend Python** (100 % bibliothèque standard, *zéro `pip install`*) — crawler + moteur de scan multi-modules. Utilisable en **CLI** ou comme **serveur API local**.
- **Extension Brave / Chrome** (Manifest V3) — interface sombre, scan de l'onglet courant en un clic, pilote le backend.

> ⚠️ **Usage autorisé uniquement.** N'analyse que des sites que **tu possèdes** ou que tu es **explicitement autorisé** à tester (pentest sous contrat, bug bounty dans le périmètre, CTF, ton propre lab). Le scan actif envoie de vrais payloads.

---

## Installation en une ligne

**Linux (Kali / Debian / Ubuntu)**
```bash
curl -fsSL https://raw.githubusercontent.com/kritogmre/bastion/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/kritogmre/bastion/main/install.ps1 | iex
```

L'installeur télécharge la dernière release (backend protégé + extension signée), **vérifie le sha256**, installe Bastion, met en place la commande **`bastion`**, démarre le backend automatiquement à chaque session, et **force-installe l'extension** dans Brave / Chrome / Chromium (elle apparaît toute seule après redémarrage du navigateur, et se met à jour automatiquement). **Aucune dépendance à installer** : un Python autonome est embarqué dans le paquet — rien d'autre n'est requis sur la machine (ni Python, ni pip), sur Linux comme sur Windows.

> Désinstaller : `~/.local/share/bastion/setup.sh --uninstall` (Linux) · `& "$env:LOCALAPPDATA\Bastion\setup.ps1" -Uninstall` (Windows).

---

## Détections

**Passif** (aucun payload envoyé) :
- En-têtes de sécurité (HSTS, **CSP + analyse fine** : unsafe-inline/eval, wildcards, default-src manquant…, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy)
- TLS / certificat (protocole obsolète, expiration, certificat non approuvé, HTTP non chiffré)
- Cookies & sessions (Secure / HttpOnly / SameSite)
- Librairies JS vulnérables → CVE connues (jQuery, Bootstrap, Angular, lodash, moment, DOMPurify, Handlebars…)
- Secrets exposés (clés AWS/Google/Stripe/GitHub…, clés privées, JWT, commentaires sensibles) — **révélation à la demande**
- Fichiers sensibles exposés (`.git`, `.env`, dumps SQL, backups, `phpinfo`, `server-status`…)
- **Reconnaissance DNS** : enregistrements (A/MX/NS/TXT…), **sous-domaines**, **transfert de zone (AXFR)**, **subdomain takeover**, SPF/DMARC manquants
- **Découverte de ressources** : robots.txt / sitemap.xml, fichiers API (Swagger/OpenAPI/GraphQL), **source maps JS**, `.well-known`, Actuator/server-status
- **Détection WAF/CDN** (Cloudflare, Akamai, Imperva…)
- Configuration CORS (origin reflété, wildcard + credentials)
- Méthodes HTTP (TRACE, PUT/DELETE)
- **Intégrité des ressources & contenu mixte** : SRI manquant sur scripts/styles tiers (CDN), ressources HTTP chargées sur une page HTTPS
- **Analyse des JWT** : décode les jetons exposés et signale `alg:none`, signature symétrique faible, absence d'expiration, claims sensibles
- Empreinte technologique + **vérifications WordPress** (version, énum. d'utilisateurs REST, xmlrpc, debug.log)

**Actif** (envoie des payloads — option à cocher) :
- XSS réfléchi (multi-contexte, marqueur, non destructif)
- Injection SQL (error-based / boolean-blind / time-based) · Injection de commande OS · LFI/traversal · SSTI
- **SSRF** (métadonnées cloud + timing aveugle) · **Injection NoSQL** (Mongo/BSON) · **Injection CRLF** (response splitting)
- **XXE** (entités externes XML → lecture de fichiers) · **Upload non restreint** (webshell → RCE) · **IDOR/BOLA** (références d'objet)
- **Redirection ouverte** · **Injection d'en-tête Host** · **Introspection GraphQL**
- **Force brute / login** (cracker dédié, §6)
- Découverte de chemins / fuzzing (calibration soft-404)
- **Moteur d'escalade** : exploite réellement (read-only) les injections confirmées (dump version/user, lecture /etc/passwd…)

**Évasion WAF** 🧬 (toggle Réglages, `waf_evasion`) : quand un payload est bloqué, les modules (xss, sqli, SSRF…) **réessaient des variantes encodées/obfusquées** (URL, double-URL, casse, commentaires SQL, null-byte, %uXXXX). Coûte 0 requête en plus sur les cibles sans WAF.

**Furtivité réseau** 🥷 (Réglages) : **pool de proxies rotatifs** (`proxy_pool`, une IP de sortie par requête) + **renouvellement de circuit Tor** (`tor_control` → SIGNAL NEWNYM toutes les N requêtes) + en-têtes d'évasion (XFF tournant) + UA tournants + low-and-slow. L'IP du scanner n'apparaît pas dans les logs cible.

**Outils Kali optionnels** (toggle « Outils externes » / `--external-tools`) — Bastion les utilise s'ils sont installés, sinon repli 100 % stdlib : **gobuster** (fuzzing étendu), **amass** (sous-domaines), **nmap** (ports & services), **sslscan** (audit TLS approfondi), **wpscan** (plugins WP), **wafw00f** (WAF).

Chaque scan produit un **score (A+ → F)**, un **rapport HTML** autonome, et des exports **JSON / Markdown / CSV / SARIF** (SARIF pour GitHub code scanning & CI). L'historique des scans permet de **suivre l'évolution** (diff « +nouveaux / corrigés », **comparaison de deux scans** au choix, tendance du score). On peut **marquer un finding comme faux positif** (ignoré par host, retiré du score), **demander à l'IA** d'expliquer/corriger un finding précis, et recevoir une **notification webhook (Discord/Slack)** en fin de scan.

---

## 1. Backend

Aucune dépendance à installer (Python 3.8+ suffit, testé sur 3.13 / Kali).

### En ligne de commande

```bash
cd bastion

# Scan passif
python3 backend/bastion.py https://exemple-a-toi.fr

# Scan actif (payloads) + détails + rapport JSON
python3 backend/bastion.py https://exemple-a-toi.fr --active -v --json rapport.json

# Limiter la portée
python3 backend/bastion.py https://exemple-a-toi.fr --no-crawl
python3 backend/bastion.py https://exemple-a-toi.fr --max-pages 10 --depth 1
```

Options utiles : `-a/--active`, `--profile rapide|complet|furtif` (furtif = discret : requêtes espacées + UA tournants), `--cookie "session=…"` / `--auth "Bearer …"` (**scan authentifié**), `--external-tools` (gobuster/amass/nmap/sslscan/wpscan), `-o/--out report.html`, `--json`, `--sarif report.sarif` (CI / code scanning), `--compare ancien.json` (diff), `-v`, `--min-severity high`, `--no-crawl`, `--max-pages`, `--depth`, `--timeout`, `--concurrency`.

### En serveur (pour l'extension)

```bash
python3 backend/bastion.py serve            # http://127.0.0.1:8777
python3 backend/bastion.py serve --port 9000
```

Le serveur n'écoute que sur `127.0.0.1`. Endpoints : `GET /api/health`, `POST /api/scan`, `POST /api/hunt` (**Chasse IA**), `GET /api/scan/<id>`, `GET /api/history`, `GET /api/history/report`, `GET /api/history/compare`, `GET/POST /api/fp` (faux positifs), `GET/POST /api/config`, `POST /api/ai/analyze`, `POST /api/ai/chat`, `GET /api/ai/detect`.

---

## 2. Extension Brave / Chrome

1. Lance le backend : `python3 backend/bastion.py serve`
2. Ouvre `brave://extensions` (ou `chrome://extensions`).
3. Active le **Mode développeur** (en haut à droite).
4. Clique **« Charger l'extension non empaquetée »** et sélectionne le dossier `bastion/extension/`.
5. Épingle l'icône 🛡, ouvre un site **autorisé**, clique l'icône.

La popup s'ouvre sur un **menu d'accueil** :

| Menu | Rôle |
|---|---|
| 🎯 **Pentest complet** | Scan passif + actif de l'onglet courant |
| 🌐 **Recon** | DNS, sous-domaines, robots/sitemap, fichiers API, source maps (passif) |
| 🔓 **Force brute login** | Cracker dédié : listes **users × passwords**, essais **en parallèle**, **fenêtre live** (voir §6) |
| 📊 **Historique** | Scans précédents de l'hôte + tendance du score |
| ✦ **Configurer l'IA** | Claude (cloud) ou IA locale (Ollama) |
| ⚙ **Réglages** | Backend, crawl, **outils externes**, IA locale |

Dans le Pentest tu choisis un **profil** (⚡ Rapide / 🎯 Complet / 🥷 **Furtif** — requêtes espacées avec jitter + user-agents tournants pour rester discret) et tu peux activer le **scan authentifié 🔑** (réutilise les cookies de ta session pour tester l'app connectée). Les résultats affichent le score, une **bannière des données sensibles** (révélation à la demande), le **diff depuis le dernier scan**, un **filtre de recherche**, l'**analyse IA + chat de suivi**, et les exports **JSON / MD / CSV**. Le point coloré en haut indique l'état du backend (vert = connecté). L'état (résultats, analyse IA) est **conservé quand tu fermes la popup** : à la réouverture sur le même site, tu retrouves ton scan — pas besoin de relancer (retour au menu uniquement si tu changes de site ou reviens toi-même à l'accueil).

---

## 3. Tester hors-ligne (légal, sur ta machine)

Un serveur volontairement vulnérable est inclus pour t'entraîner sans toucher à un site tiers :

```bash
# Terminal 1
python3 examples/vulnerable_server.py        # http://127.0.0.1:8000

# Terminal 2
python3 backend/bastion.py http://127.0.0.1:8000 --active -v
```

Tu devrais voir : XSS réfléchi, injection SQL, **redirection ouverte**, **identifiants par défaut admin/admin**, `.env` exposé, clé AWS, jQuery 1.8 vulnérable, cookie non sécurisé, etc. (score **F**).

---

## 4. Assistant IA (Claude **ou** IA locale)

Après un scan, Bastion peut le faire analyser par une IA : synthèse du risque, priorités de correction, faux positifs, quick wins — en français, à des fins **défensives**. Un **chat de suivi** permet ensuite de poser des questions sur les findings et de **générer des configs de correction** (nginx/apache, en-têtes, CSP…).

Deux options, configurables sur **http://127.0.0.1:8777/config** (ou extension : ⚙ → « Configurer l'IA ») :

- **Claude (cloud)** — modèle `claude-opus-4-8` (ou `claude-sonnet-4-6`, `claude-haiku-4-5`). Colle ta **clé API**, puis **Tester**. La clé vit dans `~/.config/bastion/config.json` en **chmod 600**, **hors du dossier du projet** (quand tu partages `bastion/`, ta clé ne part pas avec).
- **IA locale (gratuite, hors-ligne, privée)** — clique **« 🔍 Détecter l'IA locale »** : Bastion détecte **Ollama** / LM Studio et liste les modèles installés (1 clic pour configurer). Il faut un modèle : `ollama pull llama3.2:3b` (l'installeur peut le faire).

L'IA locale est **100 % à la demande** : Bastion **démarre Ollama tout seul** au moment de l'analyse et **l'arrête dès que c'est fini** (zéro empreinte au repos) ; si le modèle configuré n'est pas installé, il bascule automatiquement sur un modèle disponible. Rien n'est jamais envoyé au cloud avec l'IA locale.

> Endpoints backend : `GET /config`, `GET/POST /api/config`, `POST /api/ai/test`, `POST /api/ai/analyze`, `POST /api/ai/chat`, `GET /api/ai/detect`, `POST /api/ai/unload`.

## 5. Chasse IA (mode agentique 🤖)

Là où l'assistant IA *analyse un scan déjà fait*, la **Chasse IA** laisse l'IA **piloter** la recherche, en trois temps :

1. **Recon** — reconnaissance passive + crawl pour cartographier la surface (technos, en-têtes, endpoints, **paramètres & formulaires** découverts).
2. **Plan** — l'IA lit cette surface et renvoie des **hypothèses structurées** : pour chacune, quelle vérification lancer (`xss` / `sqli` / `openredirect` / `hostheader` / `manual`), sur quelle cible/paramètre **déjà découverts**, et pourquoi.
3. **Vérification** — Bastion exécute les **modules existants, bornés et non destructifs** sur exactement les cibles pointées par l'IA, pour **confirmer ou écarter** chaque hypothèse, puis l'IA rédige un débrief priorisé avec corrections.

**Sûreté par conception** : l'IA n'émet jamais de trafic d'attaque brut — elle *choisit* un triplet (module, cible, paramètre) dans une liste fermée, et **chaque cible sondée est validée** contre l'ensemble des cibles réellement découvertes sur l'hôte autorisé (l'IA ne peut pas détourner le scanner ailleurs). La phase de vérification ne tourne qu'en **mode actif** (même consentement qu'un scan actif) ; en passif, on obtient le plan seul.

Depuis l'extension : carte **🤖 Chasse IA** sur l'accueil → profil + bascule « Vérification active » → **Lancer**. Nécessite une IA configurée (Claude ou locale).

> Endpoint : `POST /api/hunt` (body `{target, options}`), suivi via `GET /api/scan/<id>` comme un scan classique ; le rapport porte `mode: "hunt"` avec `hypotheses[]`, `findings[]` confirmés et `summary`.

## 6. Force brute login (fenêtre live 🔓)

À distinguer du module d'**audit** `bruteforce` (qui vérifie juste quelques identifiants par défaut + l'absence de rate-limit) : le **cracker dédié** prend **ta liste d'utilisateurs** et **ta liste de mots de passe**, teste **toutes les combinaisons en parallèle**, et s'exécute **en arrière-plan** dans une **fenêtre live** séparée.

Depuis l'extension : carte **🔓 Force brute login** → colle tes utilisateurs et mots de passe (un par ligne ; **vide = listes par défaut** `data/usernames.txt` / `data/passwords.txt`), règle le **parallélisme** et « arrêter au 1ᵉʳ trouvé », puis **⚡ Lancer en fenêtre live**. La fenêtre montre en temps réel : barre de **%**, compteurs **essais / trouvés / lockout**, la **console de ce que le bot essaie**, les **identifiants trouvés** (clic = copier), et un bouton **⏹ Arrêter**.

- Moteur : `backend/core/bruteforce_engine.py` — détection de formulaire et de succès réutilisée du module d'audit ; `ThreadPoolExecutor` ; arrêt anticipé ; garde-fous (`MAX_COMBOS=5000`, listes cappées) ; conscience du lockout.
- Endpoints : `POST /api/brute` (body `{target, options:{usernames, passwords, concurrency, stop_on_first, field_user?, field_pass?}}`) → `{job_id}` ; suivi via `GET /api/scan/<id>` (le job porte `mode:"brute"` + `stats{tried,total,hits,found,pct}` + `log[]`) ; **`POST /api/brute/<id>/stop`** pour annuler.
- Usage strictement autorisé — cibles que tu possèdes ou es autorisé à tester.

### Furtivité 🥷 (rester discret pendant un test autorisé)

Coche **🥷 Furtif** (ou `options.profile:"furtif"`) pour ne pas déclencher le rate-limit / WAF / IDS de la cible :

- **Low & slow + jitter** : requêtes espacées globalement (même en multi-thread) avec un délai aléatoire, parallélisme plafonné à 3 — le trafic ne ressemble pas à un flood.
- **User-Agents tournants** : chaque requête prend un UA de navigateur réel différent.
- **En-têtes d'évasion** : `X-Forwarded-For` / `X-Real-IP` (IP différente par requête), `Accept-Language` variés → brouille la corrélation WAF/IDS et l'IP loguée côté appli.
- **Ordre aléatoire** : les couples sont mélangés → le même compte n'est pas martelé d'affilée (évite le verrouillage).
- **Back-off au lockout** : dès qu'un `429` / message de blocage apparaît, tous les workers se mettent en pause (escalade jusqu'à 30 s) — plus discret et n'aggrave pas le verrouillage.

**Proxy** : renseigne ton **egress autorisé** (champ Proxy, ou `options.proxy`, ex. `http://127.0.0.1:8118` pour Privoxy→Tor) pour que **l'IP du scanner n'apparaisse pas** dans les logs de la cible — comme un test en boîte noire depuis l'extérieur. Réglages fins disponibles : `delay`, `jitter`, `rotate_ua`, `evasion`, `shuffle`, `lockout_backoff`.

### Robustesse & modes avancés

- **Token CSRF par tentative** (`refresh_token`, auto-détecté) : si le formulaire porte un champ caché `user_token`/`csrf`/`nonce`…, chaque essai re-fetche la page login pour obtenir un **token frais + le cookie de session** associé, puis POST — indispensable contre **DVWA** et la plupart des logins protégés (sinon tous les POST sont rejetés).
- **Password-spraying** 🪣 (`spray`) : teste **un mot de passe sur tous les comptes**, pause, puis le suivant — bien plus discret et **anti-verrouillage** que le brute classique.
- **Auto-abort lockout** (`abort_on_lockout`, défaut on ; `lockout_abort_threshold`, défaut 5) : si la cible bloque N fois d'affilée malgré le back-off, le moteur **s'arrête proprement** plutôt que de s'acharner (= se faire repérer).
- **Historique** : chaque run brute est **sauvegardé par hôte** (visible dans 📊 Historique), avec les identifiants trouvés.

> Outil de test : la furtivité sert à mesurer ce que la cible **détecte** et à ne pas la perturber, sur un périmètre autorisé — pas à dissimuler une activité illégale.

## Personnalisation

Le moteur lit des fichiers de données éditables dans `backend/data/` :

| Fichier | Rôle |
|---|---|
| `jslib_cves.json` | Librairies JS → versions vulnérables / CVE |
| `secret_patterns.json` | Regex de secrets/clés à détecter |
| `sensitive_paths.json` | Fichiers/chemins sensibles à sonder |
| `wordlist.txt` | Liste de chemins pour le fuzzing intégré |
| `default_creds.txt` | Couples identifiant:mot de passe par défaut (force brute) |

Ajouter une détection = ajouter une entrée. Ajouter un module = déposer un fichier `backend/modules/xxx.py` exposant `NAME`, `ID`, `ACTIVE` et `run(ctx)`, puis l'enregistrer dans `backend/core/scanner.py`.

---

## Structure

```
bastion/
├── backend/
│   ├── bastion.py            # CLI + dispatch serve
│   ├── server.py             # API locale (stdlib http.server)
│   ├── core/                 # http_client, crawler, scanner, models, reporting,
│   │                         #   ai (+on-demand local), aiconfig, history, tools
│   ├── modules/              # une détection par fichier (headers, tls, dns, discovery,
│   │                         #   waf, ports, wordpress, xss, sqli, fuzz, bruteforce, openredirect…)
│   ├── data/                 # bases de signatures éditables
│   └── web/                  # config.html (page de configuration IA)
├── extension/                # extension Manifest V3
│   └── manifest.json · popup.* · options.* · icons/
└── examples/
    └── vulnerable_server.py  # cible de test locale (open redirect, login, etc.)
```

## Avertissement

Outil destiné à la sécurité défensive et aux tests autorisés. L'utilisateur est seul responsable de l'usage qui en est fait. Scanner un système sans autorisation est illégal dans la plupart des juridictions.
