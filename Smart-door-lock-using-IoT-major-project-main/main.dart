import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';

// ==========================================
// MOCK IOT BACKEND SERVICE
// ==========================================
class IoTBackendService {
  static Future<Map<String, String>> fetchDeviceHealth() async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'battery': '100%',
      'wifi': 'Strong',
      'gsm': 'LTE/2G',
      'firmware': 'v2.4.2',
    };
  }

  static Future<bool> saveSetting(String settingName, dynamic value) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return true;
  }

  static Future<String> triggerGsmOtp() async {
    await Future.delayed(const Duration(seconds: 2));
    return "7890";
  }

  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      {
        'event': 'Fingerprint Unlock',
        'time': '10:15 AM',
        'user': 'User 1 (Admin)',
        'isError': false,
      },
      {
        'event': 'Face Match Unlock',
        'time': '09:42 AM',
        'user': 'User 2',
        'isError': false,
      },
      {
        'event': 'Failed Keypad Attempt',
        'time': '08:30 AM',
        'user': 'Alert',
        'isError': true,
      },
      {
        'event': 'GSM SMS Alert Sent',
        'time': '08:30 AM',
        'user': 'System Alert',
        'isError': true,
      },
      {
        'event': 'NFC Key Unlock',
        'time': 'Yesterday, 6:00 PM',
        'user': 'Cleaning Service',
        'isError': false,
      },
      {
        'event': 'Master PIN Override',
        'time': 'Yesterday, 2:15 PM',
        'user': 'User 1 (Admin)',
        'isError': false,
      },
    ];
  }

  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      {
        'name': 'Master Admin (You)',
        'role': 'Admin',
        'access': 'All Methods',
        'icon': Icons.person,
      },
      {
        'name': 'Cleaning Service',
        'role': 'Guest',
        'access': 'PIN • Mon-Fri 9AM-5PM',
        'icon': Icons.person_outline,
      },
      {
        'name': 'Temporary Guest',
        'role': 'Guest',
        'access': 'OTP • Expires in 2 hrs',
        'icon': Icons.timer_outlined,
      },
    ];
  }
}

// ==========================================
// GLOBAL STATE (Local Cache)
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(
  const Color(0xFFD4AF37),
);
final ValueNotifier<int> autoLockDelayNotifier = ValueNotifier(5);
final ValueNotifier<bool> hapticFeedbackNotifier = ValueNotifier(true);
final ValueNotifier<bool> twoFactorAuthNotifier = ValueNotifier(false);
final ValueNotifier<bool> lockdownModeNotifier = ValueNotifier(false);

void main() {
  runApp(const SmartDoorApp());
}

class SmartDoorApp extends StatelessWidget {
  const SmartDoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: primaryColorNotifier,
          builder: (context, currentColor, child) {
            return MaterialApp(
              title: 'Smart Door Lock',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: _buildTheme(Brightness.light, currentColor),
              darkTheme: _buildTheme(Brightness.dark, currentColor),
              home: const DashboardScreen(),
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness, Color primary) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0D0D14)
          : const Color(0xFFF4F4F6),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.0,
        ),
      ),
      cardColor: isDark ? const Color(0xFF161622) : Colors.white,
      useMaterial3: true,
    );
  }
}

