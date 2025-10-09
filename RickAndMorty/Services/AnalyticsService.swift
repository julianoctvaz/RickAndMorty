//
//  AnalyticsService.swift
//  RickAndMorty
//
//  Created by Juliano on 08/10/25.
//

import Foundation
import TelemetryDeck

// MARK: - Passo de pegar a struct e colocar como dicionario de strings
extension Encodable {
    /// Converte qualquer struct Encodable em [String: String]
    func asStringDictionary() throws -> [String: String] {
        do {
            let data = try JSONEncoder().encode(self)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                //            throw NSError(domain: "TelemetryDeck", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato inesperado, não conseguiu transformar em dicionario de strings"]) (Exemplo sem tratamento ideal de erro)
                throw AnalyticsError.invalidDictionaryFormat("Não foi possível converter JSON em [String:String].")
            }
            
            // converte todos os valores para String (o TelemetryDeck só aceita [String:String])
            // aceitaria [String: Any] -> "isValid": true, o true precisa ser "true"
            return dict.mapValues { "\($0)" }
        } catch let error as EncodingError {
            // Aqui capturamos especificamente erros de codificação JSON.
            // Isso acontece quando o JSONEncoder não consegue transformar o objeto Swift em JSON.
            // Exemplo: uma propriedade não codificável (como Date sem formato definido).
            throw AnalyticsError.encodingError("Falha ao codificar objeto: \(error)")
        } catch {
            // Aqui capturamos qualquer outro erro genérico que possa ocorrer.
            // Serve como uma "rede de segurança" para erros que não sejam do tipo EncodingError,
            // como falhas na conversão de JSON para dicionário ou problemas de tipo.
            throw AnalyticsError.invalidDictionaryFormat("Erro inesperado: \(error.localizedDescription)")
        }
    }
}

// MARK: - Analytics Service
enum AnalyticsService {
    
     typealias Screen = AnalyticsEvent.Screens
    
    // Inicialização global (chamar uma vez, ex: no App)
    static func initialize(appID: String, userID: String? = nil) {
        var config = TelemetryManagerConfiguration(appID: appID)
        
        #if DEBUG // em desenvolvimento/teste UAT
        config.testMode = true // marca os sinais como "Testing" no painel
        #else
        config.testMode = false
        #endif
        
        config.defaultSignalPrefix = "RickAndMorty."
        config.defaultParameters = { ["platform": "iOS"] }
        if let userID = userID {
            config.defaultUser = userID  // será hashado automaticamente (escondido)
        }

        TelemetryDeck.initialize(config: config)
//        Deve printar algo no console como TelemetryDeck: initialized successfully ou newSessionBegan ao ser inicializado
        
//        TelemetryDeck.signal("AppLaunched")
        AnalyticsService.log(event: .custom(name: "AppLaunched")) //usando nosso servico
        //exemplo se tivessemos parametros adicionais
//        AnalyticsService.log(event: .custom(name: "AppLaunched", parameters: [:])) // vazio parametros
    }

    // Envia eventos com structs Codable
    static func log(event: AnalyticsEvent) {
        do {
            let parameters = try event.parameters()
            TelemetryDeck.signal(event.eventName, parameters: parameters)
            print("Telemetry enviou o evento: \(event.eventName) → \(parameters)")
            syncDataToTelemetry()
        } catch {
            print("Erro ao codificar evento \(event.eventName): \(error)")
        }
    
    }

    static func syncDataToTelemetry() {
        TelemetryDeck.requestImmediateSync()
        /* Ei, TelemetryDeck, envia agora o que estiver armazenado localmente (cache) para o servidor. Por padrão, o TelemetryDeck guarda os sinais em cache e envia em lotes automáticos a cada ~30 segundos. Este método força o envio imediato, útil durante testes ou antes de o app ser encerrado. */
    }

    
    
    // MARK: - Tempo de tela (duration signals)
    
    
//    static func startScreen(_ screen: Screens) {
//        TelemetryDeck.stopAndSendDurationSignal("ScreenTime", parameters: ["screen": "Home"])
//    }
    //    Error! Ou seja: ele precisa rodar na Main Thread, e o compilador não deixa você chamar de um contexto que possa ser background. "Call to main actor-isolated static method 'stopAndSendDurationSignal(_:parameters:floatValue:customUserID:)' in a synchronous nonisolated context"
            
