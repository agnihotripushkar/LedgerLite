import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Events ---
abstract class AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class AuthenticateUser extends AuthEvent {}

class ToggleAppLock extends AuthEvent {
  final bool enable;
  ToggleAppLock(this.enable);
}

class LockApp extends AuthEvent {}

// --- States ---
abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}

class AuthLocked extends AuthState {
  final String? errorMessage;
  const AuthLocked({this.errorMessage});
}

class AuthUnlocked extends AuthState {}

class AuthConfigured extends AuthState {
  final bool isLockEnabled;
  final bool hasBiometrics;
  const AuthConfigured({required this.isLockEnabled, required this.hasBiometrics});
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LocalAuthentication _localAuth;
  static const String _lockEnabledKey = 'biometric_lock_enabled';

  AuthBloc({LocalAuthentication? localAuth}) 
      : _localAuth = localAuth ?? LocalAuthentication(),
        super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<AuthenticateUser>(_onAuthenticateUser);
    on<ToggleAppLock>(_onToggleAppLock);
    on<LockApp>(_onLockApp);
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool(_lockEnabledKey) ?? false;

    if (isLockEnabled) {
      emit(AuthLocked());
    } else {
      emit(AuthUnlocked());
    }
  }

  Future<void> _onAuthenticateUser(AuthenticateUser event, Emitter<AuthState> emit) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access LedgerLite',
        biometricOnly: false, // fallback to pin/passcode
      );

      if (authenticated) {
        emit(AuthUnlocked());
      } else {
        emit(const AuthLocked(errorMessage: 'Authentication failed. Please try again.'));
      }
    } catch (e) {
      emit(AuthLocked(errorMessage: 'Error during authentication: ${e.toString()}'));
    }
  }

  Future<void> _onToggleAppLock(ToggleAppLock event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, event.enable);
    
    final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
    final hasBiometrics = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
    
    emit(AuthConfigured(
      isLockEnabled: event.enable,
      hasBiometrics: hasBiometrics,
    ));
  }

  Future<void> _onLockApp(LockApp event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool(_lockEnabledKey) ?? false;
    if (isLockEnabled) {
      emit(AuthLocked());
    }
  }

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledKey) ?? false;
  }
  
  Future<bool> hasBiometrics() async {
    final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
    return canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
  }
}
