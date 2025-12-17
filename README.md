# Simulación de la Línea C del Subte de Buenos Aires

**Trabajo Final Integrador** para la materia **Sistemas de Tiempo Real**.

- [Informe](informe.pdf)
- [Simulación en NetLogo](simulacion.nlogox)
- [Datasets](datasets/)

Para compilar el informe, se debe ejecutar:

```bash
typst compile --root . --pdf-standard a-2u informe/main.typ informe.pdf
```

La parte de PDF A-2u es opcional. Se utilizó [Typst v0.14.2](https://github.com/typst/typst/releases/tag/v0.14.2).

## Datasets

Para procesar los datos se crearon scripts en Python, manejados con [uv](https://github.com/astral-sh/uv). Para regenerar los datasets procesados, se debe ejecutar:

```bash
cd datasets/
uv install      # Instala las dependencias
uv run main.py  # Procesa los datasets
```