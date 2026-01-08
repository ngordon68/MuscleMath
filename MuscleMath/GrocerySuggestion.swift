//
//  GrocerySuggestion.swift
//  MuscleMath
//
//  Created by Nick Gordon on 1/7/26.
//
import Foundation
import FoundationModels

@Generable
struct GrocerySuggestion: Identifiable, Hashable {
    let id: UUID = UUID()
    @Guide(description: "Name of the item with an appropriate emoji")
    let meal: String
    let items: [GroceryItem]
    let proteinGrams: Int
    let calories: Int
    let estimatedCost: Double
    @Guide(description: "This value should be false")
    var isFavorited: Bool = false

}

@Generable
struct GroceryItem: Identifiable, Hashable {
    let id: UUID = UUID()
    
    @Guide(description: "Name of the item")
    let name: String
    
    @Guide(description: "URL to the item google results")
    let url: String
}
