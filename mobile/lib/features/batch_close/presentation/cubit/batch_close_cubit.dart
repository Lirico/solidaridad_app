import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/batch_close_repository.dart';
import '../../domain/batch_close_model.dart';
import 'batch_close_state.dart';

/// Arma y cierra el lote administrativo actual.
class BatchCloseCubit extends Cubit<BatchCloseState> {
  /// Etiqueta del lote activo: el corte real queda identificado por la API.
  static const String currentBatchNumber = 'ACTUAL';

  final BatchCloseRepository repository;

  BatchCloseCubit({required this.repository})
    : super(const BatchCloseInitial());

  /// Carga las ventas del lote actual y arma el resumen.
  Future<void> loadCurrentBatch({required String token}) async {
    emit(const BatchCloseLoading());

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: token,
    );

    if (result.sessionExpired) {
      emit(const BatchCloseSessionExpired());
      return;
    }

    if (result.connectionError) {
      emit(
        BatchCloseFailed(
          message:
              result.errorMessage ?? 'No se pudo obtener el resumen del lote.',
          connectionError: true,
        ),
      );
      return;
    }

    emit(
      BatchCloseLoaded(
        summary: BatchSummary.fromOperations(
          operations: result.operations,
          batchNumber: currentBatchNumber,
          isPartial: result.isPartial,
        ),
      ),
    );
  }

  /// Cierra el lote actual. La misma clave se conserva para reintentar una
  /// respuesta ambigua sin crear otro corte.
  Future<void> closeCurrentBatch({
    required String token,
    required String idempotencyKey,
  }) async {
    final BatchCloseState current = state;
    final BatchSummary? summary = switch (current) {
      BatchCloseLoaded(:final summary) => summary,
      BatchCloseCloseFailed(:final summary) => summary,
      _ => null,
    };
    if (summary == null) return;

    emit(BatchCloseClosing(summary: summary));
    final BatchCloseSubmitResult result = await repository.closeCurrentBatch(
      token: token,
      idempotencyKey: idempotencyKey,
    );
    if (result.sessionExpired) {
      emit(const BatchCloseSessionExpired());
      return;
    }
    if (result.connectionError) {
      emit(
        BatchCloseCloseFailed(
          summary: summary,
          message: result.errorMessage ?? 'No se pudo cerrar el lote.',
        ),
      );
      return;
    }
    emit(
      BatchCloseClosed(
        batchCloseId: result.batchCloseId,
        operations: result.operations,
      ),
    );
  }

  void reset() {
    emit(const BatchCloseInitial());
  }
}
