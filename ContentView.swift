import SwiftUI
import CoreBluetooth

// MARK: - Bluetooth Manager
class BluetoothManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var connectedDevices: [CBPeripheral] = []
    @Published var error: String?
    
    private var centralManager: CBCentralManager!
    private let serviceUUID = CBUUID(string: "180D") // Standard Heart Rate Service UUID
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            error = "Bluetooth is not powered on"
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to device: CBPeripheral) {
        centralManager.connect(device, options: nil)
    }
    
    func disconnect(from device: CBPeripheral) {
        centralManager.cancelPeripheralConnection(device)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            error = nil
        case .poweredOff:
            error = "Bluetooth is powered off"
        case .unauthorized:
            error = "Bluetooth permission denied"
        case .unsupported:
            error = "Bluetooth is not supported"
        default:
            error = "Bluetooth is not available"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if !connectedDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedDevices.append(peripheral)
        }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDevices.removeAll { $0.identifier == peripheral.identifier }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.error = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            self.error = "Error discovering services: \(error!.localizedDescription)"
            return
        }
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            self.error = "Error discovering characteristics: \(error!.localizedDescription)"
            return
        }
        
        // Handle discovered characteristics
        service.characteristics?.forEach { characteristic in
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            self.error = "Error receiving data: \(error!.localizedDescription)"
            return
        }
        
        // Handle received data
        if let data = characteristic.value {
            // Process the received data
            print("Received data: \(data)")
        }
    }
}

// MARK: - Animated Background
struct AnimatedHealthBackground: View {
    @State private var animateGradient = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.15),
                    Color(red: 0.15, green: 0.15, blue: 0.18)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            
            // Animated circles
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.75, green: 0.75, blue: 0.78).opacity(0.1),
                                Color(red: 0.85, green: 0.85, blue: 0.88).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200 + CGFloat(index * 50))
                    .offset(x: animateGradient ? 50 : -50, y: animateGradient ? -30 : 30)
                    .scaleEffect(pulseScale)
                    .opacity(0.3)
                    .animation(
                        Animation.easeInOut(duration: 4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.5),
                        value: animateGradient
                    )
            }
            
            // Health icon
            Image(systemName: "heart.text.square.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100)
                .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78).opacity(0.1))
                .rotationEffect(.degrees(animateGradient ? 5 : -5))
                .animation(
                    Animation.easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                    value: animateGradient
                )
        }
        .onAppear {
            animateGradient = true
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 0.85, blue: 0.88),
                        Color(red: 0.65, green: 0.65, blue: 0.68)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color(red: 0.15, green: 0.15, blue: 0.18))
            .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.75, green: 0.75, blue: 0.78), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers
extension View {
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedHealthBackground()
                
                VStack(spacing: 20) {
                    Text("Welcome to Double")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your Digital Twin Platform")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Get Started")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .primaryButton()
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Learn More")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .secondaryButton()
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}

