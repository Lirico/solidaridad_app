import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/batch_close_repository.dart';
import '../../domain/batch_close_model.dart';
import 'batch_close_state.dart';

/// Arma el resumen del lote actual y lo cierra.
///
/// **Cierre local (provisional):** mientras no exista el contrato de cierre con
/// el procesador, el lote y su número viven en la sesión de la app:
/// - [_lastCloseAt] es el corte del último cierre: las ventas anteriores no
///   vuelven a contarse al reingresar a la pantalla.
/// - [_batchSequence] numera los lotes (`000001`, `000002`, …).
///
/// Cuando el backend exponga el lote real, este estado local se reemplaza por la
/// respuesta de la API sin tocar la UI. Ver `docs/gaps.md` (G-P2-10).
class BatchCloseCubit extends Cubit<BatchCloseState> {
  final BatchCloseRepository repository;

  DateTime? _lastCloseAt;
  int _batchSequence = 1;

  BatchCloseCubit({required this.repository})
    : super(const BatchCloseInitial());

  /// Carga las ventas del lote actual y arma el resumen.
  Future<void> loadCurrentBatch({required String token}) async {
    emit(const BatchCloseLoading());

    final BatchCloseLoadResult result = await repository.loadOperations(
      token: token,
      after: _lastCloseAt,
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
          batchNumber: _formatBatchNumber(_batchSequence),
          after: _lastCloseAt,
          isPartial: result.isPartial,
        ),
      ),
    );
  }

  /// Cierra el lote en el terminal.
  ///
  /// Solo actúa sobre un resumen cargado: evita cerrar dos veces si la pantalla
  /// se vuelve a construir después de un cierre (p. ej. al volver con el botón
  /// atrás desde el resultado).
  void closeBatch() {
    final BatchCloseState current = state;
    if (current is! BatchCloseLoaded) return;

    _lastCloseAt = DateTime.now();
    _batchSequence += 1;
    emit(BatchCloseClosed(summary: current.summary));
  }

  void reset() {
    emit(const BatchCloseInitial());
  }
}

String _formatBatchNumber(int sequence) => sequence.toString().padLeft(6, '0');
