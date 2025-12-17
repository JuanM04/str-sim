import chardet
import os
import pandas as pd
import requests
import sys
from tqdm import tqdm
import zipfile

DATASET_URL = "https://cdn.buenosaires.gob.ar/datosabiertos/datasets/sbase/subte-viajes-molinetes/molinetes-2024.zip"
INPUT_DIR = "molinetes-2024"
OUTPUT_DIR = "out"

dtype = {
    'FECHA': 'string',
    'DESDE': 'string',
    'HASTA': 'string',
    'LINEA': 'string',
    'MOLINETE': 'string',
    'ESTACION': 'string',
    'pax_pagos': 'UInt32',
    'pax_pases_pagos': 'UInt32',
    'pax_franq': 'UInt32',
    'pax_TOTAL': 'UInt32',
}

if not os.path.exists(INPUT_DIR):
    print(f"⬇️ Descargando dataset desde {DATASET_URL}...")
    filename = f"{INPUT_DIR}.zip"
    try:
        response = requests.get(DATASET_URL, stream=True)
        total_size = int(response.headers.get('content-length', 0))
        # unit='B': unit is bytes
        # unit_scale=True: automatically converts to KB, MB, GB
        with tqdm(total=total_size, unit='B', unit_scale=True, desc="Descargando") as bar:
            with open(filename, 'wb') as f:
                for chunk in response.iter_content(chunk_size=1024):
                    if chunk:
                        f.write(chunk)
                        bar.update(len(chunk))
        print(f"📂 Extracting to ./{INPUT_DIR}")
        with zipfile.ZipFile(filename, 'r') as zip_ref:
            zip_ref.extractall(INPUT_DIR)
        os.remove(filename)
        print(f"✅ Dataset descargado y extraído exitosamente!")
    except Exception as e:
        print(f"❌ Error al descargar o extraer el dataset: {e}")
        if os.path.exists(filename):
            os.remove(filename)
        sys.exit(1)
    try:
        print(f"🧹 Limpiando los CSV en ./{INPUT_DIR}...")
        files = [f for f in os.listdir(INPUT_DIR) if f.endswith('.csv')]
        if not files:
            print(f"❌ No se encontraron archivos .csv en ./{INPUT_DIR}")
            sys.exit(1)
        for filename in tqdm(files, desc="Limpiando"):
            file_path = os.path.join(INPUT_DIR, filename)
            content = None
            encoding = None
            with open(file_path, 'rb') as f:
                # Read the first 100KB; usually enough to guess
                rawdata = f.read(100000)
            encoding = chardet.detect(rawdata)['encoding']
            with open(file_path, 'r', encoding=encoding) as f:
                content = f.read()
            # Remove quotes introduced by GBA by some weird reason
            new_content = content.replace('"', '')
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
    except Exception as e:
        print(f"❌ Error al limpiar los archivos .csv: {e}")
        sys.exit(1)

print(f"🔄 Cargando dataset desde ./{INPUT_DIR}")
try:
    inputs = [
        f"./{INPUT_DIR}/202401_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202402_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202403_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202404_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202405_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202406_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202407_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202408_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202409_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202410_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202411_PAX15min-ABC.csv",
        f"./{INPUT_DIR}/202412_PAX15min-ABC-INCLUYEOTROMODOSDEPAGO.csv",
    ]
    dataframes = []
    for filename in tqdm(inputs, desc="Leyendo los CSV"):
        try:
            df = pd.read_csv(filename, sep=';', dtype=dtype, encoding="utf8")
            dataframes.append(df)
        except Exception as e:
            print(f"⚠️ Error leyendo {filename}: {e}")
            sys.exit(1)            
    df = pd.concat(dataframes, ignore_index=True)
    print(f"✅ Dataset cargado exitosamente!")
    print(f"📊 Dimensiones: {df.shape}")
    print(f"📋 Columnas: {list(df.columns)}")
except Exception as e:
    print(f"❌ Error al cargar: {e}")

def export_station_average_usage(df: pd.DataFrame, estacion_name: list[str], group_weekdays: bool = False, output_filename: str=None):
    """
    Generate a CSV with average usage for each 15-min window for a given station.

    Parameters:
    -----------
    df : pandas.DataFrame
        The full dataset
    estacion_name : str
        Name of the station to filter (e.g., 'Malabia', 'Flores')
    group_weekdays : bool, optional
        If True, groups weekdays together and weekends together. Default is False.
    output_filename : str, optional
        Output CSV filename. If None, uses '{estacion_name}_avg_usage.csv'

    Returns:
    --------
    pandas.DataFrame
        The aggregated data (also saved to CSV)
    """
    # Filter by station
    station_data = df[df['ESTACION'].isin(estacion_name)]

    if station_data.empty:
        raise ValueError(f"No data found for station: {estacion_name}")

    # Parse date column (format: d/m/yyyy)
    fecha_parsed = pd.to_datetime(station_data['FECHA'], format='%d/%m/%Y')

    # Create new columns with extracted month and day of week
    station_data = station_data.assign(
        fecha_parsed=fecha_parsed,
        month=fecha_parsed.dt.month,
        day_of_week=fecha_parsed.dt.day_name("es_AR.utf8")
    )

    avg_usage = None
    if group_weekdays:
        # Determine season (March-November=3-11, December-February=12,1,2) and weekday/weekend
        station_data = station_data.assign(
            category=station_data['day_of_week'].apply(
                lambda d: 'Weekend' if d == 'Sábado' or d == 'Domingo' else 'Weekday'
            ) + " " + station_data['month'].apply(
                lambda m: 'Mar-Nov' if 3 <= m <= 11 else 'Dic-Feb'
            )
        )
        # Compute mean for each group
        avg_usage = station_data.groupby(
            ['DESDE', 'HASTA', 'category'],
            as_index=False
        )['pax_TOTAL'].mean()
    else:
        # Determine season (March-November=3-11, December-February=12,1,2)
        station_data = station_data.assign(
            season=station_data['month'].apply(
                lambda m: 'Mar-Nov' if 3 <= m <= 11 else 'Dic-Feb'
            )
        )
        # Compute mean for each group
        avg_usage = station_data.groupby(
            ['DESDE', 'HASTA', 'season', 'day_of_week'],
            as_index=False
        )['pax_TOTAL'].mean()

    # Generate output filename if not provided
    if output_filename is None:
        # Clean station name for filename
        clean_name = estacion_name[0].strip().replace(' ', '_')
        output_filename = f'{clean_name}_avg_usage.csv'

    # Save to CSV
    avg_usage.to_csv(output_filename, index=False, header=False, sep=',')

    print(f"✓ Saved to: {output_filename}")
    print(f"✓ Records: {len(avg_usage)} time windows")
    print(f"✓ Total days analyzed: {station_data['FECHA'].nunique()}")

    return avg_usage

df = df[df['LINEA'] == 'LineaC']
export_station_average_usage(df, ['Constitucion'], group_weekdays=True, output_filename=f"./{OUTPUT_DIR}/Constitucion_avg_usage_grouped.csv")
export_station_average_usage(df, ['Constitucion'], group_weekdays=False, output_filename=f"./{OUTPUT_DIR}/Constitucion_avg_usage.csv")
export_station_average_usage(df, ['Retiro', 'Retiro.C'], group_weekdays=True, output_filename=f"./{OUTPUT_DIR}/Retiro_avg_usage_grouped.csv")
export_station_average_usage(df, ['Retiro', 'Retiro.C'], group_weekdays=False, output_filename=f"./{OUTPUT_DIR}/Retiro_avg_usage.csv")
