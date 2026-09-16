#!/usr/bin/env bash
#
# rollback_nyanvandare.sh
# Tar bort det som nyanvandare.sh skapade.
# Användning: sudo ./rollback_nyanvandare.sh [användare] [grupp] [katalog] [läsgrupp]

set -Eeuo pipefail

ANVANDARE="${1:-anna}"
GRUPP="${2:-ekonomi}"
KATALOG="${3:-/srv/ekonomi}"
LASGRUPP="${4:-revision}"
KATALOG="${KATALOG%/}"

if [[ "$EUID" -ne 0 ]]; then
    echo "FEL: Kör som root (sudo)." >&2
    exit 1
fi

# Samma skydd som i huvudskriptet, en rm -rf på fel ställe är oåterkallelig
case "$KATALOG" in
    ""|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
    /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
        echo "FEL: Vägrar att ta bort '${KATALOG:-/}'." >&2
        exit 2 ;;
esac
if [[ "$KATALOG" != /* || "$KATALOG" == *..* ]]; then
    echo "FEL: Ogiltig sökväg '${KATALOG}'." >&2
    exit 2
fi

echo "Följande tas bort:"
echo "  Användare: ${ANVANDARE} (inklusive hemkatalog)"
echo "  Grupper:   ${GRUPP}, ${LASGRUPP}"
echo "  Katalog:   ${KATALOG} (inklusive allt innehåll)"
read -rp "Skriv JA för att fortsätta: " svar
if [[ "$svar" != "JA" ]]; then
    echo "Avbrutet, inget ändrades."
    exit 0
fi

if id "$ANVANDARE" &>/dev/null; then
    # Avsluta eventuella processer, annars vägrar userdel
    pkill -KILL -u "$ANVANDARE" || true
    userdel --remove "$ANVANDARE"
    echo "Användaren ${ANVANDARE} borttagen"
fi

for grupp in "$GRUPP" "$LASGRUPP"; do
    if getent group "$grupp" >/dev/null; then
        groupdel "$grupp"
        echo "Gruppen ${grupp} borttagen"
    fi
done

if [[ -d "$KATALOG" ]]; then
    rm -rf --one-file-system -- "$KATALOG"
    echo "Katalogen ${KATALOG} borttagen"
fi

echo "Rollback klar"
