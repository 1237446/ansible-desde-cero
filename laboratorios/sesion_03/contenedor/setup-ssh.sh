#!/bin/bash

# 1. Definir la ruta de la clave SSH (por defecto RSA de 4096 bits o Ed25519)
SSH_KEY="$HOME/.ssh/id_rsa"

echo "=== 1. Verificando par de claves SSH ==="
if [ ! -f "$SSH_KEY" ]; then
    echo "No se encontró una clave SSH en $SSH_KEY. Generando una nueva..."
    ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_KEY"
    echo "¡Clave SSH generada con éxito!"
else
    echo "La clave SSH ya existe en $SSH_KEY. Saltando generación."
fi

# 2. Definir los hosts de destino
# Puedes listar tus IPs o nombres de host aquí, separados por espacio:
# HOSTS=("192.168.1.10" "192.168.1.11" "web1" "web2")
# O puedes extraerlos automáticamente si usas tu inventario de Ansible estático/dinámico.

echo ""
echo "=== 2. Copiando la clave SSH a los hosts ==="

# Ejemplo con una lista estática de hosts de laboratorio (cámbiala según tus contenedores/VMs)
HOSTS=("web1" "web2" "web3" "web4")

# Puerto SSH por defecto (cámbialo si tus contenedores usan otro puerto mapeado, ej. 2222)
SSH_PORT=22

for host in "${HOSTS[@]}"; do
    echo "--------------------------------------------------"
    echo "Intentando copiar clave a: $host (Puerto: $SSH_PORT)"
    
    # ssh-copy-id enviará la clave pública al host remoto
    # Nota: Te pedirá la contraseña del usuario remoto la primera vez
    ssh-copy-id -p "$SSH_PORT" -o StrictHostKeyChecking=no "root@$host"
    
    if [ $? -eq 0 ]; then
        echo " [ÉXITO] Clave copiada correctamente a $host"
    else
        echo " [ERROR] No se pudo conectar o copiar la clave a $host"
    fi
done

echo "--------------------------------------------------"
echo "¡Proceso de configuración SSH finalizado!"
