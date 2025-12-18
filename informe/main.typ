#import "@preview/barcala:0.3.0": apendice, informe
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.10": codly-languages
#import "@preview/fletcher:0.5.8"
#import "@preview/lilaq:0.5.0" as lq // Paquete para gráficos, puede ser omitido
#import "@preview/physica:0.9.6": * // Paquete para matemática y física, puede ser omitido
#import "@preview/zero:0.5.0" // Paquete para números lindos y unidades de medida, puede ser omitido

#show: informe.with(
  unidad-academica: "informática",
  asignatura: "I115 Sistemas de Tiempo Real",
  trabajo: "Trabajo de simulación",
  equipo: "Grupo 3",
  autores: (
    (
      nombre: "Bejarano, Abril",
      email: "abril.bejarano@alu.ing.unlp.edu.ar",
      legajo: "03339/5",
    ),
    (
      nombre: "Majoros, Lorenzo",
      email: "lorenzomajoros@alu.ing.unlp.edu.ar",
      legajo: "03296/1",
    ),
    (
      nombre: "Seery, Juan Martín",
      email: "juan.seery@alu.ing.unlp.edu.ar",
      legajo: "03471/9",
      notas: "Autor responsable del informe",
    ),
    (
      nombre: "Seijo, Gerónimo",
      email: "seijo.geronimo@alu.ing.unlp.edu.ar",
      legajo: "01859/7",
    ),
  ),

  titulo: [Simulación de la Línea C del Subte de Buenos Aires entre sus estaciones terminales],
  resumen: strong[
    _Resumen_ --- La Ciudad Autónoma de Buenos Aires cuenta con uno de los sistemas de trenes subterráneos más importantes de América: el Subte de Buenos Aires. El mismo es utilizado por millones de pasajeros diariamente para movilizarse por la ciudad. En particular, la Línea C del Subte conecta dos estaciones cabeceras que permiten la interconexión con los ferrocarriles metropolitanos, resultando en un punto neurálgico para el transporte público. En este trabajo, se desarrolla un modelo basado en agentes para simular la dinámica entre los pasajeros que llegan desde los ferrocarriles metropolitanos y la frecuencia de los trenes subterráneos en la Línea C. El modelo permite analizar distintas configuraciones del sistema y optimizar la frecuencia de los trenes para mejorar el servicio ofrecido a los usuarios.
  ],

  fecha: "2025-12-17",
)

// Enlaces de colores
#show cite: set text(blue)
#show link: set text(blue)
#show ref: set text(blue)

// Bloques de matemática con números para citar
#set math.equation(numbering: "(1)")
#show ref: it => {
  if it.element != none and it.element.func() == math.equation {
    // Sobreescribir las referencias a ecuaciones
    link(it.element.location(), numbering(
      it.element.numbering,
      ..counter(math.equation).at(it.element.location()),
    ))
  } else {
    // Otras referencias quedan igual
    it
  }
}

// NetLogo
#set raw(syntaxes: "netlogo.yaml", lang: "NetLogo")
#let xfind(list, ..queries) = {
  queries = queries.pos()
  let v = list.find(e => {
    let q = queries.at(0)
    let q = if type(q) == str { (__tag: q) } else { (:..q) }
    let tag = q.remove("__tag", default: none)
    if tag != none and not ("tag" in e and e.tag == tag) {
      return false
    }
    for (key, value) in q {
      if not (key in e.attrs and e.attrs.at(key) == value) {
        return false
      }
    }
    return true
  })
  if queries.len() > 1 and v != none {
    xfind(v.children, ..queries.slice(1))
  } else {
    v
  }
}
#let source = xfind(xml("../simulacion.nlogox"), "model", "code").children.at(0)

// Configuración de `codly`
#show: codly-init.with()
#codly(
  languages: codly-languages,
  display-name: false,
  display-icon: false,
)

// Configuración de `zero`
#import zero: num, zi
#zero.set-num(
  decimal-separator: ",",
)
#zero.set-group(
  size: 3,
  separator: ".",
  threshold: (integer: 5, fractional: calc.inf),
)
#zero.set-unit(
  fraction: "inline",
)

// Unidades
#let Vm = zi.declare("V/m")
#let ms2 = zi.declare("m/s^2")

#outline()

#pagebreak()
= Introducción

El Subte de Buenos Aires es un sistema de trenes subterráneos ubicado debajo de las calles de la Ciudad Autónoma de Buenos Aires. El sistema resulta de gran importancia para los porteños, contabilizando poco más de 199 millones de pasajeros en 2024 @dataset_pasajeros.

En particular, la Línea C resulta de particular importancia al realizar un recorrido troncal a través la red, como se aprecia en la @fig-mapa. La misma registró al rededor de 31 millones de pasajeros en 2024 @dataset_pasajeros y conecta dos estaciones de los ferrocarriles metropolitanos de Buenos Aires: Retiro (de donde parten las líneas Mitre, Belgrano Norte y San Martín hacia el norte) y Plaza Constitución (de donde parte la línea Roca hacia el sur). La coordinación entre estos sistemas de movilidad es fundamental para que los usuarios puedan trasladarse de manera consistente, predecible y veloz.
#figure(
  image("imagenes/mapa_subte.png"),
  caption: [Mapa esquemáticos de las calles de red del Subte de Buenos Aires (obra de Emova).],
) <fig-mapa>

