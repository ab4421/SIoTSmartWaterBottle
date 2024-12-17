import serial
import csv
import time
from serial.tools import list_ports
import pandas as pd
import matplotlib.pyplot as plt

def find_arduino_port():
    """Find the first Arduino device connected"""
    ports = list_ports.comports()
    for port in ports:
        if 'Arduino' in port.description or 'USB Serial' in port.description:
            return port.device
    return None

def load_latest_scale_data():
    """Load the most recent scale data file from the current directory"""
    files = glob.glob('scale_data_*.csv')
    if not files:
        raise FileNotFoundError("No scale data files found!")
    
    latest_file = max(files, key=os.path.getctime)
    print(f"Loading data from: {latest_file}")
    return pd.read_csv(latest_file)

def plot_scale_data(df):
    """Create a formatted plot of scale data"""
    # Convert timestamp to seconds for better readability
    df['time_sec'] = df['timestamp(ms)'] / 1000.0
    
    # Create figure and subplot
    fig, ax = plt.subplots(figsize=(12, 6))
    fig.suptitle('Scale Weight Measurements', fontsize=16, y=0.95)
    
    # Plot weight data
    ax.plot(df['time_sec'], df['weight_g'], label='Weight', color='blue')
    ax.set_xlabel('Time (seconds)')
    ax.set_ylabel('Weight (g)')
    ax.set_title('Weight vs Time')
    ax.grid(True)
    ax.legend()
    
    # Adjust layout
    plt.tight_layout()
    
    return fig

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
        filename = f'scale_data_{timestamp}.csv'
        
        with open(filename, 'w', newline='') as csvfile:
            csvwriter = csv.writer(csvfile)
            
            # Write header
            headers = ['timestamp(ms)', 'weight_g']
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
                        if len(values) == 2:  # We expect 2 values (timestamp and weight)
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

        try:
            # Load the data and create plot
            df = pd.read_csv(filename)
            fig = plot_scale_data(df)
            
            # Save the plot
            plot_filename = f'scale_plot_{timestamp}.png'
            plt.savefig(plot_filename, dpi=300, bbox_inches='tight')
            print(f"Plot saved as: {plot_filename}")
            
            # Display the plot
            plt.show()
            
        except Exception as e:
            print(f"Error creating plot: {e}")

if __name__ == "__main__":
    main()
