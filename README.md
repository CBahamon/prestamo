# Préstamos

Calculadora de préstamos y créditos hipotecarios con tabla de amortización y
control de ahorros. Sin publicidad, sin cuenta, sin internet: todo se guarda en
el dispositivo.

## Qué hace

- **Calcular préstamo** — monto, tasa y plazo → cuota fija + total de intereses.
- **Crédito hipotecario** — valor de la casa + cuánto presta el banco (en % o en
  $) → monto del préstamo, cuota inicial y cuota mensual. Cruza la cuota inicial
  con lo que llevas ahorrado y dice cuánto falta.
- **Tabla de amortización** — cuota a cuota: interés, abono a capital y saldo.
- **Guardar préstamos** — lista local con detalle y borrado.
- **Ahorros** — bolsillos con nombre y monto; el total alimenta el resumen y la
  hipoteca.
- **Moneda** — arranca con la del celular (Colombia → COP) y se puede cambiar en
  Ajustes.

## Tipos de tasa soportados

| Opción | Significado |
|---|---|
| `E.A.` | Efectiva anual (la que publican los bancos en Colombia) |
| `E.M.` | Efectiva mensual |
| `N.A. M.V.` | Nominal anual, mes vencido |
| `N.A. T.V.` | Nominal anual, trimestre vencido |
| `N.A. S.V.` | Nominal anual, semestre vencido |

Todo se normaliza a **efectiva mensual** antes de calcular. Una E.A. **no** se
divide entre 12 — se usa `(1+EA)^(1/12) - 1`. Dividir entre 12 infla la cuota.

Cuota fija (sistema francés):

```
cuota = P · i / (1 - (1+i)^-n)
```

> Nota: no cubre créditos en **UVR** ni cuota decreciente (abono constante a
> capital). Si el banco cotiza en UVR, el resultado es una aproximación en pesos.

## Correr

```bash
flutter pub get
flutter run           # Android / iOS conectado
flutter test          # matemática del préstamo
```

## Compartir la app

### Android (tú)

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Se pasa por WhatsApp/Drive y se instala habilitando "orígenes desconocidos".

### iPhone (sin pagar los USD 99/año de Apple) → PWA

Un APK no corre en iPhone. La vía gratis es la versión web instalable:

```bash
flutter build web --release
# build/web  → subir a Netlify, Vercel, Cloudflare Pages o GitHub Pages
```

En el iPhone: abrir el link **en Safari** → botón compartir → **Agregar a
pantalla de inicio**. Queda con ícono propio, pantalla completa y sin barra del
navegador. Los datos se guardan en el almacenamiento local del navegador.

Deploy rápido con Netlify:

```bash
npx netlify-cli deploy --dir=build/web --prod
```

Alternativas para iOS y por qué no:

| Vía | Costo | Límite |
|---|---|---|
| PWA | $0 | ninguno relevante para este caso |
| Sideload con Xcode/AltStore | $0 | la firma vence a los **7 días**, hay que reinstalar |
| TestFlight | USD 99/año | el build expira a los 90 días |
| App Store | USD 99/año | revisión de Apple |

## Estructura

```
lib/
  core/
    amortization.dart   cuota fija + tabla de amortización
    rates.dart          tipos de tasa y conversión a efectiva mensual
    money.dart          monedas, formato y parseo de montos
  models/               préstamo guardado, bolsillo de ahorro
  state/app_state.dart  estado global + persistencia (SharedPreferences)
  screens/              inicio, calculadora, hipoteca, ahorros, guardados, ajustes
  widgets/              componentes claymorphism (ClayCard, ClayField, ...)
  theme/clay.dart       paleta y sombras
```
