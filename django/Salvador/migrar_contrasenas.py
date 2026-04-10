# Salvador/migrar_contrasenas.py
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'rbe.settings')

import django
django.setup()

from django.contrib.auth.hashers import make_password
from taquilla.models import Taquillero

for taq in Taquillero.objects.all():
    # Solo migrar si aún no está hasheada
    if not taq.contrasena.startswith('pbkdf2_'):
        contrasena_plana = taq.contrasena
        taq.contrasena = make_password(contrasena_plana)
        taq.save(update_fields=['contrasena'])
        print(f"✓ {taq.usuario}")

print("Migración completa")