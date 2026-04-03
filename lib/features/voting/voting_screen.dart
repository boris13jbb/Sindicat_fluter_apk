import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/models/candidate.dart';
import '../../core/models/election.dart';
import '../../services/asistencia_service.dart';
import '../../services/election_service.dart';
import '../../core/widgets/professional_app_bar.dart';

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
  final AsistenciaService _asistenciaService = AsistenciaService();

  static const Duration _bootstrapTimeout = Duration(seconds: 30);

  late Stream<bool> _votedStream;

  bool _localVoteDone = false;
  String _userId = '';
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userEmail = FirebaseAuth.instance.currentUser?.email;
    _electionService = ElectionService();
    _bootstrap = _loadBootstrap();
    _votedStream = _voteService.userVotedStream(widget.electionId, _userId);
  }

  Future<ResultsBootstrap> _loadBootstrap() {
    return _electionService.loadResultsBootstrap(widget.electionId).timeout(
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

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Inicia sesión para votar')));
    }

    if (_voteService.hasVotedLocally(widget.electionId, _userId) || _localVoteDone) {
      return Scaffold(
        appBar: ProfessionalAppBar(title: 'Votar', onNavigateBack: () => Navigator.pop(context)),
        body: _AlreadyVotedContent(electionId: widget.electionId),
      );
    }

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Votar',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: StreamBuilder<bool>(
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
            return _AlreadyVotedContent(electionId: widget.electionId);
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
                stream: _electionService.watchElectionLive(widget.electionId),
                initialData: ElectionLiveState(election: boot.election, isSyncing: true),
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
                    return const Center(child: Text('La elección no existe.'));
                  }

                  if (election.isNotStarted) {
                    return Center(
                      child: Text(
                        'Elección programada para: ${DateTime.fromMillisecondsSinceEpoch(election.startDate)}',
                      ),
                    );
                  }
                  if (election.isEnded) {
                    return const Center(child: Text('Esta elección ya ha finalizado.'));
                  }

                  if (election.requireAttendance && election.eventoAsistenciaId != null) {
                    final eventoId = election.eventoAsistenciaId!;
                    return StreamBuilder<bool>(
                      stream: _asistenciaService.watchUserRegisteredInEvent(
                        eventoId,
                        _userId,
                        _userEmail,
                      ),
                      builder: (context, attSnap) {
                        if (attSnap.hasError) {
                          return _VoteLoadError(
                            message: '${attSnap.error}',
                            onRetry: _retryLoad,
                          );
                        }
                        if (attSnap.connectionState == ConnectionState.waiting &&
                            !attSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (attSnap.data != true) {
                          return const Center(
                            child: Text(
                              'Asistencia no detectada. Registra tu asistencia para habilitar el voto.',
                            ),
                          );
                        }
                        return _buildVotingLayout(election, boot.candidates);
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
    );
  }

  Widget _buildVotingLayout(Election election, List<Candidate> initialCandidates) {
    return _VotingContent(
      election: election,
      electionId: widget.electionId,
      userId: _userId,
      voteService: _voteService,
      initialCandidates: initialCandidates,
      onVoteSuccess: () => setState(() => _localVoteDone = true),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
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
  });

  final Election election;
  final String electionId;
  final String userId;
  final VoteService voteService;
  final List<Candidate> initialCandidates;
  final VoidCallback onVoteSuccess;

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
                  const Icon(Icons.error_outline, size: 48, color: Colors.orange),
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
                Text('No hay candidatos disponibles.', style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.election.title, style: Theme.of(context).textTheme.titleLarge),
                      if (widget.election.description.isNotEmpty) Text(widget.election.description),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Selecciona tu candidato:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _selected?.id,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selected = candidates.firstWhere(
                      (candidate) => candidate.id == value,
                      orElse: () => _selected ?? candidates.first,
                    );
                  });
                },
                child: Column(
                  children: [
                    ...candidates.map(
                      (c) => Card(
                        color: _selected?.id == c.id
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: RadioListTile<String>(
                          title: Text(c.name),
                          value: c.id,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading || _selected == null
                    ? null
                    : _confirmar,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Emitir Voto'),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Votar')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await widget.voteService.castVote(
        electionId: widget.electionId,
        userId: widget.userId,
        candidateId: _selected!.id,
      );
      widget.voteService.recordLocalVote(widget.electionId, widget.userId);
      widget.onVoteSuccess();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already-exists') || msg.contains('already_exists') || msg.contains('already exists')) {
        widget.onVoteSuccess();
        return;
      }
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _AlreadyVotedContent extends StatelessWidget {
  const _AlreadyVotedContent({required this.electionId});
  final String electionId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text('¡Voto Registrado!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Gracias por participar.'),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/voto/results', arguments: electionId),
            child: const Text('Ver Resultados'),
          ),
        ],
      ),
    );
  }
}
