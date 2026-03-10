import SwiftUI

private struct LowSugarRecipe: Identifiable {
    let id = UUID()
    let name: String
    let mealTime: String
    let highlight: String
}

struct RecipeListView: View {
    private let recipes: [LowSugarRecipe] = [
        LowSugarRecipe(name: "燕麦鸡蛋蔬菜饼", mealTime: "早餐", highlight: "高纤维、低升糖"),
        LowSugarRecipe(name: "无糖酸奶坚果碗", mealTime: "加餐", highlight: "控制饥饿感"),
        LowSugarRecipe(name: "糙米鸡胸肉便当", mealTime: "午餐", highlight: "优质蛋白搭配复合碳水"),
        LowSugarRecipe(name: "清蒸鱼配西兰花", mealTime: "晚餐", highlight: "低脂高蛋白"),
        LowSugarRecipe(name: "番茄豆腐虾仁汤", mealTime: "晚餐", highlight: "低热量、营养密度高"),
        LowSugarRecipe(name: "牛油果全麦三明治", mealTime: "早餐", highlight: "健康脂肪+低 GI 主食"),
        LowSugarRecipe(name: "黄瓜鸡丝凉拌", mealTime: "加餐", highlight: "低碳水、清爽饱腹"),
        LowSugarRecipe(name: "杂豆南瓜焖饭", mealTime: "午餐", highlight: "提高膳食纤维比例")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("低糖饮食食谱") {
                    ForEach(recipes) { recipe in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(recipe.name)
                                    .font(.headline)
                                Spacer()
                                Text(recipe.mealTime)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                            Text(recipe.highlight)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("饮食提示") {
                    Text("主食优先选择全谷物，避免精制糖和含糖饮料。")
                    Text("每餐控制碳水总量，搭配蛋白质和蔬菜。")
                    Text("少量多餐，关注餐后血糖变化。")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("食谱")
        }
    }
}
