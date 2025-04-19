import serial
import time

SERIAL_PORT = 'COM10'
BAUD_RATE = 115200

def main():
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    except Exception as e:
        print(f"Failed to open serial port: {e}")
        return

    print("UART reader started. Waiting for data...")
    
    received_bytes = bytearray()
    start_time = time.time()
    while True:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting)
            received_bytes.extend(data)
            print(data.hex(' '))
            if len(received_bytes) >= 124:
                break
        
        if time.time() - start_time > 50:
            print("Timeout waiting for data.")
            break

    print("\nReceived total bytes:")
    print(received_bytes.hex(' '))
    ser.close()

if __name__ == '__main__':
    main()
