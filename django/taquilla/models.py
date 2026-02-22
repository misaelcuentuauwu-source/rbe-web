# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Asiento(models.Model):
    numero = models.AutoField(primary_key=True)
    tipo = models.ForeignKey('TipoAsiento', models.DO_NOTHING, db_column='tipo')
    autobus = models.ForeignKey('Autobus', models.DO_NOTHING, db_column='autobus')

    class Meta:
        managed = False
        db_table = 'asiento'


class Autobus(models.Model):
    numero = models.IntegerField(primary_key=True)
    modelo = models.ForeignKey('Modelo', models.DO_NOTHING, db_column='modelo')
    placas = models.CharField(unique=True, max_length=10)
    serievin = models.CharField(db_column='serieVIN', unique=True, max_length=17)  # Field name made lowercase.

    class Meta:
        managed = False
        db_table = 'autobus'


class Ciudad(models.Model):
    clave = models.CharField(primary_key=True, max_length=5)
    nombre = models.CharField(max_length=30)

    class Meta:
        managed = False
        db_table = 'ciudad'


class Conductor(models.Model):
    registro = models.IntegerField(primary_key=True)
    connombre = models.CharField(db_column='conNombre', max_length=30)  # Field name made lowercase.
    conprimerapell = models.CharField(db_column='conPrimerApell', max_length=30)  # Field name made lowercase.
    consegundoapell = models.CharField(db_column='conSegundoApell', max_length=30, blank=True, null=True)  # Field name made lowercase.
    licnumero = models.CharField(db_column='licNumero', max_length=15)  # Field name made lowercase.
    licvencimiento = models.DateField(db_column='licVencimiento')  # Field name made lowercase.
    fechacontrato = models.DateField(db_column='fechaContrato')  # Field name made lowercase.

    class Meta:
        managed = False
        db_table = 'conductor'


class EdoViaje(models.Model):
    numero = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=30)
    descripcion = models.CharField(max_length=50)

    class Meta:
        managed = False
        db_table = 'edo_viaje'


class Marca(models.Model):
    numero = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=30)

    class Meta:
        managed = False
        db_table = 'marca'


class Modelo(models.Model):
    numero = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=30)
    numasientos = models.IntegerField()
    ano = models.IntegerField()
    capacidad = models.IntegerField()
    marca = models.ForeignKey(Marca, models.DO_NOTHING, db_column='marca')

    class Meta:
        managed = False
        db_table = 'modelo'


class Pago(models.Model):
    numero = models.AutoField(primary_key=True)
    fechapago = models.DateTimeField()
    monto = models.DecimalField(max_digits=10, decimal_places=2)
    tipo = models.ForeignKey('TipoPago', models.DO_NOTHING, db_column='tipo')
    vendedor = models.ForeignKey('Taquillero', models.DO_NOTHING, db_column='vendedor', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'pago'


class Pasajero(models.Model):
    num = models.AutoField(primary_key=True)
    panombre = models.CharField(db_column='paNombre', max_length=30)  # Field name made lowercase.
    paprimerapell = models.CharField(db_column='paPrimerApell', max_length=30)  # Field name made lowercase.
    pasegundoapell = models.CharField(db_column='paSegundoApell', max_length=30, blank=True, null=True)  # Field name made lowercase.
    fechanacimiento = models.DateField(db_column='fechaNacimiento')  # Field name made lowercase.
    edad = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'pasajero'


class Ruta(models.Model):
    codigo = models.IntegerField(primary_key=True)
    duracion = models.CharField(max_length=10)
    origen = models.ForeignKey('Terminal', models.DO_NOTHING, db_column='origen')
    destino = models.ForeignKey('Terminal', models.DO_NOTHING, db_column='destino', related_name='ruta_destino_set')
    precio = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        managed = False
        db_table = 'ruta'


class Taquillero(models.Model):
    registro = models.AutoField(primary_key=True)
    taqnombre = models.CharField(db_column='taqNombre', max_length=30)  # Field name made lowercase.
    taqprimerapell = models.CharField(db_column='taqPrimerApell', max_length=30)  # Field name made lowercase.
    taqsegundoapell = models.CharField(db_column='taqSegundoApell', max_length=30, blank=True, null=True)  # Field name made lowercase.
    fechacontrato = models.DateField(db_column='fechaContrato')  # Field name made lowercase.
    usuario = models.CharField(max_length=20)
    contrasena = models.CharField(max_length=20)
    terminal = models.ForeignKey('Terminal', models.DO_NOTHING, db_column='terminal')
    supervisa = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'taquillero'


class Terminal(models.Model):
    numero = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=30)
    dircalle = models.CharField(db_column='dirCalle', max_length=30)  # Field name made lowercase.
    dirnumero = models.CharField(db_column='dirNumero', max_length=10)  # Field name made lowercase.
    dircolonia = models.CharField(db_column='dirColonia', max_length=30)  # Field name made lowercase.
    telefono = models.CharField(max_length=12, blank=True, null=True)
    ciudad = models.ForeignKey(Ciudad, models.DO_NOTHING, db_column='ciudad')

    class Meta:
        managed = False
        db_table = 'terminal'


