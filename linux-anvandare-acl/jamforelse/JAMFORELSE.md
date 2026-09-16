# Jämförelser: fyra skript för användare, grupp och katalogrättigheter

Samlad översikt över alla jämförelser i den här mappen. Detaljerna, bakgrunden och skripten i sin helhet finns i [`README.md`](README.md): avsnitt 8 (Claude, härdad prompt och Gemini), avsnitt 9 (Oscars variant) och avsnitt 10 (underlag för redovisning).

Alla tester kördes i Ubuntu 24.04.4 LTS den 16 september 2026, med `runuser -u` i stället för `sudo -u` (samma beteende).

## Innehåll

1. Skripten som jämförs
2. Resultat i korthet
3. Egenskaper sida vid sida
4. Styrkor och svagheter per skript
5. Claude mot Gemini i detalj
6. Testmatris: 49 tester
7. Testmatris: Oscars 25 tester
8. Lagningar och vad de gav
9. Vad jämförelserna visar
10. Köra om jämförelserna

---

## 1. Skripten som jämförs

| Skript | Ursprung | Tolkning av uppgiften |
|---|---|---|
| [`nyanvandare.sh`](nyanvandare.sh) | Claude, utifrån den avancerade prompten (README 1.3) | Delad katalog med setgid, sticky bit och ACL |
| [`../skapa_nyanvandare.sh`](../skapa_nyanvandare.sh) | Den härdade prompten ([`../PROMPT.md`](../PROMPT.md)) | Samma som ovan |
| [`gemini_nyanvandare.sh`](gemini_nyanvandare.sh) | Gemini, utifrån den avancerade prompten | Samma som ovan |
| [`oscar_skapa_anvandare.sh`](oscar_skapa_anvandare.sh) | Oscars variant (ChatGPT, prompten finns i README 1.6) | Interaktiv användarskapare med privata mappar i hemkatalogen |

Till jämförelsen hör också två lagade versioner, [`gemini_lagad.sh`](gemini_lagad.sh) och [`oscar_lagad.sh`](oscar_lagad.sh), som visar vad som återstår när de mest akuta felen är borta.

Oscars skript saknar flaggor och löser en annan tolkning, så det testas med en egen svit på 25 tester. Siffrorna i de två sviterna går inte att jämföra rakt av.

---

## 2. Resultat i korthet

### Testsviten `jamfor_skript.sh` (49 tester)

| Skript | Godkända tester |
|---|---|
| `nyanvandare.sh` (Claude) | **49 av 49** |
| `skapa_nyanvandare.sh` (härdad prompt, efter lagning) | **48 av 49** |
| `skapa_nyanvandare.sh` (härdad prompt, commit `197c62e`) | 44 av 49 |
| `gemini_nyanvandare.sh` (Gemini, original) | 30 av 49 |
| `gemini_lagad.sh` (Gemini, bara lösenordsraden lagad) | 36 av 49 |

### Testsviten `testa_oscar.sh` (25 tester)

| Skript | Godkända tester |
|---|---|
| `oscar_skapa_anvandare.sh` (original) | **16 av 25** |
| `oscar_lagad.sh` (sex lagningar) | **25 av 25** |

---

## 3. Egenskaper sida vid sida

| Egenskap | Claude (`nyanvandare.sh`) | Härdad prompt (`skapa_nyanvandare.sh`) | Gemini | Oscar |
|---|---|---|---|---|
| Delad avdelningskatalog | Ja | Ja | Ja | Nej |
| Setgid och sticky bit | Ja | Ja | Ja | Nej |
| ACL för läsgrupp | Ja | Ja | Ja | Nej |
| Privata mappar i hemkatalogen | Nej | Nej | Nej | Ja |
| Hemkatalogen stängd för andra | Ja | Ja | Ja | Nej |
| Lösenord och tvingat byte | Ja | Ja | Nej (kraschar) | Nej (saknas) |
| Fullständigt namn sparas | Nej | Nej | Nej | Ja |
| Tilläggsgrupp | Ja (`-G`) | Ja (`usermod -aG`) | Nej (`-g`) | Ja (`-G`) |
| Indata | Argument | Argument | Argument | Interaktiva menyer |
| Validering av användarnamn | Ja | Ja | Delvis | Nej |
| Skydd mot systemkataloger | Ja | Ja | Nej | Ej relevant (fast sökväg) |
| Dry-run | Ja | Ja, även utan root | Ja, men kraschar | Nej |
| Loggning | Ja | Ja | Delvis | Nej |
| Omkörning | Idempotent | Idempotent | Delvis | Avbryter om användaren finns |
| Felhantering | `set -Eeuo pipefail` och `trap` | `set -Eeuo pipefail` och `trap` | `trap` som aldrig triggas | Kontroll efter `useradd` |
| Användarvänlighet | Hjälptext | Hjälptext och sammanfattning | Hjälptext | Menyer, välkomstfil |
| Testresultat | 49 av 49 | 48 av 49 | 30 av 49 | 16 av 25 (egen svit) |
| Efter minsta lagning | | | 36 av 49 | 25 av 25 |

