import SwiftUI
import Foundation
import FoundationModels
import WebKit


@Generable
struct GrocerySuggestion: Identifiable, Hashable {
    let id: UUID = UUID()
    @Guide(description: "Name of the item with an appropriate emoji")
    let meal: String
    let items: [GroceryItem]
    let proteinGrams: Int
    let calories: Int
    let estimatedCost: Double

}

@Generable
struct GroceryItem: Identifiable, Hashable {
    let id: UUID = UUID()
    
    @Guide(description: "Name of the item with an appropriate emoji")
    let name: String
    
    @Guide(description: """
    Given a grocery item name, return a Meijer search query,
    NOT a URL.

    Example output:
    "Meijer split top white bread 22 oz"
    """)
    let searchQuery: String
   
    @Guide(description: "URL to the item's product page based off the searchQuery")
    let url: String
}

@Observable
final class SuggestionViewModel {
    var age: Int? = 30
    var weightLbs: Double? = 230
    var goalWeightLbs: Double? = 200
    var store: String = "Meijer"

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var suggestions: [GrocerySuggestion.PartiallyGenerated] = []

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

        // Construct a prompt for the on‑device Foundation Model.
        let instructions = """
        You are a nutrition and grocery planning assistant. Given the following user:
        - Age: \(age)
        - Current weight (lbs): \(Int(weightLbs))
        - Goal weight (lbs): \(Int(goalWeightLbs))
        - Preferred grocery store: \(store)

        Suggest a budget‑conscious meal plans for one day that can be shopped at the specified store. For each meal, include:
        - A short meal name
        - 3–6 specific grocery items to buy (brand‑agnostic when possible, but realistic for the store)
        - Estimated protein grams and calories for the meal
        - Estimated total cost in USD for the listed items (reasonable ballpark)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let prompt = "Plan 1 meal"

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
}

struct ContentView: View {
    @State private var model = SuggestionViewModel()
    @State var isShowingProfileSheet = false
    @State var isShowingWebView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    actionButton
                    resultsSection
                }
                .padding()
            }
            .navigationTitle("MuscleMath")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingProfileSheet.toggle()
                    } label: {
                        Image(systemName: "person")
                    }
                }
            }
            .sheet(isPresented: $isShowingProfileSheet) {
                inputCard
                    .padding()
                actionButton
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
                    Text("Weight")
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
                    TextField("e.g. Costco, Target, Aldi", text: $model.store)
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 220)
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
                    .font(.title2).bold()

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
            Text("Enter your details and tap Get Suggestions to see meals, macros, and estimated costs tailored to your store.")
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
                    ForEach(s.items ?? [], id: \.self) { item in
                        HStack(alignment: .firstTextBaseline) {
                           // Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            
                            Button(item.name ?? "No Value") {
                                isShowingWebView = true
                            }
                            .sheet(isPresented: $isShowingWebView) {
                                WebView(url: URL(string: item.url ?? ""))
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

