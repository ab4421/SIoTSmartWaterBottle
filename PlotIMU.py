import serial
import csv
import time
from serial.tools import list_ports

def find_arduino_port():
    """Find the first Arduino device connected"""
    ports = list_ports.comports()
    for port in ports:
        if 'Arduino' in port.description or 'USB Serial' in port.description:
            return port.device
    return None

def main():
    # Find Arduino port automatically
    port = find_arduino_port()
    if not port:
        print("No Arduino found. Available ports:")
        for p in list_ports.comports():
            print(f"  {p.device}: {p.description}")
        port = input("Please enter your port manually: ")

    # Configure serial connection
    try:
        ser = serial.Serial(port, 9600, timeout=1)
        print(f"Connected to {port}")
        
        # Create CSV file with timestamp
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filename = f'imu_data_{timestamp}.csv'
        
        with open(filename, 'w', newline='') as csvfile:
            csvwriter = csv.writer(csvfile)
            
            # Write header
            headers = ['timestamp(ms)', 'accelX', 'accelY', 'accelZ', 
                      'gyroX', 'gyroY', 'gyroZ']
            csvwriter.writerow(headers)
            
            print(f"Recording data to {filename}")
            print("Press Ctrl+C to stop recording")
            
            # Skip the first line (Arduino serial initialization)
            ser.readline()
            
            while True:
                try:
                    # Read and decode the line
                    line = ser.readline().decode('utf-8').strip()
                    
                    if line:  # Only process non-empty lines
                        # Split the CSV line into values
                        values = line.split(',')
                        
                        # Write to CSV if we have the correct number of values
                        if len(values) == 7:  # We expect 7 values
                            csvwriter.writerow(values)
                            print(f"Recorded: {line}", end='\r')
                        
                except KeyboardInterrupt:
                    print("\nRecording stopped by user")
                    break
                except UnicodeDecodeError:
                    # Skip any malformed data
                    continue
                
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("\nSerial connection closed")

if __name__ == "__main__":
    main()
