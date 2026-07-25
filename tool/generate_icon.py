#!/usr/bin/env python3
"""Genera el ícono de la app: calculadora de arcilla sobre fondo morado.

Se dibuja a 4x y se reduce, que es la forma barata de tener bordes suaves
sin antialiasing propio. Salidas:

  assets/icon/icon.png             1024x1024 con fondo (iOS / web / legacy)
  assets/icon/icon_foreground.png  1024x1024 transparente, glifo al 60%
                                   (capa frontal del adaptive icon de Android)

Uso:  python3 tool/generate_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

S = 1024
SS = 4  # supersampling
W = S * SS

MORADO = (108, 92, 231)
MORADO_CLARO = (139, 123, 240)
BLANCO = (255, 255, 255)
LAVANDA = (237, 234, 251)
VERDE = (76, 208, 138)
ROSA = (247, 126, 156)
SOMBRA = (60, 45, 160)


def degradado(size, arriba, abajo):
    """Degradado vertical suave para el fondo."""
    grad = Image.new("RGB", (1, size), arriba)
    px = grad.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(
            round(arriba[i] + (abajo[i] - arriba[i]) * t) for i in range(3)
        )
    return grad.resize((size, size))


def calculadora(draw, cx, cy, ancho, alto, con_sombra=True):
    """Cuerpo blanco + pantalla + teclas. Coordenadas en el lienzo grande."""
    x0, y0 = cx - ancho / 2, cy - alto / 2
    x1, y1 = cx + ancho / 2, cy + alto / 2
    radio = ancho * 0.22

    if con_sombra:
        desp = ancho * 0.045
        draw.rounded_rectangle(
            [x0 + desp, y0 + desp * 1.4, x1 + desp, y1 + desp * 1.4],
            radius=radio,
            fill=SOMBRA + (90,),
        )

    draw.rounded_rectangle([x0, y0, x1, y1], radius=radio, fill=BLANCO)

    # Pantalla
    m = ancho * 0.13
    pantalla_alto = alto * 0.22
    draw.rounded_rectangle(
        [x0 + m, y0 + m, x1 - m, y0 + m + pantalla_alto],
        radius=pantalla_alto * 0.35,
        fill=LAVANDA,
    )

    # Teclas: 3x3, la última fila con la tecla "=" verde alargada.
    tecla_zona_y0 = y0 + m + pantalla_alto + alto * 0.09
    zona_ancho = (x1 - m) - (x0 + m)
    zona_alto = (y1 - m) - tecla_zona_y0
    hueco = zona_ancho * 0.10
    t_ancho = (zona_ancho - hueco * 2) / 3
    t_alto = (zona_alto - hueco * 2) / 3

    for fila in range(3):
        for col in range(3):
            if fila == 2 and col == 1:
                continue  # la tecla verde ocupa dos espacios
            tx = x0 + m + col * (t_ancho + hueco)
            ty = tecla_zona_y0 + fila * (t_alto + hueco)
            ancho_t = t_ancho
            color = MORADO
            if fila == 2 and col == 0:
                ancho_t = t_ancho * 2 + hueco
                color = VERDE
            if fila == 0 and col == 2:
                color = ROSA
            draw.rounded_rectangle(
                [tx, ty, tx + ancho_t, ty + t_alto],
                radius=t_alto * 0.42,
                fill=color,
            )


def con_fondo():
    fondo = degradado(W, MORADO_CLARO, MORADO).convert("RGBA")

    # Máscara de squircle (esquinas iOS-style bien redondeadas).
    mascara = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mascara).rounded_rectangle(
        [0, 0, W, W], radius=W * 0.235, fill=255
    )

    capa = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa, "RGBA")
    calculadora(d, W / 2, W / 2, W * 0.50, W * 0.62)

    img = Image.alpha_composite(fondo, capa)
    img.putalpha(mascara)
    return img.resize((S, S), Image.LANCZOS)


def solo_glifo():
    """Capa frontal del adaptive icon.

    Android recorta el 33% exterior, así que lo seguro es el círculo central
    de 0.66*W. La calculadora mide 0.40x0.50 del lienzo: llena bien ese
    círculo sin que la máscara le muerda las esquinas.
    """
    capa = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa, "RGBA")
    calculadora(d, W / 2, W / 2, W * 0.40, W * 0.50, con_sombra=False)
    return capa.resize((S, S), Image.LANCZOS)


if __name__ == "__main__":
    destino = Path(__file__).resolve().parent.parent / "assets" / "icon"
    destino.mkdir(parents=True, exist_ok=True)

    con_fondo().save(destino / "icon.png")
    solo_glifo().save(destino / "icon_foreground.png")
    print(f"listo → {destino}")