class Ticket(models.Model):
    codigo = models.AutoField(primary_key=True)
    precio = models.DecimalField(max_digits=10, decimal_places=2)
    fechaemision = models.DateTimeField(db_column='fechaEmision')  # Field name made lowercase.
    asiento = models.ForeignKey(Asiento, models.DO_NOTHING, db_column='asiento')
    viaje = models.ForeignKey('Viaje', models.DO_NOTHING, db_column='viaje')
    pasajero = models.ForeignKey(Pasajero, models.DO_NOTHING, db_column='pasajero')
    tipopasajero = models.ForeignKey('TipoPasajero', models.DO_NOTHING, db_column='tipopasajero')
    pago = models.ForeignKey(Pago, models.DO_NOTHING, db_column='pago')

    class Meta:
        managed = False
        db_table = 'ticket'


class TipoAsiento(models.Model):
    codigo = models.CharField(primary_key=True, max_length=5)
    descripcion = models.CharField(unique=True, max_length=30)

    class Meta:
        managed = False
        db_table = 'tipo_asiento'


class TipoPago(models.Model):
    numero = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=30)
    descripcion = models.CharField(unique=True, max_length=50)

    class Meta:
        managed = False
        db_table = 'tipo_pago'


class TipoPasajero(models.Model):
    num = models.IntegerField(primary_key=True)
    descuento = models.IntegerField()
    descripcion = models.CharField(unique=True, max_length=30)

    class Meta:
        managed = False
        db_table = 'tipo_pasajero'


class Viaje(models.Model):
    numero = models.AutoField(primary_key=True)
    fechorasalida = models.DateTimeField(db_column='fecHoraSalida')  # Field name made lowercase.
    fechoraentrada = models.DateTimeField(db_column='fecHoraEntrada')  # Field name made lowercase.
    ruta = models.ForeignKey(Ruta, models.DO_NOTHING, db_column='ruta')
    estado = models.ForeignKey(EdoViaje, models.DO_NOTHING, db_column='estado')
    autobus = models.ForeignKey(Autobus, models.DO_NOTHING, db_column='autobus', blank=True, null=True)
    conductor = models.ForeignKey(Conductor, models.DO_NOTHING, db_column='conductor', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'viaje'


class ViajeAsiento(models.Model):
    asiento = models.OneToOneField(Asiento, models.DO_NOTHING, db_column='asiento', primary_key=True)  # The composite primary key (asiento, viaje) found, that is not supported. The first column is selected.
    viaje = models.ForeignKey(Viaje, models.DO_NOTHING, db_column='viaje')
    ocupado = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'viaje_asiento'
        unique_together = (('asiento', 'viaje'),)
