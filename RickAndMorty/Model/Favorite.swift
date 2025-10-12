//
//  Favorite.swift
//  RickAndMorty
//
//  Created by Jamerson Macedo on 27/08/24.
//

import Foundation
import SwiftData

@Model
final class Favorite {
    var id: UUID = UUID()
    var characterID: Int = 10
    var name: String = ""
    var image: String = ""

    init(characterID: Int, name: String, image: String) {
        self.characterID = characterID
        self.name = name
        self.image = image
    }
}