struct DevicesView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showAddDevice = false
    @State private var showPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.15)
                    .ignoresSafeArea()
                
                if bluetoothManager.error == "Bluetooth permission denied" {
                    VStack(spacing: 20) {
                        Image(systemName: "bluetooth")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                            .opacity(0.5)
                        
                        Text("Bluetooth Access Required")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Please enable Bluetooth access in Settings to connect to devices")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                } else if bluetoothManager.error == "Bluetooth is powered off" {
                    VStack(spacing: 20) {
                        Image(systemName: "bluetooth.slash")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                            .opacity(0.5)
                        
                        Text("Bluetooth is Turned Off")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Please turn on Bluetooth in Settings to connect to devices")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                } else if bluetoothManager.isScanning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Color(red: 0.75, green: 0.75, blue: 0.78))
                        
                        Text("Searching for devices...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                } else if bluetoothManager.connectedDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                            .opacity(0.5)
                        
                        Text("No Devices Connected")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Tap + to search for devices")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(bluetoothManager.connectedDevices, id: \.identifier) { device in
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(device.name ?? "Unknown Device")
                                        .foregroundColor(.white)
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    bluetoothManager.disconnect(from: device)
                                }) {
                                    Text("Disconnect")
                                        .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bluetoothManager.error == nil {
                        Button(action: {
                            showAddDevice = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddDevice) {
                AddDeviceView(isPresented: $showAddDevice, bluetoothManager: bluetoothManager)
            }
            .alert("Bluetooth Error", isPresented: .constant(bluetoothManager.error != nil && bluetoothManager.error != "Bluetooth permission denied" && bluetoothManager.error != "Bluetooth is powered off")) {
                Button("OK") {
                    bluetoothManager.error = nil
                }
            } message: {
                Text(bluetoothManager.error ?? "")
            }
        }
    }
}

struct AddDeviceView: View {
    @Binding var isPresented: Bool
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var searchText = ""
    
    var filteredDevices: [CBPeripheral] {
        if searchText.isEmpty {
            return bluetoothManager.discoveredDevices
        }
        return bluetoothManager.discoveredDevices.filter { 
            ($0.name ?? "").lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search devices", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .cornerRadius(10)
                    .padding()
                    
                    // Device list
                    List {
                        ForEach(filteredDevices, id: \.identifier) { device in
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(device.name ?? "Unknown Device")
                                        .foregroundColor(.white)
                                    Text("Available")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    bluetoothManager.connect(to: device)
                                    isPresented = false
                                }) {
                                    Text("Connect")
                                        .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                }
            }
            .onAppear {
                bluetoothManager.startScanning()
            }
            .onDisappear {
                bluetoothManager.stopScanning()
            }
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct DigitalTwinView: View {
    @State private var messages: [Message] = []
    @State private var newMessage: String = ""
    @State private var isProcessing: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack {
                    // Chat messages
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding()
                    }
                    
                    // Input area
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $newMessage)
                                .padding(12)
                                .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                                .cornerRadius(20)
                                .foregroundColor(.white)
                            
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(newMessage.isEmpty ? .gray : Color(red: 0.75, green: 0.75, blue: 0.78))
                            }
                            .disabled(newMessage.isEmpty || isProcessing)
                        }
                        .padding()
                    }
                    .background(Color(red: 0.12, green: 0.12, blue: 0.15))
                }
            }
            .navigationTitle("Digital Twin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: clearChat) {
                        Image(systemName: "trash")
                            .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        let userMessage = Message(content: newMessage, isUser: true, timestamp: Date())
        messages.append(userMessage)
        
        isProcessing = true
        newMessage = ""
        
        // Simulate LLM response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = generateResponse(to: userMessage.content)
            let aiMessage = Message(content: response, isUser: false, timestamp: Date())
            messages.append(aiMessage)
            isProcessing = false
        }
    }
    
    private func clearChat() {
        messages.removeAll()
    }
    
    private func generateResponse(to message: String) -> String {
        // Simple response generation logic
        let lowercasedMessage = message.lowercased()
        
        if lowercasedMessage.contains("hello") || lowercasedMessage.contains("hi") {
            return "Hello! I'm your digital twin assistant. How can I help you today?"
        } else if lowercasedMessage.contains("how are you") {
            return "I'm functioning well and ready to assist you with your health and wellness goals."
        } else if lowercasedMessage.contains("help") {
            return "I can help you with:\n• Health monitoring\n• Device connections\n• Data analysis\n• Personalized recommendations"
        } else if lowercasedMessage.contains("thank") {
            return "You're welcome! Is there anything else you'd like to know?"
        } else {
            return "I understand you're asking about '\(message)'. As your digital twin, I'm here to help you achieve your health and wellness goals. Could you please provide more specific details about what you'd like to know?"
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(red: 0.15, green: 0.15, blue: 0.18))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account").foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))) {
                    SettingsRow(title: "Profile", icon: "person.fill")
                    SettingsRow(title: "Preferences", icon: "gear")
                    SettingsRow(title: "Security", icon: "lock.shield.fill")
                }
                
                Section(header: Text("System").foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))) {
                    SettingsRow(title: "Notifications", icon: "bell.fill")
                    SettingsRow(title: "Privacy", icon: "hand.raised.fill")
                    SettingsRow(title: "About", icon: "info.circle.fill")
                }
            }
            .listStyle(PlainListStyle())
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .navigationTitle("Settings")
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                .font(.title3)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
        }
        .padding(.vertical, 8)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "iphone.and.arrow.forward")
                }
            
            DigitalTwinView()
                .tabItem {
                    Label("Digital Twin", systemImage: "person.2.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(Color(red: 0.75, green: 0.75, blue: 0.78))
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
} 
