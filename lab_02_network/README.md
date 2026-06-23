# 🌐 Lab 02 — Síťová analýza: Nmap & Wireshark

**Cíl:** Namapovat infrastrukturu cíle, analyzovat síťový provoz a najít hesla přenášená v plain textu.

**Časová náročnost:** ~35 minut  
**Potřebuješ:** Terminál v Codespace

---

## ČÁST A — Nmap (síťové skenování)

**Cíl skenování:** `scanme.nmap.org` — server provozovaný přímo Nmap.org jako legální cíl pro cvičení.

> ✅ Skenování `scanme.nmap.org` je explicitně povoleno provozovateli.  
> ⛔ Nikdy neskenuj jiné servery bez písemného souhlasu vlastníka.

---

### Krok 1 — Základní sken (zjisti co je nahoře)

```bash
nmap scanme.nmap.org
```

Počkej ~10 sekund. Výstup ukáže otevřené porty.

**Co vidíš:**
```
PORT      STATE SERVICE
22/tcp    open  ssh
80/tcp    open  http
9929/tcp  open  nping-echo
31337/tcp open  Elite
```

**Otázky:**
- Jaké služby běží na serveru?
- Co říká port 31337?

---

### Krok 2 — Detekce verzí služeb

Teď zjistíme konkrétní verze softwaru — tohle útočník potřebuje pro výběr exploitu:

```bash
nmap -sV scanme.nmap.org
```

**Co přibude ve výstupu:**
```
22/tcp open  ssh     OpenSSH 6.6.1p1
80/tcp open  http    Apache httpd 2.4.7
```

Znáš verzi → pogoogluješ CVE → víš jestli je zranitelná.

---

### Krok 3 — TCP Connect Scan (bez root práv)

V Codespace nemáš raw socket přístup, takže místo stealth SYN scanu (`-sS`) použijeme TCP Connect scan (`-sT`). Rozdíl: tento scan se zapíše do logů cíle.

```bash
nmap -sT -p 1-1000 scanme.nmap.org
```

Skenujeme porty 1–1000. Může trvat 1–2 minuty.

---

### Krok 4 — NSE skripty (automatická detekce zranitelností)

Nmap Scripting Engine umí automaticky testovat konkrétní věci:

```bash
# Zkontroluj SSH konfigurace
nmap -p 22 --script ssh-auth-methods scanme.nmap.org

# Zjisti HTTP hlavičky (prozradí technologie)
nmap -p 80 --script http-headers scanme.nmap.org

# Zkontroluj SSL/TLS (na portu 443 pokud existuje)
nmap -p 443 --script ssl-enum-ciphers scanme.nmap.org
```

**Co hledat v HTTP hlavičkách:**
- `Server:` — verze webserveru
- `X-Powered-By:` — backend technologie (PHP, ASP.NET...)
- Chybějící security hlavičky (`X-Frame-Options`, `Content-Security-Policy`)

---

### Krok 5 — Výstup do souboru

V reálném pentestingu vždy ukládáš výsledky:

```bash
# Ulož výsledky ve třech formátech najednou
nmap -sV -oA /tmp/nmap-report scanme.nmap.org

# Zobraz XML výstup
cat /tmp/nmap-report.xml

# Zobraz čitelný výstup
cat /tmp/nmap-report.nmap
```

---

## ČÁST B — Wireshark / tshark (analýza paketů)

Budeme analyzovat předpřipravený `.pcap` soubor s reálnou HTTP komunikací zachycenou v síti. Soubor je automaticky stažený v `lab_02_network/http.cap`.

> Tento soubor obsahuje HTTP přihlášení v plain textu — přesně to co vidí útočník na nešifrované síti.

---

### Krok 6 — První pohled na provoz

```bash
# Přejdi do složky labu
cd /../lab-02-network

# Zobraz základní statistiky zachyceného provozu
tshark -r http.cap -q -z io,phs
```

Uvidíš kolik paketů, jaké protokoly, kolik dat.

---

### Krok 7 — Zobraz všechny HTTP požadavky

```bash
tshark -r http.cap -Y "http.request" -T fields \
  -e frame.number \
  -e ip.src \
  -e http.request.method \
  -e http.request.uri \
  -e http.user_agent
```

**Co vidíš:**
- Zdrojové IP adresy
- Jaké URL byly navštíveny
- Jaký prohlížeč/klient byl použit

---

### Krok 8 — Najdi POST požadavky (přihlašovací formuláře)

```bash
tshark -r http.cap -Y "http.request.method == POST"
```

Vidíš POST požadavek. To je přihlašovací formulář.

Teď zobraz co bylo v těle toho požadavku:

```bash
tshark -r http.cap -Y "http.request.method == POST" -T fields \
  -e ip.src \
  -e http.request.uri \
  -e http.file_data
```

**Vidíš heslo v plain textu?** Toto je přesně to co vidí kdokoliv na stejné Wi-Fi síti pokud web nepoužívá HTTPS.

---

### Krok 9 — Sleduj celý TCP stream (jako útočník)

Zobrazíme celou konverzaci mezi klientem a serverem:

```bash
# Nejdřív zjisti čísla streamů
tshark -r http.cap -Y "tcp" -T fields -e tcp.stream | sort -nu
```

```bash
# Zobraz konkrétní stream (zkus číslo 0, 1, 2...)
tshark -r http.cap -q -z follow,tcp,ascii,0
```

Vidíš kompletní HTTP komunikaci — včetně cookies, session tokenů a hesel — přesně jak to vidí útočník při man-in-the-middle útoku na nešifrované síti.

---

### Krok 10 — Filtrování podle IP

```bash
# Provoz z konkrétní IP
tshark -r http.cap -Y "ip.src == 145.254.160.237"

# Provoz obsahující slovo "password"
tshark -r http.cap -Y 'http contains "password"'
```

---

## Shrnutí

| Technika | Příkaz | Co ukáže |
|----------|--------|----------|
| Basic scan | `nmap TARGET` | Otevřené porty |
| Service detection | `nmap -sV TARGET` | Verze softwaru → CVE lookup |
| TCP scan (bez root) | `nmap -sT TARGET` | Totéž, detekovatelné |
| NSE skripty | `nmap --script SCRIPT TARGET` | Automatická detekce zranitelností |
| HTTP analýza | `tshark -Y "http.request"` | Navštívené URL |
| Odchycená hesla | `tshark -Y "http.request.method == POST"` | Přihlašovací data v plain textu |
| TCP stream | `tshark -z follow,tcp,ascii,N` | Kompletní komunikace |

**Klíčový takeaway:** HTTP bez S = kdokoliv na síti vidí vše. Session tokeny, hesla, API klíče. HTTPS není optional.

---

**Checklist pro každý projekt:**

```
✅ HTTPS všude, HTTP redirect na HTTPS
✅ HSTS hlavička (Strict-Transport-Security)
✅ Bezpečné cookie atributy: Secure, HttpOnly, SameSite=Strict
✅ Nikdy neposílat citlivá data v GET parametrech (zůstávají v logách)
✅ Content-Security-Policy hlavička
```

```bash
# Rychlá kontrola HTTP hlaviček tvého webu
curl -I https://tvujweb.cz
```

Hledej přítomnost: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`.
