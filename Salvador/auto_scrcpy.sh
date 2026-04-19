#!/bin/bash

echo "🔄 Esperando dispositivos Android..."

while true; do
    # Obtener dispositivos conectados
    DEVICES=$(adb devices | grep -w "device" | cut -f1)

    for DEVICE in $DEVICES; do
        # Verifica si ya hay un scrcpy corriendo para ese dispositivo
        if ! pgrep -f "scrcpy -s $DEVICE" > /dev/null; then
            echo "📱 Conectando $DEVICE..."
            scrcpy -s $DEVICE &
        fi
    done

    sleep 3
done