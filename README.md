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

## Simulaciones

Las simulaciones realizadas se encuentran en la carpeta [`simulaciones/`](simulaciones/). Cada subcarpeta se nombra según los parámetros utilizados en la simulación, como `lunes-3min-2vagones`, que indica una simulación para un lunes con trenes cada 3 minutos y formaciones de 2 vagones — la paciencia media de los pasajeros siempre es el doble de la frecuencia de los trenes (en este caso, 6 minutos).

Para exportar los datos de la simulación ágilmente, se puede utilizar el comando `exportar-datos-simulacion` en la interfaz de NetLogo, que exporta un archivo CSV con los datos de los monitores.