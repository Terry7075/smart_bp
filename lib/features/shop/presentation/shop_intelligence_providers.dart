import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/data/product_normalization_engine.dart';
import 'package:smart_bp/features/shop/data/purchase_batch_repository.dart';
import 'package:smart_bp/features/shop/data/recommendation_engine.dart';

export 'shop_collaboration_providers.dart';

final productNormalizationEngineProvider = Provider<ProductNormalizationEngine>(
  (ref) => ProductNormalizationEngine(),
);

final recommendationEngineProvider = Provider<RecommendationEngine>(
  (ref) => RecommendationEngine(),
);

final purchaseBatchRepositoryProvider = Provider<PurchaseBatchRepository>(
  (ref) => const PurchaseBatchRepository(),
);

final volunteerPurchaseBatchesProvider =
    FutureProvider.autoDispose<List<VolunteerPurchaseBatch>>((ref) async {
  return const PurchaseBatchRepository().listBatches();
});