    //MARK: - Forma 1:
    //Aqui a gente está dizendo para o Swift: “Espere até ter acesso à thread principal, e aí rode essa parte do código.” É o mesmo que pedir licença pra entrar no main thread. Mesmo podendo ser "pausada" por ser uma funcao async (roda em qq thread), dentro dela falamos pra rodar na main.
//    static func startScreen(_ screen: Screens) async {
//        await MainActor.run {
//            TelemetryDeck.stopAndSendDurationSignal("ScreenTime", parameters: ["screen": "Home"])
//        }
//    }
    
    //MARK: - Forma 2:
   /*  Aqui o Swift cria uma mini thread temporária (uma Task) para executar este código de forma assíncrona.
     Importante: uma Task pode rodar tanto na Main Thread quanto em background (nonisolated),
        dependendo de onde ela for criada.
        - Se for criada dentro de um contexto de UI (ex: SwiftUI View), ela herda o MainActor automaticamente.
        - Se for criada dentro de um contexto neutro (ex: um service ou model), ela NÃO herda o MainActor e o compilador pode reclamar ao chamar funções marcadas como @MainActor.
    A anotação @MainActor in dentro da Task é o que garante explicitamente que o bloco rode na main thread. Mesmo que a funcao na documentacao esteja com anotacao ele n vai inferir!
    */
//    static func startScreen(_ screen: Screens) {
//        Task { @MainActor in //isolamos o ator ao colocar assim, nao é lista de captura como em closures é uma clausula de isolamento de ator(qual thread) isso ficou mais forte no swift 5.9, ja q concorrencia foi lancada no 5.5 (ver Strict Concurrency Checking), sem a clausula ele ate funciona mas poderia gerar um erro em tempo de execucao ou travar o app, ou simplesmente nao enviar para o telemetry. "roda mais nao envia
//            TelemetryDeck.startDurationSignal(screen.rawValue)
//        }
//    }

        
    //MARK: - Forma 3:
    //dizemos a fila principal do sistema: assim que puder, roda esse código pra mim (pre-concurrency, modo tradicional)
//    static func startScreen(_ screen: Screens) {
//        DispatchQueue.main.async {
//            TelemetryDeck.stopAndSendDurationSignal("ScreenTime", parameters: ["screen": "Home"])
//        }
//    }
    
    //MARK: - Forma 4:
//    Aqui a gente “prega uma plaquinha na porta” da função dizendo: “tudo que acontecer aqui dentro roda na thread principal”.
    @MainActor
    static func startScreen(_ screen: Screen) {
         TelemetryDeck.startDurationSignal(screen.rawValue)
    }
    
    @MainActor
     static func endScreen(_ screen: Screen) {
        TelemetryDeck.stopAndSendDurationSignal(screen.rawValue)
    }
}


// MARK: - Eventos de analytics
enum AnalyticsEvent {
    case characterSelection(CharacterSelectedEvent)
    case custom(name: String, parameters: [String: String] = [:]) // ja passa vazio os parametros se nao tiver

    var eventName: String {
        switch self {
        case .characterSelection: return "CharacterSelection"
        case .custom(let name, _): return name
        }
    }

    func parameters() throws -> [String: String] {
        switch self {
        case .characterSelection(let event):
            do {
                 // Tenta converter a struct em dicionário
                 return try event.asStringDictionary()
             } catch {
                 // Se falhar, mostra o erro e devolve dicionário vazio
                 print("⚠️ Erro ao converter evento para dicionário: \(error.localizedDescription)")
                 return [:]
             }
             // Se for custom, apenas retorna o que foi passado
        case .custom(_, let parameters):
            return parameters // poderia deixar [:] mas assim a gente tira a opcao de preencher casos adicionais
        }
    }
    
    
    // MARK: - Enum de telas
    enum Screens: String {
        case home = "Rick and Morty List (all characters)"
        case character = "Character Details"
    }
}

// MARK: - Structs de eventos
struct CharacterSelectedEvent: Codable {
    let name: String
    let origin: String
    let date: String
}
