# Laboratorio 02: Dominando Loop Control (Ejercicios Individuales)

Este laboratorio tiene como objetivo principal comprender el funcionamiento y la personalización de los bucles en Ansible mediante el uso de la directiva `loop_control`.

Para facilitar el aprendizaje, **hemos separado cada parámetro en su propio archivo de Playbook**. De esta forma, podrás ejecutar y analizar cada concepto de forma aislada sin que las salidas de la terminal se mezclen.

---

## 1. Objetivos del Laboratorio

* Ejecutar tareas iterativas en un entorno multinodo heterogéneo (2 servidores Ubuntu y 2 servidores Rocky Linux).
* Cambiar el nombre de la variable iteradora por defecto (`item`) para mejorar la legibilidad.
* Limpiar la salida estándar de la consola ocultando datos sensibles o extensos.
* Utilizar contadores dinámicos para saber en qué iteración se encuentra el bucle.
* Aplicar pausas controladas entre cada ciclo del bucle.

---

## 2. Ejercicio A: Renombrar variables con `loop_var`

El parámetro `loop_var` nos permite cambiar el nombre genérico `item` por una palabra que tenga sentido para nuestro código.

### Crea el Playbook (`test-loop-var.yml`)

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Usar 'paquete' en lugar de 'item'
      ansible.builtin.debug:
        msg: "El servidor debe instalar: {{ paquete }}"
      loop:
        - htop
        - curl
      loop_control:
        loop_var: paquete

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-loop-var.yml

```

```bash
TASK [Usar 'paquete' en lugar de 'item'] *******************************************************************************
ok: [ubuntu-node1] => (item=htop) => {
    "msg": "El servidor debe instalar: htop"
}
ok: [ubuntu-node1] => (item=curl) => {
    "msg": "El servidor debe instalar: curl"
}
ok: [rocky-node1] => (item=htop) => {
    "msg": "El servidor debe instalar: htop"
}

```

#### Lo que verás:

Al escribir el código, en lugar de usar el genérico `{{ item }}`, utilizamos `{{ paquete }}` gracias a `loop_var: paquete`. Esto hace que el playbook sea mucho más fácil de leer y entender para otros administradores, evitando confusiones sobre todo si en el futuro decides anidar un bucle dentro de otro.

---

## 3. Ejercicio B: Limpiar la consola con `label`

El parámetro `label` nos permite controlar qué información se imprime en el resumen de cada iteración en la consola (la parte que dice `item=...`).

### Crea el Playbook (`test-loop-label.yml`)

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Ocultar los datos sensibles en la pantalla
      ansible.builtin.debug:
        msg: "Configurando acceso para el usuario: {{ item.usuario }}"
      loop:
        - { usuario: "admin", clave_secreta: "XYZ-987654321-SUPER-SECRETO" }
        - { usuario: "dev", clave_secreta: "ABC-123456789-SUPER-SECRETO" }
      loop_control:
        label: "{{ item.usuario }}"

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-loop-label.yml

```

```bash
TASK [Ocultar los datos sensibles en la pantalla] **********************************************************************
ok: [ubuntu-node1] => (item=admin) => {
    "msg": "Configurando acceso para el usuario: admin"
}
ok: [ubuntu-node1] => (item=dev) => {
    "msg": "Configurando acceso para el usuario: dev"
}
ok: [rocky-node1] => (item=admin) => {
    "msg": "Configurando acceso para el usuario: admin"
}

```

#### Lo que verás:

Fíjate en la etiqueta `(item=admin)`. Si no hubiéramos usado `label: "{{ item.usuario }}"`, Ansible habría impreso el diccionario completo `(item={'usuario': 'admin', 'clave_secreta': 'XYZ...'})` en la pantalla. El `label` resume visualmente qué vuelta se está ejecutando, ocultando las contraseñas largas y manteniendo tus logs seguros y limpios.

---

## 4. Ejercicio C: Contar iteraciones con `index_var`

El parámetro `index_var` crea automáticamente un contador numérico que inicia en 0 y suma 1 por cada vuelta que da el bucle.

### Crea el Playbook (`test-loop-index.yml`)

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Usar contadores numéricos
      ansible.builtin.debug:
        msg: "Procesando índice {{ indice }} para el área de {{ item }}"
      loop:
        - ventas
        - rrhh
      loop_control:
        index_var: indice

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-loop-index.yml

```

```bash
TASK [Usar contadores numéricos] ***************************************************************************************
ok: [ubuntu-node1] => (item=ventas) => {
    "msg": "Procesando índice 0 para el área de ventas"
}
ok: [ubuntu-node1] => (item=rrhh) => {
    "msg": "Procesando índice 1 para el área de rrhh"
}
ok: [rocky-node1] => (item=ventas) => {
    "msg": "Procesando índice 0 para el área de ventas"
}

```

#### Lo que verás:

Ansible automáticamente inicializó la variable `indice` en `0` durante la primera vuelta (ventas) y la aumentó a `1` en la segunda (rrhh). Esto es sumamente útil cuando necesitas generar nombres de archivos secuenciales (ej. `archivo_0.txt`, `archivo_1.txt`) o configurar interfaces de red, sin necesidad de recurrir a comandos de bash externos.

---

## 5. Ejercicio D: Controlar el tiempo con `pause`

El parámetro `pause` fuerza a Ansible a detener su ejecución durante una cantidad específica de segundos entre cada ciclo del bucle.

### Crea el Playbook (`test-loop-pause.yml`)

```yaml
---
- hosts: all
  gather_facts: false

  tasks:
    - name: Simular esperas lentas entre iteraciones
      ansible.builtin.debug:
        msg: "Reiniciando el servicio de {{ item }}..."
      loop:
        - base_de_datos
        - servidor_web
      loop_control:
        pause: 3

```

### Prueba Práctica y Visual

Ejecuta el playbook:

```bash
ansible-playbook test-loop-pause.yml

```

```bash
TASK [Simular esperas lentas entre iteraciones] ************************************************************************
ok: [ubuntu-node1] => (item=base_de_datos) => {
    "msg": "Reiniciando el servicio de base_de_datos..."
}
# ---> (AQUÍ NOTARÁS UNA PAUSA DE 3 SEGUNDOS EXACTOS EN TU TERMINAL) <---
ok: [ubuntu-node1] => (item=servidor_web) => {
    "msg": "Reiniciando el servicio de servidor_web..."
}

```

#### Lo que verás:

La ejecución no será instantánea. Verás el mensaje de `base_de_datos`, la terminal se quedará "congelada" durante exactamente 3 segundos, y luego aparecerá el mensaje de `servidor_web`. Esto es crucial en entornos de producción cuando interactúas con APIs que tienen límites de peticiones (rate limits) o cuando necesitas que un servicio termine de arrancar completamente antes de lanzar el siguiente.
