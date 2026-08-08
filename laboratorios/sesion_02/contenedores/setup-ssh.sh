#!/bin/bash

# 1. Definir la ruta de la clave SSH y la contraseña por defecto del laboratorio
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_PASSWORD="password"  # Cambia esto si tu contraseña en el laboratorio es distinta
SSH_USER="ansible"       # Usuario remoto configurado en tus nodos

echo "=== 1. Verificando par de claves SSH ==="
if [ ! -f "$SSH_KEY" ]; then
    echo "No se encontró una clave SSH en $SSH_KEY. Generando una nueva..."
    ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_KEY"
    echo "¡Clave SSH generada con éxito!"
else
    echo "La clave SSH ya existe en $SSH_KEY. Saltando generación."
fi

# 2. Definir los hosts de destino
echo ""
echo "=== 2. Copiando la clave SSH a los hosts ==="

HOSTS=("ubuntu-node1" "ubuntu-node2" "ubuntu-node3" "rhel-node1" "rhel-node2" "rhel-node3")
SSH_PORT=22

for host in "${HOSTS[@]}"; do
    echo "--------------------------------------------------"
    echo "Intentando copiar clave a: $host (Puerto: $SSH_PORT)"

    # Usamos sshpass para inyectar la contraseña automáticamente a ssh-copy-id
    sshpass -p "$SSH_PASSWORD" ssh-copy-id -p "$SSH_PORT" -o StrictHostKeyChecking=no "${SSH_USER}@$host"

    if [ $? -eq 0 ]; then
        echo " [ÉXITO] Clave copiada correctamente a $host"
    else
        echo " [ERROR] No se pudo conectar o copiar la clave a $host"
    fi
done

echo "--------------------------------------------------"
echo "¡Proceso de configuración SSH finalizado!"
