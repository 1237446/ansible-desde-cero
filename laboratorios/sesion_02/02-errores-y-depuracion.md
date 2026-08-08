# Laboratorio 02: Vaidacion de playbooks y depuracion

En este laboratorio práctico, aprenderás a utilizar las herramientas nativas de Ansible para validar la sintaxis, simular ejecuciones y depurar playbooks de manera eficiente mediante distintos niveles de verbosidad.

---

## 1. Objetivos del Laboratorio

* Crear un archivo de Playbook (`nginx-rhel.yml`) en formato YAML estructurado.
* Realizar verificaciones de sintaxis (`--syntax-check`) y simulaciones de cambios (*Dry Run con --check*).
* Utilizar los niveles de verbosidad (-v hasta -vvvv) para analizar la ejecución y depurar errores en tiempo real.
---

## 2. Instrucciones Paso a Paso

### Paso 1: Crear el archivo del Playbook
Dentro del nodo de control `ansible-control`, crea un archivo llamado `nginx-rhel.yml`:

```bash
nano nginx-rhel.yml
```

Copia y pega el siguiente código en el archivo:

```yaml
---
- name: Desplegar Servidor Web Nginx - redhat
  hosts: rhel
  become: true
  tasks:
    - name: 1. Instalar el paquete de Nginx
      ansible.builtin.dnf:
        name: nginx
        state: present
        update_cache: true

    - name: 2. Iniciar y habilitar el servicio de Nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

    - name: 3. Publicar el index.html personalizado en Red Hat
      ansible.builtin.copy:
        dest: /usr/share/nginx/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>Servidor RetHat Linux con Ansible</title>
          </head>
          <body>
              <h1>Servidor Gestionado con Ansible</h1>
              <p>Despliegue e infraestructura totalmente automatizados por la OTI.</p>
          </body>
          </html>
        owner: nginx
        group: nginx
        mode: '0644'
```

---

### Paso 2: Verificar la Sintaxis
Antes de lanzar el playbook, ejecuta una verificación sintáctica para evitar fallos de formato:
```bash
ansible-playbook nginx-rhel.yml --syntax-check
```
*Si la salida solo muestra el nombre del playbook, la sintaxis es correcta.*
```bash
playbook: nginx-rhel.yml
```
---

### Paso 3: Simular el Despliegue (Dry Run)
Primero instalamos el modulo *python3-apt* para poder realizar la validacion:
```bash
ansible rhel -m apt -a "name=python3-apt state=present update_cache=yes"
```
```json
ubuntu1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "cache_update_time": 1785365441,
    "cache_updated": false,
    "changed": false
}
```

Prueba qué cambios realizaría Ansible sin llegar a modificar los servidores:
```bash
ansible-playbook nginx-rhel.yml --check
```
*Inspecciona la salida para comprobar qué tareas se reportan como "changed" y "failed" en la simulación.*

```bash
PLAY [Desplegar Servidor Web Nginx] **********************************************

TASK [Gathering Facts] ***********************************************************
ok: [ubuntu1]

TASK [1. Instalar el paquete de Nginx] *******************************************
changed: [ubuntu1]

TASK [2. Iniciar y habilitar el servicio de Nginx] *******************************
fatal: [ubuntu1]: FAILED! => {"changed": false, "msg": "Could not find the requested service nginx: host"}

PLAY RECAP ***********************************************************************
ubuntu1                    : ok=2    changed=1    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```
> [\!NOTE]
> el servicio de Nginx aún no existe en ubuntu1 y el modo --check no realiza ningún cambio real en los servidores; solo simula qué pasaría si lo ejecutaras. Por eso el *failed*

---

### Paso 4: Ejecutar el Playbook
Lanza la automatización para aplicar de verdad los cambios en los servidores remotos:
```bash
ansible-playbook nginx-rhel.yml
```

**Analiza el PLAY RECAP final:**
```bash
PLAY [Desplegar Servidor Web Nginx] **********************************************

TASK [Gathering Facts] ***********************************************************
ok: [ubuntu1]

TASK [1. Instalar el paquete de Nginx] *******************************************
changed: [ubuntu1]

TASK [2. Iniciar y habilitar el servicio de Nginx] *******************************
changed: [ubuntu1]

TASK [3. Publicar el index.html personalizado] ***********************************
changed: [ubuntu1]

PLAY RECAP ***********************************************************************
ubuntu1                    : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0                   : ok=4    changed=3    unreachable=0    failed=0
```
* **`ok=4`:** Cuatro tareas exitosas (incluyendo la recopilación de datos automática *Gathering Facts*).
* **`changed=3`:** Tres tareas realizaron cambios reales en el servidor (instaló, inició y copió el HTML).

---

### Paso 5: Análisis y Depuración con Verbosidad (`-v` a `-vvvv`)

Utiliza los diferentes niveles de verbosidad para inspeccionar con mayor profundidad las tareas ejecutadas y resolver posibles errores de conexión o configuración.

**Ejecución con nivel básico (`-v`)**
Muestra información general sobre los resultados de las tareas ejecutadas.

```bash
ansible-playbook -v nginx-rhel.yml

```

```bash
PLAY [Desplegar Servidor Web Nginx - redhat] ********************************************************

TASK [Gathering Facts] ******************************************************************************
ok: [rhel-node1]

TASK [1. Instalar el paquete de Nginx] **************************************************************
ok: [rhel-node1] => {"changed": false, "msg": "Nothing to do", "rc": 0, "results": []}

TASK [2. Iniciar y habilitar el servicio de Nginx] **************************************************
ok: [rhel-node1] => {"changed": false, "enabled": true, "name": "nginx", "state": "started", "status": {"ActiveEnterTimestamp": "Sat 2026-08-08 18:44:00 UTC", "ActiveEnterTimestampMonotonic": "8151422235", "ActiveExitTimestampMonotonic": "0", "ActiveState": "active", "After": "basic.target sysinit.target tmp.mount network-online.target systemd-tmpfiles-setup.service systemd-journald.socket -.mount system.slice nss-lookup.target remote-fs.target", "AllowIsolate": "no", "AssertResult": "yes", "AssertTimestamp": "Sat 2026-08-08 18:44:00 UTC", "AssertTimestampMonotonic": "8151346179", "Before": "multi-user.target shutdown.target", "BlockIOAccounting": "no", "BlockIOWeight": "[not set]", "CPUAccounting"
...
```

**Ejecución con nivel máximo de depuración de conexión (`-vvvv`)**
Muestra el proceso completo de depuración de conexiones SSH, plugins y variables internas utilizadas.

```bash
ansible-playbook -vvvv nginx-rhel.yml
```

```bash
nsible-playbook [core 2.20.1]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible-playbook
  python version = 3.14.4 (main, Jun 18 2026, 14:25:02) [GCC 15.2.0] (/usr/bin/python3)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)
No config file found; using defaults
setting up inventory plugins
Loading collection ansible.builtin from
...
```

---
[Anterior: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md) | [Siguiente: Índice del Curso](../README.md)