En este trabajo, se estudia la Línea C entre sus estaciones terminales y se analizan las dinámicas entre los pasajeros que llegan desde los ferrocarriles metropolitanos y la frecuencia de los trenes subterráneos. Resulta importante este estudio porque permite optimizar los recursos del Subte para mejorar su servicio.

#pagebreak()
= Marco teórico

Para que el estudio sea lo más verídico posible, se utilizaron datos de uso de los molinetes en el año 2024 @dataset_molinetes. Luego de analizar los datos en las estaciones de Retiro (@fig-pasajeros-retiro) y Constitución (@fig-pasajeros-constitucion), se decidió centrarse únicamente en un uso "normal" de la red --- esto es, entre los meses de marzo y noviembre inclusive para evitar fluctuaciones debido a los meses de calor y fiestas/vacaciones.

#figure(
  {
    let data = csv("../datasets/out/Retiro_avg_usage_grouped.csv")
    let data = data.filter(
      d => not (d.at(0).starts-with("00")) and not (d.at(0).starts-with("01")),
    )
    let dtf(desde) = {
      let (h, m, s) = desde.split(":")
      return int(h) + int(m) / 60 + int(s) / 3600
    }

    lq.diagram(
      width: 16cm,
      xlabel: [Hora del día],
      ylabel: [Pasajeros],
      xaxis: (
        ticks: data
          .map(d => dtf(d.at(0)))
          .dedup()
          .map(d => (
            d,
            if calc.rem(d, 1) == 0 { str(d) } else { "" },
          )),
        subticks: none,
      ),
      lq.plot(
        data.filter(d => d.at(2) == "Weekday Mar-Nov").map(d => dtf(d.at(0))),
        data.filter(d => d.at(2) == "Weekday Mar-Nov").map(d => float(d.at(3))),
        label: [Día de semana],
      ),
      lq.plot(
        data.filter(d => d.at(2) == "Weekend Mar-Nov").map(d => dtf(d.at(0))),
        data.filter(d => d.at(2) == "Weekend Mar-Nov").map(d => float(d.at(3))),
        label: [Fin de semana],
      ),
    )
  },
  caption: [Histograma de pasajeros en la estación de Retiro. Cada punto representa el flujo de personas a lo largo de los 15 minutos siguientes. Limitado entre marzo y noviembre de 2024.],
) <fig-pasajeros-retiro>


#figure(
  {
    let data = csv("../datasets/out/Constitucion_avg_usage_grouped.csv")
    let data = data.filter(
      d => not (d.at(0).starts-with("00")) and not (d.at(0).starts-with("01")),
    )
    let dtf(desde) = {
      let (h, m, s) = desde.split(":")
      return int(h) + int(m) / 60 + int(s) / 3600
    }

    lq.diagram(
      width: 16cm,
      xlabel: [Hora del día],
      ylabel: [Pasajeros],
      xaxis: (
        ticks: data
          .map(d => dtf(d.at(0)))
          .dedup()
          .map(d => (
            d,
            if calc.rem(d, 1) == 0 { str(d) } else { "" },
          )),
        subticks: none,
      ),
      lq.plot(
        data.filter(d => d.at(2) == "Weekday Mar-Nov").map(d => dtf(d.at(0))),
        data.filter(d => d.at(2) == "Weekday Mar-Nov").map(d => float(d.at(3))),
        label: [Día de semana],
      ),
      lq.plot(
        data.filter(d => d.at(2) == "Weekend Mar-Nov").map(d => dtf(d.at(0))),
        data.filter(d => d.at(2) == "Weekend Mar-Nov").map(d => float(d.at(3))),
        label: [Fin de semana],
      ),
    )
  },
  caption: [Histograma de pasajeros en la estación de Constitución. Cada punto representa el flujo de personas a lo largo de los 15 minutos siguientes. Limitado entre marzo y noviembre de 2024.],
) <fig-pasajeros-constitucion>

Dentro del horario "normal", se agruparon los datos en dos curvas. Por un lado, los "días de semana", lunes a viernes, caracterizado por el uso de los trabajadores que se mueven desde el Gran Buenos Aires hacia la ciudad a la mañana y vuelven a sus hogares a la tarde. Por otro lado, el "fin de semana", caracterizado por la recreación.

== Modelo basado en agentes

Con los datos obtenidos, se desarrolló un modelo de la Línea C del Subte de Buenos Aires. Particularmente, se sintetizó un modelo basado en agentes.

Los modelos tradicionales se basan en una descripción matemática de la realidad. Estos son limitados por las herramientas matemáticas disponibles, como las ecuaciones diferenciales. Cuando el sistema es muy complejo, las ecuaciones diferenciales pueden resultar limitantes o requerir mucho cálculo para resolverlas. Por ello, los sistemas suelen simplificarse en sistemas lineales para ser útiles.