---

## 4. Styrkor och svagheter per skript

### Claude, `nyanvandare.sh` (49 av 49)

**Styrkor:** `set -Eeuo pipefail` med fungerande `trap` och radnummer, validering av alla namn, skydd mot systemkataloger och allt under dem, idempotent omkörning, dry-run, loggning av varje kommando, loggfil 640, lösenordet visas bara i terminal och aldrig i loggen.

**Svagheter:** sparar inte fullständigt namn och är inte interaktivt. Sökvägsskyddet släppte först igenom bland annat `/usr/local`, och loggfilen skapades först med 644. Båda är lagade och hittades genom testerna.

### Härdad prompt, `skapa_nyanvandare.sh` (48 av 49)

**Styrkor:** tydliga exitkoder, dry-run som fungerar utan root och saknar bieffekter, loggfil 640, sammanfattning efter körning, `realpath -m` för att normalisera sökvägen.

**Svagheter:** lösenordet skrivs ut även när utdata går till fil eller pipe (medvetet enligt `PROMPT.md`, därav det enda underkända testet). Före lagningen släpptes `/etc/`, `/srv/x/../../etc`, `/tmp` och `/usr/local` igenom. README:n påstod att skriptet var shellcheck-rent trots SC2317. Förklaringen av `rX` i kommentarerna är fel, även om resultatet stämmer. Smådetaljer: trap-meddelandet går till stdout och posten `g:ekonomi:rwx` är överflödig.

### Gemini, `gemini_nyanvandare.sh` (30 av 49)

**Styrkor:** tydlig struktur, idempotent gruppskapande, root kontrolleras först, lösenordet hamnar aldrig i loggfilen. Rättighetsmodellen är korrekt när skriptet väl går igenom.

**Svagheter:** lösenordsraden kraschar alltid med kod 141 (SIGPIPE), även i dry-run. `trap` triggas aldrig eftersom `-E` saknas. Inget skydd mot systemkataloger. `-g` gör avdelningen till primärgrupp. Loggfilen är läsbar för alla. Detaljerna står i avsnitt 5.

### Oscar, `oscar_skapa_anvandare.sh` (16 av 25)

**Styrkor:** lättläst, användarvänligt med menyer och välkomstfil, ogiltiga val avbryter innan något ändras, sparar fullständigt namn, rätt val av `-G`, privata mappar med 700.

**Svagheter:** inget lösenord, så kontot är låst. `chown -R "$USERNAME:$DEPARTMENT"` ger hela avdelningen läsrätt till hemkatalogen. Den nya användaren listas som "annan användare". Användarnamn valideras inte. Avdelningsgruppen blir kvar när `useradd` misslyckas. `read` saknar `-r`. Rollen påverkar inga rättigheter.

---

## 5. Claude mot Gemini i detalj

Båda skripten kom från samma prompt och har nästan identisk struktur, så skillnaderna här beror på modellen och inte på prompten.

**Tre allvarliga fel i Gemini-skriptet:**

1. `temp_pass=$(tr -dc ... < /dev/urandom | head -c 12)` kraschar med kod 141 under `pipefail`. Följden blir ett konto utan lösenord, och andra körningen rapporterar ändå att allt gick bra.
2. `trap ... ERR` triggas aldrig, eftersom `set -E` saknas och all logik ligger i funktioner.
3. Inget skydd mot systemkataloger: `-p /etc -g root` hade gett `chmod 3770 /etc`.

