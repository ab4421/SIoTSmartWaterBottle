import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

def load_latest_imu_data():
    """Load the most recent IMU data file from the current directory"""
    files = glob.glob('imu_data_*.csv')
    if not files:
        raise FileNotFoundError("No IMU data files found!")
    
    latest_file = max(files, key=os.path.getctime)
    print(f"Loading data from: {latest_file}")
    return pd.read_csv(latest_file)

def plot_imu_data(df):
    """Create a formatted plot of IMU data"""
    # Convert timestamp to seconds for better readability
    df['time_sec'] = df['timestamp(ms)'] / 1000.0
    
    # Create figure and subplots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
    fig.suptitle('IMU Sensor Data', fontsize=16, y=0.95)
    
    # Plot accelerometer data
    ax1.plot(df['time_sec'], df['accelX'], label='X', color='red')
    ax1.plot(df['time_sec'], df['accelY'], label='Y', color='green')
    ax1.plot(df['time_sec'], df['accelZ'], label='Z', color='blue')
    ax1.set_xlabel('Time (seconds)')
    ax1.set_ylabel('Acceleration (g)')
    ax1.set_title('Accelerometer Data')
    ax1.grid(True)
    ax1.legend()
    
    # Plot gyroscope data
    ax2.plot(df['time_sec'], df['gyroX'], label='X', color='red')
    ax2.plot(df['time_sec'], df['gyroY'], label='Y', color='green')
    ax2.plot(df['time_sec'], df['gyroZ'], label='Z', color='blue')
    ax2.set_xlabel('Time (seconds)')
    ax2.set_ylabel('Angular Velocity (deg/s)')
    ax2.set_title('Gyroscope Data')
    ax2.grid(True)
    ax2.legend()
    
    # Adjust layout to prevent overlap
    plt.tight_layout()
    
    return fig

def main():
    try:
        # Load the data
        df = load_latest_imu_data()
        
        # Create the plot
        fig = plot_imu_data(df)
        
        # Save the plot
        timestamp = df['timestamp(ms)'].iloc[-1]
        plt.savefig(f'imu_plot_{timestamp}.png', dpi=300, bbox_inches='tight')
        print(f"Plot saved as: imu_plot_{timestamp}.png")
        
        # Display the plot
        plt.show()
        
    except FileNotFoundError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
