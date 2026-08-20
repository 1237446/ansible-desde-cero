# Laboratorio 01: Forks y Serials

Este laboratorio tiene como objetivo principal comprender el funcionamiento de la concurrencia y la ejecución por lotes en Ansible mediante el uso de la directiva `serial` y el parámetro de control de paralelismo `forks`.

---

## 1. Objetivos del Laboratorio

* Levantar un entorno multinodo heterogéneo de prueba (3 servidores Ubuntu y 3 servidores RHEL).
* Comparar visualmente la ejecución en paralelo masiva frente a la ejecución controlada por lotes (`serial`).
* Analizar cómo el parámetro de hilos concurrentes (`forks`) limita o permite la ejecución simultánea de las tareas dentro de un lote.

---

## 2. Crea un Playbook de prueba (`test-concurrency.yml`)

Este playbook aplicará a todos los hosts del grupo `all` e incluirá una pausa de 5 segundos para evidenciar el orden de procesamiento.

```yaml
---
- hosts: all
  serial: 3
  gather_facts: false

  tasks:
    - name: Ejecutar comando en el nodo y obtener la hora exacta
      ansible.builtin.shell: "sleep 2 && date +%H:%M:%S"
      register: hora_remota

    - name: Mostrar hora de finalización en cada host
      ansible.builtin.debug:
        msg: "El host {{ inventory_hostname }} terminó a las: {{ hora_remota.stdout }}"
```

---

## 3. Pruebas Prácticas y Visuales de Forks y Serials

### Prueba A: Ejecución por defecto con el Serial configurado (`serial: 3`)

Ejecuta el playbook utilizando tu inventario dinámico:

```bash
ansible-playbook test-concurrency.yml
```

```bash

PLAY [all] *************************************************************************************************************

TASK [Ejecutar comando en el nodo y obtener la hora exacta] ************************************************************
changed: [ubuntu-node2]
changed: [ubuntu-node1]
changed: [ubuntu-node3]

TASK [Mostrar hora de finalización en cada host] ***********************************************************************
ok: [ubuntu-node1] => {
    "msg": "El host ubuntu-node1 terminó a las: 00:50:10"
}
ok: [ubuntu-node2] => {
    "msg": "El host ubuntu-node2 terminó a las: 00:50:10"
}
ok: [ubuntu-node3] => {
    "msg": "El host ubuntu-node3 terminó a las: 00:50:10"
}

PLAY [all] *************************************************************************************************************

TASK [Ejecutar comando en el nodo y obtener la hora exacta] ************************************************************
changed: [rhel-node2]
changed: [rhel-node3]
changed: [rhel-node1]

TASK [Mostrar hora de finalización en cada host] ***********************************************************************
ok: [rhel-node1] => {
    "msg": "El host rhel-node1 terminó a las: 00:50:14"
}
ok: [rhel-node2] => {
    "msg": "El host rhel-node2 terminó a las: 00:50:14"
}
ok: [rhel-node3] => {
    "msg": "El host rhel-node3 terminó a las: 00:50:14"
}

PLAY RECAP *************************************************************************************************************
rhel-node1                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node2                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node3                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node1               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node2               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node3               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### Lo que verás:
Como el lote es de 3 (serial: 3) y tienes varios forks permitidos por defecto:

* Los 3 servidores Ubuntu ejecutarán el `sleep 4` al mismo tiempo.

Resultado visual: Los 3 servidores Ubuntu mostrarán exactamente la misma hora en la salida del debug (por ejemplo, `00:50:10`).

---

### Prueba B: Modificando el paralelismo global con Forks (`-f 1`)

Mantén el `serial: 3` en tu playbook, pero fuerza un límite estricto de 1 solo proceso concurrente desde la terminal usando la bandera `-f`:

```bash
ansible-playbook test-concurrency.yml -f 1
```

```bash
PLAY [all] *************************************************************************************************************