En cambio, los modelos computaciones aprovechan que las computadoras pueden realizar numerosas operaciones matemáticas simples en muy poco tiempo, habilitando obtener resultados valiosos de modelos no lineales. Un tipo de modelo computacional son los *modelos basados en agentes* (ABM, por sus siglas en inglés, _Agent-based model_) @Railsback2019[p.~10]. Lo particular de este tipo de modelos es que no se modela el sistema sí, sino que se pone énfasis en cada componente individual (cada _agente_). Cada agente cuenta con sus propias variables internas y un comportamiento predefinido con cada otro agente y con el _entorno_. Cada agente debe ser descrito según sus *propiedades* (variables internas) y sus *acciones* (o comportamiento con otros agentes y su entorno) @Wilensky2015[p.~205].

Este marco teórico resulta conveniente, ya que permite modelar a cada agente de manera individual sin saber el comportamiento del sistema como un todo. Para el caso del Subte, donde se desconocen estas dinámicas de antemano, se justifica el uso de este tipo de modelado.

#pagebreak()

= Metodología

Para estudiar la Línea C se desarroló un ABM que permite aprovechar las capacidades computacionales para simular distintos escenarios.

== Descripción del modelo

El modelo consta de dos agentes móviles: *persona*, que describe a un usuario del sistema y *tren* que describe una formación de vagones del Subte. Los mismos existen en la Línea C del Subte (su entorno), graficado en la @fig-fondo.

#figure(
  image("imagenes/fondo.png", width: 70%, scaling: "pixelated"),
  caption: [Representación gráfica del entorno del modelo de la Línea C.],
) <fig-fondo>

=== Trenes

Los trenes circulan por las vías en sentido horario y se detienen en las estaciones. Para este modelo, se asumen trenes uniformes (misma capacidad de pasajeros y velocidad máxima) y que los mismo no deben "ingresarse" en circulación, solo aparecen en las vías cuando sea la hora de apertura. Su comportamiento puede describirse según la máquina de estados finita de Moore de la @fig-fsm-tren.

