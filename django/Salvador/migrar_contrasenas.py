# Salvador/migrar_contrasenas.py
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'rbe.settings')

import django
django.setup()

from django.contrib.auth.hashers import make_password
from taquilla.models import Taquillero

# Contraseñas originales de cada taquillero (del SQL original)
contrasenas_originales = {
    'agomez': 'AG2023',
    'msanchez': 'MS22',
    'btorres': 'BT24',
    'jperez': 'JP24',
    'dramirez': 'DR23',
    'kherrera': 'KH25',
    'lsanchez': 'LS22',
    'cmedina': 'CM23',
    'freyes': 'FR25',
    'ctorres': 'CT21',
    'icruz': 'IC22',
    'sortega': 'SO24',
    'sdelgado': 'SD23',
    'vmunoz': 'VM24',
    'hparedes': 'HP22',
    'pflores': 'PF24',
    'evargas': 'EV23',
    'ksalgado': 'KS25',
    'mcastillo': 'MC23',
    'lnavarro': 'LN24',
    'savila': 'SA25',
    'sgarcia': 'salvador',
    'za': 'za',
}

for taq in Taquillero.objects.all():
    if taq.usuario in contrasenas_originales:
        taq.contrasena = make_password(contrasenas_originales[taq.usuario])
        taq.save(update_fields=['contrasena'])
        print(f"✓ {taq.usuario}")
    else:
        print(f"⚠ {taq.usuario} — no encontrado en el diccionario")

print("Migración completa")