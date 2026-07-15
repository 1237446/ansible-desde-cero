# Laboratorio 04: Handlers en Ansible

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

### Paso 1: crear directorio de trabajo

```bash
mkdir -p lab-handlers
cd lab-handlers
```

### Paso 2: crear el playbook

```bash
cat > handlers-demo.yml << 'EOF'
---
- name: Repasar handlers con un archivo de configuracion
  hosts: ubuntu
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
ansible-playbook handlers-demo.yml
```

Salida esperada:

```text
PLAY [Repasar handlers con un archivo de configuracion] ***

TASK [Crear el directorio de repaso] ***
changed: [ubuntu]

TASK [Administrar la configuracion de ejemplo] ***
changed: [ubuntu]

RUNNING HANDLER [Registrar cambio de configuracion] ***
changed: [ubuntu]

TASK [Consultar el registro creado por el handler] ***
ok: [ubuntu]

TASK [Mostrar el registro] ***
ok: [ubuntu] => {
    "handler_log.stdout_lines": [
        "La configuracion cambio y el handler fue ejecutado."
    ]
}

PLAY RECAP ***
ubuntu: ok=5 changed=3 unreachable=0 failed=0
```

### Ejecución sin cambios

```bash
ansible-playbook handlers-demo.yml
```

Salida esperada (segunda ejecución):

```text
PLAY [Repasar handlers con un archivo de configuracion] ***

TASK [Crear el directorio de repaso] ***
ok: [ubuntu]

TASK [Administrar la configuracion de ejemplo] ***
ok: [ubuntu]

TASK [Consultar el registro creado por el handler] ***
ok: [ubuntu]

TASK [Mostrar el registro] ***
ok: [ubuntu] => {
    "handler_log.stdout_lines": [
        "La configuracion cambio y el handler fue ejecutado."
    ]
}

PLAY RECAP ***
ubuntu: ok=4 changed=0 unreachable=0 failed=0
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

Vuelve a ejecutar:

```bash
ansible-playbook handlers-demo.yml
```

El handler debe ejecutarse porque el contenido cambió.

### Ejercicio 2: quitar flush_handlers

Elimina o comenta la tarea `flush_handlers`:

```yaml
# - name: Ejecutar handlers antes de validar
#   ansible.builtin.meta: flush_handlers
```

Ejecuta y observa:

```bash
ansible-playbook handlers-demo.yml
```

Ahora el handler se ejecuta **al final** del playbook, después de intentar leer `handler.log`. En la primera ejecución, el archivo no existirá aún y la tarea fallará.

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

Agrega un segundo `notify` en alguna tarea:

```yaml
notify:
  - Registrar cambio de configuracion
  - Crear archivo de estado
```

Ejecuta y verifica que ambos handlers se ejecutaron.

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
ansible ubuntu -m shell -a "rm -rf /tmp/repaso-handlers"
```
