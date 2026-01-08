import SwiftUI
import Foundation
import FoundationModels
import WebKit


@Observable
final class SuggestionViewModel {
    var age: Int? = 30
    var weightLbs: Double? = 230
    var goalWeightLbs: Double? = 200
    var store: String = "Target"
    
    var targetProteinGrams: Double? = 170
    var targetCarbGrams: Double? = 100
    var targetFatGrams: Double? = 230

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var suggestions: [GrocerySuggestion.PartiallyGenerated] = []
    var favoriteSuggestions: [GrocerySuggestion] = [
        
        GrocerySuggestion(meal: "Chicken", items: [GroceryItem(name: "Steak", url: "")], proteinGrams: 2, calories: 2, estimatedCost: 2, isFavorited: true),
        GrocerySuggestion(meal: "Chicken", items: [GroceryItem(name: "Steak", url: "")], proteinGrams: 2, calories: 2, estimatedCost: 2)
        
    ]

    @MainActor
    func generateSuggestions() async {
        errorMessage = nil
        suggestions = []
        guard let age, let weightLbs, let goalWeightLbs, !store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        isLoading = true
        defer { isLoading = false }

    
        let instructions = """
        You are a nutrition and grocery planning assistant. Given the following user:
        - Age: \(age)
        - Current weight (lbs): \(Int(weightLbs))
        - Goal weight (lbs): \(Int(goalWeightLbs))
        - Preferred grocery store: \(store)

        \(targetProteinGrams != nil || targetCarbGrams != nil || targetFatGrams != nil ? "Macro targets (if provided):\n\(targetProteinGrams != nil ? "- Target protein: \(Int(targetProteinGrams!)) g" : "")\n\(targetCarbGrams != nil ? "- Target carbs: \(Int(targetCarbGrams!)) g" : "")\n\(targetFatGrams != nil ? "- Target fat: \(Int(targetFatGrams!)) g" : "")" : "")

        Suggest a budget‑conscious meal plans for one day that can be shopped at the specified store. For each meal, include:
        - A short meal name
        - 3–6 specific grocery items to buy (brand‑agnostic when possible, but realistic for the store)
        - Estimated protein grams and calories for the meal
        - Estimated total cost in USD for the listed items (reasonable ballpark)

        If macro targets are provided, aim to meet them across the suggested meals. Prioritize protein when balancing macros.
        Plan 3 meals 
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let prompt = "Plan Meals"

            let stream = session.streamResponse(
                to: prompt,
                generating: [GrocerySuggestion].self,
                includeSchemaInPrompt: true
            )

            for try await partial in stream {
                self.suggestions = partial.content
            }
            dump(self.suggestions)
        } catch {
            self.errorMessage = "Couldn't parse suggestions. Please try again."
        }
    }
    
    func favoriteMeal(currentMeal: GrocerySuggestion) {
        favoriteSuggestions.append(currentMeal)
    }
    
}

struct ContentView: View {
    @State private var model = SuggestionViewModel()
    @State private var isShowingProfileSheet = false
    @State private var isShowingWebView = false
    @State private var isShowingFavoriteView = false
    @State private var selectedProductURL: String = ""
    @State private var currentStore: StoreOption = .Meijer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    actionButton
                    resultsSection
                }
                .padding()
            }
            .navigationTitle("Muscle Math")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingProfileSheet.toggle()
                    } label: {
                        Image(systemName: "person")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                       isShowingFavoriteView.toggle()
                    } label: {
                        Image(systemName: "heart")
                    }
                }
            }
          
            .sheet(isPresented: $isShowingProfileSheet) {
                Group {
                    ZStack {
                        Color.white
                            .ignoresSafeArea()
                        VStack {
                            inputCard
                                .padding()
                            actionButton
                        }
                    }
                }
                .presentationDetents([.fraction(0.9)])
            
            }
            
            .sheet(isPresented: $isShowingFavoriteView) {
                
                ForEach(model.favoriteSuggestions) { s in
                    // Text(meal.meal)
                    
                    
                    GroupBox((s.meal ?? "Meal").isEmpty ? "Meal" : (s.meal ?? "Meal")) {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Items")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                ForEach(s.items ?? [], id: \.self) { product in
                                    HStack(alignment: .firstTextBaseline) {
                                        // Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        
                                        Button(product.name ?? "No Value") {
                                            selectedProductURL = product.url ?? ""
                                        }
                                        .onChange(of: selectedProductURL, { oldValue, newValue in
                                            isShowingWebView = true
                                        })
                                        .sheet(isPresented: $isShowingWebView) {
                                            WebView(url: URL(string: selectedProductURL))
                                                .presentationDetents([.fraction(0.7)])
                                                .presentationDragIndicator(.visible)
                                        }
                                    }
                                }
                                
                            }
                            Divider()
                            HStack {
                                Label("Protein: \(s.proteinGrams ?? 0) g", systemImage: "bolt.heart")
                                Spacer()
                                Label("Calories: \(s.calories ?? 0)", systemImage: "flame")
                                Spacer()
                                Label(formatCost(s.estimatedCost), systemImage: "dollarsign.circle")
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }
                    .groupBoxStyle(.automatic)
                  //  .presentationDetents([.fraction(0.9)])
                    
                }
            }
        }
        .task {
            //pre warm here
        }
    }

    private var inputCard: some View {
        GroupBox("Your Details") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.secondary)
                    Text("Age")
                    Spacer()
                    TextField("Years", value: $model.age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                Divider()
                HStack {
                    Image(systemName: "scalemass")
                        .foregroundStyle(.secondary)
                    Text("Current Weight")
                    Spacer()
                    TextField("lbs", value: $model.weightLbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                HStack {
                    Image(systemName: "scalemass")
                        .foregroundStyle(.secondary)
                    Text("Goal Weight")
                    Spacer()
                    TextField("Goal lbs", value: $model.goalWeightLbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                Divider()
                HStack {
                    Image(systemName: "cart")
                        .foregroundStyle(.secondary)
                    Text("Store")
                    Spacer()
                    
                    Picker("Select Store", selection: $currentStore) {
                        ForEach(StoreOption.allCases, id: \.self) { store in
                            Text(store.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(.secondary)
                        Text("Macro Targets")
                        Spacer()
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("g", value: $model.targetProteinGrams, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("g", value: $model.targetCarbGrams, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("g", value: $model.targetFatGrams, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }
                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
            .padding(.top, 4)
        }
        .groupBoxStyle(.automatic)
    }

    private var actionButton: some View {
        Button(action: {
            isShowingProfileSheet = false
            Task { await model.generateSuggestions() }
        }) {
            HStack {
                if model.isLoading { ProgressView().tint(.white) }
                Text(model.isLoading ? "Preparing Meals…" : "Suggest Meals")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(model.isLoading)
        .accessibilityLabel("Generate grocery suggestions")
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.suggestions.isEmpty {
                contentPlaceholder

            } else {
                Text("Suggested Meals")
                    .font(.title2)
                    .bold()

                ForEach(model.suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
                
                totalsFooter
            }
        }
        .animation(.default, value: model.suggestions)
    }

    private var contentPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Enter your details in your profile and tap Get Suggestions to see meals, macros, and estimated costs tailored to your store.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func formatCost(_ cost: Double?) -> String {
        guard let cost else { return "$0.00" }
        return String(format: "$%.2f", cost)
    }

    private func suggestionCard(_ s: GrocerySuggestion.PartiallyGenerated) -> some View {
        GroupBox((s.meal ?? "Meal").isEmpty ? "Meal" : (s.meal ?? "Meal")) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(s.items ?? [], id: \.self) { product in
                        HStack(alignment: .firstTextBaseline) {
                            // Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            
                            Button(product.name ?? "No Value") {
                                selectedProductURL = product.url ?? ""
                            }
                            .onChange(of: selectedProductURL, { oldValue, newValue in
                                isShowingWebView = true
                            })
                            .sheet(isPresented: $isShowingWebView) {
                                WebView(url: URL(string: selectedProductURL))
                                    .presentationDetents([.fraction(0.7)])
                                    .presentationDragIndicator(.visible)
                            }
                        }
                    }
                   
                }
                Divider()
                HStack {
                    Label("Protein: \(s.proteinGrams ?? 0) g", systemImage: "bolt.heart")
                    Spacer()
                    Label("Calories: \(s.calories ?? 0)", systemImage: "flame")
                    Spacer()
                    Label(formatCost(s.estimatedCost), systemImage: "dollarsign.circle")
                }
                .font(.subheadline)
            }
            .padding(.top, 4)
        }
        .groupBoxStyle(.automatic)
        .overlay(alignment: .topTrailing) {
            Button {
              
                var isCurrentlyFavorited = s.isFavorited ?? true
                isCurrentlyFavorited.toggle()

                if let index = model.suggestions.firstIndex(where: { $0.id == s.id }) {
                    var updated = model.suggestions[index]
                    updated.isFavorited = isCurrentlyFavorited
                    model.suggestions[index] = updated
                }


                if isCurrentlyFavorited {
                    let items: [GroceryItem] = (s.items ?? []).map { GroceryItem(name: $0.name ?? "", url: $0.url ?? "") }
                    let full = GrocerySuggestion(
                        meal: (s.meal ?? "Meal").isEmpty ? "Meal" : (s.meal ?? "Meal"),
                        items: items,
                        proteinGrams: s.proteinGrams ?? 0,
                        calories: s.calories ?? 0,
                        estimatedCost: s.estimatedCost ?? 0,
                        isFavorited: true
                    )
                    model.favoriteMeal(currentMeal: full)
               }
            } label: {
                Image(systemName: (s.isFavorited ?? false) ? "heart.fill" : "heart")
            }
            .foregroundStyle(.pink)
            .padding()
        }
    }

    private var totalsFooter: some View {
        let totalProtein = model.suggestions.reduce(0) { $0 + ($1.proteinGrams ?? 0) }
        let totalCalories = model.suggestions.reduce(0) { $0 + ($1.calories ?? 0) }
        let totalCost = model.suggestions.reduce(0.0) { $0 + ($1.estimatedCost ?? 0) }
        return HStack {
            Text("Daily Total: ")
                .fontWeight(.semibold)
            Spacer()
            Label("\(totalProtein) g protein", systemImage: "bolt.heart")
            Label("\(totalCalories) cal", systemImage: "flame")
            Label(String(format: "$%.2f", totalCost), systemImage: "dollarsign.circle")
        }
        .padding(.top, 8)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentView()
}


enum StoreOption: String, CaseIterable {
    case Meijer = "Meijer"
    case Kroger = "Kroger"
    case Target = "Target"
    case Walmart = "Walmart"
}