**Mindre skillnader:**

| Område | Gemini-skriptet | `nyanvandare.sh` |
|---|---|---|
| Gruppmedlemskap | `-g`: `ekonomi` blir primärgrupp | `--groups`: tilläggsgrupp, egen primärgrupp behålls |
| Befintlig användare | Läggs inte till i gruppen | Kontrolleras och läggs till vid behov |
| Validering | Gruppnamn kontrolleras inte, användarnamn saknar längdgräns | Alla namn valideras, max 32 tecken |
| Flagga utan värde | `$2: unbound variable` | Tydligt meddelande |
| Loggfil | 644 root:root, läsbar för alla | 640 root:adm |
| Vad loggas | Beskrivningar, men inga fel och inga kommandon | Varje kommando och varje fel med tidsstämpel |
| Lösenord i utdata | Skrivs alltid ut, även vid omdirigering till fil | Bara om utdata går till en terminal |
| ACL vid omkörning | Bara själva katalogen | Rekursivt, befintliga filer får också läsrätt |
| Argumenttolkning | På toppnivå, utanför funktioner | I funktionen `tolka_argument` |
| Flaggor | `-d` = dry-run, `-p` = sökväg | `-d` = katalog, `-n` = dry-run |

---

## 6. Testmatris: 49 tester

`skapa_nyanvandare_fore_fix.sh` är versionen från commit `197c62e`, före lagningen av sökvägsvalideringen.

| Test | Förväntat | nyanvandare.sh | skapa_nyanvandare.sh | skapa_nyanvandare_fore_fix.sh | gemini_nyanvandare.sh | gemini_lagad.sh |
|---|---|---|---|---|---|---|
| Dry-run: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Dry-run: inget ändras på systemet | nej | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar /etc | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc/ (avslutande snedstreck) | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc via '..' | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /tmp | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar katalog under /usr | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar relativ sökväg | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar versaler i användarnamn | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar användarnamn > 32 tecken | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar ogiltigt gruppnamn | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Tydligt fel vid flagga utan värde | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Körning 1: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Körning 1: användaren skapad | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 1: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: katalogen skapad | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Lösenord visas inte i omdirigerad utdata | ja | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | Godkänt | **UNDERKÄNT** (nej) |
| Lösenord finns inte i loggfilen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 2: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Katalog: mode | 3770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Katalog: ägare | root:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| ACL: revision r-x på katalogen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: revision r-x | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: övriga --- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna i ekonomi (id) | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna listad i getent group ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Loggfil inte läsbar för alla | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| anna skapar fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna skapar underkatalog | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega läser annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega skriver i annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega raderar annas fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor listar katalogen | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor läser fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skapar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skriver i fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor raderar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående listar katalogen | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående läser fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: mode och ägare | 660 anna:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: revision effektivt r-- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Underkatalog: ärver setgid | 2770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna raderar egen fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare läggs i ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| trap rapporterar fel med radnummer | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |

Fullständig utskrift: [`testresultat.txt`](testresultat.txt).

---

## 7. Testmatris: Oscars 25 tester

| Test | Förväntat | oscar_skapa_anvandare.sh |
|---|---|---|
| Körning: returkod | 0 | Godkänt |
| Användaren skapad | ja | Godkänt |
| Fullständigt namn sparat | Anna Andersson | Godkänt |
| Skal | /bin/bash | Godkänt |
| Tilläggsgrupp ekonomi (id) | ja | Godkänt |
| Listad i getent group ekonomi | ja | Godkänt |
| Privata mappar: finns, 700, ägs av anna | ja | Godkänt |
| VÄLKOMMEN.txt: mode | 600 | Godkänt |
| Utskrift: nya användaren listas inte som 'annan' | ja | **UNDERKÄNT** (nej) |
| Lösenord satt (kan logga in) | ja | **UNDERKÄNT** (nej) |
| Lösenordsbyte krävs | ja | **UNDERKÄNT** (nej) |
| Kollega listar annas hemkatalog | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser fil i hemkatalogens rot | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser .bashrc | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser Dokument/cv.txt | NEKAS | Godkänt |
| Kollega läser VÄLKOMMEN.txt | NEKAS | Godkänt |
| Utomstående listar annas hemkatalog | NEKAS | Godkänt |
| Anna skriver i Dokument | OK | Godkänt |
| Befintlig användare avvisas | ja | Godkänt |
| Ogiltig avdelning: avbryter utan ändringar | ja | Godkänt |
| Ogiltig roll: avbryter utan ändringar | ja | Godkänt |
| Versaler i användarnamn avvisas | ja | **UNDERKÄNT** (nej) |
| Misslyckad useradd lämnar ingen grupp kvar | ja | **UNDERKÄNT** (nej) |
| Backslash i namn bevaras | Per\Olsson | **UNDERKÄNT** (PerOlsson) |
| Icke-root avvisas | ja | Godkänt |

