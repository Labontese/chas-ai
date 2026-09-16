#!/bin/bash

# ==========================================================
# Användarskapare
# Skapar användare, avdelning, roll och privata mappar
# ==========================================================

# ----------------------------------------------------------
# 1. Kontrollera att scriptet körs som root
# ----------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "Fel: Scriptet måste köras som root."
    echo "Kör exempelvis:"
    echo "sudo ./skapa_anvandare.sh"
    exit 1
fi


# ----------------------------------------------------------
# 2. Funktion för att pausa
# ----------------------------------------------------------

paus() {
    read -p "Tryck Enter för att fortsätta..."
}


# ----------------------------------------------------------
# 3. Fråga efter användarens information
# ----------------------------------------------------------

clear

echo "=============================================="
echo "        VÄLKOMMEN TILL ANVÄNDARSKAPAREN"
echo "=============================================="
echo

read -p "Ange användarnamn: " USERNAME
read -p "Ange användarens fullständiga namn: " FULLNAME


# ----------------------------------------------------------
# 4. Kontrollera om användaren redan finns
# ----------------------------------------------------------

if id "$USERNAME" &>/dev/null; then
    echo
    echo "Fel: Användaren '$USERNAME' finns redan."
    exit 1
fi


# ----------------------------------------------------------
# 5. Välj avdelning
# ----------------------------------------------------------

echo
echo "Välj avdelning:"
echo "1) Administration"
echo "2) IT"
echo "3) Ekonomi"
echo "4) Produktion"
echo

read -p "Ditt val: " DEPARTMENT_CHOICE

case "$DEPARTMENT_CHOICE" in
    1)
        DEPARTMENT="administration"
        DEPARTMENT_NAME="Administration"
        ;;
    2)
        DEPARTMENT="it"
        DEPARTMENT_NAME="IT"
        ;;
    3)
        DEPARTMENT="ekonomi"
        DEPARTMENT_NAME="Ekonomi"
        ;;
    4)
        DEPARTMENT="produktion"
        DEPARTMENT_NAME="Produktion"
        ;;
    *)
        echo "Felaktigt val av avdelning."
        exit 1
        ;;
esac


# ----------------------------------------------------------
# 6. Välj roll
# ----------------------------------------------------------

echo
echo "Välj roll:"
echo "1) Administratör"
echo "2) Chef"
echo "3) Medarbetare"
echo "4) Tekniker"
echo

read -p "Ditt val: " ROLE_CHOICE

case "$ROLE_CHOICE" in
    1)
        ROLE="Administratör"
        ;;
    2)
        ROLE="Chef"
        ;;
    3)
        ROLE="Medarbetare"
        ;;
    4)
        ROLE="Tekniker"
        ;;
    *)
        echo "Felaktigt val av roll."
        exit 1
        ;;
esac


# ----------------------------------------------------------
# 7. Skapa avdelningsgruppen om den inte finns
# ----------------------------------------------------------

if ! getent group "$DEPARTMENT" > /dev/null; then
    groupadd "$DEPARTMENT"
    echo "Gruppen '$DEPARTMENT' skapades."
else
    echo "Gruppen '$DEPARTMENT' finns redan."
fi


# ----------------------------------------------------------
# 8. Skapa användaren
# ----------------------------------------------------------

useradd \
    -m \
    -s /bin/bash \
    -c "$FULLNAME" \
    -G "$DEPARTMENT" \
    "$USERNAME"

if [ $? -ne 0 ]; then
    echo "Fel: Kunde inte skapa användaren."
    exit 1
fi


# ----------------------------------------------------------
# 9. Skapa privata mappar
# ----------------------------------------------------------

USER_HOME="/home/$USERNAME"

mkdir -p "$USER_HOME/Dokument"
mkdir -p "$USER_HOME/Bilder"
mkdir -p "$USER_HOME/Appar"
mkdir -p "$USER_HOME/Videos"


# ----------------------------------------------------------
# 10. Ge användaren ägarskap över mapparna
# ----------------------------------------------------------

chown -R "$USERNAME:$DEPARTMENT" "$USER_HOME"


# ----------------------------------------------------------
# 11. Skydda användarens privata mappar
# ----------------------------------------------------------

chmod 700 "$USER_HOME/Dokument"
chmod 700 "$USER_HOME/Bilder"
chmod 700 "$USER_HOME/Appar"
chmod 700 "$USER_HOME/Videos"


# ----------------------------------------------------------
# 12. Skapa välkomstfil
# ----------------------------------------------------------

cat > "$USER_HOME/VÄLKOMMEN.txt" << EOF
==================================================
                 VÄLKOMMEN!
==================================================

Hej $FULLNAME!

Ditt användarkonto har nu skapats.

Användarnamn : $USERNAME
Avdelning    : $DEPARTMENT_NAME
Roll         : $ROLE

Du har fått tillgång till följande privata mappar:

- Dokument
- Bilder
- Appar
- Videos

Dessa mappar är privata och kan endast användas
av ditt användarkonto.

Du är medlem i avdelningen:

$DEPARTMENT_NAME

Välkommen till organisationen!

==================================================
EOF


# ----------------------------------------------------------
# 13. Ändra ägare på välkomstfilen
# ----------------------------------------------------------

chown "$USERNAME:$DEPARTMENT" "$USER_HOME/VÄLKOMMEN.txt"

chmod 600 "$USER_HOME/VÄLKOMMEN.txt"


# ----------------------------------------------------------
# 14. Hitta andra användare på samma avdelning
# ----------------------------------------------------------

OTHER_USERS=$(getent group "$DEPARTMENT" | cut -d: -f4)


# ----------------------------------------------------------
# 15. Slutlig information
# ----------------------------------------------------------

echo
echo "=============================================="
echo "        ANVÄNDAREN HAR SKAPATS"
echo "=============================================="
echo
echo "Namn       : $FULLNAME"
echo "Användare  : $USERNAME"
echo "Avdelning  : $DEPARTMENT_NAME"
echo "Roll       : $ROLE"
echo
echo "Privata mappar:"
echo "  /home/$USERNAME/Dokument"
echo "  /home/$USERNAME/Bilder"
echo "  /home/$USERNAME/Appar"
echo "  /home/$USERNAME/Videos"
echo

echo "Andra användare på avdelningen:"
echo

if [ -z "$OTHER_USERS" ]; then
    echo "Inga andra användare finns ännu."
else
    echo "$OTHER_USERS" | tr ',' '\n'
fi

echo
echo "=============================================="
echo "Välkommen, $FULLNAME!"
echo "=============================================="
