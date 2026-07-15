# Laboratorio 01: Autobiografía en YAML

Este laboratorio tiene como objetivo principal familiarizarte con las reglas de indentación, sintaxis, listas, mapas y escalares de YAML escribiendo tu propio perfil estructurado.

---

## 1. Objetivos del Laboratorio

* Practicar la creación de archivos con extensión `.yaml` / `.yml`.
* Aplicar de forma estricta las reglas de indentación sin utilizar tabulaciones.
* Crear y diferenciar variables de tipo escalar (texto, números, booleanos), mapas (diccionarios clave-valor) y secuencias (listas).

---

## 2. Instrucciones Paso a Paso

### Paso 1: Crear la Carpeta de Prácticas
Dentro de la terminal de tu máquina virtual o en tu terminal local, crea una carpeta aislada para tus prácticas de YAML:
```bash
mkdir -p ~/sesion01-yaml
cd ~/sesion01-yaml
```

### Paso 2: Crear el Archivo de Autobiografía
Crea un archivo llamado `autobiografia.yaml` usando tu editor de texto favorito (ej. `nano`, `vi` o VS Code):
```bash
nano autobiografia.yaml
```

### Paso 3: Escribir el Contenido
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

## 3. Validación de la Sintaxis

Para comprobar que tu archivo YAML es válido y no tiene errores estructurales, puedes usar el intérprete de Python instalado en tu sistema con una sola línea de comandos:

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('autobiografia.yaml'))"
```

* **Si no sale ningún mensaje:** ¡Excelente! Tu archivo es perfectamente válido.
* **Si muestra un error (`ParserError` / `ScannerError`):** Lee detalladamente la salida. Te indicará en qué línea y columna se encuentra el error de indentación o sintaxis para que puedas corregirlo.

---

[Siguiente: Laboratorio 02 - Comandos Ad-Hoc](./02-comandos-ad-hoc.md)
