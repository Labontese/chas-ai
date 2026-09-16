# Linux: användare, grupp och delad katalog med ACL

Uppgift kring användarhantering och behörigheter på Ubuntu Server (setgid, sticky bit och
POSIX-ACL för en läsande revisionsgrupp).

## Filer
- **[`PROMPT.md`](PROMPT.md)** — den härdade prompten + en sammanfattning av vad som härdades
  mot originalet.
- **[`skapa_nyanvandare.sh`](skapa_nyanvandare.sh)** — skriptet som genererades utifrån prompten.

## Snabbstart
```bash
# Förhandsvisa utan att ändra något (funkar utan root):
bash skapa_nyanvandare.sh --dry-run

# Skarpt (kräver root); standard: anna / ekonomi / revision / /srv/ekonomi:
sudo bash skapa_nyanvandare.sh

# Egna värden:
sudo bash skapa_nyanvandare.sh -u anna -g ekonomi -r revision -d /srv/ekonomi
```

## Verifiering (på Ubuntu)
```bash
id anna
getent group ekonomi revision
ls -ld /srv/ekonomi          # ska visa drwxrws--T root ekonomi
getfacl /srv/ekonomi         # access- + default-ACL (revision: r-x / rX)
```

## Rättighetsmodell i korthet
- Basläge **3770** = `setgid`(2) + `sticky`(1) + `rwxrwx---`: gruppen ekonomi får allt,
  övriga inget, nya objekt ärver gruppen, ingen raderar andras filer.
- **setgid ärver gruppen men inte skrivbiten** → default-ACL `g:ekonomi:rwX` gör nya filer
  gruppskrivbara oavsett umask.
- **revision** får `r-x` på katalogen (x krävs för att gå in/lista) och `rX` som default, så
  framtida filer förblir läsbara utan att bli exekverbara.

## Status
Verifierad med `bash -n` (syntax) och `--dry-run` (bieffektsfri, korrekta exit-koder).
Skarp funktionstestning görs på en Ubuntu 24.04-instans.
