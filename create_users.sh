#!/bin/bash

#set -e
#set -x

archivo="$1"

if [ ! -e "$archivo" ]; then
   echo "archivo inexistente"
else

   echo "Se recibio el archivo de nombre: $archivo"

   #cat $archivo

   while IFS= read -r linea; do

       #echo "Linea: $linea"
       nombre=$(cut -d ":" -f1 <<< $linea)
       #echo "nombre: $nombre"

       contrasena=$(cut -d ":" -f2- <<< $linea)
       #echo "contrasena: $contrasena"

       sudo useradd "$nombre"

       #read -p "Introduce contraseña para $nombre: " contrasena_usuario_actual
       #echo "Entre"
       echo "$nombre:$contrasena" | sudo chpasswd

       if id "$nombre" >/dev/null 2>&1; then
          echo "El usuario $nombre se creo correctamente"
       else
          echo "Hubo un error al crear el usuario $nombre"
       fi

   done < $archivo

fi
