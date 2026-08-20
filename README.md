<div align="center">

# 🚀 Ansible desde Cero: Automatiza Linux y Servidores

*Aprende Ansible desde sus fundamentos teóricos, pasando por el lenguaje YAML y los comandos ad-hoc, hasta desplegar tu primer playbook automatizado e idempotente sobre un laboratorio multi-servidor en Docker.*

![Docker](https://img.shields.io/badge/Docker-Compose_v2-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-2.16+-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-9-10B981?style=for-the-badge&logo=rockylinux&logoColor=white)
![VS Code](https://img.shields.io/badge/VS_Code-code--server-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)

</div>

---

## 🗺️ Ruta Rápida Del Programa

Un vistazo paso a paso de tu viaje de aprendizaje. Sigue el orden de estas etapas para dominar Ansible: desde la teoría básica y tus primeros comandos, hasta la creación de orquestaciones complejas y plantillas dinámicas.

| 🗓️ Sesión | 📖 Tema Principal | 🎯 Resultado Esperado | 🔗 Enlace |
| :---: | :--- | :--- | :---: |
| **01** | **Primeros pasos y comandos Ad-Hoc** | Entender la arquitectura *Agentless* por SSH, configurar el entorno y ejecutar comandos de diagnóstico en múltiples nodos. | [Abrir](./clases/sesion_1.md) |
| **02** | **Primer playbook y despliegue de Nginx** | Escribir y estructurar variables, listas y mapas en formato YAML para lograr automatizaciones idempotentes y libres de errores. | [Abrir](./clases/sesion_2.md) |
| **03** | **Inventarios y Automatización Multiservidor** | Orquestar múltiples roles (Web/DB) usando inventarios dinámicos, control de paralelismo y *handlers* eficientes. | [Abrir](./clases/sesion_3.md) |
| **04** | **Variables, Facts, Condicionales y Templates** | Crear playbooks inteligentes que tomen decisiones basadas en variables del sistema y utilicen motores de plantillas Jinja2. | [Abrir](./clases) |

---

## 💻 Laboratorios Prácticos

La mejor forma de asimilar la automatización es practicando. En esta sección encontrarás los ejercicios guiados paso a paso para aplicar la teoría en tu propio entorno aislado. 

*(Haz clic en cada sesión para desplegar sus laboratorios)*

<details open>
<summary><b>🟢 Sesión 1: Primeros pasos y comandos Ad-Hoc</b></summary>
<br>

| Laboratorio | Descripción | Enlace |
| :--- | :--- | :---: |
| **01. Instalación de Docker** | Despliegue y configuración inicial del motor de contenedores en el host. | [🚀 Ir](./laboratorios/sesion_01/00-instalacion-de-docker.md) |
| **02. Preparación de Laboratorio** | Levantamiento de la infraestructura multi-nodo aislada con Docker Compose. | [🚀 Ir](./laboratorios/sesion_01/01-preparacion-del-laboratorio.md) |
| **03. Comandos AD-HOC** | Ejecución de tareas rápidas (ping, comandos, paquetes) sin usar playbooks. | [🚀 Ir](./laboratorios/sesion_01/02-comandos-ad-hoc.md) |

</details>

<details>
<summary><b>🔵 Sesión 2: Primer playbook y despliegue de Nginx</b></summary>
<br>

| Laboratorio | Descripción | Enlace |
| :--- | :--- | :---: |
| **01. Autobiografía en YAML** | Ejercicio práctico para dominar la indentación, sintaxis y estructura de YAML. | [🚀 Ir](./laboratorios/sesion_02/00-autobiografia-yaml.md) |
| **02. Primer Playbook de Nginx** | Automatización declarativa e idempotente de un servidor web desde cero. | [🚀 Ir](./laboratorios/sesion_02/01-primer-playbook-nginx.md) |
| **03. Errores y Depuración** | Simulación de fallos comunes y uso de herramientas de *troubleshooting*. | [🚀 Ir](./laboratorios/sesion_02/02-errores-y-depuracion.md) |

</details>

<details>
<summary><b>🟠 Sesión 3: Inventarios y Automatización Multiservidor</b></summary>
<br>

| Laboratorio | Descripción | Enlace |
| :--- | :--- | :---: |
| **01. Inventarios Dinámicos** | Consultar recursos en tiempo real en entornos elásticos y orquestadores. | [🚀 Ir](./laboratorios/sesion_03/01-inventarios-dinamicos.md) |
| **02. Group_vars y Host_vars** | Organización profesional de variables separadas de la lógica del playbook. | [🚀 Ir](./laboratorios/sesion_03/02-group-host-vars.md) |
| **03. Forks y Serials** | Control avanzado de paralelismo y despliegues progresivos por lotes. | [🚀 Ir](./laboratorios/sesion_03/03-forks-y-serials.md) |
| **04. Handlers (Manejadores)** | Configuración de tareas reactivas para reiniciar servicios solo tras cambios reales. | [🚀 Ir](./laboratorios/sesion_03/04-handlers.md) |

</details>

<details>
<summary><b>🟣 Sesión 4: Variables, Facts, Condicionales y Templates</b></summary>
<br>

| Laboratorio | Descripción | Enlace |
| :--- | :--- | :---: |
| **01. Facts (Valores descubiertos)** | Recopilación y uso de información intrínseca del sistema operativo destino. | [🚀 Ir](./laboratorios/sesion_04/01-facts.md) |
| **02. When (Condicionales)** | Ejecución selectiva de tareas basada en arquitectura lógica o sistema operativo. | [🚀 Ir](./laboratorios/sesion_04/02-condicionales-when.md) |
| **03. Loops (Bucles)** | Reducción de código mediante la iteración para crear múltiples usuarios o paquetes. | [🚀 Ir](./laboratorios/sesion_04/03-loops.md) |
| **04. Templates (Plantillas Jinja2)** | Inyección de variables en archivos de configuración generados dinámicamente. | [🚀 Ir](./laboratorios/sesion_04/04-templates.md) |

</details>

---

## 📚 Material de Apoyo

A continuación tienes a tu disposición las diapositivas de cada sesión en formato PDF. Te recomiendo descargar estos recursos para repasar los conceptos teóricos y tenerlos a mano durante los laboratorios.

| 📄 Documento | Descripción | Descarga |
| :--- | :--- | :---: |
| **Presentación Sesión 1** | Arquitectura SSH, Modelo Push y Fundamentos Agentless. | [📥 Bajar](./diapositivas/Automatización_con_Ansible_1.pdf) |
| **Presentación Sesión 2** | Lenguaje YAML, Estructura de Playbooks e Idempotencia. | [📥 Bajar](./diapositivas/Automatización_con_Ansible_2.pdf) |
| **Presentación Sesión 3** | Automatización Multiservidor, Variables y Manejadores. | [📥 Bajar](./diapositivas/Automatización_con_Ansible_3.pdf) |

<br>
<div align="center">
  <i>Construido para la comunidad de <b>Cursos PIT - Transformación Digital OTI UNI</b></i>
</div>
