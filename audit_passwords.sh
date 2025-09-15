#!/bin/bash

rm reporte.txt

echo "------------------------------------" >> reporte.txt
echo "|    USUARIO    |    CONTRASEÑA    |" >> reporte.txt
echo "------------------------------------" >> reporte.txt
echo "|                                  |" >> reporte.txt

sudo unshadow /etc/passwd /etc/shadow > contrasenas.out
grep '\$' contrasenas.out | tail -n 3 > temp_hashes.out
cat temp_hashes.out
john --wordlist=/usr/share/wordlists/rockyou.txt --format=crypt temp_hashes.out

john --show temp_hashes.out > cracked.txt

cut -d: -f1 temp_hashes.out > usuarios_nombres.txt

cut -d: -f1 cracked.txt > usuarios_debiles.txt

while read -r usuario; do
    echo "$usuario"
    if grep -q "$usuario" usuarios_debiles.txt; then
        estado="Debil"
    else
        estado="Fuerte"
    fi
    echo "|   $usuario   |   $estado   |" >> reporte.txt
done < usuarios_nombres.txt

cat reporte.txt
