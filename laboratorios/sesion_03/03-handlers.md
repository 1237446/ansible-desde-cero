# Laboratorio 03: Handlers en Ansible

## Objetivo

Aprender a usar handlers en Ansible para ejecutar tareas de forma condicional, solo cuando una tarea principal reporta un cambio.

Los handlers son tareas que se ejecutan **solo cuando otra tarea notifica un cambio**. Son ideales para acciones como reiniciar servicios, registrar eventos o validar configuraciones después de modificaciones.

---

## Conceptos Clave

| Concepto | Descripción |
|----------|-------------|
| `notify` | Disparador que activa un handler cuando la tarea cambia |
| `handlers` | Sección del playbook donde se definen los handlers |
| `flush_handlers` | Fuerza la ejecución de handlers pendientes en ese punto del playbook |
| `register` | Guarda el resultado de una tarea en una variable |
| `changed_when` | Controla cuándo una tarea reporta un cambio |

---

## Parte 1: Crear el Playbook

```bash
cat > handlers-demo.yaml << 'EOF'
---
- name: Repasar handlers con un archivo de configuracion
  hosts: ubuntu-node1
  gather_facts: false

  tasks:
    - name: Crear el directorio de repaso
      ansible.builtin.file:
        path: /tmp/repaso-handlers
        state: directory
        mode: "0755"

    - name: Administrar la configuracion de ejemplo
      ansible.builtin.copy:
        dest: /tmp/repaso-handlers/aplicacion.conf
        content: |
          modo=clase
          version=1
        mode: "0644"
      notify: Registrar cambio de configuracion

    - name: Ejecutar handlers antes de validar
      ansible.builtin.meta: flush_handlers

    - name: Consultar el registro creado por el handler
      ansible.builtin.command:
        cmd: cat /tmp/repaso-handlers/handler.log
      register: handler_log
      changed_when: false

    - name: Mostrar el registro
      ansible.builtin.debug:
        var: handler_log.stdout_lines

  handlers:
    - name: Registrar cambio de configuracion
      ansible.builtin.copy:
        dest: /tmp/repaso-handlers/handler.log
        content: "La configuracion cambio y el handler fue ejecutado.\n"
        mode: "0644"
EOF
```

---

## Parte 2: Entender el Playbook

### Flujo de ejecución

```text
1. Crear directorio /tmp/repaso-handlers
2. Copiar archivo de configuración
3. Si el archivo cambió → notificar handler
4. flush_handlers → ejecutar handler inmediatamente
5. Leer el archivo handler.log
6. Mostrar el contenido del log
```

### Puntos importantes

**`notify` en la tarea de configuración:**

```yaml
notify: Registrar cambio de configuracion
```

Solo se activa si el módulo `copy` detecta que el archivo cambió o se creó por primera vez.

**`flush_handlers` después de la notificación:**

```yaml
- name: Ejecutar handlers antes de validar
  ansible.builtin.meta: flush_handlers
```

Por defecto, los handlers se ejecutan al final de todos los tasks. `flush_handlers` fuerza su ejecución en ese punto del playbook, permitiendo que las siguientes tareas dependan del resultado del handler.

**`register` y `changed_when`:**

```yaml
register: handler_log
changed_when: false
```

`register` captura la salida del comando. `changed_when: false` indica que esta tarea de lectura nunca reporta un cambio (evita falsos positivos).

---

## Parte 3: Ejecutar el Playbook

### Ejecución normal

```bash
ansible-playbook handlers-demo.yaml
```

Salida esperada:

```bash
PLAY [Repasar handlers con un archivo de configuracion] **************************

TASK [Crear el directorio de repaso] *********************************************
changed: [ubuntu1]

TASK [Administrar la configuracion de ejemplo] ***********************************
changed: [ubuntu1]

TASK [Ejecutar handlers antes de validar] ****************************************

RUNNING HANDLER [Registrar cambio de configuracion] ******************************
changed: [ubuntu1]

TASK [Consultar el registro creado por el handler] *******************************
ok: [ubuntu1]

TASK [Mostrar el registro] *******************************************************
ok: [ubuntu1] => {
    "handler_log.stdout_lines": [
        "La configuracion cambio y el handler fue ejecutado."
    ]
}

PLAY RECAP ***********************************************************************
ubuntu1                    : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Ejecución sin cambios

```bash
ansible-playbook handlers-demo.yaml
```

Salida esperada (segunda ejecución):

```text
PLAY [Repasar handlers con un archivo de configuracion] **************************

TASK [Crear el directorio de repaso] *********************************************
ok: [ubuntu1]

TASK [Administrar la configuracion de ejemplo] ***********************************
ok: [ubuntu1]

TASK [Ejecutar handlers antes de validar] ****************************************

TASK [Consultar el registro creado por el handler] *******************************
ok: [ubuntu1]

TASK [Mostrar el registro] *******************************************************
ok: [ubuntu1] => {
    "handler_log.stdout_lines": [
        "La configuracion cambio y el handler fue ejecutado."
    ]
}

PLAY RECAP ***********************************************************************
ubuntu1                    : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