TASK [Ejecutar comando en el nodo y obtener la hora exacta] ************************************************************
changed: [ubuntu-node1]
changed: [ubuntu-node2]
changed: [ubuntu-node3]

TASK [Mostrar hora de finalización en cada host] ***********************************************************************
ok: [ubuntu-node1] => {
    "msg": "El host ubuntu-node1 terminó a las: 00:50:30"
}
ok: [ubuntu-node2] => {
    "msg": "El host ubuntu-node2 terminó a las: 00:50:33"
}
ok: [ubuntu-node3] => {
    "msg": "El host ubuntu-node3 terminó a las: 00:50:36"
}

PLAY [all] *************************************************************************************************************

TASK [Ejecutar comando en el nodo y obtener la hora exacta] ************************************************************
changed: [rhel-node1]
changed: [rhel-node2]
changed: [rhel-node3]

TASK [Mostrar hora de finalización en cada host] ***********************************************************************
ok: [rhel-node1] => {
    "msg": "El host rhel-node1 terminó a las: 00:50:39"
}
ok: [rhel-node2] => {
    "msg": "El host rhel-node2 terminó a las: 00:50:42"
}
ok: [rhel-node3] => {
    "msg": "El host rhel-node3 terminó a las: 00:50:45"
}

PLAY RECAP *************************************************************************************************************
rhel-node1                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node2                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node3                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node1               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node2               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node3               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### Lo que verás:
Aunque el lote sigue siendo de 3 (serial: 3), la bandera -f 1 obliga a Ansible a procesar 1 solo servidor a la vez:

* `ubuntu-node1` ejecuta el `sleep 3` y termina (ej. `00:50:30`).
* Luego `ubuntu-node2` ejecuta el `sleep 3` y termina (ej. `00:50:33`).
* Luego `ubuntu-node3` ejecuta el `sleep 3` y termina (ej. `00:50:36`).

Resultado visual: Cada host del lote mostrará una hora de finalización escalonada con 3 segundos de diferencia entre sí.

---

### Prueba C: Ampliando los Forks para una ejecución masiva (`-f 10`)

Modifica temporalmente tu playbook cambiando la línea `serial: 3` a `serial: 6` (o elimínala por completo para que abarque a todos los hosts de un solo golpe) y ejecuta con un alto número de forks:

```bash
ansible-playbook -i inventory.py test-concurrency.yml -f 10
```

```bash
PLAY [all] *************************************************************************************************************

TASK [Ejecutar comando en el nodo y obtener la hora exacta] ************************************************************
changed: [rhel-node3]
changed: [rhel-node2]
changed: [ubuntu-node2]
changed: [ubuntu-node1]
changed: [ubuntu-node3]
changed: [rhel-node1]

TASK [Mostrar hora de finalización en cada host] ***********************************************************************
ok: [ubuntu-node1] => {
    "msg": "El host ubuntu-node1 terminó a las: 00:52:21"
}
ok: [ubuntu-node2] => {
    "msg": "El host ubuntu-node2 terminó a las: 00:52:21"
}
ok: [ubuntu-node3] => {
    "msg": "El host ubuntu-node3 terminó a las: 00:52:21"
}
ok: [rhel-node2] => {
    "msg": "El host rhel-node2 terminó a las: 00:52:21"
}
ok: [rhel-node1] => {
    "msg": "El host rhel-node1 terminó a las: 00:52:21"
}
ok: [rhel-node3] => {
    "msg": "El host rhel-node3 terminó a las: 00:52:21"
}

PLAY RECAP *************************************************************************************************************
rhel-node1                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node2                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel-node3                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node1               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node2               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-node3               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

* **Qué observarás visualmente:**
* Los 6 contenedores (`ubuntu1`, `ubuntu2`, `ubuntu3`, `rhel1`, `rhel2`, `rhel3`) ejecutarán la tarea de forma totalmente masiva y en paralelo al mismo tiempo.
