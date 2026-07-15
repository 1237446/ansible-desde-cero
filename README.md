# Ansible desde Cero: Automatiza Linux y Servidores
Aprende Ansible desde sus fundamentos teóricos, pasando por el lenguaje YAML y los comandos ad-hoc, hasta desplegar tu primer playbook automatizado e idempotente sobre un laboratorio multi-servidor en Docker.



### Ruta Rápida Del Programa
Un vistazo paso a paso de tu viaje de aprendizaje. Sigue el orden de estas etapas para dominar Ansible: desde la teoría básica y tus primeros comandos, hasta la creación de roles complejos y la gestión de seguridad. Haz clic en "Abrir" en cada etapa para ver el contenido detallado.
| Etapa | Enfoque | Resultado esperado | Ir |
|:---:|---|---|---|
| **1** | ¿Qué es Ansible y por qué automatizar? | Entender el funcionamiento del modelo *Push* por SSH y las ventajas de la filosofía declarativa. | [Abrir](./sesion/01-introduccion-ansible.md) |
| **2** | Introducción al lenguaje YAML | Escribir y estructurar variables, listas y mapas en formato YAML sin errores de indentación. | [Abrir](./sesion/02-playbook-yaml.md) |
| **3** | Preparación del entorno y laboratorio | Levantar una infraestructura multi-servidor interconectada con Docker Compose para realizar pruebas. | [Abrir](./sesion/03-preparacion-laboratorio.md) |
| **4** | Primeros pasos con comandos Ad-Hoc | Gestionar e inspeccionar servidores remotos en tiempo real mediante comandos rápidos de una línea. | [Abrir](./sesion/04-comandos-ad-hoc.md) |
| **5** | Desarrollo de tu primer Playbook | Escribir y ejecutar un playbook de despliegue para Nginx, asegurando que sea repetible e idempotente. | [Abrir](./sesion/05-primer-playbook.md) |
| **6** | Inventarios y automatización multi-servidor | Modelar una infraestructura con inventarios estáticos, ejecutar automatizaciones sobre varios grupos, instalar servicios en nodos separados y utilizar handlers para reiniciar servicios. | [Abrir](./sesion/07-inventarios-y-automatizacion-multiservidor.md) |
| **7** | Variables, Facts, Condicionales y Templates | Definir variables en el playbook, `group_vars/` y `host_vars/`, recopilar y utilizar facts, ejecutar tareas diferentes mediante condiciones `when`, repetir tareas con `loop` y generar archivos personalizados con templates Jinja2. | [Abrir](./sesion/07-inventarios-y-automatizacion-multiservidor.md) |
| **8** | Roles, Monitoreo, Seguridad y Backups | Crear roles reutilizables con `ansible-galaxy role init`, instalar Node Exporter, cifrar variables con Ansible Vault, auditar SSH y firewall, crear backups verificables y ejecutar un laboratorio integrador. | [Abrir](./sesion/07-inventarios-y-automatizacion-multiservidor.md) |



## Laboratorios
La mejor forma de aprender Ansible es practicando. En esta sección encontrarás todos los ejercicios guiados paso a paso para aplicar la teoría en un entorno real. Haz clic en "Abrir" para acceder a las instrucciones de cada reto.
| Laboratorio | Descripción | Ir |
|---|---|---|
| 01. Autobiografía YAML | Práctica guiada de estructuración, mapas, listas y formato en YAML. | [Abrir](./laboratorios/01-autobiografia-yaml.md) |
| 02. Comandos Ad-Hoc | Pruebas de conectividad y gestión remota rápida de servidores. | [Abrir](./laboratorios/02-comandos-ad-hoc.md) |
| 03. Despliegue de Nginx | Creación, ejecución y verificación de un playbook automatizado e idempotente. | [Abrir](./laboratorios/03-primer-playbook-nginx.md) |
| 04. Handlers | Uso de handlers para ejecutar tareas condicionales solo cuando hay cambios. | [Abrir](./laboratorios/04-handlers.md) |
| 05. Inventarios y Multi-Servidor | Despliegue multi-servidor con inventarios estáticos, plays separados y handlers para Nginx y MariaDB. | [Abrir](./laboratorios/05-inventarios-y-multiservidor.md) |
| 06. Variables, Facts y Templates | Despliegue multiplataforma con variables de grupo y host, facts descubiertos, condicionales `when`, bucles `loop` y templates Jinja2. | [Abrir](./laboratorios/06-variables-facts-templates.md) |
| 07. Roles, Vault y Laboratorio Final | Creación de roles reutilizables, uso de Ansible Vault para secretos, instalación de Node Exporter, auditoría de seguridad y backup verificable. | [Abrir](./laboratorios/07-roles-vault-y-laboratorio-final.md) |



## Material de Apoyo
A continuación tienes a tu disposición las diapositivas de cada sesión en formato PDF. Te recomiendo descargar estos recursos para repasar los conceptos teóricos y tenerlos a mano durante los laboratorios.
| Material | Descripción | Ir |
|:---:|---|---|
| **1** | PDF de la primera sesión  | [Abrir](./material/Sesion01.pdf) |
| **2** | PDF de la segunda sesión  | [Abrir](./material/Sesion02.pdf) |
| **3** | PDF de la tercera sesión  | [Abrir](./material/Sesion03.pdf) |
| **4** | PDF de la cuarta sesión   | [Abrir](./material/Sesion04.pdf) |
| **5** | PDF de la quinta sesión   | [Abrir](./material/Sesion05.pdf) |
| **6** | PDF de la sexta sesión    | [Abrir](./material/Sesion06.pdf) |
| **7** | PDF de todas las sesiones | [Abrir](./material/Programa_Completo_Ansible.pdf) |
