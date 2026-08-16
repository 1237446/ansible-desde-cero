# Laboratorio 01: Controlando el flujo con `when` (Ejercicios Individuales)

Este laboratorio tiene como objetivo principal comprender el uso de **condicionales** en Ansible a través de la directiva **`when`**. Esta herramienta es fundamental para tomar decisiones lógicas durante la ejecución de un Playbook, permitiendo que una tarea se ejecute o se omita dependiendo de ciertas condiciones (como el sistema operativo, la memoria disponible o el resultado de una tarea anterior).

Al igual que en los laboratorios anteriores, hemos separado cada concepto en su propio archivo de Playbook.

---

## 1. Objetivos del Laboratorio

* Ejecutar tareas específicas según la familia del sistema operativo (Ubuntu/Debian vs Rocky/RedHat).
* Evaluar condiciones lógicas y numéricas (mayor que, menor que, combinaciones con `and` / `or`).
* Tomar decisiones basadas en el resultado de una tarea anterior capturado con `register`.

---

## 2. Ejercicio A: Condicional basado en el Sistema Operativo

En entornos heterogéneos, a menudo necesitas ejecutar un comando diferente dependiendo de si estás en Ubuntu o Rocky Linux. La directiva `when` evaluará el *Fact* del sistema operativo y decidirá si la tarea aplica o se omite (`skipped`).

### Crea el Playbook (`test-when-os.yml`)

```yaml
---
- hosts: all
  gather_facts: true # Necesario para saber si es Debian o RedHat

  tasks:
    - name: Tarea exclusiva para servidores Ubuntu (Familia Debian)
      ansible.builtin.debug:
        msg: "Soy un Ubuntu. Aquí usaría el comando 'apt'."
      when: ansible_facts['os_family'] == "Debian"

    - name: Tarea exclusiva para servidores Rocky Linux (Familia RedHat)
      ansible.builtin.debug:
        msg: "Soy un Rocky. Aquí usaría el comando 'dnf'."
      when: ansible_facts['os_family'] == "RedHat"

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-when-os.yml

```

```bash
TASK [Gathering Facts] *************************************************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Tarea exclusiva para servidores Ubuntu (Familia Debian)] *********************************************************
ok: [ubuntu-node1] => {
    "msg": "Soy un Ubuntu. Aquí usaría el comando 'apt'."
}
skipping: [rocky-node1]

TASK [Tarea exclusiva para servidores Rocky Linux (Familia RedHat)] ****************************************************
skipping: [ubuntu-node1]
ok: [rocky-node1] => {
    "msg": "Soy un Rocky. Aquí usaría el comando 'dnf'."
}

```

#### Lo que verás:

Ansible evaluará la condición en cada nodo. Cuando llegue a la primera tarea, el nodo de Rocky Linux no cumplirá la condición (`RedHat == Debian` es Falso), por lo que Ansible lo marcará en azul o cian con la palabra **`skipping`** (omitido) y no ejecutará nada en él, mientras que en Ubuntu sí lo ejecutará. En la segunda tarea ocurrirá exactamente lo contrario.

---

## 3. Ejercicio B: Condicionales numéricos y lógicos (`and` / `or`)

Puedes usar `when` para evaluar variables numéricas (como la cantidad de RAM) y combinarlas usando operadores lógicos como `and` (y) u `or` (o).

### Crea el Playbook (`test-when-logic.yml`)

```yaml
---
- hosts: all
  gather_facts: true

  vars:
    instalar_monitoreo: true

  tasks:
    - name: Instalar agente pesado de monitoreo
      ansible.builtin.debug:
        msg: "Instalando agente... El servidor tiene suficiente RAM y la variable lo permite."
      # Se ejecutará SOLO SI la variable es verdadera Y el servidor tiene más de 2000 MB de RAM
      when: 
        - instalar_monitoreo | bool
        - ansible_facts['memtotal_mb'] > 2000

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-when-logic.yml

```

```bash
TASK [Gathering Facts] *************************************************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Instalar agente pesado de monitoreo] *****************************************************************************
ok: [ubuntu-node1] => {
    "msg": "Instalando agente... El servidor tiene suficiente RAM y la variable lo permite."
}
ok: [rocky-node1] => {
    "msg": "Instalando agente... El servidor tiene suficiente RAM y la variable lo permite."
}

```

#### Lo que verás:

Al poner las condiciones como una lista (con guiones `-`), Ansible asume automáticamente que es un operador lógico **AND**. Ambas condiciones deben cumplirse. Si en tu laboratorio cambias la variable `instalar_monitoreo` a `false`, o si tuvieras un servidor muy pequeño con solo 1024 MB de RAM, la tarea sería omitida (`skipped`).

---

## 4. Ejercicio C: Condicionales basados en tareas anteriores (`register`)

A veces no puedes basar tu decisión en un *Fact* estático, sino en el resultado de una acción que acaba de ocurrir. Para esto usamos `register` (que guarda el resultado de una tarea) y luego evaluamos ese registro con `when`.

### Crea el Playbook (`test-when-register.yml`)

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Paso 1 - Verificar si existe un archivo de configuración crítico
      ansible.builtin.stat:
        path: /etc/ssh/sshd_config
      register: resultado_archivo

    - name: Paso 2 - Crear backup SOLO si el archivo existe
      ansible.builtin.debug:
        msg: "El archivo existe. Procediendo a crear un backup..."
      when: resultado_archivo.stat.exists == true

    - name: Paso 3 - Lanzar alerta SOLO si el archivo NO existe
      ansible.builtin.debug:
        msg: "¡ALERTA! El archivo de configuración ha desaparecido."
      when: not resultado_archivo.stat.exists

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-when-register.yml

```

```bash
TASK [Paso 1 - Verificar si existe un archivo de configuración crítico] ************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Paso 2 - Crear backup SOLO si el archivo existe] *****************************************************************
ok: [ubuntu-node1] => {
    "msg": "El archivo existe. Procediendo a crear un backup..."
}
ok: [rocky-node1] => {
    "msg": "El archivo existe. Procediendo a crear un backup..."
}

TASK [Paso 3 - Lanzar alerta SOLO si el archivo NO existe] *************************************************************
skipping: [ubuntu-node1]
skipping: [rocky-node1]

```

#### Lo que verás:

1. En el **Paso 1**, usamos el módulo `stat` (equivalente a correr `ls` o verificar si algo existe) en un archivo que sabemos que siempre está en Linux (`sshd_config`). El resultado se guardó en nuestra variable personalizada `resultado_archivo`.
2. En el **Paso 2**, evaluamos `resultado_archivo.stat.exists`. Como el archivo es real, la condición es verdadera y la tarea se ejecuta (`ok`).
3. En el **Paso 3**, usamos el operador inverso `not`. Como el archivo sí existe, la condición falla y la tarea se omite (`skipping`).

*Consejo adicional para la práctica:* Puedes cambiar la ruta `/etc/ssh/sshd_config` por una ruta inventada (como `/tmp/archivo_falso.txt`) y verás cómo el flujo se invierte mágicamente: el Paso 2 será omitido y la alerta del Paso 3 se ejecutará.
