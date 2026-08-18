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
ansible rhel -m dnf -a "name=python3-dnf state=present update_cache=yes"
```
```json
rhel-node1 | SUCCESS => {
    "ansible_facts": {
        "pkg_mgr": "dnf"
    },
    "changed": false,
    "msg": "Nothing to do",
    "rc": 0,
    "results": []
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
ok: [rhel-node1]

TASK [1. Instalar el paquete de Nginx] *******************************************
changed: [rhel-node1]

TASK [2. Iniciar y habilitar el servicio de Nginx] *******************************
fatal: [rhel-node1]: FAILED! => {"changed": false, "msg": "Could not find the requested service nginx: host"}

PLAY RECAP ***********************************************************************
rhel-node1                    : ok=2    changed=1    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
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
ok: [rhel-node1]

TASK [1. Instalar el paquete de Nginx] *******************************************
changed: [rhel-node1]

TASK [2. Iniciar y habilitar el servicio de Nginx] *******************************
changed: [rhel-node1]

TASK [3. Publicar el index.html personalizado] ***********************************
changed: [rhel-node1]

PLAY RECAP ***********************************************************************
rhel-node1                    : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0                     : ok=4    changed=3    unreachable=0    failed=0
```
* **`ok=4`:** Cuatro tareas exitosas (incluyendo la recopilación de datos automática *Gathering Facts*).
* **`changed=3`:** Tres tareas realizaron cambios reales en el servidor (instaló, inició y copió el HTML).

---

## Análisis y Depuración con Verbosidad (`-v` a `-vvvv`)

### 1. Ejercicio A: Nivel 1 (`-v`) - El Mensaje Oculto

Cuando usas los módulos `command` o `shell`, Ansible por defecto solo te dice si la tarea generó un cambio (`changed: true`), pero oculta lo que el comando imprimió en la pantalla, a menos que el comando falle.

### Crea el Playbook (`test-verbose-1.yml`)

```yaml
---
- hosts: ubuntu-node1 # Usaremos solo un nodo para no saturar la pantalla
  gather_facts: false

  tasks:
    - name: Ejecutar un script o comando que devuelve un dato importante
      ansible.builtin.shell: "echo 'El token de activacion secreto es: XYZ-888'"

```

#### Prueba Práctica y Visual

**Paso 1: Ejecución normal (El problema)**
Ejecuta el playbook sin verbosidad:

```bash
ansible-playbook test-verbose-1.yml
```

> [\!NOTE]
> La terminal dirá `changed: [ubuntu-node1]`. ¡Pero no puedes ver cuál es el token secreto! El playbook fue exitoso, pero la información está oculta.

**Paso 2: Ejecución con Nivel 1 (La solución)**
Agrega `-v` al comando:

```bash
ansible-playbook test-verbose-1.yml -v
```
Using /config/workspace/ansible.cfg as config file

```bash
PLAY [ubuntu-node] ******************************************************************************************************************************************************************************

TASK [Ejecutar un script o comando que devuelve un dato importante] *****************************************************************************************************************************
changed: [ubuntu-node] => {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"}, "changed": true, "cmd": "echo 'El token de activacion secreto es: XYZ-888'", "delta": "0:00:00.001836", "end": "2026-08-18 16:57:28.347634", "msg": "", "rc": 0, "start": "2026-08-18 16:57:28.345798", "stderr": "", "stderr_lines": [], "stdout": "El token de activacion secreto es: XYZ-888", "stdout_lines": ["El token de activacion secreto es: XYZ-888"]}

PLAY RECAP **************************************************************************************************************************************************************************************
ubuntu-node                : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

*Lo que verás ahora:* Debajo de la tarea, Ansible desplegará un diccionario JSON que incluye el bloque `"stdout": "El token de activacion secreto es: XYZ-888"`.

---

### 2. Ejercicio B: Nivel 2 (`-vv`) - Descubriendo Parámetros por Defecto

A veces, usas un módulo pero olvidas definir ciertos parámetros (como los permisos de un archivo). Ansible aplicará valores por defecto, pero si algo falla, necesitas saber cuáles fueron esos valores. El nivel `-vv` te muestra exactamente qué parámetros recibió el módulo internamente.

#### Crea el Playbook (`test-verbose-2.yml`)

```yaml
---
- hosts: ubuntu-node1
  gather_facts: false

  tasks:
    - name: Crear un archivo sin especificar permisos
      ansible.builtin.file:
        path: /tmp/archivo_misterioso.txt
        state: touch
```

#### Prueba Práctica y Visual

Ejecuta el playbook con dos `v`:

```bash
ansible-playbook test-verbose-2.yml -vv
```

```bash
ansible-playbook [core 2.16.3]
  config file = /config/workspace/ansible.cfg
  configured module search path = ['/config/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /config/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible-playbook
  python version = 3.12.3 (main, Jun 19 2026, 12:46:00) [GCC 13.3.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
Using /config/workspace/ansible.cfg as config file
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: vv.yaml *******************************************************************************************************************************************************************************
1 plays in vervosidad/vv.yaml

PLAY [ubuntu-node] ******************************************************************************************************************************************************************************

TASK [Crear un archivo sin especificar permisos] ************************************************************************************************************************************************
task path: /config/workspace/vervosidad/vv.yaml:6
changed: [ubuntu-node] => {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"}, "changed": true, "dest": "/tmp/archivo_misterioso.txt", "gid": 1001, "group": "ansible", "mode": "0777", "owner": "ansible", "size": 0, "state": "file", "uid": 1001}

PLAY RECAP **************************************************************************************************************************************************************************************
ubuntu-node                : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

##### Lo que verás:

Presta atención a la línea de la tarea. Verás un texto que dice `task path: ...` seguido del resultado.
Dentro del resultado, verás el bloque **`"invocation": { "module_args": { ... } }`**.
Ahí podrás solucionar el misterio y ver que, aunque tú no los escribiste, Ansible inyectó parámetros ocultos basándose en tu usuario, comprobando que el `mode` (permisos) asignado fue algo como `0644` o `0664`, y te dirá exactamente qué `owner` y `group` se aplicaron.

---

### 4. Ejercicio C: Nivel 3 (`-vvv`) - Diagnóstico de Conexión y Python

Si Ansible no puede conectarse a un servidor, el nivel `-vvv` es tu mejor amigo. Este nivel expone exactamente qué usuario SSH está intentando usar, qué llave está ofreciendo y qué ruta de Python está utilizando en el servidor remoto.

#### Crea el Playbook (`test-verbose-3.yml`)

```yaml
---
- hosts: rocky-node1 # Cambiamos de nodo para variar
  gather_facts: false

  tasks:
    - name: Comprobar conexion basica
      ansible.builtin.ping:

```

#### Prueba Práctica y Visual

Ejecuta el playbook con tres `v`:

```bash
ansible-playbook test-verbose-3.yml -vvv
```

```bash
ansible-playbook [core 2.16.3]
  config file = /config/workspace/ansible.cfg
  configured module search path = ['/config/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /config/.ansible/collections:/usr/share/ansible/collections
  ...

PLAYBOOK: vvv.yaml ******************************************************************************************************************************************************************************
1 plays in vervosidad/vvv.yaml

PLAY [rocky-node] *******************************************************************************************************************************************************************************

TASK [Comprobar conexion basica] ****************************************************************************************************************************************************************
task path: /config/workspace/vervosidad/vvv.yaml:6
<rocky-node> ESTABLISH SSH CONNECTION FOR USER: ansible
<rocky-node> SSH: EXEC sshpass -d12 ssh -C -o ControlMaster=auto -o ControlPersist=60s -o 'User="ansible"' -o ConnectTimeout=10 -o 'ControlPath="/config/.ansible/cp/d359a63182"' rocky-node '/bin/sh -c '"'"'echo ~ansible && sleep 0'"'"''
<rocky-node> (0, b'/home/ansible\n', b"Warning: Permanently added 'rocky-node' (ED25519) to the list of known hosts.\r\n")
<rocky-node> ESTABLISH SSH CONNECTION FOR USER: ansible
<rocky-node> SSH: EXEC sshpass -d12 ssh -C -o ControlMaster=auto -o ControlPersist=60s -o 'User="ansible"' -o ConnectTimeout=10 -o 'ControlPath="/config/.ansible/cp/d359a63182"' rocky-node '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/ansible/.ansible/tmp `"&& mkdir "` echo /home/ansible/.ansible/tmp/ansible-tmp-1787072395.1651983-35802-71729859643083 `" && echo ansible-tmp-1787072395.1651983-35802-71729859643083="` echo /home/ansible/.ansible/tmp/ansible-tmp-1787072395.1651983-35802-71729859643083 `" ) && sleep 0'"'"''
...
<rocky-node> ESTABLISH SSH CONNECTION FOR USER: ansible
<rocky-node> SSH: EXEC sshpass -d12 ssh -C -o ControlMaster=auto -o ControlPersist=60s -o 'User="ansible"' -o ConnectTimeout=10 -o 'ControlPath="/config/.ansible/cp/d359a63182"' rocky-node '/bin/sh -c '"'"'rm -f -r /home/ansible/.ansible/tmp/ansible-tmp-1787072395.1651983-35802-71729859643083/ > /dev/null 2>&1 && sleep 0'"'"''
<rocky-node> (0, b'', b'')
ok: [rocky-node] => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "invocation": {
        "module_args": {
            "data": "pong"
        }
    },
    "ping": "pong"
}

PLAY RECAP **************************************************************************************************************************************************************************************
rocky-node                 : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

##### Lo que verás:

La salida será bastante más extensa. Busca estas líneas clave para resolver problemas de inventario:

1. **El intérprete de Python:** Busca la línea `Discovered python interpreter...` o `ansible_python_interpreter`. Sabrás exactamente si está usando `/usr/bin/python3` o una versión antigua, lo cual es vital si un módulo de Python falla.
2. **El comando SSH:** Verás la línea exacta que usa Ansible para conectarse: `ESTABLISH SSH CONNECTION FOR USER: rocky`. Si Ansible estuviera intentando usar el usuario equivocado (ej. `root`), aquí te darías cuenta de inmediato de que tu inventario está mal configurado.

---

### 5. Ejercicio D: Nivel 4 (`-vvvv`) - El Viaje del Plugin y Sudo (Depuración Profunda)

Este es el nivel máximo de verbosidad. Se usa en casos extremos cuando necesitas ver cómo Ansible empaqueta sus módulos en pequeños scripts de Python, los envía a través de SFTP/SCP al servidor, los ejecuta usando escalada de privilegios (`sudo`), y luego borra sus rastros.

#### Crea el Playbook (`test-verbose-4.yml`)

Vamos a usar `become: true` para obligar a Ansible a usar `sudo`.

```yaml
---
- hosts: rocky-node1
  gather_facts: false

  tasks:
    - name: Quien soy yo realmente
      ansible.builtin.command: whoami
      become: true # Activamos la escalada de privilegios

```

#### Prueba Práctica y Visual

Ejecuta el playbook con cuatro `v`:

```bash
ansible-playbook test-verbose-4.yml -vvvv
```

```bash
ansible-playbook [core 2.16.3]
  config file = /config/workspace/ansible.cfg
  configured module search path = ['/config/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /config/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible-playbook
  ...

PLAYBOOK: vvvv.yaml *****************************************************************************************************************************************************************************
Positional arguments: vervosidad/vvvv.yaml
verbosity: 4
remote_user: ansible
connection: ssh
become_method: sudo
tags: ('all',)
inventory: ('/config/workspace/inventario.yaml',)
forks: 5
1 plays in vervosidad/vvvv.yaml

PLAY [rocky-node] *******************************************************************************************************************************************************************************

TASK [Quien soy yo realmente] *******************************************************************************************************************************************************************
task path: /config/workspace/vervosidad/vvvv.yaml:6
<rocky-node> ESTABLISH SSH CONNECTION FOR USER: ansible
<rocky-node> SSH: EXEC sshpass -d12 ssh -vvv -C -o ControlMaster=auto -o ControlPersist=60s -o 'User="ansible"' -o ConnectTimeout=10 -o 'ControlPath="/config/.ansible/cp/d359a63182"' rocky-node '/bin/sh -c '"'"'echo ~ansible && sleep 0'"'"''
...
<rocky-node> ESTABLISH SSH CONNECTION FOR USER: ansible
<rocky-node> SSH: EXEC sshpass -d12 ssh -vvv -C -o ControlMaster=auto -o ControlPersist=60s -o 'User="ansible"' -o ConnectTimeout=10 -o 'ControlPath="/config/.ansible/cp/d359a63182"' rocky-node '/bin/sh -c '"'"'rm -f -r /home/ansible/.ansible/tmp/ansible-tmp-1787072566.4386768-36423-119001527090276/ > /dev/null 2>&1 && sleep 0'"'"''
...
changed: [rocky-node] => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": true,
    "cmd": [
        "whoami"
    ],
    "delta": "0:00:00.002989",
    "end": "2026-08-18 17:02:46.692426",
    "invocation": {
        "module_args": {
            "_raw_params": "whoami",
            "_uses_shell": false,
            "argv": null,
            "chdir": null,
            "creates": null,
            "executable": null,
            "expand_argument_vars": true,
            "removes": null,
            "stdin": null,
            "stdin_add_newline": true,
            "strip_empty_ends": true
        }
    },
    "msg": "",
    "rc": 0,
    "start": "2026-08-18 17:02:46.689437",
    "stderr": "",
    "stderr_lines": [],
    "stdout": "root",
    "stdout_lines": [
        "root"
    ]
}

PLAY RECAP **************************************************************************************************************************************************************************************
rocky-node                 : ok=1    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

##### Lo que verás (¡Prepárate para mucho texto!):

El objetivo de este nivel es auditar problemas de permisos de bajo nivel. En la terminal busca lo siguiente:

1. **La transferencia:** Verás comandos que dicen `EXEC (ssh ... sftp)` o `EXEC (ssh ... scp)`. Es Ansible copiando un archivo temporal (ej. `/home/rocky/.ansible/tmp/.../AnsiballZ_command.py`) a tu servidor remoto.
2. **La ejecución real:** Verás la línea exacta que se ejecuta en el servidor. Notarás algo parecido a `sudo -H -S -n -u root ... /bin/sh -c ... python3 /ruta/temporal/AnsiballZ_command.py`.
*Si alguna vez un administrador de seguridad te pregunta "¿Qué comandos exactos ejecuta Ansible en mi servidor?", con el nivel `-vvvv` puedes mostrarle la secuencia nativa completa de Linux.*

---
[Anterior: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md) | [Siguiente: Índice del Curso](../README.md)
