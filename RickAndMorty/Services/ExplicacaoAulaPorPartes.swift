//
//  em.swift
//  RickAndMorty
//
//  Created by Juliano on 14/10/25.
//

import Foundation
import FirebaseAnalytics

class Aula {
    
    public func log (event: AnalyticsEvent) {
        var parameters: [String: Any] = [:]

        
        switch event {
        case .characterSelection(let characterSelectionEvent):
            
            // MARK: - Passo 1: Codificar a struct em Data (JSON bruto)
            // Usamos o JSONEncoder para transformar nosso objeto Swift (CharacterSelectionEvent)
            // em um formato padronizado de bytes (JSON). Isso é seguro e evita erro humano ao montar JSONs na mão.
            do {
               let dataEventBruto = try JSONEncoder().encode(characterSelectionEvent)
                
                // MARK: - Passo 2: Converter o JSON (Data) em dicionário [String: Any]
                // O Firebase (e outros SDKs) esperam receber parâmetros como dicionário.
                // Em vez de montar o dicionário manualmente (arriscando erros de tipo ou digitação),
                // usamos o JSONSerialization para converter o Data em um formato legível pelo Swift.
                if let dictParameters = try JSONSerialization.jsonObject(with: dataEventBruto) as? [String: Any] {
                    
                    // Atribuímos o dicionário final para o envio ao Analytics
                    parameters = dictParameters
                    
                    // Vantagem: podemos manipular o dicionário depois (ex: adicionar campos extras de tracking)
                    // sem precisar poluir a struct original (mantendo o modelo limpo e reutilizável).
                    
                } else {
                    print("Erro: O JSON não pôde ser convertido para [String: Any].")
                }
                
            } catch {
                // Captura erros tanto na serialização quanto na conversão
                print("Erro ao codificar ou converter o evento: \(error.localizedDescription)")
            }
        case .screenView(_):
            print(1)
        case .actionPerformed(_):
            print(1)
        case .custom(name: _, parameters: _):
            print(1)
        }
        
        // MARK: - Passo 3: Enviar dicionario para firebase

   print("Event tracked: From \(event.eventName) | params: \(parameters)" )
   
       Analytics.logEvent(event.eventName, parameters: parameters)
   
   }
}
