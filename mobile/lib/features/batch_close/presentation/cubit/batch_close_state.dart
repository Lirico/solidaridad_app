import 'package:flutter/material.dart';

import '../../../sales/domain/sale_model.dart';
import '../../domain/batch_close_model.dart';

/// Estados de la pantalla de Cierre de Lote.
///
/// La API separa el lote administrativo actual de los cortes ya cerrados.
@immutable
sealed class BatchCloseState {
  const BatchCloseState();
}

class BatchCloseInitial extends BatchCloseState {
  const BatchCloseInitial();
}

class BatchCloseLoading extends BatchCloseState {
  const BatchCloseLoading();
}

class BatchCloseFailed extends BatchCloseState {
  final String message;
  final bool connectionError;

  const BatchCloseFailed({required this.message, this.connectionError = false});
}

class BatchCloseLoaded extends BatchCloseState {
  final BatchSummary summary;

  const BatchCloseLoaded({required this.summary});
}

class BatchCloseClosing extends BatchCloseState {
  final BatchSummary summary;

  const BatchCloseClosing({required this.summary});
}

class BatchCloseCloseFailed extends BatchCloseState {
  final BatchSummary summary;
  final String message;

  const BatchCloseCloseFailed({required this.summary, required this.message});
}

class BatchCloseClosed extends BatchCloseState {
  final int? batchCloseId;
  final List<OperationModel> operations;

  const BatchCloseClosed({
    required this.batchCloseId,
    required this.operations,
  });
}

/// Emitido cuando la API responde 401 (token inválido/expirado).
class BatchCloseSessionExpired extends BatchCloseState {
  const BatchCloseSessionExpired();
}
