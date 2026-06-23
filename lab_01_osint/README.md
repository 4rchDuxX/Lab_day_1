# 🔍 Lab 01 — OSINT & GitHub Secrets

**Cíl:** Zjistit, co o firmě útočník vidí dřív, než pošle jediný paket. Najít uniknuté secrets v Git historii.

**Časová náročnost:** ~30 minut  
**Potřebuješ:** Prohlížeč + terminál v Codespace

---

## ČÁST A — Pasivní průzkum (prohlížeč, bez terminálu)

### Krok 1 — DNS průzkum s DNSDumpster

DNSDumpster je legální veřejná služba. Dívá se na veřejné DNS záznamy — žádný přímý kontakt s cílem.

1. Otevři **https://dnsdumpster.com**
2. Do vyhledávacího pole zadej: `testphp.vulnweb.com`
3. Klikni na **Search**

**Co hledat ve výsledcích:**
- Záložka **DNS Records** — jaké subdomény existují?
- Záložka **MX Records** — jaký mailový server firma používá? (prozradí poskytovatele)
- Záložka **TXT Records** — SPF/DMARC konfigurace (špatná konfigurace = možnost email spoofingu)
- Graf dole — vizuální mapa infrastruktury

**Otázky k zamyšlení:**
- Kolik subdomén vidíš?
- Jakou cloudovou infrastrukturu firma používá?
- Je SPF/DMARC správně nakonfigurované?

---

### Krok 2 — Shodan (vyhledávač zařízení)

Shodan indexuje celý internet a ukládá informace o otevřených portech a službách.

1. Zaregistruj se zdarma na **https://shodan.io** (nebo použij účet cvičitele)
2. Do vyhledávání zadej IP adresu cíle: `45.33.32.156` (to je scanme.nmap.org — legální cíl)
3. Prozkoumej výsledky

**Co vidíš bez jediného vlastního skenu:**
- Otevřené porty
- Verze služeb (Apache 2.4.x, OpenSSH 7.x...)
- Geolokace serveru
- Historické záznamy

**Zadej do Shodanu tenhle dotaz:**
```
hostname:vulnweb.com
```

Vidíš celou infrastrukturu cíle bez jediného paketu.

---

### Krok 3 — Google Dorks

Otevři Google a zkopíruj tyto dotazy jeden po druhém:

```
site:github.com "DB_PASSWORD" "vulnweb"
```
```
intitle:"index of" "parent directory" site:testphp.vulnweb.com
```
```
filetype:env "APP_KEY" site:github.com
```

> ⚠️ Pozor — u posledního dotazu neklikej na žádné výsledky. Jen si prohlédni co Google indexuje. Jsou to reálné uniklé klíče skutečných lidí.

**Otázka:** Kolik výsledků vrátí dotaz na `.env` soubory s APP_KEY?

---

## ČÁST B — TruffleHog (terminál v Codespace)

Tohle spusť v terminálu v Codespace (dole v VS Code).

### Krok 4 — Skenování demo repa s fake secrets

TruffleHog prohledá celou Git historii a najde secrets i v dávno smazaných commitech.

```bash
trufflehog git https://github.com/trufflesecurity/test_keys --only-verified
```

Počkej ~30 sekund. TruffleHog projde celou historii commitů.

**Co vidíš ve výstupu:**
- `Detector` — jaký typ klíče byl nalezen (AWS, GitHub, Stripe...)
- `Verified` — TruffleHog ověřil, že klíč je skutečně aktivní
- `Commit` — hash commitu kde byl klíč nalezen
- `File` — v jakém souboru

---

### Krok 5 — Proč nestačí klíč smazat

Teď uděláme experiment. Podíváme se na historii commitů a najdeme klíč i když byl "smazán":

```bash
# Naklonuj repo
git clone https://github.com/trufflesecurity/test_keys /tmp/test_keys
cd /tmp/test_keys

# Zobraz historii commitů
git log --oneline

# Prohledej konkrétní commit kde byl klíč (vezmi hash z předchozího výstupu TruffleHog)
git show <HASH_COMMITU>
```

Vidíš? Klíč je tam navždy — dokud nepřepíšeš celou Git historii pomocí `git filter-repo`.

---

### Krok 6 — Skenování vlastního repa

Máš vlastní GitHub repo? Zkus:

```bash
trufflehog github --repo=https://github.com/TVUJ_USERNAME/TVOJE_REPO
```

Nebo celou org:

```bash
trufflehog github --org=NAZEV_ORG
```

---

## ✅ Shrnutí — co jsme se naučili

| Technika | Nástroj | Co prozradí |
|----------|---------|-------------|
| DNS průzkum | DNSDumpster | Subdomény, mail servery, SPF/DMARC |
| Port/service průzkum | Shodan | Otevřené porty, verze služeb, historické záznamy |
| Indexované soubory | Google Dorks | .env soubory, zálohy DB, odkryté adresáře |
| Git secrets | TruffleHog | API klíče, hesla, tokeny v historii commitů |

**Klíčový takeaway:** Útočník toto celé udělá ještě před prvním paketem. Obrana začíná tím, že víš co o sobě vystavuješ.

---

## Prevence — co dělat jako vývojář

```bash
# Přidej do .gitignore
echo ".env" >> .gitignore
echo "*.pem" >> .gitignore
echo "config/secrets.yml" >> .gitignore

# Nainstaluj pre-commit hook který zabrání commitu secrets
pip install pre-commit
# Viz https://pre-commit.com
```

Doporučené nástroje do CI/CD: **GitGuardian**, **TruffleHog CI action**, **GitHub Secret Scanning** (automaticky na public repech).
