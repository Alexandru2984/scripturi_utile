#!/bin/bash
# Script pentru configurarea PostgreSQL pentru un proiect Django

# === ATENȚIE ===
# Acest script presupune că ai deja un mediu virtual Python configurat și activ.
# De asemenea, presupune că Django NU este instalat în mediul virtual;
# va instala doar conectorul PostgreSQL (psycopg2-binary).
# Asigură-te că mediul virtual se află la calea specificată mai jos.

# --- CONFIGURARE ---
DB_NAME="mydb"       # Numele bazei de date dorite
DB_USER="user"       # Numele utilizatorului PostgreSQL
DB_PASSWORD="mypassword" # Parola utilizatorului PostgreSQL
VENV_PATH="$HOME/venv"   # Calea completă către mediul tău virtual Python

# --- 1. Verifică existența mediului virtual ---
echo "---"
echo "[1/6] Verific mediul virtual Python..."
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Eroare: Mediul virtual nu a fost găsit la '$VENV_PATH'."
    echo "Asigură-te că ai creat mediul virtual și calea este corectă."
    exit 1
fi
echo "Mediul virtual găsit: '$VENV_PATH'."

# --- 2. Instalează PostgreSQL ---
echo "---"
echo "[2/6] Instalare PostgreSQL și pachete auxiliare..."
# Actualizează lista de pachete
sudo apt update || { echo "Eroare la actualizarea pachetelor. Ieșire."; exit 1; }
# Instalează PostgreSQL și contribuțiile sale
sudo apt install postgresql postgresql-contrib -y || { echo "Eroare la instalarea PostgreSQL. Ieșire."; exit 1; }
echo "PostgreSQL instalat cu succes."

# --- 3. Creează utilizator și bază de date PostgreSQL ---
echo "---"
echo "[3/6] Creare utilizator și bază de date PostgreSQL..."

# Verifică dacă utilizatorul există deja
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo "Utilizatorul '$DB_USER' există deja. Trec peste creare."
else
    sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
EOF
    if [ $? -ne 0 ]; then echo "Eroare la crearea utilizatorului '$DB_USER'. Ieșire."; exit 1; fi
    echo "Utilizatorul '$DB_USER' creat cu succes."
fi

# Verifică dacă baza de date există deja
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    echo "Baza de date '$DB_NAME' există deja. Trec peste creare."
else
    sudo -u postgres psql <<EOF
CREATE DATABASE $DB_NAME;
EOF
    if [ $? -ne 0 ]; then echo "Eroare la crearea bazei de date '$DB_NAME'. Ieșire."; exit 1; fi
    echo "Baza de date '$DB_NAME' creată cu succes."
fi

# Configurează rolul și acordă permisiuni
sudo -u postgres psql <<EOF
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
if [ $? -ne 0 ]; then echo "Eroare la configurarea rolului sau acordarea permisiunilor. Ieșire."; exit 1; fi
echo "Permisiuni acordate și rol configurat pentru '$DB_USER' pe baza de date '$DB_NAME'."

# --- 4. Activează mediul virtual și instalează conectorul Python ---
echo "---"
echo "[4/6] Activare mediu virtual și instalare conector psycopg2-binary..."
source "$VENV_PATH/bin/activate" || { echo "Eroare la activarea mediului virtual. Ieșire."; exit 1; }
# Instalează psycopg2-binary în mediul virtual
pip install psycopg2-binary || { echo "Eroare la instalarea psycopg2-binary. Ieșire."; exit 1; }
echo "psycopg2-binary instalat cu succes în mediul virtual."
# Dezactivează mediul virtual pentru a nu interfera cu alte comenzi ulterioare (opțional, dar bună practică)
deactivate

# --- 5. Testează conexiunea PostgreSQL din Python ---
echo "---"
echo "[5/6] Testez conexiunea la baza de date PostgreSQL din Python..."
# Folosește calea absolută către interpretorul Python din mediul virtual
"$VENV_PATH/bin/python3" -c "
import psycopg2
try:
    conn = psycopg2.connect(
        dbname='$DB_NAME',
        user='$DB_USER',
        password='$DB_PASSWORD',
        host='localhost'
    )
    print('Conexiune la PostgreSQL reușită!')
    conn.close()
except Exception as e:
    print('Eroare la conectarea la PostgreSQL:', e)
    exit(1) # Ieșire cu cod de eroare dacă testul eșuează
"
if [ $? -ne 0 ]; then echo "Testul de conexiune a eșuat. Verifică detaliile."; exit 1; fi
echo "Testul de conexiune a trecut cu succes."

# --- 6. Gata! ---
echo "---"
echo "[6/6] FELICITĂRI! Totul este pregătit."
echo "Poți configura Django să utilizeze baza de date '$DB_NAME' cu utilizatorul '$DB_USER'."
echo "Nu uita să activezi mediul virtual ('source $VENV_PATH/bin/activate') înainte de a rula proiectul Django."
echo "---"