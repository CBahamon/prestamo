import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../theme/clay.dart';
import 'clay_motion.dart';

/// Tarjeta base con relieve de arcilla.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.margin,
    this.onTap,
    this.depth = 1,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? ClayColors.surface;
    final oscura = color != null && color != ClayColors.surface;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: claySoft(base: ClayColors.purple, depth: depth),
      ),
      child: ClayPressable(
        onTap: onTap,
        borderRadius: radius,
        waveColor: oscura ? Colors.white : ClayColors.purple,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Botón cuadrado tipo "acceso rápido" del menú principal.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // El padding le da aire a la sombra: el recorte de la onda no la corta.
    return ClayPressable(
      onTap: onTap,
      borderRadius: 26,
      pressedScale: 0.90,
      waveColor: color,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.28)!, color],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    offset: const Offset(0, 8),
                    blurRadius: 14,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.7),
                    offset: const Offset(-3, -3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ClayColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto hundido en la superficie de arcilla.
class ClayField extends StatelessWidget {
  const ClayField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.prefix,
    this.suffix,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.inputFormatters,
    this.onChanged,
    this.money = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final String? prefix;
  final String? suffix;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  /// Agrupa los miles con puntos mientras se escribe.
  final bool money;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: ClayColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F2FE),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ClayColors.purple.withValues(alpha: 0.10),
                offset: const Offset(2, 3),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters:
                inputFormatters ??
                (money ? const [MilesInputFormatter()] : null),
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ClayColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: ClayColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              prefixText: prefix,
              suffixText: suffix,
              prefixStyle: const TextStyle(
                color: ClayColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
              suffixStyle: const TextStyle(
                color: ClayColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selector de opciones en píldoras (tipo de tasa, plazo, etc.).
class ClayChips<T> extends StatelessWidget {
  const ClayChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
    this.label,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: ClayColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = o == selected;
            // La píldora elegida da un saltico y se infla un poco.
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: active ? 1.06 : 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: ClayPressable(
                onTap: () => onSelect(o),
                borderRadius: 16,
                pressedScale: 0.93,
                waveColor: active ? Colors.white : ClayColors.purple,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: active ? ClayColors.purple : const Color(0xFFF4F2FE),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: ClayColors.purple.withValues(alpha: 0.4),
                              offset: const Offset(0, 5),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? Colors.white : ClayColors.textMuted,
                    ),
                    child: Text(labelOf(o)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Botón principal de acción.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = ClayColors.purple,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClayPressable(
      onTap: onPressed,
      borderRadius: 22,
      pressedScale: 0.96,
      waveColor: Colors.white,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.22)!, color],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              offset: const Offset(0, 9),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado morado con esquinas redondeadas inferiores.
class ClayHeader extends StatelessWidget {
  const ClayHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return WaveEdge(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 22,
          right: 22,
          bottom: 44,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ClayColors.purpleLight, ClayColors.purple],
          ),
        ),
        child: Row(
          children: [
            if (showBack)
              ClayPressable(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: 20,
                pressedScale: 0.85,
                waveColor: Colors.white,
                child: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            Expanded(
              child: Column(
                // Sin esto el encabezado se estira a toda la pantalla cuando
                // vive dentro de un Stack, que sí le da altura acotada.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Pantalla con el encabezado flotando encima del contenido.
///
/// El contenido scrollea **por debajo** del morado, así que el recorte lo hace
/// la ola del [ClayHeader] y no una línea recta. El alto del encabezado se
/// mide en tiempo real (cambia con el tamaño de letra del sistema y con el
/// notch), y se le pasa al hijo para que arranque justo debajo.
class ClayScaffold extends StatefulWidget {
  const ClayScaffold({
    super.key,
    required this.header,
    required this.builder,
    this.background = ClayColors.background,
  });

  final ClayHeader header;

  /// Recibe el alto del encabezado para usarlo como padding superior.
  final Widget Function(BuildContext context, double topPadding) builder;

  final Color background;

  @override
  State<ClayScaffold> createState() => _ClayScaffoldState();
}

class _ClayScaffoldState extends State<ClayScaffold> {
  double _headerHeight = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.background,
      body: Stack(
        children: [
          Positioned.fill(child: widget.builder(context, _headerHeight)),
          Align(
            alignment: Alignment.topCenter,
            child: _MeasureHeight(
              // La ola invade los últimos píxeles: el contenido puede empezar
              // un poco más arriba y aún así quedar tapado por la cresta.
              onChange: (alto) => setState(() => _headerHeight = alto - 16),
              child: widget.header,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avisa el alto real de su hijo después de cada layout.
///
/// Medir con GlobalKey no sirve aquí: dentro de un Stack la búsqueda termina
/// en el Align que ocupa toda la pantalla, no en el encabezado.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChange, required Widget super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _ultimo;

  @override
  void performLayout() {
    super.performLayout();
    if (_ultimo != null && (size.height - _ultimo!).abs() < 0.5) return;
    _ultimo = size.height;
    // Fuera del layout: notificar aquí mismo dispararía un setState en pleno
    // build.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size.height));
  }
}