// ==========================================
// DASHBOARD SCREEN
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isLocked = true;
  bool isConnected = false;
  bool isConnecting = true;
  UsbPort? _port;

  @override
  void initState() {
    super.initState();
    _initHardwareConnection();
  }

  // UPDATED: USB Connection with Permission Check
  Future<void> _initHardwareConnection() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      if (devices.isNotEmpty) {
        UsbDevice device = devices[0];

        // App ko permission grant karne ka dialog show karega
        bool? allowed = await device.requestPermission();

        if (allowed == true) {
          _port = await device.create();
          bool openResult = await _port!.open();

          if (openResult) {
            await _port!.setDTR(true);
            await _port!.setRTS(true);
            await _port!.setPortParameters(
              9600,
              UsbPort.DATABITS_8,
              UsbPort.STOPBITS_1,
              UsbPort.PARITY_NONE,
            );

            if (mounted) {
              setState(() {
                isConnected = true;
                isConnecting = false;
              });
            }
            return;
          }
        } else {
          if (mounted)
            _showSnackBar('USB Permission Denied!', Colors.redAccent);
        }
      }
    } catch (e) {
      print("USB Connection Error: $e");
    }

    if (mounted) {
      setState(() {
        isConnected = false;
        isConnecting = false;
      });
      _showSnackBar(
        'Hardware Not Connected. Check OTG Cable.',
        Colors.orangeAccent,
      );
    }
  }

  // UPDATED: Safe Hardware Communication
  void unlockDoor(String method) async {
    if (!isConnected || _port == null) {
      _showSnackBar('Hardware Offline!', Colors.redAccent);
      return;
    }
    if (lockdownModeNotifier.value && method != 'Master Override') {
      _showSnackBar('Lockdown Mode Active. Access Denied.', Colors.redAccent);
      return;
    }

    try {
      // 1 = Unlock signal
      await _port!.write(Uint8List.fromList('1'.codeUnits));

      setState(() => isLocked = false);
      _showSnackBar(
        'Door Unlocked via $method',
        Theme.of(context).colorScheme.primary,
      );

      Timer(Duration(seconds: autoLockDelayNotifier.value), () async {
        if (_port != null) {
          // 0 = Lock signal
          await _port!.write(Uint8List.fromList('0'.codeUnits));
        }
        if (mounted) setState(() => isLocked = true);
      });
    } catch (e) {
      _showSnackBar('Failed to send signal to Hardware.', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isConnecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 20),
              const Text(
                'Connecting to Smart Lock...',
                style: TextStyle(letterSpacing: 1.5, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('S M A R T  D O O R'),
        leading: Icon(
          isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: isConnected ? primaryColor : Colors.redAccent,
          size: 20,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: lockdownModeNotifier,
        builder: (context, isLockdown, child) {
          return Column(
            children: [
              if (isLockdown)
                Container(
                  width: double.infinity,
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'LOCKDOWN MODE ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // Status Section
              Container(
                padding: const EdgeInsets.only(top: 20, bottom: 40),
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isLocked
                                              ? Colors.redAccent
                                              : primaryColor)
                                          .withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).cardColor,
                              border: Border.all(
                                color:
                                    (isLocked ? Colors.redAccent : primaryColor)
                                        .withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black45
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                isLocked
                                    ? Icons.lock_outline_rounded
                                    : Icons.lock_open_rounded,
                                key: ValueKey<bool>(isLocked),
                                size: 45,
                                color: isLocked
                                    ? Colors.redAccent
                                    : primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isLocked ? 'L O C K E D' : 'U N L O C K E D',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        color: isLocked ? Colors.redAccent : primaryColor,
                        letterSpacing: 4,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: isLocked ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: ValueListenableBuilder<int>(
                        valueListenable: autoLockDelayNotifier,
                        builder: (context, delay, child) => Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            'Auto-locking in ${delay}s...',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Access Methods',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Access Grid
              Expanded(
                child: Opacity(
                  opacity: isLockdown ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: isLockdown,
                    child: GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.15,
                      children: [
                        _UnlockCard(
                          title: 'Keypad PIN',
                          icon: Icons.dialpad_rounded,
                          onTap: () => _openScreen(
                            context,
                            PinUnlockScreen(
                              onUnlock: () => unlockDoor('Keypad PIN'),
                            ),
                          ),
                        ),
                        _UnlockCard(
                          title: 'Fingerprint',
                          icon: Icons.fingerprint_rounded,
                          onTap: () => _openScreen(
                            context,
                            BiometricUnlockScreen(
                              type: 'Fingerprint',
                              onUnlock: () => unlockDoor('Fingerprint'),
                            ),
                          ),
                        ),
                        _UnlockCard(
                          title: 'Face Match',
                          icon: Icons.face_retouching_natural_rounded,
                          onTap: () => _openScreen(
                            context,
                            BiometricUnlockScreen(
                              type: 'Face',
                              onUnlock: () => unlockDoor('Face Match'),
                            ),
                          ),
                        ),
                        _UnlockCard(
                          title: 'NFC Key',
                          icon: Icons.nfc_rounded,
                          onTap: () => _openScreen(
                            context,
                            RfidUnlockScreen(
                              onUnlock: () => unlockDoor('NFC Key'),
                            ),
                          ),
                        ),
                        _UnlockCard(
                          title: 'Bluetooth',
                          icon: Icons.bluetooth_rounded,
                          onTap: () => _openScreen(
                            context,
                            BluetoothUnlockScreen(
                              onUnlock: () => unlockDoor('Bluetooth'),
                            ),
                          ),
                        ),
                        _UnlockCard(
                          title: 'One-Time Pass',
                          icon: Icons.password_rounded,
                          onTap: () => _openScreen(
                            context,
                            OtpUnlockScreen(onUnlock: () => unlockDoor('OTP')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
}

class _UnlockCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _UnlockCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: primaryColor.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black26
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 28, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ASYNCHRONOUS SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isSaving = false;
  Map<String, String> deviceHealth = {
    'battery': '--',
    'wifi': '--',
    'gsm': '--',
    'firmware': '--',
  };
  bool isLoadingHealth = true;

  @override
  void initState() {
    super.initState();
    _fetchDeviceHealth();
  }

  Future<void> _fetchDeviceHealth() async {
    final health = await IoTBackendService.fetchDeviceHealth();
    if (mounted) {
      setState(() {
        deviceHealth = health;
        isLoadingHealth = false;
      });
    }
  }

  Future<void> _handleSettingUpdate(
    String settingKey,
    dynamic value,
    ValueNotifier notifier,
  ) async {
    setState(() => isSaving = true);
    bool success = await IoTBackendService.saveSetting(settingKey, value);
    if (success && mounted) {
      notifier.value = value;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Setting saved successfully.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S E T T I N G S')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              _buildHardwareStatusCard(context),
              const SizedBox(height: 30),

              _SectionHeader(title: 'Security & Access'),
              _buildSettingsBlock(context, [
                _SettingsTile(
                  icon: Icons.history_rounded,
                  title: 'Activity Logs',
                  subtitle: 'View recent unlock history',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActivityLogsScreen(),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.group_outlined,
                  title: 'Manage Users & Access',
                  subtitle: 'Add fingerprints, faces, and guest PINs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: twoFactorAuthNotifier,
                  builder: (context, value, _) => _SwitchTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Require PIN + Biometric',
                    value: value,
                    onChanged: (val) =>
                        _handleSettingUpdate('2FA', val, twoFactorAuthNotifier),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: lockdownModeNotifier,
                  builder: (context, value, _) => _SwitchTile(
                    icon: Icons.lock_clock_outlined,
                    title: 'Emergency Lockdown',
                    subtitle: 'Disable all access except Master PIN',
                    value: value,
                    isDestructive: true,
                    isLast: true,
                    onChanged: (val) => _handleSettingUpdate(
                      'Lockdown',
                      val,
                      lockdownModeNotifier,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 25),
              _SectionHeader(title: 'Device Configuration'),
              _buildSettingsBlock(context, [
                ValueListenableBuilder<int>(
                  valueListenable: autoLockDelayNotifier,
                  builder: (context, value, _) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Auto-Lock Delay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${value}s',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: value.toDouble(),
                          min: 3,
                          max: 30,
                          divisions: 27,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) =>
                              autoLockDelayNotifier.value = val.toInt(),
                          onChangeEnd: (val) => _handleSettingUpdate(
                            'AutoLock',
                            val.toInt(),
                            autoLockDelayNotifier,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ValueListenableBuilder<bool>(
                  valueListenable: hapticFeedbackNotifier,
                  builder: (context, value, _) => _SwitchTile(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Vibrate on keypad press',
                    value: value,
                    onChanged: (val) => _handleSettingUpdate(
                      'Haptics',
                      val,
                      hapticFeedbackNotifier,
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Door Chime Volume',
                  subtitle: 'Medium',
                  isLast: true,
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 25),
              _SectionHeader(title: 'Appearance (Local)'),
              _buildSettingsBlock(context, [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, child) => _SwitchTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: 'Switch between Light/Dark',
                    value: mode == ThemeMode.dark,
                    onChanged: (val) => themeNotifier.value = val
                        ? ThemeMode.dark
                        : ThemeMode.light,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accent Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildColorSelector(context),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),

          if (isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: isLoadingHealth
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: CircularProgressIndicator(),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatusItem(
                  icon: Icons.battery_charging_full_rounded,
                  value: deviceHealth['battery']!,
                  label: 'Battery',
                  color: Colors.green,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: primaryColor.withValues(alpha: 0.3),
                ),
                _StatusItem(
                  icon: Icons.wifi_rounded,
                  value: deviceHealth['wifi']!,
                  label: 'ESP32 Wi-Fi',
                  color: primaryColor,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: primaryColor.withValues(alpha: 0.3),
                ),
                _StatusItem(
                  icon: Icons.cell_tower_rounded,
                  value: deviceHealth['gsm']!,
                  label: 'GSM Signal',
                  color: Colors.blueAccent,
                ),
              ],
            ),
    );
  }

  Widget _buildSettingsBlock(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black12
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildColorSelector(BuildContext context) {
    final List<Color> colors = [
      const Color(0xFFD4AF37),
      const Color(0xFF10B981),
      const Color(0xFF38BDF8),
      const Color(0xFFA855F7),
      const Color(0xFFFB7185),
      const Color(0xFF94A3B8),
    ];
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: colors
          .map(
            (color) => GestureDetector(
              onTap: () => primaryColorNotifier.value = color,
              child: ValueListenableBuilder<Color>(
                valueListenable: primaryColorNotifier,
                builder: (context, selectedColor, child) {
                  bool isSelected = selectedColor == color;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatusItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 1.5,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(icon, color: Theme.of(context).iconTheme.color),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 56),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDestructive;
  final bool isLast;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isDestructive = false,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    final activeColor = isDestructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: Icon(
            icon,
            color: isDestructive
                ? Colors.redAccent
                : Theme.of(context).iconTheme.color,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.redAccent : null,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          value: value,
          activeThumbColor: activeColor,
          activeTrackColor: activeColor.withValues(alpha: 0.5),
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 56),
      ],
    );
  }
}

// ==========================================
// SCREENS WITH REAL-TIME DATA FETCHING
// ==========================================
class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A C T I V I T Y  L O G S')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: IoTBackendService.fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load logs.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No activity found.'));
          }

          final logs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              final isError = log['isError'] as bool;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isError
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  child: Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: isError ? Colors.redAccent : Colors.green,
                  ),
                ),
                title: Text(log['event']),
                subtitle: Text(log['time']),
                trailing: Text(
                  log['user'],
                  style: TextStyle(
                    color: isError ? Colors.redAccent : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('M A N A G E  U S E R S')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: IoTBackendService.fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final users = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  leading: CircleAvatar(child: Icon(user['icon'])),
                  title: Text(user['name']),
                  subtitle: Text(user['access']),
                  trailing: user['role'] == 'Admin'
                      ? const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.blue,
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {},
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// UNLOCK SCREENS
// ==========================================
class PinUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const PinUnlockScreen({super.key, required this.onUnlock});
  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String pin = "";
  final String correctPin = "1234";
  void _addNumber(String num) {
    if (pin.length < 4) {
      setState(() => pin += num);
      if (pin.length == 4)
        Future.delayed(const Duration(milliseconds: 300), _verifyPin);
    }
  }

  void _removeNumber() {
    if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
  }

  void _verifyPin() {
    if (pin == correctPin) {
      widget.onUnlock();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Incorrect PIN',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => pin = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E N T E R  P I N')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please enter your passcode',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool isFilled = index < pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isFilled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 30,
              crossAxisSpacing: 30,
              childAspectRatio: 1.0,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i <= 9; i++)
                  _NumpadButton(text: '$i', onTap: () => _addNumber('$i')),
                const SizedBox.shrink(),
                _NumpadButton(text: '0', onTap: () => _addNumber('0')),
                InkWell(
                  onTap: _removeNumber,
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.backspace_outlined,
                    size: 28,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _NumpadButton({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      highlightColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
          ),
        ),
      ),
    );
  }
}

class BiometricUnlockScreen extends StatefulWidget {
  final String type;
  final VoidCallback onUnlock;
  const BiometricUnlockScreen({
    super.key,
    required this.type,
    required this.onUnlock,
  });
  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen>
    with SingleTickerProviderStateMixin {
  bool isAuthenticating = false;
  late AnimationController _pulseController;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _authenticate() async {
    setState(() => isAuthenticating = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => isAuthenticating = false);
      widget.onUnlock();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 'Face' ? 'F A C E  I D' : 'T O U C H  I D'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: isAuthenticating ? null : _authenticate,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isAuthenticating)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Container(
                        width: 180 + (_pulseController.value * 20),
                        height: 180 + (_pulseController.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    widget.type == 'Face'
                        ? Icons.face_retouching_natural_rounded
                        : Icons.fingerprint_rounded,
                    size: 100,
                    color: isAuthenticating
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Text(
              isAuthenticating ? 'Authenticating...' : 'Tap icon to scan',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RfidUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const RfidUnlockScreen({super.key, required this.onUnlock});
  @override
  State<RfidUnlockScreen> createState() => _RfidUnlockScreenState();
}

class _RfidUnlockScreenState extends State<RfidUnlockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool isScanning = true;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _simulateNfcRead();
  }

  void _simulateNfcRead() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => isScanning = false);
      widget.onUnlock();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('N F C  R E A D E R')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                padding: const EdgeInsets.all(50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: _pulseController.value * 0.5,
                    ),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.nfc_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 60),
            Text(
              isScanning
                  ? 'Hold your key near the device'
                  : 'Successfully Authenticated',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BluetoothUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const BluetoothUnlockScreen({super.key, required this.onUnlock});
  @override
  State<BluetoothUnlockScreen> createState() => _BluetoothUnlockScreenState();
}

class _BluetoothUnlockScreenState extends State<BluetoothUnlockScreen> {
  bool isScanning = true;
  bool isConnecting = false;
  @override
  void initState() {
    super.initState();
    _simulateBluetoothScan();
  }

  void _simulateBluetoothScan() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => isScanning = false);
  }

  void _connectAndUnlock() async {
    setState(() => isConnecting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      widget.onUnlock();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('B L U E T O O T H')),
      body: Center(
        child: isScanning
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Searching for nearby locks...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.bluetooth_connected_rounded,
                      size: 70,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Front Door',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                    ),
                    onPressed: isConnecting ? null : _connectAndUnlock,
                    child: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Connect & Unlock',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class OtpUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const OtpUnlockScreen({super.key, required this.onUnlock});
  @override
  State<OtpUnlockScreen> createState() => _OtpUnlockScreenState();
}

class _OtpUnlockScreenState extends State<OtpUnlockScreen> {
  String enteredOtp = "";
  String generatedOtp = "";
  bool isOtpSent = false;
  bool isRequestingGsm = false;

  void _sendOtp() async {
    setState(() => isRequestingGsm = true);
    String code = await IoTBackendService.triggerGsmOtp();
    if (mounted) {
      setState(() {
        generatedOtp = code;
        isOtpSent = true;
        isRequestingGsm = false;
        enteredOtp = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GSM Module sent SMS: Your code is $generatedOtp'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _addNumber(String num) {
    if (enteredOtp.length < 4) {
      setState(() => enteredOtp += num);
      if (enteredOtp.length == 4)
        Future.delayed(const Duration(milliseconds: 300), _verifyOtp);
    }
  }

  void _removeNumber() {
    if (enteredOtp.isNotEmpty)
      setState(
        () => enteredOtp = enteredOtp.substring(0, enteredOtp.length - 1),
      );
  }

  void _verifyOtp() {
    if (enteredOtp == generatedOtp) {
      widget.onUnlock();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Invalid OTP. Try again.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => enteredOtp = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('O N E  T I M E  P A S S')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 60,
            color: isOtpSent
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade500,
          ),
          const SizedBox(height: 20),
          Text(
            isOtpSent
                ? 'Enter the 4-digit code sent via SMS'
                : 'Request access code to your phone',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 40),

          if (!isOtpSent)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: isRequestingGsm ? null : _sendOtp,
              child: isRequestingGsm
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send SMS via GSM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
            ),

          if (isOtpSent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = index < enteredOtp.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 50,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFilled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    isFilled ? enteredOtp[index] : "",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 25,
                crossAxisSpacing: 25,
                childAspectRatio: 1.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i <= 9; i++)
                    _NumpadButton(text: '$i', onTap: () => _addNumber('$i')),
                  const SizedBox.shrink(),
                  _NumpadButton(text: '0', onTap: () => _addNumber('0')),
                  InkWell(
                    onTap: _removeNumber,
                    customBorder: const CircleBorder(),
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 28,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
