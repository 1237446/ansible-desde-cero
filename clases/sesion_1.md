# SESIÓN 1 - Primeros pasos con Ansible y automatización de servidores

* Qué es Ansible y por qué se usa para automatizar infraestructura Linux 
* Cómo funciona su arquitectura agentless mediante SSH 
* Preparación del laboratorio con VirtualBox y servidores Linux 
* Primeros comandos ad-hoc para ejecutar tareas remotas sin playbooks

---

## 📑 Índice
1. [Introducción a Ansible](#1-introducción-a-ansible)
2. [Ventajas y Características](#2-ventajas-y-características)
3. [Arquitectura de Ansible](#3-arquitectura-de-ansible)
4. [Preparación del Laboratorio](#4-preparación-del-laboratorio)
5. [Inventarios](#5-inventarios)
6. [Configuración (ansible.cfg)](#6-configuración-ansiblecfg)
7. [Módulos de Ansible](#7-módulos-de-ansible)
8. [Comandos Ad-Hoc](#8-comandos-ad-hoc)

---

## 1. Introducción a Ansible

### El Problema: Administración Manual de Servidores
Antes de la automatización, la gestión de infraestructura requería:
* Instalar paquetes uno por uno en cada servidor.
* Configurar servicios manualmente.
* Verificar el estado de los servicios.
* Manejar múltiples servidores, lo cual se vuelve tedioso y altamente **propenso a errores humanos**.

### La Solución: ¿Qué es Ansible?
Ansible (creado en 2012 por Michael DeHaan y posteriormente adquirido por Red Hat) es una plataforma de automatización IT open-source que permite:
* **Gestión de configuraciones:** Mantener servidores en un estado deseado.
* **Despliegue de aplicaciones:** Automatizar el despliegue (deployment) de software.
* **Orquestación:** Coordinar tareas complejas entre múltiples sistemas.
* **Aprovisionamiento:** Configurar infraestructura desde cero.

### Scripts Tradicionales vs Ansible
| Criterio | Scripts Tradicionales (Bash, Python) | Ansible (Playbooks) |
| :--- | :--- | :--- |
| **Enfoque** | Imperativo (Dices *cómo* hacerlo) | Declarativo (Dices *qué* estado deseas) |
| **Esfuerzo** | Requieren controlar muchos casos y errores manualmente. | Usa módulos listos para tareas comunes. |
| **Idempotencia** | El resultado depende de cómo se escribió (puede fallar si se ejecuta dos veces). | **Idempotente por diseño** (Solo aplica cambios si es necesario). |
| **Mantenimiento** | Complejos y difíciles de reutilizar. | Playbooks altamente legibles y estructurados. |

---

## 2. Ventajas y Características

### Comparativa: Ansible vs Otras Herramientas
Existen otras herramientas en el mercado, pero Ansible destaca por su simplicidad:
* **Puppet:** Enfocado en la gobernanza y auditoría estricta (Requiere agentes y usa un DSL propio).
* **Chef:** Ofrece máxima flexibilidad programática al escribir configuración como código real en Ruby.
* **SaltStack:** Destaca por su velocidad y arquitectura basada en eventos (ZeroMQ).
* **Ansible:** Destaca por ser **Agentless** (sin agentes), utilizar **SSH** estándar y basarse en **YAML**.

### Formato YAML (Legible por humanos)
A diferencia de otras herramientas que requieren aprender lenguajes de programación complejos, Ansible usa YAML.

**Ejemplo en Ansible (YAML):**
```yaml
- name: Asegurar que Apache está corriendo
  service:
    name: apache2
    state: started
    enabled: yes
```

**Ejemplo en Puppet (DSL propio):**
```puppet
service { 'apache2':
  ensure => 'running',
  enable => true,
}
```

**Ejemplo en Chef (Ruby DSL):**
```ruby
service 'apache2' do
  action [:enable, :start]
  supports :restart => true, :reload => true
end
```

---

## 3. Arquitectura de Ansible

La arquitectura de Ansible se basa en un modelo **Push** (empujar configuraciones) y es **Agentless** (no requiere instalar software o demonios adicionales en los servidores destino). Esto reduce drásticamente la superficie de ataque.

1. **Control Node (Tu máquina):** Donde ejecutas Ansible. Contiene el *Ansible-core*, el *Inventario*, los *Módulos* y los *Plugins*.
2. **Conexión SSH:** Ansible abre un túnel blindado (SSH directo) hacia los servidores. Se utiliza autenticación por claves criptográficas (pública/privada) en lugar de contraseñas.
3. **Managed Nodes (Servidores destino):** Reciben las instrucciones, las procesan y devuelven el resultado.

### Flujo de Trabajo
1. **Handshake:** Establecer la conexión SSH.
2. **Generación:** Empaquetar módulos en Python y transferirlos al servidor destino.
3. **Ejecución remota:** El código se procesa en el destino.
4. **Retorno:** Se reporta el estado y los resultados en formato JSON.
5. **Limpieza:** Ansible borra los archivos temporales transferidos (sin dejar rastro).

---

## 4. Preparación del Laboratorio

Para simular un entorno empresarial con múltiples servidores sin consumir excesivos recursos, utilizaremos una combinación de **VirtualBox** y **Docker**.

1. **VirtualBox + Ubuntu Base:** Crearemos una única máquina virtual con Ubuntu Server (mínimo 2 GB RAM, 2 CPUs). Red configurada en adaptador "Sólo Anfitrión" o "Red Interna".
2. **Docker y Docker Compose:** Dentro de la VM, usaremos contenedores Docker para simular nuestros nodos (servidores gestionados). Los contenedores son ideales porque empaquetan la aplicación y dependencias aisladas del sistema host.

### Comandos de Instalación (En la VM Ubuntu)
```bash
# 1. Instalar Docker y Git
sudo apt update && sudo apt install docker.io docker-compose-v2 git -y

# 2. Clonar el repositorio del laboratorio
git clone https://github.com/1237446/laboratorio-ansible.git
cd laboratorio-ansible

# 3. Iniciar el laboratorio en segundo plano
docker compose up -d

# 4. Ingresar al nodo de control para empezar a usar Ansible
sudo docker exec -it ansible-control bash
```

---

## 5. Inventarios

El **inventario** es como tu agenda de contactos. Es un archivo donde listas las direcciones IP o nombres de dominio de tus servidores y los organizas para aplicar automatizaciones masivamente.
* **Hosts:** Máquinas individuales.
* **Grupos:** Conjuntos de hosts (ej. servidores web, bases de datos).
* **Grupos de Grupos (children):** Grupos que contienen otros grupos.

### Formato INI (Más simple)
```ini
[web]
ubuntu-node1

[db]
rhel-node1

[all:vars]
ansible_user=ansible
```

### Formato YAML (Recomendado para estructuras complejas)
```yaml
all:
  vars:
    ansible_user: ansible
  children:
    web:
      hosts:
        ubuntu-node1:
    db:
      hosts:
        rhel-node1:
```

---

## 6. Configuración (ansible.cfg)

El archivo `ansible.cfg` controla el comportamiento general de Ansible. Ansible busca este archivo en un orden de precedencia específico: **El primero que encuentra, gana**.
1. Variables de entorno (`ANSIBLE_CONFIG`).
2. `./ansible.cfg` (En el directorio actual de tu proyecto - **El más recomendado**).
3. `~/.ansible.cfg` (En el home del usuario).
4. `/etc/ansible/ansible.cfg` (Configuración global).

### Ejemplo de `ansible.cfg` para el proyecto:
```ini
[defaults]
# Ruta al archivo que contiene tus servidores/inventario
inventory = ./inventory.yaml

# Usuario remoto por defecto para iniciar sesión
remote_user = ubuntu

# Archivo de clave privada para autenticación SSH
private_key_file = ~/.ssh/id_rsa

# Desactiva la verificación estricta de claves SSH (útil en laboratorios o automatización masiva)
host_key_checking = False

# Formato de salida visual limpio en la terminal
stdout_callback = yaml
timeout = 30

[privilege_escalation]
# Activa la elevación de privilegios (ej. usar sudo)
become = True
become_method = sudo
become_user = root

# Evita que pida la contraseña de sudo interactivamente
become_ask_pass = False
```

---

## 7. Módulos de Ansible

Los módulos (o *task plugins*) son las herramientas de trabajo. Son unidades de código reutilizables e independientes que ejecutan tareas específicas en el servidor remoto.
* Son **idempotentes**.
* Se envían al servidor, se ejecutan y se borran.

### Módulos más utilizados:
* `ping`: Verifica la conectividad (No es un ping ICMP, verifica que Ansible pueda abrir sesión SSH y ejecutar Python).
* `command` / `shell`: Ejecuta comandos en el sistema remoto (shell acepta pipes `|` y redirecciones).
* `copy`: Copia archivos desde el nodo de control al servidor gestionado.
* `apt` / `yum`: Gestión e instalación de paquetes según la distribución de Linux.
* `service`: Arranca, detiene o reinicia servicios del sistema (ej. Nginx, Apache).
* `setup`: Recopila información detallada del sistema (conocidos como *facts*).

---

## 8. Comandos Ad-Hoc

*"Una línea, múltiples servidores."*

Los comandos Ad-Hoc son ejecuciones rápidas y puntuales que se lanzan directamente desde la terminal sin necesidad de escribir un *Playbook*. Son ideales para reiniciar un servicio rápido, verificar el estado de los servidores o instalar una utilidad al instante.

**Sintaxis General:**
```bash
ansible <hosts/grupo> -i <inventario> -m <módulo> -a "<argumentos>"
```

### Ejemplos Prácticos

**1. Verificar conectividad en todos los servidores:**
```bash
ansible all -i inventory.ini -m ping
```

**2. Ejecutar un comando remoto para ver el tiempo de actividad:**
```bash
ansible web -i inventory.ini -m command -a "uptime"
```

**3. Instalar un paquete (htop) con permisos de administrador:**
```bash
ansible web -i inventory.ini -m apt -a "name=htop state=present" --become
```

**4. Copiar un archivo a los servidores:**
```bash
ansible all -i inventory.ini -m copy -a "src=./hola.txt dest=/tmp/hola.txt"
```

**5. Reiniciar un servicio (Nginx):**
```bash
ansible web -i inventory.ini -m service -a "name=nginx state=restarted" --become
```
