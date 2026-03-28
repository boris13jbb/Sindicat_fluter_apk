import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/models/candidate.dart';
import '../../core/models/election.dart';
import '../../services/election_service.dart';
import '../../services/asistencia_service.dart';
import '../../core/widgets/professional_app_bar.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key, required this.electionId});
  final String electionId;

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final ElectionService _electionService = ElectionService();
  final VoteService _voteService = VoteService();
  
  late Stream<bool> _votedStream;
  late Future<Election?> _electionFuture;
  
  bool _localVoteDone = false;
  String _userId = '';
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userEmail = FirebaseAuth.instance.currentUser?.email;
    
    // Inicializamos los flujos una sola vez
    _votedStream = _voteService.userVotedStream(widget.electionId, _userId);
    _electionFuture = _electionService.getElection(widget.electionId);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Inicia sesión para votar')));
    }

    // Bloqueo inmediato si ya votó (caché local o estado de esta sesión)
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
                child: Text('Error de conexión: ${votedSnap.error}', 
                  style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            );
          }

          if (votedSnap.data == true || _localVoteDone) {
            return _AlreadyVotedContent(electionId: widget.electionId);
          }

          return FutureBuilder<Election?>(
            future: _electionFuture,
            builder: (context, electionSnap) {
              if (electionSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final election = electionSnap.data;
              if (election == null) return const Center(child: Text('La elección no existe.'));
              
              if (election.isNotStarted) return Center(child: Text('Elección programada para: ${DateTime.fromMillisecondsSinceEpoch(election.startDate)}'));
              if (election.isEnded) return const Center(child: Text('Esta elección ya ha finalizado.'));

              // Verificación de asistencia
              if (election.requireAttendance && election.eventoAsistenciaId != null) {
                return FutureBuilder<bool>(
                  future: AsistenciaService().isUserRegisteredInEvent(election.eventoAsistenciaId!, _userId, _userEmail),
                  builder: (context, attSnap) {
                    if (attSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (attSnap.data != true) return const Center(child: Text('Asistencia no detectada. Registra tu asistencia para habilitar el voto.'));
                    return _buildVotingLayout(election, _userId);
                  },
                );
              }

              return _buildVotingLayout(election, _userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildVotingLayout(Election election, String userId) {
    return _VotingContent(
      election: election,
      electionId: widget.electionId,
      userId: userId,
      voteService: _voteService,
      onVoteSuccess: () => setState(() => _localVoteDone = true),
    );
  }
}

class _VotingContent extends StatefulWidget {
  const _VotingContent({
    required this.election,
    required this.electionId,
    required this.userId,
    required this.voteService,
    required this.onVoteSuccess,
  });

  final Election election;
  final String electionId;
  final String userId;
  final VoteService voteService;
  final VoidCallback onVoteSuccess;

  @override
  State<_VotingContent> createState() => _VotingContentState();
}

class _VotingContentState extends State<_VotingContent> {
  Candidate? _selected;
  bool _loading = false;
  late Stream<List<Candidate>> _candidatesStream;

  @override
  void initState() {
    super.initState();
    _candidatesStream = ElectionService().getCandidates(widget.electionId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Candidate>>(
      stream: _candidatesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text('No hay candidatos disponibles.'));
        
        final candidates = snap.data!;

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
              ...candidates.map((c) => Card(
                color: _selected?.id == c.id ? Theme.of(context).colorScheme.primaryContainer : null,
                child: RadioListTile<String>(
                  title: Text(c.name),
                  value: c.id,
                  groupValue: _selected?.id,
                  onChanged: (v) => setState(() => _selected = c),
                ),
              )),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading || _selected == null ? null : _confirmar,
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Emitir Voto'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
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
