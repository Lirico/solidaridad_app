import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/batch_close_repository.dart';
import '../../domain/batch_close_model.dart';
import 'batch_close_state.dart';

/// Arma el resumen del lote actual.
///
/// **Sin cierre:** la pantalla es informativa. La app todavía no cierra nada
/// porque no existe el contrato de cierre contra el procesador, y el Nº de lote
/// es provisorio ([provisionalBatchNumber]). Cuando el backend exponga el lote
/// real, este valor se reemplaza por la respuesta de la API sin tocar la UI.
/// Ver `docs/gaps.md` (G-P2-10).
class BatchCloseCubit extends Cubit<BatchCloseState> {
  /// Nº de lote provisorio mientras la API no exponga el lote real.
  static const String provisionalBatchNumber = '000001';

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
          batchNumber: provisionalBatchNumber,
          isPartial: result.isPartial,
        ),
      ),
    );
  }

  void reset() {
    emit(const BatchCloseInitial());
  }
}
