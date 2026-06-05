import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/data/clarification_dialogue_service.dart';
import 'package:smart_bp/features/shop/data/clarification_session_repository.dart';
import 'package:smart_bp/features/shop/data/community_analytics_repository.dart';
import 'package:smart_bp/features/shop/data/daily_shopping_list_repository.dart';
import 'package:smart_bp/features/shop/data/fulfillment_repository.dart';
import 'package:smart_bp/features/shop/data/hybrid_nlu_orchestrator.dart';
import 'package:smart_bp/features/shop/data/personalized_recommendation_service.dart';
import 'package:smart_bp/features/shop/domain/daily_shopping_line.dart';
import 'package:smart_bp/features/shop/domain/recommendation_card.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

final hybridNluOrchestratorProvider = Provider<HybridNluOrchestrator>(
  (ref) => HybridNluOrchestrator(),
);

final clarificationSessionRepositoryProvider =
    Provider<ClarificationSessionRepository>(
  (ref) => ClarificationSessionRepository(),
);

final clarificationDialogueServiceProvider =
    Provider<ClarificationDialogueService>(
  (ref) => ClarificationDialogueService(
    nlu: ref.watch(hybridNluOrchestratorProvider),
    sessions: ref.watch(clarificationSessionRepositoryProvider),
    recommendations: ref.watch(personalizedRecommendationServiceProvider),
  ),
);

final personalizedRecommendationServiceProvider =
    Provider<PersonalizedRecommendationService>(
  (ref) => PersonalizedRecommendationService(),
);

class ShopNluResultNotifier extends Notifier<ShopNluResult?> {
  @override
  ShopNluResult? build() => null;

  void setResult(ShopNluResult? value) => state = value;
}

final shopNluResultProvider =
    NotifierProvider<ShopNluResultNotifier, ShopNluResult?>(
  ShopNluResultNotifier.new,
);

final personalizedRecommendationsProvider = FutureProvider.family<
    RecommendationCardSet,
    ({String userId, String? categoryKey, String? categoryId})>((ref, arg) {
  return ref.read(personalizedRecommendationServiceProvider).fetchCards(
        userId: arg.userId,
        categoryKey: arg.categoryKey,
        categoryId: arg.categoryId,
      );
});

final dailyShoppingListProvider = FutureProvider.family<
    List<DailyShoppingLine>,
    ({String locationPointId, DateTime? date})>((ref, arg) async {
  return ref.read(dailyShoppingListRepositoryProvider).fetch(
        locationPointId: arg.locationPointId,
        shoppingDate: arg.date,
      );
});

final dailyShoppingListRepositoryProvider =
    Provider<DailyShoppingListRepository>(
  (ref) => DailyShoppingListRepository(),
);

final fulfillmentRepositoryProvider = Provider<FulfillmentRepository>(
  (ref) => FulfillmentRepository(),
);

final communityAnalyticsProvider = FutureProvider.family<CommunityAnalytics,
    String?>((ref, locationPointId) {
  return ref.read(communityAnalyticsRepositoryProvider).fetch(
        locationPointId: locationPointId,
      );
});

final communityAnalyticsRepositoryProvider =
    Provider<CommunityAnalyticsRepository>(
  (ref) => CommunityAnalyticsRepository(),
);