#figure(
  {
    import fletcher: diagram, edge, node
    // import fletcher.
    diagram(
      node-stroke: .1em,
      node-fill: gray.lighten(75%),
      label-size: 0.8em,
      spacing: (8em, 7em),

      edge((-0.7, 0), (0, 0), [Apertura], "*-|>", label-pos: 0, label-side: center),
      node((0, 0), text(0.7em, `ASCENSO`), radius: 2.2em),
      edge(align(center, $t > #`TREN-T-ESPERA`\/ 2$), label-angle: auto, "-|>"),
      node((1, 0), text(0.7em, `EN_TRÁNSITO`), radius: 2.2em),
      edge(align(center)[Llegó a destino], "-|>", label-sep: 3pt),
      node((2, 0), text(0.7em, `DESCENSO`), radius: 2.2em),
      edge((0, 0), align(center, $t > #`TREN-T-ESPERA`\/ 2$), bend: 30deg, "-|>"),
      edge(align(center)[Clausura], label-angle: -90deg, label-sep: -15pt, "-|>"),
      node((2, 0.8), text(0.7em)[*FIN*], extrude: (-2.5, 0), radius: 2.2em),
    )
  },

  caption: [Máquina de estados de los trenes. Los lazos de espera no se graficaron para simplificar.],
) <fig-fsm-tren>

Cada tren puede encontrarse en uno de tres estados.
- `ASCENSO`: el tren se encuentra detenido en una estación por un tiempo fijo ($#`TREN-T-ESPERA`\/2$), luego pasa al estado `EN_TRÁNSITO`. Durante este estado, se admite la subida de pasajeros.
- `EN_TRÁNSITO`: el tren se mueve entre dos estaciones. Comienza acelerando hasta su velocidad máxima para luego frenar y para en su destino. Al llegar al destino, pasa al estado `DESCENSO`.
- `DESCENSO`: el tren se encuentra detenido en una estación por un tiempo fijo ($#`TREN-T-ESPERA`\/2$). Durante este estado, se admite el descenso de pasajeros. Si el Subte sigue en funcionamiento, luego pasa al estado `ASCENSO`; de lo contrario, el tren sale del sistema (*FIN*).

Además, los trenes son parametrizados, permitiendo variar sus propiedades para simular distintos escenarios.
- `max-pasajeros`: pasajeros máximos que soporta la formación.
- `TREN-V-MAX` [#zi.m-s()]: velocidad máxima de los trenes.
- `TREN-ACC` [#ms2()]: aceleración del tren.

Se estimaron parámetros base para realizar comparaciones. Se simula que la distancia entre ambas estaciones es de #zi.km[4.5] (aproximado según los mapas de Emova). Además, también según estimaciones realizadas por los autores, el recorrido entre cabeceras tarda aproximadamente #zi.minute[13]. Esto resulta en una velocidad media de los trenes de #zi.km-h[20].

=== Pasajeros

El otro agente móvil es el pasajero. Se asume que todo pasajero usuario de la Línea ingresa por las cabeceras, acorde al estudio deseado de la sincronización con los ferrocarriles metropolitanos. Las estaciones intermedias no resultan de interés porque se quiere ver si los trenes pueden recoger a la mayor cantidad de pasajeros desde las cabeceras, para luego bajar donde sea necesario --- además, al ser cabeceras, no importa si el tren llega lleno porque necesariamente se vacía antes del ascenso de nuevos pasajeros.

De este modo, su comportamiento puede describirse según la máquina de estados finita de Moore de la @fig-fsm-pasajero. Cada pasajero idealmente espera a un tren, se sube y viaja; pero se le agregó un parámetro de _paciencia_ que le permite desistir y movilizarse de otra manera si espera demasiado.

#figure(
  {
    import fletcher: diagram, edge, node
    // import fletcher.
    diagram(
      node-stroke: .1em,
      node-fill: gray.lighten(75%),
      label-size: 0.8em,
      spacing: (5em, 7em),

      // edge((-0, 0), "r", "-|>",  label-pos: 0, label-side: center),
      edge((0, 0), "r", "*-|>", label-pos: 0, label-side: center),
      node((1, 0), text(0.7em, `ESPERANDO`), radius: 2.2em),
      edge((2, 0), align(center)[Hay tren en\ el andén], "-|>"),
      edge((4, 0), align(center, $t > #`t-paciencia`$), bend: -30deg, "-|>"),
      node((2, 0), text(0.7em, `SUBIENDO`), radius: 2.2em),
      edge((1, 0), [Tren sin capacidad], "-|>", bend: -50deg, label-angle: auto, label-sep: 5pt),
      edge(align(center)[Subió\ al tren], "-|>"),
      node((3, 0), text(0.7em, `VIAJANDO`), radius: 2.2em),
      edge(align(center)[Llegó a\ destino], "-|>"),
      node((4, 0), text(0.7em)[*`SALIENDO`*], extrude: (-2.5, 0), radius: 2.2em),
    )
  },

  caption: [Máquina de estados de los pasajeros. Los lazos de espera no se graficaron para simplificar.],
) <fig-fsm-pasajero>

Cada pasajero puede encontrarse en uno de cuatro estados.
- `ESPERANDO`: el pasajero se encuentra en la estación esperando a que llegue el próximo tren. En este estado, incrementa su variable interna `t-esperando`. Si se supera su umbral de paciencia, el mismo pasa al estado `SALIENDO`. Si llega un tren en estado de `ASCENSO`, el pasajero pasa al estado `SUBIENDO`.
- `SUBIENDO`: el pasajero se dirige hacia el tren. Al llegar a las puertas, verifica si el tren tiene espacio disponible. Si lo tiene, se sube y pasa al estado `VIAJANDO`; de lo contrario, pasa nuevamente al estado `ESPERANDO`.
- `VIAJANDO`: el pasajero espera sereno a que el tren llegue a su destino. Al pasar el tren a su estado de `DESCENSO`, el pasajero pasa a su estado de `SALIENDO`.
- `SALIENDO`: desde su posición actual, el pasajero se dirige hacia la salida más cercana para luego desaparecer de la simulación.

Cada pasajero puede ser parametrizado con dos opciones.
- `destino`: hacia dónde se dirige.
- `t-paciencia` [#zi.s()]: el tiempo máximo dispuesto a esperar en el andén.

Los mismos no aparecen de forma azarosa en las estaciones. Deben aparecer siguiendo los histogramas de molinetes (@fig-pasajeros-retiro y @fig-pasajeros-constitucion).

== Implementación

Este modelo se implementó en NetLogo 7.0.0, una herramienta diseñada para implementar ABM @NetLogo, que permite definir agentes, sus propiedades y comportamientos de manera sencilla. La @fig-interfaz muestra la interfaz de la simulación.

#figure(
  image("imagenes/interfaz.png", width: 85%),
  caption: [Interfaz de la simulación en NetLogo. A la izquierda, se observan los controles de la simulación. A la derecha, se observan los trenes y los pasajeros circulando por la Línea C del Subte de Buenos Aires.],
) <fig-interfaz>


La simulación se ejecuta en un entorno gráfico con coordenadas entre $(40, 20)$ y $(-40, -20)$, donde se representan las vías del Subte, trenes y pasajeros circulando por las mismas. La simulación cuenta con controles para iniciar, pausar y reiniciar la simulación, así como para ajustar parámetros como la cantidad de trenes en circulación y la velocidad de los mismos. Los dos botones más importantes son el de `setup` y el de `go`, que inicializan y ejecutan la simulación, respectivamente.

En el @cod-globals se observan las variables globales definidas en NetLogo. Con las constantes se parametriza el modelo. Estas son:
- `SEG-A-TICKS`: cantidad de segundos reales que representa un _tick_ de la simulación, fijado en 1~tick cada segundo.
- `DIAS-HORA-INICIO` y `DIAS-HORA-FIN`: horarios de inicio y fin de operación del Subte, diferenciando entre días de semana y fines de semana @EmovaHorarios.
- `TREN-V-MAX`: velocidad máxima de los trenes.
- `TREN-ACC`: aceleración de los trenes.
- `TREN-T-ESPERA`: tiempo que el tren permanece detenido en cada estación, fijado en un estimado de #zi.s[60]. Este tiempo se divide en dos partes iguales para el ascenso y descenso de pasajeros.
- `N-TRENES`: cantidad de formaciones en circulación.
- `ESTACIONES-DISTANCIA`: distancia entre estaciones, estimada en #zi.km[4.5] entre cada estación.
- `ESTACIONES-DEMANDA`: la frecuencia de pasajeros en cada estación, primero por día y luego por la cantidad de pasajeros cada 15 minutos. Estos datos se obtuvieron a partir del análisis de los histogramas de molinetes (@fig-pasajeros-retiro y @fig-pasajeros-constitucion).

#figure(
  {
    codly(
      header: [*simulacion.nlogox*],
      ranges: ((3, 25), (30, 30)),
      skips: ((26, 0),),
    )
    raw(source, block: true)
  },
  caption: [Declaración de las variables globales en NetLogo. Se separan en constantes (parámetros del modelo) y variables (estado de la simulación).],
  placement: top,
) <cod-globals>

El resto de valores son inferidos (como `ESCALA`, que convierte las distancias reales en distancias gráficas) o son variables de estado de la simulación (como `dia-actual`, que indica el día actual de la semana).

Aparte de estas entradas, se miden distintas variables de salida para analizar el desempeño del sistema (obtenidas a partir de los _monitores_ de NetLogo, como se ve en la @fig-monitores). Se mide la ocupación de cada estación y la cantidad de pasajeros cuya paciencia se agotó.

#figure(
  image("imagenes/monitores.png", width: 85%),
  caption: [Monitores de la simulación en NetLogo.],
) <fig-monitores>

=== _Patches_

En NetLogo, los _patches_ son las celdas que componen el entorno gráfico. En este modelo, la mayoría de celdas son inocuas, salvo agunas que son utilizadas por las personas para ubicarse en las estaciones. Así, se definieron parámetros para cada _patch_ en el @cod-patches-own que permiten identificar las paredes de las estaciones, los andenes y las salidas.

#figure(
  {
    codly(header: [*simulacion.nlogox*], range: (70, 73))
    raw(source, block: true)
  },
  caption: [Declacación de variables de los _patches_ de NetLogo.],
) <cod-patches-own>


=== Trenes (_Turtle_)

En NetLogo, los _turtles_ son los agentes móviles. En este modelo, se definieron dos tipos de _turtles_: los trenes y las personas. Por un lado, los trenes tienen sus parámetros previamente descritos, así como variables internas para manejar su estado (como `estado` y `n-pasajeros`), definidas en el @cod-trenes-own.

#figure(
  {
    codly(header: [*simulacion.nlogox*], range: (41, 54))
    raw(source, block: true)
  },
  caption: [Declacación de variables de los trenes de NetLogo.],
) <cod-trenes-own>

La `direccion` del tren indica hacia dónde se mueve (hacia Constitución o hacia Retiro). Con `n-pasajeros` se lleva una cuenta de cuántos pasajeros hay en ese momento en el tren. `recorrido` es una lista de coordenadas que permiten el movimiento fluido del tren entre estaciones, junto a `v-actual`, `d-recorrida` y `d-total`.

Luego, cuando comienza el día, el `trenes-dispatcher` se encarga de crear los trenes necesarios y ubicarlos en la estación inicial. Para ello, se utiliza el código del @cod-trenes-dispatcher. Luego, los mismos desaparecen al finalizar el día.

#figure(
  {
    codly(
      header: [*simulacion.nlogox*],
      ranges: ((240, 247), (252, 255)),
      skips: ((248, 0),),
    )
    raw(source, block: true)
  },
  caption: [Rutina que crea los trenes al inicio del día en NetLogo.],
) <cod-trenes-dispatcher>

Finalmente, la máquina de estados se implementa como múltiples funciones dentro de la rutina `go` que se ejecuta en bucle, como se muestra en el @cod-trenes-go.

#figure(
  {
    codly(
      header: [*simulacion.nlogox*],
      ranges: ((178, 179), (190, 190), (193, 201), (212, 212)),
      skips: ((180, 0), (191, 0), (202, 0)),
    )
    raw(source, block: true)
  },
  caption: [Avance de las máquinas de estados de los trenes en NetLogo.],
) <cod-trenes-go>

=== Pasajeros (_Turtle_)

Similarmente, los pasajeros tienen sus parámetros previamente descritos, así como variables internas para manejar su estado, definidas en el @cod-pasajeros-own.

#figure(
  {
    codly(header: [*simulacion.nlogox*], range: (57, 65))
    raw(source, block: true)
  },
  caption: [Declacación de variables de los pasajeros de NetLogo.],
) <cod-pasajeros-own>

El parámetro `t-paciencia` es aleatorio para cada pasajero, siguiendo una distribución normal con media definida por un _slider_ (por defecto #zi.minute[8]) y desviación estándar de #zi.minute[1.5]. La `direccion` indica hacia dónde se dirige el pasajero (hacia Constitución o hacia Retiro). `t-esperando` lleva la cuenta del tiempo que el pasajero lleva esperando en el andén.

El comportamiento de estos es bastante más simple que el de los trenes, porque se mueven sin rumbo por las estaciones hasta que llegue algún tren. Luego, intentan subirse. Si logran subirse, se crea un _link_ entre el pasajero y el tren para que el pasajero pueda "saber" cuándo llegó a su destino. Finalmente, descienden y se dirigen a la salida y se elimina el _link_.

Los pasajeros aparecen en las estaciones según la demanda de pasajeros, implementada en el @cod-pasajeros-dispatcher. La misma lee los histogramas de molinetes y crea pasajeros acorde a la frecuencia de llegada de los mismos.

Finalmente, la máquina de estados se implementa como múltiples funciones dentro de la rutina `go` que se ejecuta en bucle, como se muestra en el @cod-personas-go.

#figure(
  {
    codly(
      header: [*simulacion.nlogox*],
      ranges: ((351, 365), (381, 386)),
      skips: ((366, 0),),
    )
    raw(source, block: true)
  },
  caption: [Rutina que simula la demanda de pasajeros en NetLogo.],
) <cod-pasajeros-dispatcher>

#figure(
  {
    codly(
      header: [*simulacion.nlogox*],
      ranges: ((178, 179), (191, 191), (202, 212)),
      skips: ((180, 0), (192, 0)),
    )
    raw(source, block: true)
  },
  caption: [Avance de las máquinas de estados de los pasajeros en NetLogo.],
) <cod-personas-go>

