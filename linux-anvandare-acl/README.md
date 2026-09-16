# Linux: användare, grupp och delad katalog med ACL

Uppgift kring användarhantering och behörigheter på Ubuntu Server: setgid, sticky bit och POSIX-ACL för en läsande revisionsgrupp.

## Filer

| Fil | Innehåll |
|---|---|
| [`PROMPT.md`](PROMPT.md) | Den härdade prompten och en sammanfattning av vad som härdades mot originalet |
| [`skapa_nyanvandare.sh`](skapa_nyanvandare.sh) | Skriptet som genererades utifrån prompten |
| [`jamforelse/`](jamforelse/) | Prompter, jämförelse mellan tre skript och Oscars variant, testsviter, testresultat och underlag för redovisning |
| [`jamforelse/JAMFORELSE.md`](jamforelse/JAMFORELSE.md) | Samlad jämförelse av alla fyra skript med testresultat |

I [`jamforelse/`](jamforelse/) finns också `nyanvandare.sh` (Claude), `gemini_nyanvandare.sh` (Gemini), `oscar_skapa_anvandare.sh` (Oscars interaktiva variant med egen testsvit), rollback-skriptet, en fullständig genomgång inför muntlig validering och ett underlag för redovisningen (avsnitt 10). Börja med [`jamforelse/README.md`](jamforelse/README.md).

## Snabbstart

```bash
# Förhandsvisa utan att ändra något (fungerar utan root):
bash skapa_nyanvandare.sh --dry-run

# Skarpt (kräver root). Standard: anna / ekonomi / revision / /srv/ekonomi
sudo bash skapa_nyanvandare.sh

# Egna värden:
sudo bash skapa_nyanvandare.sh -u anna -g ekonomi -r revision -d /srv/ekonomi

# Ta bort allt igen (frågar efter bekräftelse):
sudo bash jamforelse/rollback_nyanvandare.sh anna ekonomi /srv/ekonomi revision
```

## Verifiering (på Ubuntu)

```bash
id anna
getent group ekonomi revision
ls -ld /srv/ekonomi          # drwxrws--T+ root ekonomi
getfacl /srv/ekonomi         # access- och default-ACL, revision: r-x
```

Den fullständiga testplanen med åtkomsttester per användare finns i [`jamforelse/README.md`](jamforelse/README.md), avsnitt 5.

## Rättighetsmodell i korthet

- Basläge **3770** = setgid (2) + sticky (1) + `rwxrwx---`. Gruppen ekonomi får allt, övriga inget, nya objekt ärver gruppen och ingen kan radera någon annans filer.
- **Setgid ärver gruppen men inte skrivbiten.** Med användarens umask 022 skulle nya filer bli 644. Default-ACL:n gör att nya filer blir gruppskrivbara (660) oavsett umask.
- **Revision** får `r-x` på katalogen (x krävs för att gå in och lista) och motsvarande default-ACL. Stort `X` i `setfacl -d -m g:revision:rX` löses upp mot katalogen redan när kommandot körs och lagras som `r-x`. Att nya filer ändå bara blir läsbara (`r--`) beror på att program skapar filer med läge 666, vilket ger ACL-masken `rw-`.

## Status

Funktionstestad på Ubuntu 24.04.4 LTS (2026-09-16) med testsviten [`jamforelse/jamfor_skript.sh`](jamforelse/jamfor_skript.sh): **48 av 49** tester godkända. Passerar `shellcheck` 0.9.0 utan anmärkningar.

Testningen hittade en lucka i sökvägsvalideringen som är lagad: `/etc/`, `/srv/x/../../etc`, `/tmp`, `/srv`, `/opt` och `/usr/local` släpptes igenom eftersom sökvägen jämfördes mot en lista med exakta namn. Nu normaliseras sökvägen med `realpath -m` och både systemkatalogerna och allt under dem vägras.

Det enda underkända testet är att det tillfälliga lösenordet skrivs ut även när utdata går till en fil eller pipe. Det följer kravet i `PROMPT.md` och är ett medvetet val. Detaljer finns i [`jamforelse/README.md`](jamforelse/README.md), avsnitt 8.1.
