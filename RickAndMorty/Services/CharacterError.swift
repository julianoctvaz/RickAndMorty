//
//  CharacterError.swift
//  RickAndMorty
//
//  Created by Jamerson Macedo on 24/08/24.
//

enum CharacterError: Error {
    case networkError(String)
    case decodingError(String)
    case unknownError
}