=== _Monitors_

Para variar los párametros del modelo, se utilizan _sliders_ y _choosers_ en la interfaz gráfica de NetLogo, como se ve en la @fig-controles. Estos permiten modificar las constantes definidas en el @cod-globals.

#figure(
  image("imagenes/controles.png", width: 60%),
  caption: [Controles y monitores de la simulación.],
) <fig-controles>

Con `n-vagones` se cambia la cantidad de vagones por formación --- cada vagón cuenta con una capacidad máxima de 20 pasajeros. Con `paciencia-media` se cambia la paciencia media de los pasajeros --- la desviación estándar se mantiene fija en #zi.minute[1.5]. Con `dia-incial` se puede elegir el día de la semana en que comienza la simulación. Finalmente, con `frecuencia-trenes` se puede elegir la frecuencia de los trenes en minutos, internamente se calcula la cantidad de trenes necesarios para mantener esa frecuencia, como se ve en el @cod-frecuencia-trenes.

#figure(
  {
    codly(header: [*simulacion.nlogox*], range: (98, 99))
    raw(source, block: true)
  },
  caption: [Cómputo de la cantidad de trenes necesarios según la frecuencia deseada en NetLogo. La duración del recorrido del tren se calcula considerando una aceleración y desaceleración uniforme.],
) <cod-frecuencia-trenes>

