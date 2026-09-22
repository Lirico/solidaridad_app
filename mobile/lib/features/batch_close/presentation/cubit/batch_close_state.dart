import 'package:flutter/material.dart';

import '../../domain/batch_close_model.dart';

/// Estados de la pantalla de Cierre de Lote.
///
/// El cierre es **local** (no hay contrato de cierre contra el procesador
/// todavía): `loadCurrentBatch` arma el resumen desde la API y `closeBatch`
/// corta el lote en el terminal. Ver `docs/gaps.md` (G-P2-10).
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

/// El lote se cerró en el terminal (cierre local) y ya no admite otro cierre.
class BatchCloseClosed extends BatchCloseState {
  final BatchSummary summary;

  const BatchCloseClosed({required this.summary});
}

/// Emitido cuando la API responde 401 (token inválido/expirado).
class BatchCloseSessionExpired extends BatchCloseState {
  const BatchCloseSessionExpired();
}
