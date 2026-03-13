#!/bin/bash

echo "🚀 Iniciando reparación de entorno RBE para Ubuntu..."

# 1. Matar procesos que estorben en el puerto 3306
echo "🔍 Buscando ocupantes del puerto 3306..."
sudo systemctl stop mysql 2>/dev/null
sudo killall -9 mysqld 2>/dev/null
sudo killall -9 mariadbd 2>/dev/null

# 2. Limpiar archivos de bloqueo de XAMPP
echo "🧹 Limpiando archivos temporales de XAMPP..."
sudo rm -f /opt/lampp/var/mysql/*.pid
sudo rm -f /opt/lampp/var/mysql/mysql.sock

# 3. Corregir permisos (el dolor de cabeza de Linux vs Windows)
echo "🔐 Ajustando permisos de la base de datos..."
sudo chown -R root:root /opt/lampp/var/mysql
sudo chmod -R 777 /opt/lampp/var/mysql

# 4. Arrancar MySQL de XAMPP
echo "🐘 Arrancando MySQL de XAMPP..."
sudo /opt/lampp/lampp startmysql

# 5. Configurar el entorno virtual de Python
echo "🐍 Reconstruyendo entorno virtual..."
if [ -d "venv" ]; then
    rm -rf venv
fi
python3 -m venv venv
source venv/bin/activate

# 6. Instalar dependencias
echo "📦 Instalando requerimientos..."
pip install --upgrade pip
pip install -r requirements.txt

echo "✅ ¡Todo listo, Rodavlas! Ahora intenta: python manage.py runserver"