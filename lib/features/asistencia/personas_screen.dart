import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/models/member.dart';
import '../../core/security/route_access.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

class PersonasAsistenciaScreen extends StatefulWidget {
  const PersonasAsistenciaScreen({super.key, this.combinedItemsLoader});

  final Stream<List<Map<String, dynamic>>> Function()? combinedItemsLoader;

  @override
  State<PersonasAsistenciaScreen> createState() =>
      _PersonasAsistenciaScreenState();
}

class _PersonasAsistenciaScreenState extends State<PersonasAsistenciaScreen> {
  MembersService? _membersService;
  AsistenciaService? _asistenciaService;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    if (widget.combinedItemsLoader == null) {
      _membersService = MembersService();
      _asistenciaService = AsistenciaService();
    }
  }

  void _openPersonDetail(Map<String, dynamic> item) {
    if (item['source'] == 'member') {
      final m = item['data'] as Member;
      Navigator.pushNamed(
        context,
        '/asistencia/persona_detalle',
        arguments: m.id,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _PersonaQrDetailContent(
              persona: item['data'] as PersonaAsistencia,
            ),
          ),
        );
      },
    );
  }

  ({int total, int activos, int inactivos}) _statsFor(
    List<Map<String, dynamic>> list,
  ) {
    var activos = 0;
    var inactivos = 0;
    for (final item in list) {
      if (item['source'] == 'member') {
        final m = item['data'] as Member;
        if (m.status == MemberStatus.active) {
          activos++;
        } else {
          inactivos++;
        }
      } else {
        activos++;
      }
    }
    return (total: list.length, activos: activos, inactivos: inactivos);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;
    final canManageMembers = adminRouteRoles.contains(role);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Personas',
            subtitle: 'Socios habilitados',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.sync_rounded,
                  onTap: () => setState(() {}),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Listado combinado: padrón Socios y personas legacy.',
                        ),
                      ),
                    );
                  },
                ),
                if (canManageMembers) ...[
                  const SizedBox(width: 6),
                  VotoCircleIconButton(
                    icon: Icons.group_add_outlined,
                    onTap: () {
                      Navigator.pushNamed(context, '/members');
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              12,
              AppDesignTokens.horizontalPadding,
              8,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar o filtrar registros…',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppDesignTokens.primary.withValues(alpha: 0.65),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.45),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _buildCombinedStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('❌ Error en Stream combinado: ${snap.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? [];
                final stats = _statsFor(list);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignTokens.horizontalPadding,
                        0,
                        AppDesignTokens.horizontalPadding,
                        12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PersonasStatCell(
                              value: '${stats.total}',
                              label: 'Personas',
                              valueColor: AppDesignTokens.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PersonasStatCell(
                              value: '${stats.activos}',
                              label: 'Activos',
                              valueColor: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PersonasStatCell(
                              value: '${stats.inactivos}',
                              label: 'Inactivos',
                              valueColor: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignTokens.horizontalPadding,
                        0,
                        AppDesignTokens.horizontalPadding,
                        12,
                      ),
                      child: Row(
                        children: [
                          if (canManageMembers) ...[
                            Expanded(
                              child: PrimaryButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/members'),
                                label: 'Nueva persona',
                                icon: Icons.add_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Material(
                              color: AppDesignTokens.lavanda,
                              elevation: 0,
                              borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusMedium,
                              ),
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/asistencia/importar_personas',
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDesignTokens.radiusMedium,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.upload_file_rounded,
                                        size: 20,
                                        color: AppDesignTokens.primaryDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Importar lista',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppDesignTokens.primaryDark,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignTokens.horizontalPadding,
                        0,
                        AppDesignTokens.horizontalPadding,
                        8,
                      ),
                      child: Text(
                        'Listado',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppDesignTokens.primaryDark,
                        ),
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _busqueda.isNotEmpty
                                          ? 'No se encontraron resultados'
                                          : 'No hay personas registradas.\n\n'
                                                'Usa Importar lista o gestiona socios.',
                                      textAlign: TextAlign.center,
                                      style: AppDesignTokens.bodyMuted(context),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppDesignTokens.horizontalPadding,
                                0,
                                AppDesignTokens.horizontalPadding,
                                16,
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final item = list[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PersonasListRow(
                                    item: item,
                                    onTap: () => _openPersonDetail(item),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _buildCombinedStream() {
    final loader = widget.combinedItemsLoader;
    if (loader != null) return loader();

    return _membersService!.getAllMembers().asyncExpand((members) {
      return _combinarPersonasYMembers(members).asStream();
    });
  }

  Future<List<Map<String, dynamic>>> _combinarPersonasYMembers(
    List<Member> members,
  ) async {
    final result = <Map<String, dynamic>>[];
    final identificadoresVistos = <String>{};

    debugPrint(
      '🔄 Combinando ${members.length} members con personas legacy...',
    );

    try {
      for (final member in members) {
        final identificador = member.workerCode?.isNotEmpty == true
            ? member.workerCode!
            : (member.documentId ?? '');

        if (identificador.isEmpty) continue;

        if (_busqueda.isNotEmpty) {
          final query = _busqueda.toLowerCase();
          final matches =
              member.fullName.toLowerCase().contains(query) ||
              member.memberNumber.toLowerCase().contains(query) ||
              identificador.toLowerCase().contains(query);

          if (!matches) continue;
        }

        identificadoresVistos.add(identificador);
        result.add({'id': member.id, 'data': member, 'source': 'member'});
      }

      debugPrint('   ✅ Agregados ${result.length} members');

      try {
        final legacyPersonas = await _asistenciaService!
            .fetchAllLegacyPersonas();

        debugPrint(
          '   📊 Encontradas ${legacyPersonas.length} personas legacy',
        );

        int personasAgregadas = 0;
        for (final persona in legacyPersonas) {
          final identificador = persona.identificador;

          if (identificador != null &&
              identificador.isNotEmpty &&
              identificadoresVistos.contains(identificador)) {
            continue;
          }

          if (identificador != null && identificador.isNotEmpty) {
            identificadoresVistos.add(identificador);
          }

          if (_busqueda.isNotEmpty) {
            final query = _busqueda.toLowerCase();
            final matches =
                persona.nombreCompleto.toLowerCase().contains(query) ||
                (persona.identificador?.toLowerCase().contains(query) ?? false);

            if (!matches) continue;
          }

          result.add({'id': persona.id, 'data': persona, 'source': 'persona'});
          personasAgregadas++;
        }

        debugPrint('   ✅ Agregadas $personasAgregadas personas legacy');
      } catch (e) {
        debugPrint('⚠️ Error cargando personas legacy: $e');
      }

      result.sort((a, b) {
        final sourceA = a['source'] as String;
        final sourceB = b['source'] as String;

        String nombreA, nombreB;
        if (sourceA == 'member') {
          final m = a['data'] as Member;
          nombreA = m.lastName.toLowerCase();
        } else {
          final p = a['data'] as PersonaAsistencia;
          nombreA = p.apellidos.toLowerCase();
        }

        if (sourceB == 'member') {
          final m = b['data'] as Member;
          nombreB = m.lastName.toLowerCase();
        } else {
          final p = b['data'] as PersonaAsistencia;
          nombreB = p.apellidos.toLowerCase();
        }

        return nombreA.compareTo(nombreB);
      });

      debugPrint(
        '📊 Total: ${result.length} '
        '(${result.where((r) => r['source'] == 'member').length} members, '
        '${result.where((r) => r['source'] == 'persona').length} legacy)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error en _combinarPersonasYMembers: $e');
      rethrow;
    }
  }
}

String _socioCodigoLabel(Member m) {
  final n = m.memberNumber.trim();
  if (n.isEmpty) return 'S-—';
  if (RegExp(r'^\d+$').hasMatch(n)) {
    return 'S-${n.padLeft(4, '0')}';
  }
  return 'S-$n';
}

String _trabCodigoLabel(Member m) {
  final w = m.workerCode?.trim();
  if (w == null || w.isEmpty) return '—';
  final up = w.toUpperCase();
  if (up.startsWith('TRAB')) return w;
  return 'TRAB-$w';
}

bool _itemEstaActivo(Map<String, dynamic> item) {
  if (item['source'] == 'member') {
    return (item['data'] as Member).status == MemberStatus.active;
  }
  return true;
}

/// KPI compacto (`07_asistencia_personas`).
class _PersonasStatCell extends StatelessWidget {
  const _PersonasStatCell({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppDesignTokens.bodyMuted(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Fila del listado premium; el QR completo se muestra al tocar.
class _PersonasListRow extends StatelessWidget {
  const _PersonasListRow({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = _itemEstaActivo(item);
    final source = item['source'] as String;
    final avatarBg = activo ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final avatarFg = activo ? Colors.green.shade800 : Colors.red.shade800;

    late final String title;
    late final String subtitle;
    late final String estadoTxt;

    if (source == 'member') {
      final m = item['data'] as Member;
      title = m.fullName;
      subtitle = '${_socioCodigoLabel(m)} · ${_trabCodigoLabel(m)}';
      estadoTxt = activo ? 'Activo' : 'Inactivo';
    } else {
      final p = item['data'] as PersonaAsistencia;
      title = p.nombreCompleto;
      final id = p.identificador?.trim().isNotEmpty == true
          ? p.identificador!
          : p.id;
      subtitle = 'Legacy · $id';
      estadoTxt = 'Legacy';
    }

    final chipBg = source != 'member'
        ? AppDesignTokens.lavanda
        : (activo ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE));
    final chipFg = source != 'member'
        ? AppDesignTokens.primaryDark
        : (activo ? Colors.green.shade900 : Colors.red.shade900);

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppDesignTokens.primary.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.groups_2_rounded, color: avatarFg, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppDesignTokens.bodyMuted(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  estadoTxt,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: chipFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppDesignTokens.primary.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaQrDetailContent extends StatelessWidget {
  const _PersonaQrDetailContent({required this.persona});

  final PersonaAsistencia persona;

  @override
  Widget build(BuildContext context) {
    final qrData = persona.identificador?.isNotEmpty == true
        ? persona.identificador!
        : persona.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          persona.nombreCompleto,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppDesignTokens.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '(Persona legacy)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.orange.shade800,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: qrData,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        if (persona.identificador != null &&
            persona.identificador!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Identificador: ${persona.identificador}'),
        ],
      ],
    );
  }
}
