const express = require('express');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON bodies from frontend requests
app.use(express.json());
app.use(cors());

// Serve the HTML dashboard from the 'public' folder
app.use(express.static(path.join(__dirname, 'public')));

// --- MOCK DATABASE & HARDWARE STATE ---
// In a real project, this would be a MySQL/PostgreSQL database or MongoDB
let isLocked = true; 

let accessLogs = [
    { user: "Admin", type: "dashboard", event: "System Initialized", time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute:'2-digit' }), success: true }
];

// Helper function to add logs
function addLog(user, type, event, success) {
    const time = new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute:'2-digit' });
    accessLogs.unshift({ user, type, event, time, success }); // Add to beginning of array
    if (accessLogs.length > 50) accessLogs.pop(); // Keep only latest 50 logs
}

// --- API ENDPOINTS FOR FRONTEND DASHBOARD ---

// 1. Toggle Lock State (Dashboard Button)
app.post('/api/toggle-lock', (req, res) => {
    const { command } = req.body; // 'lock' or 'unlock'
    
    // --> HARDWARE INTEGRATION POINT: <--
    // Here is where you tell the Arduino to move the motor.
    // If using Serial: serialPort.write(command === 'unlock' ? 'U' : 'L');
    // If using ESP32/WiFi: fetch('http://<ESP32_IP>/lock?state=' + command);
    
    console.log(`[SERVER] Received command from dashboard: ${command}`);
    
    if (command === 'unlock') {
        isLocked = false;
        addLog("Admin Dashboard", "dashboard", "Remote Unlocked", true);
    } else {
        isLocked = true;
        addLog("Admin Dashboard", "dashboard", "Remote Locked", true);
    }
    
    // Respond back to HTML dashboard that it was successful
    res.json({ success: true, isLocked: isLocked });
});

// 2. Get Current Lock Status
app.get('/api/status', (req, res) => {
    // This allows the dashboard to sync if someone unlocks the door physically 
    // using an RFID card or Fingerprint directly at the door.
    res.json({ success: true, isLocked: isLocked });
});

// 3. Get Access Logs
app.get('/api/logs', (req, res) => {
    // Send the logs to the dashboard to display in the table
    res.json({ success: true, logs: accessLogs });
});

// 4. Trigger Enroll Mode (Add new Fingerprint/RFID)
app.post('/api/enroll-mode', (req, res) => {
    // --> HARDWARE INTEGRATION POINT: <--
    // Send a command to Arduino to enter 'Enroll Mode'
    // serialPort.write('E'); 
    
    console.log("[SERVER] Arduino put into Enroll Mode");
    addLog("System", "dashboard", "Enrollment Mode Activated", true);
    res.json({ success: true });
});

// --- API ENDPOINTS FOR ARDUINO/ESP32 TO CALL ---

// If your ESP32 reads an RFID card, it should call this endpoint to log it
app.post('/api/hardware/scan', (req, res) => {
    const { sensor, id, authorized } = req.body; 
    // Example payload from ESP32: { "sensor": "rfid", "id": "A1B2C3D4", "authorized": true }
    
    console.log(`[HARDWARE] Scan received from ${sensor}: ID ${id} - Authorized: ${authorized}`);
    
    if(authorized) {
        isLocked = false; // Door opens
        addLog(`User (${id})`, sensor, "Access Granted", true);
    } else {
        addLog(`Unknown (${id})`, sensor, "Access Denied", false);
    }
    
    res.json({ received: true });
});

// --- START SERVER ---
app.listen(PORT, () => {
    console.log(`========================================`);
    console.log(`🚀 Smart Lock IoT Server is running!`);
    console.log(`🌐 Dashboard available at: http://localhost:${PORT}`);
    console.log(`========================================`);
});