Luego, se cuenta con dos monitores que muestran la hora actual de la simulación y el día de la semana actual. Más abajo se encuentran _plots_ que grafican distintas variables de la simulación (@fig-monitores). Para cada estación, se grafica la ocupación de la misma en función del tiempo. Además, se grafica la cantidad de pasajeros viajando en algún tren según su destino. Finalmente, se grafican dos funciones acumuladoras: una que cuenta la cantidad de pasajeros que lograron llegar a su destino y otra que cuenta la cantidad de pasajeros que desistieron de esperar.

== Replicación de experimentos

El código fuente de la simulación se encuentra disponible en el repositorio de GitHub #link("https://github.com/JuanM04/str-sim"). Para ejecutar la simulación, basta con descargar el repositorio y abrir el archivo `simulacion.nlogo` con NetLogo 7.0.0 o superior. Nótese que es necesario descargar todo el repositorio, ya que la simulación depende de archivos externos (los histogramas de molinetes). En ese repositorio también se encuentran archivos externos a la simulación en sí, como
- el código fuente de este informe en `informe/`,
- los datasets procesados en `datasets/` junto a el script que los generó
- y las simulaciones realizadas en `simulaciones/`.

#pagebreak()
= Resultados

Sobre la simulación desarrollada, se realizaron múltiples experimentos variando los parámetros del modelo. En particular, se variaron la cantidad de vagones por formación y la frecuencia de los trenes. Para estos experimentos, se fijó la paciencia media de los pasajeros en el doble de la frecuencia de los trenes, para simular que los pasajeros están dispuestos a esperar entre uno y dos trenes antes de desistir.

Como base, se tomaron frecuencias de 3, 5 y 7 minutos para los días de semana, sábados y domingos, respectivamente @EmovaHorarios. Sobre estas frecuencias, se variaron la cantidad de vagones por formación entre 1 y 3 vagones (cada uno con capacidad para 20 pasajeros). Estos resultados se resumen en la @tabla-resultados-base.