En la segunda ejecución, el archivo de configuración no cambió, por lo tanto el handler **no se ejecutó**.

---

## Parte 4: Experimentar

### Ejercicio 1: modificar el contenido del archivo

Cambia el contenido en el playbook:

```yaml
content: |
  modo=produccion
  version=2
```

```yaml
- name: Administrar la configuracion de ejemplo
  ansible.builtin.copy:
    dest: /tmp/repaso-handlers/aplicacion.conf
    content: |
      modo=produccion
      version=2
    mode: "0644"
  notify: Registrar cambio de configuracion
```

Vuelve a ejecutar:

```bash
ansible-playbook handlers-demo.yml
```

El handler debe ejecutarse porque el contenido cambió.
```bash
ansible ubuntu-node1 -m command -a "cat /tmp/repaso-handlers/aplicacion.conf"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
modo=produccion
version=2
```

### Ejercicio 2: quitar flush_handlers

Eliminamos el archivo creado por el playbook
```bash
ansible ubuntu-node1 -m command -a "rm -rf /tmp/repaso-handlers"
```

Elimina o comenta la tarea `flush_handlers`:
```yaml
# - name: Ejecutar handlers antes de validar
#   ansible.builtin.meta: flush_handlers
```

Ejecuta y observa:
```bash
ansible-playbook handlers-demo.yaml
```

Ahora el handler se ejecuta **al final** del playbook, después de intentar leer `handler.log`. En la primera ejecución, el archivo no existirá aún y la tarea fallará.

```bash
PLAY [Repasar handlers con un archivo de configuracion] ************************************************************

TASK [Crear el directorio de repaso] *******************************************************************************
changed: [ubuntu1]

TASK [Administrar la configuracion de ejemplo] *********************************************************************
changed: [ubuntu1]

TASK [Consultar el registro creado por el handler] *****************************************************************
fatal: [ubuntu1]: FAILED! => {"changed": false, "cmd": ["cat", "/tmp/repaso-handlers/handler.log"], "delta": "0:00:00.002539", "end": "2026-07-30 16:54:30.703627", "msg": "non-zero return code", "rc": 1, "start": "2026-07-30 16:54:30.701088", "stderr": "cat: /tmp/repaso-handlers/handler.log: No such file or directory", "stderr_lines": ["cat: /tmp/repaso-handlers/handler.log: No such file or directory"], "stdout": "", "stdout_lines": []}

PLAY RECAP *********************************************************************************************************
ubuntu1                    : ok=2    changed=2    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

### Ejercicio 3: agregar múltiples handlers

Agrega un segundo handler al playbook:

```yaml
handlers:
  - name: Registrar cambio de configuracion
    ansible.builtin.copy:
      dest: /tmp/repaso-handlers/handler.log
      content: "La configuracion cambio y el handler fue ejecutado.\n"
      mode: "0644"

  - name: Crear archivo de estado
    ansible.builtin.copy:
      dest: /tmp/repaso-handlers/estado.txt
      content: "Estado: activo\n"
      mode: "0644"
```

Agrega un segundo `notify` en alguna tarea y cambia el contenido en el playbook:

```yaml
- name: Administrar la configuracion de ejemplo
  ansible.builtin.copy:
    dest: /tmp/repaso-handlers/aplicacion.conf
    content: |
      modo=produccion
      version=3
    mode: "0644"
  notify:
    - Registrar cambio de configuracion
    - Crear archivo de estado
```

Ejecuta y verifica que ambos handlers se ejecutaron.
```bash
ansible-playbook handlers-demo.yml
```

Verificar el cambio del archivo *aplicacion.conf*
```bash
ansible ubuntu-node1 -m command -a "cat /tmp/repaso-handlers/aplicacion.conf"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
modo=produccion
version=3
```

Verificar la creacion del archivo *estado.txt*
```bash
ansible ubuntu-node1 -m command -a "cat /tmp/repaso-handlers/estado.txt"
```
```bash
ubuntu1 | CHANGED | rc=0 >>
Estado: activo
```

---

## Comandos Útiles

| Comando | Descripción |
|---------|-------------|
| `ansible-playbook handlers-demo.yml` | Ejecutar el playbook |
| `ansible-playbook handlers-demo.yml --check` | Modo dry-run (sin cambios reales) |
| `ansible-playbook handlers-demo.yml --diff` | Mostrar diferencias en archivos |
| `ansible-playbook handlers-demo.yml -v` | Modo verbose |

---

## Errores Frecuentes

| Error | Causa | Solución |
|-------|-------|----------|
| Handler no se ejecuta | La tarea no reportó cambio | Verificar que el contenido realmente cambió |
| Handler se ejecuta siempre | `changed_when` no está definido | Agregar `changed_when: false` en tareas de lectura |
| Handler ejecuta antes de tiempo | Falta `flush_handlers` | Agregar `meta: flush_handlers` después del notify |
| Handler no encuentra nombre | Error de escritura en `notify` | Verificar que el nombre coincida exactamente |

---

## Limpieza

```bash
# Eliminar los archivos creados en el host remoto
ansible web -i inventory.ini -m command -a "rm -rf /tmp/repaso-handlers"
```
