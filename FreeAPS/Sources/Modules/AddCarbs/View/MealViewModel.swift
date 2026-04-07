class MealViewModel: ObservableObject {

    var items: [FoodItemDetailed] = []

    var mealNutritionValues: NutritionValues {
        nutritionValues(for: items)
    }

    var mealMicronutrientValues: [MicroNutrient: Decimal] {
        micronutrientValues(for: items)
    }

    var aggregatedNutrition: AggregatedNutrition {
        AggregatedNutrition(
            macros: mealNutritionValues,
            micros: mealMicronutrientValues
        )
    }
}
