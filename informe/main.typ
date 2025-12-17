#import "@preview/barcala:0.3.0": apendice, informe, nomenclatura
#import "@preview/lilaq:0.5.0" as lq // Paquete para gráficos, puede ser omitido
#import "@preview/physica:0.9.6": * // Paquete para matemática y física, puede ser omitido
#import "@preview/zero:0.5.0" // Paquete para números lindos y unidades de medida, puede ser omitido
#import "@preview/fletcher:0.5.8"

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
  resumen: [*_Resumen_ --- .*],

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

// NetLogo
#set raw(syntaxes: "netlogo.yaml")

#outline()

#nomenclatura(
  ($q$, [Carga [#zi.coulomb()]]),
  ($I$, [Corriente [#zi.ampere()]]),
  ($U$, [Potencial eléctrico [#zi.volt()]]),
  ($va(E)$, [Campo eléctrico [#Vm()]]),
  ($va(B)$, [Campo magnético [#zi.tesla()]]),
)

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

En cambio, los modelos computaciones aprovechan que las computadoras pueden realizar numerosas operaciones matemáticas simples en muy poco tiempo, habilitando obtener resultados valiosos de modelos no lineales. Un tipo de modelo computacional son los *modelos basados en agentes* (ABM, por sus siglas en inglés, _Agent-based model_) @Railsback2019[p.~10]. Lo particular de este tipo de modelos es que no se modela el sistema sí, sino que se pone énfasis en cada componente individual (cada _agente_). Cada agente cuenta con sus propias variables internas y un comportamiento predefinido con cada otro agente y con el _entorno_. Cada agente deben ser descrito según sus *propiedades* (variables internas) y sus *acciones* (o comportamiento con otros agentes y su entorno) @Wilensky2015[p.~205].

Este marco teórico resulta conveniente, ya que permite modelar a cada agente de manera individual sin saber el comportamiento del sistema como un todo. Para el caso del Subte, donde se desconocen estas dinámicas de antemano, se justifica el uso de este tipo de modelado.

#pagebreak()

= Metodología

Para estudiar la Línea C se desarroló un ABM que permite aprovechar las capacidades computaciones para simular distintos escenarios.

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

Los mismo no aparecen de forma azarosa en las estaciones. Deben aparecer siguiendo los histogramas de molinetes (@fig-pasajeros-retiro y @fig-pasajeros-constitucion).

== Implementación

Este modelo se implementó en NetLogo, una herramienta diseñada para implementar ABM @NetLogo.

#highlight(fill: red)[imagen final]


= Resultados

= Conclusiones


// Sección de apéndices. Si no se usa, se puede comentar o borrar
#show: apendice

= Apéndice
Si corresponde, utilice uno o más apéndices para complementar la información del trabajo.

#pagebreak()

#bibliography("bibliografia.bib")
