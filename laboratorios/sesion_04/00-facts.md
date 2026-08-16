# Laboratorio 00: Ansible Facts y Set Fact (Ejercicios Individuales)

Este laboratorio tiene como objetivo principal comprender cómo Ansible recopila información automática del sistema a través de los **Ansible Facts**, y cómo podemos crear o modificar nuestras propias variables al vuelo durante la ejecución utilizando el módulo **`set_fact`**.

---

## 1. Objetivos del Laboratorio

* Utilizar comandos **Ad-Hoc** para invocar el módulo `setup` y explorar el hardware y sistema operativo de los nodos.
* Utilizar los facts dentro de un Playbook para mostrar información específica de cada servidor.
* Crear variables personalizadas en tiempo de ejecución utilizando `set_fact`.
* Realizar cálculos dinámicos combinando los facts del sistema y `set_fact` para generar configuraciones a medida (ej. cálculo de memoria).

---

## 2. Ejercicio A: Explorando Facts con Comandos Ad-Hoc (Módulo `setup`)

Antes de escribir playbooks, la mejor forma de entender los "Facts" es usando comandos Ad-Hoc directamente en la terminal. El módulo `setup` es el encargado de conectarse a los servidores y devolver un diccionario JSON gigante con toda la información de la máquina.

### Prueba Práctica y Visual

Ejecuta el siguiente comando en tu terminal para consultar a todos los nodos:

```bash
ansible all -m setup

```

#### Lo que verás:

La terminal se llenará de texto en formato JSON. Esta es toda la información que Ansible descubre automáticamente. Dentro de ese gran bloque, busca las variables clave que listamos en nuestra tabla de referencia. Las encontrarás estructuradas bajo la llave principal `ansible_facts`:

* `"os_family": "Debian"` (o `RedHat`)
* `"distribution": "Ubuntu"` (o `Rocky`)
* `"distribution_version": "22.04"`
* `"hostname": "ubuntu-node1"`
* `"processor_vcpus": 4`
* `"memtotal_mb": 8192`

### Filtrando la salida del comando Ad-Hoc

Como la salida anterior es abrumadora, el módulo `setup` permite usar el argumento `filter` para buscar variables específicas. Prueba ejecutar estos comandos:

```bash
# Filtrar solo la información de la distribución del SO
ansible all -m setup -a "filter=ansible_distribution*"

# Filtrar solo la memoria total
ansible all -m setup -a "filter=ansible_memtotal_mb"

```

*Nota: Al usar el filtro en la terminal, Ansible busca usando el prefijo clásico `ansible_` (ej. `ansible_memtotal_mb`), aunque dentro de tus playbooks la buena práctica es llamarlos usando el formato de diccionario: `ansible_facts['memtotal_mb']`.*

---

## 3. Ejercicio B: Usando los Facts en un Playbook

Ahora que sabemos cómo se llaman las variables gracias al comando Ad-Hoc, vamos a consumirlas dentro de un Playbook activando la opción `gather_facts: true`.

### Crea el Playbook (`test-facts.yml`)

```yaml
---
- hosts: all
  gather_facts: true # ¡Crucial! Ejecuta el módulo setup automáticamente en segundo plano

  tasks:
    - name: Mostrar un reporte detallado del hardware y SO
      ansible.builtin.debug:
        msg: |
          --- Reporte de {{ ansible_facts['hostname'] }} ---
          Familia del SO : {{ ansible_facts['os_family'] }}
          Distribución   : {{ ansible_facts['distribution'] }}
          Versión del SO : {{ ansible_facts['distribution_version'] }}
          CPUs Virtuales : {{ ansible_facts['processor_vcpus'] }}
          Memoria Total  : {{ ansible_facts['memtotal_mb'] }} MB

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-facts.yml

```

