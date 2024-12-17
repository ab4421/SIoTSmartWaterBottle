import Foundation
import CoreBluetooth
import UIKit // Import UIKit to access UIApplication notifications

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Shared instance
    static let shared = BLEManager()

    // Published variables
    @Published var isConnected = false
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var gyroX: Double = 0.0
    @Published var gyroY: Double = 0.0
    @Published var gyroZ: Double = 0.0
    @Published var volume: String = "0.0 mL"
    @Published var uprightStatus: String = "Not Upright"
    @Published var totalIntake: Double = 0.0 {
        didSet {
            saveData()
            // Update notification manager when water is consumed
            NotificationManager.shared.updateLastIntakeHour()
        }
    }
    @Published var currentVolume: Double = 0.0
    @Published var refillAmount: Double = 0.0
    @Published var isRefillMode: Bool = false

    private var previousVolume: Double = 0.0

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var calibrateCharacteristic: CBCharacteristic?

    private let imuServiceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let accelCharacteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef1")
    private let gyroCharacteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef2")
    private let scaleCharacteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef3")
    private let uprightCharacteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef4")
    private let calibrateCharacteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef5") // UUID for calibration, calculate, and refill commands

    // Command values
    private let COMMAND_CALIBRATE: UInt8 = 1
    private let COMMAND_CALCULATE: UInt8 = 2
    private let COMMAND_REFILL: UInt8 = 3

    // Add this property to track the last saved date
    private var lastSavedDate: Date {
        get {
            UserDefaults.standard.object(forKey: "lastSavedDate") as? Date ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSavedDate")
        }
    }

    // Make the initializer private to enforce singleton usage
    private override init() {
        super.init()
        // Initialize central manager with restoration identifier for background functionality
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.yourapp.identifier"])
        loadData()
        scheduleMidnightReset()
        setupAppLifecycleObservers()
    }

    deinit {
        removeAppLifecycleObservers()
    }

    // MARK: - App Lifecycle Observers

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillEnterForeground() {
        print("App will enter foreground")
        // Reload data and update properties
        loadData()
        // Optionally, reconnect to peripheral if needed
        if !isConnected {
            startScanning()
        }
    }

    @objc private func appDidEnterBackground() {
        print("App did enter background")
        // Save current data
        saveData()
    }

    // MARK: - CBCentralManagerDelegate Methods

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on. Scanning for peripherals.")
            startScanning()
        } else {
            print("Bluetooth not available.")
            isConnected = false
        }
    }

    func startScanning() {
        centralManager.scanForPeripherals(withServices: [imuServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true)])
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        print("Central Manager will restore state")
        // Restore peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                self.peripheral = peripheral
                self.peripheral?.delegate = self
                if peripheral.state == .connected {
                    self.isConnected = true
                } else {
                    // Attempt to reconnect
                    centralManager.connect(peripheral, options: nil)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        isConnected = true
        peripheral.discoverServices([imuServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral")
        isConnected = false
        // Attempt to reconnect
        centralManager.connect(peripheral, options: nil)
    }

    // MARK: - CBPeripheralDelegate Methods

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == imuServiceUUID {
                print("Discovered IMU service")
                peripheral.discoverCharacteristics([accelCharacteristicUUID, gyroCharacteristicUUID, scaleCharacteristicUUID, uprightCharacteristicUUID, calibrateCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                switch characteristic.uuid {
                case accelCharacteristicUUID:
                    print("Found Accelerometer Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                case gyroCharacteristicUUID:
                    print("Found Gyroscope Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                case scaleCharacteristicUUID:
                    print("Found Scale Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                case uprightCharacteristicUUID:
                    print("Found Upright Status Characteristic")
                    peripheral.setNotifyValue(true, for: characteristic)
                case calibrateCharacteristicUUID:
                    print("Found Calibrate/Calculate/Refill Characteristic")
                    calibrateCharacteristic = characteristic
                default:
                    break
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, let dataString = String(data: value, encoding: .utf8) {
            DispatchQueue.main.async {
                switch characteristic.uuid {
                case self.accelCharacteristicUUID:
                    let values = dataString.split(separator: ",").map { Double($0) ?? 0.0 }
                    self.accelX = values.count > 0 ? values[0] : 0.0
                    self.accelY = values.count > 1 ? values[1] : 0.0
                    self.accelZ = values.count > 2 ? values[2] : 0.0
                case self.gyroCharacteristicUUID:
                    let values = dataString.split(separator: ",").map { Double($0) ?? 0.0 }
                    self.gyroX = values.count > 0 ? values[0] : 0.0
                    self.gyroY = values.count > 1 ? values[1] : 0.0
                    self.gyroZ = values.count > 2 ? values[2] : 0.0
                case self.scaleCharacteristicUUID:
                    if let newVolume = Double(dataString.components(separatedBy: " ").first ?? "") {
                        self.currentVolume = newVolume

                        // Check for volume increase or decrease
                        let volumeChange = newVolume - self.previousVolume

                        if self.isRefillMode {
                            // If in refill mode, do not increment total intake
                            print("Refill mode active. Ignoring volume changes for total intake.")
                        } else {
                            if volumeChange < -5.0 { // Volume decreased (drank water), threshold to ignore small fluctuations
                                // Increment total intake
                                self.totalIntake += abs(volumeChange)
                                print("Water intake increased by \(abs(volumeChange)) mL")
                                self.saveData()
                            } else if volumeChange > 100.0 {
                                // Significant volume increase detected
                                self.promptRefillAlert()
                            } else {
                                // Ignore small increases
                                print("Volume change insignificant")
                            }
                        }

                        self.previousVolume = newVolume
                    }
                case self.uprightCharacteristicUUID:
                    self.uprightStatus = dataString
                default:
                    break
                }
            }
        }
    }

    // MARK: - Command Methods

    // Function to send calibration command
    func sendCalibrationCommand() {
        if let calibrateCharacteristic = calibrateCharacteristic {
            print("Sending calibration command")
            let command: UInt8 = COMMAND_CALIBRATE // Command to trigger calibration
            let data = Data([command])
            peripheral?.writeValue(data, for: calibrateCharacteristic, type: .withResponse)
        } else {
            print("Calibrate characteristic not found")
        }
    }

    // Function to send calculate command
    func sendCalculateCommand() {
        if let calibrateCharacteristic = calibrateCharacteristic {
            print("Sending calculate command")
            let command: UInt8 = COMMAND_CALCULATE // Command to trigger calculation
            let data = Data([command])
            peripheral?.writeValue(data, for: calibrateCharacteristic, type: .withResponse)
        } else {
            print("Calibrate characteristic not found")
        }
    }

    // Function to send refill command
    func sendRefillCommand() {
        if let calibrateCharacteristic = calibrateCharacteristic {
            print("Sending refill command")
            let command: UInt8 = COMMAND_REFILL // Command to trigger refill mode
            let data = Data([command])
            peripheral?.writeValue(data, for: calibrateCharacteristic, type: .withResponse)

            // Toggle refill mode
            self.isRefillMode.toggle()

            if self.isRefillMode {
                // Entering refill mode
                print("Entered refill mode.")
            } else {
                // Exiting refill mode, save refill amount
                self.refillAmount = self.currentVolume
                self.saveData()
                print("Exited refill mode. Refill amount updated to \(self.refillAmount) mL.")
            }
        } else {
            print("Calibrate characteristic not found")
        }
    }

    // Function to prompt refill alert
    func promptRefillAlert() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefillAlert"), object: nil)
        }
    }

    // Data persistence methods
    func saveData() {
        let defaults = UserDefaults.standard
        defaults.set(self.totalIntake, forKey: "totalIntake")
        defaults.set(self.refillAmount, forKey: "refillAmount")
        defaults.set(self.currentVolume, forKey: "currentVolume")
        // Save the current date
        self.lastSavedDate = Date()
        print("Data saved: totalIntake = \(self.totalIntake), lastSavedDate = \(self.lastSavedDate)")
    }

    func loadData() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        
        // Check if the saved data is from today
        if calendar.isDateInToday(self.lastSavedDate) {
            self.totalIntake = defaults.double(forKey: "totalIntake")
        } else {
            // If it's a new day, reset totalIntake
            self.totalIntake = 0.0
        }
        
        self.refillAmount = defaults.double(forKey: "refillAmount")
        self.currentVolume = defaults.double(forKey: "currentVolume")
        self.previousVolume = self.currentVolume
        print("Data loaded: totalIntake = \(self.totalIntake), lastSavedDate = \(self.lastSavedDate)")
    }

    func scheduleMidnightReset() {
        let now = Date()
        let calendar = Calendar.current
        var midnight = calendar.startOfDay(for: now)
        midnight = calendar.date(byAdding: .day, value: 1, to: midnight)!

        let timeInterval = midnight.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            self.totalIntake = 0.0
            self.saveData()
            self.scheduleMidnightReset() // Schedule next reset
        }
    }
}
