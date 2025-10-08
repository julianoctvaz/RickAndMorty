//
//  FormattedDate.swift
//  RickAndMorty
//
//  Created by Jamerson Macedo on 24/08/24.
//

import Foundation

extension Date {
    func formattedDate(from dateString : String) ->String{
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString){
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
            dateFormatter.locale = Locale(identifier: "pt_BR")
            return dateFormatter.string(from: date)
        }
        return "DATA INVALIDA"
    }
    
    func formatted() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short // ou .none se não quiser hora
        dateFormatter.locale = Locale(identifier: "pt_BR")
        return dateFormatter.string(from: self)
    }
}
