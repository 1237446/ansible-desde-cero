# Laboratorio 01: group_vars/ y host_vars/

---

## 1. Objetivos del Laboratorio
Para entenderlo mejor, usaremos una analogía sencilla: **Las reglas de uniforme de una empresa**.

1. La regla de toda la empresa (`all`).
2. La regla de un departamento específico (`grupo`).
3. El permiso especial de un empleado (`host`).

## "Guerra de Jerarquías" en Ansible:

### Paso 1: Preparar el entorno

Crea una carpeta nueva y las dos carpetas base.

```bash
mkdir lab-jerarquia
cd lab-jerarquia
mkdir group_vars host_vars
```

## Paso 2: Crear un inventario con más estructura

Crea tu archivo **`inventory.ini`**. Vamos a dividir a nuestros servidores en dos grupos ("departamentos").

```ini
[ventas]
servidor_1
servidor_2

[marketing]
servidor_3

```

### Paso 3: Nivel 1 - La regla global (`all.yml`)

El archivo `all.yml` dentro de `group_vars` es especial. Lo que pongas aquí aplica a **absolutamente todos los servidores** del inventario, sin importar en qué grupo estén. Es la regla base.

Crea el archivo **`group_vars/all.yml`**:

```yaml
---
color_camiseta: "BLANCO (Regla global de la empresa)"

```

### Paso 4: Nivel 2 - La regla del grupo (`ventas.yml`)

Las variables de un grupo específico tienen mayor prioridad que `all.yml` y sobrescriben sus valores. Vamos a decir que el departamento de ventas tiene un color distinto.

Crea el archivo **`group_vars/ventas.yml`**:

```yaml
---
color_camiseta: "AZUL (Regla específica para el grupo ventas)"

```

> [!NOTE]
> No crearemos nada para el grupo de marketing, así que ellos tendrán que acatar la regla global).

### Paso 5: Nivel 3 - La regla individual (`host_vars/`)

El nivel más alto de autoridad lo tiene el host individual. Las variables definidas aquí aplastan tanto a las del grupo como a las globales. El `servidor_1` es el jefe de ventas y lleva otro color.

Crea el archivo **`host_vars/servidor_1.yml`**:

```yaml
---
color_camiseta: "ROJO (Permiso especial solo para servidor_1)"

```

### Paso 6: Ver la magia de la precedencia en acción

Ejecuta el comando de auditoría para ver cómo Ansible resolvió esta pelea de variables:

```bash
ansible-inventory -i inventory.ini --list

```

#### Analizando el resultado didáctico:

Fíjate en la sección `_meta.hostvars` del JSON que te devuelve la terminal. Verás exactamente cómo Ansible aplicó la jerarquía:

```json
    "_meta": {
        "hostvars": {
            "servidor_1": {
                "color_camiseta": "ROJO (Permiso especial solo para servidor_1)"
            },
            "servidor_2": {
                "color_camiseta": "AZUL (Regla específica para el grupo ventas)"
            },
            "servidor_3": {
                "color_camiseta": "BLANCO (Regla global de la empresa)"
            }
        }
    }
```

## El Resumen de la Jerarquía (Precedencia)

Ansible siempre se pregunta: *"¿De qué color es la camiseta de este servidor?"* y busca la respuesta en este orden exacto (de menor a mayor importancia):

1. **`servidor_3` (Marketing):** Ansible no encontró archivo en `host_vars`, no encontró archivo en `group_vars/marketing.yml`, así que retrocedió hasta `group_vars/all.yml`. **Resultado: BLANCO.**
2. **`servidor_2` (Ventas):** Ansible no encontró archivo en `host_vars`, pero SÍ encontró `group_vars/ventas.yml`. Esta regla aplastó a `all.yml`. **Resultado: AZUL.**
3. **`servidor_1` (Ventas):** Ansible encontró directamente el archivo `host_vars/servidor_1.yml`. Al encontrarlo, dejó de importarle lo que dijera su grupo o la regla global. **Resultado: ROJO.**
