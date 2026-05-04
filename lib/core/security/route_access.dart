import '../models/user.dart';
import '../models/user_role.dart';

/// Roles con acceso administrativo pleno a módulos de gestión.
const adminRouteRoles = {UserRole.superadmin, UserRole.admin};

/// Roles autorizados para operar el módulo de asistencia.
const attendanceRouteRoles = {
  UserRole.superadmin,
  UserRole.admin,
  UserRole.operadorAsistencia,
};

/// Solo superadmin (configuración global sensible).
const superAdminRouteRoles = {UserRole.superadmin};

enum RouteAccessDecision { loading, loginRequired, allowed, denied }

RouteAccessDecision resolveProtectedRouteAccess({
  required bool isLoading,
  required bool isSignedIn,
  required AppUser? user,
  Set<UserRole>? allowedRoles,
}) {
  if (isLoading) {
    return RouteAccessDecision.loading;
  }

  if (!isSignedIn || user == null) {
    return RouteAccessDecision.loginRequired;
  }

  if (allowedRoles == null || allowedRoles.contains(user.role)) {
    return RouteAccessDecision.allowed;
  }

  return RouteAccessDecision.denied;
}