#figure(
  table(
    columns: 7,
    align: (
      left + horizon,
      center + horizon,
      center + horizon,
      center + horizon,
      right + horizon,
      right + horizon,
      left + horizon,
    ),
    stroke: none,

    table.hline(),
    table.header[Día][Frecuencia][Trenes][Vagones][Pas. transportados][Pas. que desistieron][Simulación],
    table.hline(),
    table.cell(rowspan: 3)[Lunes],
    table.cell(rowspan: 3, zi.minute[3]),
    table.cell(rowspan: 3, num[10]),
    num[1],
    num[4870],
    num[360],
    [@fig-lunes-3min-1vagón],
    [*#num[2]*],
    [*#num[4891]*],
    [*#num[14]*],
    [*@fig-lunes-3min-2vagones*],
    num[3],
    num[4893],
    num[12],
    [@fig-lunes-3min-3vagones],
    table.hline(),
    table.cell(rowspan: 2)[Sábado],
    table.cell(rowspan: 2, zi.minute[5]),
    table.cell(rowspan: 2, num[6]),
    [*#num[1]*],
    [*#num[2711]*],
    [*#num[22]*],
    [*@fig-sábado-5min-1vagón*],
    num[2],
    num[2717],
    num[16],
    [@fig-sábado-5min-2vagones],
    table.hline(),
    table.cell(rowspan: 1)[Domingo],
    table.cell(rowspan: 1, zi.minute[7]),
    table.cell(rowspan: 1, num[4]),
    [*#num[1]*],
    [*#num[1918]*],
    [*#num[0]*],
    [*@fig-domingo-7min-1vagón*],
    table.hline(),
  ),
  caption: [Configuraciones base de la simulación con frecuencias estándar del Subte.],
) <tabla-resultados-base>

Puede apreciarse que para los días de semana, con coches de un solo vagón se quedan cortos en capacidad, ya que hay una cantidad considerable de pasajeros que desisten de esperar. Al agregar un vagón más, la cantidad de pasajeros transportados aumenta levemente, pero la cantidad de pasajeros que desisten disminuye drásticamente. Finalmente, al agregar un tercer vagón, la cantidad de pasajeros transportados y que desisten se mantiene casi constante.

Un análisis semejante se realizó con los días sábados y domingos, llegando a conclusiones similares. Para los sábados, basta con formaciones de un vagón porque formaciones de dos vagones no presentan una mejora. Es interesante el caso de los domingos, con formaciones de un solo vagón son suficientes para transportar a todos los pasajeros sin que nadie desista.


== Optimizaciones

// lunes-5min-2vagones
// observer: "Trenes utilizados: 6"
// observer: "Pasajeros viajados: 3037"
// observer: "Pasajeros impacientes: 1868"
//
// lunes-5min-3vagones
// observer: "Trenes utilizados: 6"
// observer: "Pasajeros viajados: 4762"
// observer: "Pasajeros impacientes: 143"

// sábado-9min-1vagón
// observer: "Trenes utilizados: 3"
// observer: "Pasajeros viajados: 2496"
// observer: "Pasajeros impacientes: 237"
//
// sábado-9min-2vagones
// observer: "Trenes utilizados: 3"
// observer: "Pasajeros viajados: 2607"
// observer: "Pasajeros impacientes: 126"

A partir de los resultados base, se investigó optimizar el sistema. Comenzando por un día de semana, se probó con reducir la frecuencia de los trenes a 5 minutos (un minuto menos de la paciencia media estimada). Dejando la cantidad de vagones en 2, se obtuvieron los resultados de la @fig-lunes-5min-2vagones. Al disminuir la frecuencia, la cantidad de pasajeros transportados disminuyó considerablemente ($#num(4891) -> #num(3037)$) y los pasajeros que desistieron aumentaron ($#num(14) -> #num(1868)$). Para solventar eso, se agregó un vagón más por formación, obteniendo los resultados de la @fig-lunes-5min-3vagones. Con esta configuración, se obtuvieron solo #num[143] pasajeros que desistieron, transportando un total de #num[4762] pasajeros.

Esto resulta en una optimización considerable, ya que se logró transportar casi la misma cantidad de pasajeros que con la configuración base (frecuencia de 3 minutos y formaciones de 2 vagones) pero con menos trenes en circulación (6 en lugar de 10). Esto implica un ahorro considerable en costos operativos, ya que se utilizan menos recursos para brindar un servicio similar.

De manera similar se optimzaron los fines de semana, llegando a las conclusiones de la @tabla-resultados-optimos.

#figure(
  table(
    columns: 7,
    align: (
      left + horizon,
      center + horizon,
      center + horizon,
      center + horizon,
      right + horizon,
      right + horizon,
      left + horizon,
    ),
    stroke: none,

    table.hline(),
    table.header[Día][Frecuencia][Trenes][Vagones][Pas. transportados][Pas. que desistieron][Simulación],
    table.hline(),
    table.cell(rowspan: 2)[Lunes],
    zi.minute[3],
    num[10],
    num[2],
    num[4891],
    num[14],
    [@fig-lunes-3min-2vagones],
    zi.minute[5],
    num[6],
    num[3],
    num[4762],
    num[143],
    [@fig-lunes-5min-3vagones],
    table.hline(),
    table.cell(rowspan: 2)[Sábado],
    zi.minute[5],
    num[6],
    num[1],
    num[2711],
    num[22],
    [@fig-sábado-5min-1vagón],
    zi.minute[9],
    num[3],
    num[2],
    num[2607],
    num[126],
    [@fig-sábado-9min-2vagones],
    table.hline(),
    table.cell(rowspan: 2)[Domingo],
    zi.minute[7],
    num[4],
    num[1],
    num[1918],
    num[0],
    [@fig-domingo-7min-1vagón],
    zi.minute[11],
    num[3],
    num[1],
    num[1915],
    num[3],
    [@fig-domingo-11min-1vagón],
    table.hline(),
  ),
  caption: [Configuraciones base y optimizadas para cada día.],
) <tabla-resultados-optimos>

Nótese que para el caso de los domingos, se probó reducir la frecuencia a 13 minutos, pero con esta configuración no se logró reducir la cantidad de pasajeros que desistieron de #num[100]. Esto no resultaba de un problema en los otros días, pero como los domingos viajan alrededor de #num[2000] pasajeros, esto resultaba en un porcentaje elevado de pasajeros que desistían (#num[5%]). Por ello, se redujo la frecuencia hasta lograr un resultado más razonable.

= Conclusiones

El modelo desarrollado permitió simular el funcionamiento de la Línea C del Subte de Buenos Aires bajo distintos parámetros. El mismo fue propuesto para estudiar la sincronización entre los trenes del Subte y los ferrocarriles metropolitanos en las cabeceras de Retiro y Constitución. A partir de estos datos, se logró estimar la cantidad de trenes necesarios para satisfacer la demanda de pasajeros en distintos días de la semana. Además, se logró optimizar el sistema reduciendo la cantidad de trenes en circulación sin afectar significativamente la cantidad de pasajeros transportados.

Estos descubrimientos resultan valiosos para la planificación del servicio de la Línea C y pueden ser extendidos a otras líneas del Subte o a otros sistemas de transporte público. Futuras investigaciones podrían explorar la inclusión de estaciones intermedias, variaciones en la demanda a lo largo del año o la incorporación de eventos especiales que afecten el flujo de pasajeros.

#bibliography("bibliografia.bib")

#show: apendice

#pagebreak()
= Simulaciones base

En este apéndice se muestran los resultados completos de las simulaciones realizadas para distintos parámetros del modelo para lograr una configuración base.

#figure(
  image("../simulaciones/lunes-3min-1vagón.png"),
  caption: [Resultados de la simulación un lunes con trenes cada 3 minutos, formaciones de 1 vagón y una paciencia media de 6 minutos.],
) <fig-lunes-3min-1vagón>

#figure(
  image("../simulaciones/lunes-3min-2vagones.png"),
  caption: [Resultados de la simulación un lunes con trenes cada 3 minutos, formaciones de 2 vagones y una paciencia media de 6 minutos.],
) <fig-lunes-3min-2vagones>

#figure(
  image("../simulaciones/lunes-3min-3vagones.png"),
  caption: [Resultados de la simulación un lunes con trenes cada 3 minutos, formaciones de 3 vagones y una paciencia media de 6 minutos.],
) <fig-lunes-3min-3vagones>

#figure(
  image("../simulaciones/sábado-5min-1vagón.png"),
  caption: [Resultados de la simulación un sábado con trenes cada 5 minutos, formaciones de 1 vagón y una paciencia media de 10 minutos.],
) <fig-sábado-5min-1vagón>

#figure(
  image("../simulaciones/sábado-5min-2vagones.png"),
  caption: [Resultados de la simulación un sábado con trenes cada 5 minutos, formaciones de 2 vagones y una paciencia media de 10 minutos.],
) <fig-sábado-5min-2vagones>

#figure(
  image("../simulaciones/domingo-7min-1vagón.png"),
  caption: [Resultados de la simulación un domingo con trenes cada 7 minutos, formaciones de 1 vagón y una paciencia media de 14 minutos.],
) <fig-domingo-7min-1vagón>


= Simulaciones optimizadas

En este apéndice se muestran los resultados completos de las simulaciones realizadas para distintos parámetros del modelo para lograr una configuración optimizada.

#figure(
  image("../simulaciones/lunes-5min-2vagones.png"),
  caption: [Resultados de la simulación un lunes con trenes cada 5 minutos, formaciones de 2 vagones y una paciencia media de 6 minutos.],
) <fig-lunes-5min-2vagones>

#figure(
  image("../simulaciones/lunes-5min-3vagones.png"),
  caption: [Resultados de la simulación un lunes con trenes cada 5 minutos, formaciones de 3 vagones y una paciencia media de 6 minutos.],
) <fig-lunes-5min-3vagones>

#figure(
  image("../simulaciones/sábado-9min-1vagón.png"),
  caption: [Resultados de la simulación un sábado con trenes cada 9 minutos, formaciones de 1 vagón y una paciencia media de 10 minutos.],
) <fig-sábado-9min-1vagón>

#figure(
  image("../simulaciones/sábado-9min-2vagones.png"),
  caption: [Resultados de la simulación un sábado con trenes cada 9 minutos, formaciones de 2 vagones y una paciencia media de 10 minutos.],
) <fig-sábado-9min-2vagones>

#figure(
  image("../simulaciones/domingo-11min-1vagón.png"),
  caption: [Resultados de la simulación un domingo con trenes cada 11 minutos, formaciones de 1 vagón y una paciencia media de 14 minutos.],
) <fig-domingo-11min-1vagón>
