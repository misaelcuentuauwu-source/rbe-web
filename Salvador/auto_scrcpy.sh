#!/bin/bash

echo "🔄 Esperando dispositivos Android..."

# Función para limpiar procesos al salir
cleanup() {
    echo "🛑 Deteniendo scrcpy..."
    pkill scrcpy
    exit 0
}

# Captura Ctrl+C
trap cleanup SIGINT

while true; do
    DEVICES=$(adb devices | grep -w "device" | cut -f1)

    for DEVICE in $DEVICES; do
        if ! pgrep -f "scrcpy -s $DEVICE" > /dev/null; then
            echo "📱 Conectando $DEVICE..."
            scrcpy -s $DEVICE &
        fi
    done

    sleep 3
done