import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/formatters/amount_formatter.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_sheet_panel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/widgets/user_menu_button.dart';
import '../../../sales/domain/sale_model.dart';
import '../../../sales/presentation/cubit/sales_cubit.dart';
import '../../../sales/presentation/cubit/sales_state.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  int _offset = 0;
  static const int _limit = 20;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialHistory() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthSuccess && authState.user != null) {
      context.read<SalesCubit>().loadHistory(
        token: authState.user!.token,
        limit: _limit,
        offset: 0,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthSuccess || authState.user == null) return;

    setState(() => _loadingMore = true);
    final newOffset = _offset + _limit;
    final items = await context.read<SalesCubit>().salesRepository.fetchHistory(
      token: authState.user!.token,
      limit: _limit,
      offset: newOffset,
    );

    if (items.isNotEmpty && mounted) {
      setState(() => _offset = newOffset);
      context.read<SalesCubit>().appendHistory(items);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      appBar: const AppHeader(
        title: 'Historial de Ventas',
        actions: [UserMenuButton(), SizedBox(width: 8)],
      ),
      bottomNavigationBar: const AppBottomNavBar(),
      body: AppSheetPanel(
        child: BlocListener<SalesCubit, SalesState>(
          listener: (context, state) {
            if (state is SalesSessionExpired) {
              context.read<AuthCubit>().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            }
          },
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<SalesCubit, SalesState>(
      builder: (context, state) {
        if (state is SalesLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = state.history;

        if (history.isEmpty) {
          return const Center(
            child: Text(
              'No hay transacciones registradas.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: history.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == history.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final operation = history[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  operation.result == PaymentResult.approved
                      ? Icons.check_circle
                      : operation.result == PaymentResult.voided
                      ? Icons.undo
                      : operation.result == PaymentResult.connectionError
                      ? Icons.wifi_off
                      : Icons.error,
                  color: operation.result == PaymentResult.approved
                      ? Colors.green
                      : operation.result == PaymentResult.voided
                      ? Colors.grey
                      : operation.result == PaymentResult.connectionError
                      ? Colors.orange
                      : Colors.red,
                  size: 32,
                ),
                title: Text(
                  '${operation.productLabel} — ${formatAmount(operation.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text('${operation.cardNumber} \n${operation.id}'),
                trailing: Text(
                  '${operation.date.hour.toString().padLeft(2, '0')}:${operation.date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.grey),
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.saleDetail,
                    arguments: operation,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