```bash
TASK [Gathering Facts] *************************************************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]
# ...

TASK [Mostrar un reporte detallado del hardware y SO] ******************************************************************
ok: [ubuntu-node1] => {
    "msg": "---\nReporte de ubuntu-node1 ---\nFamilia del SO : Debian\nDistribución   : Ubuntu\nVersión del SO : 22.04\nCPUs Virtuales : 4\nMemoria Total  : 8192 MB"
}
ok: [rocky-node1] => {
    "msg": "---\nReporte de rocky-node1 ---\nFamilia del SO : RedHat\nDistribución   : Rocky\nVersión del SO : 9.2\nCPUs Virtuales : 4\nMemoria Total  : 8192 MB"
}

```

#### Lo que verás:

Primero verás una tarea automática llamada `Gathering Facts`. En ese momento, Ansible ejecuta silenciosamente el comando del Ejercicio A. Luego, la tarea de `debug` extrae exactamente las variables de nuestra tabla de referencia y las imprime formateadas.

---

## 4. Ejercicio C: Creación básica con `set_fact`

El módulo `set_fact` te permite inyectar nuevas variables durante la ejecución del playbook. Estas variables persistirán y estarán disponibles para todas las tareas que le sigan.

### Crea el Playbook (`test-set-fact-basic.yml`)

```yaml
---
- hosts: all
  gather_facts: false # No necesitamos facts del sistema para este ejercicio

  tasks:
    - name: Definir variables de entorno personalizadas
      ansible.builtin.set_fact:
        entorno_despliegue: "produccion"
        version_app: "v2.5.0"

    - name: Usar las variables creadas
      ansible.builtin.debug:
        msg: "Desplegando la versión {{ version_app }} en el entorno de {{ entorno_despliegue }}"

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-set-fact-basic.yml

```

```bash
TASK [Definir variables de entorno personalizadas] *********************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Usar las variables creadas] **************************************************************************************
ok: [ubuntu-node1] => {
    "msg": "Desplegando la versión v2.5.0 en el entorno de produccion"
}

```

#### Lo que verás:

La primera tarea (`set_fact`) no hace cambios en el sistema, solo guarda los datos en la memoria de Ansible de forma independiente para cada host. La segunda tarea consume esas variables para armar el mensaje.

---

## 5. Ejercicio D: El poder real (Facts + `set_fact` dinámico)

Aquí es donde ocurre la magia. Vamos a usar un **Fact** que descubrimos en el Ejercicio A (`memtotal_mb`) y el módulo **`set_fact`** para realizar una operación matemática al vuelo: asignarle el 70% de la RAM del servidor a una aplicación Java.

### Crea el Playbook (`test-set-fact-dynamic.yml`)

```yaml
---
- hosts: all
  gather_facts: true # Necesitamos los facts para saber la RAM de cada máquina

  tasks:
    - name: Calcular memoria disponible para la JVM (70% del total)
      ansible.builtin.set_fact:
        jvm_heap_mb: "{{ (ansible_facts['memtotal_mb'] * 0.7) | int }}"

    - name: Mostrar el comando de ejecución simulado
      ansible.builtin.debug:
        msg: "Ejecutando en {{ ansible_facts['hostname'] }}: java -Xmx{{ jvm_heap_mb }}m -jar mi_aplicacion.jar"

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-set-fact-dynamic.yml

```

```bash
TASK [Gathering Facts] *************************************************************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Calcular memoria disponible para la JVM (70% del total)] *********************************************************
ok: [ubuntu-node1]
ok: [rocky-node1]

TASK [Mostrar el comando de ejecución simulado] ************************************************************************
ok: [ubuntu-node1] => {
    "msg": "Ejecutando en ubuntu-node1: java -Xmx5734m -jar mi_aplicacion.jar"
}
ok: [rocky-node1] => {
    "msg": "Ejecutando en rocky-node1: java -Xmx5734m -jar mi_aplicacion.jar"
}

```

#### Lo que verás:

El código es exactamente el mismo para todos, pero `set_fact` evaluó la variable `ansible_facts['memtotal_mb']` de manera independiente para cada nodo, la multiplicó por 0.7, redondeó el número (`| int`) y guardó el resultado correcto. Si tus máquinas virtuales tienen distinta cantidad de RAM, el valor asignado a Java cambiará dinámicamente para cada una.
