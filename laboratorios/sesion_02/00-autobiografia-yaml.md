# Laboratorio 00: Autobiografía en YAML

Este laboratorio tiene como objetivo principal familiarizarte con las reglas de indentación, sintaxis, listas, mapas y escalares de YAML escribiendo tu propio perfil estructurado.

---

## 1. Objetivos del Laboratorio

* Practicar la creación de archivos con extensión `.yaml` / `.yml`.
* Aplicar de forma estricta las reglas de indentación sin utilizar tabulaciones.
* Crear y diferenciar variables de tipo escalar (texto, números, booleanos), mapas (diccionarios clave-valor) y secuencias (listas).
* Utilizar los operadores de texto multilínea (`|` y `>`) correctamente.
* Comprender y aplicar la anidación de estructuras complejas (listas de diccionarios).

---

## 2. Creacion de Autobiografia

### Paso 1: Crear el Archivo

Desde la terminal integrada, escribe el siguiente comando para que el editor abra un archivo nuevo:
```bash
touch autobiografia.yaml
```

### Paso 2: Escribir el Contenido
Copia y personaliza la siguiente plantilla con tus propios datos. Asegúrate de respetar los espacios en blanco:

```yaml
---
# Autobiografia en YAML
nombre: "Juan Perez"            # Escalar (Texto con comillas)
edad: 28                        # Escalar (Entero)
universidad: "UNI"              # Escalar (Texto)
estudiante_activo: true         # Escalar (Booleano)

contacto:                       # Estructura de Mapa (Diccionario)
  correo: "juan.perez@uni.pe"
  telefono: "987654321"
  ciudad: "Lima"

habilidades:                    # Estructura de Secuencia (Lista)
  - Linux
  - Git
  - Ansible
  - Docker

metas:                          # Mapa que contiene escalares
  corto_plazo: "Aprender automatizacion con Ansible"
  largo_plazo: "Implementar GitOps en mi entorno de trabajo"
# Fin del documento
```

> [!IMPORTANT]
> **Puntos Críticos de Revisión:**
> 1. Asegúrate de que los dos puntos `:` tengan un espacio en blanco después. La sintaxis correcta es `nombre: "Juan"`, no `nombre:"Juan"`.
> 2. Los elementos de la lista `habilidades` deben llevar un guion `-` alineado verticalmente.
> 3. No utilices la tecla `TAB`. Si tu editor inserta un carácter de tabulación, el archivo fallará en la validación. Usa la barra espaciadora.

---

### Validación de la Sintaxis

Para comprobar que tu archivo YAML es válido y no tiene errores estructurales, puedes usar el intérprete de Python instalado en tu sistema con una sola línea de comandos:

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('autobiografia.yaml'))"
```

* **Si no sale ningún mensaje:** ¡Excelente! Tu archivo es perfectamente válido.
* **Si muestra un error (`ParserError` / `ScannerError`):** Lee detalladamente la salida. Te indicará en qué línea y columna se encuentra el error de indentación o sintaxis para que puedas corregirlo.

## 3. Inventario de Servidor

### Paso 1: Crear el Archivo desde la Interfaz Gráfica
Desde la terminal integrada, escribe el siguiente comando para que el editor abra un archivo nuevo:
```bash
touch inventario_web.yaml
```

### Paso 2: Escribir el Contenido
Copia el siguiente bloque de código en tu editor de VS Code. Observa cómo el editor colorea automáticamente las claves, valores y listas para ayudarte a identificar la estructura:

```yaml
---
# Configuracion de Inventario de Servidores
entorno: "produccion"
version_despliegue: 2.4
mantenimiento_activo: false

# Lista de diccionarios (cada guion representa un servidor distinto)
servidores:
  - nombre: "web-01"
    direccion_ip: "192.168.10.11"
    sistema_operativo: "ubuntu"
    servicios:
      - nginx
      - php-fpm

  - nombre: "db-01"
    direccion_ip: "192.168.10.50"
    sistema_operativo: "rocky"
    servicios:
      - mariadb

# Bloque de texto literal (El caracter '|' respeta los saltos de linea)
mensaje_motd: |
  =========================================
  Bienvenido al entorno de produccion.
  Todo acceso no autorizado sera reportado.
  =========================================

# Bloque de texto plegado (El caracter '>' une las lineas en un solo parrafo)
politica_actualizacion: >
  Los servidores de base de datos solo deben
  reiniciarse durante la ventana de mantenimiento
  aprobada los fines de semana.
# Fin del documento
```

> [!IMPORTANT]
> **Puntos Críticos de Revisión:**
> 1. **Anidación de Listas y Mapas:** Nota que debajo de `servidores:`, el guion `-` indica el inicio de un nuevo elemento de la lista. VS Code dibujará líneas guía verticales para ayudarte a alinear correctamente las propiedades debajo de cada guion.
> 2. **Cadenas Multilínea:** El símbolo `|` (pipe) preserva los saltos de línea exactos (ideal para banners), mientras que el símbolo `>` (mayor que) convierte los saltos de línea en espacios simples, formando un solo párrafo.
> 3. VS Code está preconfigurado para insertar espacios en lugar de tabulaciones, pero asegúrate de mantener siempre **2 espacios por nivel** de indentación.

---

## 3. Validación de la Sintaxis

Para comprobar que tu archivo YAML es estructuralmente válido, asegúrate de haber guardado los cambios en el editor (`Ctrl + S`) y ejecuta el siguiente comando en la terminal integrada:

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('inventario_web.yaml'))"

```

* **Si la terminal no devuelve ningún mensaje y vuelve al prompt:** La validación ha sido exitosa. Has estructurado correctamente un archivo YAML avanzado.
* **Si muestra un error (`ParserError` / `ScannerError`):** Revisa cuidadosamente el panel del editor. VS Code podría estar marcando la línea conflictiva en rojo. Revisa especialmente la alineación de la lista bajo la clave `servidores`.

---

[Siguiente: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md)