Med [`oscar_lagad.sh`](oscar_lagad.sh) blir alla 25 godkända. Fullständig utskrift: [`testresultat_oscar.txt`](testresultat_oscar.txt).

---

## 8. Lagningar och vad de gav

| Skript | Lagning | Före | Efter |
|---|---|---|---|
| `skapa_nyanvandare.sh` | Normalisera sökvägen med `realpath -m` och vägra systemkataloger och allt under dem | 44 av 49 | 48 av 49 |
| `gemini_nyanvandare.sh` | Byt lösenordsraden mot `head -c 9 /dev/urandom \| base64` | 30 av 49 | 36 av 49 |
| `oscar_skapa_anvandare.sh` | Lösenord med tvingat byte, `chown -R "$USERNAME:"`, filtrera bort den nya användaren, validera användarnamn, ta bort gruppen vid fel, `read -r` | 16 av 25 | 25 av 25 |

För Gemini tar den minsta lagningen i README avsnitt 8.2 (`set -E`, ny lösenordsrad och sökvägsskydd) bort de allvarliga felen. För att nå samma nivå som Claudes skript krävs dessutom `-G` i stället för `-g`, validering av namn, loggfil 640 och de övriga punkterna i avsnitt 5.

---

## 9. Vad jämförelserna visar

- **Prompten styr strukturen.** Claude och Gemini fick samma avancerade prompt och gav nästan identisk struktur. Oscars variant, som inte bygger på den prompten, blev ett helt annat skript.
- **Prompten styr även felen.** Den avancerade prompten krävde `set -euo pipefail` utan `-E`. Gemini följde den bokstavligt och fick en `trap` som aldrig fungerar. Den härdade prompten kräver `-E` uttryckligen.
- **Rättighetsmodellen var rätt överallt.** Alla tre ACL-skripten gav identiskt resultat i rättighetsmatrisen och arvstesterna. Skillnaderna ligger i validering, felhantering och robusthet.
- **De farligaste felen syns inte.** Geminis krasch är tyst, och Oscars `chown -R` ser rimlig ut medan välkomstfilen säger att mapparna är privata.
- **Även AI-genererade tester och dokumentation hade fel.** Den första testsviten godkände Geminis validering för att kraschen tolkades som att skriptet vägrade. En README påstod shellcheck-renhet som inte stämde, och en kommentar förklarade `rX` fel.
- **En lista med exakta katalognamn är ett svagt skydd.** Normalisera sökvägen först och vägra hela underträd.

---

## 10. Köra om jämförelserna

Kör endast i en test-VM. Sviterna skapar och tar bort användare, grupper och `/srv/ekonomi`.

```bash
cd linux-anvandare-acl/jamforelse
sudo apt install acl

# 49 tester mot ACL-skripten
git show 197c62e:linux-anvandare-acl/skapa_nyanvandare.sh > skapa_nyanvandare_fore_fix.sh
sudo bash jamfor_skript.sh nyanvandare.sh ../skapa_nyanvandare.sh \
    skapa_nyanvandare_fore_fix.sh gemini_nyanvandare.sh gemini_lagad.sh | tee testresultat.txt

# 25 tester mot Oscars variant
sudo bash testa_oscar.sh oscar_skapa_anvandare.sh | tee testresultat_oscar.txt
sudo bash testa_oscar.sh oscar_lagad.sh
```

Båda sviterna frågar efter `JA` innan de startar (hoppa över med `-y`) och skriver en sammanfattning som Markdown-tabell, som kan klistras in här.
