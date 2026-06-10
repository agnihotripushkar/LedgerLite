import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_lite/data/database/app_database.dart';

// --- Events ---
abstract class CategoryEvent {}

class LoadCategories extends CategoryEvent {}

class AddCategory extends CategoryEvent {
  final String name;
  final String icon;
  final int colorValue;
  final bool isIncome;

  AddCategory({
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.isIncome,
  });
}

// --- States ---
abstract class CategoryState {
  const CategoryState();
}

class CategoryLoading extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  const CategoryLoaded(this.categories);
}

class CategoryError extends CategoryState {
  final String message;
  const CategoryError(this.message);
}

// --- BLoC ---
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final AppDatabase _database;
  StreamSubscription<List<Category>>? _subscription;

  CategoryBloc(this._database) : super(CategoryLoading()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<_UpdateCategoriesList>(_onUpdateCategoriesList);
  }

  void _onLoadCategories(LoadCategories event, Emitter<CategoryState> emit) {
    emit(CategoryLoading());
    _subscription?.cancel();
    _subscription = _database.watchCategories().listen(
      (categories) {
        add(_UpdateCategoriesList(categories));
      },
      onError: (error) {
        emit(CategoryError('Failed to load categories: $error'));
      },
    );
  }

  void _onUpdateCategoriesList(_UpdateCategoriesList event, Emitter<CategoryState> emit) {
    emit(CategoryLoaded(event.categories));
  }

  Future<void> _onAddCategory(AddCategory event, Emitter<CategoryState> emit) async {
    try {
      await _database.insertCategory(CategoriesCompanion.insert(
        name: event.name,
        icon: event.icon,
        colorValue: event.colorValue,
        isIncome: event.isIncome,
      ));
    } catch (e) {
      emit(CategoryError('Failed to add category: $e'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class _UpdateCategoriesList extends CategoryEvent {
  final List<Category> categories;
  _UpdateCategoriesList(this.categories);
}
