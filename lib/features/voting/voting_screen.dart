import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/candidate.dart';
import '../../core/models/election.dart';
import '../../core/security/election_visibility.dart';
import '../../services/election_service.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../elections/widgets/voto_premium_chrome.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key, required this.electionId});
  final String electionId;

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  late ElectionService _electionService;
  late Future<ResultsBootstrap> _bootstrap;
  final VoteService _voteService = VoteService();
  final AuthService _authService = AuthService();

  static const Duration _bootstrapTimeout = Duration(seconds: 30);

  late Stream<bool> _votedStream;

  bool _localVoteDone = false;
  String _userId = '';
  String? _memberId; // ID canónico del socio para validación de elegibilidad

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _electionService = ElectionService();
    _bootstrap = _loadBootstrap();
    _votedStream = _voteService.userVotedStream(widget.electionId, _userId);
    _initializeMemberId();
  }

  /// Inicializa el memberId canónico del socio para validar elegibilidad.
  Future<void> _initializeMemberId() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _memberId = user.memberId?.trim().isNotEmpty == true
              ? user.memberId!.trim()
              : user.employeeNumber?.trim().isNotEmpty == true
              ? user.employeeNumber!.trim()
              : _userId;
        });
        debugPrint(
          '🗳️ MemberId inicializado: $_memberId '
          '(tipo: ${user.memberId?.trim().isNotEmpty == true
              ? "users.memberId"
              : user.employeeNumber?.trim().isNotEmpty == true
              ? "employeeNumber"
              : "userId fallback"})',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al inicializar memberId: $e');
    }
  }

  Future<ResultsBootstrap> _loadBootstrap() {
    return _electionService
        .loadResultsBootstrap(widget.electionId)
        .timeout(
          _bootstrapTimeout,
          onTimeout: () => throw TimeoutException(
            'La conexión es demasiado lenta. Comprueba datos móviles o Wi‑Fi.',
          ),
        );
  }

  void _retryLoad() {
    setState(() {
      _electionService = ElectionService();
      _bootstrap = _loadBootstrap();
    });
  }

  Widget _voteShell({
    String title = 'Votar',
    required String subtitle,
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: title,
            subtitle: subtitle,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return _voteShell(
        subtitle: 'Inicia sesión para participar',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
            child: Text(
              'Inicia sesión para votar.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppDesignTokens.primaryDark.withValues(alpha: 0.8),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_voteService.hasVotedLocally(widget.electionId, _userId) ||
        _localVoteDone) {
      return _voteShell(
        subtitle: 'Tu participación quedó registrada',
        child: _AlreadyVotedContent(
          electionId: widget.electionId,
          bootstrap: _bootstrap,
        ),
      );
    }

    final role = context.watch<AuthProvider>().user?.role;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<ResultsBootstrap>(
            future: _bootstrap,
            builder: (context, bootSnap) {
              var headerSubtitle = 'Cargando…';
              if (bootSnap.hasData && bootSnap.data?.election != null) {
                final t = bootSnap.data!.election!.title.trim();
                headerSubtitle = t.isNotEmpty ? t : 'Elección';
              } else if (bootSnap.hasError) {
                headerSubtitle = 'Votación';
              }
              return VotoWaveHeader(
                title: 'Emitir voto',
                subtitle: headerSubtitle,
                onBack: () => Navigator.pop(context),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<bool>(
              stream: _votedStream,
              builder: (context, votedSnap) {
                if (votedSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error de conexión: ${votedSnap.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (votedSnap.data == true || _localVoteDone) {
                  return _AlreadyVotedContent(
                    electionId: widget.electionId,
                    bootstrap: _bootstrap,
                  );
                }

                return FutureBuilder<ResultsBootstrap>(
                  future: _bootstrap,
                  builder: (context, bootSnap) {
                    if (bootSnap.hasError) {
                      return _VoteLoadError(
                        message: '${bootSnap.error}',
                        onRetry: _retryLoad,
                      );
                    }
                    if (bootSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final boot = bootSnap.data!;
                    if (boot.election == null) {
                      return const Center(child: Text('La elección no existe.'));
                    }

                    return StreamBuilder<ElectionLiveState>(
                      stream: _electionService.watchElectionLive(
                        widget.electionId,
                      ),
                      initialData: ElectionLiveState(
                        election: boot.election,
                        isSyncing: true,
                      ),
                      builder: (context, electionSnap) {
                        if (electionSnap.hasError) {
                          return _VoteLoadError(
                            message: '${electionSnap.error}',
                            onRetry: _retryLoad,
                          );
                        }
                        final live = electionSnap.data!;
                        final election = live.election;
                        if (election == null) {
                          return const Center(
                            child: Text('La elección no existe.'),
                          );
                        }

                        final votingStatus = getElectionVotingStatus(
                          election: election,
                        );
                        if (votingStatus != ElectionVotingStatus.open) {
                          final detail =
                              votingStatus == ElectionVotingStatus.notStarted
                              ? '\nInicio: ${DateTime.fromMillisecondsSinceEpoch(election.startDate)}'
                              : '';
                          return Center(
                            child: Text(
                              '${electionVotingStatusMessage(votingStatus)}$detail',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (election.requireAttendance) {
                          final eventoId = election.eventoAsistenciaId;
                          if (eventoId == null || eventoId.isEmpty) {
                            return const Center(
                              child: Text(
                                'Esta elección requiere asistencia, pero no tiene un evento vinculado.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          if (_memberId == null || _memberId!.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return StreamBuilder<bool>(
                            stream: _voteService.watchUserEligibilityForElection(
                              electionId: widget.electionId,
                              attendanceEventId: eventoId,
                              userId: _userId,
                              memberId: _memberId!,
                            ),
                            builder: (context, attSnap) {
                              if (attSnap.hasError) {
                                return _VoteLoadError(
                                  message: '${attSnap.error}',
                                  onRetry: _retryLoad,
                                );
                              }
                              if (attSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !attSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (attSnap.data != true) {
                                return const Center(
                                  child: Text(
                                    'Asistencia no detectada. Registra tu asistencia para habilitar el voto.',
                                  ),
                                );
                              }
                              return _buildVotingLayout(
                                election,
                                boot.candidates,
                              );
                            },
                          );
                        }

                        return _buildVotingLayout(election, boot.candidates);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: role != null
          ? VotoModuleBottomNavigation(
              role: role,
              selection: VotoNavSlot.voto,
            )
          : null,
    );
  }

  Widget _buildVotingLayout(
    Election election,
    List<Candidate> initialCandidates,
  ) {
    return _VotingContent(
      election: election,
      electionId: widget.electionId,
      userId: _userId,
      voteService: _voteService,
      initialCandidates: initialCandidates,
      onVoteSuccess: () => setState(() => _localVoteDone = true),
      memberId: _memberId,
    );
  }
}

Color _voteAccentForIndex(int index) {
  switch (index % 3) {
    case 0:
      return AppDesignTokens.primary;
    case 1:
      return Colors.blue.shade600;
    default:
      return Colors.green.shade600;
  }
}

class _VotingCandidateOptionTile extends StatelessWidget {
  const _VotingCandidateOptionTile({
    required this.candidate,
    required this.listaIndex,
    required this.accent,
    required this.selected,
  });

  final Candidate candidate;
  final int listaIndex;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final desc = candidate.description?.trim();
    final rawUrl = candidate.imageUrl?.trim() ?? '';
    final urlOk =
        rawUrl.isNotEmpty && validateCandidateImageUrl(rawUrl) == null;

    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          radioTheme: RadioThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return accent;
              }
              return accent.withValues(alpha: 0.55);
            }),
          ),
        ),
        child: Material(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(AppDesignTokens.radiusLarge),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(AppDesignTokens.radiusLarge),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : AppDesignTokens.primary.withValues(alpha: 0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: RadioListTile<String>(
              value: candidate.id,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              controlAffinity: ListTileControlAffinity.trailing,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VotingCandidateAvatar(
                    imageUrl: urlOk ? rawUrl : null,
                    accent: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lista $listaIndex',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          candidate.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppDesignTokens.primaryDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (desc != null && desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppDesignTokens.primaryDark.withValues(
                                alpha: 0.55,
                              ),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VotingCandidateAvatar extends StatelessWidget {
  const _VotingCandidateAvatar({
    this.imageUrl,
    required this.accent,
  });

  final String? imageUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: accent.withValues(alpha: 0.12),
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.12),
      child: Icon(Icons.person_rounded, color: accent, size: 28),
    );
  }
}

class _VoteLoadError extends StatelessWidget {
  const _VoteLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
        child: PremiumCard(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppDesignTokens.primaryDark.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VotingContent extends StatefulWidget {
  const _VotingContent({
    required this.election,
    required this.electionId,
    required this.userId,
    required this.voteService,
    required this.initialCandidates,
    required this.onVoteSuccess,
    this.memberId, // 🆕 ID del socio para validación de elegibilidad
  });

  final Election election;
  final String electionId;
  final String userId;
  final VoteService voteService;
  final List<Candidate> initialCandidates;
  final VoidCallback onVoteSuccess;
  final String? memberId; // 🆕 ID del socio

  @override
  State<_VotingContent> createState() => _VotingContentState();
}

class _VotingContentState extends State<_VotingContent> {
  Candidate? _selected;
  bool _loading = false;
  late Stream<List<Candidate>> _candidatesStream;
  final ElectionService _electionService = ElectionService();

  @override
  void initState() {
    super.initState();
    _candidatesStream = _electionService.getCandidates(widget.electionId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Candidate>>(
      stream: _candidatesStream,
      initialData: widget.initialCandidates,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar candidatos: ${snap.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final candidates = snap.data ?? [];
        if (candidates.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay candidatos disponibles.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        final sorted = List<Candidate>.from(candidates)
          ..sort((a, b) {
            final o = a.order.compareTo(b.order);
            if (o != 0) return o;
            return a.name.compareTo(b.name);
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.horizontalPadding,
            8,
            AppDesignTokens.horizontalPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona una opción',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppDesignTokens.primaryDark,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu voto será registrado de forma segura.',
                      style: AppDesignTokens.bodyMuted(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: _selected?.id,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selected = sorted.firstWhere(
                      (candidate) => candidate.id == value,
                      orElse: () => _selected ?? sorted.first,
                    );
                  });
                },
                child: Column(
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == sorted.length - 1 ? 0 : 12,
                        ),
                        child: _VotingCandidateOptionTile(
                          candidate: sorted[i],
                          listaIndex: i + 1,
                          accent: _voteAccentForIndex(i),
                          selected: _selected?.id == sorted[i].id,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading || _selected == null ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirmar voto',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Votar por ${_selected!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Votar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    debugPrint('\n🗳️ Usuario confirmó voto - Iniciando proceso...');
    setState(() => _loading = true);

    try {
      debugPrint('   📤 Llamando a castVote...');
      await widget.voteService.castVote(
        electionId: widget.electionId,
        userId: widget.userId,
        candidateId: _selected!.id,
        memberId: widget
            .memberId, // 🆕 Pasar memberId para validación de elegibilidad
      );

      debugPrint('   ✅ castVote completado sin errores');
      widget.voteService.recordLocalVote(widget.electionId, widget.userId);
      debugPrint('   ✅ Voto local registrado');
      widget.onVoteSuccess();
      debugPrint('   ✅ UI actualizada - mostrando pantalla de éxito\n');
    } catch (e, stackTrace) {
      debugPrint('   ❌ Error en _confirmar: $e');
      debugPrint('   Stack trace: $stackTrace');

      final msg = e.toString().toLowerCase();

      // Verificar si es error de voto ya existente
      if (msg.contains('already-exists') ||
          msg.contains('already_exists') ||
          msg.contains('already exists') ||
          msg.contains('ya existe') ||
          msg.contains('duplicado')) {
        debugPrint('   ⚠️ Detectado voto duplicado - tratando como éxito');
        widget.voteService.recordLocalVote(widget.electionId, widget.userId);
        widget.onVoteSuccess();
        return;
      }

      // Verificar si es error de elegibilidad
      if (msg.contains('elegible') ||
          msg.contains('permiso') ||
          msg.contains('requisito')) {
        debugPrint('   ❌ Error de elegibilidad detectado');
        if (mounted) {
          setState(() => _loading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('No se puede votar'),
              content: Text(
                'No cumples con los requisitos para votar en esta elección.\n\n'
                'Posibles causas:\n'
                '• No tienes registro de asistencia en el evento requerido\n'
                '• Tu socio no está activo\n'
                '• La elección requiere asistencia pero no estás registrado',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Error genérico
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar tu voto: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _confirmar(),
            ),
          ),
        );
      }
    }
  }
}

class _AlreadyVotedContent extends StatelessWidget {
  const _AlreadyVotedContent({
    required this.electionId,
    required this.bootstrap,
  });
  final String electionId;
  final Future<ResultsBootstrap> bootstrap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.horizontalPadding,
        24,
        AppDesignTokens.horizontalPadding,
        32,
      ),
      child: Center(
        child: PremiumCard(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 72,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                '¡Voto registrado!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gracias por participar.',
                style: AppDesignTokens.bodyMuted(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FutureBuilder<ResultsBootstrap>(
                future: bootstrap,
                builder: (context, snapshot) {
                  final election = snapshot.data?.election;
                  final canViewResults =
                      election != null &&
                      canViewElectionResults(election: election);

                  if (canViewResults) {
                    return FilledButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/voto/results',
                        arguments: electionId,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Ver resultados',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  }

                  return Text(
                    election?.showResultsAutomatically == false
                        ? 'Los resultados serán publicados por administración.'
                        : election == null ||
                                !election.isActive ||
                                !election.isVisibleToVoters
                            ? 'Los resultados no están publicados para votantes.'
                            : 'Los resultados estarán disponibles cuando finalice la elección.',
                    textAlign: TextAlign.center,
                    style: AppDesignTokens.bodyMuted(context),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
